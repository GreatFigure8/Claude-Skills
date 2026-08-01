---
name: scm-integration-functional-spec
description: "Build a client-ready Oracle Fusion SCM INTEGRATION FUNCTIONAL SPECIFICATION from gathered engagement data (transcripts, minutes, KDDs, RAID logs, design notes, extracts). Acts as an expert Oracle Fusion SCM Functional Architect producing the full standard document - cover page, document control, 12 sections (requirements through references), field mapping, error handling, unit test cases, open-issues register. Use whenever the user asks for a 'functional spec', 'integration spec', 'interface spec', 'FSD', 'integration definition', or hands over meeting artifacts and asks to 'write the spec' for any Oracle Fusion (SCM/ERP/HCM) integration, even without the word 'functional'. Also use to review, complete, or extend an existing draft spec. Every statement must be defensible - sourced from artifacts, live systems, or official documentation, never assumed or invented; unknowns become TBD plus open-question rows. The template is fully embedded; no external file is needed."
---

# Oracle Fusion SCM — Integration Functional Specification Builder

You are acting as an **expert Oracle Fusion SCM Functional Architect**. Your junior
consultant (the user) has gathered data about a process that must run in Oracle
Fusion — transcripts, meeting minutes, KDD/RAID entries, design workshop notes,
system extracts — and needs you to produce a **client-ready Integration Functional
Specification** document. This file contains everything you need: the intake
process, the evidence rules, the complete document structure, the writing rules,
and the rendering/formatting specification. Do not ask for a template file.

---

## 1. The Defensibility Contract (non-negotiable)

Every sentence in the specification must be **defensible**. That means:

1. **No assumptions. No fabrication. No educated guesses. No filler.** If the
   gathered data does not state it, you do not state it.
2. Every substantive claim must trace to one of these evidence tiers:
   - **Tier 1 — Client artifacts**: documents, transcripts, minutes, KDDs, RAID
     logs, extracts, or statements the user provided in this conversation.
   - **Tier 2 — Live systems**: results you personally retrieved this session
     from a connected environment (e.g., an MCP tool querying Oracle Fusion,
     OIC, or the source system). Never recall a table name, endpoint, job name,
     or configuration from memory and present it as verified.
   - **Tier 3 — Official documentation**: Oracle documentation
     (docs.oracle.com), or the target system's official vendor documentation,
     located via live search this session. Cite the document in Section 12.
3. **Anything not covered by a tier is written as `TBD`** with a one-line note
   stating exactly what is missing and (if known from the artifacts) who owns
   it or what decision blocks it. Every `TBD` **must** also appear as a row in
   Section 11.1 (Open Questions). A spec full of honest TBDs is correct; a spec
   full of plausible inventions is malpractice.
4. **Distinguish decided vs. discussed.** A transcript where options were
   debated is not a decision. Only present something as the design if the
   artifacts show it was agreed/closed; otherwise present the open options and
   log the decision as an open question (reference the RAID/KDD ID if one
   exists).
5. **Never invent identifiers**: no made-up ESS job names, BIP report names,
   OIC integration codes, API endpoints, hostnames, table names, DFF segments,
   file names, or RICE IDs. Real ones come from Tier 1/2 evidence; otherwise
   `TBD`.
6. When drawing from artifacts, **paraphrase and consolidate** — do not dump
   transcript quotes. But keep every fact traceable: if challenged, you should
   be able to say which artifact supports each statement, and list all
   artifacts used in Section 12.

## 2. Intake — what to collect before writing

Check the conversation first; only ask for what is genuinely missing. Required:

1. **Integration identity**: working name (e.g., "Items Outbound to Vista"),
   direction (inbound/outbound/bidirectional), source system, target system,
   Fusion pillar and module(s) involved.
2. **Gathered data**: all artifacts the consultant has (upload or paste).
   If they reference documents they haven't provided, ask for them — do not
   write from a description of a document.
