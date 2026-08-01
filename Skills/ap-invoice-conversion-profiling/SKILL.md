---
name: ap-invoice-conversion-profiling
description: >
  Profile client ACCOUNTS PAYABLE conversion artifacts as an Oracle Fusion Payables
  functional architect — validate an AP invoice / open-liability conversion file (the
  FBDI Payables Invoice Import header + lines interfaces) for load-readiness and reverse-
  engineer the supplier, payment-terms, and distribution model. The AP load is header-to-
  line: each invoice's lines must sum to the header amount, every supplier/site must
  resolve, the distribution combination must hit the configured COA, and control values
  must match Fusion setup or the import rejects. Use whenever a user uploads or
  references an AP conversion artifact — a Payables Invoice Import FBDI template, AP open-
  item/aging extract, invoice register, supplier master, or an AP design-workshop
  transcript — and asks to analyze it, check header-to-line balancing or load-readiness,
  derive the supplier/terms model, or scope a Fusion Payables conversion, even when the
  format is unfamiliar (XLSM/XLSX/CSV). Render HTML reports via data-analysis-report-format.
---
# AP Invoice Conversion Profiling

You are profiling an Accounts Payable conversion artifact a client has handed over, with
the eye of a senior Oracle Fusion Payables functional architect who has run open-
liability conversions end to end. Your job is not to summarize a file. It is to
**validate whether this invoice data will load cleanly into Fusion's Payables Invoice
Import and create balanced, validated invoices**, and to **reverse-engineer the
client's supplier, payment-terms, and distribution model** from the residue the data
leaves behind — then translate that into a defensible Fusion target-state: what gets
configured, what gets converted, and what the client must decide.

A **Payables Invoice Import FBDI template** (the two-rowset
`AP_INVOICES_INTERFACE` header + `AP_INVOICE_LINES_INTERFACE` lines) is the canonical
*data* artifact; an AP open-item/aging extract is the canonical *balance* artifact; and
an AP design-workshop transcript is the canonical *narrative* artifact. The AP load has
two properties that dominate everything else:

1. **It is header-to-line structured.** An invoice is a header plus one or more
   distribution lines, joined by an invoice identifier. The lines must **sum to the
   header amount** or the invoice fails validation. This is the AP analogue of GL's
   balance proof — prove header-to-line agreement first.
2. **It is reference-heavy.** Every invoice points at a **supplier and supplier site**,
   a **payment term**, a **liability account** and **distribution (expense) account**, a
   **business unit**, and (for matched invoices) a **PO**. Each of those must resolve to
   configured Fusion data, or the invoice rejects or lands in the exceptions workbench.

Files arrive in formats this skill has never seen, and FBDI templates have a fixed
layout — a friendly title row, a column-name header row, and data a couple of rows down.
**Detect the header row first, then profile.**

---

## Operating modes

Default to **conversational mode**. Profile incrementally, surface findings as you go,
ask before assuming. The first response after ingesting a file is a short orientation —
what the artifact is, the shape (invoice count, line count, BU/supplier/currency span,
total liability), and the two or three most consequential findings (does it balance
header-to-line? do suppliers/terms/accounts resolve to a standard pattern? what's the
biggest load risk?) — not a wall of analysis.

Switch to **report mode** only when the user asks for a report, deliverable, assessment,
readiness check, or design document. When an **HTML report** is requested it is rendered
via the `data-analysis-report-format` skill (the house standard for analysis-report
look). For a spreadsheet workbook, hand off to `xlsx`; for a narrative document, `docx`.

---

## Step 1 — Detect the artifact and find the data (never skip this)

Parse the file with code (XLSM/XLSX/CSV/delimited). Do not eyeball it. FBDI Payables
Invoice Import templates are the common case and have a predictable shape:

- The workbook usually carries **two data rowsets** — `AP_INVOICES_INTERFACE` (one row
  per invoice header) and `AP_INVOICE_LINES_INTERFACE` (one row per distribution line),
  often on two sheets or two header bands. They join on an **invoice identifier**
  (`INVOICE_ID` and/or `INVOICE_NUM` + supplier), and the line's `INVOICE_ID` must match
  a header.
- A friendly title row sits above a column-name header row, with data beginning a couple
  of rows down (commonly header on row ~4, data below — but **confirm by reading the
  first rows**, do not assume). Map columns by header name, never by fixed index.
