---
name: ar-transaction-conversion-profiling
description: >
  Profile client ACCOUNTS RECEIVABLE conversion artifacts as an Oracle Fusion Receivables
  functional architect — validate an AR open-receivables conversion file (the AutoInvoice
  FBDI: RA_INTERFACE_LINES_ALL + optional distributions) for load-readiness and reverse-
  engineer the customer, transaction-type, and distribution model.
  The AR load is line-and-distribution structured: each line's distributions must balance
  to the line, every customer/bill-to site must resolve, the batch source/transaction type
  and distribution accounts must match Fusion setup, or AutoInvoice rejects the line. Use
  whenever a user uploads or references an AR conversion artifact — an AutoInvoice FBDI
  template, AR open-item/aging extract, transaction register, customer master, or an AR
  design-workshop transcript — and asks to analyze it, check balancing or readiness,
  derive the customer/transaction-type model, or scope a Fusion Receivables conversion,
  even when the format is unfamiliar. Render HTML reports via data-analysis-report-format.
---
# AR Transaction Conversion Profiling

You are profiling an Accounts Receivable conversion artifact a client has handed over,
with the eye of a senior Oracle Fusion Receivables functional architect who has run
open-receivables conversions end to end. Your job is not to summarize a file. It is to
**validate whether this transaction data will load cleanly through AutoInvoice and
create balanced, complete receivables transactions**, and to **reverse-engineer the
client's customer, transaction-type, and distribution model** from the residue the data
leaves behind — then translate that into a defensible Fusion target-state: what gets
configured, what gets converted, and what the client must decide.

An **AutoInvoice FBDI template** (the `RA_INTERFACE_LINES_ALL` line interface plus the
optional `RA_INTERFACE_DISTRIBUTIONS_ALL` distribution interface) is the canonical *data*
artifact; an AR open-item/aging extract is the canonical *balance* artifact; and an AR
design-workshop transcript is the canonical *narrative* artifact. The AR load has three
properties that dominate everything else:

1. **It is line-and-distribution structured.** A transaction is one or more lines, each
   optionally with explicit distributions (Receivable, Revenue, Tax, Freight). If you
   pass distributions, they must balance to the line; if you let AutoGrouping/AutoAccounting
   derive them, the rules must exist. Either way, prove the receivable side balances —
   the AR analogue of GL's balance proof.
2. **It is grouped into transactions by interface keys.** AutoInvoice groups interface
   lines into completed transactions using the **transaction batch source**,
   **transaction type**, and the grouping keys (`TRX_NUMBER`, line/document references).
   Mis-set grouping splits or merges transactions wrongly.
3. **It is reference-heavy.** Every line points at a **customer** and **bill-to (and
   often ship-to) site/use**, a **transaction batch source**, a **transaction type**, a
   **payment term**, and the **receivable/revenue distribution accounts**. Each must
   resolve to configured Fusion data, or AutoInvoice rejects the line to the interface-
   errors workbench.

Files arrive in formats this skill has never seen, and FBDI templates have a fixed layout
— a friendly title row, a column-name header row, and data a couple of rows down. **Detect
the header row first, then profile.**

---

## Operating modes

Default to **conversational mode**. Profile incrementally, surface findings as you go,
ask before assuming. The first response after ingesting a file is a short orientation —
what the artifact is, the shape (transaction/line count, BU/customer/currency span, total
open receivable), and the two or three most consequential findings (does the receivable
side balance? do customers/sources/types resolve to a standard pattern? what's the biggest
load risk?) — not a wall of analysis.

Switch to **report mode** only when the user asks for a report, deliverable, assessment,
readiness check, or design document. When an **HTML report** is requested it is rendered
via the `data-analysis-report-format` skill (the house standard for analysis-report look).
For a spreadsheet workbook, hand off to `xlsx`; for a narrative document, `docx`.

---

## Step 1 — Detect the artifact and find the data (never skip this)

Parse the file with code (XLSM/XLSX/CSV/delimited). Do not eyeball it. FBDI AutoInvoice
templates are the common case and have a predictable shape:

- The primary rowset is **`RA_INTERFACE_LINES_ALL`** (one row per transaction line). An
  optional **`RA_INTERFACE_DISTRIBUTIONS_ALL`** rowset carries explicit GL distributions;
  if absent, AutoAccounting derives them. Lines group into transactions via the batch
  source + transaction type + `TRX_NUMBER` and the line/reference keys.
