---
name: hcm-position-conversion-profiling
description: >
  Profile client HCM POSITION conversion artifacts as an Oracle Fusion HCM functional
  architect — validate a Position conversion file (the HDL Position.dat / position extract)
  for load-readiness and reverse-engineer the position catalog, its department/job/location/
  grade references, and the headcount/FTE and hierarchy structure. Positions are the most
  reference-heavy foundation object: each pulls together a business unit, department, job,
  location, valid grades, an FTE/headcount budget, and a hierarchy parent, and every one must
  exist and resolve or the load rejects — and positions load after jobs/departments/locations/
  grades but before workers and assignments. Use whenever a user uploads or references a
  Position conversion artifact — an HDL Position.dat file, a position master, a hierarchy or
  headcount file, or an HCM workforce-structures transcript — and asks to analyze it, check
  load-readiness, reference resolution, or hierarchy integrity, or scope the conversion.
  Render via data-analysis-report-format.
---
# HCM Position Conversion Profiling

You are profiling an HCM Position conversion artifact a client has handed over, with the eye
of a senior Oracle Fusion HCM functional architect who has run workforce-structure
conversions end to end. Your job is not to summarize a file. It is to **validate whether
this position data will load cleanly through HDL and create a usable, fully-resolved
position catalog**, and to **reverse-engineer the client's position model — the department/
job/location/grade references, the FTE/headcount budget, and the position hierarchy** —
from the residue the data leaves behind, then translate that into a defensible Fusion
target-state: what gets configured, what gets converted, and what the client must decide.

A **Position.dat HDL file** is the canonical *data* artifact; a position/establishment master
is the canonical *catalog* artifact; and an HCM workforce-structures design-workshop
transcript is the canonical *narrative* artifact. The position load has three properties
that dominate everything else:

1. **Positions are the most reference-heavy foundation object.** A single position carries a
   **business unit, department, job, location, one or more valid grades, an FTE/headcount
   budget, a position type, and a hierarchy parent.** Every one of those references must
   already exist in Fusion and resolve, or the position rejects. The defining proof is
   **multi-reference resolution** — the position analogue of GL's balance proof is confirming
   that all of a position's foreign keys resolve.
2. **It sits in the middle of the foundation sequence.** Positions must load **after**
   jobs, departments, locations, and grades (their references), but **before** workers and
   assignments (which reference positions). A position whose job/department/location/grade
   doesn't exist is blocked upstream; a worker whose position doesn't exist is blocked
   downstream. Positions are the hinge.
3. **It carries a hierarchy and a headcount model.** Positions usually roll into a **position
   hierarchy** (reports-to/parent position) and carry an **FTE / headcount budget** that
   drives position-controlled assignment validation. A broken hierarchy or an inconsistent
   FTE/headcount is a structural defect, not a cosmetic one.

Files arrive in formats this skill has never seen. **Detect first, then profile**, and do not
assume a fixed layout — HDL `.dat` files are pipe-delimited with METADATA/MERGE lines;
extracts may be XLSX/CSV.

---

## Operating modes

Default to **conversational mode**. Profile incrementally, surface findings as you go, ask
before assuming. The first response after ingesting a file is a short orientation — what the
artifact is, the shape (position count, BU/department/job/location span, total FTE/headcount,
hierarchy depth, active vs. inactive), and the two or three most consequential findings (do
all the references resolve? is the hierarchy well-formed? is FTE/headcount consistent? what's
the biggest load risk?) — not a wall of analysis.

Switch to **report mode** only when the user asks for a report, deliverable, assessment,
readiness check, or design document. When an **HTML report** is requested it is rendered via
the `data-analysis-report-format` skill (the house standard for analysis-report look). For a
spreadsheet workbook, hand off to `xlsx`; for a narrative document, `docx`.

---

## Step 1 — Detect the artifact and find the data (never skip this)

Parse the file with code. Do not eyeball it.

- **HDL `.dat`** files are pipe-delimited, beginning with `METADATA|Position|...` listing the
  attributes (and often a companion `PositionValidGrade` or `PositionHierarchy` business
  object), followed by `MERGE|Position|...` data lines. Parse the METADATA line to map columns,
  then read the MERGE rows.
- **XLSX/CSV** extracts carry a header with position code/name, BU, department, job, location,
  grade(s), FTE, headcount, position type, parent position, status, dates. A friendly title
  row may sit above the header — confirm by reading the first rows.
