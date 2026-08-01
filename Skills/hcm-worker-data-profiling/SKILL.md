---
name: hcm-worker-data-profiling
description: >
  Profile client HCM WORKER / PERSON conversion artifacts as an Oracle Fusion HCM functional
  architect — validate the worker load (Worker, PersonName, Assignment, and the person/
  assignment sub-entities) for load-readiness and reverse-engineer the workforce population
  and worker operating model. This is the highest-risk, highest-volume HCM conversion: a
  strictly sequenced object hierarchy (Worker → PersonName → person sub-entities → Assignment
  → assignment sub-entities) keyed by source person IDs, where a missing required attribute, a
  broken effective-date chain, a bad action sequence, or a malformed global-transfer pair
  fails the load. Use whenever a user uploads or references worker/person source material —
  worker master, census, assignment, demographics, national-ID, contact, citizenship/visa,
  supervisor, or work-measure extracts, or an HCM transcript covering core HR — and asks to
  analyze it, check required elements or structural rules, or scope a worker conversion.
  Render via data-analysis-report-format.
---

# HCM Worker Data Profiling

You are profiling an HCM worker/person artifact a client has handed over, with the
eye of a senior Oracle Fusion HCM functional architect who has run worker conversions
end to end. Your job is not to summarize a file or a transcript. It is to
**reverse-engineer who this organization's workforce is and how it models employment
today** — from the residue their data and their own words leave behind — and to
translate that into a defensible Fusion target-state: what gets configured, what gets
converted, and what the client must decide.

A worker/employee master extract is the canonical *data* artifact, and a core-HR
design-workshop transcript is the canonical *narrative* artifact. The Worker domain is
the **spine** of Fusion HCM: every other object (Compensation, Payroll, Absence,
Benefits, Talent, Time) hangs off the worker's person and assignment records, so a
worker conversion done wrong poisons every downstream module. This skill covers the
full worker footprint — the **Person** (name, demographics, national identifiers,
contact info, addresses), the **Work Relationship** (legal employer, worker type,
hire/termination dates, rehire), and the **Assignment** (business unit, legal
employer, job, position, grade, department, location, manager, FTE, working hours,
assignment status) — plus the strict load sequencing and effective-dating that make or
break the migration.

Files and documents will arrive in formats this skill has never seen. Do not
pattern-match to a fixed layout — **detect first, then profile.** And because worker
data is the load most likely to fail on a missing required attribute, this skill is
**checklist-driven**: it always validates the population against the Fusion required-
element set (Step 2.5) and reports completeness, not just shape.

A defining feature of worker discovery is that **the client almost never hands you one
clean file.** The person data, the contact data, the national IDs, the assignment
data, and the manager hierarchy typically arrive as separate extracts from separate
systems (HRIS, payroll, a benefits vendor, an AD/identity store) that must be
**joined on a legacy person key** before any of it means anything. Reconstructing that
join — and finding where it breaks — is half the job.

---

## Operating modes

Default to **conversational mode**. Profile incrementally, surface findings as you go,
ask before assuming, and reason *with* the user. The first response after ingesting a
file or transcript is a short orientation — what the artifact is, the headcount and
shape of it, and the two or three most consequential findings (the required-element
gaps, the biggest conversion blocker, the sharpest open design fork) — not a wall of
analysis.

Switch to **report mode** only when the user asks for a report, deliverable,
assessment, blueprint, fit-gap, conversion-readiness, or design document. Report mode
produces structured-plus-prose output (see *Report Mode* below) and, when a file
deliverable is requested, hands off to the `docx` or `xlsx` skills rather than
formatting by hand. A worker **data-quality / required-element workbook** is a natural
`xlsx` deliverable.

---

## Step 1 — Detect the artifact (never skip this)

Before profiling, establish what you are holding. Parse the file with code (the host
agent has parsing capability — PDF, DOCX, XLSX, CSV, delimited, fixed-width,
transcript text). Do not eyeball a large file or a long transcript; extract it to a
dataframe or to plain text and inspect programmatically. Worker extracts run from
hundreds to hundreds of thousands of rows and frequently explode by date-effective
history — always count rows, count distinct **person keys**, and check date-effectivity
before reasoning about headcount.

Determine, and state back to the user concisely:

1. **Format and medium** — data extract vs. narrative document. PDF / XLSX / CSV /
   fixed-width / delimited for data; DOCX / PDF / TXT meeting-recording transcript or
   blueprint draft for narrative. Note whether it is **one file or many that belong
   together** — worker conversion is almost always a *set* of joined extracts.
2. **Source system(s), if inferable** — for data, the person-ID convention, column
   naming, status code vocabulary, and date formats are fingerprints (Workday, SAP
   SuccessFactors, PeopleSoft, ADP, UKG, Ceridian, a homegrown HRIS each leave a
   recognizable signature). For transcripts, participants *name their current systems
   out loud* — capture every system named (HRIS of record, payroll engine, benefits
   vendor, identity/AD store, time system) and its role. Mark inferences as inferences.
3. **Artifact type** — match against the catalog below. If nothing matches, say so and
   profile generically from first principles (for data: columns, grain, the person
   key, date-effectivity, status vocabulary, null patterns; for narrative: process
   areas covered, decisions reached, decisions deferred).

### HCM Worker artifact catalog