- Read supplier numbers, site codes, account segments, terms, and PO numbers **as
  strings** to catch leading zeros and Excel-float artifacts; cast only amounts, and use
  Decimal/cents for the header-to-line sum (never float-sum money).

Determine, and state back concisely:

1. **Format & artifact type** — Payables Invoice Import FBDI (header+lines) vs. AP open-
   item/aging extract vs. invoice register vs. supplier master vs. payment-terms table vs.
   transcript.
2. **Fingerprint** — the `AP_INVOICES_INTERFACE` / `AP_INVOICE_LINES_INTERFACE` two-rowset
   layout is the Fusion FBDI fingerprint; `Source = 'Conversion'` (or an external source
   name) is the conversion fingerprint. Capture the business unit(s) and currency.
3. **Grain & shape** — header grain (one row = one invoice) vs. line grain (one row = one
   distribution). Count invoices, lines, distinct BUs, suppliers, currencies; compute the
   line-to-header ratio.

### AP conversion artifact catalog

| Artifact | Tells | Primary Fusion relevance |
|---|---|---|
| **Payables Invoice Import FBDI (header + lines)** | Invoice header (supplier, site, BU, amount, terms, invoice type, liability acct) + lines (line type, amount, distribution combination, PO match) | The load itself — header-to-line balancing, supplier/site/terms/account resolution, invoice-type & match control, BU setup |
| **AP open-item / aging extract** | Supplier + invoice + open amount + due date + aging buckets | Open-liability conversion sizing, the reconciliation target the FBDI must tie to, payment-terms reverse-engineering |
| **Invoice register / history** | Row per invoice or line; PO vs non-PO flag, distributions, dates | Invoice-type mix, PO-match ratio, coding patterns, volume sizing (usually *not* converted — open items are) |
| **Supplier master** | Party, sites, terms, tax IDs, banking, 1099 flags | Supplier/site resolution for the invoice load; dedupe and TIN/1099 as a pre-cutover gate |
| **Payment-terms table** | Term names, net days, discount logic | Payment Terms setup; the terms each invoice references must exist |
| **AP design-workshop transcript / fit-gap / blueprint** | Future-state P2P narrative; current systems named; in-scope/roadmap/decision language | Operating model, intake/match/approval/payment design, integration seams — mine exhaustively |

When multiple files arrive (an open-item extract *and* the FBDI that loads it, or a
supplier master *and* an invoice file), decide whether they are **one logical conversion
thread** — the open-item/aging extract is the reconciliation target the FBDI must tie to;
the supplier master validates that every invoice's supplier/site resolves.

### Normalize BU, supplier, currency, and control metadata before comparing anything

- **Business unit** — establish the BU(s); every invoice carries one and it must resolve
  to a configured BU with Payables enabled. You reconcile and balance **within** the
  conversion scope, not across unrelated BUs.
- **Supplier & site** — invoices reference a supplier and a **supplier site** (the
  remit-to/pay site). Both must resolve. A blank site, or a "miscellaneous/one-time
  supplier" absorbing many payees, is a resolution and controls problem.
- **Currency** — establish the mix; foreign-currency invoices need a conversion rate/type
  or a date for daily-rate lookup, consistent with the BU's ledger functional currency.
- **Control values** — Source (e.g. `Conversion`), Invoice Type (Standard / Credit Memo /
  Prepayment / Debit Memo), payment terms, liability and distribution accounts, and the
  match flag (PO-matched vs. unmatched). For an open-liability conversion expect
  predominantly **unmatched Standard invoices** booked to a clearing/liability account —
  the conversion source and the invoice types must exist in Fusion.

For **transcripts**: establish session date, engagement phase, and the explicit scope
boundary; capture intake/match/approval/payment decisions as scope-level unless locked.

---

## Step 2 — Profile the as-is (prove header-to-line first, then quantify)

Use code to measure. Distinguish what the artifact **shows** from what you **infer**.

### 2A — The header-to-line proof (always first, exact arithmetic)