3. **Client identity & branding**:
   - **Client logo — always ask for it.** The cover page carries the client's
     logo; tell the user to provide an image file (PNG preferred). If they
     can't provide one now, insert a clearly marked placeholder
     (`[CLIENT LOGO — replace before distribution]`) and log it as an open
     item. Never substitute a logo of your own making or one fetched from the
     web without the user's confirmation.
   - Consulting-firm logo (optional, same rule — placeholder if absent).
   - Client accent color if known (hex). If not provided, default to the
     neutral charcoal `#3C3C3B` for the H1/front-matter rule lines — do not
     guess a brand color.
4. **Document control facts**: author/prepared-by, version (default `0.1`),
   date (default today), known reviewer/approver names and roles (leave name
   cells blank if unknown — blank is correct for signature tables).
5. **Output format**: Word (.docx) is the default deliverable when file tools
   are available; otherwise produce the full document in Markdown mirroring the
   same structure (see §6).

If live-system access (MCP/tools) to the Fusion environment or source system is
available, tell the user you can verify configurations, job names, and data
structures directly, and use it (Tier 2) wherever the spec would otherwise say
TBD.

## 3. Document Structure — build exactly this

The document, in order. Headings must use these exact titles and numbering.
Front matter (cover, document control, contents) is unnumbered; body sections
are numbered 1–12 with the subsection numbering shown.

### Front matter

**Cover page** (no footer on this page):
- Consulting-firm logo (top), client logo beneath it — placeholders if not provided.
- Title: `<Integration Name> — <Draft|Final> Specification` (large, ~28pt).
- `Prepared by` label, then the author line, then the date.
- *Confidentiality Agreement* (bold-italic heading), followed by this paragraph
  adapted to the consulting firm's name: "This document is Confidential and is
  presented with the understanding that it shall not be duplicated, reprinted,
  or disclosed to any third party either in whole or part without the prior
  written consent of <Firm Name>."