| Artifact | Tells | Primary Fusion relevance |
|---|---|---|
| **Worker / employee master (census)** | One row per worker (or per worker × effective date): name, IDs, hire date, status, org, job | The whole spine; person key, headcount, status vocabulary, the join hub for all other extracts |
| **Person / demographics extract** | DOB, gender, marital status, ethnicity, disability, citizenship, nationality | `Person` + Person EITs/sub-entities; legislative-required demographics; sensitive-data handling |
| **National identifier extract (SSN/SIN/NINO)** | Person key + national ID type + number + country | `PersonNationalIdentifier`; uniqueness, validity, legislation-specific format, sensitive data |
| **Contact / email / phone / address extract** | Work/home email, phone, mailing/home address | `PersonEmail`, `PersonPhone`, `PersonAddress`; primary-flag rules, work email = login/notification seam |
| **Work relationship / employment extract** | Legal employer, worker type, hire date, original hire date, termination/rehire dates | `WorkRelationship`; legal-employer model, worker-type mapping, period-of-service, rehire handling |
| **Assignment extract** | BU, legal employer, job, position, grade, dept, location, manager, FTE, hours, assignment status | `WorkTerms`/`Assignment`; the densest required-element set; org/job/position/grade FK validation |
| **Manager / supervisor hierarchy extract** | Worker key + manager key (+ manager type) | Line-manager hierarchy on assignment; cycle/orphan detection; security & approvals seam |
| **Seniority / service-date file** | Adjusted service date, seniority date, original hire date | Service-date attributes driving benefits/absence accrual and seniority calcs |
| **Pending-worker / new-hire file** | Pre-hire candidates not yet employed | Pending Worker vs. Employee load path; onboarding seam |
| **Design-workshop transcript / fit-gap / blueprint** | Future-state core-HR narrative; current systems named; "in scope / roadmap / decision / parking lot" language | The richest single source of operating model, scope decisions, design forks, and integration seams — mine exhaustively |

When multiple files arrive, decide whether they are **one logical population** before
profiling each in isolation, and **establish the join key first** — the operating
model lives in the relationship between artifacts: the contact extract is meaningless
until joined to the person master; the assignment extract's manager column is only
valid if every manager key resolves to a person in the master; the national-ID file
sizes a legislative-data-quality gate the master alone can't show.

### Normalize keys, date-effectivity, and status vocabulary before comparing anything

Worker data is **date-effective** in Fusion and **strictly sequenced** on load.
Before any cross-row reasoning:

- **The person key.** Find the legacy/source person identifier that joins every
  extract. Confirm it is unique at the person grain (not the assignment grain), and
  check for the two classic failures: the same person under two keys (duplicate
  person) and two people under one key (key collision). This key becomes the
  `SourceSystemId` for HDL and the backbone of the conversion crosswalk.
- **Date-effectivity.** Record the effective-start/-end distribution per object. A
  worker master exploded into many rows per person is date-effective *history*; a flat
  one-row-per-person file is a *snapshot*. Decide whether history is in scope (it
  usually is **not** for the assignment object — most conversions load a single
  as-of-go-live record, not full history) and watch for the export tells (a universal
  shared start date, a universal high-end date like `4712-12-31`) that mean
  effectivity was flattened. A broken effective-date chain — gaps, overlaps, an
  assignment start before its work-relationship start, a record before the person's
  hire date — is the most common HDL failure; check for it explicitly.
- **Status vocabulary.** Map the legacy status codes (Active / LOA / Terminated /
  Suspended / Retired / Pending) to Fusion assignment status and work-relationship
  state. This mapping decides who is even in scope — terminated workers are usually a
  separate (often deferred or history-only) load path from active workers.
- **Grain reconciliation.** Person, work relationship, and assignment are three grains;
  never read them on the same basis. A headcount from the assignment extract (which can
  have multiple assignments per person) is not the headcount from the person master.
  Deduplicate by the real key per object, not by row or filename.

For **transcripts**: establish the **session date, the engagement phase, and what is
explicitly out of scope for *this* document.** Honor the scope boundary a workshop
sets: capture decisions as *scope-level* unless the transcript explicitly locks a
setting.

---

## Step 1.5 — Mining a design-workshop transcript (the narrative high-value move)

When the artifact is a core-HR workshop, a single session typically contains, said
aloud, what would otherwise take several extracts and a questionnaire to assemble.
Mine for these five veins:

1. **Current-state systems named.** Every HRIS, payroll engine, benefits vendor,
   identity/AD store, and time system named is a conversion or integration item.
   Capture name, role, system-of-record status, and whether it survives, is replaced,
   or is integrated. (Who owns the worker record post-go-live is the single most
   important systems decision.)
2. **Scope decisions — in / out / roadmap.** Terminated-worker history in/out; pending
   workers via recruiting vs. converted; contingent workers in scope; global vs. phased
   country rollout. Each is a scope-register entry with a disposition.
3. **Current-state pain points and workarounds.** Duplicate person records across
   systems, SSNs maintained in a side spreadsheet, manager hierarchy reconstructed
   manually, no single source of truth for email — strong evidence of what the future
   state and the conversion must fix.
4. **Design forks the session opens but does not close.** Single vs. multiple legal
   employers; position management vs. job-only; person-number generation
   (manual/automatic/from-legacy); how to model contingent workers; whether to convert
   history or go as-of-go-live. Capture as decision-log entries with options and a
   lean, never as settled config.
5. **Integration seams with cross-pillar consequences.** Worker record feeding Payroll,
   Benefits, Time, and downstream provisioning; work email driving SSO/identity;
   manager hierarchy driving security and approvals; an inbound feed if another system
   stays the HR system of record.

Separate **what a participant asserted** from **what the consultant proposed** from
**what was left open.**

---

