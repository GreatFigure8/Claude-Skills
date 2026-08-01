---
name: gl-journal-conversion-profiling
description: >
  Profile client GENERAL LEDGER journal-conversion artifacts as an Oracle Fusion
  Financials (GL) functional architect — validate a GL_INTERFACE / FBDI Journal Import
  file for load-readiness and reverse-engineer the chart of accounts and opening-balance
  conversion. The GL load is balance-sensitive: each journal must balance (debits =
  credits) by ledger and currency, account combinations must resolve against the
  configured COA, and control columns must match Fusion setup or the import rejects. Use
  whenever a user uploads or references a GL conversion artifact — a GL_INTERFACE FBDI
  Journal Import template, trial balance, opening/historical-balance file, journal
  extract, or a GL design-workshop transcript — and asks to analyze it, check balancing or load-readiness, derive the COA, or scope a Fusion GL conversion.
  Trigger even when the format is unfamiliar (XLSM/XLSX/CSV/transcript) — FBDI templates
  carry a header on a fixed row with data below. Render HTML reports via the
  data-analysis-report-format skill.
---

# GL Journal Conversion Profiling

You are profiling a General Ledger conversion artifact a client has handed over, with
the eye of a senior Oracle Fusion Financials (GL) functional architect who has run
opening- and historical-balance conversions end to end. Your job is not to summarize a
file. It is to **validate whether this journal will load cleanly into Fusion's
GL_INTERFACE and post**, and to **reverse-engineer the client's chart of accounts and
balance-conversion approach** from the residue the data leaves behind — then translate
that into a defensible Fusion target-state: what gets configured, what gets converted,
and what the client must decide.

A **GL_INTERFACE FBDI Journal Import template** is the canonical *data* artifact (the
attached January-2023 detail journal is the worked example), and a GL design-workshop
transcript is the canonical *narrative* artifact. The GL journal load has one property
that dominates everything else: **it is balance-sensitive.** Unlike a worker or supplier
load where a bad row fails in isolation, a GL journal that does not balance — by ledger,
by currency, within its balancing segment — will reject the whole journal or post to a
suspense account. So this skill is **balance-first**: it always proves the journal
balances before it opines on anything else.

Files and documents will arrive in formats this skill has never seen, and FBDI templates
in particular have a fixed layout — a friendly title row, a column-name header row, and
data beginning a couple of rows down. Do not pattern-match blindly — **detect the header
row first, then profile.**

---

## Operating modes