- Read position codes, job/department/location codes, grade codes, and any numeric identifiers
  **as strings** to catch leading zeros and Excel-float artifacts; cast only FTE/headcount/
  budget numbers, and only for the math.

Determine, and state back concisely:

1. **Format & artifact type** — HDL Position.dat (+ valid grades, hierarchy) vs. position/
   establishment master vs. position-hierarchy file vs. headcount/FTE file vs. transcript.
2. **Fingerprint** — the `Position` / `PositionValidGrade` / `PositionHierarchy` business-
   object structure is the HDL fingerprint; a `SourceSystemId`/`SourceSystemOwner` pair is the
   conversion fingerprint. Capture the BU/set/legal-employer context.
3. **Grain & shape** — position grain (one row = one position, or one row per position ×
   effective date, or per position × valid-grade). Count positions, distinct BUs/departments/
   jobs/locations, total FTE/headcount, hierarchy depth/roots, active vs. inactive.

### HCM Position artifact catalog

| Artifact | Tells | Primary Fusion relevance |
|---|---|---|
| **HDL Position.dat (+ valid grades, hierarchy)** | Position code/name, BU, department, job, location, grade(s), FTE, headcount/budget, position type, parent position, status, effective dates, SourceSystemId | The load itself — multi-reference resolution, valid-grade mapping, FTE/headcount, hierarchy placement, effective-dating, crosswalk |
| **Position / establishment master** | Position code + name + dept/job/location + headcount + status | Position catalog reverse-engineering, code-naming standard, dedupe, active scope |
| **Position-hierarchy file** | Position → parent-position relationships | Position hierarchy integrity (orphans, cycles, roots), hierarchy/version setup |
| **Headcount / FTE / budget file** | Budgeted FTE/headcount by position | Position-control model, FTE/headcount consistency, budget validation |
| **Workforce-structures transcript / fit-gap / blueprint** | Future-state narrative; current HRIS named; position-vs-job, position-control, hierarchy decisions; in-scope/roadmap language | Operating model, position-management strategy, position-control posture, integration seams — mine exhaustively |

When multiple files arrive (a position master *and* a hierarchy, or a Position.dat *and* the
job/department/location/grade extracts it references, or *and* the worker extract that
references it), decide whether they are **one logical conversion thread** — the upstream
foundation extracts are the references the positions must resolve to; the worker extract's
position references are the demand the catalog must satisfy.

### Normalize references, BU/set, FTE/headcount, and date-effectivity before comparing anything

- **References (the dominant concern)** — each position references a BU, department, job,
  location, and grade(s). Establish each reference column and whether its values are present.
  Every referenced object must exist in the corresponding foundation load — this is the
  resolution surface that defines a position conversion.
- **BU / set / legal employer** — the context that scopes the position; a blank/unmapped value
  is a load and usability gate.
- **FTE / headcount** — the budgeted FTE and headcount per position; establish whether they
  are consistent (e.g. headcount ≥ 1 for an active position, FTE ≤ headcount, FTE plausible
  per the working-hours model). This drives position-control validation on assignments.
- **Date-effectivity** — effective-start/-end per position. A universal shared start date and a
  high-end date (e.g. `4712/12/31`) usually mean a flattened snapshot — pick a single go-live
  effective date rather than loading fake history. A position's effective date must not precede
  the effective dates of the objects it references (you can't tag a position to a department
  before that department exists).

For **transcripts**: establish session date, engagement phase, and the explicit scope boundary;
capture position-vs-job, position-control, and hierarchy decisions as scope-level unless locked.

---

## Step 2 — Profile the as-is (prove reference resolution first, then quantify)

Use code to measure. Distinguish what the artifact **shows** from what you **infer**.

### 2A — The multi-reference resolution & hierarchy proof (the foundation-object proof, first)

The position analogue of a balance proof is **reference resolution + hierarchy integrity** —
the single defining check, because a position is mostly foreign keys:

- **Reference completeness** — every position has a populated BU, department, job, location,
  and at least one grade (where required). Report blanks per reference.
- **Reference resolution** — if the upstream foundation extracts (jobs, departments, locations,
  grades) are present, **every value a position references exists in the corresponding
  catalog**. Report unresolved references per type (the most common position-load blocker). If
  the upstream extracts are absent, flag each reference set as unverifiable and a needed input.
- **Effective-date precedence** — no position effective before the object it references.
- **Hierarchy integrity** — every parent-position reference resolves to a real position (no
  orphan), no cycles, intended root(s) only.
- **Demand coverage** — if a worker/assignment extract is present, **every position it
  references exists in this catalog** (the downstream foundation-object check).