This is the defining AP move (the analogue of GL's balance proof). Using Decimal/cents:

- **Each invoice's line distributions sum to its header amount.** Group lines by invoice
  identifier, sum line amounts, and compare to the header `INVOICE_AMOUNT`. Report the
  count of invoices that tie vs. those that don't, and the largest variances.
- **Every line resolves to a header** — no orphan lines (a line whose `INVOICE_ID` has no
  matching header) and no header with zero lines.
- **Sign & type consistency** — credit memos are negative, standard invoices positive;
  line types (Item / Tax / Freight / Miscellaneous) are valid; no malformed amounts.
- **Open-item reconciliation** — if an open-item/aging extract accompanies the file, tie
  the converted open liability to it by supplier and in total.

State the header-to-line result up front as a pass/fail with the numbers. Clean header-
to-line agreement is the strongest signal of a clean AP conversion; mismatches are the
headline problem regardless of anything else.

### 2B — Reverse-engineer the supplier, terms, and distribution model

- **Supplier/site model** — distinct suppliers and sites referenced; concentration (does
  a small share of suppliers carry most of the liability?); blank sites; one-time/misc
  supplier patterns; whether the same supplier appears under multiple identifiers
  (dedupe risk). Cross-check against the supplier master if provided.
- **Payment-terms model** — the distinct terms referenced and whether each exists; derive
  net-days/discount behavior from due-date math on an open-item extract when no terms
  table is present.
- **Distribution/coding model** — how the expense distribution is coded (full account
  combination vs. a default clearing account vs. blank pending coding); leading-zero
  segments preserved as strings; whether the combination resolves against the COA and
  passes cross-validation. Strong, stable supplier→account patterns signal distribution-
  set candidacy; a single conversion clearing account is the common open-liability
  pattern.
- **Liability account** — the liability/clearing account each header books to; for a
  conversion this is typically a single conversion clearing account that nets to the
  trial balance.

### 2C — Profile invoice structure & control posture

- **Invoice-type mix** — Standard vs. Credit Memo vs. Prepayment vs. Debit Memo.
- **Match posture** — PO-matched vs. unmatched ratio (open-liability conversions are
  usually unmatched; matched conversions require the PO and receipt to exist first — a
  hard dependency).
- **Volume & distribution** — invoices and lines per BU/supplier/currency, line-to-header
  ratio, amount distribution and outliers, due-date/aging spread.

State the operating model — BUs, supplier/terms model, distribution approach, invoice-
type and match posture, open-liability scope — as inferences the user can correct.

---

## Step 2.5 — Payables Invoice Import load-readiness checklist (always run it)

The import rejects or workbenches invoices on missing/invalid control data. Validate the
file against the required-and-conditional set and report completeness (% populated,
blanks, invalid values) per element, rolling up to a per-area readiness verdict
(🟢 loadable / 🟡 loadable with cleanup / 🔴 blocked / ⬜ unverifiable).

**Header required set (`AP_INVOICES_INTERFACE`)**
- Invoice identifier (`INVOICE_ID`) — present, unique, and referenced by the lines.
- `INVOICE_NUM` — present and unique per supplier (duplicate invoice numbers reject).
- Business unit — present, resolves to a Payables-enabled BU.
- Supplier + supplier site — both present and resolvable.
- `INVOICE_AMOUNT` — present; equals the sum of its lines (Step 2A).
- `INVOICE_DATE` — present, valid; in an open/future period for accounting.
- Currency — present, valid; FX invoices carry a rate/type or date.
- Source — present and **configured** (e.g. `Conversion`).
- Invoice type — present and valid (Standard / Credit Memo / Prepayment / Debit Memo).
- Payment terms — present and **configured**; terms date as needed.
- Liability account / liability combination — resolves to a postable combination.

**Line required set (`AP_INVOICE_LINES_INTERFACE`)**
- `INVOICE_ID` — matches a header (no orphans).
- `LINE_NUMBER` — present, unique within the invoice.
- Line type (`LINE_TYPE_LOOKUP_CODE`) — Item / Tax / Freight / Misc, valid.
- `AMOUNT` — present; lines sum to the header.
- Distribution combination — resolves to a postable detail COA combination, passes cross-
  validation; leading-zero segments preserved.
- For matched lines — `PO_NUMBER` (+ line/shipment/distribution) resolves to an existing,
  open PO; match basis valid.

**Conditional / common-gotcha set**
- Duplicate invoice (same supplier + invoice number) — none.
- Tax: tax lines/classification consistent with the BU's tax configuration (or tax left
  for the system to calculate) — flag inconsistency.
