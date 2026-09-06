---
name: oic-iar-integration-review
description: >
  Analyze an exported Oracle Integration Cloud integration (an .iar file) against
  Oracle's published REST API docs and OIC design best practices, then render findings
  as an interactive single-file HTML report — a step-through request trace, a
  severity-filterable findings register, API conformance tables, and a path-forward
  decision, every claim traced to the IAR or a live-searched Oracle doc. Use whenever
  the user uploads/references an .iar and asks to analyze, review, audit, or assess it;
  mentions an IAR export or OIC integration review; questions whether it follows Oracle
  best practices or the documented REST API; or describes it as chatty, slow, pulling
  too much data, or failing silently against Fusion — even without the word "review".
  Also for "the OIC review format" or a past review referenced by name. Not for
  building/modifying an OIC integration (oic-integration-build) or generic reports with
  no OIC/IAR artifact (data-analysis-report-format).
---

# OIC IAR Integration Review

Reverse-engineer what an Oracle Integration Cloud integration actually does — not what
its name or description claims — by reading every artifact in its exported package,
checking that behavior against Oracle's current REST API documentation and OIC design
guidance, and delivering the findings as a client-presentable interactive report.

The report born from this skill was built reviewing an Archrock OTL time-clock
integration; that finished report is bundled at `assets/example_report.html` — open it
before building a new one so the shell, the trace stepper, the findings register, and
the API-conformance tables are in view.

## Core discipline: never guess, always trace

Every claim in the finished report must point at one of two things: an exact line from
the IAR (an XPath expression, a JCA property, a DVM row, an orchestration element — quoted
verbatim, not paraphrased into something that sounds more damning or more benign than it
is) or a specific, currently-fetched Oracle documentation page. If a conclusion depends
on something outside the IAR — the target tenant's live configuration, runtime instance
data, the caller's own behavior — say so explicitly and mark it a verification step, not
a finding. This is the same discipline a functional architect owes a client: the report
is worthless the first time someone catches a claim that doesn't hold up.

### Copy, never retype

Evidence quotes are byte-exact copies — produced by `sed -n '<a>,<b>p'`, `grep -F`, or a
read of the file — never typed out from memory of what the file said. In this skill's
first graded run every report failed the verbatim check, and never on a point of fact:
`xml:id="id_53"` was dropped from inside a tag, `&quot;` was rendered as `'`, `AND` was
lowercased to `and`, `concat (` was respaced, namespace prefixes were stripped, and a `…`
was placed inside a quoted string. Each of those reads to a client as "that quote is not
in the file", and one is enough to make a reader distrust the other fifty-eight. The
mechanism isn't carelessness: reconstructing a line from your understanding of it feels
exactly like copying it.

- Copy the bytes. If you can't paste them from a tool result, re-read the exact range.
- Never elide inside a quote. If a line is too long, quote a shorter *contiguous* span —
  `…` or `...` breaks the string.
- Don't normalise: keep the entity references, attribute order, casing, and spacing the
  file has, including the `xml:id` attributes OIC writes into every element.
- Inside an Evidence `<pre>`, an unmarked line is a verbatim quote. Every label, file
  path, arrow, or `key = value` rendering you wrote yourself goes inside
  `<span class="cm">…</span>`, so a reader can tell your summary from the file's text.
- Verify before delivering: `python3 scripts/check_quotes.py <report.html> <file.iar>`
  greps every unmarked Evidence line against the extracted archive and prints the ones it
  can't find. Fix what it names.

### Never claim a check you didn't run

An Evidence block that says "`grep -rl` returns only the defining file" when no such grep
ran is a fabrication even when the conclusion is right, and it's the one error a client
can catch without knowing anything about OIC. Run the command, then quote what it
printed. If you concluded something by reading rather than by grepping, write it as a
reading ("only processor_97 references it, by inspection") — that is honest and still
useful. Order matters as well: a check run after the report was written is not what the
report was based on, so run your verification before you write the finding, not to
retro-fit it.

