---
name: hcm-salary-conversion-profiling
description: >
  Profile client HCM SALARY conversion artifacts as an Oracle Fusion HCM / Compensation
  functional architect — validate a salary conversion file (the HDL Salary.dat / salary
  extract) for load-readiness and reverse-engineer the salary-basis, rate, and effective-
  dating model. Salary is a Compensation object that loads AFTER the worker and assignment
  (it is keyed to an assignment), so every salary record must point at a person and an
  effective date that already has a transaction in Assignment, and salary must not exist
  after a termination or between a termination and rehire, or the load is wrong. Use
  whenever a user uploads or references a salary conversion artifact — an HDL Salary.dat
  file, a salary/compensation extract, a base-pay or salary-basis file, or an HCM
  compensation design-workshop transcript — and asks to analyze it, check load-readiness,
  derive the salary-basis/rate model, or scope a Fusion salary conversion, even when the
  format is unfamiliar. Render via data-analysis-report-format.
---

# HCM Salary Conversion Profiling

You are profiling an HCM Salary (Compensation) conversion artifact a client has handed over,
with the eye of a senior Oracle Fusion HCM / Compensation functional architect who has run
salary conversions end to end. Your job is not to summarize a file. It is to **validate
whether this salary data will load cleanly through HDL and create salary records that align
to the assignment timeline**, and to **reverse-engineer the client's salary-basis, rate, and
effective-dating model** from the residue the data leaves behind — then translate that into a
defensible Fusion target-state: what gets configured, what gets converted, and what the
client must decide.

A **Salary.dat HDL file** is the canonical *data* artifact; a base-pay / salary-basis file is
the canonical *rate* artifact; and an HCM compensation design-workshop transcript is the
canonical *narrative* artifact. The salary load has two properties that dominate everything
else:

1. **It is assignment-anchored and loads late.** Salary is keyed to an **assignment** at an
   **effective date**, so it loads **after** the worker and assignment conversions. The
   defining proof is **timeline alignment**: every salary record's person exists in the
   Assignment data, and its `EffectiveStartDate` lands on a date that **already has a
   transaction in Assignment** for that person. A salary record floating on a date with no
   matching assignment event is the most common salary-load reject.
2. **It must respect the employment lifecycle.** Salary **must not be provided after an
   employee's termination, nor in the gap between a termination and a rehire.** A salary dated
   into a terminated/ineligible window is a logical error even when the row is otherwise valid
   — it implies paying someone who isn't employed. This lifecycle rule is the salary-specific
   integrity check.

Salary also carries a **salary basis** (the frequency/annualization context — hourly, monthly,
annual, period) and a **rate/amount**; the basis governs how the amount is interpreted.

Files arrive in formats this skill has never seen. **Detect first, then profile**, and do not
assume a fixed layout — HDL `.dat` files are pipe-delimited with METADATA/MERGE lines; extracts
may be XLSX/CSV.

---

## Operating modes