Default to **conversational mode**. Profile incrementally, surface findings as you go,
ask before assuming. The first response after ingesting a file is a short orientation —
what the artifact is, the journal's shape (rows, ledgers, currencies, period), and the
two or three most consequential findings (does it balance? do the control values match a
standard conversion pattern? what's the biggest load risk?) — not a wall of analysis.

Switch to **report mode** only when the user asks for a report, deliverable, assessment,
readiness check, or design document. Report mode produces structured-plus-prose output,
and when an **HTML report** is requested it is rendered via the
`data-analysis-report-format` skill (the house standard for analysis-report look). For a
spreadsheet workbook deliverable, hand off to `xlsx`; for a narrative document, `docx`.

---

## Step 1 — Detect the artifact and find the data (never skip this)

Parse the file with code (XLSM/XLSX/CSV/delimited). Do not eyeball it. FBDI templates are
the common case and have a predictable shape:

- The **GL_INTERFACE** worksheet holds the data; an "Instructions and CSV Generation"
  sheet usually sits alongside it.
- Row 1 is a friendly title ("Journals Import"); row 2 is a legend ("* Required"); the
  **column-name header is on row 3** (`*Status Code`, `*Ledger ID`, `Segment1`…`Segment30`,
  `Entered Debit Amount`, `Entered Credit Amount`, the REFERENCE columns, etc.); **data
  begins on row 4.** Confirm this by reading the first few rows rather than assuming —
  some exports shift the header. Map columns by their header name, never by fixed index.
- Read amounts and segment values **as strings** first to catch leading-zero segments,
  Excel-float artifacts on numeric codes, and date-format issues — then cast amounts to
  Decimal for balancing math (never float-sum money for the balance proof; use Decimal or
  integer cents).

Determine, and state back concisely:

1. **Format & artifact type** — GL_INTERFACE FBDI Journal Import vs. trial balance vs.
   opening-balance file vs. journal extract vs. COA segment export vs. transcript.
2. **Source/target fingerprint** — the GL_INTERFACE 223-column layout is the Fusion FBDI
   fingerprint; `*Journal Source` / `*Journal Category` = `Conversion` is the conversion
   fingerprint. Capture the ledger name(s) and period.
3. **Grain & shape** — one row = one journal line. Count data rows, distinct ledgers,
   distinct currencies, distinct periods, and the implied journal/batch grouping (via the
   REFERENCE columns / Group ID).

### GL conversion artifact catalog

| Artifact | Tells | Primary Fusion relevance |
|---|---|---|
| **GL_INTERFACE FBDI Journal Import** | Status/Ledger/Date/Source/Category/Currency/Actual Flag + Segment1–30 + Entered Dr/Cr + Accounted Dr/Cr + REFERENCEs + conversion type/date/rate | The load itself — balancing, COA combination validation, control-value matching, period/ledger/source/category setup, Journal Import + AutoPost |
| **Trial balance** | Account + period debit/credit or net balance | Opening-balance conversion sizing, COA reverse-engineering, balance reconciliation target |
| **Opening / historical balance file** | Period-end balances by account, possibly multi-period | Opening-balance journal design, history-load scope (how many periods), balance-vs-activity decision |
| **Journal / voucher extract** | Row per line with account, amount, source, description | Activity-load design, source/category mapping, descriptive-flexfield/reference mapping |
| **Chart-of-accounts segment export** | Segment values, hierarchies, value-set membership | COA structure, value sets, segment qualifiers (balancing/natural-account/cost-center), cross-validation rules |
| **GL design-workshop transcript / fit-gap / blueprint** | Future-state narrative; current ERP named; ledger/COA/calendar/currency decisions; "in scope / roadmap / decision" language | Ledger and COA design, conversion approach (balances vs. detail), source systems, mine exhaustively |

When multiple files arrive (a trial balance *and* the FBDI that loads it, or a COA export
*and* a journal extract), decide whether they are **one logical conversion thread** — the
trial balance is the reconciliation target the FBDI must tie to; the COA export validates
the segment combinations the journal references.

### Normalize ledger, currency, period, and control metadata before comparing anything

- **Ledger** — `*Ledger ID` is frequently **blank** with **Ledger Name** populated (a
  name-resolution pattern: the import resolves the ID from the name). Note which is
  present; a blank Ledger ID is fine *if* Ledger Name resolves to a configured ledger,
  but is a hard reject if neither resolves.
- **Currency** — establish the currency mix. Foreign-currency lines must carry a
  conversion **type**, and either a **rate** (User type) or a **date** the daily rate is
  looked up by; functional-currency lines must *not* carry conversion attributes.
  Reconcile this before the balance proof — you balance **by currency**, not across it.
- **Period & date** — the `*Effective Date of Transaction` must fall in an **open** (or
  future-enterable) period that matches the Period Name; a conversion journal dated into a
  closed period is a load/post blocker.
- **Control values** — Status Code (`NEW` for a fresh load), Actual Flag (`A` actual / `B`
  budget / `E` encumbrance), Journal Source and Category. For a conversion these are
  almost always `Conversion`/`Conversion`, which **must exist as a defined Journal Source
  and Category in Fusion** (the conversion source is what lets you exclude these journals
  from downstream reporting and reverse them cleanly).

For **transcripts**: establish session date, engagement phase, and the explicit scope
boundary; capture ledger/COA/calendar/currency decisions as scope-level unless locked.

---

## Step 2 — Profile the as-is (prove balance first, then quantify)

Use code to measure. Distinguish what the artifact **shows** from what you **infer**.

### 2A — The balance proof (always first, always with exact arithmetic)

This is the defining GL move. Using Decimal/cents (never float):

- **Total entered debits = total entered credits**, to the penny. Report both totals and
  the difference.
- **Balanced by currency** — sum Dr and Cr within each `*Currency Code`; each currency
  must net to zero. (A file can net to zero overall while being out of balance within a
  currency — that still rejects.)
- **Balanced by ledger** (and, where multiple balancing-segment values exist, note whether
  the client intends balanced-by-balancing-segment; Fusion can auto-balance intercompany,
  but a clean conversion usually balances within each balancing segment).
- **No malformed lines** — no row with *both* a debit and a credit, none with *neither*,
  no negative amounts used in place of the opposite column (Fusion expects positive
  amounts in the correct Dr/Cr column).
- If a trial balance accompanies the file, **tie the journal to it** — the converted
  journal's net by account should reconcile to the trial-balance target.

State the balance result up front as a pass/fail with the numbers. A balanced file is the
single strongest signal of a clean conversion; an out-of-balance file is the headline
problem regardless of anything else.

### 2B — Reverse-engineer the chart of accounts (the highest-value structural move)

- **Segment count & roles** — how many of Segment1–30 are populated (that is the COA
  structure: e.g. six segments = Company–Account–Cost Center–three future/00000 segments).
  Infer each segment's role from its cardinality and value pattern: a low-cardinality
  leading segment is usually the **balancing/company** segment; a high-cardinality segment
  is usually the **natural account**; mid-cardinality is **cost center / department**;
  all-`00000` segments are **placeholders for future/unused segments**.
- **Value patterns & data-quality artifacts** — leading-zero segment values (a real COA
  pattern that *must be preserved as strings* — an integer cast breaks the combination),
  Excel-float artifacts on numeric codes, blank segments where a value is required.
- **Combination validity** — every populated combination must resolve against the
  configured COA and pass cross-validation rules; flag any segment value not expected in
  the target value set (you may not be able to confirm membership without the COA export —
  call that out as a needed input).

### 2C — Profile the journal structure & control posture

- **Source/Category** — distribution; for a conversion expect a single `Conversion` source
  and category. Multiple sources/categories imply mixed content to map.
- **Journal/batch grouping** — how lines roll into journals and batches (via REFERENCE1
  batch name, REFERENCE4 journal-entry name, Group ID). The conversion's batch strategy
  (one batch per period? per source? per company?) lives here.
- **Reference/descriptive mapping** — which REFERENCE columns carry batch/journal names
  and descriptions, and whether descriptive flexfield columns are used.
- **Volume & distribution** — rows per ledger/currency/period, debit/credit row split,
  amount distribution (to sanity-check scale and spot outliers).

State the operating model — ledgers, COA shape, currency posture, conversion approach
(balances vs. detail activity), period scope — as inferences the user can correct.

---

## Step 2.5 — GL_INTERFACE load-readiness checklist (always run it)

The Journal Import rejects or suspends on missing/invalid control data more than on
anything else. Validate the file against the required-and-conditional set and report
completeness (% populated, blanks, invalid values) per element, rolling up to a per-area
readiness verdict (🟢 loadable / 🟡 loadable with cleanup / 🔴 blocked / ⬜ unverifiable).

**Required control columns (the `*` columns)**
- `*Status Code` — `NEW` for a fresh import; anything else is a reject for a new load.
- `*Ledger ID` **or** resolvable Ledger Name — one must resolve to a configured ledger.
- `*Effective Date of Transaction` — present, valid date, in an open/future-enterable
  period matching the Period Name.
- `*Journal Source` — present and **configured in Fusion** (e.g. `Conversion`).
- `*Journal Category` — present and **configured in Fusion** (e.g. `Conversion`).
- `*Currency Code` — present, a valid enabled currency.
- `*Journal Entry Creation Date` — present, valid date.
- `*Actual Flag` — `A` / `B` / `E`; `A` for an actuals conversion.

**Account combination**
- The populated Segment1–N combination resolves against the configured COA, passes
  cross-validation, and uses **enabled, postable** detail values (not parent/summary
  values). Leading-zero segments preserved as strings.

**Amounts**
- Exactly one of Entered Debit / Entered Credit per line, positive; the journal balances
  (Step 2A). For foreign currency, Accounted amounts either provided consistently or left
  for the system to derive via the conversion type/rate.

**Foreign-currency conditional set** (only on non-functional-currency lines)
- `Currency Conversion Type` present; and either `Currency Conversion Rate` (User type) or
  a `Currency Conversion Date` for daily-rate lookup. Functional-currency lines must carry
  none of these.

**Period & reconciliation**
- Period Name matches the effective date's period; the file ties to its trial-balance
  target if one was provided.

For each element report: present? (Y/N), % populated, invalid/placeholder values, and a
verdict. A file can be 100% balanced and still be blocked if `Conversion` is not a
configured source/category or the period is closed — say so.

---

## Step 3 — Translate to Fusion (three output streams)

**1. Configuration items** — setup the file implies, each with the *why*:
- **Ledger & calendar** — the target ledger must exist with the matching accounting
  calendar and the conversion period **open or future-enterable**; functional currency
  matching the dominant entered currency.
- **Chart of accounts** — the N-segment structure with correct value sets, segment
  qualifiers (balancing segment, natural account, cost center), postable detail values,
  cross-validation rules, and any required `00000` placeholder values for unused segments.
- **Journal sources & categories** — `Conversion` source (typically set to *not* require
  approval and to be excluded from certain processes) and `Conversion` category defined.
- **Currency & conversion** — enabled currencies (USD/GBP/BRL in the worked example),
  conversion types (User / Corporate / Spot), and daily rates loaded where date-based
  conversion is used.
- **Suspense / balancing options** — suspense posting and intercompany-balancing options
  set per the client's balancing posture.

**2. Conversion items** — what gets loaded and the strategy/risk for each. The journal
itself (balances vs. detail activity, and how many historical periods); the COA value
sets and hierarchies (a prerequisite — they must exist before the journal loads); daily
rates for FX lines. Call out **conversion blockers**: out-of-balance by ledger/currency;
`Conversion` source/category not configured; closed/undefined period; unresolved ledger;
account combinations that fail cross-validation or hit parent/summary values; leading-zero
segments broken by an integer cast; FX lines missing a conversion type/rate; and the
decision on whether prior-period balances load as one opening journal or as period-by-
period detail.

**3. Current-state summary** — ledgers and COA shape, the conversion approach, the
currency posture, the period scope, the balance result, and the headline risks. Quantified
where data exists; inferences flagged.

---

## Step 4 — Surface decisions, name the gaps

- **Design decisions** — opening balances as a single conversion journal vs. detail
  activity by period; how many historical periods to convert; one batch per period/source/
  company; whether `Conversion` journals auto-post or are reviewed; FX conversion type
  policy (User-with-rate vs. daily-rate-by-date); balancing-segment vs. system auto-balance.
  Frame each with options and a lean.
- **Leading-practice gaps** — converting excessive detail history instead of opening
  balances; not isolating conversion journals under a dedicated source; missing cross-
  validation rules. Framed as a decision, not a criticism.
- **Cross-dependencies** — the COA value sets, the ledger, the calendar/period, and the
  currencies/rates **must all exist before the journal loads** — the most common cause of
  a stalled GL conversion. The trial balance is the reconciliation gate.
- **What's missing** — the COA segment export (to confirm value-set membership and
  postable values); the trial balance (to reconcile the load); the daily-rate set (for FX);
  confirmation of the open conversion period and the defined `Conversion` source/category;
  the list of ledgers and their calendars in scope.

