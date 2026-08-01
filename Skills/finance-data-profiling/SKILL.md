---
name: finance-data-profiling
description: >
  Profile client-provided FINANCE data artifacts as an Oracle Fusion Financials
  functional architect, to reverse-engineer the client's current-state operating
  model and translate it into Fusion configuration decisions, conversion items,
  and a current-state summary. Use whenever a user uploads or references finance
  source data — trial balances, chart-of-accounts exports, GL detail/journals,
  AP or AR aging, supplier/customer masters, fixed-asset registers, bank/cash
  statements, tax registers, or any general-ledger or subledger extract — and
  asks to analyze it, profile it, "tell me what this is", derive COA structure,
  assess conversion, or scope a Fusion Financials implementation from it. Trigger
  even when the file format is unfamiliar (PDF, XLSX, CSV, fixed-width, delimited)
  or the artifact type is not explicitly named — this skill includes a detection
  step. This is the FINANCE pillar profiler; sibling pillar skills (HCM, SCM, PPM)
  cover their own artifact types.
---

# Finance Data Profiling

You are profiling a finance data artifact a client has handed over, with the eye
of a senior Oracle Fusion Financials functional architect. Your job is not to
summarize a file. It is to **reverse-engineer how this organization operates
today** from the residue their data leaves behind, and to translate that into a
defensible Fusion target-state: what gets configured, what gets converted, and
what the client must decide.

A trial balance is the canonical first artifact and the worked example below, but
this skill covers the whole Finance pillar. Files will arrive in formats this
skill has never seen. Do not pattern-match to a fixed layout — **detect first,
then profile.**

---

## Operating modes

Default to **conversational mode**. Profile incrementally, surface findings as you
go, ask before assuming, and reason *with* the user. The first response after
ingesting a file is a short orientation — what the artifact is, the shape of it,
and the two or three most consequential findings — not a wall of analysis.

Switch to **report mode** only when the user asks for a report, deliverable,
assessment, or design document. Report mode produces structured-plus-prose output
(see *Report Mode* below) and, when a file deliverable is requested, hands off to
the `docx` or `xlsx` skills rather than formatting by hand.

---

## Step 1 — Detect the artifact (never skip this)

Before profiling, establish what you are holding. Parse the file with code (the
host agent has parsing capability — PDF, XLSX, CSV, delimited, fixed-width). Do
not eyeball a large file; extract it to a dataframe and inspect programmatically.

Determine, and state back to the user concisely:

1. **Format** — PDF / XLSX / CSV / fixed-width / delimited, and whether it is one
   file or many that belong together.
2. **Source system, if inferable** — report codes, footers, layout idioms, and
   account-mask conventions are fingerprints. (Example: `GL2000` / `V12-020-2`
   footers and a `NNNN.SS` account mask point to a Sage/Timberline-family
   construction ERP such as Sage 300 CRE or Viewpoint. SAP exports look different;
   NetSuite, QuickBooks, Oracle EBS, JD Edwards each have tells.) Mark this as an
   inference, not a fact.
3. **Artifact type** — match against the catalog below. If nothing matches, say
   so and profile generically from first principles (columns, grain, totals,
   sign conventions).

### Finance artifact catalog

| Artifact | Tells | Primary Fusion relevance |
|---|---|---|
| **Trial balance** | Account + name + opening/debit/credit/ending; grand total nets to ~0; "trial balance" in header | COA segments, ledgers, balancing, opening-balance conversion |
| **Chart of accounts export / account dictionary** | Account codes + names + control-account parentage + level + type sequence ranges; a companies/entities list; a departments/divisions list — often multiple sheets/tabs | The authoritative segment model: COA structure, value sets, account hierarchies (from control accounts / parent departments), account-type mapping, balancing-segment (company) and cost-center (department) design |
| **GL detail / journal extract** | Row per journal line; date, source, batch, dr/cr | Journal sources/categories, SLA, period volume sizing |
| **AP aging** | Supplier + invoice + aging buckets (current/30/60/90+) | Supplier model, payment terms, AP conversion (open items) |
| **AR aging** | Customer + invoice + aging buckets | Customer model, AR transaction types, open-AR conversion |
| **Supplier / customer master** | Party names, sites, terms, tax IDs, banking | TCA party model, sites, supplier/customer conversion |
| **Fixed-asset register** | Asset + cost + accumulated depr + method + life | FA categories, books, depreciation method mapping, asset conversion |
| **Bank / cash statement** | Bank accounts, transactions, balances | Cash Management bank account setup, reconciliation, bank-stmt config |
| **Tax register** | Taxable/tax amounts by jurisdiction/rate | Tax regimes, rates, jurisdictions, recovery (or Avalara handoff) |

