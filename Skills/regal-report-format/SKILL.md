---
name: regal-report-format
description: "The Regal house DESIGN SYSTEM for HTML reports - the exact visual language of the REGAL DEV-2 checklist deliverables (Regal orange #F56601 on charcoal, Manrope/Inter/JetBrains Mono, dark thesis card with diagonal-stripe motif and stat tiles, verdict pills with matching row inset bars, eyebrow-labeled numbered section cards, finding blocks, legend + disclosure footer, Hackett copyright). Apply it to ANY report an agent renders as HTML for the Regal project - audits, status reports, readiness assessments, comparisons, profiling results, summaries, scorecards - regardless of subject matter. Trigger whenever the user asks for 'a report', 'the standard format', 'the usual report look', 'Regal report styling', or an agent is about to emit an HTML deliverable in a Regal context, even if branding is not mentioned - if the context is Regal and the output is a report, use this format. Content comes from the analysis; THIS skill dictates how it looks and how the HTML is structured."
---

# Regal Report Format (HTML Design System)

The house visual language for Regal HTML report deliverables. Reference artifact: the REGAL DEV-2 SCM task checklist. `assets/template.html` carries the complete CSS **verbatim** plus a content-agnostic skeleton — start every report from it and replace only content. Do not restyle, re-derive, or "improve" the CSS; consistency across deliverables is the point.

## Design tokens

| Token | Value | Use |
|---|---|---|
| `--ink` | `#212933` | Primary text; also the Regal dark/charcoal |
| `--slate` | `#4A5568` | Secondary text, leads, table detail |
| `--mist` | `#7C878E` | Metadata, footer |
| `--canvas` | `#F4F6F9` | Page background |
| `--paper` | `#fff` | Card background |
| `--line` | `#E2E8F0` | Borders, row separators |
| `--brand` | `#F56601` | Regal orange — accents, pills, topbar, title accent word |
| `--brand-deep` | `#C44E00` | Eyebrows, code text, table headers |
| `--brand-soft` | `#FDEBDD` | Code background, table header background |
| `--green/-bg` | `#1E8E5A` / `#E6F4EC` | Positive verdicts |
| `--amber/-bg` | `#C77A11` / `#FBF0DD` | Caution verdicts |
| `--red/-bg` | `#C0392B` / `#FBEAE8` | Negative verdicts |
| `--gray/-bg` | `#8A97A8` / `#EEF1F5` | Neutral / not-applicable |

Typography (Google Fonts): **Manrope** 600–800 for headings, stats, pills, table headers; **Inter** 400–600 for body; **JetBrains Mono** for code, dates, and environment/pod tags. Body 1.55 line-height, antialiased.

## Page anatomy (fixed order)

1. **Topbar** — 6px gradient strip, charcoal → orange → light orange. Opens every report.
2. **Header (`rhead`)** — left: title with **one accent word in orange** (`<span class="accent">`), subtitle with a `<code>` mono tag (pod, env, version); right: mono date block (generated date, report type, source).
3. **Scope note** — orange-bordered "How to read this" strip stating method and limits. Include whenever the report makes judgments.
4. **Thesis card** — the one-glance takeaway, always before any detail: dark gradient card (charcoal, diagonal orange stripe motif via the `::after` — pure CSS, no images), eyebrow label, one declarative sentence as `<h2>`, 2–3 sentence lead, a `stats` grid of 3–5 tiles (`g/a/r/o` color classes), and the `verdict-big` row with a `bigpill`.
5. **Numbered section cards** — eyebrow `Section 0N · Label`, `<h2>` heading, optional lead, then tables and/or finding blocks. Typical arc: evidence table → interpretation → recommendations/sequence. Adapt count and labels to the content.
6. **Legend + footer card** — colored-dot legend defining what green/amber/red mean *in this report*, then the `foot` line: method/source/date disclosure, honest limits, `© {year} The Hackett Group, Inc. All Rights Reserved.`

## Component grammar

- **Tables**: wrap in `<div class="tw">` (mobile scroll). `thead th` renders in brand-soft/deep automatically. Cell classes: `tn` (item name, bold), `num` (centered numeric), `det` (slate detail, may contain `<code>` and `<b>`), `vc` (right-aligned verdict cell). **Row class `v-green|v-amber|v-red|v-gray` paints the 3px left inset bar and must always match the row's pill color** — a green pill on an unclassed row is a defect.
- **Pills**: `<span class="pill green|amber|red|gray">SHORT UPPER TEXT</span>`. One per row, short labels (DONE, AT RISK, FAIL, N/A).
- **Finding blocks (`sblock`)**: left-border-colored cards for prose findings — `<h4>` title + one `<p>`. 3–5 per interpretation section; color = tone of the finding.
- **Stats tiles**: big Manrope number + small label; `g/a/r` for classified counts, `o` (orange) for totals/neutral headline numbers.
- **Inline code**: `<code>` for object names, paths, hosts, IDs — never for emphasis.

## Semantics and voice

- Color is **meaning, not decoration**: green = confirmed good, amber = present-but-qualified, red = gap/risk/absent, gray = neutral or out of scope. Define the meanings in the legend every time; never reuse a color against its semantic.
- Thesis first: a reader who sees only the dark card should leave with the correct conclusion.
- Honest-framing footer is mandatory: how the data was derived, from what source, when, and what the report is *not* claiming (e.g., "no completion percentage — no requirements baseline"). Overstating certainty in a styled report is still overstating certainty.
- Client-facing prose in direct address — "your environment," "your team" — except literal resource names. Hackett attribution stays in the footer.

## Mechanics

- **One self-contained HTML file**: CSS inline in `<head>`, Google Fonts via `<link>`, no JS required, no external images (the stripe motif is CSS).
- Preserve the `@media print` and `@media(max-width:680px)` blocks — deliverables get printed and read on phones.
- Filename: `{client}_{env-or-scope}_{subject}_{report-type}.html`, lowercase snake. In Claude write to `/mnt/user-data/outputs/`; in external systems emit as an artifact/attachment.
- Longer reports: add section cards (Section 04, 05…) rather than inventing new component types. If a report genuinely needs a component this system lacks (e.g., a timeline), build it from the existing tokens and note the addition.

## Scope

This is the **Regal-branded** report system. For non-Regal work use the generic `data-analysis-report-format` house system or the relevant client's brand skill. Content correctness is out of scope here — pair with whatever analysis/profiling skill produces the substance; this skill only governs presentation.
