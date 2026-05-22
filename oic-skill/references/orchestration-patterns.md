# Orchestration Patterns

> **Scope note.** This reference documents the **scalar-only orchestration path** — the exception, not the default. It uses nested For-Each loops, manual counters, halt-guards, verdict-Switches, and OIC-side Stitch enrichment. For new builds, start from `references/payload-in-js-orchestration.md` (the payload-in-JS thin shape that the cash app was rebuilt into). The patterns here remain valid for the genuine scalar-only exception cases described in `references/interop-patterns.md`, and for understanding/maintaining any legacy scalar-only integration.

Composable patterns for OIC flow design. Most integrations are a small number of these patterns repeated and combined.

## The manual counter pattern (For-Each with positional access)

OIC's For-Each has no built-in index. Every loop that needs to address a sibling variable positionally needs a manual counter.

**Declaration (in Variables UI):**
- Name: `$counter` (project-specific name: `$pIdx`, `$aIdx`, `$rcptIdx`, `$mIdx`)
- Type: number
- Default value: 0

**First activity inside the For-Each body:**
```
Activity:  Assign
TARGET:    $counter
VALUE:     fn:number($counter) + 1
```

**Usage downstream in the loop body:**
```
$response/ns57:payments[$counter]/ns57:allocations[$counter2]/ns57:fieldName
```

**Why `fn:number()` is mandatory** — without it, OIC infers the counter as xsd:double from the JSON sample (if applicable) and arithmetic produces incorrect values. Wrap both sides of any arithmetic on counters.

## Scope variable lifecycle

OIC scope variables are declared at a specific nesting level (integration root, inside a Scope activity, inside a For-Each). They have lifetime equal to their declaring scope.

**Where to declare what:**
- **Integration-level (root):** Cross-payment counters like `$pIdx`. Variables that need to survive across outer-loop iterations.
- **Per-payment (inside outer For-Each):** Per-payment counters, accumulators, match results, halt flags. Reset per outer iteration because the For-Each re-enters the scope.
- **Per-allocation (inside inner For-Each):** Allocation-level transient values. Most allocation work uses per-payment scope variables addressed positionally via counters.

**The reset pattern:**
- For variables that should reset per outer iteration: declare in the per-payment scope. They auto-reset.
- For variables that need a fresh start mid-flow (e.g. between two For-Each loops at the same scope level): declare a NEW variable rather than trying to reset the old. Counter pattern: `$aIdx` for first loop, `$aIdx2` for second loop. Don't reset `$aIdx`.
- For variables that need to reset per inner-iteration (e.g. `$previouslyApplied` reset per allocation in the apply loop): keep at per-payment scope; first activity inside the inner loop is a Stitch with `OPERATION: assign, TARGET: $var, VALUE: "false"` (or 0, or "").

## The halt-guard wrapper pattern

When the integration has multiple sequential sections that can each halt processing of a payment, wrap each section after the first in a halt-check.

**Initial declaration:** `$paymentHalted` at per-payment scope, type string, default `"false"`.

**Section boundary pattern:**

```
Section A executes. May Stitch $paymentHalted := "true" if it decides to halt.

Section B header — drop a Switch activity:
  Condition (single branch, no Otherwise): $paymentHalted = "false"
  Inside the branch: all of Section B's activities.

Section C header — drop another Switch (sibling, not nested):
  Condition (single branch, no Otherwise): $paymentHalted = "false"
  Inside the branch: all of Section C's activities.
```

Each section's halt-guard checks the CURRENT value of `$paymentHalted`, because previous sections may have changed it.

**Single-branch, no Otherwise** — this is the OIC anti-pattern avoidance. Don't use a two-branch Switch with an empty Otherwise.

## The verdict-code Switch pattern

When a decision has more than two outcomes, capture the decision into a string scope variable, then Switch on it.

**Step 1:** Drop a Call JavaScript Function. JS function returns a verdict string like `"ok:valid"`, `"halt:customer-not-found"`, `"fail:invoice-not-found"`.

**Step 2:** Capture into a scope variable:
```
Activity:  Assign
TARGET:    $verdictCode
VALUE:     $JS_Validate/output_JS_Validate__ret
```

