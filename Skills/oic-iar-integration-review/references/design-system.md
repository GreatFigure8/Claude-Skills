# OIC IAR Review — Report Design System

The house format for the interactive report this skill produces. One self-contained
HTML file, no external dependencies except Google Fonts. The shape below is fixed; only
the content and the brand palette change per engagement. `../assets/example_report.html`
is this exact system fully populated — open it side by side with this file.

## Why interactive, not a static document

`data-analysis-report-format` is the right choice for a scorecard someone reads
top-to-bottom once. An IAR review is different: the reader wants to verify a claim
against the actual orchestration, filter seventeen findings down to the four that
block go-live, and compare two remediation paths side by side. Three components carry
that weight and are the signature of this format:

1. **The request trace** — the real orchestration, in execution order, stepped through
   one activity at a time with a running cost meter (Fusion calls so far, lookups so
   far, wasted activities so far). This is what makes "this integration calls Fusion
   twice and validates positionally" land as demonstrated fact rather than assertion.
2. **The findings register** — severity-filterable, evidence-first, collapsed by
   default so a 17-finding report doesn't read as a wall of text.
3. **The path-forward decision** — options laid out as a real decision (not a single
   prescribed answer) when the right fix depends on a fact outside the IAR.

## Design tokens

```css
:root{
  /* Structural — do not rename these; components below depend on them */
  --ink:#1c1f22; --slate:#4a5259; --mist:#8b949c; --paper:#fff; --canvas:#f3f5f7; --line:#dfe4e8;
  --brand:#1F4E79; --brand-soft:#EAF1F8;      /* swap for client brand (see brand layering) */
  --brand-2:#2E6DA4;                           /* a lighter step of --brand, for gradients */
  --brand-dark:#13324d;                        /* a darker step of --brand, for header bands */
  --brand-light:#bfe9f7;                       /* a pale tint of --brand, for on-dark accents */

  /* Verdict semantics — universal, never rename or remap the color meaning */
  --green:#0a8c78; --green-bg:#e3f6f2;  /* conforms / keep / on-track */
  --amber:#c25f00; --amber-bg:#fff0e1;  /* partial / needs attention / caution */
  --red:#c0261b;   --red-bg:#fdeae8;    /* broken / unreachable / critical */
  --gray:#7f7f7f;  --gray-bg:#eef1f4;   /* unused / not assessable / n-a */

  --mono:"JetBrains Mono",ui-monospace,SFMono-Regular,Menlo,monospace;
  --disp:"Manrope",system-ui,sans-serif;
  --body:"Inter",system-ui,sans-serif;
}
```

`--brand*` and the two accent hexes (used for the topbar gradient's third stop, e.g. a
yellow) are the only tokens a brand layer should override. Everything else — spacing,
type scale, verdict colors, component structure — stays fixed so every report in this
format reads as the same family.

Fonts: Manrope (display/headers, 600–800), Inter (body, 400–600), JetBrains Mono (code,
data, IDs). If the client's own typefaces are licensed and unavailable to embed,
substitute these and say so once in the footer — don't silently pretend a substitution
is the real thing.

## Structural shell

1. **Topbar** — a 6–8px gradient rule, `--brand-dark` → `--brand` → `--brand-2`, with
   one accent stop from the brand's secondary color if it has one.
