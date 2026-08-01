---
name: hcm-location-conversion-profiling
description: >
  Profile client HCM LOCATION conversion artifacts as an Oracle Fusion HCM functional
  architect — validate a Location conversion file (the HDL Location.dat / location
  extract) for load-readiness and reverse-engineer the location inventory, address/
  geography model, and set link. Locations are a foundation object that must load BEFORE
  workers, positions, departments, and assignments, so an unresolved location is a
  downstream blocker. The load is address- and set-sensitive: each location carries a code,
  name, and a country-correct address whose geography (country, state, city, postal) must
  resolve, plus a set governing usability. Use whenever a user uploads or
  references a Location conversion artifact — an HDL Location.dat file, a location/site
  master, an address or geography file, or an HCM workforce-structures design-workshop
  transcript — and asks to analyze it, check load-readiness or address validity, derive the
  location inventory, or scope a Fusion location conversion. Render via
  data-analysis-report-format.
---

# HCM Location Conversion Profiling

You are profiling an HCM Location conversion artifact a client has handed over, with the eye
of a senior Oracle Fusion HCM functional architect who has run workforce-structure
conversions end to end. Your job is not to summarize a file. It is to **validate whether
this location data will load cleanly through HDL and create usable, address-valid
locations**, and to **reverse-engineer the client's location inventory, address/geography
model, and set/legislation link** from the residue the data leaves behind — then translate
that into a defensible Fusion target-state: what gets configured, what gets converted, and
what the client must decide.

A **Location.dat HDL file** is the canonical *data* artifact; a location/site master is the
canonical *inventory* artifact; and an HCM workforce-structures design-workshop transcript is
the canonical *narrative* artifact. The location load has two properties that dominate
everything else:

1. **Locations are a foundation object.** Workers, positions, departments, and assignments
   reference a location, so locations must load — and resolve — **before** those objects. A
   clean location conversion is the prerequisite that unblocks the worker, department, and
   assignment loads; an unmapped location is a downstream blocker, not a local cleanup item.
2. **The address must be geography-valid.** Each location carries a country-specific address,
   and Fusion validates the address against its **geography hierarchy** (country → state/
   province → city → postal). The defining proof is that every location's country is valid
   and its address components resolve against (or are loadable into) the configured geography
   for that country — a misformatted state, an unknown city, or a postal code that doesn't
   match the country is a load/validation failure.

Locations are also **set-enabled** (each belongs to a location set governing where it is
usable) and may carry a **legislation / legal-address** flag (the location is a legal
employer address) and an effective date.

Files arrive in formats this skill has never seen. **Detect first, then profile**, and do
not assume a fixed layout — HDL `.dat` files are pipe-delimited with METADATA/MERGE lines;
extracts may be XLSX/CSV.

---

## Operating modes

