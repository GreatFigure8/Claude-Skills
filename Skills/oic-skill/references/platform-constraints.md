# OIC Platform Constraints

This is the catalog of things that DO NOT WORK in OIC and the workarounds. Every entry was discovered by trying it and failing. When something fails unexpectedly, start here.

## For-Each repeating element rules

**The repeating-element source of a For-Each must be a structural collection reference.** This means a variable path that names a collection element directly. It cannot be:

- A predicate-filtered XPath: `$response/payments[$pIdx]/allocations[ns57:invoiceCustomer != ""]` is rejected.
- An indexer expression: `$response/payments[$pIdx]/allocations` is rejected even though it resolves to a single collection — the predicate `[$pIdx]` makes it not a structural reference.
- An XPath with a function call: `subsequence(...)`, `filter(...)`, anything dynamic.

**What does work:**
- The current iteration's child collection: `$payment/ns57:allocations` (works because `$payment` is the current For-Each element and `/ns57:allocations` is a direct child path).
- A top-level variable's direct child collection: `$ListReceipts/.../response-wrapper/items`.
- The integration trigger payload's collection: `$request/ns57:payments`.

**The workaround when you need a subset:** Iterate the full collection, then use an inside-the-loop Switch as the first activity to skip elements that don't match the filter criterion. The "filter" becomes a proceed-if-X condition inside the loop body.

**The workaround when you need positional access in another variable:** Manual counter pattern. Iterate the structural collection; increment a counter at the top of the loop body; use the counter to index into the other variable via XPath (which DOES accept indexers inside expressions).

## For-Each has no built-in index variable

OIC's For-Each does not expose `position()`, `index()`, or any similar built-in. Always declare a counter:

1. In the integration's variable declaration UI (Designer → Variables → Add), declare a scope variable. Type: number. Default value: 0.
2. As the **first activity inside the For-Each body**, drop an Assign that increments it:
   ```
   TARGET: $counter
   VALUE:  fn:number($counter) + 1
   ```
3. Reference `$counter` in any downstream activity inside the loop.

The `fn:number()` wrapper is critical — without it, OIC may treat the variable as xsd:double and arithmetic gives the wrong result (see "Number coercion" below).

When iterating a second time over the same source, declare a NEW counter (e.g. `$aIdx2`), not reset `$aIdx`. See the "Cannot Assign to literal 0" entry.

## Assign is scalars only; Stitch is for complex variables

The Assign activity in OIC accepts only scalar values (string, number, boolean) as both target and source.

When the target is a complex variable (an XML element, a JSON object, a collection), use Stitch. Stitch supports:
- `assign` — set the target to the value (scalar or complex)
- `append` — add an element to a collection
- `insert` — insert at a position
- `remove` — delete an element
- `replace` — replace a complex element

