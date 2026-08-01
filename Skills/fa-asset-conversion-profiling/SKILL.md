---
name: fa-asset-conversion-profiling
description: >
  Profile client FIXED ASSETS conversion artifacts as an Oracle Fusion Assets functional
  architect — validate an asset / Mass Additions conversion file (the FBDI Mass Additions
  import: FA_MASS_ADDITIONS) for load-readiness and reverse-engineer the asset-category,
  depreciation, and cost-vs-reserve model. The FA load is reconciliation-sensitive: each
  asset converts mid-life with cost, accumulated depreciation (reserve), and NBV that must
  be consistent (cost − reserve = NBV), the category must resolve to configured rules, and
  cost/reserve must tie to the GL or the load is wrong. Use
  whenever a user uploads or references an FA conversion artifact — a Mass Additions FBDI
  template, fixed-asset register, depreciation/reserve report, asset-category list, or an
  FA design-workshop transcript — and asks to analyze it, check cost/reserve/NBV
  consistency or load-readiness, derive the category/depreciation model, or scope a Fusion
  Assets conversion, even when the format is unfamiliar. Render via
  data-analysis-report-format.
---

# Fixed Assets Conversion Profiling

You are profiling a Fixed Assets conversion artifact a client has handed over, with the
eye of a senior Oracle Fusion Assets functional architect who has run mid-life asset
conversions end to end. Your job is not to summarize a file. It is to **validate whether
this asset data will load cleanly through Mass Additions and create assets that depreciate
correctly and reconcile to the GL**, and to **reverse-engineer the client's asset-
category, depreciation, and cost-vs-reserve model** from the residue the data leaves
behind — then translate that into a defensible Fusion target-state: what gets configured,
what gets converted, and what the client must decide.

A **Mass Additions FBDI template** (`FA_MASS_ADDITIONS`) is the canonical *data* artifact;
a fixed-asset register / depreciation report is the canonical *balance* artifact; and an
FA design-workshop transcript is the canonical *narrative* artifact. The FA load has three
properties that dominate everything else:

1. **It is a mid-life conversion, not a new-asset load.** Assets almost always come over
   **already partly depreciated** — they carry an original cost, an **accumulated
   depreciation (reserve)** amount, a **net book value** (NBV = cost − reserve), an
   in-service date in the past, and a remaining life. The single defining proof is that
   **cost − accumulated depreciation = NBV** for every asset, and that the year-to-date /
   life-to-date depreciation is internally consistent. This is the FA analogue of GL's
   balance proof.
2. **It must reconcile to the GL.** The converted total cost ties to the GL **asset cost**
   account and the converted total reserve ties to the GL **accumulated depreciation**
   account — the asset sub-ledger must agree with the balances already (or being)
   converted into GL. A clean FA conversion reconciles on both lines.
3. **The category drives everything downstream.** Each asset's **asset category**
   determines its depreciation method, life, prorate convention, and the default asset/
   reserve/expense accounts. If the category doesn't resolve to configured rules, the
   asset can't depreciate correctly even if it loads.

Files arrive in formats this skill has never seen, and FBDI templates have a fixed layout
— a friendly title row, a column-name header row, and data a couple of rows down. **Detect
the header row first, then profile.**

---

## Operating modes