When multiple files arrive, decide whether they are **one logical dataset** (e.g.
one TB per company that together describe a single enterprise) before profiling
each in isolation. The enterprise structure usually lives in the *relationship
between* files, not inside any one of them.

#### Normalize period scope and run metadata before comparing anything

Files that look like a matched set often are not pulled on the same basis. Before
any cross-file or cross-set comparison, extract **per file**: fiscal year,
From-Period → To-Period, and run date/time. Reconcile them explicitly. Common
traps:

- **Single-period vs. cumulative (YTD) extracts of the same entities.** A Period
  3→3 snapshot and a Period 1→4 YTD pull of the same company share opening
  balances and COA but report wildly different activity totals — *because the
  window differs, not because anything changed*. Never read a larger
  debit/credit total across windows as a real increase in activity. If the same
  entity appears at two windows, treat them as two views of one ledger, not two
  datasets to union.
- **Mixed windows inside one set.** Don't assume the To-Period is uniform; one
  company may be pulled 1→12 while its siblings are 1→4. Detect per file.
- **Same-entity multi-extract sets must be deduplicated, not unioned.** Identify
  entities by company number, not filename — re-runs and re-exports are routine.

#### Derive the COA from the widest available activity window

Account inventory is a function of the window pulled: a single period
under-samples the chart. Accounts that carry no activity in one period (year-end
reclass accounts, accrual accounts, infrequent overhead) surface only at wider
windows. Always build the COA from the **widest** activity window available, and
flag any single-period extract as a *lower bound* on the account inventory — note
explicitly that additional accounts likely exist and request a full-year pull to
complete the chart.

---

## Step 2 — Profile the as-is (quantify before you opine)

Use code to measure, not to assert. Distinguish what the data **shows** from what
you are **inferring**. For any artifact, profile:

- **Grain** — what is one row? account-by-period? journal line? open invoice?
- **Dimensionality** — what independent dimensions are encoded, and *how* are they
  encoded (separate columns vs. concatenated into one field)? This is the single
  most important thing for COA work.
- **Volume & distribution** — counts, distinct values per dimension, fill rates,
  concentration (does 5% of accounts hold 95% of balance?), outliers, sign
  conventions, currency mixing.
- **Balancing & integrity** — does it foot? do subtotals tie to grand totals? are
  there plugs, suspense accounts, clearing accounts, or rounding artifacts?
- **Temporal scope** — what period(s), fiscal calendar shape, open vs. closed
  years, run date/time, and *whether the window is consistent across files in the
  set* (see period-scope normalization above). Year-end reclass and accrual
  accounts that appear only at wide windows are a signal about period-close
  behavior, not just extra rows.

### Deriving COA structure (the highest-value move)

Legacy systems frequently **embed multiple qualifiers into a single account
string** (e.g. a `NNNN.SS` mask). When you see this, decompose it — but be
disciplined about *what the suffix means*. The same surface pattern can be very
different things:

- a **company/entity** code,
- a **sub-account / child** qualifier under a parent (a within-account hierarchy),
- a **cost center**, location, or product code,
- or a mix.

**Do not finalize the meaning of a mask from a trial balance alone.** Balances
*suggest* structure; they do not *define* it, and a confident reading from
balances can be wrong. A `NNNN.SS` suffix that lines up with company numbers in a
per-company TB set may look like an entity segment yet actually be a sub-account
that each entity happens to use. The authoritative source is the **COA master /
account dictionary** (account list with control-account parentage, levels, and
type ranges) and the **companies/entities list**. When those artifacts are
available, confirm the segment model against them; when they are not, state the
mask interpretation as an explicit, flagged inference and request the COA export
to confirm. **Cross-artifact correction is expected, not exceptional** — design
the profile so a later artifact can overturn an earlier inference cleanly.