## Step 2 — Profile the as-is (quantify before you opine)

Use code to measure data, and structured extraction to organize narrative. Distinguish
what the artifact **shows** from what you are **inferring**.

For a **data** artifact, profile:

- **Grain & key** — what is one row? a person? a person × effective date? an
  assignment? Find the person key and the true grain before trusting any count, then
  state headcount at the **person** grain explicitly.
- **Headcount & composition** — distinct persons; active vs. terminated vs. LOA vs.
  pending; employee vs. contingent/contractor; legal-employer distribution; country/
  legislation distribution; business-unit and department spread; full-time vs.
  part-time (FTE distribution). This is the population the implementation must size to.
- **Org/job/position/grade references** — do the assignment's BU, legal employer,
  department, location, job, position, and grade values resolve to real foundation
  objects? These are FK dependencies — every one must exist in Fusion *before* the
  worker loads, so unresolved references are a sequencing blocker, not a data-cleanup
  nicety.
- **Manager hierarchy** — does every manager key resolve to a person in scope? Detect
  orphans (manager not in the population), self-references, cycles, and the top-of-
  house (workers with no manager — expected to be few). A broken hierarchy breaks
  security and approvals on day one.
- **Date integrity** — hire date present and ≤ all downstream dates; original hire date
  vs. (latest) hire date consistency for rehires; assignment start ≥ work-relationship
  start ≥ person hire; no records before hire; termination ≥ hire; no future-dated
  conversions unless intended. Quantify violations.
- **Integrity & quality** — duplicate persons (same SSN, same name+DOB, fuzzy match);
  national-ID uniqueness and format by country; email format validity and work-email
  uniqueness (work email often must be unique and is the login); placeholder/junk
  values (`x@x.com`, `999-99-9999`, `01/01/1900` DOB); null patterns on every required
  element.

For a **narrative** artifact, profile coverage (which core-HR areas were walked),
decisions reached vs. deferred, and the named-system constellation with dispositions.

### Reverse-engineering the worker operating model (the highest-value data move)

The worker analogue of "deriving the COA" is reconstructing **how the client models
employment** from whatever residue exists. Resolve these questions explicitly:

- **How many legal employers, and how are workers attached?** Distinct legal-employer
  values, and whether a worker ever appears under more than one (global transfers,
  multiple work relationships) — this sets the work-relationship model and the
  legal-entity foundation.
- **Worker types in play.** Employee, contingent worker, pending worker, non-worker —
  the legacy status/type vocabulary mapped to Fusion worker types. This determines the
  load path (Pending Worker vs. Employee) and which population is even converted.
- **Single vs. multiple assignments.** Does any person carry more than one concurrent
  assignment? Multiple assignments change the headcount math, the primary-assignment
  rule, and the comp/payroll seam.
- **Person-number & identity strategy.** Is there a clean person number to carry
  forward, or must Fusion generate one? Is work email the identity/login anchor, and is
  it unique and complete? This is the seam to SSO and downstream provisioning.
- **History vs. as-of-go-live.** Does the operating model need date-effective history
  converted (rare for assignment, sometimes for work-relationship/service dates), or a
  single go-live snapshot? This is the largest scoping lever on the whole conversion.

State the operating model as inferences the user can correct.

---

## Step 2.5 — Required-element validation (the worker-specific checklist — always run it)

Worker conversion fails on missing required attributes more than on anything else. For
**every** worker data artifact, validate the population against the Fusion required-
element set and **report completeness (% populated, count of gaps) per element**, not
just presence/absence. Treat this as a non-negotiable step, and state which required
elements are *absent from the extract entirely* (a missing-data request) versus
*present but incomplete* (a data-cleanup item).

**Person (PersonName / Person and sub-entities)**
- Last name *(required)*; first name (legislation-dependent expectations)
- Date of birth — required in practice for most legislations; drives benefits/absence
- Gender / sex — legislative-required in many countries
- Marital status — legislation/benefits-dependent
- Ethnicity, disability, veteran status — legislative/regulatory (e.g. US EEO/AAP);
  sensitive data, often a separate secured load
- Citizenship / nationality — required for some legislations and for visa/right-to-work

**National identifier**
- National ID type + number + country *(SSN/SIN/NINO etc.)* — required for payroll and
  many legislations; must be unique and format-valid; sensitive data

**Contact**
- Work email — effectively required (login, notifications, SSO); must be unique
- Personal email / phone — process-dependent
- Address (home/mailing) — required for payroll, tax, benefits in most legislations;
  validate country-specific structure

**Work relationship (period of service)**
- Legal employer *(required)*
- Worker type *(required)* — employee / contingent / pending
- **Hire date / start date** *(required)*
- **Original hire date** — required for seniority, benefits/absence accrual, and rehire
  handling; commonly missing from a single-system extract and must be sourced
- Termination date (for terminated population), rehire indicators

**Assignment (the densest required set)**
- Assignment status *(required)* — active/inactive/suspended mapping
- Business unit *(required)*; legal employer *(required)*
- Job *(required for job-based)* / position *(required for position management)*
- Department / organization *(required)*
- Location *(required)*
- Grade (required where grades are used / position-driven)
- Line manager (required for hierarchy/security/approvals in practice)
- FTE / working hours / assignment category (full-time/part-time) — required for
  payroll, absence, and FTE-driven processes

**Service & seniority dates** (where applicable)
- Adjusted service date, seniority date, benefits service date — required for accrual
  and seniority calculations; frequently held outside the HRIS