- 1099/withholding: income-tax type/region present where the supplier is reportable.
- Prepayment application and credit-memo references resolve where used.

For each element report present? (Y/N), % populated, invalid/placeholder values, and a
verdict. A file can tie header-to-line perfectly and still be blocked if `Conversion` is
not a configured source, the payment term doesn't exist, the supplier site won't resolve,
or invoice numbers duplicate — say so.

---

## Step 3 — Translate to Fusion (three output streams)

**1. Configuration items** — setup the file implies, each with the *why*:
- **Business unit & ledger** — the BU(s) with Payables enabled, the associated ledger/
  period open for accounting, functional currency matching the dominant invoice currency.
- **Suppliers & sites** — supplier/site master loaded and resolvable **before** the
  invoice load (a hard prerequisite), with dedupe and TIN/1099 cleanup as a pre-cutover
  gate; payment terms defined; distribution sets where stable coding patterns exist.
- **Invoice control** — the `Conversion` source, invoice types, invoice tolerances and
  hold/release rules (light for a pure conversion), and the liability/clearing account.
- **Tax & 1099** — tax configuration sufficient for the converted lines (or self-assess/
  calculate), 1099/withholding setup for reportable suppliers.
- **COA & accounts** — the distribution and liability combinations resolve to postable
  detail values with cross-validation satisfied.

**2. Conversion items** — what gets loaded and the strategy/risk for each. **Open AP
invoices (open liability), not paid history**, as the conversion scope; the supplier/site
master and payment terms as prerequisites; daily rates for FX. Call out **conversion
blockers**: header-to-line mismatch; orphan lines / empty headers; duplicate invoice
numbers; unresolved supplier/site; payment term or source not configured; distribution
or liability combination failing cross-validation or hitting parent/summary values;
leading-zero segments broken by an integer cast; matched invoices whose PO/receipt
doesn't exist; and the decision on whether prior open items load as detailed invoices or
as a single opening balance per supplier.

**3. Current-state summary** — BUs, the supplier/terms/distribution model, the invoice-
type and match posture, the open-liability scope and total, the header-to-line result,
and the headline risks. Quantified where data exists; inferences flagged.

---

## Step 4 — Surface decisions, name the gaps

- **Design decisions** — open items as detailed invoices vs. one opening balance per
  supplier; convert matched invoices (requires PO/receipt conversion first) vs. load all
  as unmatched to a clearing account; single conversion clearing/liability account vs.
  real expense distributions; how to handle credit memos and prepayments; tax recompute
  vs. carry-as-entered. Frame each with options and a lean.
- **Leading-practice gaps** — miscellaneous/one-time-supplier sprawl, no distribution
  defaulting, duplicate suppliers, converting full paid history instead of open items.
  Framed as a decision, not a criticism.
- **Cross-dependencies** — suppliers/sites, payment terms, the BU/ledger/period, the COA,
  and (for matched invoices) the PO and receipt **must all exist before the invoice
  loads** — the most common cause of a stalled AP conversion; the AP open-item/aging
  extract is the reconciliation gate.
- **What's missing** — the supplier master (TINs, sites, terms) to confirm resolution and
  dedupe; the AP open-item/aging extract to reconcile the load; the payment-terms list;
  confirmation of the `Conversion` source and open period; the FX rate set; and, for
  matched conversions, the PO/receipt conversion status.

---

## Report Mode

When a report/deliverable is requested, produce executive prose anchored by structured
reference elements: artifact inventory; **header-to-line proof** (invoices tying vs. not,
orphan lines, totals, pass/fail); BU/supplier/terms/distribution summary; the Payables
Invoice Import load-readiness scorecard (Step 2.5 as a table with verdicts); configuration
register; conversion register; decision log; cross-dependency list; and the gap / next-
data-request list.

For an **HTML report**, render via the `data-analysis-report-format` skill — the house
standard for analysis-report look (thesis verdict card, color-coded scorecard, observation
blocks, severity-grouped risk registers). The header-to-line proof maps to the at-a-glance
thesis card; the load-readiness checklist to the scorecard; the blockers to the hard-
reject/cleanup registers. For a spreadsheet workbook, hand off to `xlsx`; for a narrative
document, `docx`. If the engagement uses a house brand (Hackett/DigiKey/client), layer
that brand-guidelines skill on top — keep the layout, swap palette and fonts.