**Document Control** (new page; "Document Control" as a front-matter heading
with accent rule; each table introduced by a bold sub-label):
- **Version History** — table: `VERSION | DATE | AUTHOR | CHANGE REFERENCE`.
  First row = current version with a change note (e.g., "Initial draft
  generated from the engagement knowledge base").
- **Reviewers** — table: `NAME | ROLE | DATE REVIEWED`. Populate roles from
  evidence (typical: Functional Lead, Technical Lead, Client Integration
  Owner); leave NAME/DATE blank unless known.
- **Approvers** — table: `NAME | ROLE | SIGNOFF TYPE | APPROVAL DATE`. Roles
  typically include client IT and business owners plus firm functional and
  technical leads — use roles actually relevant to this engagement.

**Contents** (new page): a table of contents covering heading levels 1–3. In
docx output insert a real TOC field (`TOC \o "1-3"`) and note beneath it:
"Refresh this field (select it and press F9) whenever headings or page numbers
change." In Markdown output, generate the list manually.

### Body sections

**1. Introduction and Functional Requirements** — open with a 2–4 sentence
plain-language summary: what the interface moves, between which systems, how
often, and which system is the system of record.
- **1.1 Scope Overview** — explicit "In scope:" and "Out of scope:" paragraphs.
  Out-of-scope items come from evidence (things deferred, handled natively in
  the target, or covered by sibling interfaces) — never pad this list.
- **1.2 Functional Requirements** — bullet list of testable business
  requirements ("Oracle must be the single source of truth for item
  creation…"). Each bullet must trace to an artifact; write them as
  requirements (must/shall), not as narrative.
- **1.3 Functional Configurations** — prose on what functional setup must
  exist for the integration to work.
  - **1.3.1 Fusion Configurations** — Fusion-side setup (e.g., PIM attributes,
    inventory orgs, UOMs). Include a `#### Descriptive Flexfields (DFF)`
    sub-block: list required DFF contexts/segments if evidenced, else TBD.

**2. Business Assumptions & Process Flow**
- **2.1 Business Assumptions** — bullets. These are *documented operating
  assumptions from the artifacts* (e.g., "a centralized team manages item
  creation"), not your assumptions. If the artifacts contain none, say so.
- **2.2 Business Process Flow** — 1–3 paragraphs narrating the end-to-end
  business flow in time order, including upstream/downstream sequencing
  dependencies (e.g., "must run before the consumption interface").
- **2.3 Error Handling & Re-processing Flow** — business-level narrative of
  what happens when it fails: detection, notification, who investigates,
  correction, reprocessing, and any timing constraints.

**3. Design Attributes**
- **3.1 Selection / Filter Criteria on Source System** — what records qualify
  for extraction (date window, status filters, org filters).
- **3.2 Encryption Requirements** — requirements only; implementation lives in
  5.7–5.9. Reference program-level security KDDs by ID if they exist.
- **3.3 Frequency** — schedule, timing windows, sequencing constraints.
- **3.4 Volume** — expected/observed volumes, peak considerations, growth. If
  volumes were only flagged as a risk with testing planned, say exactly that.
- **3.5 Control Totals** — batch/transaction reconciliation and success
  criteria (e.g., "batch successful only when all records accepted").

**4. Technical Overview**
- **4.1 Solution Overview** — 1–2 paragraphs: extraction mechanism, transport
  channel, target endpoint, and any open architectural decisions (with RAID
  IDs).
- **4.2 Technical Components** — one summary paragraph, then:
  - **4.2.1 Fusion Components** — ESS jobs, extraction jobs. Real names only
    from evidence; else TBD.
  - **4.2.2 BI Components** — BIP reports / BICC extracts, data models, output
    formats.
  - **4.2.3 Integration Platform** — with `####` sub-blocks:
    **Connection Components** (adapters/connections, host/port/auth — TBD
    unless evidenced), **Integration Components** (flows/orchestrations),
    **Integration Lookups** (cross-reference lookups with purpose; names/values
    TBD unless evidenced).

**5. Integration Process Flow**
- **5.1 Integration Flow Steps** — numbered steps `1.` through `n.` covering
  trigger → extract → transform/map → segment → transmit → target response →
  status capture → error surfacing. Steps must match the evidence; reference
  open decisions inline (e.g., "segmentation count TBD per RAID PP_1055").
- **5.2 Process Flow Diagram** — one paragraph describing the diagram's
  content, then: "The consultant will insert the formal process flow diagram
  here." (You may additionally offer to generate a diagram, but the written
  placeholder stays in the document.)
- **5.3 Field Mapping** — table:
  `# | SOURCE FIELD | TARGET FIELD | TRANSFORMATION / RULE | REQUIRED? | NOTES`.
  One row per mapped field found in evidence. Unknown target names,
  transformations, or required flags are TBD *in the cell*. Close with a
  catch-all row for deferred attributes if the artifacts defer detailed
  mapping. This table is the heart of the spec — never pad it with fields no
  artifact mentions.
- **5.4 Integration File Creation** — how the payload/file is constructed and
  delivered; state explicitly if no intermediate file is persisted.
- **5.5 File Naming** — narrative plus:
  - **5.5.1 Archive File Naming Convention** — show the pattern line
    `Format: [PREFIX]_[MMDDYYYY]_[HH24MISS].zip` only if evidenced or adopted
    as a program standard; otherwise keep the Format line with placeholders and
    mark TBD.
  - **5.5.2 Data File Naming Convention** — same treatment.
- **5.6 Target File Specification** — table:
  `FILE NAME | FILE TYPE | CONTENTS | RECORD COUNT`. Describe CONTENTS from
  evidence even when name/type/count are TBD.
- **5.7 Encryption** / **5.8 Encryption Considerations** / **5.9 Encryption
  Keys** — algorithm & standards; rotation/constraints; key ownership,
  exchange, storage. Each is commonly TBD early — reference the governing
  security KDD and log the open item.

**6. Source File Location** — table:
`SERVER (HOST:PORT) | PATH | ENCRYPTED? | FILENAME`. Real values only from
evidence; a row of TBDs is the correct early-phase state. (For pure API
integrations with no file staging, keep the section and state that no file
location applies, or TBD if staging is undecided.)

**7. Error Handling**
- **7.1 Potential Errors** — table:
  `# | POTENTIAL ERROR | POSSIBLE REASON | SOLUTION STRATEGY`. Derive scenarios
  from the evidence (failure modes discussed, sequencing risks, data-quality
  risks, connectivity). Each row's solution must be consistent with the control
  and reprocessing model in §2.3/§3.5/§8. Aim for the genuinely applicable set
  — typically 4–8 rows — not an exhaustive generic list.
- **7.2 Error Structure** — table:
  `# | COLUMN | DATA TYPE | REQUIRED? | COMMENT`. Populate only if an error
  file/record layout is evidenced; otherwise leave the header row with one
  empty body row (as the template does) — it signals "to be defined."

**8. Reporting and Reprocessing**
- **8.1 Reporting** — dashboards/reports, what they show, audience;
  distribution list TBD unless evidenced.
- **8.2 Re-processing** — who triggers reprocessing, granularity (batch vs.
  record), and timing constraints.

**9. Installation Notes**
- **9.1 Summary Installation Notes** — deployment order across environments
  (Dev → Test → Prod), environment-specific values to set, and pre-promotion
  gates (e.g., stress testing) from evidence.
- **9.2 Installation Document Reference** — reference it if it exists; else
  "TBD, a detailed installation and deployment guide does not yet exist and
  must be produced during detailed design."

**10. Unit Test Cases** — table: `SCENARIO # | DESCRIPTION`. Derive from the
requirements and error scenarios: always include the happy path and an empty
run; add cases for each distinctive functional rule (multi-entity handling,
sequencing validation) and each major error mode (invalid data, timeout,
partial batch, duplicates). Every test case must be traceable to a requirement
or error row in this document.

**11. Issues Management**
- **11.1 Open Questions / Items for Review** — table:
  `ID | DESCRIPTION | OWNER | STATUS | TARGET DATE`. **Every TBD in the
  document gets a row here.** Carry over RAID/KDD IDs and owners from the
  artifacts; leave OWNER blank when unknown. STATUS is `Open`; note blockers in
  TARGET DATE ("Blocked on RAID PP_1055 resolution") when evidenced.
- **11.2 Closed Issues** — table: `ID | DESCRIPTION | OWNER | RESOLUTION`.
  Decisions already made in the artifacts (closed RAID items, agreed KDDs) —
  these justify design statements in the body.
- Cross-check before finishing: TBDs ↔ 11.1 must reconcile 1:1; decided design
  points should trace to 11.2 or a cited artifact.

**12. References** — table: `# | DOCUMENT | VERSION | LOCATION`. Every artifact
used (exact filenames as provided) and every Tier-3 documentation source
(title + URL). This table is the audit trail for the defensibility contract.

## 4. Writing rules

- Voice: professional, declarative, third person. Requirements use
  must/shall. No hedging ("probably", "likely", "should be fine") — a fact is
  evidenced, or it is TBD.
- TBD convention: `TBD, <what exactly is unknown and what confirms it>` — e.g.,
  "TBD, archive naming convention has not been defined in the available
  documentation." Never a bare "TBD" in prose (bare TBD is fine inside table
  cells).
- Use the client's own vocabulary from the artifacts (system names, team
  names, RAID/KDD IDs) verbatim and consistently.
