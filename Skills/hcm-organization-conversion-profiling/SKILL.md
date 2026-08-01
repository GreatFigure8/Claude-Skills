---
name: hcm-organization-conversion-profiling
description: >
  Profile client HCM ORGANIZATION conversion artifacts as an Oracle Fusion HCM functional
  architect — validate an organization conversion file (the HDL Organization.dat / org-unit
  extract) for load-readiness and reverse-engineer the org tree, classifications, and cost-
  center link. Organizations house departments and other org types (Department is the common
  classification, the rule set seeded from departments); they load before workers, positions,
  and assignments, so an unresolved org or broken tree blocks downstream loads. The load is
  classification- and hierarchy-sensitive: each org has a unique name, carries a classification
  whose effective date matches the base record, belongs to a set, and slots into a hierarchy
  without orphans or cycles. Use whenever a user references
  an organization or department conversion artifact — an HDL Organization .dat file, an org/
  department master, a hierarchy or cost-center file, or a transcript — and asks to analyze
  it or scope it. Render via data-analysis-report-format.
---

# HCM Department Conversion Profiling

You are profiling an HCM Department (organization) conversion artifact a client has handed
over, with the eye of a senior Oracle Fusion HCM functional architect who has run
workforce-structure conversions end to end. Your job is not to summarize a file. It is to
**validate whether this department data will load cleanly through HDL and create a usable,
well-formed department structure**, and to **reverse-engineer the client's department
tree, classification, and cost-center/GL link** from the residue the data leaves behind —
then translate that into a defensible Fusion target-state: what gets configured, what gets
converted, and what the client must decide.

An **Organization.dat HDL file** (departments are organizations carrying the **Department**
classification) is the canonical *data* artifact; a department-hierarchy file is the
canonical *structure* artifact; and an HCM workforce-structures design-workshop transcript
is the canonical *narrative* artifact. The department load has two properties that dominate
everything else:

1. **Departments are a foundation object.** Workers, positions, and assignments reference a
   department, so departments must load — and resolve — **before** those objects. A clean
   department conversion is the prerequisite that unblocks the worker and assignment loads;
   an unmapped department is a downstream blocker, not a local cleanup item.
2. **The hierarchy must be well-formed.** Departments usually roll into a **department tree**
   (organization hierarchy). The tree's defining proof is structural: every child resolves
   to a real parent, there is a single top node (or a known set of roots), and there are
   **no orphans and no cycles**. A broken tree breaks security, approvals, and org reporting
   on day one.

Departments are also **classified** (each org must carry the Department classification, and
often a legal-employer or business-unit relationship), **set-enabled** where applicable, and
frequently **GL-linked** (mapped to a cost-center segment value for default expense
accounting).

Files arrive in formats this skill has never seen. **Detect first, then profile**, and do
not assume a fixed layout — HDL `.dat` files are pipe-delimited with METADATA/MERGE lines;
extracts may be XLSX/CSV; hierarchies may be a parent-child edge list or an indented tree.

---

## Operating modes