Stitch can also assign scalars to scope variables — useful when you need to reset a scope variable to a literal value (since Assign can't take literals, see below).

## Cannot Assign to literal `""` or `0`

OIC's Assign activity treats literal empty strings and zeros as "no value" and rejects the assignment. This is a frequent surprise when trying to reset a scope variable mid-flow.

**Workarounds:**
1. **Best:** declare the variable with the desired default value in the declaration UI. The default is applied at the start of each enclosing scope (per-payment, per-iteration, integration-level).
2. **For resets mid-flow:** use Stitch with operation `assign`. Stitch tolerates literal values that Assign rejects:
   ```
   OPERATION: assign
   TARGET:    $previouslyApplied
   VALUE:     "false"
   ```
3. **For counter re-use:** declare a fresh counter (`$aIdx2`) for the second iteration rather than trying to reset `$aIdx`.

## Complex-type root-to-root assignment rejected

A Stitch assign like `$response := $request` won't work even when the types are compatible. OIC requires you to map at the collection level:

```
OPERATION: assign
TARGET:    $response/ns57:payments
VALUE:     $request/ns57:payments
```

Collection-to-collection IS allowed; root-complex-type-to-root-complex-type is not.

## No native XML↔JSON serialization

`oraext:parseJSON` and `oraext:serializeToJson` do NOT exist in OIC. Common misconceptions; they show up in tutorials for other Oracle products but not OIC.

**When you have an XML payload and need it as JSON:** see `interop-patterns.md` for the regex-based JavaScript approach and the Stage File round trip.

**When a Call JavaScript Function returns a JSON string:** Stage File "Read Entire File" with a file reference built from `decodeBase64ToReference(encodeBase64(output_JavaScript1__ret))` and a Sample JSON Document — see `interop-patterns.md`.

## XPath collections are 1-indexed

`$collection[1]` is the first item, not `[0]`. Apply this consistently — using `[0]` returns an empty result, often silently.

## Indexed XPath is fine in regular expressions

This trips people up because the rule is asymmetric:

- **In For-Each repeating-element source:** indexer-based paths rejected. `$response/payments[$pIdx]/allocations` will fail validation.
- **In Switch conditions, Stitch values, and any other XPath expression:** indexer-based paths work fine. `count($ListReceipts/.../items[$matchedReceiptIdx]/remittanceReferences[...])` is valid.

When tempted to declare a new For-Each to filter or access nested structure, ask first: can a `count()`, `sum()`, or `string-join()` XPath in a single activity do the work? Often yes.

## Number coercion — `fn:number()` is required everywhere

OIC's sample-JSON inference treats every numeric value as xsd:double. Arithmetic on xsd:double works in some contexts and fails silently in others (especially comparisons). To avoid the surprise, wrap **BOTH sides** of any arithmetic or comparison in `fn:number()`:

```
fn:number($pIdx) + 1
fn:number($totalDue) + fn:number($invoice/InvoiceBalanceAmount)
fn:number($paymentAmount) > fn:number($totalDue)
```

`fn:current-date()` returns an xs:date, not a number — use it for date fields without further wrapping. Same for `fn:current-dateTime()`.

## Booleans are strings

Boolean as a type doesn't behave consistently across OIC's XPath, JavaScript callouts, and JSON serialization. The robust pattern is to use strings:

- Declare scope variables as **string** with default `"false"` (not boolean false).
- Switch conditions: `$flag = "true"` and `$flag = "false"`.
- JS functions return the literal strings `"true"` or `"false"`, not JavaScript booleans.
- Stitch assigns use string literals: `VALUE: "true"`.

This convention applies everywhere flags are used.

## No empty Switch branches

OIC accepts a Switch with a single branch and no Otherwise — and that is the right pattern when you want "proceed only if condition true, otherwise skip to whatever comes after."

But it does NOT accept an empty branch. If you find yourself wanting `Branch (cond): empty; Otherwise: do work`, restructure as `Branch (not cond): do work; no Otherwise`. Stop trying to make the truth side empty — that's an anti-pattern that gets caught at activation.

## JavaScript library activation cache

This is the single biggest source of "but I just changed it and nothing happened" confusion. OIC binds Call JavaScript Function activities to a specific library snapshot at integration activation time. Changes to the library do not propagate until you force a re-bind.

**The six-step refresh:**

1. **Confirm the upload actually changed the library.** Open the library in Console (Design → Libraries → your-lib). If your new function isn't visible or a removed function is still listed, the upload didn't take. Re-upload with a trivial top-of-file comment change to force a different file hash so OIC sees a real change.

2. **Save the library after upload.** Uploading isn't enough — you must click Save on the library's Configure screen. That bumps the library's internal version. No Save = no version bump.

3. **Deactivate AND reactivate the integration.** Edit → save → reactivate isn't always enough. Hit Deactivate first, wait until it shows Configured, then Activate. This forces OIC to re-resolve every Call JavaScript Function activity.

4. **Open each Call JavaScript Function activity and re-Save it.** Click in, hit Save without changing anything. This re-binds the activity to the current function signature. **If you added or removed parameters, this is mandatory** — parameter slots are cached on the activity, not on the library.

5. **Hard refresh the Designer UI.** Ctrl+Shift+R. OIC's React UI caches metadata aggressively and will show yesterday's function list.

6. **Check the activity logs.** Run the integration; in the activity stream, expand the JS activity. It shows which library version it actually called. If that version is older than your latest upload, one of the above steps didn't take.

The two most common failure modes:
- Step 2 missed (uploaded but didn't Save).
- Step 4 missed when the function signature changed (activity bound to old params).

## Stitch operation pitfalls

- **`assign` is the workhorse.** Most operations are assigns.
- **`append` requires the target to be a repeating element.** If `$response/.../infoFlags` is declared as a single string (not an array), `append` fails. Use `assign`.
- **`replace` requires an existing element.** If the target doesn't exist, use `assign` with a complex value instead.

## Schema inference traps from Sample JSON / XML Documents

When pasting a Sample JSON Document into a Stage File or trigger, OIC infers the schema from what it sees. Common traps:

- **Empty arrays infer as `array<any>`** — element type is unknown. Always populate at least one example element so OIC can infer the element type.
- **Optional fields absent from all samples don't appear in the schema.** If you'll Stitch a field onto the response, include it in at least one sample row.
- **Field type follows the first occurrence.** If `applied_amount` appears as integer `100` first and decimal `14.58` second, OIC may infer integer and fail on the decimal. Put the decimal example first or use floating-point throughout.

## SOAP fault handling without verbose returnMode

Without `processControl/returnMode="Full"` (which most Fusion services do not accept), SOAP faults come back differently:

- Some services (`StandardReceiptService.createApplyReceipt`) return errors INSIDE the success envelope, in a `Message[*]` collection. There is no SOAP fault binding to handle.
- Other services return standard SOAP 1.1 faults to the Invoke activity's fault path. The fault element variable is typically `$ActivityName_Fault` or just `$fault` depending on adapter version.

Always capture a real fault payload via the OIC Test action before designing the fault handler. Don't assume one shape over the other.

## Date and time handling

- `fn:current-date()` returns the current xs:date (no time component). Use for GL dates.
- `fn:current-dateTime()` returns the current xs:dateTime. Use when time of day matters.
- OIC's date strings in JSON are typically ISO 8601 (`2025-05-22` or `2025-05-22T14:30:00.000+00:00`).
- For date math, parse ISO strings to xs:date with `xs:date($s)` then add/subtract via `xs:dayTimeDuration("P2D")`.
- In JavaScript, work with ISO strings as substrings (`s.substring(0, 10)`) rather than relying on `Date` constructors — Nashorn's Date timezone behavior varies.