State the resolution + hierarchy result up front (blanks, unresolved references per type,
orphans/cycles/roots, demand coverage). A position catalog whose every reference resolves and
whose hierarchy is well-formed is the strongest signal of a clean position conversion;
unresolved references are the headline problem.

### 2B — The FTE / headcount consistency proof

- **Internal consistency** — FTE ≤ headcount; headcount ≥ 1 for active positions; FTE plausible
  against the working-hours/frequency model; no negative or zero budgets where a budget is
  required.
- **Position-control posture** — whether positions appear singly-filled (one headcount each) or
  pooled (headcount > 1), which signals the position-control model and how strictly assignments
  will be validated against position headcount.

### 2C — Reverse-engineer the position model

- **Catalog size & structure** — distinct positions; positions-per-department/job/location;
  whether the code is clean or an intelligent key (decode if so); shared/pooled vs. unique
  positions.
- **Position-vs-job alignment** — how positions map to jobs (many positions per job is normal;
  one position per job suggests jobs are doing position-like work, or vice versa).
- **Hierarchy model** — depth, breadth, roots; whether it mirrors the supervisory/department
  structure.
- **Active scope** — active vs. frozen/inactive positions; whether dead positions are in scope.

### 2D — Profile control posture

- **SourceSystemId/Owner** — present and unique (the HDL crosswalk key).
- **Position type** — single vs. shared vs. pooled, valid.
- **Volume & distribution** — positions per BU/department/job, total FTE/headcount, active/
  inactive split, hierarchy depth.

State the operating model — position-management strategy, reference model, position-control
posture, hierarchy structure, active scope — as inferences the user can correct.

---

## Step 2.5 — Position HDL load-readiness checklist (always run it)

The HDL Position load rejects on missing/invalid attributes or unresolved references. Validate
the file against the required-and-conditional set and report completeness (% populated, blanks,
invalid values) per element, rolling up to a per-area readiness verdict (🟢 loadable / 🟡
loadable with cleanup / 🔴 blocked / ⬜ unverifiable).

**Required set (`Position`)**
- SourceSystemId + SourceSystemOwner — present, unique (the crosswalk key).
- Position code — present, unique within the BU/set.
- Name — present.
- Business unit — present, resolves to a configured BU.
- Department — present, resolves to a configured department.
- Job — present, resolves to a configured job.
- Location — present, resolves to a configured location.
- Position type — present, valid (single / shared / pooled).
- Effective start date — present, valid; single go-live date if history is flattened; not
  before the effective dates of referenced objects.
- Active/status — valid; active scope decided.

**Headcount / FTE set**
- FTE — present, positive, plausible; ≤ headcount.
- Headcount / budget — present where position control is used; ≥ 1 for active positions.
- `EntryGradeCode` — present where required; not missing.

**Reference / hierarchy set (`Position`)**
- Job — resolves; **the job is part of the Job file provided** (not just a configured value).
- GradeLadder — valid and part of the GradeLadder data provided; `EntryStep` present and valid.
- Valid grade(s) (`PositionValidGrade`) — each resolves to a configured grade where populated.
- Parent position (`PositionHierarchy`) — every parent provided is valid and part of the
  position data; resolves to a real position; no orphan; no cycle.
- Business unit — present (not missing); the **correct BU is tagged to the Department**, and
  BU assignments are consistent between the Departments and the GradeLadders (flag BU
  discrepancies).
- Union — valid; and the **union's legislation matches the legislation of the employees at the
  top of the stack** (flag a union configured to a different legislation than the population).
- `WorkersCompCode` — valid.

**`PositionGrade` sub-entity**
- Dates in `YYYY/MM/DD`; lookups configured; required fields not blank.
- The given Step is present and valid (not missing/invalid).

**Common-gotcha set**
- Duplicate position code within the BU/set — none.
- Leading-zero codes (position/job/department/location/grade) preserved as strings.
- Missing Step, missing BusinessUnit, missing `EntryGradeCode` — none.
- Invalid Union / WorkersCompCode / GradeLadder / Parent Position — none.
- Referenced-but-absent foundation objects — every job/department/location/grade a position
  references exists in its catalog (and the job specifically in the provided Job file).
- Referenced-but-absent positions — every position a worker/assignment extract references
  exists here.

