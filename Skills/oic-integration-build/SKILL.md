---
name: oic-integration-build
description: Patterns, platform constraints, and design decisions for building Oracle Integration Cloud (OIC) integrations against Oracle Fusion REST and SOAP services. Covers the var _ret JavaScript pattern, payload-in-JS vs scalar-only design, Stitch vs Assign rules, Stage File patterns for Base64 payloads and JS-returned JSON, halt-guard wrappers, manual For-Each counters, Fusion REST quirks (standardReceipts Status not queryable), Fusion SOAP createApplyReceipt response shape (Messages + Values, no fault binding), BIP runReport handling, JS library activation caching, the scope-per-REST-call fault model and uniform exceptions[] response contract, and the cash-application payment rollup and status vocabulary. Use whenever building, modifying, or debugging an OIC integration; writing JavaScript for an OIC library; working with Fusion REST or SOAP; or mentioning For-Each, Stitch, Scope variables, Call JavaScript Function, Stage File, BIP, createApplyReceipt, standardReceipts, exceptions[], or any OIC/Fusion construct.
---

# OIC Integration Build

A skill for designing and implementing Oracle Integration Cloud integrations against Oracle Fusion (or any system using a similar REST+SOAP backplane). Born from extensive trial-and-error on a multi-payment cash application orchestration, it captures the platform constraints, design decisions, and orchestration patterns that aren't obvious from Oracle's documentation.

## Core philosophy

OIC is a low-code orchestration platform with sharp edges. Most patterns that look natural on paper run into a platform quirk in practice. The patterns in this skill are not preferences — they are the shapes the platform actually accepts.

Three principles anchor every design decision:

**1. Payload-in-JS is the preferred default.** Send the inbound XML to a JavaScript function, convert it to JSON inside the function, run the business logic on the JSON, and return either a scalar verdict or a transformed JSON string. This minimizes the number of OIC steps per integration — JS does the heavy lifting in one activity, and OIC does the orchestration around it. The earlier "everything as scalars" pattern (used by the cash app library) is now an exception, reserved for cases where the orchestration genuinely needs per-iteration visibility in the activity stream.

**2. The standard data flow.** Default to this shape:
   - OIC receives XML (the request trigger payload, a SOAP response, a BIP report output).
   - Call JavaScript Function: input is `getContentAsString($xmlVariable)`. Inside the JS, decode entities, parse the XML to a JSON object, run all the business logic, decide.
   - JS returns either a **scalar** (string/number/boolean — e.g. a verdict code or status string) or a **JSON string** (when downstream activities need to consume structured data).
   - If JSON is returned, the next OIC activity is **Stage File "Read Entire File"** with a file reference built via `decodeBase64ToReference(encodeBase64(...))` and a Sample JSON Document. The Stage File output is a typed variable downstream activities can XPath into.

   The Stage File round trip is mandatory for any JSON return — OIC has no native JSON parser. See `references/interop-patterns.md` for the exact mechanics.

**3. The platform tells you what it accepts.** When an idea doesn't work, it's usually a platform constraint, not a logic bug. Check `references/platform-constraints.md` before assuming the problem is your code.

## When to use this skill

Pull this skill in whenever the work involves:

- Designing or modifying an OIC integration flow
- Writing or reviewing JavaScript code for an OIC library
- Calling Oracle Fusion REST or SOAP services from OIC
- Constructing For-Each, Switch, Stitch, Map, Stage File, or Call JavaScript Function activities
- Debugging an OIC error that doesn't have an obvious explanation
- Working with BIP report responses (typically Base64-encoded XML)
- Translating between JSON, XML, and OIC's typed variables

## Reference files — read on demand

Each reference is a deep dive on a specific topic. Read the one that matches the current task. They are designed to be read end-to-end and are short enough to fit comfortably in context.

- **`references/platform-constraints.md`** — Things that don't work in OIC, and why. Start here when something unexpected fails. Covers For-Each restrictions, Assign vs Stitch boundaries, scope variable lifecycle, the no-empty-Switch-branch rule, indexer behavior in XPath vs For-Each sources, number coercion, boolean-as-string, the JS library activation cache trap.