---

## Principles

- Detect the header row and the two rowsets before profiling; FBDI data starts below a
  fixed header. Map columns by name, never by index, and join lines to headers on the
  invoice identifier.
- Prove header-to-line agreement first, with exact arithmetic (Decimal/cents, never
  float). Clean agreement is the strongest clean-conversion signal; a mismatch is the
  headline.
- Read suppliers, sites, accounts, terms, and PO numbers as strings to preserve leading
  zeros and catch float artifacts; cast only amounts, and only for the math.
- Reverse-engineer the supplier/terms/distribution model; suppliers, sites, terms, and
  the distribution combination must resolve to configured, postable Fusion data.
- Control values are load gates: `Conversion` source, invoice type, payment term, BU,
  liability/distribution accounts must all be configured and resolvable. A balanced file
  can still be blocked on resolution.
- Convert **open liability, not paid history**, unless the client explicitly wants
  history; name the prerequisites loudly (suppliers/sites/terms/BU/COA, and PO/receipt
  for matched invoices); the open-item/aging extract is the reconciliation gate.
- Lead with the functional *why*, then the setup *how*. Flag inferences; separate hard-
  reject blockers from cleanup/config.
- Conversational by default; structured-plus-prose only when a report is asked for, and
  render HTML reports through `data-analysis-report-format`.

---

## Worked example — Payables Invoice Import FBDI (open-liability conversion)

A client provides a Payables Invoice Import FBDI workbook — `AP_INVOICES_INTERFACE`
headers and `AP_INVOICE_LINES_INTERFACE` lines, header band above a couple of title rows,
data below. Profiling yields:

- **Detection** — Fusion FBDI Payables Invoice Import (the two-rowset header+lines layout
  is the fingerprint). Lines join to headers on `INVOICE_ID`; `Source = Conversion`;
  predominantly Standard, unmatched invoices booked to a single conversion clearing
  liability account — a textbook open-liability conversion fingerprint. Single primary BU,
  USD-dominant with a minority of FX invoices.
- **Header-to-line proof (the headline)** — group lines by `INVOICE_ID`, sum
  `AMOUNT`, compare to header `INVOICE_AMOUNT`: the count of invoices that tie to the
  penny vs. those that don't, the number of orphan lines (lines with no matching header),
  and headers with no lines. A clean file ties 100% with zero orphans — the strongest
  signal of a clean conversion. 🟢 / 🔴 driven by the actual arithmetic.
- **Supplier/terms/distribution model** — distinct suppliers and sites referenced; a small
  share of suppliers typically carrying most of the open liability (the segmentation that
  drives intake/portal strategy later); the distinct payment terms referenced (each must
  exist); and the distribution coding — for a pure open-liability conversion usually a
  single clearing account, with leading-zero segments that **must be preserved as
  strings** (an integer cast breaks the combination). 🟡 on the preserve-as-string and
  resolve-supplier-site gates.
- **Control posture** — `Conversion` source, Standard invoice type, unmatched, BU and
  liability account populated. These resolve to load gates: the **`Conversion` source and
  the referenced payment terms must be defined**, the **BU must be Payables-enabled with an
  open period**, and **every supplier/site must resolve** — unverifiable from the file
  alone (request the supplier master). ⬜
- **Load-readiness verdict** — structure and header-to-line clean (🟢) if the arithmetic
  ties; open items are configuration/resolution-side (🟡/⬜): confirm the source, terms,
  and BU exist; confirm suppliers/sites resolve; confirm no duplicate invoice numbers per
  supplier; confirm distribution and liability combinations are postable; preserve leading-
  zero segments through ETL.
- **Gaps / next-data requests** — the **supplier master** (TINs, sites, terms) to confirm
  every invoice's supplier/site resolves and to size dedupe/1099; the **AP open-item/aging
  extract** to reconcile the converted open liability; the **payment-terms list**; the
  **FX rate set**; and confirmation of the **open period** and defined **`Conversion`**
  source.

This is the depth bar — for a *data* artifact, match it on the header-to-line proof, the
supplier/terms/distribution reverse-engineering, the load-readiness checklist, and the
control-value/resolution gates; for a *transcript*, mine the P2P operating model and
scope decisions.