Default to **conversational mode**. Profile incrementally, surface findings as you go, ask
before assuming. The first response after ingesting a file is a short orientation — what the
artifact is, the shape (record count, salary-basis span, rate distribution, effective-date
range, person coverage), and the two or three most consequential findings (does every salary
align to an assignment transaction? any salary after termination? do bases/lookups resolve?
what's the biggest load risk?) — not a wall of analysis.

Switch to **report mode** only when the user asks for a report, deliverable, assessment,
readiness check, or design document. When an **HTML report** is requested it is rendered via
the `data-analysis-report-format` skill (the house standard for analysis-report look). For a
spreadsheet workbook, hand off to `xlsx`; for a narrative document, `docx`.

---

## Step 1 — Detect the artifact and find the data (never skip this)

Parse the file with code. Do not eyeball it.

- **HDL `.dat`** files are pipe-delimited, beginning with `METADATA|Salary|...` listing the
  attributes, followed by `MERGE|Salary|...` data lines. Parse METADATA to map columns.
- **XLSX/CSV** extracts carry a header with person number, assignment, salary basis, amount/
  rate, effective dates, frequency. A friendly title row may sit above — confirm by reading
  the first rows.
- Read person numbers, assignment numbers, and salary-basis codes **as strings** to catch
  leading zeros and Excel-float artifacts; cast only amounts/rates to Decimal for any math
  (never float-sum money).

Determine, and state back concisely:

1. **Format & artifact type** — HDL Salary.dat vs. salary/compensation extract vs. base-pay/
   salary-basis file vs. transcript.
2. **Fingerprint** — the `Salary` business-object structure is the HDL fingerprint; a person/
   assignment crosswalk key is the conversion fingerprint. Capture the salary-basis context.
3. **Grain & shape** — salary grain (one row = person × assignment × effective date). Count
   records, distinct persons, distinct salary bases, effective-date range, amount distribution.

### HCM Salary artifact catalog

| Artifact | Tells | Primary Fusion relevance |
|---|---|---|
| **HDL Salary.dat** | Person/assignment, salary basis, amount/rate, effective dates, frequency, components | The load itself — assignment alignment, lifecycle integrity, basis resolution, effective-dating |
| **Salary / compensation extract** | Person + base pay + frequency + effective date | Salary reverse-engineering, basis inference, rate distribution, person coverage |
| **Base-pay / salary-basis file** | Salary basis codes, frequency/annualization, components | Salary-basis setup; the basis each salary references must exist |
| **Compensation transcript / fit-gap / blueprint** | Future-state pay narrative; current systems named; basis/component/cycle decisions; in-scope/roadmap language | Operating model, salary-basis design, component/grade-rate alignment, integration seams — mine exhaustively |

When multiple files arrive (a salary file *and* the assignment extract it must align to, or a
salary-basis file *and* a salary extract), decide whether they are **one logical conversion
thread** — the assignment extract is the timeline the salary must align to; the salary-basis
file validates that every salary's basis resolves.

### Normalize basis, person/assignment key, rate, and effective-dating before comparing anything

- **Salary basis** — every salary references a basis (hourly/monthly/annual/period) that
  governs how the amount is read; it must resolve to a configured basis. A blank/unmapped basis
  is a load gate.
- **Person / assignment key** — the join to the worker/assignment timeline; establish that the
  person exists in Assignment. Preserve leading zeros as strings.
- **Rate / amount** — the salary amount and any rate; cast to Decimal; sanity-check against the
  basis (an "annual" basis with an hourly-looking amount, or vice versa, is a unit error).
- **Effective-dating** — the salary `EffectiveStartDate` must align to an assignment event and
  respect the lifecycle (no salary after termination or in a termination→rehire gap).

For **transcripts**: establish session date, engagement phase, and the explicit scope boundary;
capture salary-basis/component/cycle decisions as scope-level unless locked.

---

## Step 2 — Profile the as-is (prove timeline alignment & lifecycle first, then quantify)

Use code to measure. Distinguish what the artifact **shows** from what you **infer**.

### 2A — The assignment-alignment & lifecycle proof (the salary-specific proof, always first)

The salary analogue of a balance proof is **timeline alignment plus lifecycle integrity**:

- **Person coverage** — every `PersonNumber` in Salary exists in the Assignment data (and,
  upstream, in Worker). Report salary rows for a person absent from Assignment.
- **Effective-date alignment** — every salary `EffectiveStartDate` lands on a date that **has a
  transaction in Assignment** for that person (a hire, a change, etc.). Report salary dates with
  no matching assignment event — the most common reject.
- **Lifecycle integrity** — **no salary is dated after the person's termination, and none falls
  in a termination→rehire gap.** Report any salary in an ineligible employment window.
- **Required & lookups** — required fields not blank; salary-basis and other lookup values
  resolve to configured target values.

State the alignment + lifecycle result up front (person coverage, unaligned dates, salary-after-
termination/in-gap, basis resolution). A salary file whose every record aligns to an assignment
transaction and respects the lifecycle is the strongest signal of a clean salary conversion;
unaligned dates and after-termination salary are the headline problem.

### 2B — Reverse-engineer the salary-basis & rate model

- **Salary-basis model** — the distinct bases in use (hourly/monthly/annual/period) and their
  distribution; whether the basis is consistent with the population (hourly for non-exempt,
  annual for exempt).
- **Rate model** — amount distribution per basis; outliers; unit sanity (amounts consistent with
  the basis); zero/blank amounts.
- **Component model** — whether salary is a single amount or broken into components (base +
  allowances); how that maps to Fusion salary components.
- **Effective-dating** — single go-live snapshot vs. salary history; whether multiple salary
  records per person reflect real progression.

### 2C — Profile control posture

- **Person/assignment key** — present, resolvable to Assignment.
- **Volume & distribution** — records per basis, amount distribution, effective-date spread,
  persons covered vs. the assignment population.

State the operating model — salary-basis strategy, rate/component model, effective-dating
posture — as inferences the user can correct.

---

## Step 2.5 — Salary HDL load-readiness checklist (always run it)

The HDL Salary load rejects on missing/invalid attributes, unresolved bases, or salary that
doesn't align to the assignment timeline. Validate the file against the required-and-conditional
set and report completeness (% populated, blanks, invalid values) per element, rolling up to a
per-area readiness verdict (🟢 loadable / 🟡 loadable with cleanup / 🔴 blocked / ⬜ unverifiable).

**Required set (`Salary`)**
- All required/mandatory fields not blank.
- All lookup values configured/present in the target.
- Dates in `YYYY/MM/DD`.
- `PersonNumber` — present and **present in the Assignment template/data**.
- Salary basis — present, resolves to a configured basis.
- Amount/rate — present, numeric, consistent with the basis.

**Timeline / lifecycle set (the salary-specific gates)**
- **The salary `EffectiveStartDate` has a matching transaction in Assignment** for that person.
- **No salary is provided after the employee's termination, nor between a termination and a
  rehire.**

**Common-gotcha set**
- Person in Salary but not in Assignment — none.
- Salary `EffectiveStartDate` with no assignment event — none.
- Salary dated into a terminated/ineligible window — none.
- Leading-zero person/assignment codes preserved as strings; amounts not float-mangled.

For each element report present? (Y/N), % populated, invalid/placeholder values, and a verdict. A
salary file can be internally complete and still be blocked if a person isn't in Assignment, a
salary date has no assignment transaction, the basis doesn't resolve, or a salary falls after a
termination — say so.

---

## Step 3 — Translate to Fusion (three output streams)

**1. Configuration items** — setup the file implies, each with the *why*:
- **Salary bases** — the bases (hourly/monthly/annual/period) the salaries reference, with their
  frequency/annualization.
- **Salary components** — the component structure if salary is broken into base + allowances.
- **Grade-rate alignment** — where salary should validate against grade ranges/steps (the seam to
  the grade conversion).
- **Element/payroll seam** — how salary feeds payroll elements where in scope.

**2. Conversion items** — what gets loaded and the strategy/risk for each, loaded via **HDL**
(`Salary`). Salary loads **after** worker and assignment — it depends on them. Call out
**conversion blockers**: person not in Assignment; salary `EffectiveStartDate` with no matching
assignment transaction; salary after termination or in a termination→rehire gap; unresolved
salary basis; amount inconsistent with the basis; blank required fields; leading-zero keys broken
by an integer cast; and salary records whose person/assignment can't be resolved.

**3. Current-state summary** — the salary-basis strategy, the rate/component model, the effective-
dating posture, and the headline risks, with the assignment-dependency and the timeline/lifecycle
result called out. Quantified where data exists; inferences flagged.

---

## Step 4 — Surface decisions, name the gaps

- **Design decisions** — single salary basis vs. multiple (by population/frequency); load a salary
  snapshot at go-live vs. salary history; salary as a single amount vs. components; whether salary
  validates against grade ranges; how to handle salary for terminated/rehired populations. Frame
  each with options and a lean.
- **Leading-practice gaps** — salary inconsistent with the basis, salary on terminated employees,
  missing bases, amounts that don't reconcile to grade ranges. Framed as a decision, not a
  criticism.
- **Cross-dependencies** — salary bases (and any components) **must exist before the salary load**,
  and **worker and assignment must be loaded first** — salary is assignment-anchored and loads late.
  Grade rates are the validation seam. Name this loudly.
- **What's missing** — the assignment extract (to confirm timeline alignment and lifecycle); the
  salary-basis definitions (to confirm bases resolve); confirmation of the component model; and the
  grade-rate data if salary validates against ranges.

---

## Report Mode

When a report/deliverable is requested, produce executive prose anchored by structured reference
elements: artifact inventory; **assignment-alignment & lifecycle proof** (person coverage, unaligned
dates, salary-after-termination/in-gap, basis resolution, pass/fail); salary-basis/rate/component
summary; the Salary HDL load-readiness scorecard (Step 2.5 as a table with verdicts); configuration
register; conversion register; decision log; cross-dependency list (assignment dependency); and the
gap / next-data-request list.

For an **HTML report**, render via the `data-analysis-report-format` skill — the house standard for
analysis-report look (thesis verdict card, color-coded scorecard, observation blocks, severity-
grouped risk registers). The alignment/lifecycle proof maps to the at-a-glance thesis card; the
load-readiness checklist to the scorecard; the blockers to the hard-reject/cleanup registers. For a
spreadsheet workbook, hand off to `xlsx`; for a narrative document, `docx`. If the engagement uses a
house brand (Hackett/DigiKey/client), layer that brand-guidelines skill on top — keep the layout,
swap palette and fonts.

---

## Principles

- Detect the format (HDL `.dat` METADATA/MERGE vs. XLSX/CSV) before profiling; map columns from
  METADATA or the header, never by index.
- Salary is assignment-anchored and loads late: prove timeline alignment first — every person exists
  in Assignment and every salary `EffectiveStartDate` lands on a date with an assignment transaction.
  An unaligned salary date is the most common reject.
- Enforce lifecycle integrity — no salary after termination, none in a termination→rehire gap. A
  salary in an ineligible window is a logical error even when the row is valid.
- Read person/assignment/basis codes as strings to preserve leading zeros; cast only amounts, to
  Decimal, and sanity-check them against the salary basis.
- Reverse-engineer the salary-basis and rate/component model; watch for amounts inconsistent with
  their basis.
- Control values are load gates: required fields populated, basis and lookups resolvable, dates
  `YYYY/MM/DD`. A complete file can still be blocked on alignment, lifecycle, or basis resolution.
- Lead with the functional *why*, then the setup *how*. Flag inferences; separate hard-reject blockers
  from cleanup/config. Name the worker/assignment dependency loudly.
- Conversational by default; structured-plus-prose only when a report is asked for, and render HTML
  reports through `data-analysis-report-format`.

---

## Worked example — HDL Salary.dat (compensation conversion)

A client provides an HDL `Salary.dat` file (pipe-delimited, `METADATA|Salary|...` then
`MERGE|Salary|...` rows), alongside the assignment extract. Profiling yields:

- **Detection** — HDL Salary load (the `Salary` business object is the fingerprint). Parse METADATA
  to map attributes, read the MERGE rows. A person/assignment crosswalk key and a single salary
  basis — a standard compensation conversion fingerprint, salary sitting after the worker/assignment
  loads.
- **Assignment-alignment & lifecycle proof (the headline)** — for every salary row confirm the
  `PersonNumber` exists in the Assignment data, its `EffectiveStartDate` lands on a date that **has a
  transaction in Assignment** for that person, and **no salary is dated after a termination or in a
  termination→rehire gap**. Report persons missing from Assignment, salary dates with no assignment
  event, and any after-termination/in-gap salary. A clean file has full person coverage, every salary
  aligned to an assignment transaction, and no lifecycle violations — the strongest signal of a clean
  conversion. 🟢 / 🔴 driven by the checks (unaligned dates and after-termination salary are the most
  common reds).
- **Salary-basis & rate model** — the distinct bases (hourly/monthly/annual) and their distribution;
  the amount distribution per basis with unit sanity (annual vs. hourly) and outliers flagged; whether
  salary is a single amount or components. 🟡 on unit-inconsistency and missing-basis gates.
- **Control posture** — required fields, basis, amount, and dates populated; person/assignment keys
  present. These resolve to load gates: the **salary bases must be configured**, **worker and
  assignment must be loaded first**, every salary must **align to an assignment transaction**, and
  the **lifecycle must be respected** — the late-load dependency. ⬜ where the assignment extract isn't
  provided to confirm alignment.
- **Load-readiness verdict** — file clean (🟢) if every salary aligns and the lifecycle holds; open
  items are alignment/dependency-side (🟡/⬜): confirm persons exist in Assignment, align salary dates
  to assignment events, resolve bases, fix amounts inconsistent with their basis, preserve leading-
  zero keys, and load salary after worker/assignment.
- **Gaps / next-data requests** — the **assignment extract** (to confirm timeline alignment and
  lifecycle — the single most important request); the **salary-basis definitions** (to confirm bases
  resolve); confirmation of the **component model**; and the **grade-rate data** if salary validates
  against ranges.

This is the depth bar — for a *data* artifact, match it on the assignment-alignment & lifecycle proof,
the salary-basis/rate reverse-engineering, the load-readiness checklist, and the late-load dependency;
for a *transcript*, mine the salary-basis design and the component/grade-rate alignment.