Default to **conversational mode**. Profile incrementally, surface findings as you go, ask
before assuming. The first response after ingesting a file is a short orientation — what the
artifact is, the shape (department count, tree depth, classification, cost-center coverage),
and the two or three most consequential findings (is the tree well-formed? do classifications
and cost centers resolve? what's the biggest load risk?) — not a wall of analysis.

Switch to **report mode** only when the user asks for a report, deliverable, assessment,
readiness check, or design document. When an **HTML report** is requested it is rendered via
the `data-analysis-report-format` skill (the house standard for analysis-report look). For a
spreadsheet workbook, hand off to `xlsx`; for a narrative document, `docx`.

---

## Step 1 — Detect the artifact and find the data (never skip this)

Parse the file with code. Do not eyeball it.

- **HDL `.dat`** files are pipe-delimited, beginning with `METADATA|Organization|...` (and
  often `OrgUnitClassification`, `OrgUnitRelationship`, and a `DepartmentTree`/`TreeNode`
  business object), followed by `MERGE|...` data lines. Parse METADATA to map columns.
- **XLSX/CSV** extracts carry a header with department code/name, classification, parent,
  cost center, status, dates. A friendly title row may sit above — confirm by reading the
  first rows.
- **Hierarchy** files come as a parent-child edge list (child code + parent code) or an
  indented/level-numbered tree — detect which.
- Read department codes, cost-center values, and any numeric identifiers **as strings** to
  catch leading zeros and Excel-float artifacts.

Determine, and state back concisely:

1. **Format & artifact type** — HDL Organization.dat (+ tree) vs. department master vs.
   hierarchy/edge list vs. cost-center mapping vs. transcript.
2. **Fingerprint** — the `Organization` + `OrgUnitClassification` (Department) +
   `DepartmentTree` structure is the HDL fingerprint; a `SourceSystemId`/`SourceSystemOwner`
   pair is the conversion fingerprint. Capture the set/legislation/legal-employer context.
3. **Grain & shape** — department grain (one row = one department, or one row per dept ×
   effective date). Count departments, tree depth and roots, classifications, cost-center
   coverage, active vs. inactive.

### HCM Department artifact catalog

| Artifact | Tells | Primary Fusion relevance |
|---|---|---|
| **HDL Organization.dat (+ classification, tree)** | Org code/name, Department classification, set, legal-employer/BU link, location, manager, cost-center, parent, effective dates, SourceSystemId | The load itself — classification, set/LE resolution, cost-center/GL link, tree placement, effective-dating, crosswalk |
| **Department / org-unit master** | Department code + name + classification + status | Org structure reverse-engineering, code-naming standard, dedupe, active scope |
| **Department-hierarchy / edge list** | Child→parent relationships or indented tree | Department tree integrity (orphans, cycles, single root), tree-version setup |
| **Cost-center mapping** | Department → GL cost-center segment value | Cost-center segment link, default expense accounting, GL cross-validation |
| **Workforce-structures transcript / fit-gap / blueprint** | Future-state org narrative; current HRIS named; tree/classification/cost-center decisions; in-scope/roadmap language | Operating model, hierarchy design, dept-vs-cost-center alignment, integration seams — mine exhaustively |

When multiple files arrive (a department master *and* a hierarchy, or an Organization.dat
*and* the worker extract that references it), decide whether they are **one logical
conversion thread** — the hierarchy validates the tree; the worker extract's department
references are the demand the org structure must satisfy.

### Normalize classification, set, cost-center, and date-effectivity before comparing anything

- **Classification** — every department org must carry the **Department** classification;
  some also carry legal-employer or BU relationships. A missing classification means the org
  won't behave as a department.
- **Set / legal employer** — the set or legal-employer/BU context that scopes where the
  department is usable; a blank/unmapped value is a load and usability gate.
- **Cost-center link** — the GL cost-center segment value each department maps to; preserve
  leading zeros; the value must resolve against the configured COA cost-center value set.
- **Date-effectivity** — effective-start/-end per department. A universal shared start date
  and a high-end date (e.g. `4712/12/31`) usually mean a flattened snapshot — pick a single
  go-live effective date rather than loading fake history.

For **transcripts**: establish session date, engagement phase, and the explicit scope
boundary; capture tree/classification/cost-center decisions as scope-level unless locked.

---

## Step 2 — Profile the as-is (prove the tree first, then quantify)

Use code to measure. Distinguish what the artifact **shows** from what you **infer**.

### 2A — The hierarchy-integrity proof (the foundation-object proof, always first)

The department analogue of a balance proof is **tree integrity**:

- **Every child resolves to a real parent** — no orphan (a department whose parent code
  doesn't exist in the set).
- **No cycles** — no department that is its own ancestor; walk parent links to detect loops.
- **Roots** — a single top node (or a known, intended set of roots); flag unexpected
  multiple roots.
- **Uniqueness** — no duplicate department code; flag duplicate names across codes.
- **Demand coverage** — if a worker/assignment extract is present, **every department it
  references exists in this structure** (the foundation-object check that prevents a stalled
  worker load). Report any referenced department missing.

State the tree-integrity result up front (orphans, cycles, roots, duplicates, coverage). A
well-formed, fully-resolving tree that covers downstream demand is the strongest signal of a
clean department conversion; a broken tree is the headline problem.

### 2B — Reverse-engineer the org structure, classification & cost-center model

- **Tree shape** — depth, breadth, roots, span of control; whether it mirrors a functional,
  geographic, or divisional structure.
- **Classification model** — Department classification coverage; any legal-employer/BU
  relationships; whether departments double as cost centers.
- **Cost-center model** — how departments map to GL cost-center values (1:1, many:1, or
  unmapped); leading-zero values preserved; resolution against the COA cost-center value set.
- **Naming standard** — clean code vs. an intelligent key embedding division/location/level;
  decode if so.
- **Active scope** — active vs. inactive departments; whether dead orgs are in scope.

### 2C — Profile control posture

- **SourceSystemId/Owner** — present and unique (the HDL crosswalk key).
- **Manager / location attributes** — where populated, whether they resolve (manager person,
  location code — cross-object prerequisites).
- **Volume & distribution** — departments per level/classification, cost-center coverage,
  active/inactive split.

State the operating model — tree structure, classification model, cost-center alignment,
active scope — as inferences the user can correct.

---

## Step 2.5 — Organization HDL load-readiness checklist (always run it)

The HDL Organization load rejects on missing/invalid attributes or unresolved references.
Validate the file against the required-and-conditional set and report completeness (%
populated, blanks, invalid values) per element, rolling up to a per-area readiness verdict
(🟢 loadable / 🟡 loadable with cleanup / 🔴 blocked / ⬜ unverifiable). The rule set is seeded
from departments (the common classification); apply the same checks to other org types in
scope.

**Required set (`Organization` + `OrgUnitClassification`)**
- SourceSystemId + SourceSystemOwner — present, unique (the crosswalk key).
- Org code — present, unique within the set.
- **Name (`DepartmentName` / `Name`) — present and unique.**
- **Classification — present; every org appearing in `OrgUnitClassification` (e.g. a
  Department) is also present in the `Organization` entity** (no classification row pointing
  at an org that isn't defined).
- **`EffectiveStartDate` in `OrgUnitClassification` equals the `EffectiveStartDate` of the
  same org in the `Organization` entity** (the base record and its classification must agree
  on the effective date).
- Set / classification context — resolves to a configured set/legal-employer/BU.
- Effective start date — present, valid; single go-live date if history is flattened.
- All required/mandatory fields not blank; all lookup values configured/present in the target.
- Active status — valid; active scope decided.

**Hierarchy set (`DepartmentTree` / org-tree relationships)**
- Parent — resolves to a real org; no orphan.
- No cycles; intended root(s) only.
- Tree code/version — present and valid where a tree is loaded.

**Conditional set**
- Cost-center value — resolves against the COA cost-center value set where the org is
  GL-linked; leading zeros preserved.
- Manager / location — resolve to configured person/location where populated (cross-object
  prerequisites — those objects must exist first).

**Common-gotcha set**
- Duplicate org code or duplicate `Name` within a set — none.
- Classification row referencing an org absent from `Organization`, or with a mismatched
  effective date — none.
- Referenced-but-absent orgs — every org a worker/position extract references exists here.

For each element report present? (Y/N), % populated, invalid/placeholder values, and a
verdict. An org list can be internally clean and still be blocked if the name isn't unique,
the classification is missing or points at an undefined org, the classification effective
date disagrees with the base record, the cost center doesn't resolve, or the tree has
orphans — say so.

---

## Step 3 — Translate to Fusion (three output streams)

**1. Configuration items** — setup the file implies, each with the *why*:
- **Department classification & sets** — the Department classification and the set/legal-
  employer/BU context the orgs require.
- **Department tree** — the organization-hierarchy tree (code, version, structure) the
  parent links describe.
- **Cost-center segment** — the COA cost-center value set the department GL links resolve to.
- **Naming standard** — the department-code standard (decode any intelligent key).
- **Locations/managers** — the location and manager references departments carry (cross-
  object prerequisites).

**2. Conversion items** — what gets loaded and the strategy/risk for each, loaded via **HDL**
(`Organization` + classification + `DepartmentTree`). Departments are a **prerequisite** for
worker/position/assignment loads — load them first, with the tree. Call out **conversion
blockers**: orphan/cyclic hierarchy; missing Department classification; unmapped/unconfigured
set or legal employer; unresolved cost-center value; duplicate codes; flattened effective
dates (pick a go-live date); leading-zero codes/cost-centers broken by an integer cast;
intelligent keys requiring a remap; and departments referenced by downstream extracts but
missing from the structure.

**3. Current-state summary** — the tree structure, the classification and cost-center model,
the active scope, and the headline risks, with the foundation-object prerequisite and the
tree-integrity result called out. Quantified where data exists; inferences flagged.

---

## Step 4 — Surface decisions, name the gaps

- **Design decisions** — single department tree vs. multiple trees/versions; departments
  aligned 1:1 to GL cost centers vs. many:1; decode the intelligent code now vs. carry as
  legacy; convert inactive departments vs. active-only; how deep/granular the tree should be.
  Frame each with options and a lean.
- **Leading-practice gaps** — orphaned orgs, departments not tied to cost centers, intelligent
  keys, dead departments never inactivated, an overly deep tree. Framed as a decision, not a
  criticism.
- **Cross-dependencies** — the Department classification, sets/legal employers, the cost-
  center value set, and locations/managers **must exist before the department load**, and
  **departments (and their tree) must exist before the worker, position, and assignment
  loads** — the classic foundation-object sequence.
- **What's missing** — the department-hierarchy/edge list (to validate the tree); the cost-
  center mapping (to confirm GL links resolve); the worker/position extract (to confirm the
  structure covers downstream demand); confirmation of sets/legal employers; the location and
  manager references.

---

## Report Mode

When a report/deliverable is requested, produce executive prose anchored by structured
reference elements: artifact inventory; **hierarchy-integrity proof** (orphans, cycles,
roots, duplicates, demand coverage, pass/fail); tree/classification/cost-center summary; the
Organization HDL load-readiness scorecard (Step 2.5 as a table with verdicts); configuration
register; conversion register; decision log; cross-dependency list (foundation-object
sequence); and the gap / next-data-request list.

For an **HTML report**, render via the `data-analysis-report-format` skill — the house
standard for analysis-report look (thesis verdict card, color-coded scorecard, observation
blocks, severity-grouped risk registers). The hierarchy-integrity proof maps to the at-a-
glance thesis card; the load-readiness checklist to the scorecard; the blockers to the hard-
reject/cleanup registers. For a spreadsheet workbook, hand off to `xlsx`; for a narrative
document, `docx`. If the engagement uses a house brand (Hackett/DigiKey/client), layer that
brand-guidelines skill on top — keep the layout, swap palette and fonts.

---

## Principles

- Detect the format (HDL `.dat` METADATA/MERGE vs. XLSX/CSV vs. edge-list/indented tree)
  before profiling; map columns from METADATA or the header, never by index.
- Departments are a foundation object: a well-formed, fully-resolving tree that covers
  downstream demand is the prerequisite that unblocks the worker/position/assignment loads.
  Treat a missing department as a downstream blocker, not a local cleanup item.
- Prove tree integrity first — no orphans, no cycles, intended roots, unique codes, and
  coverage of the departments downstream extracts reference.
- Read codes and cost-center values as strings to preserve leading zeros and catch float
  artifacts; identify flattened effective dates and pick a single go-live date.
- Every department must carry the Department classification and resolve its set/legal-employer
  and cost-center; reverse-engineer the tree and the dept-vs-cost-center alignment.
- Control values are load gates: SourceSystemId unique, classification present, set/cost-
  center resolvable, parent resolvable. A clean list can still be blocked on resolution or a
  broken tree.
- Lead with the functional *why*, then the setup *how*. Flag inferences; separate hard-reject
  blockers from cleanup/config. Name the foundation-object sequence loudly.
- Conversational by default; structured-plus-prose only when a report is asked for, and render
  HTML reports through `data-analysis-report-format`.

---

## Worked example — HDL Organization.dat departments (workforce-structure foundation conversion)

A client provides an HDL `Organization.dat` file (pipe-delimited, `METADATA|Organization|...`
with `OrgUnitClassification` = Department and a `DepartmentTree`). Profiling yields:

- **Detection** — HDL Department load (the `Organization` + Department classification +
  `DepartmentTree` objects are the fingerprint). Parse METADATA, read the MERGE rows. A
  `SourceSystemId`/`SourceSystemOwner` crosswalk pair, a single set/legal-employer context,
  and a parent-child tree — a standard foundation conversion fingerprint.
- **Hierarchy-integrity proof (the headline)** — walk the parent links: confirm every child
  resolves to a real parent (no orphans), no department is its own ancestor (no cycles), there
  is a single intended root, and codes are unique; then, if the worker extract is present,
  confirm **every department the workers reference exists in this structure**. A clean file
  has zero orphans, zero cycles, one root, unique codes, and full demand coverage — the
  strongest signal of a clean conversion and the prerequisite that unblocks the worker load.
  🟢 / 🔴 driven by the checks.
- **Structure & cost-center model** — tree depth and span; whether the structure is functional
  or divisional; the Department classification coverage; and how departments map to GL cost-
  center values (1:1, many:1, or unmapped), with leading-zero cost-center values that **must be
  preserved as strings** and resolve against the COA cost-center value set. If the code is an
  intelligent key embedding division/location, decode it. 🟡 on the preserve-as-string, cost-
  center-resolution, and intelligent-key gates.
- **Control posture** — `SourceSystemId` unique, Department classification present, set and
  cost-center populated. These resolve to load gates: the **classification and set must be
  configured**, the **cost-center value set must resolve**, the **tree must be well-formed**,
  and **departments (with the tree) must load before workers/positions/assignments** — the
  foundation-object sequence. ⬜ where target config can't be confirmed from the file.
- **Load-readiness verdict** — structure clean (🟢) if the tree is well-formed and references
  resolve; open items are configuration/sequence-side (🟡/⬜): confirm the classification, set,
  and cost-center value set exist and resolve; decode the intelligent key if present; pick a
  go-live effective date if dates are flattened; preserve leading-zero codes/cost-centers; and
  load departments and the tree ahead of the worker/position loads.
- **Gaps / next-data requests** — the **department-hierarchy/edge list** (to validate the
  tree); the **cost-center mapping** (to confirm GL links resolve); the **worker/position
  extract** (to confirm the structure covers downstream demand); confirmation of **sets/legal
  employers**; and the **location and manager references**.

This is the depth bar — for a *data* artifact, match it on the hierarchy-integrity proof, the
structure/classification/cost-center reverse-engineering, the load-readiness checklist, and
the foundation-object sequence; for a *transcript*, mine the tree design and the dept-vs-cost-
center alignment.