- **`references/javascript-patterns.md`** — The `var _ret` pattern (mandatory for every declared function), ES5.1/Nashorn constraints, prefix conventions, the no-trailing-commas rule, JSDoc requirements, internal helper conventions. Read before writing any JS code targeted at OIC.

- **`references/orchestration-patterns.md`** — How to structure For-Each loops with manual counters, halt-guard wrappers between sections, verdict-code Switch patterns, fresh-counter trick for re-iteration, Stitch operations (assign / append / replace / remove), scope variable reset patterns. Read when laying out an integration's flow.

- **`references/fusion-service-quirks.md`** — Quirks specific to Oracle Fusion services: /standardReceipts Status not queryable, /receivablesInvoices behavior, StandardReceiptService createApplyReceipt response shape (Messages + Values, no separate fault binding, no processControl, no BusinessUnit), BIP runReport returning Base64. Read when integrating with Fusion specifically.

- **`references/interop-patterns.md`** — How to move data between JavaScript and OIC. Covers `getContentAsString` for payload input, scalar return passthrough, the `decodeBase64ToReference(encodeBase64(...))` Stage File round trip for JSON-string returns, Sample XML/JSON Document configuration. Read when designing the JS↔OIC boundary.

- **`references/verification-toolkit.md`** — Commands and scripts for verifying JS syntax (`node --check`), Nashorn ES5 compatibility (`jjs --language=es5`), HTML well-formedness (lxml), screenshot rendering (Playwright), and how to use the `hackett-fusion` MCP server to probe live Fusion tenants. Read when validating output.

## Workflow when asked to build or modify an OIC integration

1. **Confirm the default applies** — payload-in-JS unless there's a specific reason to deviate. Reasons to deviate: the orchestration needs per-iteration visibility in the activity stream for ops/audit purposes; multiple independent decisions need to fan out across different OIC branches based on the same data; or the JS would become unwieldy (>500 lines for a single function's responsibility). If none of those apply, default to payload-in-JS.

2. **List the constraints in play** — Skim `references/platform-constraints.md` for any that apply to the task. If the user's request implies an indexer-based For-Each source, or assigning a literal `""` to a scope variable, or using `oraext:parseJSON`, flag it now rather than later.

3. **Identify the patterns in play** — From `references/orchestration-patterns.md`, identify which patterns apply. For payload-in-JS integrations the orchestration shrinks: REST/SOAP trigger → Call JavaScript Function → (Stage File round trip if JSON returned) → Map to response. For scalar-only integrations (the exception), full For-Each + counters + halt guards apply.

4. **Draft step-by-step** — Build the integration as a numbered linear recipe ("Step 1 — drop X, Step 2 — drop Y"). The recipe format forces every activity to be specified concretely; vague prose hides ambiguity. Include exact mapper expressions, exact scope variable names, exact Switch conditions.

5. **Pre-flight check the JS** — If new JavaScript is being added, lint and Nashorn-verify before handing off. See `references/verification-toolkit.md`.

6. **Watch for the cache** — When testing changes, the OIC library activation cache will bite. Apply the six-step refresh from `references/platform-constraints.md` whenever a JS change doesn't seem to take effect.

## Top platform constraints (the ones that bite most often)

These are summarized here for fast reference. Full discussion in `references/platform-constraints.md`.

1. **For-Each repeating element must be a structural collection reference.** No predicates (`[x = y]`), no indexer expressions (`payments[$pIdx]/allocations`). Use the current iteration's structural variable (e.g. `$payment/allocations`) and address other variables positionally via a manual counter inside the loop.

2. **For-Each has no built-in index.** Declare a counter scope variable with default `0` in the declaration UI. First activity inside the loop body is `Assign $counter := fn:number($counter) + 1`.

3. **Assign is scalars only. Stitch is for complex variables.** And `Stitch assign` is the verb for setting a scalar to a literal value when you can't use Default.

4. **Cannot Assign to literal `""` or `0`.** Initial values come from the declaration UI's Default field. Resets either declare a fresh variable or use a Stitch with a literal value.

5. **JSON numbers infer as xsd:double.** Wrap arithmetic and comparison expressions in `fn:number()` on BOTH sides: `fn:number($pIdx) + 1`, `fn:number($a) + fn:number($b)`.