Oracle's REST APIs are release-versioned and do change shape (required fields, query
parameters, response semantics, resource paths) across releases. Never answer from
memory of what an endpoint "usually" looks like — web-search the current
`docs.oracle.com` page for the exact resource before asserting what it requires or
returns. The same applies to OIC platform mechanics (adapter parameter handling, fault
model, scheduling limits) — search Oracle's current integration-cloud documentation
rather than relying on general REST/iPaaS intuition. `references/oracle-hcm-otl-notes.md`
is a dated starting point for search terms from one prior review, not a citable source —
re-verify anything from it live.

### Hedge runtime claims one sentence at a time

An IAR tells you what the integration *would* do. It never tells you what it *has* done.
Unless this session actually opened the activity stream or called the tenant, there is no
instance data behind any sentence about current behaviour — and "this works today", "Fusion
has been consistent about that", "with one record it is correct, which is why nobody has
noticed" all read as analysis and land as fact. A handover framing ("I inherited this, is it
OK?") pulls hardest toward exactly this reassurance; the honest answer to "does it work" is
what the artifact does, plus the fact that what it *has done* is not in the artifact.

- Every behavioural claim is one of two things: **quoted** from the IAR or a fetched doc, or
  explicitly marked **inference / needs verification in that same sentence**.
- A blanket disclaimer at the top of the report hedges nothing below it. Readers — and
  graders — read the sentence, not the preamble, so the hedge travels with the claim.
- Banned constructions, whatever the surrounding argument: "this/it works (today | fine |
  still)", "runs fine", "which is why it has not been noticed", "nobody has hit this",
  "Fusion has been consistent", "in practice it always …". Conceding an assumption in the
  same breath ("so this works — but it is an assumption") does not rescue the claim; it
  still asserts the behaviour. No reassurance prose either ("nothing to worry about").
- Rewrite in the conditional, deriving from the artifact rather than from the field: not
  "with one record it is correct, which is why it has not been noticed", but "with exactly
  one record the PATCH targets the intended row; with two or more it targets whichever
  record Fusion returns first — verify on the pod". Same finding, no claim about what has
  been observed, and the verification step is now visible to the client.
- Check it mechanically before delivering, alongside the quote check:

```bash
python3 scripts/check_claims.py <report.html>
```

  It flags the banned constructions and any sentence asserting runtime state with no
  verification language in that same sentence. It errs toward flagging; dismiss a note in a
  second, but fix every FAIL — in iteration-2 grading four such sentences in one report
  failed the whole runtime-claims assertion.

## Workflow

### 1. Extract and inventory every artifact

```bash
mkdir -p work && cd work && unzip -o -q /path/to/*.iar
find . -type f | sort
```

Read, don't sample. An IAR's substance lives across many small files:

- `icspackage/project/*/PROJECT-INF/project.xml` — the orchestration itself: every
  activity in execution order (`<ns2:orchestration>`), every processor definition
  (assign, transformer/map, contentBasedRouter/switch, invoke, scope/`try`, catch,
  messageTracker), and every messageContext (what schema each variable holds).
- `icspackage/project/*/PROJECT-INF/analysis.json` — a quick activity-count summary;
  cross-check it against what you actually count in `project.xml`.
- `icspackage/project/*/resources/**/*.jca` — each REST/SOAP endpoint's real
  configuration: resource URI, HTTP verb, media type, security policy, and (critically)
  the pasted request/response samples, which is what actually generated the schema the
  mapper sees.
- `icspackage/project/*/resources/**/*.wsdl` — the generated schema for each endpoint;
  check `maxOccurs` on arrays (an integration that only reads element `[1]` of an
  `unbounded` array is a finding).
- `icspackage/project/*/resources/**/*.xsl` — every mapping, in full. This is where
  request/response shape and pass-through-vs-transform decisions actually live.