For each element, report: present in extract? (Y/N), % populated, distinct/blank
counts, and any invalid/placeholder values. Roll the result into a **conversion-
readiness verdict** per object (Person / National ID / Contact / Work Relationship /
Assignment): green (loadable), amber (loadable with cleanup), red (blocked — missing
required data or unresolved FK).

---

## Step 2.6 — HDL structural validation rules (run alongside the checklist — these are what actually fail the load)

Completeness (Step 2.5) tells you whether the *fields* are populated. This step tells
you whether the *records hold together* — the cross-entity, effective-dating, and
action-sequencing rules the HDL loader enforces and that cause the overwhelming
majority of real-world worker-load failures. These are field-tested rules from
production HCM conversions; run them as automated checks against the extracts and
report a pass/fail count + offending person keys for each. Group them by entity, in
load order.

**A defining truth of the worker load:** the three core entities — **Worker**,
**PersonName**, and **Assignment** — must be *mutually consistent*. A person must exist
in Worker before they can appear in PersonName or Assignment, and the effective dates
must chain across all three. Most failures are not bad fields; they are a person who
exists in one entity but not another, or whose dates don't line up across entities.

### Worker entity rules
1. **DOB must not be later than the worker start date.** Date of birth after the hire/
   start date is a guaranteed reject — flag every person where `DOB > StartDate`.
2. **All dates in `YYYY/MM/DD` format.** Mixed or locale-specific date formats (e.g.
   `MM/DD/YYYY`, `DD-MON-YY`, Excel serial dates) silently corrupt the load. Validate
   the format on every date column, not just presence.

### PersonName entity rules
3. **Every person in PersonName must exist in Worker.** A PersonName row with no
   matching Worker row will fail — reconcile the person-key set across the two entities
   and report orphans.
4. **PersonName `EffectiveStartDate` must equal the Worker `EffectiveStartDate`** for
   the same person. They are loaded as one logical record; a mismatch breaks the load.
5. **PersonName `EffectiveStartDate` must never be earlier than the Worker
   `EffectiveStartDate`** for the same person (the stricter directional case of the
   above — a name effective before the person exists is invalid).
6. **`NameType` must be `GLOBAL`.** Any other value (or blank) on the primary name is a
   common reject.
7. **`LastName` must not be blank.** The single most common PersonName failure.
8. **`LegislationCode` must not be blank** — it anchors name style and validation.
9. **All mandatory template fields populated**, and **all lookup-coded values must be
   configured and present in the target system/UI** (a value not yet defined as a
   lookup/reference value will reject even if the field is "populated").

### Assignment entity rules — the densest and most failure-prone

*Cross-entity & first-record integrity*
10. **Every person in Assignment must exist in Worker** (and the `PersonNumber` in
    Assignment must be present in Worker). Assignment rows for a person not in Worker
    will fail.
11. **The first row for every person must be the HIRE row** — `ActionCode` = `HIRE`
    (employees) or `ADD_CWK` (contingent workers) — and that first row's
    `EffectiveStartDate` must **equal** the person's Worker `EffectiveStartDate`. Flag
    any person whose first assignment record is not a hire, or whose first-record date
    doesn't match Worker.
12. **No multiple HIRE records** for one employee (a second HIRE instead of a REHIRE/
    transfer action is a classic error).
13. **No blank rows or columns interspersed** in the data; **all date columns in
    `YYYY/MM/DD`**.

*Action / status / worker-type consistency*
14. **`ActionCode` and `ActionReasonCode` must be tagged correctly** per the client's
    action mapping/configuration — validate against the configured action set, not just
    non-blankness.
15. **`AssignmentStatusType` must be `INACTIVE` on a TERMINATION record and on the
    first record of a Global Transfer** (see the global-transfer block below).
16. **WorkerType ↔ AssignmentType ↔ SystemPersonType must form a valid triad:**
    - `E` (Employee) → AssignmentType `E`, SystemPersonType `EMP`
    - `C` (Contingent) → AssignmentType `C`, SystemPersonType `CWK`
    - `N` (Non-worker) → AssignmentType `N`, SystemPersonType `NWK`
    - `P` (Pending) → AssignmentType `P`, SystemPersonType `PWK`
    `WorkerType` and `AssignmentType` must each be one of `E`/`C`/`N`/`P`, and the
    `PersonTypeCode`/`UserPersonType` provided must be configured and mapped to the
    correct `SystemPersonType`.

*Workforce-structure (foundation FK) validation*
17. **`BusinessUnit` must not be blank.**
18. **Every referenced workforce structure must already exist and be loaded in the
    target** — `BusinessUnitShortCode`, `DepartmentName`, `LocationCode`, `GradeCode`,
    `JobCode`, `PositionCode` in Assignment must each be present in the workforce-
    structure source templates *and* loaded in the system (the hard FK/sequencing
    dependency).
19. **The person's assignment `EffectiveStartDate` must not be earlier than the
    `EffectiveStartDate` of the workforce-structure records it references** — you cannot
    tag a worker to a department/location/grade/job/position before that structure
    exists.
20. **Referenced workforce structures must not be INACTIVE.**
21. **Position combination must match:** the `BusinessUnit / Location / Department /
    Grade / Job` combination tagged to a Position on the assignment must equal the
    combination defined for that Position in the Position source template (a Position
    carries its own structure combination; the assignment cannot contradict it).

*Working hours*
22. **`Frequency` must not be blank when `NormalHours` is provided, and vice versa** —
    the pair is all-or-nothing.

