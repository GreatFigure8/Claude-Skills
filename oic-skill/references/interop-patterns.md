# Interop Patterns — JavaScript ↔ OIC

How data crosses the boundary between JavaScript callouts and OIC's typed variable system. Reading this file BEFORE designing a payload-consuming JS function will save a refactor.

## The default pattern (payload-in-JS)

**Default to this shape for any payload-consuming integration:**

```
[Inbound XML payload]
    │
    ↓
Call JavaScript Function
    Input: getContentAsString($xmlVariable)
    JS converts XML → JSON internally (regex parser)
    JS runs business logic on the JSON
    Returns: scalar OR JSON string
    │
    ↓
[If scalar]  →  use $JsCall/output_*__ret directly downstream
[If JSON]    →  Stage File round trip → typed OIC variable
    │
    ↓
[Response or further OIC orchestration]
```

This minimizes OIC step count. One JS function does parsing + decisions + transformation. OIC's role shrinks to: receive the inbound, hand off to JS, route the result.

**Why this works:**
- The JS function is a single testable unit. Linting and Nashorn smoke tests cover it before deployment.
- The OIC orchestration becomes a thin wrapper — easy to read at a glance.
- Adding new business rules is a JS edit, not an OIC re-arrangement.

## When to fall back to the scalar-only pattern (exception)

The scalar-only pattern — JS receives discrete scalars (counts, sums, flags) computed in OIC via XPath, decides, returns one scalar — is used when:

- **Per-iteration visibility is required.** Operations or audit need to see each iteration's result in the OIC activity stream. With payload-in-JS, the activity stream shows one JS call and one result; with scalar-only, every iteration is a visible activity.
- **Multiple independent decisions fan out across the orchestration.** When the same data drives different OIC branches with different rules, scalar-only puts the decision points in OIC where the branching lives.
- **The JS would become unwieldy.** If a single function would exceed ~500 lines or have 10+ orthogonal responsibilities, the scalar-only split keeps each function small.

The DigiKey cash app library **originally** used scalar-only, on the reasoning that ops needed per-allocation visibility and the orchestration had many fan-out branches. It was later **rebuilt as payload-in-JS** (see `references/payload-in-js-orchestration.md`) — the per-allocation visibility turned out to be satisfied by the apply For-Each alone (each SOAP call still shows in the activity stream), and the fan-out branching moved into JS as `statusCode` strings. Treat the reasons below as the genuine triggers for scalar-only, but note that "per-iteration visibility" specifically is often weaker than it first appears: if the only thing that must iterate visibly is a set of external calls, keep just those in a For-Each and put the rest in JS.

## The two-question design check

Both questions now have strong defaults:

**Q1: Where does the payload live during processing?**
- **Default: inside JS.** Map the XML payload into the JS function via `getContentAsString($xml)`.
- **Exception: in OIC structural variables.** Choose this only when per-iteration visibility or fan-out branching demands it.

**Q2: What does the JS function return?**
- **A scalar** (string, number, boolean) → consumer uses `$JsCall/output_*__ret` directly downstream.
- **A JSON string** → consumer needs the Stage File round trip (described below).

## Input — sending data INTO JavaScript

OIC's Call JavaScript Function activity has a parameter mapper. Each declared JS function parameter gets a mapping expression that resolves to a value at runtime.

**For scalar inputs** — string, number, boolean — map the XPath expression directly:
```
Parameter: paymentAmount
Expression: fn:number($payment/ns57:payment_amount)
```

**For collection counts and sums** — pass the result of XPath aggregation:
```
Parameter: faultMessageCount
Expression: count($ApplyReceipt/.../result/Message[
  fn:string-length(ns0:code) > 0
  or fn:string-length(ns0:message) > 0
  or fn:string-length(ns0:severity) > 0
])

Parameter: valueCount
Expression: count($ApplyReceipt/.../result/Value)

Parameter: totalAmountApplied
Expression: sum($ApplyReceipt/.../result/Value/ns0:AmountApplied)
```