**Step 3:** Drop a Switch with one branch per outcome:
```
Branch 1: $verdictCode = "halt:customer-not-found"
Branch 2: $verdictCode = "fail:invoice-not-found"
Branch 3: $verdictCode = "fail:no-remaining-balance"
Branch 4: $verdictCode = "ok:needs-pr-check"
Branch 5: Otherwise (catches "ok:valid" — the default success path)
```

**Why a string scope variable is better than a multi-condition Switch:** every branch condition is a simple equality check. No nested logic. Adding a new outcome is one new JS return value plus one new branch. The JS function's logic is the single source of truth.

## The proceed-if-X guard inside a loop

When iterating a structural collection but only wanting to act on a subset (e.g. only allocations with a populated invoice customer), use a guard Switch as the FIRST activity inside the loop body.

```
For-Each: $payment/ns57:allocations as $alloc
  First activity (after counter increment): Assign $counter := fn:number($counter) + 1
  Second activity: Switch with single branch, no Otherwise
    Condition: $response/.../allocations[$counter]/ns57:invoiceCustomer != ""
    Inside the branch: all the per-iteration work
```

This pattern replaces the would-be (rejected) `[predicate]` filter on the For-Each source.

## The Stitch operations cheat sheet

| Operation | When to use | Example target |
|-----------|-------------|----------------|
| `assign` | Set a value (scalar or complex). Workhorse. | `$response/.../allocations[$aIdx]/ns57:statusCode` |
| `append` | Add an element to a repeating collection. | `$response/.../allocations` (the collection itself) |
| `insert` | Insert at a specific position. Rarely needed. | |
| `remove` | Delete an existing element. | |
| `replace` | Replace an existing complex element. | |

**Common pitfall:** Using `append` on a non-repeating field. If `infoFlags` is declared as a single string (not an array), `append` fails — use `assign`.

**Stitch with multiple operations:** A single Stitch activity can have multiple operations executed in sequence. Use this to bundle related writes (e.g. setting statusCode + receipt_number + faultDetail + failedCount all in one Stitch).

## The "valid" branch Stitch (sample from Step 19 of the cash app)

A typical standard-case Stitch on a valid allocation:

```
OPERATION: assign
TARGET:    $anchor
VALUE:     dkcasLib:dkcas_deriveAnchor($anchor, $invoice.../BillToCustomerNumber)

OPERATION: assign
TARGET:    $totalDue
VALUE:     fn:number($totalDue) + fn:number($invoice.../InvoiceBalanceAmount)

OPERATION: assign
TARGET:    $response/.../allocations[$aIdx]/ns57:businessUnit
VALUE:     $invoice.../BusinessUnit

OPERATION: assign
TARGET:    $response/.../allocations[$aIdx]/ns57:invoiceCustomer
VALUE:     $invoice.../BillToCustomerNumber
```

Four operations bundled. Three update accumulator/state scope variables; one writes onto the response.

> In the payload-in-JS rebuild, this OIC-side enrichment is gone: `businessUnit` and `invoiceCustomer` are written onto the allocation inside the JS (`buildAppliesAndSkeleton`) from the matched invoice row, and ride the final one-to-one response drag. See `references/payload-in-js-orchestration.md`. The Stitch form below is the scalar-only equivalent.

## Pre-computing scalars for clean Switch conditions

Rather than embedding heavy XPath in a Switch condition, pre-compute the result into a scope variable:

**Anti-pattern (works but unreadable):**
```
Switch condition: dkcasLib:dkcas_parseSoapResultIsSuccess(
  count($ApplyReceipt/.../result/Message[fn:string-length(ns0:code) > 0 or ...]),
  count($ApplyReceipt/.../result/Value),
  sum($ApplyReceipt/.../result/Value/ns0:AmountApplied)
) = "true"
```

**Pattern:**
```
1. Call JavaScript Function: name=JS_ParseApply, mapping the count() and sum() into the three params.
2. Switch with two sibling branches:
   Branch 1: $JS_ParseApply/output_JS_ParseApply__ret = "true"
   Branch 2: $JS_ParseApply/output_JS_ParseApply__ret = "false"
```