- Prose sections: short paragraphs (2–5 sentences). Lists for requirements and
  assumptions. Tables where the structure above says table — do not convert
  tables to prose or vice versa.
- Length is an output, not a target: a thin evidence base yields a short spec
  with a long Section 11.1. That is the correct result.

## 5. Working process

1. **Intake** (§2) — confirm identity, artifacts, logos, document-control facts.
2. **Evidence pass** — read every artifact fully. Build a private inventory of
   facts→sources, decided vs. open items, named identifiers, and explicit TBDs.
   Use live tools (Tier 2) and official docs (Tier 3) to close gaps where
   possible.
3. **Draft** the full document per §3.
4. **Defensibility audit** — walk the document: every claim → tier; every
   TBD → 11.1 row; every artifact/doc → Section 12; no invented identifiers;
   discussed-not-decided items not presented as design.
5. **Render** (§6) and deliver. Summarize for the user: sections that are
   solid, the open-question count, and the top items blocking a complete spec.

## 6. Rendering & formatting

### 6.1 Word (.docx) — default when file-creation tools are available

Follow the platform's docx skill/tooling for mechanics. Apply this design:

- **Page**: US Letter (12240 × 15840 DXA). Margins: top/bottom 1080 DXA
  (0.75"), left/right 1440 DXA (1"). Header 620, footer 500.
