---
name: meeting-summary
description: >
  Produce a Regal-branded Word (.docx) meeting summary that extracts and
  organizes OPEN ITEMS (actions, pending decisions, follow-ups, blockers,
  parking-lot, open questions) from one OR MANY meeting source files —
  transcripts, notes, chat logs, recap emails, workshop captures. Use when the
  user asks to "summarize meeting(s)", "pull the open items", "what's
  outstanding from these calls", "build a recap doc", "action items by module",
  or hands over a batch of meeting artifacts wanting a professional deliverable.
  Open items lead; narrative summaries follow. Every open item is classified by
  Oracle Fusion PILLAR and MODULE so the reader sees what they own first.
  Triggers for a single file or mixed formats (.txt/.md/.docx/.pdf/.vtt/.csv),
  and for "meeting recap", "workshop notes", "standup summary", "MoM/minutes".
  Do NOT use for non-meeting documents (design specs, code, data extracts).
---

# Meeting Summary — Open-Item Extraction & Regal-Branded Report

You are acting as a senior Oracle Fusion engagement lead writing the post-meeting
record. The deliverable is **not a transcript condensation**. Its job is to make
the reader instantly see **what is still open and who owns it**, organized so an
Oracle Fusion functional/technical reader can navigate by the pillar and module
they're responsible for. Narrative recap is secondary and lives *after* the open
items.

The output is always a **Regal Cinemas-branded Word (.docx)** document, prepared
as a Hackett deliverable (the footer carries the Hackett copyright/reproduction
line per Regal brand standards for Hackett-produced materials).

---

## Core principle: open items first, by pillar and module

The reader scans for their own work. The document leads with a consolidated
**Open Items** register grouped by Oracle Fusion **Pillar → Module**, so a
Finance/AP lead, an HCM lead, and an integrations lead each find their items
without reading the whole thing. Per-meeting narrative summaries follow afterward
as supporting context.

Document order is fixed:

1. **Title block** (branded header) — engagement, date range, number of meetings covered.
2. **Executive summary** — 3–6 sentences across all meetings: themes, biggest open risks, key decisions made.
3. **Open Items by Pillar & Module** — the centerpiece. One table per pillar, sub-grouped by module.
4. **Decisions log** — decisions that were *made* (closed), for the record.
5. **Per-meeting summaries** — chronological narrative recaps, one short section each.
6. **Appendix: source files** — list of files ingested with detected meeting metadata.

---

## Step 1 — Ingest every source file (works across many files)

The user may pass one file, several files, or a directory. Handle all of them.

- Look in `/mnt/user-data/uploads/` for attached files; also honor any explicit paths the user names.
- Accept mixed formats. Read each according to type:
  - `.txt` / `.md` / `.vtt` / `.srt` — read directly.
  - `.docx` — use the `docx` skill's `extract-text`.
  - `.pdf` — use the `pdf-reading` skill (text extraction; OCR only if scanned).
  - `.csv` / `.xlsx` — read tabular; useful for pre-structured action-item logs.
- For each file, derive meeting **metadata**: a title (from filename or heading),
  a **date** (parse from filename, header, or first timestamp; if none, mark
  "date unknown"), and participants if stated.
- Sort meetings chronologically. Never silently drop a file — if one can't be
  parsed, note it in the appendix and continue.

Do not eyeball large transcripts. Parse programmatically and scan the full text.

---

## Step 2 — Extract open items (be precise about what "open" means)

An **open item** is anything left unresolved that requires future action or a
future decision. Capture:

- **Action items** — someone must *do* something. ("Kellie to send revised COA mapping.")
- **Pending decisions** — a choice is required but not yet made. ("Decide single vs. multiple ledgers.")
- **Open questions** — raised, not answered. ("Does Moss need multi-currency in AP?")
- **Blockers / risks / dependencies** — flagged as impeding progress.
- **Parking-lot items** — explicitly deferred.

Do **not** capture as open: things already decided (those go to the Decisions
log), pure status narration, or pleasantries.

For each open item, structure the following fields:

| Field | Notes |
|---|---|
| **Item** | One clear sentence, imperative where it's an action. |
| **Type** | Action / Decision / Question / Blocker / Parking-lot |
| **Owner** | Named person or role; "Unassigned" if none stated — flag these, they matter. |
| **Due / target** | Date or milestone if stated; else "TBD". |
| **Pillar** | See Step 3. |
| **Module** | See Step 3. |
| **Source** | Meeting title + date it came from (for traceability). |
| **Priority** | High / Med / Low — infer from language ("blocker", "ASAP", go-live impact). |

Deduplicate across files: the same item raised in two meetings is **one** item
with the latest status; note it recurred.

---

## Step 3 — Classify by Oracle Fusion Pillar and Module

Every open item gets a **Pillar** and a **Module**. This is what lets the reader
navigate to their own work. Classify from the item's subject matter.

**Pillars** (top-level grouping):

- **Finance (ERP)**
- **HCM**
- **SCM**
- **PPM** (Project Portfolio Management)
- **EPM** (Planning / FCCS / ARCS / Narrative Reporting)
- **Integrations & Technical** (OIC, REST/SOAP, BIP, FBDI/HDL, ESS, security/roles, ID domains, conversions, reporting/OTBI)
- **Cross-functional / Program** (governance, cutover, training, testing, scope, timeline — not module-specific)