- `icspackage/project/*/resources/**/expr.properties` — every Assign and Switch
  expression, verbatim (`TextExpression` and `XpathExpression`).
- `icspackage/dvms/*.dvm` — every lookup table, in full (not just column names — the
  actual rows matter: is a key present, is a value stale, do two DVMs disagree).
- `icspackage/appinstances/*.xml` — connection definitions: adapter type, security
  policy, role (source/target/both), and audit info (who last touched it, when).

### 2. Find every dead end — grep before you conclude

A huge fraction of what makes these reviews valuable is catching assigned values that
are never read, lookups whose result nothing consumes, and validation branches that
structurally cannot fire. Don't eyeball this — check it:

```bash
# For every variable an Assign creates, does anything else reference it?
grep -rl '\$variableName\b' --include="*.xsl" --include="expr.properties" .
```

A variable referenced only in the file that defines it is unused. Note the *count* of
lookups and dead assigns per request — it is a real, quotable cost (each DVM lookup and
each Fusion invoke is measurable overhead), not just tidiness.

For positional XPath (`timeEvents[1]`, `[2]`, a fixed index into something the WSDL
declares `maxOccurs="unbounded"`), work out what happens on the untested cardinalities
(a 1-element array, a 3-element array) — XPath comparing against an absent node is
`false`, which silently passes validation rather than failing it. This is usually the
single highest-value finding in one of these reviews.

Enumerate *every* positional site before moving on — `grep -rn '\[1\]\|\[1\.0\]\|\[2\]'`
across the XSLs and `expr.properties` — and say what happens at each one. Reasoning
carefully about one indexed array while silently passing over a second one in the same
mapping reads as thorough and leaves the same bug in place.

For any REST invoke whose filter/query logic looks suspicious, check whether the value
was mapped into a **template parameter** (path segment, declared `{like this}` in the
resource URI) versus a **query parameter** (declared separately and mapped on its own).
OIC's REST adapter treats these as genuinely different constructs; a filter expression
written into a template parameter is silently ignored by the target and the endpoint
returns its default (often unfiltered) collection. This exact bug — `?q=...` string
built and then stuffed into a `{QueryParam}` template slot — is common enough to check
for by default whenever a downstream call is returning more data than expected.

### 3. Ground every Fusion-facing claim in a live-fetched Oracle doc

For each REST resource the integration calls, search for and fetch the current
`docs.oracle.com` reference page (search `<resource name> REST API Oracle Fusion Cloud`,
then fetch the `op-<resource>-<verb>.html` or `api-<resource>.html` page — these pages
frequently reject a direct guessed URL, so search first and fetch the result). Pull:
required fields and their max lengths, valid value lists (lookup-backed enumerations),
query parameters and finders on GET collections, and the documented response semantics
(what does `count` mean, what does a 201 actually guarantee downstream). For HCM/ERP/SCM
resources with a multi-stage processing model behind the REST call (e.g., an import that
lands in an interface table and is only turned into a real record by a separate
scheduled process), find and read that process's documentation too — a 2xx from the
REST call is frequently "accepted for processing," not "done," and that gap is often
exactly what the integration's response contract gets wrong.