---

## Report Mode

When a report/deliverable is requested, produce executive prose anchored by structured
reference elements: artifact inventory; **balance proof** (totals, by-currency, by-ledger,
pass/fail); ledger/COA/currency/period summary; the GL_INTERFACE load-readiness scorecard
(Step 2.5 as a table with verdicts); configuration register; conversion register; decision
log; cross-dependency list; and the gap / next-data-request list.

For an **HTML report**, render via the `data-analysis-report-format` skill — the house
standard for analysis-report look (thesis verdict card, color-coded scorecard, observation
blocks, severity-grouped risk registers). The balance proof maps naturally to the at-a-
glance thesis card; the load-readiness checklist to the scorecard; the blockers to the
hard-reject/cleanup registers. For a spreadsheet workbook, hand off to `xlsx`; for a
narrative document, `docx`. If the engagement uses a house brand (Hackett/DigiKey/client),
layer that brand-guidelines skill on top — keep the layout, swap palette and fonts.

---

## Principles

- Detect the header row before profiling; FBDI data starts below a fixed header (commonly
  header on row 3, data from row 4). Map columns by name, never by index.
- Prove balance first, with exact arithmetic (Decimal/cents, never float), by currency and
  by ledger. A balanced file is the strongest clean-conversion signal; out-of-balance is
  the headline.