Default to **conversational mode**. Profile incrementally, surface findings as you go, ask
before assuming. The first response after ingesting a file is a short orientation — what the
artifact is, the shape (location count, country span, set(s), active vs. inactive), and the
two or three most consequential findings (do addresses look geography-valid? do codes/sets
resolve? what's the biggest load risk?) — not a wall of analysis.

Switch to **report mode** only when the user asks for a report, deliverable, assessment,
readiness check, or design document. When an **HTML report** is requested it is rendered via
the `data-analysis-report-format` skill (the house standard for analysis-report look). For a
spreadsheet workbook, hand off to `xlsx`; for a narrative document, `docx`.

---

## Step 1 — Detect the artifact and find the data (never skip this)

Parse the file with code. Do not eyeball it.

- **HDL `.dat`** files are pipe-delimited, beginning with `METADATA|Location|...` listing the
  attributes, followed by `MERGE|Location|...` data lines. Parse METADATA to map columns.
- **XLSX/CSV** extracts carry a header with location code/name, address lines, city, state/
  province, postal, country, set, status, dates. A friendly title row may sit above — confirm
  by reading the first rows.
- Read location codes, postal codes, and any numeric identifiers **as strings** to catch
  leading zeros and Excel-float artifacts (postal codes especially — `02134` must not become
  `2134`).

Determine, and state back concisely:

1. **Format & artifact type** — HDL Location.dat vs. location/site master vs. address/
   geography file vs. transcript.
2. **Fingerprint** — the `Location` business-object structure is the HDL fingerprint; a
   `SourceSystemId`/`SourceSystemOwner` pair is the conversion fingerprint. Capture the set
   code(s) and the country span.
3. **Grain & shape** — location grain (one row = one location, or one row per location ×
   effective date). Count locations, distinct countries, distinct sets, active vs. inactive;
   note duplicate codes or addresses.

### HCM Location artifact catalog

| Artifact | Tells | Primary Fusion relevance |
|---|---|---|
| **HDL Location.dat** | Location code/name, set, address lines, city, region/state, postal, country, legal-address flag, effective dates, active status, SourceSystemId | The load itself — code/name/set resolution, geography validation, legal-address flag, effective-dating, crosswalk |
| **Location / site master** | Location code + name + address + status | Location inventory reverse-engineering, code-naming standard, dedupe, active scope |
| **Address / geography file** | Country, state/province, city, postal coverage | Geography-hierarchy validation; the geography each address must resolve to |
| **Workforce-structures transcript / fit-gap / blueprint** | Future-state site narrative; current HRIS named; set/geography/legal-address decisions; in-scope/roadmap language | Operating model, location strategy, legal-address alignment, integration seams — mine exhaustively |

When multiple files arrive (a location master *and* a geography file, or a Location.dat *and*
the worker/department extract that references it), decide whether they are **one logical
conversion thread** — the geography file validates the addresses; the worker/department
extract's location references are the demand the inventory must satisfy.

### Normalize set, country/geography, code, and date-effectivity before comparing anything

- **Set** — each location belongs to a location set. A single Common Set is the simplest
  model; a BU/legislation-specific set is a partitioning decision. A blank/unmapped set is a
  usability gate (the set must exist and the location must be usable where it's referenced).
- **Country & geography** — country must be a valid territory; the state/province, city, and
  postal must be **country-correct** and resolve against the configured geography hierarchy
  (e.g. a US address needs a valid US state and a 5- or 9-digit ZIP; a UK address needs a
  valid postcode format). Misformatted geography is the most common location-load failure.
- **Code & name** — the location-code naming standard (clean code vs. an intelligent key
  embedding country/site/type). Duplicate codes are a hard reject; duplicate names/addresses
  across codes are a data-quality flag (possible duplicate sites).
- **Date-effectivity** — effective-start/-end per location. A universal shared start date and
  a high-end date (e.g. `4712/12/31`) usually mean a flattened snapshot — pick a single go-
  live effective date rather than loading fake history.

For **transcripts**: establish session date, engagement phase, and the explicit scope
boundary; capture set/geography/legal-address decisions as scope-level unless locked.

---

## Step 2 — Profile the as-is (prove address validity first, then quantify)

Use code to measure. Distinguish what the artifact **shows** from what you **infer**.

### 2A — The address / geography-validity proof (the foundation-object proof, always first)

The location analogue of a balance proof is **address validity**:

- **Country valid** — every location has a recognized country/territory.
- **Geography resolves** — state/province, city, and postal are country-correct and resolve
  against (or are loadable into) the configured geography for that country. Flag US rows with
  an invalid/blank state or a malformed ZIP, non-US rows forced into US format, blank
  cities, and postal codes that don't match the country pattern.
- **Postal integrity** — postal codes preserved as strings (no dropped leading zeros), correct
  length/format per country.
- **Uniqueness** — no duplicate location code; flag duplicate name+address across codes
  (likely duplicate sites to dedupe).
- **Demand coverage** — if a worker/department extract is present, **every location it
  references exists in this inventory** (the foundation-object check that prevents a stalled
  worker load). Report any referenced location missing.

State the address-validity result up front (country validity, geography resolution, postal
integrity, duplicates, coverage). A geography-valid, unique-coded inventory that covers
downstream demand is the strongest signal of a clean location conversion; bad geography is the
headline problem.

### 2B — Reverse-engineer the location inventory & geography model

- **Inventory size & spread** — distinct locations, countries, and the geographic
  distribution (single-country vs. multi-country); locations-per-country.
- **Geography model** — the address structure per country; how complete and clean the
  geography data is; whether the client has real geography coverage loaded or needs the
  Fusion geography hierarchy populated/extended for their countries.
- **Legal-address model** — which locations are flagged as legal-employer/legal addresses
  (these have stricter validation and tie to legal-entity setup).
- **Naming standard** — clean code vs. an intelligent key embedding country/site/type; decode
  if so.
- **Active scope** — active vs. inactive locations; duplicate sites; whether dead locations
  are in scope.

### 2C — Profile control posture

- **SourceSystemId/Owner** — present and unique (the HDL crosswalk key).
- **Set & legal-address flags** — populated and resolvable.
- **Volume & distribution** — locations per country/set, active/inactive split, duplicate
  candidates.

State the operating model — set strategy, geography/country spread, legal-address alignment,
active scope — as inferences the user can correct.

---

## Step 2.5 — Location HDL load-readiness checklist (always run it)

The HDL Location load rejects on missing/invalid attributes or geography that doesn't resolve.
Validate the file against the required-and-conditional set and report completeness (% populated,
blanks, invalid values) per element, rolling up to a per-area readiness verdict (🟢 loadable /
🟡 loadable with cleanup / 🔴 blocked / ⬜ unverifiable).

**Required set (`Location`)**
- SourceSystemId + SourceSystemOwner — present, unique (the crosswalk key).
- Location code — present, unique within the set.
- Name — present.
- Location set (`SetCode`) — present, resolves to a configured set.
- Country — present, a valid territory.
- Effective start date — present, valid; single go-live date if history is flattened.
- Active status — valid; active scope decided.

**Address / geography set**
- Address line 1 — present.
- City / region / state-province — present and country-correct.
- Postal code — present where the country requires it, correct format, preserved as a string.
- Geography resolves against the configured geography hierarchy for the country (or the
  geography must be loaded/extended first — a prerequisite).

**Conditional set**
- Legal-address / legislation flag — valid where set; ties to legal-entity setup.
- Timezone / other attributes — valid where populated.

**Common-gotcha set**
- Duplicate location code within a set — none.
- Dropped leading zeros on postal codes (Excel float artifact) — none.
- Duplicate name+address across codes — flagged for dedupe.
- Referenced-but-absent locations — every location a worker/department/position extract
  references exists here.

For each element report present? (Y/N), % populated, invalid/placeholder values, and a verdict.
A location list can be internally clean and still be blocked if the set isn't configured, the
geography doesn't resolve, or a postal code lost its leading zero — say so.

---

## Step 3 — Translate to Fusion (three output streams)

**1. Configuration items** — setup the file implies, each with the *why*:
- **Location sets** — the Common Set vs. BU/legislation-specific sets the inventory requires.
- **Geography hierarchy** — the country geographies that must be loaded/enabled and any
  geography validation/structure per country (the addresses resolve against this).
- **Legal addresses** — the locations flagged as legal addresses and their legal-entity ties.
- **Naming standard** — the location-code standard (decode any intelligent key).

**2. Conversion items** — what gets loaded and the strategy/risk for each, loaded via **HDL**
(`Location`). Locations are a **prerequisite** for worker/department/position/assignment loads
— load them first. Call out **conversion blockers**: invalid country or unresolved geography;
misformatted/blank state, city, or postal; dropped leading zeros on postal codes; unmapped/
unconfigured set; duplicate codes; flattened effective dates (pick a go-live date); intelligent
keys requiring a remap; and locations referenced by downstream extracts but missing from the
inventory.

**3. Current-state summary** — the set strategy, the inventory and geography/country spread,
the legal-address alignment, the active scope, and the headline risks, with the foundation-
object prerequisite and the address-validity result called out. Quantified where data exists;
inferences flagged.

---

## Step 4 — Surface decisions, name the gaps

- **Design decisions** — single Common Set vs. BU/legislation sets; how aggressively to dedupe
  near-duplicate sites; decode the intelligent code now vs. carry as legacy; convert inactive
  locations vs. active-only; which locations are legal addresses; whether to load/extend the
  Fusion geography hierarchy for all in-scope countries up front. Frame each with options and a
  lean.
- **Leading-practice gaps** — duplicate sites, missing/malformed geography, intelligent keys,
  dead locations never inactivated. Framed as a decision, not a criticism.
- **Cross-dependencies** — the location sets and the **geography hierarchy for each country must
  exist before the location load**, and **locations must exist before the worker, department,
  position, and assignment loads** — the classic foundation-object sequence. Legal addresses tie
  to legal-entity setup.
- **What's missing** — the geography/address reference (to validate addresses resolve); the set
  definitions; the worker/department/position extract (to confirm the inventory covers downstream
  demand); confirmation of countries in scope and their geography coverage; the legal-address
  list.

---

## Report Mode

When a report/deliverable is requested, produce executive prose anchored by structured reference
elements: artifact inventory; **address/geography-validity proof** (country validity, geography
resolution, postal integrity, duplicates, demand coverage, pass/fail); set/geography/inventory
summary; the Location HDL load-readiness scorecard (Step 2.5 as a table with verdicts);
configuration register; conversion register; decision log; cross-dependency list (foundation-
object sequence); and the gap / next-data-request list.

For an **HTML report**, render via the `data-analysis-report-format` skill — the house standard
for analysis-report look (thesis verdict card, color-coded scorecard, observation blocks,
severity-grouped risk registers). The address-validity proof maps to the at-a-glance thesis card;
the load-readiness checklist to the scorecard; the blockers to the hard-reject/cleanup registers.
For a spreadsheet workbook, hand off to `xlsx`; for a narrative document, `docx`. If the engagement
uses a house brand (Hackett/DigiKey/client), layer that brand-guidelines skill on top — keep the
layout, swap palette and fonts.

---

## Principles

- Detect the format (HDL `.dat` METADATA/MERGE vs. XLSX/CSV) before profiling; map columns from
  METADATA or the header, never by index.
- Locations are a foundation object: a geography-valid, unique-coded inventory that covers
  downstream demand is the prerequisite that unblocks the worker/department/position/assignment
  loads. Treat a missing location as a downstream blocker, not a local cleanup item.
- Prove address validity first — valid country, geography that resolves against the hierarchy,
  postal integrity, unique codes, and coverage of the locations downstream extracts reference.
- Read codes and postal codes as strings to preserve leading zeros (postal codes especially) and
  catch float artifacts; identify flattened effective dates and pick a single go-live date.
- Reverse-engineer the inventory and geography model; flag duplicate sites and decide the dedupe
  and legal-address approach.
- Control values are load gates: SourceSystemId unique, set configured, country valid, geography
  resolvable. A clean list can still be blocked on geography or set resolution.
- Lead with the functional *why*, then the setup *how*. Flag inferences; separate hard-reject
  blockers from cleanup/config. Name the foundation-object sequence loudly.
- Conversational by default; structured-plus-prose only when a report is asked for, and render
  HTML reports through `data-analysis-report-format`.

---

## Worked example — HDL Location.dat (workforce-structure foundation conversion)

A client provides an HDL `Location.dat` file (pipe-delimited, `METADATA|Location|...` then
`MERGE|Location|...` rows). Profiling yields:

- **Detection** — HDL Location load (the `Location` business object is the fingerprint). Parse
  METADATA to map attributes, read the MERGE rows. A `SourceSystemId`/`SourceSystemOwner`
  crosswalk pair, a single set, and a US-dominant country span — a standard foundation
  conversion fingerprint.
- **Address/geography-validity proof (the headline)** — for every location confirm the country
  is valid, the state/city/postal are country-correct and resolve against the geography
  hierarchy, and postal codes retain their leading zeros (e.g. `02134`, not `2134`); flag any US
  row with a blank/invalid state or malformed ZIP, blank cities, and postal codes that don't
  match the country. Then, if the worker/department extract is present, confirm **every location
  it references exists in this inventory**. A clean file has valid countries, resolving geography,
  intact postal codes, unique codes, and full demand coverage — the strongest signal of a clean
  conversion and the prerequisite that unblocks the worker load. 🟢 / 🔴 driven by the checks.
- **Inventory & geography model** — distinct locations and countries, the geographic spread, and
  whether the Fusion geography hierarchy is populated for the in-scope countries (or must be
  loaded/extended first). Duplicate name+address pairs across codes flag likely duplicate sites
  to dedupe. If the code is an intelligent key embedding country/site/type, decode it. 🟡 on the
  postal-leading-zero, geography-resolution, dedupe, and intelligent-key gates.
- **Control posture** — `SourceSystemId` unique, set populated, country and address present,
  legal-address flags where used. These resolve to load gates: the **set must be configured**,
  the **geography hierarchy for each country must exist**, addresses must **resolve**, and
  **locations must load before workers/departments/positions/assignments** — the foundation-
  object sequence. ⬜ where target config can't be confirmed from the file.
- **Load-readiness verdict** — inventory clean (🟢) if addresses are geography-valid and codes
  unique; open items are configuration/sequence-side (🟡/⬜): confirm the set and the country
  geographies exist, resolve all addresses, dedupe near-duplicate sites, preserve postal leading
  zeros, decode the intelligent key if present, pick a go-live effective date if dates are
  flattened, and load locations ahead of the worker/department loads.
- **Gaps / next-data requests** — the **geography/address reference** (to validate addresses
  resolve); the **set definitions**; the **worker/department/position extract** (to confirm the
  inventory covers downstream demand); confirmation of **countries in scope** and their geography
  coverage; and the **legal-address list**.

This is the depth bar — for a *data* artifact, match it on the address/geography-validity proof,
the inventory/geography reverse-engineering, the load-readiness checklist, and the foundation-
object sequence; for a *transcript*, mine the location strategy and the legal-address alignment.
