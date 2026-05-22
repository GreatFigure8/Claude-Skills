# Payload-in-JS Orchestration (the proven thin shape)

This is the reference implementation of the payload-in-JS default. It documents the shape the DigiKey cash application was **rebuilt into** — migrating away from the original 40-step scalar-only design (see history note at the bottom). If you're building a new Fusion integration, start here, not from `orchestration-patterns.md` (which documents the scalar-only exception path).

## The shape in one picture

A multi-payment, multi-allocation cash application — arguably a "hard" integration — collapses to ~13 linear OIC activities with **one** For-Each, **zero** routers/Switches, **two** Stitches, and **one** scope variable. All decision logic lives in five JavaScript functions. OIC is thin glue.

```
 0. REST trigger receives the remittance payload (JSON → typed XML)
 1. Call JS: planInvoiceLookup(getContentAsString($trigger))   → JSON: invoicesQ + plan
 2. Stage File: read planA                                      → typed
 3. Invoke REST GetInvoices  (q = $planA/invoicesQ)             → invoice rows
 4. Call JS: planReceiptsLookup($planA, GetInvoices xml)        → JSON: receiptsQ + enriched plan
 5. Stage File: read planB                                      → typed
 6. Invoke REST ListReceipts (q = $planB/receiptsQ)             → receipt rows
 7. Call JS: buildAppliesAndSkeleton($planB, ListReceipts xml)  → JSON: appliesToExecute + response skeleton
 8. Stage File: read workingState                               → typed
 9. Init scope var $skeletonState := workingState skeleton string
10. For-Each over $workingState/appliesToExecute as $applyItem:
      10.1 Map SOAP createApplyReceipt request from $applyItem
      10.2 Invoke SOAP createApplyReceipt
      10.3 Call JS: recordApplyResult($skeletonState, soap xml, ...)
      10.4 Stitch assign $skeletonState := recordApplyResult ret
    ── END For-Each ──
11. Call JS: finalizePaymentStatus($skeletonState)             → final response JSON   ← OUTSIDE the loop
12. Stage File: read finalResponse                             → typed
13. Map $finalResponse/payments → REST trigger response
```

Five JS functions: `planInvoiceLookup`, `planReceiptsLookup`, `buildAppliesAndSkeleton`, `recordApplyResult`, `finalizePaymentStatus`. The first three each return a JSON string consumed via a Stage File round trip. `recordApplyResult` runs per loop iteration and mutates a running skeleton string. `finalizePaymentStatus` runs once at the end.

## Why this beats the scalar-only shape

- **One For-Each, not nested loops.** Invoice lookup and receipt lookup are batched: a single GetInvoices call with `TransactionNumber in (...)` fetches every invoice; a single ListReceipts call fetches every candidate receipt. The only loop left is the apply loop, because each SOAP `createApplyReceipt` is inherently one external call.
- **No manual counters.** Each apply item carries a `_backref: { paymentIdx, allocIdx }` that JS encoded during `buildAppliesAndSkeleton`. `recordApplyResult` uses those numbers to find and mutate the right allocation in the skeleton. OIC never computes a position.
- **No routers/Switches.** All verdict branching (invoice-not-found, no-balance, no-receipt-match, customer-not-found) is decided in JS and recorded as a `statusCode` string on each allocation. OIC doesn't branch.
- **Per-iteration visibility is preserved.** The apply For-Each still shows each SOAP call in the activity stream — so the original reason cited for choosing scalar-only ("ops needs per-allocation visibility") did not actually require scalar-only. The applies are the only thing ops needs to see iterate, and they still do.

## The loop boundary rule (finalize runs ONCE, outside the loop)

`finalizePaymentStatus` computes each payment's roll-up `statusCode` and `infoFlags` from the applied/failed counts **across all its allocations**. That is only correct after every allocation has been processed. Therefore:

- Activities 10.1–10.4 are INSIDE the For-Each, repeating per `applyItem`.
- `finalizePaymentStatus` (Step 11) is a SIBLING of the For-Each, AFTER it closes — at the main flow scope, run exactly once.

Placing finalize inside the loop would recompute payment status off partially-applied data on every iteration. In the OIC canvas, drop it *below* the For-Each container, not inside it. This is the single most common structural misread of the design.