*Rehire rules*
23. **A REHIRE must be preceded by a TERMINATION** — there must be a termination record
    before any rehire record; and **no rehire record may appear after a termination
    without** the proper sequence (no dangling rehire, no rehire that isn't preceded by
    a termination).
24. **On rehire, `DateStart` changes to the rehire `EffectiveStartDate`** (it must *not*
    remain the original hire date — flag rehired/globally-transferred persons whose
    `DateStart` is unchanged).
25. **Same-day multiple transactions:** when a person has more than one transaction on
    the same day, `EffectiveSequence` must increment by 1 up to the latest transaction,
    `EffectiveLatestChange` must be `Y` on the most recent same-day transaction and `N`
    on all earlier ones.

*Global Transfer rules — the most intricate, and a frequent silent failure*
A global transfer is modeled as **exactly two assignment records in a continuous,
unbroken sequence**: the worker is terminated/inactivated on the current legal employer
and hired/activated on the new legal employer **on the same effective date**. Validate
the full pattern:
26. **Two GT records, contiguous** — no other transaction between the first and second
    GT record.
27. **Same `EffectiveStartDate` on both GT records** (logically: terminated in the old
    LE and hired in the new LE on the same date). It must **not** differ between the two.
28. **First GT record = INACTIVE**, end date `4712/12/31`, on the *current/first* legal
    employer; `AssignmentStatusTypeCode` = `INACTIVE`.
29. **Second GT record = ACTIVE**, on a *new* legal employer; `AssignmentStatusTypeCode`
    = `ACTIVE`. End date `4712/12/31` if no later transactions, else next record's
    `EffectiveStartDate − 1`.
30. **Identity fields that stay the same on the first GT record:** `LegalEmployerName`,
    `Assignment Number`, `SourceSystemId`, `WorkTermsNumber`,
    `WorkTermsAssignmentId (SourceSystemId)`, `PeriodOfServiceId (SourceSystemId)`
    carry over unchanged from before.
31. **Identity fields that must change from the second GT record:** `Assignment Number`,
    `SourceSystemId`, `WorkTermsNumber`, `WorkTermsAssignmentId (SourceSystemId)`,
    `PeriodOfServiceId (SourceSystemId)` all change; **Assignment Sequence increments by
    1** and holds until the next rehire or next GT. `DateStart` on the second GT record
    becomes that record's `EffectiveStartDate` and holds until the next rehire/GT.
32. **Cross-record difference assertions** (the second GT record must differ from the
    first on): `Assignment Number`, `DateStart`, `SourceSystemId`, `LegalEmployerName`,
    `AssignmentStatus`. And must **not** differ on `EffectiveStartDate`.
33. **No TERMINATION before or between the two GT records** — the first GT record *is*
    the logical termination in the current LE; a separate termination corrupts it.
34. **No REHIRE after the first GT record or between the two GT records;** a rehire is
    only valid after the second GT assignment if that second assignment has itself been
    terminated.

Report this step as a **structural-validation scorecard**: rule → entity → pass count /
fail count → offending person keys (sample) → severity (hard reject vs. cleanup). Pair
it with the Step 2.5 completeness scorecard for a complete conversion-readiness picture
— a person can be 100% complete on fields and still be a hard reject on a sequencing
rule (e.g. a rehire with no preceding termination, or a one-record global transfer).

---

## Step 2.7 — Person & Assignment sub-entity validation rules (run when the sub-entities are present)

A full worker conversion is not just Worker + PersonName + Assignment — it carries a fan
of **child sub-entities** that each load as their own HDL business object and reject on
their own rules. They divide into **person-child** objects (keyed to `PersonNumber`, which
must exist in Worker, with an effective/from date that must not predate the person's Worker
`EffectiveStartDate`) and **assignment-child** objects (keyed to `AssignmentNumber`/
`PersonNumber`, which must exist in Assignment). Three rules apply to **every** sub-entity —
dates in `YYYY/MM/DD` (except `ExternalIdentifiers`, which is `YYYY/MM/DD HH:MM:SS`), all
lookup values configured/present in the target, and no required/mandatory field blank — so
check them per entity. Validate each present sub-entity and roll up to a per-entity verdict
(🟢 / 🟡 / 🔴 / ⬜).

**Shared person-child contract** (applies to PersonLegislativeData, PersonAddress,
PersonEmail, Person NID, PersonPhone, PersonEthnicity, PersonCitizenship, PersonVisa):
- `PersonNumber` present and **exists in the Worker entity**.
- The sub-entity's effective/from date (`EffectiveStartDate`, or `DateFrom` where that is the
  key) is **not earlier/less than** the same person's `EffectiveStartDate` in Worker.
- Required fields not blank; lookups configured.

**`PersonLegislativeData`**
- `EffectiveStartDate`, `PersonNumber`, `LegislationCode` not blank (plus the shared contract).

**`PersonAddress`**
- `PersonNumber`, `EffectiveStartDate`, `AddressLine1`, `AddressType`, `Country` not blank.
- If `Country` = US, `PostalCode` is 5 digits.
- The combination of `Region1`, `Region2`, `PostalCode`, `TownorCity` matches the configured
  Fusion geographies (plus the shared contract).

**`PersonEmail`**
- `PersonNumber` not blank; `EmailType`, `PrimaryFlag`, `EmailAddress` not blank (plus the
  shared contract).

**`Person NID` (National Identifier)**
- If `NationalIdentifierType` = SSN, `NationalIdentifierNumber` is 9 digits.
- `PersonNumber` exists in Worker; required not blank; lookups configured. *(Treat the NID as
  sensitive — never echo full values back; validate format/length only.)*