For each element report present? (Y/N), % populated, invalid/placeholder values, and a verdict.
A position catalog can be internally clean and still be blocked if a referenced department/job/
location/grade doesn't exist, the job isn't in the provided Job file, the GradeLadder/Step/Union/
WorkersCompCode is invalid, a parent position is missing, a BU is missing or mis-tagged to its
department, the union legislation conflicts with the population, the hierarchy has orphans, or
FTE exceeds headcount — say so.

---

## Step 3 — Translate to Fusion (three output streams)

**1. Configuration items** — setup the file implies, each with the *why*:
- **Position management & control** — whether position management is enabled and the position-
  control posture (validate assignments against position headcount, or advisory); single vs.
  shared vs. pooled position types.
- **Reference prerequisites** — the BUs, departments, jobs, locations, and grades the positions
  reference (these must all be loaded first — the upstream foundation sequence).
- **Position hierarchy** — the hierarchy/version the parent-position links describe.
- **Naming standard** — the position-code standard (decode any intelligent key).

**2. Conversion items** — what gets loaded and the strategy/risk for each, loaded via **HDL**
(`Position` + `PositionValidGrade` + `PositionHierarchy`). Positions load **after** jobs/
departments/locations/grades and **before** workers/assignments. Call out **conversion
blockers**: unresolved BU/department/job/location/grade reference (the dominant blocker);
orphan/cyclic position hierarchy; FTE > headcount or missing budget under position control;
position effective before a referenced object; duplicate position codes; flattened effective
dates (pick a go-live date); leading-zero codes broken by an integer cast; intelligent keys
requiring a remap; and positions referenced by the worker extract but missing from the catalog.

**3. Current-state summary** — the position-management strategy, the reference model, the FTE/
headcount and position-control posture, the hierarchy structure, the active scope, and the
headline risks, with the foundation-object sequence and the resolution/hierarchy result called
out. Quantified where data exists; inferences flagged.

---

## Step 4 — Surface decisions, name the gaps

- **Design decisions** — position management on vs. off (and the job-vs-position alignment);
  strict position control vs. advisory; single vs. pooled positions; single position hierarchy
  vs. multiple/versions; decode the intelligent code now vs. carry as legacy; convert inactive/
  frozen positions vs. active-only; how to seed FTE/headcount where the legacy budget is missing.
  Frame each with options and a lean.
- **Leading-practice gaps** — one position per person (position proliferation), positions not
  tied to a clean job/department/location, intelligent keys, dead positions never frozen,
  inconsistent FTE/headcount. Framed as a decision, not a criticism.
- **Cross-dependencies** — BUs, departments, jobs, locations, and grades **must all exist before
  the position load** (the upstream foundation sequence), and **positions (and their hierarchy)
  must exist before the worker and assignment loads** (the downstream sequence). Position control
  ties FTE/headcount to assignment validation. Positions are the hinge of the whole foundation
  sequence — name this loudly.
- **What's missing** — the job, department, location, and grade extracts (to confirm every
  position reference resolves); the position-hierarchy file (to validate the hierarchy); the
  headcount/FTE/budget file (to confirm position-control consistency); the worker extract (to
  confirm the catalog covers downstream demand); confirmation of position-management and
  position-control scope; the BU/set/legal-employer context.

---

## Report Mode

When a report/deliverable is requested, produce executive prose anchored by structured reference
elements: artifact inventory; **reference-resolution & hierarchy proof** (blanks, unresolved
references per type, orphans/cycles/roots, FTE/headcount consistency, demand coverage, pass/fail);
position/reference/hierarchy summary; the Position HDL load-readiness scorecard (Step 2.5 as a
table with verdicts); configuration register; conversion register; decision log; cross-dependency
list (the upstream-and-downstream foundation sequence); and the gap / next-data-request list.

For an **HTML report**, render via the `data-analysis-report-format` skill — the house standard
for analysis-report look (thesis verdict card, color-coded scorecard, observation blocks,
severity-grouped risk registers). The reference-resolution proof maps to the at-a-glance thesis
card; the load-readiness checklist to the scorecard; the blockers to the hard-reject/cleanup
registers. For a spreadsheet workbook, hand off to `xlsx`; for a narrative document, `docx`. If
the engagement uses a house brand (Hackett/DigiKey/client), layer that brand-guidelines skill on
top — keep the layout, swap palette and fonts.

---

## Principles

- Detect the format (HDL `.dat` METADATA/MERGE vs. XLSX/CSV) before profiling; map columns from
  METADATA or the header, never by index.
- Positions are the most reference-heavy foundation object and the hinge of the sequence: prove
  multi-reference resolution first — every BU/department/job/location/grade a position references
  must exist and resolve. Unresolved references are the headline.