The JS activity is called once. Both Switch branches reference its output. Cleaner, and the function isn't called twice.

## The nested For-Each + counter pattern

When an outer loop's structural element is a complex with its own collection (e.g. payments containing allocations), the inner For-Each can iterate the current outer element's collection directly:

```
Outer For-Each: $request/ns57:payments as $payment
  Counter increment: $pIdx := fn:number($pIdx) + 1
  Per-payment scope reset (scope vars at per-payment level get fresh defaults).
  
  Inner For-Each: $payment/ns57:allocations as $alloc
    Counter increment: $aIdx := fn:number($aIdx) + 1
    Process this allocation.
    Address into $response positionally: $response/ns57:payments[$pIdx]/ns57:allocations[$aIdx]
```

This works because the inner For-Each's source (`$payment/ns57:allocations`) is a structural collection reference. Indexed addressing (`$response/.../payments[$pIdx]/allocations[$aIdx]`) is in a regular XPath expression (Stitch target), where indexers are fine.

## The fresh-counter trick for re-iteration

When the same payment's allocations need to be iterated twice (e.g. once for validation, once for SOAP apply), declare a second counter at the same scope:

```
Per-payment scope variables:
  $aIdx (number, 0)   -- used in first allocation loop
  $aIdx2 (number, 0)  -- used in second allocation loop
```

This avoids the "can't Assign literal 0" trap. Both counters auto-reset between outer iterations because they're declared at per-payment scope.

## Map activity vs Stitch — when to use which

Both can move data from one variable to another. Rough decision:

- **Map (visual data mapper):** good when you want to map a whole complex variable to another complex variable, especially for trigger response assembly. Drag-and-drop the source to the target; OIC infers field mappings by name.
- **Stitch:** better when you're updating one or a few fields inside a larger variable, or when computing values to write (using XPath expressions or function calls).

The cash app uses **Stitch everywhere** inside the loop (for fine-grained field updates) and **one Map activity at the very end** to write `$response` to the REST trigger response variable.

## Address into the response, not the request

The output of the orchestration is `$response`. When Stitching field values onto an allocation, always target the response copy of that allocation, never the request:

```
TARGET: $response/ns57:payments[$pIdx]/ns57:allocations[$aIdx]/ns57:statusCode
```

The request is read-only context. The response is the deliverable. The integration starts by seeding `$response/payments := $request/payments` (collection-to-collection Stitch assign), then mutates `$response` in place as orchestration progresses.

## A complete halt-guard + verdict-Switch + Stitch sequence

For reference, here's a representative section of the cash app orchestration:

```
Step 9:  Inner For-Each over $payment/ns57:allocations as $alloc
Step 10: First activity inside: Assign $aIdx := fn:number($aIdx) + 1
Step 11: Switch — single branch, no Otherwise: $paymentHalted = "false"
Step 12:   Inside the branch: REST invoke GetInvoices for $alloc/ns57:invoice_number
Step 13:   Call JS_Validate (returns verdict string)
Step 14:   Assign $verdictCode := $JS_Validate/output_JS_Validate__ret
Step 15:   Switch on $verdictCode with 5 branches:
Step 16:     Branch 1: "halt:customer-not-found" → Stitch $paymentHalted := "true", customer-not-found statusCode on payment + remaining allocations
Step 17:     Branch 2: "fail:invoice-not-found" → Stitch allocation-invoice-not-found on this allocation only
Step 18:     Branch 3: "fail:no-remaining-balance" → Stitch allocation-no-remaining-balance
Step 19:     Branch 4: "ok:needs-pr-check" → Stitch anchor/totalDue/businessUnit/invoiceCustomer, then BIP PR check, then validate result, possibly halt
Step 20:     Branch 5 (Otherwise): "ok:valid" → Stitch anchor/totalDue/businessUnit/invoiceCustomer (no PR check needed)
```

Every step is one activity. Every activity has a clearly named output variable. Every Switch condition is a simple equality on a scope variable. This shape composes well and is debuggable in the activity stream.
