---
name: hcm-job-conversion-profiling
description: >
  Profile client HCM JOB conversion artifacts as an Oracle Fusion HCM functional
  architect — validate a Job conversion file (the HDL Job.dat / job extract) for load-
  readiness and reverse-engineer the job catalog, job-family/function, and set/legislation
  model. Jobs are a foundation object that must load BEFORE workers, positions, and
  assignments, so an unresolved job code or set is a downstream conversion blocker. The
  job load is set- and date-effective: each job belongs to a job set (common vs.
  legislation-specific), carries an effective-dated job code and name, and may map to a
  job family, grade, and job-function attributes that must resolve to configured values.
  Use whenever a user uploads or references a Job conversion artifact — an HDL Job.dat
  file, a job/job-code master, a job-family list, or an HCM workforce-structures design-
  workshop transcript — and asks to analyze it, check load-readiness, derive the job
  catalog, or scope a Fusion job conversion. Render via data-analysis-report-format.
---

# HCM Job Conversion Profiling

You are profiling an HCM Job conversion artifact a client has handed over, with the eye of
a senior Oracle Fusion HCM functional architect who has run workforce-structure
conversions end to end. Your job is not to summarize a file. It is to **validate whether
this job data will load cleanly through HDL and create a usable job catalog**, and to
**reverse-engineer the client's job catalog, job-family/function structure, and set/
legislation model** from the residue the data leaves behind — then translate that into a
defensible Fusion target-state: what gets configured, what gets converted, and what the
client must decide.

A **Job.dat HDL file** is the canonical *data* artifact; a job-code master is the canonical
*catalog* artifact; and an HCM workforce-structures design-workshop transcript is the
canonical *narrative* artifact. The job load has one property that dominates everything
else: **jobs are a foundation object.** Workers, positions, and assignments all reference
a job, so jobs must load — and resolve — **before** those objects. A clean job conversion
is the prerequisite that unblocks the worker and assignment loads; an unmapped or
mis-coded job is a downstream blocker, not a local cleanup item. Two further properties
shape the load: jobs are **set-enabled** (each belongs to a job set — Common Set or a
legislation/BU-specific set, which governs where the job is usable) and **date-effective**
(effective-start/-end with a job code and name).

Files arrive in formats this skill has never seen. **Detect first, then profile**, and do
not assume a fixed layout — HDL `.dat` files are pipe-delimited with a METADATA/MERGE line
structure, while extracts may be XLSX/CSV.

---

## Operating modes