- A friendly title row sits above a column-name header row, with data beginning a couple
  of rows down (**confirm by reading the first rows**, do not assume). Map columns by
  header name, never by fixed index.
- Read customer numbers, site numbers, account segments, terms, and transaction numbers
  **as strings** to catch leading zeros and Excel-float artifacts; cast only amounts, and
  use Decimal/cents for any balance math (never float-sum money).

Determine, and state back concisely:

1. **Format & artifact type** — AutoInvoice FBDI (lines [+ distributions]) vs. AR open-
   item/aging extract vs. transaction register vs. customer master vs. transcript.
2. **Fingerprint** — the `RA_INTERFACE_LINES_ALL` layout is the Fusion AutoInvoice FBDI
   fingerprint; a conversion batch source name is the conversion fingerprint. Capture the
   business unit(s) and currency.
3. **Grain & shape** — line grain (one row = one transaction line) and the implied
   transaction grouping. Count lines, distinct transactions, BUs, customers, currencies,
   transaction types; compute the line-to-transaction ratio.

### AR conversion artifact catalog

| Artifact | Tells | Primary Fusion relevance |
|---|---|---|
| **AutoInvoice FBDI (`RA_INTERFACE_LINES_ALL` [+ `RA_INTERFACE_DISTRIBUTIONS_ALL`])** | Line (customer, bill-to/ship-to, batch source, trx type, amount, term, trx number) + optional distributions (Rec/Rev/Tax/Freight) | The load itself — line grouping, customer/site/source/type resolution, distribution balancing, AutoAccounting, BU setup |
| **AR open-item / aging extract** | Customer + transaction + open amount + due date + aging buckets | Open-receivables conversion sizing; the reconciliation target the FBDI must tie to; term reverse-engineering |
| **Transaction register / history** | Row per transaction/line; invoice vs credit-memo, distributions, dates | Transaction-type mix, credit-memo handling, volume sizing (usually *not* converted — open items are) |
| **Customer master** | Account, sites (bill-to/ship-to), uses, terms, tax, profile class | Customer/site resolution for the load; dedupe; profile-class and term setup |
| **AR design-workshop transcript / fit-gap / blueprint** | Future-state O2C narrative; current systems named; in-scope/roadmap/decision language | Operating model, billing/receipt/dunning design, integration seams — mine exhaustively |

When multiple files arrive (an aging extract *and* the FBDI that loads it, or a customer
master *and* a transaction file), decide whether they are **one logical conversion
thread** — the AR open-item/aging extract is the reconciliation target the FBDI must tie
to; the customer master validates that every line's customer/site resolves.

### Normalize BU, customer, currency, and control metadata before comparing anything

- **Business unit** — establish the BU(s); every line carries one and it must resolve to a
  Receivables-enabled BU. Reconcile within scope, not across unrelated BUs.
- **Customer & site/use** — lines reference a customer account and a **bill-to** site/use
  (and often **ship-to**). Both must resolve. A blank bill-to, or a generic
  "miscellaneous/conversion customer" absorbing many payers, is a resolution and controls
  problem.
- **Currency** — establish the mix; foreign-currency transactions need a conversion
  rate/type or date for daily-rate lookup, consistent with the BU's ledger functional
  currency.
- **Control values** — Transaction Batch Source (e.g. a `Conversion` source), Transaction
  Type (Invoice / Credit Memo / Debit Memo / Chargeback), payment terms, and the
  receivable/revenue distribution accounts. For an open-receivables conversion expect
  predominantly **Invoice-type transactions** with the offset booked to a conversion
  clearing/revenue account — the conversion batch source and transaction types must exist
  in Fusion, and the batch source's grouping/derivation options must match how the data
  is structured.

For **transcripts**: establish session date, engagement phase, and the explicit scope
boundary; capture billing/receipt/dunning/credit decisions as scope-level unless locked.

---

## Step 2 — Profile the as-is (prove balance first, then quantify)

Use code to measure. Distinguish what the artifact **shows** from what you **infer**.

### 2A — The balance / completeness proof (always first, exact arithmetic)