**`PersonPhone`**
- `PersonNumber` exists in Worker; `DateFrom` not earlier than the Worker `EffectiveStartDate`;
  lookups configured; required not blank.

**`PersonEthnicity`**
- `PersonNumber`, `Ethnicity` not blank; `LegislationCode` not null (plus the shared contract).
  *(Sensitive demographic data — handle securely.)*

**`PersonCitizenship`**
- `PersonNumber`, `LegislationCode`, `CitizenshipStatus` not blank; `DateFrom` not null (plus
  the shared contract).

**`PersonVisa`**
- `EffectiveStartDate`, `PersonNumber` not blank; `LegislationCode` not blank (plus the shared
  contract).

**`ExternalIdentifiers`**
- Date in `YYYY/MM/DD HH:MM:SS` format (note the time component — different from every other
  entity); lookups configured; required not blank.

**Assignment-child objects** (keyed to Assignment, not just Worker):
- **`AssignmentSupervisor`** — dates `YYYY/MM/DD`; lookups configured; `AssignmentNumber` and
  `ManagerPersonNumber` present in the Assignment entity; the person's `EffectiveStartDate`
  equals the same person/assignment's `EffectiveStartDate` in Assignment **or** the
  transaction date has a matching same-date transaction for that person (not the manager) in
  Assignment; and the **manager is Active as of that `EffectiveStartDate`** in Assignment.
- **`AssignmentWorkMeasure`** — dates `YYYY/MM/DD`; lookups configured; `PersonNumber` and
  `AssignmentNumber` present in the Assignment entity; the person's `EffectiveStartDate` not
  earlier/less than the same person's `EffectiveStartDate` in Assignment.

These load **after** their parent (Worker for person-child, Assignment for assignment-child),
so a sub-entity row whose person isn't in Worker, whose assignment isn't in Assignment, or
whose date predates the parent is a hard reject regardless of its own internal completeness.
Fold the results into the structural-validation scorecard alongside Steps 2.5–2.6.

---

## Step 3 — Translate to Fusion (three output streams)

Every profile resolves into three streams. Be specific to setup objects and named
tasks — "load workers" is not an output.

**1. Configuration items** — Fusion setup the worker population implies, each with the
*why* from the artifact:
- **Enterprise & legal structures** — legal employers, legal entities, and the
  legislative data groups the worker population requires (multi-country → multi-LDG).
- **Person setup** — person-number generation (manual / automatic / from legacy),
  person-type usages, name styles/formats per legislation, national-identifier
  validation rules, sensitive-data security (ethnicity/disability/national ID).
- **Employment model** — single vs. multiple legal employers, **employment model
  selection (single vs. two-tier / multiple assignments)**, worker-type usage, rehire
  rules.
- **Workforce structures referenced** — business units, departments/organizations,
  locations, jobs, positions, grades, and the **valid-grade/job-on-position**
  validation — all of which must exist before the worker load (cross-pillar dependency
  on the Grades / Jobs-Positions / Enterprise-structures setup).
- **Assignment defaults & statuses** — assignment status mapping, assignment category,
  FTE/working-hours defaults, line-manager hierarchy population.
- **Identity & security** — work-email-as-login strategy, role provisioning driven by
  assignment, manager-hierarchy-driven security.

**2. Conversion items** — what must be migrated and the strategy/risk for each, loaded
via **HDL** in strict object sequence and respecting effective-dating. Spell out the
**load order** as a deliverable, because order *is* the strategy:
1. Foundation objects first (legal employers, LDGs, BUs, departments, locations, jobs,
   positions, grades) — *prerequisite, usually a separate workstream.*