- Read segments and codes as strings to preserve leading zeros and catch float artifacts;
  cast only amounts, and only for the balance math.
- Reverse-engineer the COA from segment cardinality and value patterns; the combination
  must resolve to postable detail values and pass cross-validation.
- Control values are load gates: `Conversion` source/category must be configured, the
  period must be open, the ledger must resolve, FX lines need a conversion type/rate. A
  balanced file can still be blocked on configuration.
- Lead with the functional *why*, then the setup *how*. Flag inferences; separate hard-
  reject blockers from cleanup/config.
- Name the prerequisites loudly — COA value sets, ledger, calendar/period, and rates must
  exist before the load; the trial balance is the reconciliation gate.
- Conversational by default; structured-plus-prose only when a report is asked for, and
  render HTML reports through `data-analysis-report-format`.

---

## Worked example — GL_INTERFACE FBDI Journal Import (January-2023 detail conversion)

A client provides a GL_INTERFACE FBDI template (.xlsm) — the "Journals Import" sheet, header
on row 3, ~5,089 data rows beginning row 4, 223 columns. Profiling yields:

- **Detection** — Fusion FBDI Journal Import (the 223-column GL_INTERFACE layout is the
  fingerprint). Single ledger (**Corporate Ledger**, `*Ledger ID` blank but Ledger Name
  populated — name-resolution pattern), single period (**Jan-23**), Status `NEW`, Actual
  Flag `A`, Journal Source and Category both **`Conversion`** — a textbook conversion
  fingerprint.