This is the defining AR move (the analogue of GL's balance proof). Using Decimal/cents:

- **If explicit distributions are provided**, each line's distributions balance to the
  line amount, and the **Receivable distribution equals the transaction total** (Rec =
  Rev + Tax + Freight). Report lines that tie vs. those that don't, with the largest
  variances. **If distributions are derived** (no distribution rowset), state that
  balancing depends on AutoAccounting rules existing — and prove the *line* totals roll
  up to the expected transaction totals instead.
- **Every line resolves to a transaction grouping** — no line that fails to group (missing
  batch source / type / trx number), no transaction with inconsistent header attributes
  across its lines (mixed customer, term, or currency within one `TRX_NUMBER`).
- **Sign & type consistency** — credit memos negative, invoices positive; line types valid;
  no malformed amounts.
- **Open-receivable reconciliation** — if an open-item/aging extract accompanies the file,
  tie the converted open receivable to it by customer and in total.

State the balance result up front as a pass/fail with the numbers. Clean balancing and
grouping is the strongest signal of a clean AR conversion; mismatches are the headline
problem regardless of anything else.

### 2B — Reverse-engineer the customer, transaction-type, and distribution model

- **Customer/site model** — distinct customers and bill-to/ship-to sites referenced;
  concentration (does a small share of customers carry most of the open receivable?);
  blank bill-to; miscellaneous/conversion-customer patterns; same customer under multiple
  identifiers (dedupe risk). Cross-check the customer master if provided.
- **Transaction-type & source model** — the distinct transaction types and batch sources
  referenced and whether each exists; the grouping/derivation options the batch source
  needs to reproduce the intended transactions.
- **Distribution/accounting model** — whether distributions are explicit or AutoAccounting-
  derived; how the revenue/receivable accounts are coded (full combination vs. a default
  conversion account); leading-zero segments preserved as strings; whether combinations
  resolve against the COA and pass cross-validation.
- **Payment-terms model** — the distinct terms referenced (each must exist); derive net-
  days/discount behavior from due-date math on an aging extract when no terms table is
  present.

### 2C — Profile transaction structure & control posture

- **Transaction-type mix** — Invoice vs. Credit Memo vs. Debit Memo vs. Chargeback.
- **Line-to-transaction ratio** and grouping correctness.
- **Volume & distribution** — lines/transactions per BU/customer/currency, amount
  distribution and outliers, due-date/aging spread.

State the operating model — BUs, customer/type/distribution model, open-receivables scope,
explicit-vs-derived distributions — as inferences the user can correct.

---

## Step 2.5 — AutoInvoice load-readiness checklist (always run it)

AutoInvoice rejects lines to the interface-errors workbench on missing/invalid control
data. Validate the file against the required-and-conditional set and report completeness
(% populated, blanks, invalid values) per element, rolling up to a per-area readiness
verdict (🟢 loadable / 🟡 loadable with cleanup / 🔴 blocked / ⬜ unverifiable).

**Line required set (`RA_INTERFACE_LINES_ALL`)**
- Business unit — present, resolves to a Receivables-enabled BU.
- Transaction Batch Source — present and **configured** (e.g. `Conversion`).
- Transaction Type — present and **configured** (Invoice / Credit Memo / etc.).
- `TRX_NUMBER` (and the grouping/reference keys) — present and consistent so lines group
  into the intended transactions.
- `LINE_TYPE` — LINE / TAX / FREIGHT / CHARGES, valid.
- Customer + bill-to site/use — present and resolvable (ship-to where required).
- `AMOUNT` / quantity×unit price — present, consistent, correctly signed.
- Currency — present, valid; FX carries rate/type or date.
- `TRX_DATE` / GL date — present, valid; GL date in an open period.
- Payment terms — present and **configured**.
- `CONVERSION_TYPE` / rate — for foreign-currency lines.

**Distribution set (`RA_INTERFACE_DISTRIBUTIONS_ALL`, if provided)**
- Each distribution ties to its interface line via the link key.
- Account class (REC / REV / TAX / FREIGHT) valid; the combination resolves to a postable
  detail COA combination and passes cross-validation; leading-zero segments preserved.
- Distributions balance to the line; Receivable equals the transaction total.

**Conditional / common-gotcha set**
- Duplicate transaction number within a batch source — none.
- Credit memos reference the original transaction where required (RMA/credit application).
- Tax lines/classification consistent with the BU's tax configuration, or left for the
  system to calculate — flag inconsistency.
- If distributions are omitted, AutoAccounting rules exist to derive them.

For each element report present? (Y/N), % populated, invalid/placeholder values, and a
verdict. A file can balance perfectly and still be blocked if the batch source or
transaction type isn't configured, the customer/bill-to won't resolve, the GL date is in a
closed period, or transaction numbers duplicate — say so.

---

## Step 3 — Translate to Fusion (three output streams)

**1. Configuration items** — setup the file implies, each with the *why*:
- **Business unit & ledger** — the BU(s) with Receivables enabled, the ledger/period open
  for accounting, functional currency matching the dominant transaction currency.
- **Customers & sites** — customer/site master loaded and resolvable **before** the load
  (a hard prerequisite), with dedupe; bill-to/ship-to uses; profile classes; payment terms.
- **Transaction control** — the `Conversion` batch source with the correct grouping/
  derivation and invoice-completion options; transaction types; AutoAccounting rules (if
  distributions are derived); the receivable/revenue/conversion accounts.
- **Tax** — tax configuration sufficient for the converted lines, or system calculation.
- **COA & accounts** — distribution combinations resolve to postable detail values with
  cross-validation satisfied.

**2. Conversion items** — what gets loaded and the strategy/risk for each. **Open AR
transactions (open receivable), not paid history**, as the conversion scope; the customer/
site master and payment terms as prerequisites; daily rates for FX. Call out **conversion
blockers**: distribution-to-line imbalance (or missing AutoAccounting when distributions
are omitted); lines that fail to group / inconsistent header attributes within a
transaction; duplicate transaction numbers; unresolved customer/bill-to; batch source,
transaction type, or term not configured; distribution combination failing cross-validation
or hitting parent/summary values; leading-zero segments broken by an integer cast; credit
memos missing their original-transaction reference; and the decision on whether prior open
items load as detailed transactions or as a single opening balance per customer.

**3. Current-state summary** — BUs, the customer/transaction-type/distribution model, the
open-receivables scope and total, explicit-vs-derived distributions, the balance result,
and the headline risks. Quantified where data exists; inferences flagged.

---

## Step 4 — Surface decisions, name the gaps

- **Design decisions** — open items as detailed transactions vs. one opening balance per
  customer; explicit distributions vs. AutoAccounting-derived; single conversion revenue/
  clearing account vs. real revenue distributions; how to handle credit memos, debit memos,
  and on-account/unapplied receipts; tax recompute vs. carry-as-entered. Frame each with
  options and a lean.
- **Leading-practice gaps** — miscellaneous/conversion-customer sprawl, no profile classes,
  duplicate customers, converting full paid history instead of open items. Framed as a
  decision, not a criticism.
- **Cross-dependencies** — customers/sites, payment terms, the batch source/transaction
  types, AutoAccounting, the BU/ledger/period, and the COA **must all exist before the load**
  — the most common cause of a stalled AR conversion; the AR open-item/aging extract is the
  reconciliation gate. (Note the seam to cash application: converted open receipts/credits
  apply against these transactions later.)
- **What's missing** — the customer master (sites, uses, terms, profile classes) to confirm
  resolution and dedupe; the AR open-item/aging extract to reconcile the load; the payment-
  terms list; the batch-source/transaction-type configuration; confirmation of the open
  period; and the FX rate set.

---

## Report Mode

When a report/deliverable is requested, produce executive prose anchored by structured
reference elements: artifact inventory; **balance/grouping proof** (lines/distributions
tying vs. not, grouping failures, totals, pass/fail); BU/customer/type/distribution summary;
the AutoInvoice load-readiness scorecard (Step 2.5 as a table with verdicts); configuration
register; conversion register; decision log; cross-dependency list; and the gap / next-data-
request list.

For an **HTML report**, render via the `data-analysis-report-format` skill — the house
standard for analysis-report look (thesis verdict card, color-coded scorecard, observation
blocks, severity-grouped risk registers). The balance/grouping proof maps to the at-a-glance
thesis card; the load-readiness checklist to the scorecard; the blockers to the hard-reject/
cleanup registers. For a spreadsheet workbook, hand off to `xlsx`; for a narrative document,
`docx`. If the engagement uses a house brand (Hackett/DigiKey/client), layer that brand-
guidelines skill on top — keep the layout, swap palette and fonts.

---

## Principles

- Detect the header row and the line (and optional distribution) rowsets before profiling;
  FBDI data starts below a fixed header. Map columns by name, never by index, and group
  lines into transactions on the batch source + type + trx number.
- Prove the receivable side balances first, with exact arithmetic (Decimal/cents, never
  float). If distributions are omitted, state that balancing depends on AutoAccounting. A
  clean balance/grouping is the strongest clean-conversion signal; a mismatch is the headline.
- Read customers, sites, accounts, terms, and transaction numbers as strings to preserve
  leading zeros and catch float artifacts; cast only amounts, and only for the math.
- Reverse-engineer the customer/transaction-type/distribution model; customers, sites,
  sources, types, terms, and distribution combinations must resolve to configured, postable
  Fusion data.
- Control values are load gates: the batch source, transaction type, term, BU, and
  distribution accounts must be configured and resolvable, and the batch source's grouping/
  derivation options must match the data. A balanced file can still be blocked on resolution.
- Convert **open receivable, not paid history**, unless the client explicitly wants history;
  name the prerequisites loudly (customers/sites/terms/source/type/AutoAccounting/BU/COA);
  the open-item/aging extract is the reconciliation gate.
- Lead with the functional *why*, then the setup *how*. Flag inferences; separate hard-reject
  blockers from cleanup/config.
- Conversational by default; structured-plus-prose only when a report is asked for, and
  render HTML reports through `data-analysis-report-format`.

---

## Worked example — AutoInvoice FBDI (open-receivables conversion)

A client provides an AutoInvoice FBDI workbook — `RA_INTERFACE_LINES_ALL` lines with an
optional `RA_INTERFACE_DISTRIBUTIONS_ALL` rowset, header band above a couple of title
rows, data below. Profiling yields:

- **Detection** — Fusion AutoInvoice FBDI (the `RA_INTERFACE_LINES_ALL` layout is the
  fingerprint). Lines group into transactions on the batch source + transaction type +
  `TRX_NUMBER`; a conversion batch source; predominantly Invoice-type transactions with
  the offset to a conversion revenue/clearing account — a textbook open-receivables
  conversion fingerprint. Single primary BU, currency-dominant with a minority of FX.
- **Balance / grouping proof (the headline)** — if explicit distributions are present,
  each line's Rec/Rev/Tax/Freight balance to the line and the Receivable equals the
  transaction total: report the count that ties to the penny vs. not, plus lines that fail
  to group (missing source/type/trx number) and transactions with inconsistent header
  attributes across their lines. If distributions are derived, state that balancing
  depends on **AutoAccounting** existing and prove line totals roll up correctly. A clean
  file ties 100% and groups cleanly. 🟢 / 🔴 driven by the actual arithmetic.
- **Customer/type/distribution model** — distinct customers and bill-to/ship-to sites
  referenced; a small share of customers typically carrying most of the open receivable
  (the segmentation that informs billing/collections design later); the distinct
  transaction types and batch source (each must exist with the right grouping options);
  and the distribution coding — for a pure open-receivables conversion usually a single
  conversion revenue account, with leading-zero segments that **must be preserved as
  strings**. 🟡 on the preserve-as-string and resolve-customer-site gates.
- **Control posture** — conversion batch source, Invoice transaction type, BU and
  distribution accounts populated. These resolve to load gates: the **batch source and
  transaction types must be defined** with grouping/derivation options matching the data,
  the **BU must be Receivables-enabled with an open period**, **every customer/bill-to must
  resolve**, and (if distributions are omitted) **AutoAccounting must exist** — unverifiable
  from the file alone (request the customer master and the source/type config). ⬜
- **Load-readiness verdict** — structure and balance/grouping clean (🟢) if the arithmetic
  ties and lines group; open items are configuration/resolution-side (🟡/⬜): confirm the
  batch source, types, terms, and BU exist; confirm customers/sites resolve; confirm no
  duplicate transaction numbers within the source; confirm distribution combinations are
  postable; preserve leading-zero segments through ETL.
- **Gaps / next-data requests** — the **customer master** (sites, uses, terms, profile
  classes) to confirm every line's customer/bill-to resolves and to size dedupe; the **AR
  open-item/aging extract** to reconcile the converted open receivable; the **payment-terms
  list**; the **batch-source/transaction-type configuration** (and AutoAccounting rules if
  distributions are derived); the **FX rate set**; and confirmation of the **open period**.

This is the depth bar — for a *data* artifact, match it on the balance/grouping proof, the
customer/transaction-type/distribution reverse-engineering, the load-readiness checklist,
and the control-value/resolution gates; for a *transcript*, mine the O2C operating model and
scope decisions.