Also check the adapter-level mechanics against Oracle's OIC documentation: which adapter
Oracle recommends for the target application (a generic REST adapter hand-configured
from pasted samples is more fragile than a purpose-built adapter that discovers the
resource catalog), the platform's stated anti-patterns (chatty integrations — an invoke
inside a loop, or unnecessary extra round-trips; synchronous integrations doing too
much; too many duplicate connections), and its fault-handling model (scope-per-invoke
with handlers, a global fault handler as the last resort, Fault Return for a real HTTP
status rather than the platform's generic 500).

Two of those checks get skipped most often, and both belong in every report:

- **Adapter choice.** Name the adapter each connection actually uses (read
  `icspackage/appinstances/*.xml`) and, when the target is a Fusion application, state
  whether Oracle ships a purpose-built adapter for it (Oracle HCM Cloud, ERP Cloud, and
  so on). A generic REST adapter pointed at a Fusion pod is a finding in its own right —
  hand-pasted samples rather than a discovered resource catalog define the schema, so the
  integration silently keeps whatever shape the sample had — even when it currently works.
- **Sample-payload hygiene.** Read the `RequestSample`/`ResponseSample` blocks in every
  `.jca`. Dev/test hostnames, real e-mail addresses, plaintext passwords and live IDs left
  in the samples ship inside the package and are a finding, severity set by what leaked.

**Cite only what you actually fetched.** Every "judged against" reference must resolve to
a URL that appeared in this session's search or fetch results. Recalled citations are the
trap: a W3C spec section, an A-Team blog post, a plausible `docs.oracle.com` path that
404s — all three look like diligence and none can be checked. If a fetch fails (403, 404,
a redirect to a different release), search for the working page or drop the reference and
argue from the IAR instead. A claim that rests on general knowledge should say so rather
than borrow authority from a page you didn't read.

### 4. Classify findings

Use this severity taxonomy — it's what the report's filter chips and color-coding are
built around:

- **Critical** — the integration does something other than what it claims: a validation
  that cannot fire, a filter that isn't applied, an unhandled fault path, a response that
  lies about the outcome.
- **High** — wrong result or materially wasted capacity under normal (not edge-case)
  load: unused lookups running every request, an incomplete validation that lets bad
  data through, a status contract that doesn't match the target system's real processing
  model.
- **Medium** — maintainability, operability, or security posture: mislabeled tracking
  variables, a generic adapter where a purpose-built one exists, unrelated data bundled
  into the package, a contract that's a verbatim copy of the target's (no abstraction).
- **Low** — cosmetic or edge-case: leftover dev/test data in adapter samples, naming
  typos, a style choice that's technically fine but worth flagging.
- **Good** — behavior to explicitly preserve. Every review needs some of these; an
  all-red report reads as biased and is usually wrong about something.

Every finding needs, in this order: **evidence** (the exact IAR expression or config,
quoted), **why it matters** (tie the mechanism to Oracle's documented behavior — not
"this seems bad" but "Oracle's adapter treats template and query parameters as separate
constructs, so..."), **judged against** (the specific doc page(s)), and **fix** (concrete
and actionable, not "review this").

### 5. Render the report

Read `references/design-system.md` for the exact CSS tokens, component markup, and JS
interaction patterns (the tabbed shell, the thesis card, the click-through request
trace with its running cost meter, the filterable findings register, the API-conformance
tables, the path-forward decision framework, the evidence/sources tab) and follow it —
don't redesign the shape, only fill it with this integration's content. `assets/example_report.html`
is the rendered reference; open it to see the format in context.

**Brand.** If the client is Archrock, read `references/archrock-brand.md` for the
palette, font substitutions, and the logo-on-navy-band pattern (the wordmark is white-on-
transparent and disappears on a light page), and use `assets/archrock_logo.png`. If the
client has its own brand-guidelines skill available, use that instead — same pattern
`data-analysis-report-format` follows: this skill owns the shape, a brand skill owns the
palette. Otherwise use the neutral tokens already in `design-system.md`.

**Wording.** Avoid loaded one-word labels for technical states — "unused code" or
"unreachable branch," not "dead" — the same fact reads as objective either way, but one
version doesn't need defending in a client meeting.

**Hackett logo.** Every report carries The Hackett Group's mark regardless of client
brand — embed `assets/hackett_logo.svg` inline per the "Hackett logo (always)" rule in
`references/design-system.md`.

**Before you deliver — run the checker, don't eyeball it.**

```bash
uv run --with playwright scripts/check_report.py <report.html> <source.iar>
```

It mechanically checks what a hand review keeps missing: the six tabs, trace completeness
against `project.xml`, cost-meter accuracy, horizontal overflow at **420, 820, 1000, 1280
and 1440px** with every `<details>` forced open and every tab visible, a 13px minimum
computed font size, neutral wording, and the Hackett logo. Every failure it prints gets
fixed before the report is presented — fixed, not noted. In the first graded run the only
runs that passed the trace, cost and overflow rules were the ones that ran this script;
the ones that verified by hand all failed, including one that checked "narrow" at 445px
and shipped a block that overflows at 420. Check the exact widths.

Two definitions the checker enforces, so build the data to match:

- **One trace node per orchestration activity.** `NODES` carries an entry for every
  element inside `<ns2:orchestration>` that isn't a container or declaration
  (`orchestration`, `integrationMetadata`, `globalVariable`, `globalTry`, `label`,
  `route`, `try`) — assigns, transformers, routers, invokes, notifications, stage-file
  actions, catches, activity-stream loggers, replies, stops, all of them, in execution
  order. Rolling "13 assigns" up into one node under-counts the trace: the first graded
  run shipped 49 nodes for 58 activities, 33 for 37, and 48 for 85.
- **The cost meter counts every invoke.** `cost.c` summed across all nodes equals the
  number of `<invoke>` activities in `project.xml` — *every* outbound call, not only the
  Fusion-facing REST ones, because a local integration call, a BIP SOAP call and a
  callback each cost a real round trip. `cost.l` summed equals the number of
  `dvm:lookupValue` occurrences across `expr.properties`. Where the distinction between
  call types matters to the narrative, draw it in the node's `kind`/`d` text — never by
  leaving invokes out of the meter.

The overflow rule is usually a layout bug, not a content one (a two-column CSS grid whose
children are tables or `<pre>` blocks overflows its card unless the grid columns are
`minmax(0,1fr)` and the children have `min-width:0` — baked into the reference CSS, but
check any component you add). If Playwright or another browser tool is available, also
screenshot each tab before presenting, so you have seen what the client will see.

Save the finished file to `/mnt/user-data/outputs/` and present it — never just paste
the HTML into chat.

## Reference files

- **`references/design-system.md`** — the report's visual and interactive design
  system: palette tokens, typography, the full component CSS (drop-in), and the JS
  scaffolding for tabs, the request-trace stepper, and the filterable findings register.
  Read this before writing any HTML.
- **`references/archrock-brand.md`** — Archrock's palette (sourced from
  `archrock.com/css/base.css`), font substitutions, and logo usage notes. Read this only
  when the client is Archrock.