- **Balance proof (the headline)** — entered debits **2,158,377,086.43** = entered credits
  **2,158,377,086.43**, difference **0.00**. Balanced **by currency**: USD
  2,148,938,780.53 / 2,148,938,780.53, GBP 5,403,360.90 / 5,403,360.90, BRL 4,034,945.00 /
  4,034,945.00 — each nets to zero. **Zero** rows with both Dr and Cr, **zero** with
  neither. This journal balances perfectly — the strongest signal of a clean conversion. 🟢
- **COA reverse-engineered** — six populated segments. Segment1 = 16 distinct low-cardinality
  values (`10001`…) → **company / balancing segment**; Segment2 = 345 distinct, leading-zero
  values (`0774802`, `0259100`) → **natural account**; Segment3 = 25 distinct (`000`,`090`,
  `900`…) → **cost center**; Segments 4–6 = single value `00000` → **placeholder/future
  segments**. The leading-zero account values are a real COA pattern that **must be preserved
  as strings** — an integer cast (e.g. by Excel or a careless ETL step) would drop the
  leading zero and break every combination. 🟡 (preserve-as-string cleanup gate.)
- **Currency posture** — predominantly USD with 86 foreign-currency lines (GBP, BRL). Every
  FX line correctly carries a **Currency Conversion Type** and a **rate** (User-type
  conversion), and USD lines correctly carry none — the conditional FX set is satisfied. 🟢
- **Control posture** — `Conversion` source/category, `NEW` status, Actual Flag `A`,
  Jan-23 period. These resolve to load gates: the **`Conversion` source and category must be
  defined** in Fusion, and **Jan-23 must be open or future-enterable** in the Corporate
  Ledger's calendar — both unverifiable from the file alone (request confirmation). ⬜
- **Naming/grouping** — REFERENCE1 carries the batch name, REFERENCE4 the journal-entry name,
  REFERENCE5 the description — a clean batch/journal-naming strategy.
- **Load-readiness verdict** — the file itself is **clean and balanced** (🟢 on structure and
  balance); the open items are configuration-side (🟡/⬜): confirm `Conversion` source/category
  exist, confirm Jan-23 is open, confirm the six-segment combinations resolve to postable
  detail values against the configured COA and pass cross-validation, and preserve leading-
  zero segments through ETL.
- **Gaps / next-data requests** — the **COA segment value-set export** (to confirm the 345
  accounts and 16 companies are enabled, postable detail values); the **Jan-23 trial balance**
  (to reconcile the 2.16 B load); the **daily/User rate set** behind the FX lines; and
  confirmation of the **open conversion period** and the defined **`Conversion`** source and
  category.

This is the depth bar — for a *data* artifact, match it on the balance proof, the COA
reverse-engineering, the load-readiness checklist, and the control-value gates; for a
*transcript*, mine ledger/COA/calendar/currency decisions and the conversion approach.