**Modules** (sub-grouping under each pillar). Use the client's term if they used
one; otherwise map to the canonical Fusion module:

- **Finance:** GL, AP, AR, FA, CM (Cash Management), Tax, Expenses, Intercompany, Budgetary Control, Procurement-to-Pay overlap.
- **HCM:** Core HR, Absence, Payroll, Benefits, Talent, Compensation, Time & Labor, Recruiting (ORC).
- **SCM:** Inventory, Procurement, Order Management, Manufacturing, Cost Management, Product Hub.
- **PPM:** Project Costing, Project Billing, Project Control, Grants, Capital Projects.
- **EPM:** Planning, FCCS, ARCS, EPCM, Narrative Reporting.
- **Integrations & Technical:** OIC Integrations, REST APIs, SOAP, BIP/OTBI Reporting, FBDI/HDL Conversion, ESS Scheduling, Security & Roles, Identity (IDCS / ID Domains), Environments/Cloud.
- **Cross-functional:** Program Mgmt, Cutover, Testing (SIT/UAT), Training/OCM, Data Governance, Scope/Change.

If an item genuinely spans modules (e.g., an AP-to-OIC integration), file it under
the **primary owner's** pillar/module and note the dependency in the item text.
When uncertain, prefer the more specific module over a vague one, and never leave
Pillar blank — use **Cross-functional / Program** as the catch-all.

---

## Step 4 — Generate the Regal-branded .docx

Hand off to the generator script rather than hand-building XML. The script applies
Regal brand standards (loaded from the `regal-brand-guidelines` skill): a dark/
charcoal page-header band with an orange rule, Trebuchet MS titles / Calibri body,
the Regal chart palette for pillar accent bands (orange → charcoal → red → dark →
gray → mid-orange), charcoal table headers, and the Hackett-deliverable footer
(© line with reproduction-restriction language).

1. Build a JSON payload (`summary.json`) with this shape:

```json
{
  "engagement": "Moss & Associates — Oracle Fusion Implementation",
  "date_range": "2026-05-01 to 2026-05-22",
  "meeting_count": 4,
  "executive_summary": "Across four workshops ...",
  "pillars": [
    {
      "pillar": "Finance (ERP)",
      "modules": [
        {
          "module": "AP",
          "open_items": [
            {
              "item": "Confirm 2-way vs 3-way match policy for non-PO invoices.",
              "type": "Decision",
              "owner": "Client — Controller",
              "due": "Before SIT",
              "priority": "High",
              "source": "AP Workshop — 2026-05-15"
            }
          ]
        }
      ]
    }
  ],
  "decisions": [
    { "decision": "Single primary ledger, USD.", "owner": "Program", "source": "Kickoff — 2026-05-01" }
  ],
  "meetings": [
    {
      "title": "AP Workshop",
      "date": "2026-05-15",
      "participants": "Kellie, Controller, AP Lead",
      "summary": "Walked the non-PO invoice flow ..."
    }
  ],
  "sources": [
    { "file": "ap_workshop_0515.vtt", "detected": "AP Workshop, 2026-05-15", "status": "parsed" }
  ]
}
```

2. Run the generator:

```bash
cd <skill_dir>
npm install docx    # if not already present
node scripts/generate_summary.js summary.json /mnt/user-data/outputs/Meeting_Summary.docx
```

3. Validate, then present the file:

```bash
python /mnt/skills/public/docx/scripts/office/validate.py /mnt/user-data/outputs/Meeting_Summary.docx
```

Use `present_files` on the output path.

---

## Report craftsmanship rules

- **Open items lead.** Never bury them under narrative. The pillar tables come
  before per-meeting recaps.
- **Owners and dates are non-negotiable columns.** Unassigned owners and TBD dates
  are surfaced (don't hide them) — they are the action the reader must take.
- **Empty pillars are omitted.** Only render pillars/modules that actually have
  open items, so the doc reflects this engagement, not the full Fusion footprint.
- **Priority drives order** within a module: High → Med → Low.
- **Traceability:** every open item shows which meeting it came from.
- **Decisions vs. open items:** if it's settled, it's a decision (logged for the
  record), not an open item. Keep the distinction clean.
- **Tone:** concise, professional consulting voice. No filler, no transcript
  quoting beyond a short phrase where wording is load-bearing.
- **Minimum font size:** all text in the Word document must be **at least 12pt** —
  body, table cells, headers, footers, captions, and metadata included. Nothing
  renders below 12pt. (In docx-js, `size` is half-points, so 12pt = `size: 24`;
  the floor applies regardless of how the document is produced.)
- **Branding:** all colors, fonts, header band, and footer per
  `regal-brand-guidelines`. Orange (#F56601) leads on titles/section headers,
  charcoal (#3C3C3B) on table headers; always include the Hackett-deliverable ©
  footer with the current year and reproduction-restriction line.

---

## Conversational vs. report mode

If the user just wants to *see* the open items quickly, surface them inline first
(grouped by pillar/module) and offer the branded .docx. If they ask for the
document outright, go straight to generation. Either way, the .docx is the
canonical deliverable.
