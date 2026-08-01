---
name: data-analysis-report-format
description: >
  The STANDARD house format for any data-analysis report — the reusable visual design
  system (palette, typography, layout shell, verdict semantics, section patterns, drop-in
  CSS) extracted from the worker-conversion readiness report. Use whenever producing a
  data-analysis, assessment, profiling, readiness, scorecard, fit-gap, or audit
  deliverable as a polished HTML document, in ANY domain (HCM, Finance, AP/AR, SCM, PPM,
  integrations, data-quality, conversion readiness), so every report shares one
  professional, color-coded identity instead of ad-hoc styling. Trigger alongside any
  analysis or profiling skill the moment the output is "a report", "an assessment", "a
  readiness report", "a scorecard", or the user asks for the analysis "as a report" /
  "in the standard format" / "the report format". The companion
  analysis skill supplies WHAT to say; this skill supplies HOW it looks. Layer a client
  brand-guidelines skill on top when needed. Do NOT use for non-report outputs (chat
  answers, raw spreadsheets, code).
---

# Data Analysis Report Format (House Standard)

This is the standard visual format for every data-analysis report Claude produces. It
was extracted from the worker-conversion readiness report so that all analysis
deliverables — across any domain — share one professional, color-coded identity. The
companion analysis skill (e.g. an HCM/Finance/integration profiler) decides *what* the
report says and which sections it needs; this skill decides *how it looks and how it is
assembled*.

The output is always a **single self-contained HTML file** in `/mnt/user-data/outputs/`
— a designed document a consultant would put in front of a client. Never a plain
markdown dump, never a monochrome ASCII/terminal table, never a chat summary when a
report was asked for.

---

## When this applies

Use this format whenever the deliverable is an analysis written up as a report:
assessments, profiling reports, conversion- or migration-readiness reports, data-quality
scorecards, fit-gap analyses, audit findings, validation summaries, due-diligence
write-ups. The data domain does not matter — the format is domain-neutral. The section
*set* flexes to the analysis (see "Section library"); the *styling* never changes.

If a client house brand is in play, layer that brand-guidelines skill's color/type
tokens over this structure — keep the layout, swap the palette and fonts.

---

## Design tokens (the house style — do not improvise)

```
Palette (light, professional, accessible):
  --ink:        #1B2430   /* primary text */
  --slate:      #4A5568   /* secondary text */
  --mist:       #8A97A8   /* tertiary / captions */
  --paper:      #FFFFFF   /* card surface */
  --canvas:     #F4F6F9   /* page background */
  --line:       #E2E8F0   /* hairline borders */
  --brand:      #1F4E79   /* deep professional blue — headers, eyebrows, accents */
  --brand-soft: #EAF1F8   /* tinted table-header / eyebrow / chip background */

Verdict / status semantics (dots, pills, row accents, severity headers):
  --green:  #1E8E5A   --green-bg:  #E6F4EC   /* good / loadable / pass / on-track */
  --amber:  #C77A11   --amber-bg:  #FBF0DD   /* cleanup / caution / partial */
  --red:    #C0392B   --red-bg:    #FBEAE8   /* blocked / fail / critical */
  --gray:   #8A97A8   --gray-bg:   #EEF1F5   /* unverifiable / masked / N-A */

Type (Google Fonts, fall back to system-ui):
  Display / headers:  "Manrope" (600/700/800)
  Body:               "Inter" (400/500/600)
  Data / codes / IDs: "JetBrains Mono" (400/500)
```