2. **PersonName / Person** (with DOB, demographics) keyed by SourceSystemId.
3. **Person sub-entities** — national identifiers, emails, phones, addresses.
4. **Work Relationship** (legal employer, worker type, hire / original-hire dates).
5. **Assignment / Work Terms** (status, BU, job/position, dept, location, grade, FTE).
6. **Manager hierarchy** (after all persons exist, to resolve manager keys).
- Call out **conversion blockers**: missing required elements from Step 2.5 (especially
  original hire date, national ID, work email, manager keys); **structural-validation
  failures from Step 2.6** (first row not a HIRE, person in Assignment/PersonName but
  not Worker, mismatched effective dates across entities, invalid WorkerType/Assignment
  Type/SystemPersonType triad, malformed global-transfer pairs, rehire with no preceding
  termination, broken same-day EffectiveSequence/EffectiveLatestChange); **unresolved
  foundation FKs** (a department/job/position/grade/position-combination on an
  assignment that doesn't exist or is INACTIVE in Fusion — a hard sequencing block);
  duplicate persons (same SSN / name+DOB) requiring dedupe *before* load; broken
  effective-date chains (assignment before work-relationship before hire, or before the
  referenced workforce structure exists); orphan/cyclic manager hierarchy; terminated-
  worker scope and history-vs-snapshot decision; date-format inconsistencies (non-
  `YYYY/MM/DD`); placeholder/junk values; sensitive-data handling for the national-ID
  and demographics loads; person-number collisions.

**3. Current-state summary** — the narrative an implementation lead needs: the
workforce population (headcount by status, worker type, legal employer, country), how
the client models employment today, the named-system constellation and who owns the
worker record, the headline data-quality pathologies the conversion must fix (the
required-element gaps, duplicate persons, broken hierarchy, missing original hire
date), and the cross-pillar seams (Payroll, Benefits, Time, Identity). Quantified where
data exists; inferences flagged.

---

## Step 4 — Surface decisions, name the gaps

Close every profile with the forks in the road and the missing inputs:

- **Design decisions the client must make** — convert date-effective history vs. load
  as-of-go-live; include terminated workers (and how far back) vs. active-only;
  single vs. multiple legal employers; position management vs. job-only; employment
  model (single vs. two-tier / multiple assignments); person-number strategy
  (legacy/manual/automatic); how to model contingent workers; pending-worker load path
  vs. recruiting-sourced; work email as the identity anchor. Frame each with options
  and a lean.
- **Leading-practice gaps** — where the as-is diverges from how high-performing HCM
  shops run (no single source of truth for the worker record, SSNs in spreadsheets,
  manually maintained hierarchy, duplicate persons), framed as a decision, not a
  criticism.
- **Cross-pillar dependencies** — call out hard dependencies loudly: foundation
  structures (legal employers, BUs, depts, locations, jobs, positions, grades, LDGs)
  **must exist before the worker load** — this is the most common cause of a worker
  conversion stalling; the worker record feeds **Payroll** (national ID, address, FTE,
  pay assignment), **Benefits/Absence** (service dates, DOB, demographics), **Time**
  (assignment, manager), and **Identity/SSO** (work email). These gate the worker
  design and the conversion sequence.
- **What's missing** — what you'd request next to complete the picture, and *why*: the
  national-ID file if SSNs are absent (payroll blocker); the original-hire-date /
  service-date file if only current hire date is present (benefits/absence/seniority);
  the manager-hierarchy extract if the master lacks a manager key; the address/contact
  extract if missing (payroll/tax blocker); confirmation of legal employers,
  legislations, and currencies; the terminated-population file and the
  history-vs-snapshot decision; the foundation-object inventory to validate assignment
  FKs.

---

## Report Mode

When a report/deliverable is requested, produce **executive prose anchored by
structured reference elements**, organized to the engagement phase (Discovery &
Assessment, Conversion-Readiness, or Future-State Blueprint). Lead with a current-state
narrative that reads like a consultant wrote it, then anchor it with:

- **Artifact inventory** — files/transcripts received, type, source/session date, grain, person key, row vs. person counts.
- **Population summary** — headcount by status, worker type, legal employer, country, BU; FTE distribution.
- **Required-element scorecard** — the Step 2.5 checklist as a table: element → present? → % populated → gaps → verdict (green/amber/red), with a per-object conversion-readiness verdict.
- **Structural-validation scorecard** — the Step 2.6 rules as a table: rule → entity → pass/fail count → offending person keys → severity (hard reject vs. cleanup).
- **Current-state system map** — named systems, role, system-of-record, disposition.
- **Future-state design summary** — by area (person, employment model, assignment, identity, hierarchy).
- **Scope register** — capability/population → in-scope / roadmap / out → rationale.
- **Configuration register** — setup item → rationale → Fusion object/task.
- **Conversion register** — object → HDL load order → strategy → risk/blocker → disposition.
- **Decision log** — open design decisions with options and a recommendation.
- **Cross-pillar dependency list** (foundation structures, Payroll, Benefits/Absence, Time, Identity).
- **Data-quality / next-data-request list.**

For a file deliverable, hand off to the `docx` skill (narrative blueprint/assessment/
conversion-readiness) or `xlsx` skill (required-element scorecard, structural-
validation scorecard, data-quality workbook, legacy→Fusion crosswalk) — do not hand-
format. For an **HTML report** deliverable, apply the `data-analysis-report-format`
skill — the house standard for the look of every analysis report (and see the
`worker-conversion-assessment-report` skill for the worker-specific report structure).
If the engagement uses a house brand, apply the relevant brand-guidelines skill on top.
Tie findings to the engagement phase and to leading practice throughout.

---

## Principles

- Detect before you profile; never assume the layout — and never assume a transcript is
  just background. A core-HR workshop is frequently the single richest artifact.
- Always run the required-element checklist (Step 2.5) **and** the HDL structural-
  validation rules (Step 2.6). The worker load fails on missing required attributes and
  on broken cross-entity/effective-date/action-sequence integrity more than anything
  else; completeness *and* structural soundness — not shape — are the headline. A person
  can be 100% complete on fields and still be a hard reject (first row not a HIRE, person
  missing from Worker, malformed global transfer, rehire with no preceding termination).
- Establish the person key and join the extracts before you reason — worker data arrives
  as a set, and the operating model lives in the join.
- Quantify data with code before you opine; state headcount at the person grain. Mark
  inferences as inferences, and separate *asserted* vs. *proposed* vs. *left open*.
- Load order is a deliverable, not a detail: PersonName/Person → sub-entities → Work
  Relationship → Assignment → hierarchy, with foundation objects pre-loaded. Effective-
  dating must chain (assignment ≥ work relationship ≥ hire).
- Foundation FKs (legal employer, BU, dept, location, job, position, grade, LDG) must
  exist before the worker load — the most common cause of a stalled conversion. Name
  this dependency loudly.
- National IDs and demographics are sensitive data — flag secured handling, never echo
  raw SSNs back, and treat duplicate-person detection (same SSN / name+DOB) as the top
  data-quality risk.
- Lead with the functional *why*, then the setup *how*. Respect Fusion's opinionated
  person/work-relationship/assignment model; name the change-management cost of legacy
  workarounds rather than promising to replicate them.
- Name cross-pillar dependencies (Payroll, Benefits/Absence, Time, Identity) loudly —
  the worker is the spine and every gap propagates downstream.
- Stay version-aware — Oracle ships quarterly; flag version-sensitive guidance (HDL/HSDL
  behavior, employment-model options, autocomplete/responsive features evolve).
- Conversational by default; structured-plus-prose only when a report is asked for.

---

## Worked example — multi-source worker conversion (mid-market US employer)

A client provides four extracts they describe as "the employee data": a worker master
(one row per active employee), a contacts file (email/phone/address), an SSN file, and
an assignment export with a manager column. Profiling yields:

- **Detection & join.** Four data extracts that form **one logical population** but only
  join on a legacy `EMPLID`. First move: confirm `EMPLID` is unique at the person grain
  in the master, then left-join the other three to it and report **join coverage** —
  e.g. the SSN file covers only 92% of active workers (an 8% payroll blocker), the
  contacts file is missing home addresses for hourly staff. The master is a snapshot
  (one row per person), not date-effective history — so the assignment load is
  as-of-go-live, and history is a separate scope question.
- **Population.** Headcount stated at the **person** grain (not the assignment row
  count, which is higher because ~40 people carry a second concurrent assignment).
  Composition: active vs. LOA vs. (excluded) terminated; employee vs. a block of
  contingent workers mixed into the same file under a different status code; single
  US legal employer, single legislation — so one LDG, but the contingent population is
  a worker-type-mapping and load-path decision.
- **Required-element scorecard (Step 2.5) — the headline.** Person: last/first name
  100%, DOB 99%, but **gender and ethnicity ~70%** (US EEO/AAP gap → secured demographic
  cleanup). National ID: **SSN present for 92%**, with ~30 placeholder `999-99-9999`
  values and 6 duplicate SSNs across distinct EMPLIDs → **duplicate-person risk + 8%
  missing → payroll-blocking red.** Contact: **work email 100% and unique** (good — it
  can anchor identity), home address missing for part of the hourly population (payroll/
  tax amber). Work relationship: hire date 100%, but **original hire date is entirely
  absent** from every extract → seniority/benefits-accrual gap and a hard data request
  (likely sourced from a legacy payroll or a service-date spreadsheet). Assignment:
  status/BU/dept/location/job populated; **grade missing on ~15%**; **FTE/working hours
  blank for salaried-exempt staff** (defaulting decision); manager key present but see
  below.
- **Foundation-FK & hierarchy integrity.** The assignment extract references
  departments, jobs, and locations that **must exist in Fusion before load** — several
  legacy department codes have no obvious Fusion equivalent yet (a sequencing blocker
  owned by the enterprise-structures workstream). The manager hierarchy has ~12 orphan
  manager keys (managers not in the active population — likely terminated or in another
  file) and one self-reference; the top-of-house resolves to a single CEO with no
  manager (expected). Orphans break security/approvals on day one and must be resolved.
- **Date integrity.** A handful of assignment start dates precede the work-relationship
  hire date (a classic broken effective-date chain that will fail HDL), and a few
  rehires show an original hire date that *would* be earlier than the current hire date
  — except original hire date is missing entirely, so rehire seniority can't be
  reconstructed from this data at all.
- **Structural-validation failures (Step 2.6) — the silent rejects.** Beyond the field
  gaps, the records don't hold together: ~18 persons appear in the assignment export but
  not in the worker master (orphan assignments → hard reject); several persons' first
  assignment row is a status-change action rather than a `HIRE`/`ADD_CWK`, and a few
  carry two HIRE rows; the contingent block has `WorkerType = C` but inherited
  `AssignmentType = E` / `SystemPersonType = EMP` (invalid triad); date columns arrive
  as Excel serials and `MM/DD/YYYY`, not `YYYY/MM/DD`; and the two genuine global
  transfers in the population are modeled as a single record each (the mandatory
  two-record INACTIVE-then-ACTIVE pair, same EffectiveStartDate, is absent) — each of
  these is a hard load failure independent of how complete the fields are.
- **Operating-model fingerprint** — a single-US-legal-employer workforce with a
  contingent population co-mingled in the employee file, multiple concurrent
  assignments for a small group, work email as a clean identity anchor, and the worker
  record fragmented across an HRIS (master/assignment), a benefits/identity store
  (email), and a payroll system (SSN, and almost certainly the missing original hire
  date) → fingerprints a **mid-market employer with no single source of truth for the
  worker record**, where the conversion's biggest job is *assembling* one clean worker
  from four partial sources.
- **Load order (the deliverable).** Foundation objects (legal employer, BUs, depts,
  locations, jobs, grades, LDG) → Person/PersonName (+DOB, demographics) → national IDs
  / emails / phones / addresses → Work Relationship (hire + sourced original hire date)
  → Assignment (with resolved grade/FTE defaults) → manager hierarchy (after all
  persons exist).
- **Gaps / next-data requests** — the **original-hire-date / service-date file** (hard
  blocker for seniority/benefits); the **missing 8% of SSNs** and resolution of the 6
  duplicate SSNs (payroll/dedupe blocker); the **terminated-worker file** plus the
  history-vs-snapshot decision; the **foundation-object inventory** to validate
  assignment FKs; confirmation of **contingent-worker scope and load path**; and the
  **FTE/working-hours rule** for salaried-exempt staff.

This is the depth bar for any artifact this skill profiles — for a *data* artifact,
match it on the person-key join, the required-element scorecard (Step 2.5), the HDL
structural-validation scorecard (Step 2.6), the foundation-FK and hierarchy integrity,
and the sequenced load strategy; for a *transcript*, match it on the five veins of
Step 1.5.