- **`references/oracle-hcm-otl-notes.md`** — dated notes on the Oracle Fusion HCM
  Time & Labor REST APIs (`timeEventRequests`, `workers`, `timeRecordEventRequests`) and
  OIC design pitfalls from a prior review. A starting point for search terms only —
  re-verify everything live before citing it in a report.
- **`assets/example_report.html`** — a complete rendered report in this format
  (Archrock / INT0830 AFM Employee OTL Request). Open it to see the shell, thesis card,
  trace stepper, findings register, and conformance tables in context.
- **`assets/archrock_logo.png`** — trimmed, transparent Archrock wordmark for use per
  `archrock-brand.md`.
- **`scripts/check_report.py`** — the mechanical report checker (tabs, trace
  completeness, cost meter, overflow at five widths, minimum font size, wording, Hackett
  logo). Run it on every report before delivery:
  `uv run --with playwright scripts/check_report.py <report.html> <source.iar>`.
- **`scripts/check_quotes.py`** — greps every unmarked Evidence line in a report against
  the extracted IAR and lists what isn't there:
  `python3 scripts/check_quotes.py <report.html> <file.iar>`.
- **`scripts/check_claims.py`** — flags unhedged runtime claims and reassurance prose in a
  finished report (the "this works today" family), skipping `<pre>` evidence blocks:
  `python3 scripts/check_claims.py <report.html>`.