Default to **conversational mode**. Profile incrementally, surface findings as you go, ask
before assuming. The first response after ingesting a file is a short orientation — what
the artifact is, the shape (job count, set(s), family span, active vs. inactive), and the
two or three most consequential findings (do codes/sets resolve to a standard pattern? is
this the full catalog or a delta? what's the biggest load risk?) — not a wall of analysis.

Switch to **report mode** only when the user asks for a report, deliverable, assessment,
readiness check, or design document. When an **HTML report** is requested it is rendered
via the `data-analysis-report-format` skill (the house standard for analysis-report look).
For a spreadsheet workbook, hand off to `xlsx`; for a narrative document, `docx`.

---

## Step 1 — Detect the artifact and find the data (never skip this)

Parse the file with code. Do not eyeball it.

- **HDL `.dat`** files are pipe-delimited, beginning with a `METADATA|Job|...` line listing
  the attributes, followed by `MERGE|Job|...` data lines (and often a companion
  `JobLegislativeInfo` or `ValidGrade` business object). Parse the METADATA line to map
  columns, then read the MERGE rows.
- **XLSX/CSV** extracts carry a header row with job code, name, set, family, status, dates.
  A friendly title row may sit above the header — confirm by reading the first rows.
- Read job codes, family codes, and any numeric identifiers **as strings** to catch leading
  zeros and Excel-float artifacts.

Determine, and state back concisely:

1. **Format & artifact type** — HDL Job.dat vs. job-code master vs. job-family/function
   list vs. transcript.
2. **Fingerprint** — the `Job` / `JobLegislativeInfo` business-object structure is the HDL
   fingerprint; a `SourceSystemId`/`SourceSystemOwner` pair is the conversion fingerprint.
   Capture the set code(s) and legislation/BU context.
3. **Grain & shape** — job grain (one row = one job, or one row per job × effective date).
   Count jobs, distinct sets, distinct families, active vs. inactive; note duplicate codes
   or names.

### HCM Job artifact catalog

| Artifact | Tells | Primary Fusion relevance |
|---|---|---|
| **HDL Job.dat** | Job code, name, set, effective dates, active status, job family, FLSA/job-function, approval/regulatory attributes, SourceSystemId | The load itself — code/name/set resolution, set assignment, family mapping, effective-dating, SourceSystemId crosswalk |
| **Job-code master extract** | Job code + name + family/function + status | Job catalog reverse-engineering, code-naming standard, dedupe, active scope |
| **Job-family / job-function list** | Family/function structure and membership | Job Family setup; the family each job maps to must exist |
| **Workforce-structures transcript / fit-gap / blueprint** | Future-state narrative; current HRIS named; set/family/job-vs-position decisions; in-scope/roadmap language | Operating model, set strategy, job-vs-position approach, integration seams — mine exhaustively |

When multiple files arrive (a job master *and* a family list, or a Job.dat *and* the worker
extract that references it), decide whether they are **one logical conversion thread** —
the family list validates that every job's family resolves; the worker extract's job
references are the demand the job catalog must satisfy.

### Normalize set, legislation, code, and date-effectivity before comparing anything

- **Set** — each job belongs to a job set. A single Common Set is the simplest model; a
  legislation- or BU-specific set is a partitioning decision. A blank/unmapped set is a
  load blocker (the set must exist and the job must be usable where workers reference it).
- **Legislation** — `JobLegislativeInfo` (FLSA status, job functions) is legislation-
  specific; multi-country catalogs need the right legislation per job.
- **Code & name** — the job-code naming standard (clean code vs. an intelligent key
  embedding family/level/location). Duplicate codes are a hard reject; duplicate names
  across distinct codes are a data-quality flag.
- **Date-effectivity** — effective-start/-end per job. A universal shared start date and a
  high-end date (e.g. `4712/12/31`) usually mean a flattened snapshot, not real history —
  pick a single go-live effective date rather than loading a fake history.

For **transcripts**: establish session date, engagement phase, and the explicit scope
boundary; capture set/family/job-vs-position decisions as scope-level unless locked.

---

## Step 2 — Profile the as-is (quantify before you opine)

Use code to measure. Distinguish what the artifact **shows** from what you **infer**.

### 2A — Catalog integrity (the foundation-object proof)

The job analogue of a balance proof is **catalog integrity** — does this set of jobs hold
together and resolve?

- **Unique codes** — no duplicate job code within a set; flag duplicate names across codes.
- **Set resolution** — every job's set is populated and resolves to a configured set.
- **Family resolution** — every job's family/function resolves to a configured family (or
  is intentionally blank).
- **Effective-date sanity** — effective-start ≤ effective-end; no malformed dates; flatten-
  vs-history identified.
- **Demand coverage** — if a worker/assignment extract is present, **every job it
  references exists in this catalog** (the foundation-object check that prevents a stalled
  worker load). Report any referenced job missing from the catalog.

State the integrity result up front. A complete, resolvable, unique-coded catalog that
covers downstream demand is the strongest signal of a clean job conversion.

### 2B — Reverse-engineer the job catalog & family model

- **Catalog size & structure** — distinct jobs, distinct families, jobs-per-family
  distribution; whether the code is clean or an intelligent key (decode it if so).
- **Family/function model** — the job-family and job-function structure in use; FLSA
  exempt/non-exempt split where present.
- **Job vs. position signal** — a very large, granular job count (one job per person/level/
  location) signals the client may really need **positions**, with jobs as the broader
  classification — call this out as a design fork (the job-vs-position decision).
- **Active scope** — active vs. inactive jobs; whether dead jobs are in scope.

### 2C — Profile control posture

- **SourceSystemId/Owner** — present and unique (the HDL crosswalk key).
- **Naming standard** — intelligent key vs. clean code; consistency.
- **Volume & distribution** — jobs per set/family, active/inactive split.

State the operating model — set strategy, family structure, job-vs-position posture, active
scope — as inferences the user can correct.

---

## Step 2.5 — Job HDL load-readiness checklist (always run it)

The job conversion loads through HDL as a **set of related business objects**, not one flat
file, and each rejects on its own missing/invalid attributes or unresolved cross-references.
Validate the file against the sub-entity set below and report completeness (% populated,
blanks, invalid values) per element, rolling up to a per-entity readiness verdict (🟢 loadable
/ 🟡 loadable with cleanup / 🔴 blocked / ⬜ unverifiable). Three rules apply to **every** sub-
entity — dates in `YYYY/MM/DD`, all lookup values configured/present in the target, and no
required/mandatory field blank — so check them per entity rather than once globally. The
`SourceSystemId`/`SourceSystemOwner` crosswalk pair should be present and unique on each.