2. **Brand band** (only when a client logo exists) — full-width `--brand-dark`
   background directly under the topbar, logo left, a small caps label right ("Oracle
   Integration Review"). See "Logo handling" below for why a dark band is usually
   necessary.
3. **Report header** — title (Manrope 800, ~30px), a one-line subtitle giving package
   name, integration code/version, the source→OIC→target path, and what the review was
   checked against; a mono "prepared by / date" block right-aligned.
4. **Scope note** — a `--brand-soft` callout, `--brand` left border, stating exactly
   what was reviewed (file counts) and — just as important — what was **not** reviewed
   (runtime data, live tenant config, the caller's own behavior). This line is what lets
   every other claim in the report be stated flatly instead of hedged.
5. **Thesis card** — a `--brand` gradient card, white text, one sentence of headline
   verdict, a row of stat tiles (the numbers that prove the thesis — call these out as
   ratios/counts, not vague adjectives: "2 Fusion calls per request, one wasted" beats
   "inefficient"), and one or two big verdict pills.
6. **Sticky tabs** — `position:sticky;top:0`, translucent backdrop-blur bar. Six is the
   right number for this format: *What it does* (architecture + rules-as-coded +
   response contract + what to keep), *Trace a request* (the stepper), *Findings*
   (the register), *[Domain] API conformance* (the field-by-field tables), *Path
   forward* (the decision), *Evidence & sources*.
7. **Footer** — verdict-color legend, a confidentiality/basis line, and (if fonts were
   substituted or the palette approximated) a one-line disclosure.

## Logo handling

Fetch the client's logo from their own domain (search `<brand> logo transparent png` or
pull it from their published CSS/site assets — do not use a generic logo database as the
canonical source when the brand's own site is reachable). Trim to the visible mark with
a small script (crop to the non-transparent/non-background bounding box) rather than
shipping whatever margin the source file had. Check the logo's actual colors before
placing it: a wordmark built white-on-transparent (common for dark-theme site headers)
will vanish on a light card background — put it on a `--brand-dark` band instead of
trying to recolor or outline it. Never fabricate a logo or brand mark that doesn't exist.

## Component: the request trace (signature element)

A vertical timeline (`.flow`) of every real orchestration activity, in execution order,
each one a clickable node; a sticky detail pane (`.detail`) beside it shows the selected
node's explanation and a running cost meter. Build the node list directly from the
orchestration file — don't summarize steps together, and don't invent steps that aren't
there. Each node carries:

- `nm` — short activity name as it appears in the flow
- `kind` — activity type + one contextual detail (e.g. "Fusion HTTP call #1")
- `k` — a category class for the marker dot: default (plain), `k-invoke` (a real
  outbound call — amber marker), `k-fault` (a catch/fault handler — red marker), or a
  category for unused-code activities (gray marker, gray pill in the node)
- `d` — the explanation, written for a reader who cannot see the IAR: what this step
  does, and if relevant, why it's a problem, in a sentence or two
- `cost` — `{c, l, x}` = Fusion calls / lookups / unused-code activities *this step
  contributes*, so the running meter can sum everything up to and including the current
  step

```js
const NODES=[
 {g:'Trigger', nm:'Receive · <op name>', kind:'REST trigger · POST /...', k:'',
  d:'What the trigger receives and any tracking variables captured.', cost:{c:0,l:0,x:0}},
 {g:'InitializeVariable (n assigns)', nm:'someVar = "literal"', kind:'Assign', k:'k-unused',
  d:'Why this is unused: grep result, or what it would have fed if it were wired in.',
  cost:{c:0,l:0,x:1}},
 // ...one entry per real activity, in execution order. `g` starts a new named group
 // heading (matches the orchestration's own scope/section names) and is omitted on
 // every node after the first in that group.
];
```

Rendering and stepping logic (tabs, node click/keyboard handling, cost accumulation,
prev/next) is mechanical — copy it from `assets/example_report.html`'s `<script>` block
(`NODES`, `setNode`, the `flow`/`detail` wiring) rather than rewriting it; only the
`NODES` array and the surrounding prose are engagement-specific.

## Component: findings register

Severity-filterable list of `<details>` cards. Filter chips show live counts per
severity (`All`, `Critical`, `High`, `Medium`, `Low`, `Good`) computed from the data, not
hard-coded. Each finding is a JS object:

```js
{id:'C1', sev:'critical', // critical | high | medium | low | good
 t:'One-sentence title stating the mechanism, not just the symptom',
 one:'One more sentence: the concrete consequence.',
 ev:'<pre>...exact expression(s) from the IAR, with <span class="bad">…</span> /
      <span class="ok">…</span> / <span class="hl">…</span> spans marking the
      specific tokens the reader should notice...</pre>',
 why:'<p>Mechanism-level explanation tying the evidence to documented behavior.</p>',
 ref:'The specific Oracle doc page(s) this is judged against.',
 fix:'<p>Concrete, actionable remediation.</p>'}
```

Render function, filter-chip wiring, and the `<details>` markup are also mechanical —
reuse `assets/example_report.html`'s `F` array structure and its `renderFilters`/
`renderList` functions verbatim; only populate `F` for the engagement at hand.

Severity color mapping (fixed, matches the verdict tokens): critical → red, high →
amber/orange accent, medium → brand-soft blue, low → gray, good → green.

## Component: API conformance tables

One table per Fusion (or other target) REST resource actually called. Columns: the
documented field/rule, what the integration actually sends or checks, whether OIC
validates it before sending, and a verdict pill. Follow each table with an `.sblock`
callout for anything that needs a paragraph (e.g. "what does a 201 actually guarantee
downstream" for a resource with async backend processing). Where the root cause is a
platform mechanic (template vs. query parameter, an unindexed positional XPath), give it
its own two-column "as built vs. as documented" `<pre>` comparison — this is usually the
single most persuasive piece of the report.

## Component: path forward

Not a single prescription unless the IAR genuinely only supports one answer. When the
right fix depends on a fact outside the IAR (does the target's config rely on a
processing feature this integration is bypassing?), lay out real options side by side
(`.two` grid of `.opt` cards), each with a numbered `<ol>` of concrete steps and an
explicit statement of the trade-off that decides between them. Follow with an interim
hot-fix table if a smaller change can ship before the full rebuild, and a target-state
recipe using the same `.flow`/`.node` markup as the trace component (without the
click-through JS — a static illustration of the redesigned sequence).

## Reference CSS (drop-in)

Copy this in full and adjust only the `:root` brand tokens per engagement/brand layer.
It already includes the overflow fixes below — do not remove them.

```css
*{box-sizing:border-box}
html{scroll-behavior:smooth}
body{margin:0;background:var(--canvas);color:var(--ink);font-family:var(--body);font-size:14.5px;line-height:1.58;-webkit-font-smoothing:antialiased}
a{color:var(--brand)}
h1,h2,h3,h4{font-family:var(--disp);margin:0;color:var(--ink)}
code,.mono{font-family:var(--mono);font-size:13px}
code{overflow-wrap:anywhere;background:var(--brand-soft);color:var(--brand-dark);padding:1px 6px;border-radius:5px;font-weight:500}
pre{font-family:var(--mono);font-size:13px;line-height:1.5;background:#262626;color:#e9eef2;padding:14px 16px;border-radius:10px;overflow:auto;margin:10px 0 0;white-space:pre-wrap;word-break:break-word;max-width:100%}
pre .hl{color:#ffc600} pre .cm{color:#8fb7cc} pre .bad{color:#ff8a80} pre .ok{color:#7fe0c9}
.topbar{height:8px;background:linear-gradient(90deg,var(--brand-dark) 0%,var(--brand) 55%,var(--brand-2) 85%)}
.wrap{max-width:1180px;margin:0 auto;padding:26px 24px 70px}
.brandline{display:flex;align-items:center;justify-content:space-between;gap:16px;margin:-26px -24px 24px;padding:16px 28px;background:var(--brand-dark)}
.brandline .logo small{color:var(--brand-light);letter-spacing:.16em;text-transform:uppercase;font-size:13px;font-weight:700}
.rhead{display:flex;justify-content:space-between;align-items:flex-end;flex-wrap:wrap;gap:12px;margin-bottom:8px}
.rhead .ttl{font-size:31px;font-weight:800;letter-spacing:-.6px;line-height:1.12;color:var(--brand-dark)}
.rhead .sub{color:var(--slate);font-size:15px;margin-top:8px;font-weight:500;max-width:820px}
.rhead .meta{text-align:right;color:var(--mist);font-size:13px;font-family:var(--mono);line-height:1.7}
.scopenote{background:var(--brand-soft);border-left:4px solid var(--brand);color:var(--brand-dark);font-size:13.5px;padding:12px 16px;border-radius:0 10px 10px 0;margin:16px 0 22px;font-weight:500}
.card{overflow:hidden;background:var(--paper);border:1px solid var(--line);border-radius:14px;padding:26px 28px;margin-bottom:22px;box-shadow:0 1px 3px rgba(0,0,0,.05),0 8px 24px rgba(0,0,0,.04)}
.eyebrow{font-family:var(--disp);text-transform:uppercase;letter-spacing:.14em;font-size:12px;font-weight:700;color:var(--brand);margin-bottom:6px}
.card>h2{font-size:21px;font-weight:800;margin-bottom:6px;color:var(--brand-dark)}
.card>.lead{color:var(--slate);font-size:14.5px;margin-bottom:18px;max-width:900px}
.thesis{background:linear-gradient(135deg,var(--brand-dark) 0%,var(--brand) 45%,var(--brand-2) 100%);color:#fff;border:none;position:relative;overflow:hidden}
.thesis .eyebrow{color:var(--brand-light)} .thesis h2{color:#fff;font-size:24px}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(165px,1fr));gap:14px;margin-top:20px}
.stat{background:rgba(255,255,255,.09);border:1px solid rgba(255,255,255,.2);border-radius:12px;padding:16px 18px}
.stat .v{font-family:var(--disp);font-size:32px;font-weight:800;line-height:1}
.stat .l{font-size:13px;color:#d6e4f0;margin-top:8px;font-weight:500}
.stat.g .v{color:#7fe0c9} .stat.a .v{color:#f4ce8b} .stat.r .v{color:#f2a9a0}
.verdict-big{display:flex;align-items:center;gap:14px;margin-top:22px;flex-wrap:wrap}
.verdict-big .label{font-size:13px;color:#d6e4f0;font-weight:600;text-transform:uppercase;letter-spacing:.12em}
.bigpill{font-family:var(--disp);font-weight:800;font-size:15px;padding:8px 20px;border-radius:999px;background:#fff;color:var(--red)}
.bigpill.amber{color:var(--amber)} .bigpill.green{color:var(--green)}
.tabs{position:sticky;top:0;z-index:20;background:rgba(243,245,247,.94);backdrop-filter:blur(8px);border-bottom:1px solid var(--line);margin:0 -24px 22px;padding:10px 24px;display:flex;gap:6px;flex-wrap:wrap}
.tab{font-family:var(--disp);font-weight:700;font-size:13.5px;color:var(--slate);background:transparent;border:1px solid transparent;padding:8px 14px;border-radius:999px;cursor:pointer}
.tab:hover{background:#fff;border-color:var(--line)}
.tab.active{background:var(--brand-dark);color:#fff;border-color:var(--brand-dark)}
.tab:focus-visible,button:focus-visible,a:focus-visible,[tabindex]:focus-visible{outline:3px solid var(--brand-2);outline-offset:2px}
.panel{display:none} .panel.active{display:block;animation:fade .25s ease}
@keyframes fade{from{opacity:0;transform:translateY(4px)}to{opacity:1;transform:none}}
.pill{display:inline-block;font-family:var(--disp);font-weight:700;font-size:12px;padding:3px 11px;border-radius:999px;white-space:nowrap}
.pill.green{background:var(--green-bg);color:var(--green)} .pill.amber{background:var(--amber-bg);color:var(--amber)} .pill.red{background:var(--red-bg);color:var(--red)} .pill.gray{background:var(--gray-bg);color:var(--gray)} .pill.blue{background:var(--brand-soft);color:var(--brand-dark)}
.dot{display:inline-block;width:10px;height:10px;border-radius:50%;margin-right:7px;vertical-align:middle}
.dot.green{background:var(--green)} .dot.amber{background:var(--amber)} .dot.red{background:var(--red)} .dot.gray{background:var(--gray)}
/* --- overflow fixes: keep these, this format is a two-column grid of tables/code --- */
.tw{overflow-x:auto;-webkit-overflow-scrolling:touch;border-radius:10px;border:1px solid var(--line);max-width:100%}
table{width:100%;border-collapse:collapse;font-size:13.5px}
thead th{background:var(--brand-dark);color:#fff;font-family:var(--disp);font-weight:700;text-align:left;padding:11px 13px;font-size:12.5px;text-transform:uppercase;letter-spacing:.05em;white-space:nowrap}
tbody td{padding:11px 13px;border-top:1px solid var(--line);vertical-align:top}
tbody tr:hover{background:#f8fbfd}
.v-green td:first-child{box-shadow:inset 4px 0 0 var(--green)} .v-amber td:first-child{box-shadow:inset 4px 0 0 var(--amber)} .v-red td:first-child{box-shadow:inset 4px 0 0 var(--red)} .v-gray td:first-child{box-shadow:inset 4px 0 0 var(--gray)}
.subgrid{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:22px;margin-top:8px}
.two{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:18px}
.subgrid>*,.two>*,.opt{min-width:0;max-width:100%}
.filters{display:flex;gap:8px;flex-wrap:wrap;margin:0 0 18px;align-items:center}
.chip{font-family:var(--disp);font-weight:700;font-size:13px;padding:6px 13px;border-radius:999px;border:1px solid var(--line);background:#fff;color:var(--slate);cursor:pointer}
.chip.on{border-color:var(--brand-dark);background:var(--brand-dark);color:#fff}
.find{border:1px solid var(--line);border-left-width:6px;border-radius:0 12px 12px 0;background:#fff;margin-bottom:14px;overflow:hidden}
.find.sev-critical{border-left-color:var(--red)} .find.sev-high{border-left-color:var(--amber)} .find.sev-medium{border-left-color:var(--brand)} .find.sev-low{border-left-color:var(--gray)} .find.sev-good{border-left-color:var(--green)}
.find summary{min-width:0;list-style:none;cursor:pointer;padding:16px 20px;display:flex;gap:14px;align-items:flex-start}
.find summary::-webkit-details-marker{display:none}
.find summary .id{font-family:var(--mono);font-size:13px;font-weight:500;color:var(--mist);min-width:36px;padding-top:3px}
.find summary h3{overflow-wrap:anywhere;font-size:16.5px;font-weight:800;color:var(--brand-dark);line-height:1.3}
.find summary .oneline{color:var(--slate);font-size:14px;margin-top:4px}
.find summary .caret{width:22px;height:22px;border-radius:50%;border:1px solid var(--line);display:grid;place-items:center;color:var(--slate);flex:none;transition:transform .2s;margin-top:2px}
.find[open] summary .caret{transform:rotate(180deg)}
.find .body{min-width:0;padding:0 20px 20px 70px;color:var(--slate);font-size:14px}
.find .body h4{font-size:13px;text-transform:uppercase;letter-spacing:.12em;color:var(--brand);margin:16px 0 6px}
.trace{display:grid;grid-template-columns:minmax(0,1.15fr) minmax(0,1fr);gap:26px;margin-top:6px}
.flow{position:relative;padding-left:26px}
.flow:before{content:"";position:absolute;left:11px;top:14px;bottom:14px;width:4px;background:linear-gradient(var(--brand),var(--brand-dark));border-radius:4px}
.node{position:relative;background:#fff;border:1px solid var(--line);border-radius:10px;padding:10px 14px;margin-bottom:8px;cursor:pointer;display:flex;gap:12px;align-items:center;transition:border-color .15s,transform .15s}
.node:before{content:"";position:absolute;left:-21px;top:50%;width:14px;height:14px;margin-top:-7px;border-radius:50%;background:#fff;border:3px solid var(--brand)}
.node.k-invoke:before{background:#ffc600;border-color:var(--brand-dark)} .node.k-unused:before{background:var(--line);border-color:var(--gray)} .node.k-fault:before{background:var(--red);border-color:var(--red)}
.node .kind{font-size:13px;color:var(--slate);overflow-wrap:anywhere}
.node>span:nth-child(2){min-width:0;flex:1}
.detail{position:sticky;top:64px;background:#fff;border:1px solid var(--line);border-radius:14px;padding:20px 22px}
.meter{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin:14px 0 6px}
.meter div{background:var(--canvas);border-radius:10px;padding:10px 8px;text-align:center}
.meter .v{font-family:var(--disp);font-weight:800;font-size:24px;color:var(--brand-dark);line-height:1}
.meter .v.warn{color:var(--amber)} .meter .v.bad{color:var(--red)}
.opt{border:1px solid var(--line);border-radius:12px;padding:18px 20px;background:#fff}
.kv{display:grid;grid-template-columns:minmax(140px,200px) minmax(0,1fr);gap:6px 14px;font-size:13.5px;margin-top:10px}
.kv dd{margin:0;color:var(--ink);min-width:0;overflow-wrap:anywhere}
.legend{display:flex;gap:18px;flex-wrap:wrap;font-size:13px;color:var(--slate);align-items:center;font-weight:500}
.foot{color:var(--mist);font-size:13px;margin-top:14px;border-top:1px solid var(--line);padding-top:14px;line-height:1.7}
@media(max-width:820px){.trace{grid-template-columns:1fr}.detail{position:static}.two{grid-template-columns:1fr}.subgrid{grid-template-columns:1fr}.rhead .ttl{font-size:25px}.find .body{padding-left:20px}.meter{grid-template-columns:repeat(2,1fr)}.kv{grid-template-columns:1fr}}
@media(prefers-reduced-motion:reduce){*{transition:none!important;animation:none!important}html{scroll-behavior:auto}}
@media print{body{background:#fff}.card{box-shadow:none;break-inside:avoid}.wrap{max-width:none}.thesis{-webkit-print-color-adjust:exact;print-color-adjust:exact}.tabs{display:none}.panel{display:block!important}tbody tr{break-inside:avoid}.find{break-inside:avoid}.detail{position:static}}
```

## Overflow — the recurring failure mode and its fix

The single most common defect in a first draft of this report is content spilling past
its card at some viewport width. It always traces back to one cause: a CSS grid's
default `min-width:auto` on its children, which lets a wide table or an unwrapped `<pre>`
line force the whole column wider than the card, wider than `.wrap`, wider than the
viewport. The reference CSS above already fixes this (`minmax(0,1fr)` grid columns,
`min-width:0` on grid children, `white-space:pre-wrap` + `word-break:break-word` on
`<pre>`, `overflow-wrap:anywhere` on inline code and table cells, tables scrolling inside
their own `.tw` wrapper rather than the page scrolling). If you add any new grid layout
or code block, apply the same three rules, and verify — don't assume — by rendering the
finished file (Playwright or similar) at a few widths (≈420, 820, 1000, 1280, 1440px)
and checking that no element's bounding-box right edge exceeds the viewport width on any
tab, including inside opened `<details>` findings.

## Minimum type size

Every text element must be ≥13px. The base body font-size above is 14.5px; the smallest
elements (table header labels, mono chips, meter labels) are set at exactly 13px — don't
go smaller when adding new components.