**For complex payloads (when path-(a) was chosen)** — use `getContentAsString`:
```
Parameter: jsonPayload
Expression: getContentAsString($jsonVariable)
```

`getContentAsString` converts a typed OIC variable into a string scalar JS can accept. The JS function receives the entire payload as one string parameter. This is the path-(a) entry point.

## Output — receiving data FROM JavaScript

JS functions return strings (or numbers/booleans). OIC exposes the result as `$JsCall/output_<functionName>__ret`.

**For scalar returns** — use the output directly downstream:
```
Switch condition: $JS_Validate/output_dkcas_validateInvoiceForAlloc__ret = "ok:valid"
Assign source: $JS_Compute/output_dkcas_computePaymentStatusCode__ret
```

This is path-(b)'s entire output story. No further processing needed.

**For JSON-string returns** — the consumer needs to parse the JSON back into a typed structure. This is the **Stage File round trip** below.

## The Stage File round trip for JSON returns

When a JS function returns a JSON string (e.g. an XML-to-JSON converter), OIC has no native JSON parser. The path that works:

**Step 1:** Call JavaScript Function returns the JSON string at `$JS_Convert/output_*__ret`.

**Step 2:** Drop a Stage File activity. Operation: **Read Entire File**.

**Step 3:** For File Reference, use this expression:
```
decodeBase64ToReference(encodeBase64($JS_Convert/output_*__ret))
```

What's happening: `encodeBase64` turns the JSON string into a Base64 string. `decodeBase64ToReference` decodes the Base64 string back to bytes AND wraps them in a file reference that Stage File can consume. Net effect: turn a string into a "file" without writing to disk.

**Step 4:** Configure File Contents → Sample JSON Document. Paste a JSON sample that matches the JS function's output shape. OIC infers the schema from the sample.

**Step 5:** The Stage File activity now exposes a typed variable at `$StageFileActivity/<root>` that downstream activities can XPath into normally — Stitch targets, Map sources, etc.

**Why this works:** Stage File is OIC's most flexible "give me typed data from a string" mechanism. It was designed for file inputs but accepts inline-string references via the encodeBase64/decodeBase64ToReference trick.

**Why this is the right pattern (vs alternatives):**
- `oraext:parseJSON` doesn't exist in OIC.
- Custom XSLT inside a Map is brittle.
- Writing the JSON to a stage file on disk works but requires file management.
- The round trip is one Stage File activity with one expression. Clean.

## The Stage File pattern for Base64 XML (BIP reports)

The same `Read Entire File` mechanism handles Base64-encoded XML from BIP `runReport`:

**Step 1:** Invoke `runReport`. Response includes `reportBytes` — a Base64-encoded XML string.

**Step 2:** Stage File → Read Entire File. File Reference:
```
$PrCheck/runReportResponse/runReportReturn/reportBytes
```

No `decodeBase64ToReference` wrapper needed here — `reportBytes` is already typed as Base64 in the SOAP WSDL, so OIC handles the decode automatically.

**Step 3:** Configure File Contents → Sample XML Document. Upload a captured XML response from the BIP report (e.g. the `<DATA_DS>` envelope with sample `<G_1>` rows).

**Step 4:** Downstream access via `$StageFileActivity/DATA_DS/G_1[...]` etc.

## Choosing path-(a) or path-(b) — practical guidance

**Path-(a) (payload-in-JS) is now the DEFAULT.** Use unless one of the path-(b) reasons applies. The motivation is fewer OIC steps per integration, easier maintenance, and a single testable artifact.

**Path-(b) (scalar-only JS) is the exception.** Choose only when:
- Per-iteration visibility in the OIC activity stream is required for ops/audit (each iteration shows up as a distinct activity entry).
- Multiple OIC branches fan out from the same data on different rules (branching belongs in OIC, not JS).
- The JS would become unwieldy (>500 lines per function, >10 orthogonal responsibilities).