**`JobFamily`**
- Required fields not blank; lookups configured; dates in `YYYY/MM/DD`.
- `JobFamilyCode` unique.
- The combination of `JobFamilyCode` + `JobFamilyName` unique.

**`Job`**
- Required fields not blank; lookups configured; dates in `YYYY/MM/DD`.
- `JobCode` unique.
- The combination of `JobCode` + `JobName` unique.

**`JobGrade`**
- Dates in `YYYY/MM/DD`; lookups configured; required fields not blank.
- **Every `JobCode` in `JobGrade` exists in the `Job` entity.**
- **Every grade tagged to a job in `JobGrade` is present in the system** (grades must
  already exist — a cross-object prerequisite).

**`JobExtraInfo` (Job Extra Information)**
- Dates in `YYYY/MM/DD`; lookups configured; required fields not blank.
- **Every job in `JobExtraInfo` exists in the `Job` entity.**

**`JobLegislativeInfo` (Job Legislative Extra Information)**
- Dates in `YYYY/MM/DD`; lookups configured; required fields not blank.
- **Every job in `JobLegislativeInfo` exists in the `Job` entity.**
- **The `EffectiveStartDate` of a job in `JobLegislativeInfo` equals the `EffectiveStartDate`
  of the same job in the `Job` entity.**

**Common-gotcha set**
- Duplicate job/job-family code — none; leading-zero codes preserved as strings.
- Referenced-but-absent jobs — every job a worker/position extract references exists here.

For each element report present? (Y/N), % populated, invalid/placeholder values, and a
verdict. The objects load in dependency order — `JobFamily` and `Job` before `JobGrade`/
`JobExtraInfo`/`JobLegislativeInfo` — so a structurally clean file can still be blocked if a
`JobGrade`/`JobExtraInfo`/`JobLegislativeInfo` row references a job absent from the `Job`
entity, a tagged grade doesn't exist, a legislative effective date disagrees with the job's,
a lookup isn't configured, or a code collides — say so.

---

## Step 3 — Translate to Fusion (three output streams)

**1. Configuration items** — setup the file implies, each with the *why*:
- **Job sets** — the Common Set vs. legislation/BU-specific sets the catalog requires.
- **Job families & functions** — the families/functions each job maps to.
- **Legislations** — the legislations the `JobLegislativeInfo` (FLSA, functions) spans.
- **Naming standard** — the job-code standard (decode any intelligent key; move level/
  location off the code).
- **Job-vs-position decision** — whether the granularity calls for position management with
  jobs as the broader classification.

**2. Conversion items** — what gets loaded and the strategy/risk for each, loaded via **HDL**
(`Job` + `JobLegislativeInfo`). Jobs are a **prerequisite** for worker/position/assignment
loads — load them first. Call out **conversion blockers**: duplicate codes; unmapped/
unconfigured set; unresolved family; flattened effective dates (pick a go-live date);
leading-zero codes broken by an integer cast; intelligent keys requiring a remap and a
legacy→Fusion crosswalk; and jobs referenced by downstream extracts but missing from the
catalog.

**3. Current-state summary** — the set strategy, the catalog and family structure, the job-
vs-position posture, the active scope, and the headline risks, with the foundation-object
prerequisite called out. Quantified where data exists; inferences flagged.

---

## Step 4 — Surface decisions, name the gaps

- **Design decisions** — single Common Set vs. legislation/BU sets; jobs-only vs. position
  management with jobs as classification; decode the intelligent code now vs. carry as
  legacy; convert inactive jobs vs. active-only; how granular the catalog should be. Frame
  each with options and a lean.
- **Leading-practice gaps** — job proliferation (one job per person), intelligent keys, no
  job families, duplicate jobs. Framed as a decision, not a criticism.
- **Cross-dependencies** — job sets, families, and legislations **must exist before the job
  load**, and **jobs must exist before the worker, position, and assignment loads** — the
  classic foundation-object sequence. Valid-grade mappings require grades to exist first.
- **What's missing** — the job-family list (to confirm families resolve); the set
  definitions; the worker/position extract (to confirm the catalog covers downstream
  demand); confirmation of legislations in scope; the grade list if valid-grade mappings
  are included.

---

## Report Mode

When a report/deliverable is requested, produce executive prose anchored by structured
reference elements: artifact inventory; **catalog-integrity proof** (unique codes, set/
family resolution, demand coverage, pass/fail); set/family/catalog summary; the Job HDL
load-readiness scorecard (Step 2.5 as a table with verdicts); configuration register;
conversion register; decision log; cross-dependency list (foundation-object sequence); and
the gap / next-data-request list.