Verdict color meaning is universal and reusable: green = good/pass, amber = needs
attention/partial, red = blocked/fail/critical, gray = can't assess. A report may rename
the *labels* to fit its domain (e.g. "Pass / Review / Fail", "On track / At risk /
Off track", "Loadable / Cleanup / Blocked") but must keep the color mapping.

---

## Required structural shell (every report)

1. **Top bar** — a slim `--brand` gradient rule across the top.
2. **Report header** — title (Manrope 800, ~30px), a one-line subtitle of context
   (domain · artifact · scope · sample size), and a mono generation date, right-aligned.
3. **Scope note** — a `--brand-soft` callout with a `--brand` left border stating what
   the analysis covers and, crucially, what it does *not* cover / what it's based on.
4. **At-a-glance thesis card** — a `--brand` gradient card (white text) with a row of
   stat tiles (the headline numbers) and one prominent overall-verdict pill. This is the
   single most prominent element — the thesis of the report.
5. **Body sections** — drawn from the Section library below, in the order the analysis
   dictates, each a white `--paper` card with an uppercase `--brand` eyebrow ("Section
   01", or a named label) and a Manrope heading.
6. **Footer card** — the verdict legend (the four colored dots with labels), a
   confidentiality line, and a "based on the provided sample/data" caveat.

The shell is fixed; sections 5's contents flex.

---

## Section library (mix to fit the analysis)

Each renders with the shared components below. Use the ones the analysis needs; skip the
rest. Keep prose tight — short paragraphs and bulleted facts, not walls of text.

- **Population / dataset summary** — a `Segment · Count · Notes` table plus prose
  findings (key dimensions, composition, distributions). Compact sub-tables for
  breakdowns (e.g. distribution by category) sit in a two-column `subgrid`.
- **Scorecard** — the core table for element-by-element findings. Columns adapt to the
  domain but follow the pattern: `Item · Present/Status · Coverage% (count) · Findings ·
  Verdict`. Verdict is a right-aligned colored pill; the row carries a colored left-border
  accent matching its verdict. Inline codes/IDs/dates use mono chips so artifacts pop.
- **Per-object / per-area verdict** — small `Object · Verdict pill · Primary reason` table.
- **Observations / findings blocks** — titled blocks with an eyebrow label (e.g. a rule
  reference, a category, a severity) and prose, with a colored left border by severity.
  Use instead of a table when each finding needs a paragraph.
- **Inference / interpretation** — prose items, each a short heading + paragraph, every
  one flagged as an inference the reader can correct.
- **Issues / risks register** — severity-grouped tables: a red-headed "Critical / Hard"
  table and an amber-headed "Cleanup / Review" table, each `# · Item · (Affected) ·
  Detail`.
- **Decisions & next steps** — numbered prose decisions, then a `Item · Why needed ·
  Urgency` table with urgency as colored pills.

A report is free to add a domain-specific section, but it must reuse the shared
components (cards, eyebrows, tables, pills, dots, mono chips, severity headers) so it
still reads as the same family.

---

## Shared components (the visual vocabulary)

- **Card** — white surface, 1px `--line` border, ~14px radius, generous padding, soft
  shadow. Every section is a card.
- **Eyebrow** — uppercase, letter-spaced, 11px, Manrope 700, `--brand`. Labels every
  section.
- **Tables** — no heavy gridlines. Header row `--brand-soft` background with `--brand`
  uppercase text; rows separated by `--line` hairlines; ≥10px cell padding; subtle
  hover. Numeric/count columns centered in Manrope bold; code/ID/date columns in mono.
- **Verdict pill** — rounded, Manrope 700, ~11.5px, colored text on matching soft
  background (e.g. `--red` on `--red-bg`).
- **Verdict dot** — 9px filled circle in the verdict color; used in legends and inline.
- **Mono chip** — inline `<code>` with `--brand-soft` background and `--brand` text, for
  any literal code, ID, date, or data artifact (`30001158.0`, `06413`, `YYYY-MM-DD`).
- **Severity header** — a small pill-block heading above a register table: red bg for
  critical/hard, amber bg for cleanup/review.
- **Stat tile** — used only inside the thesis card: big Manrope number + small label, on
  a translucent white panel over the brand gradient.
- **Left-border row accent** — `inset 3px 0 0 <verdict>` on the first cell of a scorecard
  row, color-coded to its verdict.

---

## Build & quality rules

- One self-contained HTML file; all CSS in a single `<style>` block; fonts from Google
  Fonts with system-ui fallback. No external JS dependencies. **Never use localStorage /
  sessionStorage.**
- Every number in the report comes from the actual analyzed data — never invent counts.
  When parsing source data, read values as strings to catch leading zeros, float
  artifacts, and date-format issues, then surface them as mono chips.
- Responsive: wrap every table in an `overflow-x:auto` container; stat tiles and the
  legend wrap on narrow screens; the two-column subgrid collapses to one column on mobile.
- Accessible: visible keyboard focus, sufficient contrast (the tokens are chosen for it),
  honor `prefers-reduced-motion`.
- **Print-clean** — include a print stylesheet: white background, preserve verdict colors
  (`print-color-adjust:exact` on the gradient cards), avoid breaking table rows across
  pages, drop shadows. The report must export to a clean PDF.
- Watch CSS specificity: avoid class selectors that cancel each other's padding/margins
  between sections (a common failure with `.section` vs element selectors).
- Lead with the thesis; keep prose tight; flag inferences; separate critical from
  cleanup. Save to `/mnt/user-data/outputs/` and present the file.

---

## Reference CSS (drop-in starting point)

This is the house stylesheet from the worker report, generalized. Start from it and add
only domain-specific tweaks; do not redesign it. A complete rendered example using this
exact format is bundled at `assets/example_report.html` — open it to see the shell,
thesis card, scorecard, observation blocks, and registers in context before building a
new one.

```css
:root{
  --ink:#1B2430; --slate:#4A5568; --mist:#8A97A8; --paper:#fff; --canvas:#F4F6F9; --line:#E2E8F0;
  --brand:#1F4E79; --brand-soft:#EAF1F8;
  --green:#1E8E5A; --green-bg:#E6F4EC; --amber:#C77A11; --amber-bg:#FBF0DD;
  --red:#C0392B; --red-bg:#FBEAE8; --gray:#8A97A8; --gray-bg:#EEF1F5;
}
*{box-sizing:border-box}
body{margin:0;background:var(--canvas);color:var(--ink);font-family:"Inter",system-ui,sans-serif;line-height:1.55;-webkit-font-smoothing:antialiased}
.wrap{max-width:1100px;margin:0 auto;padding:32px 24px 64px}
h1,h2,h3,h4{font-family:"Manrope",system-ui,sans-serif;margin:0;color:var(--ink)}
code{font-family:"JetBrains Mono",ui-monospace,monospace;font-size:.85em;background:var(--brand-soft);color:var(--brand);padding:1px 6px;border-radius:5px;font-weight:500}
.topbar{height:6px;background:linear-gradient(90deg,var(--brand),#2E6DA4);border-radius:6px;margin-bottom:22px}
.rhead{display:flex;justify-content:space-between;align-items:flex-end;flex-wrap:wrap;gap:12px;margin-bottom:6px}
.rhead .ttl{font-size:30px;font-weight:800;letter-spacing:-.5px}
.rhead .sub{color:var(--slate);font-size:15px;margin-top:6px;font-weight:500}
.rhead .date{color:var(--mist);font-size:13px;font-family:"JetBrains Mono",monospace}
.scopenote{background:var(--brand-soft);border-left:3px solid var(--brand);color:var(--brand);font-size:13.5px;padding:10px 14px;border-radius:0 8px 8px 0;margin:14px 0 26px;font-weight:500}
.card{background:var(--paper);border:1px solid var(--line);border-radius:14px;padding:26px 28px;margin-bottom:22px;box-shadow:0 1px 3px rgba(27,36,48,.04),0 8px 24px rgba(27,36,48,.03)}
.eyebrow{font-family:"Manrope",sans-serif;text-transform:uppercase;letter-spacing:.13em;font-size:11px;font-weight:700;color:var(--brand);margin-bottom:4px}
.card>h2{font-size:20px;font-weight:700;margin-bottom:4px}
.card>.lead{color:var(--slate);font-size:14px;margin-bottom:18px}
.thesis{background:linear-gradient(135deg,#1F4E79,#2E6DA4);color:#fff;border:none}
.thesis .eyebrow{color:#BED4EC} .thesis h2{color:#fff}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:14px;margin-top:16px}
.stat{background:rgba(255,255,255,.10);border:1px solid rgba(255,255,255,.18);border-radius:11px;padding:16px 18px}
.stat .v{font-family:"Manrope",sans-serif;font-size:30px;font-weight:800;line-height:1}
.stat .l{font-size:12.5px;color:#D6E4F0;margin-top:7px;font-weight:500}
.stat.g .v{color:#8FE3B6} .stat.a .v{color:#F4CE8B} .stat.r .v{color:#F2A9A0}
.verdict-big{display:flex;align-items:center;gap:12px;margin-top:18px;flex-wrap:wrap}
.verdict-big .label{font-size:13px;color:#D6E4F0;font-weight:600;text-transform:uppercase;letter-spacing:.1em}
.bigpill{font-family:"Manrope",sans-serif;font-weight:700;font-size:15px;padding:7px 18px;border-radius:999px;background:#fff;color:var(--red)}
.tw{overflow-x:auto;-webkit-overflow-scrolling:touch;border-radius:10px}
table{width:100%;border-collapse:collapse;font-size:13.5px}
thead th{background:var(--brand-soft);color:var(--brand);font-family:"Manrope",sans-serif;font-weight:700;text-align:left;padding:11px 13px;font-size:12px;text-transform:uppercase;letter-spacing:.04em;white-space:nowrap}
tbody td{padding:11px 13px;border-top:1px solid var(--line);vertical-align:top}
tbody tr:hover{background:#FAFBFD}
td.el{font-weight:600;color:var(--ink);min-width:160px}
.num,td.num{text-align:center;font-family:"Manrope",sans-serif;font-weight:700;color:var(--ink);white-space:nowrap}
td.mono-cell{font-family:"JetBrains Mono",monospace;font-size:12px;color:var(--slate);white-space:nowrap}
td.gaps{color:var(--slate);min-width:280px;max-width:440px}
td.vc{white-space:nowrap;text-align:right}
.v-green td:first-child{box-shadow:inset 3px 0 0 var(--green)}
.v-amber td:first-child{box-shadow:inset 3px 0 0 var(--amber)}
.v-red td:first-child{box-shadow:inset 3px 0 0 var(--red)}
.v-gray td:first-child{box-shadow:inset 3px 0 0 var(--gray)}
.pill{display:inline-block;font-family:"Manrope",sans-serif;font-weight:700;font-size:11.5px;padding:3px 11px;border-radius:999px;white-space:nowrap}
.pill.green{background:var(--green-bg);color:var(--green)}
.pill.amber{background:var(--amber-bg);color:var(--amber)}
.pill.red{background:var(--red-bg);color:var(--red)}
.pill.gray{background:var(--gray-bg);color:var(--gray)}
.dot{display:inline-block;width:9px;height:9px;border-radius:50%;margin-right:7px;vertical-align:middle}
.dot.green{background:var(--green)} .dot.amber{background:var(--amber)} .dot.red{background:var(--red)} .dot.gray{background:var(--gray)}
.subgrid{display:grid;grid-template-columns:1fr 1fr;gap:22px;margin-top:8px}
.subgrid h3{font-size:14px;margin-bottom:10px;color:var(--brand)}
.prose-find{margin-top:20px} .prose-find p{color:var(--slate);font-size:14px} .prose-find b{color:var(--ink)}
.sblock{border:1px solid var(--line);border-left-width:4px;border-radius:0 10px 10px 0;padding:14px 18px;margin-bottom:13px;background:#FCFCFE}
.sblock.v-red{border-left-color:var(--red)} .sblock.v-amber{border-left-color:var(--amber)} .sblock.v-green{border-left-color:var(--green)}
.sblock h4{font-size:15px;margin:2px 0 6px} .sblock p{color:var(--slate);font-size:13.5px;margin:0}
.omitem{padding:13px 0;border-top:1px solid var(--line)} .omitem:first-child{border-top:none}
.omitem h4{font-size:15px;color:var(--brand);margin-bottom:4px} .omitem p{color:var(--slate);font-size:13.5px;margin:0}
.sev{font-family:"Manrope",sans-serif;font-weight:700;font-size:12px;text-transform:uppercase;letter-spacing:.06em;padding:6px 13px;border-radius:8px;display:inline-block;margin:20px 0 10px}
.sev.hard{background:var(--red-bg);color:var(--red)} .sev.soft{background:var(--amber-bg);color:var(--amber)} .sev:first-child{margin-top:0}
td.bid{font-family:"Manrope",sans-serif;font-weight:800;color:var(--red);text-align:center;width:42px} td.bid.amber-id{color:var(--amber)}
ol.dec{margin:6px 0 0;padding-left:22px} ol.dec li{margin-bottom:13px;color:var(--slate);font-size:13.5px} ol.dec li b{color:var(--ink)}
.legend{display:flex;gap:18px;flex-wrap:wrap;font-size:12.5px;color:var(--slate);align-items:center;font-weight:500}
.legend .item{display:flex;align-items:center}
.foot{color:var(--mist);font-size:12px;margin-top:14px;border-top:1px solid var(--line);padding-top:14px}
@media(max-width:680px){.subgrid{grid-template-columns:1fr} .rhead .ttl{font-size:24px}}
@media(prefers-reduced-motion:reduce){*{transition:none!important;animation:none!important}}
@media print{
  body{background:#fff} .card{box-shadow:none;break-inside:avoid} .wrap{max-width:none}
  .thesis{-webkit-print-color-adjust:exact;print-color-adjust:exact}
  tbody tr{break-inside:avoid}
}
```

---

## Principles

- One format, every analysis report. The data domain changes; the look does not.
- The companion analysis skill owns the content and the section set; this skill owns the
  styling and the shell.
- Lead with the thesis card; make the headline numbers and overall verdict the most
  prominent thing on the page.
- In color, professional, designed — never a monochrome ASCII/terminal table, never a
  raw markdown dump when a report was requested.
- Reuse the shared components so every report reads as the same family; flex the section
  set, not the visual vocabulary.
- Verdict colors are universal (green good / amber attention / red critical / gray
  unassessable); relabel for the domain, keep the mapping.
- Every number traces to the analyzed data; surface data artifacts as mono chips.
- Print-clean and responsive by default. Save to outputs and present the file.
- Layer a client brand-guidelines skill on top when the engagement calls for it — keep
  the layout, swap palette and fonts.
