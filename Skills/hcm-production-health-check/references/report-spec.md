# Report specification and build

The deliverable is a single self-contained HTML file built by `assets/build.py` from the data in `assets/data.py`. Copy both to a working folder, replace the data, run `python3 build.py`, render with Playwright, present the file.

## Design
- Design system: Claude Design "industry" export (Barlow / Barlow Condensed, blueprint frames with corner ticks, Hackett accent palette `#235CE8 / #184389 / #F4900C`, background `#F4F7F9`). `assets/tpl/ds.css` is the design-system CSS with its `@font-face` rules stripped; the six latin font subsets are in `assets/tpl/*.bin` and are embedded as base64 by the builder; `assets/tpl/logo_clean.svg` is the Hackett logo with C2PA metadata removed.
- Severity colours: Critical `#F4900C`, High `#184389`, Medium `#235CE8`, Low `#7A8E9E`. Domain score colour: <50 orange, <70 dark blue, else blue.
- Minimum 15px text (code tags 14px is the only exception). No headers in tables beyond uppercase labels; tables are CSS grid `.tbl` with `.th`/`.tr` rows.

## Section order and content
1. **Masthead** — logo, "HCM Implementation Health Check", Environment, run date. Sticky `nav.toc` beneath it.
2. **Title grid** — eyebrow (client · product), h1 "Production health check, <month year>", lede, KPI blueprint (employees, active headcount, accounts · non-employee, LEs · BUs · payrolls, one-line footprint).
3. **Summary** (`.verdict`, dark blue) — overall score counting up, label (At risk <50 / Needs attention <70 / Healthy), headline sentence, one paragraph, severity pills.
4. **Footprint** — two-column key/value list.
5. **Definitions** — employee / not an employee / duplicate rule card, and the population waterfall table (Population, Count, Basis).
6. **What is working** — metric cards.
7. **Scorecard by domain** — clickable cards (score, bar, blurb, finding count, highest severity) that filter the register.
8. **Findings register** — severity and domain segment filters, expand all; rows: Ref, Severity, Finding, Domain, Measured; expanded body: What we found / Why it matters / Recommended action / Effort / Owner / Reference.
9. **Trends** — hires vs terminations by month since go-live; scheduled-process errors last 30 days (hover for success rate).
10. **Access** — account classification table; IT Security Manager and BI Admin holder-class tables; roles containing seeded BIAdministrator with user counts; who effectively holds it; roles still held by open leaver accounts; AoR table; non-person account category table.
11. **National IDs** — four tiles + one-line note.
12. **Failing processes** — root-cause card; BIP reports with errors; other ESS jobs with errors; recurring schedule ownership table; flow/extract task failures.
13. **Payroll** — issues table (#, Issue, Measured, Why it matters to pay, Finding); element table by classification; "Not yet verified" list.
14. **Recruiting** — open requisitions by state; active applications by phase/state with idle >30d; offers since go-live by phase/state.
15. **Modules** — Module / What is configured and in use / Assessment.
16. **Footer** — © year The Hackett Group, Inc. All Rights Reserved. Prepared by Jonathan Stevenson. · Enabling Digital World Class® Performance.

No "Scope and method" section. No names, emails, person numbers or personal folder paths.

## Interaction
- Sticky nav (`position: sticky; top: 0`), active link tracks scroll; last link lit at page bottom.
- Nav click: `window.scrollTo({top: offsetTop-chain − 64, behavior:'smooth'})` — never derive the target from `getBoundingClientRect()` of a section that may be scaled.
- Appear animation: builder JS wraps each non-grid section's children in `.rv-inner.rv-anim`; grid sections get `.rv-anim` themselves. `.rv-anim {opacity:0; transform:scale(.5); transition: opacity 1.1s cubic-bezier(.22,1,.36,1), transform 1.3s …}`; `section.in` → opacity 1, scale 1. Enter observer `rootMargin '0px 0px -12% 0px'`, leave observer resets when fully out of view, so it replays.
- Bars: widths/heights start at 0 and are set from `data-w`/`data-h` when the section shows; scorecard keeps bars across re-render via a `shown` class on the grid.
- Reduced motion and print: everything visible, no transitions.

## Build and verify
```bash
python3 build.py                      # writes /mnt/user-data/outputs/<name>.html
python3 - <<'EOF'                     # headless checks
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b=p.chromium.launch(); pg=b.new_page(viewport={'width':1400,'height':900}); errs=[]; pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///mnt/user-data/outputs/<name>.html'); pg.wait_for_timeout(500)
    for a in [a.get_attribute('href') for a in pg.query_selector_all('#toc a')]:
        pg.click(f'a[href="{a}"]'); pg.wait_for_timeout(2600)
        print(a, round(pg.evaluate(f"document.querySelector('{a}').getBoundingClientRect().top")), pg.evaluate(f"getComputedStyle(document.querySelector('{a}').querySelector('.rv-anim')||document.querySelector('{a}')).opacity"))
    print(errs); b.close()
EOF
grep -o -i "[a-z0-9._%+-]*@[a-z0-9.-]*\.[a-z]\{2,\}" <file>   # must be empty
```
Every anchor should print top ≈ 64 and opacity 1. Then `present_files`.

## Data file conventions (`data.py`)
- `FINDINGS`: list of dicts (id, severity, domain, title, metric, metricLabel, evidence, impact, actions[], effort, owner, reference). Renumber sequentially after removing one and fix every `(Fnn)` cross-reference in evidence, module table, account table and payroll table.
- `DOMAINS`: name, score, blurb. `TERMS`/`HIRES`: [month, n] since go-live. `ESS30`: [job, errors, successes].
- Tables are lists of tuples rendered by `rows(tbl, headers, grid_columns, right_aligned_indexes)`.