For an **HTML report**, render via the `data-analysis-report-format` skill — the house
standard for analysis-report look (thesis verdict card, color-coded scorecard, observation
blocks, severity-grouped risk registers). The catalog-integrity proof maps to the at-a-
glance thesis card; the load-readiness checklist to the scorecard; the blockers to the hard-
reject/cleanup registers. For a spreadsheet workbook, hand off to `xlsx`; for a narrative
document, `docx`. If the engagement uses a house brand (Hackett/DigiKey/client), layer that
brand-guidelines skill on top — keep the layout, swap palette and fonts.

---

## Principles

- Detect the format (HDL `.dat` METADATA/MERGE vs. XLSX/CSV) before profiling; map columns
  from the METADATA line or the header, never by index.
- Jobs are a foundation object: a clean, resolvable, unique-coded catalog that covers
  downstream demand is the prerequisite that unblocks the worker/position/assignment loads.
  Treat a missing or mis-coded job as a downstream blocker, not a local cleanup item.
- Prove catalog integrity first — unique codes, set and family resolution, effective-date
  sanity, and coverage of the jobs downstream extracts reference.
- Read codes as strings to preserve leading zeros and catch float artifacts; identify
  flattened effective dates and pick a single go-live date rather than loading fake history.
- Reverse-engineer the catalog and family model; watch for job proliferation that really
  signals a need for positions (the job-vs-position fork).
- Control values are load gates: SourceSystemId unique, set configured, family resolvable,
  legislation valid. A clean catalog can still be blocked on resolution.
- Lead with the functional *why*, then the setup *how*. Flag inferences; separate hard-reject
  blockers from cleanup/config. Name the foundation-object sequence loudly.
- Conversational by default; structured-plus-prose only when a report is asked for, and
  render HTML reports through `data-analysis-report-format`.

---

## Worked example — HDL Job.dat (workforce-structure foundation conversion)

A client provides an HDL `Job.dat` file (pipe-delimited, `METADATA|Job|...` then
`MERGE|Job|...` rows, with a companion `JobLegislativeInfo`). Profiling yields:

- **Detection** — HDL Job load (the `Job` + `JobLegislativeInfo` business objects are the
  fingerprint). Parse the METADATA line to map attributes, read the MERGE rows. A single US
  legislation, a `SourceSystemId`/`SourceSystemOwner` crosswalk pair, and a single set — a
  standard foundation conversion fingerprint.
- **Catalog-integrity proof (the headline)** — confirm job codes are unique within the set,
  every set value resolves, every job family resolves (or is intentionally blank), and
  effective dates are sane; then, if the worker extract is present, confirm **every job the
  workers reference exists in this catalog**. A clean file has unique codes, full resolution,
  and complete demand coverage — the strongest signal of a clean conversion and the
  prerequisite that unblocks the worker load. 🟢 / 🔴 driven by the checks.
- **Catalog & family model** — distinct jobs and families, jobs-per-family distribution, FLSA
  exempt/non-exempt split. If the code is an intelligent key embedding level/location, decode
  it (a naming-standard decision). If the catalog is very large and granular (approaching one
  job per person), flag the **job-vs-position fork** — the client may need positions with
  jobs as the broader classification. 🟡 on the intelligent-key and granularity gates.
- **Control posture** — `SourceSystemId` unique, set populated, families and legislation
  present. These resolve to load gates: the **set must be configured**, **families must
  resolve**, the **legislation must be valid**, and **jobs must load before workers/positions/
  assignments** — the foundation-object sequence. ⬜ where target config can't be confirmed
  from the file.
- **Load-readiness verdict** — catalog clean (🟢) if codes are unique and references resolve;
  open items are configuration/sequence-side (🟡/⬜): confirm sets and families exist, decode
  the intelligent key if present, pick a go-live effective date if dates are flattened,
  preserve leading-zero codes, and load jobs ahead of the worker/position loads.
- **Gaps / next-data requests** — the **job-family list** (to confirm families resolve); the
  **set definitions**; the **worker/position extract** (to confirm the catalog covers
  downstream demand); the **grade list** if valid-grade mappings are included; and
  confirmation of the **legislations in scope**.

This is the depth bar — for a *data* artifact, match it on the catalog-integrity proof, the
catalog/family reverse-engineering, the load-readiness checklist, and the foundation-object
sequence; for a *transcript*, mine the set strategy and the job-vs-position decision.