**The DigiKey cash app was migrated FROM path-(b) TO path-(a).** Its original design cited both of the first two reasons, but the rebuild showed the per-iteration-visibility reason was satisfied by keeping only the SOAP apply calls in a For-Each while moving all decisions into JS. See `references/payload-in-js-orchestration.md`. For integrations without a hard fan-out requirement, path-(a) is preferred — and even with one, check whether only the external calls truly need to iterate visibly.

When in doubt, start with path-(a) and only split into scalars if a real reason emerges. The reverse direction (consolidating scalars back into a single payload-in-JS function) is harder than starting consolidated.

## Common interop pitfalls

**1. Forgetting `fn:number()` on JS return values used in arithmetic.**
JS returns are strings. `$JS_Compute/output_*__ret + 1` does string concatenation. Wrap: `fn:number($JS_Compute/output_*__ret) + 1`.

**2. Treating JS booleans as XPath booleans.**
JS returns the strings `"true"` and `"false"`. Switch conditions: `$JS_Check/output_*__ret = "true"`, NOT `$JS_Check/output_*__ret = true()`.

**3. Empty-string vs null.**
OIC's XPath sometimes treats absent fields as null, sometimes as empty string. JS receives both as `null` or `undefined`. Always normalize at the top of the function: `var s = String(value == null ? '' : value);`.

**4. Activity output names are case-sensitive.**
`$JS_Compute/output_dkcas_doThing__ret` — the function name in the path is exactly the JS function name. Double-check spelling.

**5. Forgetting to map all declared parameters.**
If the JS function takes three parameters, the activity must map all three. Missing parameters become `undefined` in JS, which usually breaks the function silently.

**6. JSON sample with empty arrays.**
When configuring a Sample JSON Document for Stage File, empty arrays infer as `array<any>` and downstream code can't address element fields. Always have at least one populated element in the sample.

## A complete worked example — payload-in-JS (the default)

Scenario: receive an HTML-entity-encoded XML payload, parse it, run the business logic, return a structured result.

```
Step 1: REST Trigger receives the inbound XML payload.

Step 2: Call JavaScript Function — myproject_processRequest
  Input parameter: xmlPayload = getContentAsString($request)

  Inside the function (single file, single responsibility):
    1. Decode HTML/XML entities (testxtoj-style regex helper).
    2. Parse the XML to a JS object representing payments + allocations.
    3. Run business logic: validate, decide, transform, accumulate.
    4. Build the result object.
    5. Return JSON.stringify(result).

  Output: $JS_Process/output_myproject_processRequest__ret  (a JSON string)

Step 3: Stage File — Read Entire File
  File Reference: decodeBase64ToReference(encodeBase64(
    $JS_Process/output_myproject_processRequest__ret
  ))
  Configure File Contents: Sample JSON Document
    (paste a sample matching the JS function's output shape)
  Output: $StageFile/Root  (typed: matches the JS return shape)

Step 4: Map activity from $StageFile/Root to the REST trigger response.
```

Four OIC activities total. All business logic lives in one JS function that can be linted, Nashorn-tested, and version-controlled independently. The orchestration is thin and unlikely to need future changes.

## When the orchestration grows (and when it doesn't have to)

The DigiKey cash app *originally* ran to ~40 steps for three cited reasons. The rebuild re-examined each:

- **Per-iteration activity-stream visibility.** Originally cited as needing scalar-only across the board. In practice only the external SOAP `createApplyReceipt` calls needed to iterate visibly — and they still do, inside a single apply For-Each. Everything else (parsing, matching, verdicts, enrichment, roll-up) moved into JS. Visibility was preserved without scalar-only.
- **Fan-out into ~5 verdict branches.** Moved into JS as `statusCode` strings on each allocation. OIC no longer branches at all.
- **Some operations are inherently OIC activities** (the SOAP invokes, BIP runReport). True — but in the rebuild these are the *only* OIC activities of substance; the glue around them did not have to stay in OIC.

Net result: ~40 steps → ~13 linear activities, one For-Each, the logic in five testable JS functions. The lesson: before accepting a step-heavy scalar-only design, isolate exactly what must iterate visibly (usually just external calls) and push everything else into JS. See `references/payload-in-js-orchestration.md` for the full shape.