## Map from the FINAL variable, not the working one

`statusCode`, `receipt_number`, and `faultDetail` are only final after `finalizePaymentStatus` runs. The Step 13 response map MUST read `$finalResponse` (the Step 12 stage-file output). If the variable picker defaults back to `$workingState` (the Step 8 output, before the apply loop), every appliable allocation still reads `statusCode: "pending"` with empty `faultDetail` — stale, with no result info. Always confirm the response map's source variable.

## Enrichment happens in JS, carried by a 1:1 drag

Per-allocation `businessUnit` and `invoiceCustomer` are NOT wired in the OIC mapper from the GetInvoices response. They're populated inside `buildAppliesAndSkeleton`, which has the matched invoice row in scope (it attached it during `planReceiptsLookup` as `alloc.invoice`). The function copies `invoice.BusinessUnit → businessUnit` and `invoice.BillToCustomerNumber → invoiceCustomer` onto each skeleton allocation. By Step 13 they're already in `$finalResponse`, and the one-to-one `payments` drag carries them through.

Rule: **populated whenever the invoice was found** (including a zero-balance `allocation-no-remaining-balance` line), **empty only when the invoice wasn't found** (`allocation-invoice-not-found`, `allocation-customer-not-found`). The response schema must declare both fields on each allocation or OIC drops them silently during the drag.

## Two-level result model

The response carries outcome at two granularities; don't conflate them:

| Question | Field | Level |
|----------|-------|-------|
| Disposition of the whole payment? | `payment.statusCode` + `payment.infoFlags` | payment (roll-up) |
| Did this invoice line fail, and why? | `allocation.statusCode` + `allocation.faultDetail` | allocation (detail) |

A payment can be `payment-success` overall while one allocation still carries a non-empty `faultDetail` (e.g. a skipped `allocation-no-remaining-balance` line). `faultDetail` is the per-line drill-down; `payment.statusCode` is the roll-up the caller acts on.

## faultDetail lifecycle (three writers)

`faultDetail` is written by three functions in sequence; each later writer can overwrite the earlier:

1. **`buildAppliesAndSkeleton`** (verdict branch, pre-SOAP) — a skip reason for un-appliable allocations (`"Invoice {n} not found in Fusion."`, `"Invoice has zero or negative remaining balance."`, `"No receipt matched this payment within tolerance."`, etc.), or `""` for allocations headed to the apply loop (`statusCode: "pending"`).
2. **`recordApplyResult`** (per apply iteration, post-SOAP) — `""` on a successful apply, or the `AR-xxxxx` business-fault message on failure.
3. **`finalizePaymentStatus`** (safety net) — any allocation still `"pending"` (its SOAP call never ran) gets `"Apply step did not complete."`

It is empty on success and non-empty only on failure or skip.

## Return-shape discipline

The three planning functions return JSON strings; each needs a Stage File round trip (`decodeBase64ToReference(encodeBase64(...))` — see `interop-patterns.md`). `recordApplyResult` returns the mutated skeleton string, captured back into the `$skeletonState` scope variable via a Stitch assign. `finalizePaymentStatus` returns the final response string for the last Stage File + response map.

Keep the running state in ONE scope variable (`$skeletonState`). The For-Each reads and rewrites it each iteration. This is the only mutable scope variable in the whole integration.

## History — why this replaced the scalar-only design

The cash app originally shipped as ~40 OIC steps (guide v49, lib `cashApplicationLib_v25.js`): nested For-Each loops, ~17 routers, ~19 Stitches, manual counters, halt-guard wrappers, OIC-side enrichment. A production happy-path failure (the apply For-Each's inner conditional scope was empty, so the SOAP invoke never fired) prompted a rebuild rather than a patch. The payload-in-JS redesign (lib v31→v34, guide v50→v57) reduced it to ~13 linear activities. The orchestration is now thin enough to read top-to-bottom and debug without an architecture diagram.

The scalar-only patterns in `orchestration-patterns.md` remain valid for the genuine exception cases (see `interop-patterns.md` for when those apply), but they are no longer the cash app's shape and should not be the starting point for new builds.