6. **Booleans are strings.** Declare scope variables as string with default `"false"`, not boolean. Switch conditions: `$flag = "true"`, not `$flag = true()`.

7. **No empty Switch branches.** Always use the proceed-on-true condition, single branch, no Otherwise. Restructure the logic if you find yourself wanting an empty branch.

8. **Indexer in regular XPath is fine** — `$response/payments[$pIdx]/allocations[$aIdx]` works inside Switch conditions, Stitch values, and `count()` expressions. Only For-Each repeating-element sources reject indexer paths.

9. **JS library activation cache.** Uploading a new library version isn't enough. Six-step refresh: save library, deactivate+reactivate integration, re-Save each Call JavaScript Function activity, hard-refresh designer UI. The most common failure modes are "uploaded but didn't Save" and "function signature changed but activity bound to old params".

## The JavaScript `var _ret` pattern (mandatory)

Every declared function intended to run in OIC's Nashorn engine must use this pattern:

```javascript
function someFunction(args) {
  var _ret;
  // ... compute value, possibly with early-return branches that all
  // assign _ret first ...
  if (condition) {
    _ret = earlyValue;
    return _ret;
  }
  _ret = mainValue;
  return _ret;
}
```

This applies to **public and internal** declared functions. Inline lambda callbacks (e.g. inside `.replace()`) do not need this — they are language-level constructs, not OIC-registered functions.

Full details, prefix conventions, JSDoc requirements, and the ES5.1 limitations are in `references/javascript-patterns.md`.

## The two design questions — defaults and exceptions

For any payload-consuming integration, two design choices have to be made. Both have strong defaults now:

**Q1: Where does the payload live during processing?**
   - **Default: inside JS.** Send the XML to a JS function via `getContentAsString($xml)`. The function parses, decides, and returns. Minimizes OIC step count.
   - **Exception: in OIC structural variables.** Used when per-iteration visibility in the activity stream is required for ops/audit, or when multiple independent decisions need to fan out across different OIC branches based on the same data. The cash app library follows this exception path.

**Q2: What does the JS function return?**
   - **Scalar (string/number/boolean)** — consumer uses `$JsCall/output_*__ret` directly downstream. Good for verdict codes, status strings, simple boolean decisions.
   - **JSON string** — consumer needs the Stage File round trip with `decodeBase64ToReference(encodeBase64(...))` to convert the JSON back into a typed OIC variable. Required when downstream activities (Map, Stitch, For-Each) need to read structured data. See `references/interop-patterns.md` for the exact mechanics.

If unsure, default to payload-in-JS with the smallest-possible return shape. Only fall back to the scalar-only path when there's an articulable reason to.

## Cash-application response contract (rollup, status vocabulary, exceptions[])

These rules are specific to the cash-application family of integrations but generalize to any payload-in-JS orchestration that applies line items and reports a structured result. They were hardened on the DigiKey Phase 2 build.

### Payment-level rollup precedence

The finalize function computes each payment's `statusCode` from its allocation outcomes. When **at least one** allocation applied, the code is the financial comparison of applied total vs total due: `payment-success` (equal), `payment-less-than-total-due-success` (under), or `payment-more-than-total-due-success` (over). When **no** allocation applied, the payment takes a true failure code with this precedence — never a `*-success`:

```
customer-not-found  >  receipt-not-found  >  payment-apply-failed
```

`customer-not-found` wins if any allocation is `allocation-customer-not-found`; else `receipt-not-found` if any is `allocation-no-receipt-match`; else `payment-apply-failed` (apply faults, invoice-not-found, no-balance, or pending safety-net). Every non-applied allocation is **cleared**: `applied_amount = 0` and `receipt_number = ""`.

- **`totalDue` = sum of resolved invoice balances**, captured at skeleton-build time — NOT the applied sum. A $200 line that applies cleanly against an $847 invoice still yields `payment-less-than-total-due-success` because 200 < 847.
- **`infoFlags` (`payment-header-line-mismatch`)** is computed from the **requested** line amounts captured BEFORE clearing, so it survives the zeroing and still reflects what the remittance asked for. It is independent of the apply outcome and co-occurs with any `statusCode`.

### Allocation status vocabulary the library actually emits