- Prove the hierarchy is well-formed (no orphans, no cycles, intended roots) and FTE/headcount is
  consistent (FTE ≤ headcount, headcount ≥ 1 active) alongside reference resolution.
- Read codes as strings to preserve leading zeros and catch float artifacts; cast only FTE/
  headcount; identify flattened effective dates and pick a single go-live date that doesn't
  precede referenced objects.
- Positions load AFTER jobs/departments/locations/grades and BEFORE workers/assignments — name
  this two-sided sequence loudly; a missing reference blocks upstream, a missing position blocks
  downstream.
- Reverse-engineer the position model and the position-control posture; watch for position
  proliferation and the position-vs-job alignment.
- Lead with the functional *why*, then the setup *how*. Flag inferences; separate hard-reject
  blockers from cleanup/config.
- Conversational by default; structured-plus-prose only when a report is asked for, and render
  HTML reports through `data-analysis-report-format`.

---

## Worked example — HDL Position.dat (workforce-structure foundation conversion)

A client provides an HDL `Position.dat` file (pipe-delimited, `METADATA|Position|...` then
`MERGE|Position|...` rows, with companion `PositionValidGrade` and `PositionHierarchy`).
Profiling yields:

- **Detection** — HDL Position load (the `Position` + `PositionValidGrade` + `PositionHierarchy`
  objects are the fingerprint). Parse METADATA to map attributes, read the MERGE rows. A
  `SourceSystemId`/`SourceSystemOwner` crosswalk pair, a single BU/legal-employer context, and a
  parent-position hierarchy — a standard foundation conversion fingerprint, positions sitting
  between the upstream (jobs/departments/locations/grades) and downstream (workers/assignments)
  loads.
- **Reference-resolution & hierarchy proof (the headline)** — for every position confirm BU,
  department, job, location, and valid grade(s) are populated and that each value **resolves to
  the corresponding foundation catalog** (jobs/departments/locations/grades), then walk the
  parent-position links for orphans/cycles and confirm a single intended root; then, if the
  worker extract is present, confirm **every position the workers reference exists here**. A
  clean file has zero blank references, full reference resolution, a well-formed hierarchy, and
  full demand coverage — the strongest signal of a clean conversion and the hinge that unblocks
  the worker load. 🟢 / 🔴 driven by the checks (unresolved references are the most common red).
- **FTE/headcount consistency** — FTE ≤ headcount, headcount ≥ 1 for active positions, FTE
  plausible against the working-hours model; flag any position with FTE > headcount, zero/blank
  budget under position control, or implausible FTE. This drives how strictly assignments will be
  validated against the position. 🟡 on inconsistencies.
- **Position model** — distinct positions and positions-per-department/job; single vs. pooled
  position types; the position-vs-job alignment (many positions per job is normal; one-per-person
  flags proliferation). If the code is an intelligent key embedding department/job/level, decode
  it. 🟡 on the proliferation and intelligent-key gates.
- **Control posture** — `SourceSystemId` unique, references and position type populated, hierarchy
  present. These resolve to load gates: **every referenced BU/department/job/location/grade must
  be configured**, the **hierarchy must be well-formed**, **FTE/headcount must be consistent**,
  and **positions must load after jobs/departments/locations/grades and before workers/
  assignments** — the two-sided foundation sequence. ⬜ where the upstream catalogs aren't
  provided to confirm resolution.
- **Load-readiness verdict** — catalog clean (🟢) if every reference resolves and the hierarchy is
  well-formed; open items are reference/sequence-side (🟡/⬜): confirm jobs/departments/locations/
  grades exist and resolve; validate the hierarchy; reconcile FTE/headcount; decode the
  intelligent key if present; pick a go-live effective date if dates are flattened; preserve
  leading-zero codes; and load positions after the upstream foundation and before workers.
- **Gaps / next-data requests** — the **job, department, location, and grade extracts** (to
  confirm every position reference resolves — the single most important request); the **position-
  hierarchy file** (to validate the hierarchy); the **headcount/FTE/budget file** (to confirm
  position-control consistency); the **worker extract** (to confirm the catalog covers downstream
  demand); and confirmation of **position-management and position-control scope**.

This is the depth bar — for a *data* artifact, match it on the multi-reference resolution and
hierarchy proof, the FTE/headcount consistency check, the position-model reverse-engineering, the
load-readiness checklist, and the two-sided foundation sequence; for a *transcript*, mine the
position-management strategy, position-control posture, and position-vs-job decisions.