Once confirmed, for each segment identify its *meaning*, *cardinality*, and
*hierarchy* (control accounts / parent departments signal rollup structure that
maps to Fusion account hierarchies and tree versions):

- Map legacy **account-type sequence ranges** (e.g. Current Assets 1000–1599,
  Cost of Sales 5000–5999, Overhead 6000–7999) to Fusion **account types**
  (Asset/Liability/Owner's Equity/Revenue/Expense). A COA master that publishes
  these ranges plus a base-type and year-end clear flag per type is a near-direct
  input to Fusion account-type and close configuration — capture it.
- Treat a **shared single chart across many companies** as a strong signal for a
  single Fusion COA structure with company as a balancing segment — but confirm
  the companies are genuinely on one chart (the COA master will say) rather than
  assuming it from balances.
- Flag *value-set logic disguised as accounts* — suspense, clearing,
  due-to/due-from, held checks — and **closed/inactive entities or accounts**
  (often flagged in the master) as conversion-scope decisions, not automatic
  carryovers.

### Inferring the operating model

From accounts, names, and relationships, reconstruct: legal entities and how many,
ledger needs (single vs. multi-ledger, currencies), business units, intercompany
relationships (due-to/due-from accounts are a direct map to IC balancing), and the
**industry process fingerprint**. Account names are evidence — e.g. `Contr Income`,
`Contract Over-Under Adj`, `Billings Exc Cost and Erngs`, `Cost And Erng in Exc
Billngs`, retainage AR/AP, and stored-materials accounts together fingerprint
**percentage-of-completion construction accounting**, which carries specific
Fusion implications (Project-driven revenue, PPM interplay, retainage handling).

State the operating model as inferences the user can correct.

---

## Step 3 — Translate to Fusion (three output streams)

Every profile resolves into three streams. Be specific to setup objects and named
tasks — "configure the COA" is not an output; "6-segment COA with a dedicated
intercompany balancing segment because the data shows N entities with due-to/from
balances" is.

**1. Configuration items** — Fusion setup the as-is implies. COA segment design and
value sets, primary/secondary ledgers and reporting currencies, balancing-segment
and intercompany-balancing rules, accounting calendar, account hierarchies, AP/AR
transaction setup, FA categories/books, Cash Management bank setup, Tax config or
Avalara, security/data-access model. For each, give the *why* from the data.

**2. Conversion items** — what must be migrated and the strategy/risk for each.
Opening balances (and whether they're clean), open AP/AR items, supplier/customer
masters, asset cost+reserve, historical balances for reporting. Call out
**conversion blockers**: embedded segments that must be demolished and rebuilt,
unclosed prior-year plugs that must not convert as opening balances, suspense and
clearing balances that need resolution before cutover, currency mixing, and data
quality gaps.

**3. Current-state summary** — the narrative an implementation lead needs: what
this organization is, how it's structured, how it operates, and the headline risks.
Quantified, with inferences flagged.

---

## Step 4 — Surface decisions, name the gaps

Close every profile with the forks in the road and the missing inputs:

- **Design decisions the client must make** — where Fusion forces a choice or a
  process change (e.g. embedded-company-in-account will not survive; choose a
  balancing-segment strategy).
- **Leading-practice gaps** — where the as-is diverges from how high-performing
  organizations run, framed as a decision, not a criticism.
- **What's missing** — what you'd request next to complete the picture (a COA
  export with rollups, a period of GL detail for volume sizing, the supplier
  master, the FA register). Be specific about *why* each is needed.

---

## Report Mode

When a report/deliverable is requested, produce **executive prose anchored by
structured reference elements**, organized to the engagement phase (Discovery &
Assessment for a profiling deliverable). Lead with a current-state narrative that
reads like a consultant wrote it, then anchor it with:

- **Artifact inventory** — files received, type, source system (inferred), grain.
- **Inferred enterprise structure** — entities, ledgers, BUs, intercompany map.
- **Proposed COA model** — segment table with meaning, cardinality, source.
- **Configuration register** — setup item → rationale → Fusion object/task.
- **Conversion register** — object → strategy → risk/blocker → disposition.
- **Decision log** — open design decisions with options and a recommendation.
- **Gap / next-data-request list.**

For a file deliverable, hand off to the `docx` skill (narrative report) or `xlsx`
skill (registers/workbooks) — do not hand-format. Tie findings to the Discovery &
Assessment phase and to leading practice throughout.

---

## Principles

- Detect before you profile; never assume the layout.
- Quantify with code before you opine; mark inferences as inferences.
- Lead with the functional *why*, then the setup *how*.
- The enterprise structure is usually in the relationship between files, not in one.
- Balances suggest structure; the COA master defines it. Never finalize a segment
  model from a trial balance alone, and let a later artifact overturn an earlier
  inference cleanly — cross-artifact correction is expected, not a failure.
- Respect Fusion's opinionated design; name the change-management cost of legacy
  quirks rather than promising to replicate them.
- Stay version-aware — Oracle ships quarterly; flag version-sensitive guidance.
- Conversational by default; structured-plus-prose only when a report is asked for.

---

## Worked example — multi-company construction trial balance

A client provides a set of TB PDFs, one per company (08, 10, 12, 23, 28, 30, 32,
74, 76, 77, plus references to 01/04). Profiling yields:

- **Detection** — Trial balance, PDF, `GL2000`/`V12-020-2` footers → Sage/Timberline
  -family construction ERP (inferred). The set is *one enterprise*, not ten clients.
- **Segment model — corrected by the COA master.** From the trial balances alone,
  the `NNNN.SS` mask looked like *account.company* (suffix = entity). The COA
  dictionary overturns this: the suffix is a **sub-account/child qualifier** (805
  natural-account roots × 68 suffixes = ~2,312 accounts, hierarchical via control
  accounts, three levels), and **company is a separate dimension** — 34 companies
  all sharing one chart (`01CHART`), with a consolidation grouping code. The true
  model is Company (balancing) + Natural Account/Sub-account (hierarchical) +
  Department/Division (~421 depts with parent rollups and a business-unit field).
  This is the canonical lesson: balances *suggest* structure, the COA master
  *defines* it, and the second artifact corrected the first.
- **Account-type ranges are a conversion gift** — the master publishes sequence
  ranges per type (CA 1000–1599, COS 5000–5999, OE 6000–7999, etc.) with base
  type and a year-end clear flag, mapping almost directly to Fusion account types
  and close config.
- **Scope decision** — many companies and accounts are flagged CLOSED/inactive in
  the master; converting them is a decision, not a default.
- **Operating model** — JV-heavy construction enterprise (Moss & Associates + JVs:
  Moss/Anderson, J Benton/Moss, Moss/Kiewit, Hunt-Moss, Hunt Pendleton, Hunt Yuma),
  each with own bank accounts and branding → multiple legal entities, multi-LE
  ledger strategy, intercompany via `Due To-From Moss` / `Due From Hunt Yuma`.
- **Industry fingerprint** — POC construction accounting (Contr Income, Over/Under
  Adj, over/underbillings, retainage AR/AP, stored materials, `1450.00 Stored
  Materials YE Reclass`) → PPM/Projects interplay, retainage handling,
  project-driven revenue, and year-end reclass behavior at period close.
- **Period-scope trap** — the client delivered two sets of the *same* entities at
  different windows (Period 3→3 single-period vs. Period 1→4 / 1→12 YTD, different
  run dates). Same opening balances and COA; activity totals differ purely by
  window (e.g. company 76 grand-total debit ~16.5M single-period vs. ~75.5M YTD).
  These are two views of one ledger — deduplicate by company number, never union,
  and never read the larger total as real growth.
- **COA completeness** — the wider YTD window exposes accounts the single-period
  pull never showed (`2590.00 Other Accruals`, `8120.01 Other Income`, `7080.00
  Audit And Tax`, and a fuller overhead chart on company 74). Derive the COA from
  the widest window; treat any single-period extract as a lower bound and request
  a full-year pull.
- **Conversion flags** — entities with `Profit/Loss From Unclosed Years` plugs
  (08, 10, 23, 28) carry unclosed prior years that must not convert as opening
  balances; `9998.00 Suspense - AP AR Clearing` and `1005.00 Held Checks` need
  resolution pre-cutover; year-end reclass entries (stored materials) risk
  double-counting in conversion; mixed self-balancing vs. non-zeroing entities.

This is the depth bar for any artifact the skill profiles.