`allocation-applied`, `allocation-no-receipt-match`, `allocation-customer-not-found`, `allocation-invoice-not-found`, `allocation-no-remaining-balance`, `allocation-apply-failed`. Note: **`allocation-skipped` is NOT emitted** — earlier docs referenced it, but the implemented library does not produce it. Don't expect or assert it.

### Matching rule

Match a receipt to a payment on the receipt's **`UnappliedAmount`** (not gross `Amount`) within **±0.005**, same currency, anchor-customer match, and a **±2-day** window around `payment_date`. First (oldest) qualifying receipt wins.

### The uniform exceptions[] contract + scope-per-REST-call fault model

The response carries a single top-level `exceptions[]` array, separate from per-payment/per-allocation status. Wire it from a **scope-per-call fault model**: one outer process scope wrapping the whole flow, plus one scope wrapping **each REST invoke**. Every scope's fault handler emits one entry. The `createApplyReceipt` SOAP invoke is **not** scope-wrapped — its business errors ride inside a 200-level envelope, so the JS library detects them and appends the entry itself.

Every entry shares ONE uniform object shape — all seven keys always present, unused ones empty `""` or `[]`, so the caller never needs a presence check:

```
{ type, errorCode, reason, severity, title, detail, errorDetails[] }
```

`errorDetails[]` elements are likewise uniform: `{ type, instance, title, errorPath, errorCode }`.

Field population by `type`:

- **`GENERIC`** (outer process scope handler): `errorCode`, `reason` filled; `severity`/`title`/`detail` empty; `errorDetails: []`. The catch-all of last resort for anything not caught by a REST scope.
- **`REST`** (per-REST-call scope handler): `errorCode`, `reason`, `title`, `detail`, `errorDetails[]` filled from the Fusion REST error body; `severity` empty.
- **`createApplyReceipt`** (emitted in JS, not a scope handler): `errorCode` = SOAP code, `reason` = SOAP message (+ payment/invoice/receipt context), `severity` = the SOAP `<severity>` element; `title`/`detail` empty; `errorDetails: []`.

**SOAP faults are single-sourced into exceptions[].** The allocation row still reports `statusCode = allocation-apply-failed` so the caller knows the line didn't apply, but its `faultDetail` is left `""` — the diagnostic lives only in the matching `createApplyReceipt` entry, correlated by payment reference + invoice number. Don't keep a second copy on the row.

Accumulate REST/GENERIC entries in a scope string variable (a JSON-stringified array mutated like the skeleton state), then merge into `skeleton.exceptions[]` at finalize before mapping the trigger response. `exceptions[]` is always present — empty `[]` on a clean run.

> Excluded from this skill: the one-off "open AR in TEST" data pull used during development. It is not a reusable integration pattern.

## What this skill does NOT cover

- General OIC platform basics (how to create an integration, how to configure a connection). Assumes the user knows the OIC console.
- Iterating on a skill — that's the skill-creator skill.
- Non-Fusion target systems (though many patterns generalize, the service-quirks reference is Fusion-specific).
- Performance tuning beyond "don't put expensive operations in tight loops".

## Working notes from the project that birthed this skill

The DigiKey Cash Application Phase 2 orchestration was the proving ground. Specific artifacts referenced:
- `cashApplicationLib_v40.js` — five public `dkcajs_` functions (planInvoiceLookup → planReceiptsLookup → buildAppliesAndSkeleton → recordApplyResult → finalizePaymentStatus) plus underscore-prefixed internal helpers, all following the `_ret` pattern (the grandfathered originals were exempted retroactively). v39 added the payment-level rollup precedence; v40 added the uniform `exceptions[]` builder and single-sourced SOAP faults into it.
- `cash_application_oic_implementation_guide_v63.html` — linear activity-by-activity walkthrough with a full TOC; §9 documents the scope model and the `exceptions[]` contract.
- `cash_app_phase_2_architecture_v4.docx` — §8.4 defines what each `exceptions[]` type means and when it is used; Appendix D is the scope-construction checklist.
- The hackett-fusion MCP server (`auth_check`, `execute_sql`, `run_bip_report`, `identify_environment`) for live tenant queries.

When in doubt, mirror the patterns that work in those artifacts rather than inventing new ones.
