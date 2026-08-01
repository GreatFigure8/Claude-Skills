# Report Format Spec

The deliverable is one self-contained HTML file (no external JS/CSS except Google Fonts), saved
to `/mnt/user-data/outputs/` and presented with `present_files`. Layer the house
`data-analysis-report-format` and the client brand skill (e.g. `regal-brand-guidelines`) if
present; the tokens below already encode the Regal palette over the standard report shell.

## Design tokens (CSS variables)
```
--ink:#212933; --slate:#4A5568; --mist:#7C878E; --paper:#fff; --canvas:#F4F6F9; --line:#E2E8F0;
--brand:#F56601; --brand-deep:#C44E00; --brand-soft:#FDEBDD; --regal-dark:#212933;
--green:#1E8E5A; --green-bg:#E6F4EC;  /* MET / Configured */
--amber:#C77A11; --amber-bg:#FBF0DD;  /* PARTIAL */
--red:#C0392B;   --red-bg:#FBEAE8;    /* NOT MET / Not started */
--gray:#8A97A8;  --gray-bg:#EEF1F5;   /* NOT ASSESSED */
```
Fonts: Manrope (headings/numbers), Inter (body), JetBrains Mono (codes/IDs). A 6px gradient
top bar (`--regal-dark → --brand → #F8A56E`). Cards: white, 14px radius, 1px `--line` border,
soft shadow. The thesis card is dark (`linear-gradient(135deg,#212933,#3C3C3B)`) with a diagonal
orange watermark.

## Required sections (in order)
1. **Header** — title "REGAL <ENV> — HCM Configuration Readiness" (accent the word
   *Readiness*), subtitle naming the artifacts and `<env code>`, generation date, and the mode
   (A or B).
2. **Scope note** — a `--brand-soft` callout: what was compared (which artifacts, or that none
   were provided), that findings are live-query based, what is excluded / NOT ASSESSED. In
   Mode B, state plainly that no percentage is given and why.
3. **Thesis card** (dark) — headline verdict. **Mode A**: the big overall readiness % with a
   one-line basis, plus stat tiles (KDDs confirmed, RTM requirements, areas MET/PARTIAL/NOT MET,
   a key gap), and artifact chips. **Mode B**: a qualitative verdict, NO percentage.
4. **Scoring methodology** (Mode A) — show the formula in a dark `<code>` block exactly as in the
   skill, the denominator basis (disposition split), and the **RTM-status integrity note** if the
   RTM lifecycle columns are blank.
5. **Readiness scorecard** — one row per area: `Area · Weight · Required (from artifact) ·
   Configured in env · Coverage bar (0/50/100%) · Verdict pill`. Left-border color per verdict.
6. **Requirement traceability** (Mode A) — sample KDD → committed decision → environment finding
   → verdict; highlight mismatches as the highest-value output.
7. **Security findings** — custom roles vs. seeded, role mappings, elevated-access callouts,
   security-profile NOT ASSESSED note.
8. **Extended audit** — Actions/Action Reasons (custom vs seeded), Salary Basis → LDG and →
   Grade Rate with the specific bases missing links, custom flexfield segments.
9. **Gaps to close** — severity-grouped: "Critical — NOT MET (high weight)" then "In build —
   PARTIAL". Include requirement weights so priority is visible.
10. **Footer** — verdict legend, the data provenance line (artifacts + env + date + the
    overall fraction, e.g. `223.0/601 = 37.1%`), the interpretive/point-in-time caveat, and the
    client confidentiality line.

## Verdict pills & bars
- Pills: rounded, Manrope 700, colored bg+fg per verdict (`green/amber/red/gray`).
- Coverage bar: a thin track (`--gray-bg`) with a filled span colored by score
  (green=100, amber=50, red=0) and the % label right-aligned.

## Tone rules
- Lead with the scorecard and numbers; prose is minimal and interpretive.
- Every count must be traceable to a live query or a named artifact.
- Keep the percentage auditable: always show weight basis + assessed/excluded + MET/PARTIAL/NOT
  MET split near the headline number.
- Mode B contains zero percentages, anywhere.

## Build mechanics
Generate the HTML with a small Python script (f-string/`.replace` for the scorecard rows) rather
than hand-writing every row, so verdict class, pill, and bar stay consistent. Save to
`/home/claude/<name>.html`, copy to `/mnt/user-data/outputs/`, then `present_files`.