- **Base font**: Arial throughout, black text. Body ~10pt, line spacing 1.15
  (`line=276`), space-after 140.
- **Cover title**: 28pt; "Prepared by" ~20pt; author/date bold ~12pt.
- **Headings** (all bold, 12pt, with `outlineLevel` set so the TOC works):
  - H1: bottom border, single, 1.5pt (`sz=12`), **accent color** (client brand
    hex, else `#3C3C3B`), space-after 260.
  - H2: space-before 320. H3: before 260 / after 120. H4: before 220 / after 100.
  - Front-matter headings ("Document Control", "Contents"): bold 13pt with the
    same accent bottom border; sub-labels ("Version History", "Reviewers",
    "Approvers"): bold body size.
- **Tables**: full-width, DXA widths on table and every cell (columnWidths sum
  to table width). Header row: shading fill `#3C3C3B`, bold white text 8.5pt,
  ALL-CAPS column labels. Body rows: 9pt, alternate-row shading `#F5F5F5`
  (`ShadingType.CLEAR`), borders `#DADADA` single ½pt. First column of
  numbered tables bold (`**1**`).
- **Footer** (all pages except cover): document title left, `Page X of Y`
  right (real PAGE/NUMPAGES fields). Cover page uses `titlePg` with an empty
  first-page footer.
- **Logos**: cover page, firm logo then client logo, natural aspect ratio,
  roughly 2.5–3.7" wide. Missing logo → bordered text placeholder
  `[CLIENT LOGO — replace before distribution]` and an 11.1 row.
- **TOC**: real `TOC \o "1-3"` field plus the F9 refresh note.
- **Page breaks** before: Document Control, Contents, Section 1, and each
  subsequent H1 section.
- Validate/render-check the output if the environment provides tools for it.

### 6.2 Markdown fallback — any environment without file tools

Produce one complete Markdown document mirroring §3 exactly: `#` for H1
sections, `##`/`###`/`####` for subsections, bold front-matter labels, pipe
tables with the exact column headers, a manual Contents list, and
`![CLIENT LOGO — replace before distribution]` / firm-logo placeholders at the
top. State the intended Word styling (this §6.1) in a short note only if the
user asks how to format it.

## 7. Quality gate — before delivering, confirm every box

- [ ] Every factual claim traces to Tier 1/2/3 evidence; zero guesses.
- [ ] No invented job names, report names, endpoints, hosts, file names, DFFs,
      or IDs.
- [ ] Every TBD follows the convention and has a matching 11.1 row.
- [ ] Decided vs. discussed correctly separated (11.2 vs. 11.1).
- [ ] All 12 sections + front matter present with exact headings/numbering.
- [ ] All tables use the exact column schemas from §3.
- [ ] Section 12 lists every artifact and external doc actually used.
- [ ] Client logo obtained, or placeholder inserted **and** the user told to
      provide it.
- [ ] Test cases and error rows are mutually consistent and traceable.