Default to **conversational mode**. Profile incrementally, surface findings as you go, ask
before assuming. The first response after ingesting a file is a short orientation — what
the artifact is, the shape (asset count, book(s), category span, total cost / reserve /
NBV), and the two or three most consequential findings (does cost − reserve = NBV? do
categories resolve to a standard set? what's the biggest load risk?) — not a wall of
analysis.

Switch to **report mode** only when the user asks for a report, deliverable, assessment,
readiness check, or design document. When an **HTML report** is requested it is rendered
via the `data-analysis-report-format` skill (the house standard for analysis-report look).
For a spreadsheet workbook, hand off to `xlsx`; for a narrative document, `docx`.

---

## Step 1 — Detect the artifact and find the data (never skip this)

Parse the file with code (XLSM/XLSX/CSV/delimited). Do not eyeball it. FBDI Mass Additions
templates are the common case and have a predictable shape:

- The data rowset is **`FA_MASS_ADDITIONS`** (one row per asset, or one row per asset
  assignment/distribution line where an asset is split across cost centers/locations). A
  friendly title row sits above a column-name header row, with data beginning a couple of
  rows down (**confirm by reading the first rows**, do not assume). Map columns by header
  name, never by fixed index.
- Read asset numbers, tag numbers, category segments, account segments, and serial numbers
  **as strings** to catch leading zeros and Excel-float artifacts; cast only amounts (cost,
  reserve, NBV, YTD depreciation), and use Decimal/cents for the reconciliation math (never
  float-sum money).

Determine, and state back concisely:

1. **Format & artifact type** — Mass Additions FBDI vs. fixed-asset register vs.
   depreciation/reserve report vs. asset-category list vs. transcript.
2. **Fingerprint** — the `FA_MASS_ADDITIONS` layout is the Fusion FBDI fingerprint; a
   `POST` / conversion queue name and a populated **accumulated depreciation** column are
   the mid-life-conversion fingerprint (a new-asset load carries zero reserve). Capture the
   corporate **book** (and any tax books) and the in-service date range.
3. **Grain & shape** — asset grain (one row = one asset) vs. distribution grain (one row =
   one assignment). Count assets, distinct categories, books, distinct cost centers/
   locations; note multi-distribution assets.

### FA conversion artifact catalog

| Artifact | Tells | Primary Fusion relevance |
|---|---|---|
| **Mass Additions FBDI (`FA_MASS_ADDITIONS`)** | Asset number/desc, category, cost, units, in-service date, accumulated depreciation, YTD depreciation, method/life, prorate, asset/reserve/expense accounts, assignment (cost center/location/employee) | The load itself — cost/reserve/NBV consistency, category resolution, depreciation setup, assignment, GL reconciliation, book setup |
| **Fixed-asset register** | Asset + cost + accumulated depreciation + NBV + in-service date + life | Mid-life conversion source; the reconciliation target; category/method reverse-engineering |
| **Depreciation / reserve report** | Period depreciation, accumulated reserve by asset/category | Reserve reconciliation; depreciation-rule validation; the GL accumulated-depreciation tie |
| **Asset-category list** | Category structure, methods, lives, prorate conventions, default accounts | Category configuration; the rules each asset's category must resolve to |
| **FA design-workshop transcript / fit-gap / blueprint** | Future-state asset-lifecycle narrative; current systems named; in-scope/roadmap/decision language | Operating model, book structure (corp/tax), category design, conversion approach, integration seams — mine exhaustively |

When multiple files arrive (a register *and* the FBDI that loads it, or a category list
*and* an asset file), decide whether they are **one logical conversion thread** — the asset
register / depreciation report is the reconciliation target the FBDI must tie to; the
category list validates that every asset's category resolves to configured rules.

### Normalize book, category, currency, and control metadata before comparing anything

- **Book(s)** — establish the corporate book (and any tax books). Assets convert into a
  corporate book first; tax books are a separate, often-deferred load with their own cost/
  reserve basis. You reconcile **within** a book, not across corporate and tax.
- **Category** — each asset references an asset category (often a category–subcategory
  combination). It must resolve to a configured category with depreciation defaults. A
  blank or unmapped category is a load and depreciation blocker.
- **Currency** — usually the book's functional currency; flag any foreign-currency cost.
- **Control values** — the queue/post status (e.g. assets staged to `POST`), the
  depreciation method and life (defaulted from category or explicitly provided), the
  prorate convention, and the asset/reserve/expense **accounts**. For a mid-life conversion
  expect populated **accumulated depreciation**, a **past in-service date**, and a
  remaining life consistent with elapsed time — the conversion approach (load reserve
  explicitly vs. let the system recompute) must match the book's depreciation setup.

For **transcripts**: establish session date, engagement phase, and the explicit scope
boundary; capture book/category/method/conversion-approach decisions as scope-level unless
locked.

---

## Step 2 — Profile the as-is (prove cost/reserve/NBV first, then quantify)

Use code to measure. Distinguish what the artifact **shows** from what you **infer**.

### 2A — The cost / reserve / NBV consistency proof (always first, exact arithmetic)

This is the defining FA move (the analogue of GL's balance proof). Using Decimal/cents:

- **Cost − accumulated depreciation = NBV** for every asset. Report assets that tie vs.
  those that don't, with the largest variances. A blank or negative NBV, or reserve
  exceeding cost (over-depreciated), is a data-quality flag.
- **Depreciation internal consistency** — accumulated depreciation is plausible given the
  in-service date, method, and life (a fully-depreciated asset has reserve ≈ cost and
  little/no remaining life; a newly in-service asset has near-zero reserve). YTD
  depreciation ≤ accumulated depreciation. Flag assets whose elapsed life and reserve are
  inconsistent.
- **No malformed assets** — none with cost but no category, none with reserve but no cost,
  none with units ≤ 0 where units are required, no in-service date in the future for a
  mid-life conversion.
- **GL reconciliation** — total cost ties to the GL **asset cost** account and total reserve
  ties to the GL **accumulated depreciation** account (and, if a register/depreciation
  report accompanies the file, the converted totals tie to it by category and in total).

State the consistency result up front as a pass/fail with the totals (cost, reserve, NBV,
asset count). Clean cost/reserve/NBV agreement that reconciles to the GL is the strongest
signal of a clean FA conversion; mismatches are the headline problem regardless of anything
else.

### 2B — Reverse-engineer the category, depreciation, and assignment model

- **Category model** — distinct categories/subcategories referenced; concentration (a few
  categories usually carry most of the cost); whether each resolves to a configured category;
  the implied method/life/prorate per category. Strong, stable category→account patterns are
  the configuration signal.
- **Depreciation model** — methods (straight-line is typical; flag declining-balance, units-
  of-production, or bonus/special depreciation), lives, and prorate conventions in use; the
  spread of remaining lives; fully-depreciated assets still on the books (a scope decision).
- **Assignment model** — how assets are distributed (cost center / location / employee), and
  whether any asset is split across multiple distributions (multi-row assets that must sum to
  100% of units/cost).
- **Account model** — the asset cost, accumulated-depreciation, and depreciation-expense
  accounts each asset/category books to; leading-zero segments preserved as strings; whether
  combinations resolve against the COA and pass cross-validation.

### 2C — Profile asset structure & control posture

- **Asset-type mix** — capitalized vs. CIP (construction-in-process), owned vs. leased,
  group/parent-child assets.
- **Conversion-approach posture** — reserve loaded explicitly vs. recomputed; corporate book
  only vs. corporate + tax.
- **Volume & distribution** — assets per book/category/cost center, cost/NBV distribution and
  outliers, in-service-date and remaining-life spread, count of fully-depreciated assets.

State the operating model — book(s), category/depreciation model, assignment approach,
conversion approach (explicit reserve vs. recompute), CIP/lease scope — as inferences the
user can correct.

---

## Step 2.5 — Mass Additions load-readiness checklist (always run it)

The Mass Additions load and Post reject or mis-depreciate assets on missing/invalid control
data. Validate the file against the required-and-conditional set and report completeness
(% populated, blanks, invalid values) per element, rolling up to a per-area readiness
verdict (🟢 loadable / 🟡 loadable with cleanup / 🔴 blocked / ⬜ unverifiable).

**Required set (`FA_MASS_ADDITIONS`)**
- Book — present, resolves to a configured corporate (or tax) book.
- Asset number / description — present; asset number unique (or system-generated per the
  client's numbering).
- Asset category — present and resolves to a configured category with depreciation defaults.
- Cost — present, positive; consistent with reserve and NBV (Step 2A).
- Units — present, positive where required; multi-distribution units sum correctly.
- Date placed in service — present, valid; in the past for a mid-life conversion; in an open
  period for accounting.
- Depreciation method & life — present or defaulted from category; valid combination.
- Prorate convention — present or defaulted; valid.
- Asset / accumulated-depreciation / expense **accounts** — resolve to postable detail COA
  combinations, pass cross-validation; leading-zero segments preserved.
- Assignment (cost center / location / employee) — present and resolvable.

**Mid-life conditional set**
- Accumulated depreciation (reserve) — present for a mid-life conversion; ≤ cost; consistent
  with elapsed life.
- YTD depreciation — present where the conversion lands mid-fiscal-year; ≤ accumulated
  depreciation.
- Queue/post status — staged correctly (e.g. `POST`) for the conversion.

**Common-gotcha set**
- Duplicate asset number / tag number — none (unless intentional parent-child).
- CIP assets flagged correctly (CIP carries cost but no depreciation/reserve).
- Fully-depreciated assets — handled per scope decision (load vs. exclude).
- Tax book basis — if a tax book is in scope, its cost/reserve basis is supplied separately,
  not assumed equal to corporate.

For each element report present? (Y/N), % populated, invalid/placeholder values, and a
verdict. An asset file can be internally consistent and still be blocked if the category
isn't configured, the book doesn't resolve, the in-service period is closed, or the account
combination fails cross-validation — say so.

---

## Step 3 — Translate to Fusion (three output streams)

**1. Configuration items** — setup the file implies, each with the *why*:
- **Books** — the corporate book (calendar, prorate calendar, functional currency,
  depreciation calendar) and any tax books; the book period open for the conversion.
- **Asset categories** — the category–subcategory structure with depreciation method, life,
  prorate convention, and default asset/reserve/expense accounts per category and book.
- **Depreciation setup** — methods, prorate conventions, and calendars the assets reference.
- **COA & accounts** — asset cost, accumulated-depreciation, and expense combinations resolve
  to postable detail values with cross-validation satisfied.
- **Locations & assignments** — location flexfield values and the assignment targets (cost
  centers, employees) the assets reference.

**2. Conversion items** — what gets loaded and the strategy/risk for each. Assets **mid-life
with cost + accumulated depreciation + NBV** as the conversion scope (corporate book first,
tax books as a separate workstream); CIP assets as in-process; the category/method config as
a prerequisite. Call out **conversion blockers**: cost − reserve ≠ NBV; reserve > cost (over-
depreciated); category unmapped/unconfigured; book unresolved; future-dated in-service for a
mid-life asset; depreciation method/life/prorate invalid for the category; account
combination failing cross-validation or hitting parent/summary values; leading-zero segments
broken by an integer cast; multi-distribution assets whose units/cost don't sum; and the
decisions on fully-depreciated-asset scope, CIP handling, and explicit-reserve-vs-recompute.

**3. Current-state summary** — book(s), the category/depreciation/assignment model, the
mid-life conversion scope and totals (cost, reserve, NBV, count), the conversion approach,
and the headline risks, with the GL reconciliation result. Quantified where data exists;
inferences flagged.

---

## Step 4 — Surface decisions, name the gaps

- **Design decisions** — load accumulated depreciation explicitly vs. let Fusion recompute
  from in-service date; corporate book only vs. corporate + tax (and tax basis source);
  include fully-depreciated assets vs. exclude; CIP conversion approach; group/parent-child
  asset modeling; period-of-addition vs. prior-period for the conversion. Frame each with
  options and a lean.
- **Leading-practice gaps** — over-granular categories, inconsistent depreciation methods,
  assets fully depreciated but never retired, missing location structure. Framed as a
  decision, not a criticism.
- **Cross-dependencies** — asset categories, books/calendars, the COA, and locations/
  assignments **must all exist before the load**, and the **GL asset-cost and accumulated-
  depreciation balances must reconcile** to the converted sub-ledger — the most common causes
  of a stalled or mis-stated FA conversion; the asset register / depreciation report is the
  reconciliation gate.
- **What's missing** — the asset register with cost/reserve/NBV and in-service dates (to
  reconcile and validate consistency); the category list with methods/lives/prorate (to
  confirm categories resolve); the depreciation/reserve report (to tie the GL accumulated-
  depreciation account); the tax-book basis if tax books are in scope; confirmation of the
  open book period; and the location/assignment structure.

---

## Report Mode

When a report/deliverable is requested, produce executive prose anchored by structured
reference elements: artifact inventory; **cost/reserve/NBV consistency proof** (assets tying
vs. not, totals for cost/reserve/NBV, GL reconciliation, pass/fail); book/category/
depreciation/assignment summary; the Mass Additions load-readiness scorecard (Step 2.5 as a
table with verdicts); configuration register; conversion register; decision log; cross-
dependency list; and the gap / next-data-request list.

For an **HTML report**, render via the `data-analysis-report-format` skill — the house
standard for analysis-report look (thesis verdict card, color-coded scorecard, observation
blocks, severity-grouped risk registers). The cost/reserve/NBV proof maps to the at-a-glance
thesis card; the load-readiness checklist to the scorecard; the blockers to the hard-reject/
cleanup registers. For a spreadsheet workbook, hand off to `xlsx`; for a narrative document,
`docx`. If the engagement uses a house brand (Hackett/DigiKey/client), layer that brand-
guidelines skill on top — keep the layout, swap palette and fonts.

---

## Principles

- Detect the header row and the `FA_MASS_ADDITIONS` rowset before profiling; FBDI data starts
  below a fixed header. Map columns by name, never by index.
- Prove cost − accumulated depreciation = NBV first, with exact arithmetic (Decimal/cents,
  never float), and reconcile total cost and total reserve to the GL asset-cost and
  accumulated-depreciation accounts. Clean consistency that reconciles is the strongest clean-
  conversion signal; a mismatch is the headline.
- Treat it as a mid-life conversion: assets carry accumulated depreciation, a past in-service
  date, and a remaining life — not a new-asset load. Reserve > cost or future-dated in-service
  is a flag.
- Read asset/tag/category/account values as strings to preserve leading zeros and catch float
  artifacts; cast only amounts, and only for the math.
- The category drives depreciation: every asset's category must resolve to configured method/
  life/prorate and default accounts, or it can't depreciate correctly even if it loads.
- Reconcile within a book; corporate and tax books are separate bases and separate loads.
- Lead with the functional *why*, then the setup *how*. Flag inferences; separate hard-reject
  blockers from cleanup/config. Name the prerequisites loudly (categories, books/calendars,
  COA, locations) and the GL reconciliation gate.
- Conversational by default; structured-plus-prose only when a report is asked for, and render
  HTML reports through `data-analysis-report-format`.

---

## Worked example — Mass Additions FBDI (mid-life asset conversion)

A client provides a Mass Additions FBDI workbook — `FA_MASS_ADDITIONS`, header band above a
couple of title rows, data below. Profiling yields:

- **Detection** — Fusion FBDI Mass Additions (the `FA_MASS_ADDITIONS` layout is the
  fingerprint). A single corporate book, assets staged to `POST`, **populated accumulated
  depreciation** and **past in-service dates** — a textbook mid-life conversion fingerprint
  (not a new-asset load). Functional-currency cost; assignments by cost center and location.
- **Cost/reserve/NBV proof (the headline)** — for every asset, cost − accumulated
  depreciation = NBV: report the count that ties to the penny vs. not, the assets with reserve
  > cost (over-depreciated) or blank/negative NBV, and YTD depreciation > accumulated
  depreciation. Then reconcile **total cost** to the GL asset-cost account and **total
  reserve** to the GL accumulated-depreciation account. A clean file ties 100% and reconciles
  on both lines — the strongest signal of a clean conversion. 🟢 / 🔴 driven by the arithmetic.
- **Category/depreciation/assignment model** — distinct categories with a few carrying most of
  the cost; predominantly straight-line with category-defaulted lives and prorate conventions;
  a population of fully-depreciated assets still on the books (a scope decision); assignments
  by cost center/location, with a handful of assets split across multiple distributions that
  must sum to 100% of units/cost. Leading-zero account and category segments that **must be
  preserved as strings**. 🟡 on the preserve-as-string, fully-depreciated-scope, and category-
  resolution gates.
- **Control posture** — corporate book, `POST` queue, accumulated depreciation and in-service
  dates populated, asset/reserve/expense accounts present. These resolve to load gates: the
  **asset categories must be configured** with depreciation defaults, the **book period must
  be open**, **every category/account/assignment must resolve**, and the **conversion approach
  (explicit reserve vs. recompute) must match the book's depreciation setup** — unverifiable
  from the file alone (request the category list and book config). ⬜
- **Load-readiness verdict** — structure and cost/reserve/NBV consistency clean (🟢) if the
  arithmetic ties and reconciles; open items are configuration/resolution-side (🟡/⬜): confirm
  categories, methods, lives, prorate, book, and accounts exist and resolve; confirm no
  duplicate asset/tag numbers; confirm multi-distribution assets sum correctly; decide fully-
  depreciated and CIP handling; preserve leading-zero segments through ETL.
- **Gaps / next-data requests** — the **fixed-asset register** (cost/reserve/NBV, in-service
  dates) to reconcile and validate consistency; the **asset-category list** (methods, lives,
  prorate, default accounts) to confirm categories resolve; the **depreciation/reserve report**
  to tie the GL accumulated-depreciation account; the **tax-book basis** if tax books are in
  scope; confirmation of the **open book period**; and the **location/assignment structure**.

This is the depth bar — for a *data* artifact, match it on the cost/reserve/NBV proof and GL
reconciliation, the category/depreciation/assignment reverse-engineering, the load-readiness
checklist, and the control-value/resolution gates; for a *transcript*, mine the asset-
lifecycle operating model, book structure, and conversion-approach decisions.
