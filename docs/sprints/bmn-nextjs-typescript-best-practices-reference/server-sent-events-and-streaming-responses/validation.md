# Validation — server-sent-events-and-streaming-responses

Branch `wip/nextjs-typescript-best-practices-reference/server-sent-events-and-streaming-responses`, cut from
`origin/feat/nextjs-typescript-best-practices-reference` (efff2ea). Date: 2026-10-04.

## TDD record

| Step | Command | Result |
| --- | --- | --- |
| RED | `pytest .../test_nextjs_topic_sse_and_streaming.py` against the stub | 22 failed, 0 passed. Reasons: `is_stub` true, no rules, no sections (`LookupError: no heading 'Not confirmed by the docs'`), missing terms, no ts blocks |
| GREEN | same file against the finished topic file | 22 passed |
| GREEN, generic contract | `pytest test_nextjs_reference.py test_nextjs_topic_sse_and_streaming.py -rs` | 151 passed, 56 skipped. No skip line names `sse-and-streaming.md`, so the 7 generic topic tests now run on it |
| REFACTOR | Reflowed prose to 140 columns without splitting links, cut the first draft from 987 to 794 lines, re-ran | 151 passed, 56 skipped |

The first RED run had one vacuous pass (`test_sse_examples_never_use_any` passed on a file with no code).
It now asserts that ts/tsx blocks exist, which gave the 22 failures above.

## Gates

- Full suite: `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q -rs`
  gives **696 passed, 56 skipped** (73 s). The skeleton's record was 667 passed, 63 skipped: +22 topic
  tests, +7 generic tests no longer skipped. The 56 skips are 7 generic tests × 8 stubs, each with the
  reason `<file> is a stub pending <owning slug>`. Nothing is skipped for this file.
- Lint: `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` gives `All checks passed!`.
- `wc -l` on the topic file: 794 (cap 800). `grep -nE 'TODO|TBD'`: no output.
- shellcheck: no `.sh` file changed. Types: none (stack.md).
- Scope (AC11): `git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists
  only the topic file, the topic test file and files under this story folder.

## AC10 one-off: Sources equals the evidence file

Command (saved as a script outside the repo, run from the worktree root):

```text
topic = set(source_urls(read(TOPICS_DIR / "sse-and-streaming.md")))
ev = set(re.findall(r"https://[^\s|)>]+", open(".../evidence/sources-verified.md").read()))
```

Output:

```text
topic: 52 evidence: 52
missing from evidence: []
extra in evidence: []
exit=0
```

Every one of the 52 Sources is also cited in the file's prose (checked while generating the evidence
table: no row says `Sources only`). 34 of the 52 are on nextjs.org or vercel.com.

## Grounding

- The rule sheet in the plan was transcribed, then the load-bearing pages were fetched again the same day
  (the evidence file marks which). Numbers match: the Fluid and non-Fluid duration tables, the Edge
  25 s / 300 s row, 1,024 file descriptors, the 504, `supportsCancellation` and its glob example, and the
  Streaming guide's HTTP contract and `X-Accel-Buffering` text.
- Nothing is stated that a cited page doesn't confirm. What no page confirms is listed under
  `## Not confirmed by the docs` (11 items), each with the URLs checked.
- Differences from the plan sheet are listed in `evidence/sources-verified.md`. The ones that change
  behaviour: the error frame is named `stream-error`, not `error` (SSE-14); the Vercel Functions API
  reference says `runtime = 'edge'` is unsupported from Next.js 16.3 (SSE-9, NC 10); and the client hook
  calls its Effect Event from an arrow function, as react.dev's example does.

## Snippet checks (not committed; scratch directory outside the repo)

The plan said snippets aren't compiled. They were, because the file is a flagship and the reference
implementation has to be correct:

- All 7 path-commented TypeScript blocks were extracted and type-checked with TypeScript 7.0.2,
  `@types/react` 19.3.0 and `@types/node` 26 under `strict`, `noUncheckedIndexedAccess` and
  `exactOptionalPropertyTypes`, with a `@/*` path alias to `./src/*` and local stubs for `@/lib/auth` and
  `ai`. Result: no errors.
- The route handler was run under Node 26 with in-memory stubs and mock timers. Six tests passed. They
  cover replay from `Last-Event-ID` then live events, the heartbeat at 15 s and release on abort (one
  test); release on `cancel()`; a clean close at `maxDuration` minus 10 s; a failing `subscribe` becoming
  a `stream-error` frame then a close; an already-aborted request closing at once; and 401 before any
  stream exists. The response headers were `text/event-stream` and `no-cache, no-transform`, with no
  `Connection`.
- The client helpers were run the same way: the frame encoder (multi-line data, CR/LF/NUL rejected),
  `readSse` over frames split across chunks, 204 stopping, a partial trailing block dropped, and
  `readSseWithReconnect` resuming with the last id after a failure, backing off, and stopping on 204.
- The React hook was type-checked only. No React runtime test was run.

## Assumptions

1. **Anti-pattern shape.** The skeleton's contract fixes `### Don't …` H3 headings, each with a fenced
   block, so the file uses them, not the plan's `- **Don't**` bullets. Each item names its `SSE-` rule in
   the heading, contains a `**Do**` line and has a bad block and a good block. The plan's pairing test was
   written to that shape (`h.anti_patterns`, `**Do**` in the body, at least two fences). The file has 4
   items, above the floor of 3, instead of the plan's 6, because the 800-line cap bound.
2. **Line cap.** The first complete draft was 987 lines. It was cut to 794 by reflowing prose to 140
   columns (links kept whole), shortening the route walkthrough and Not confirmed items, dropping the
   plan's `ask-chat` client and two anti-patterns, and removing a few secondary links. No rule was cut.
3. **Reconnecting reader.** SSE-23 says a `fetch` reader must reconnect with backoff and send the last
   id, so `read-sse.ts` also has `readSseWithReconnect` and a 204 stop, which the plan's sketch lacked.
4. **Route failure handling.** The plan's route had no failure path for `subscribe` or `replaySince`. A
   rejection would have left the heartbeat timer running against a dead stream. The route now catches,
   sends a `stream-error` frame and closes, and `abort` closes the stream through the same `end()`.
5. **Event name.** See Grounding: `stream-error`, kept as `(convention)`.
6. **AI SDK.** The chat route keeps the plan's `streamText` and `toTextStreamResponse()` as vercel.com
   shows them. The file says the API names differ by AI SDK major and sends readers to the SDK docs
   without a URL, because the AI SDK's own site isn't an allowed host.
7. **Rule ids.** The checklist and anti-patterns cite only `SSE-` ids. The file never writes another
   topic's id and links the sibling topic files instead.
8. **Defects found in shared files**, for REVIEW① to pick up, not fixed here (this story never edits
   them): `nextjs.md` non-negotiable 2 allows a new `middleware.ts` "if you need the Edge runtime", and
   the Vercel Functions API reference says that from Next.js 16.3 setting `runtime` to `edge` is no longer
   supported. Whether that covers middleware isn't stated on either host. The skeleton's `STUB_TITLES`
   keeps "Server-Sent Events" capitalised, and this file keeps that H1.
9. No Supabase, Vercel, env var or migration is involved. `deploy_pending` is `[]`.

## TEST1: unit (2026-10-04)

Branch `wip/nextjs-typescript-best-practices-reference/tests-unit-1`, cut from the detached run base `origin/dev` `59279a3` (the run branch tip after
the wave-2 merges, with origin/dev merged in). Tester: `tests-unit-1`. No code was changed; this is a
verification pass.

### Commands and results

| Step | Command | Result |
| --- | --- | --- |
| Full suite with coverage | `uv run --quiet --with pytest --with pytest-cov python -m pytest Skills/dev-bother-me-nope/assets/tests -q --cov=Skills/dev-bother-me-nope/assets/tests --cov-report=term` | **1026 passed in 95.32s (0:01:35)**, exit 0, 0 failed, 0 skipped. Log: `docs/sprints/bmn-nextjs-typescript-best-practices-reference/nextjs-standard-entry-point-and-skill-wiring/evidence/test1-unit-full-suite.txt` |
| Lint | `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` | `All checks passed!` |
| Story tests, verbose | `pytest test_nextjs_topic_sse_and_streaming.py test_nextjs_reference.py ... -v` (483 tests across the nextjs files and `test_skill_text_rules.py`) | 483 PASSED, 0 other. The tests this map cites are listed in `evidence/test1-unit-results.txt` |
| TERMS and example needles | one-off script comparing this story's criterion 3 and 4 lists with the test | story TERMS (24) equal the test's TERMS (24), same order: True; story example needles missing from the test source: 0 |
| URL sets | one-off script comparing `## Sources` of `references/nextjs/sse-and-streaming.md` with the URLs in `evidence/sources-verified.md` | 52 cited, 52 listed, nothing only in one of them. All 52 evidence rows carry fetch date 2026-10-04 and a non-empty Backs cell |
| Scope | one-off `git diff --name-only <merge>^1 <merge>` for this story's merge `eacca37` | 4 files, all inside the story scope (the topic file, `test_nextjs_topic_sse_and_streaming.py`, and files under `docs/sprints/bmn-nextjs-typescript-best-practices-reference/server-sent-events-and-streaming-responses/`); outside scope: none |

### Coverage

- `references/nextjs/sse-and-streaming.md`: Markdown, coverage n/a. It is exercised by the generic contract tests and by `test_nextjs_topic_sse_and_streaming.py`; the file is 29 rules, 795 lines (cap 800).
- `nextjs_doc_helpers.py` (shared parser the tests use): **99%** (243 of 245 statements). Uncovered: line 180 (an unterminated code fence at end of file) and line 294 (`h1` of an empty file). Target 80% met.
- `test_nextjs_topic_sse_and_streaming.py`: **100%** (96 of 96 statements). Whole suite: **99%** (3604 of 3635).

### Criterion map

All [unit] criteria of `story.md`, mapped to the test or one-off check that covers them. The generic
contract tests are the ones `test_nextjs_reference.py` runs for every topic file; none is skipped
(the suite has no skips), so each ran on `sse-and-streaming.md`.

| AC | Criterion | Covering test(s) / check | Result |
| --- | --- | --- | --- |
| 1 | Contract | generic contract tests (17 x `[sse-and-streaming.md]` + `test_rule_ids_are_unique_across_topic_files`)<br>`test_sse_topic_uses_only_sse_rule_ids` | PASS |
| 2 | Not a stub, at least 15 SSE rules | `test_sse_topic_is_no_longer_a_stub`<br>`test_sse_topic_has_at_least_15_rules` | PASS |
| 3 | Required terms | `test_sse_topic_names_every_required_concept` | PASS |
| 4 | Examples (SSE handler, frame encoding, heartbeat, Last-Event-ID, EventSource hook, getReader; no `any`) | `test_sse_topic_has_route_handler_example`<br>`test_sse_topic_has_frame_encoding_example`<br>`test_sse_topic_has_heartbeat_cleared_example`<br>`test_sse_topic_has_last_event_id_resume_example`<br>`test_sse_topic_has_client_event_source_hook_example`<br>`test_sse_topic_has_fetch_reader_example`<br>`test_sse_examples_never_use_any` | PASS |
| 5 | SSE handler complete: GET, abort, cancel(, frames | `test_sse_route_handler_example_releases_on_abort_and_cancel`<br>`test_sse_frame_encoder_writes_id_event_data_and_blank_line` | PASS |
| 6 | Vercel section: `maxDuration` and a vercel.com link in `## Rules` | `test_sse_rules_set_max_duration_with_vercel_link`<br>`test_sse_route_handler_example_closes_before_max_duration` | PASS |
| 7 | Client facts sourced to MDN/WHATWG | `test_sse_rules_state_event_source_client_facts`<br>`test_sse_sources_include_mdn_or_whatwg` | PASS |
| 8 | Version notes name the major and link nextjs.org | `test_sse_version_notes_name_the_major_and_link_nextjs` | PASS |
| 9 | Reviewer-ready | `test_sse_review_checklist_items_each_name_an_sse_rule`<br>`test_sse_anti_patterns_pair_every_dont_with_a_do`<br>`test_sse_checklist_and_anti_patterns_cite_only_defined_rules` | PASS |
| 10 | Grounding evidence (one-off) | one-off set-equality check, see below | PASS |
| 11 | Scope and gates (one-off + suite + ruff) | one-off `git diff --name-only` check, full suite, ruff (see below)<br>`test_sse_not_confirmed_section_exists_and_cites_urls` | PASS |

**Totals:** 11 PASS, 0 FAIL, 0 uncovered.

### TEST1 assumptions

1. AC9 (grounding evidence) is a one-off check by design ("not a permanent test"). It was re-run here with the plan's set-equality method and passed.
2. AC10 scope is checked against the story's merge into the run branch (`git diff --name-only <merge>^1 <merge>`), because `origin/feat/...` has since moved on. The suite and ruff are checked on the final tree.
3. Where the criterion text asks for content beyond what its test asserts (for example, the shape of an example), the test is taken as the verification the story names; factual correctness of the claims against nextjs.org and vercel.com is the REVIEW① lens, not a unit test.

## TEST1 content

Run 2026-10-04 on a detached worktree at `origin/dev` `59279a3` (branch `wip/nextjs-typescript-best-practices-reference/tests-content-1`). This repo ships Markdown, so the black-box surface is the content: live sources, and the TypeScript snippets compiled in a real Next.js 16.3.8 project. File under test: `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/sse-and-streaming.md`.

### 1. Live sources

Command (per URL, 8 in parallel): `curl -sL -A <desktop browser UA> --max-time 20 --max-redirs 10 -o /dev/null -w "%{http_code}|%{url_effective}|%{num_redirects}" <url>`. A URL passes only when the final status is 2xx and the final URL is the same page (host without `www.`, path without trailing slash). Scope: every URL in the `## Sources` section.

Result: **52 URLs, 52 pass, 0 fail**. (Across all ten files: 283 unique URLs, 283 pass, 0 fail; every one returned HTTP 200 with no redirect.)

| URL | HTTP | Redirects | Result |
| --- | --- | --- | --- |
| https://developer.mozilla.org/en-US/docs/Web/API/EventSource | 200 | 0 | pass |
| https://developer.mozilla.org/en-US/docs/Web/API/EventSource/EventSource | 200 | 0 | pass |
| https://developer.mozilla.org/en-US/docs/Web/API/ReadableStream/ReadableStream | 200 | 0 | pass |
| https://developer.mozilla.org/en-US/docs/Web/API/ReadableStreamDefaultController/desiredSize | 200 | 0 | pass |
| https://developer.mozilla.org/en-US/docs/Web/API/ReadableStreamDefaultController/enqueue | 200 | 0 | pass |
| https://developer.mozilla.org/en-US/docs/Web/API/ReadableStreamDefaultReader/read | 200 | 0 | pass |
| https://developer.mozilla.org/en-US/docs/Web/API/Request/signal | 200 | 0 | pass |
| https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events | 200 | 0 | pass |
| https://developer.mozilla.org/en-US/docs/Web/API/TextDecoder/decode | 200 | 0 | pass |
| https://developer.mozilla.org/en-US/docs/Web/API/TextEncoderStream | 200 | 0 | pass |
| https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS | 200 | 0 | pass |
| https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cache-Control | 200 | 0 | pass |
| https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Connection | 200 | 0 | pass |
| https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/AsyncGenerator/return | 200 | 0 | pass |
| https://html.spec.whatwg.org/multipage/server-sent-events.html | 200 | 0 | pass |
| https://html.spec.whatwg.org/multipage/urls-and-fetching.html | 200 | 0 | pass |
| https://nextjs.org/blog/next-16 | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/cacheComponents | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/compress | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/route | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/maxDuration | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/runtime | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/after | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/connection | 200 | 0 | pass |
| https://nextjs.org/docs/app/getting-started/route-handlers | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/authentication | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/backend-for-frontend | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/migrating-to-cache-components | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/preserving-ui-state | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/self-hosting | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/streaming | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/upgrading/version-16 | 200 | 0 | pass |
| https://nextjs.org/docs/messages/edge-runtime-deprecated | 200 | 0 | pass |
| https://react.dev/reference/react/useEffect | 200 | 0 | pass |
| https://react.dev/reference/react/useEffectEvent | 200 | 0 | pass |
| https://vercel.com/changelog/node-js-vercel-functions-now-support-per-path-request-cancellation | 200 | 0 | pass |
| https://vercel.com/changelog/node-js-vercel-functions-now-support-request-cancellation | 200 | 0 | pass |
| https://vercel.com/docs/errors/function_invocation_timeout | 200 | 0 | pass |
| https://vercel.com/docs/fluid-compute | 200 | 0 | pass |
| https://vercel.com/docs/functions/configuring-functions/duration | 200 | 0 | pass |
| https://vercel.com/docs/functions/functions-api-reference | 200 | 0 | pass |
| https://vercel.com/docs/functions/limitations | 200 | 0 | pass |
| https://vercel.com/docs/functions/runtimes/edge | 200 | 0 | pass |
| https://vercel.com/docs/functions/streaming-functions | 200 | 0 | pass |
| https://vercel.com/docs/functions/websockets | 200 | 0 | pass |
| https://vercel.com/docs/limits | 200 | 0 | pass |
| https://vercel.com/docs/project-configuration/vercel-json | 200 | 0 | pass |
| https://vercel.com/kb/guide/ai-gateway-and-ai-sdk | 200 | 0 | pass |
| https://vercel.com/kb/guide/do-vercel-serverless-functions-support-websocket-connections | 200 | 0 | pass |
| https://vercel.com/kb/guide/handling-backpressure | 200 | 0 | pass |
| https://vercel.com/kb/guide/publish-and-subscribe-to-realtime-data-on-vercel | 200 | 0 | pass |

### 2. Snippet type-check

Method (same for every story; the scratch project lives outside the repo and is not committed):

- Scratch dir `/private/tmp/claude-501/-Users-jonathanstevenson-Source-claude-skills/b71aefe4-ae21-4000-aa3e-8b70fbcfbe94/scratchpad/tscheck-test1/w1/app`, `npm install --save-exact next@16.3.8 react react-dom typescript@7.0.2 @types/react @types/react-dom @types/node zod server-only client-only vitest @playwright/test @testing-library/react vite-tsconfig-paths @vitejs/plugin-react shiki jose ai @vercel/otel @vercel/firewall @opentelemetry/api` (resolved: next 16.3.8, react and react-dom 19.3.0, typescript 7.0.2, @types/react and @types/react-dom 19.3.0, @types/node 26.6.4, zod 4.6.5, server-only 0.0.1, client-only 0.0.1, vitest 5.0.3, @playwright/test 1.63.0, @testing-library/react 16.3.3, vite-tsconfig-paths 6.1.1, @vitejs/plugin-react 6.1.1, shiki 4.5.0, jose 6.2.12, ai 7.0.127, @vercel/otel 2.1.3, @vercel/firewall 1.2.5, @opentelemetry/api 1.9.1; all from npm). typescript 6.0.3 and 5.9.3 were installed beside it for the cross-check and the parse pass.
- Every ```` ```ts ```` and ```` ```tsx ```` fence of the ten files was extracted (218 fences: 160 Do/Pattern/rule, 58 inside the Don't half of an Anti-patterns entry). Each doc becomes one virtual Next.js project under `app/proj/<doc>/`: a fence whose first line is a `// path/to/file.ts` comment is written at that path (first occurrence only, Don't halves never), so `@/` and relative imports between fences resolve to the real fence; every other fence is its own module under `_loose/`. `next typegen` runs per project so the global `PageProps`, `LayoutProps` and `RouteContext` types exist; dummy `page.tsx`, `layout.tsx`, `route.ts` and `@slot` files are created for the route literals the fences use.
- Compiler config: the doc's own P1 `tsconfig.json` (`strict: true`, `noUncheckedIndexedAccess`, `lib: ES2020`, `moduleResolution: bundler`, ...) with `paths` `@/*` -> `./*` and `./src/*`; command `node node_modules/typescript/bin/tsc --noEmit --pretty false -p tsconfig.json` (TypeScript 7.0.2) in each project. Cross-checks: TypeScript 6.0.3 with the same config, and TypeScript 7.0.2 with the `create-next-app` default compilerOptions (`strict`, `target ES2017`, `lib dom/dom.iterable/esnext`).
- Prelude (declared, never silent): a fence that is a fragment gets only (a) `export {}` when it has no import or export, (b) a wrapper `async function __fragment() {` ... `}` when it is a bare statement list (TS1108 `return` outside a function), (c) an `import` of a well-known Next.js, React or Zod name (`z`, `redirect`, `notFound`, `revalidateTag`, `updateTag`, `cookies`, `Suspense`, ...) that the fence uses but does not import, (d) `declare var name: any` for any other free name the fence uses but does not define, (e) an any-typed stub module for a local `@/` or `./` import that no fence in the doc defines, (f) a typed export on the doc's own module when the doc says the module holds more than it shows. The records below say which fence got which.
- A fence with a parse error cannot be typechecked, so it is parked outside the project and reported on its own.

Result for `sse-and-streaming.md`: **15 fences = 11 Do/Pattern/rule + 4 Don't half. Do/Pattern/rule: 10 pass, 1 fail.**

Cross-checks for this file: TypeScript 6.0.3 with the same config reports 1 Do-fence error(s) (#06); TypeScript 7.0.2 with the `create-next-app` default compilerOptions reports 0.

#### Failures (Do/Pattern/rule fences)

- **FAIL** #06 (line 476) fetch reader for POST or custom headers
  - `TS2550` at fence line 21, col 48 (file line 497): Property 'at' does not exist on type '[string, string][]'. Do you need to change your target library? Try changing the 'lib' compiler option to 'es2022' or later.
  - Cause: the fence calls `.at(-1)`; `Array.prototype.at` is ES2022, and the doc's own recommended `tsconfig.json` (typescript.md P1) sets `lib: ["ES2020", "DOM", "DOM.Iterable"]`. With the `create-next-app` default (`lib` includes `esnext`) or with `lib: ["ESNext", ...]` the same fence compiles clean (checked). Either bump the P1 `lib`/`target` or avoid `.at()` in the snippet.
  - Repro: build the virtual project from the fences with the P1 `tsconfig.json`, run `tsc --noEmit -p tsconfig.json` (7.0.2 or 6.0.3); the error is in `_loose/06-fetch-reader-for-post-or-custom-headers.ts`.

#### Pass with a declared prelude that deserves a look

None.

#### Prelude record

- 7 of 11 Do/Pattern/rule fences begin with a `// path` comment and sit at that path in the virtual project; the other 4 are standalone modules under `_loose/`.
- `export {}` was appended to 4 fences that had no import or export (fences #09, #11, #13, #15); that only makes the fragment a module so names do not collide.
- Other preludes (Do/Pattern/rule fences only):

| Fence | Prelude |
| --- | --- |
| #03 (line 236) The SSE Route Handler | any-typed stub module: `src/lib/auth.ts` |
| #07 (line 571) AI SDK on Vercel | any-typed stub module: `src/lib/auth.ts` |
| #09 (line 611) Don't start a heartbeat or subscription with no release path (SSE-15) | free names declared `any`: `isReleased`, `heartbeat`, `unsubscribe`, `request` |
| #11 (line 629) Don't fan out through a module-level listener set (SSE-21) | free names declared `any`: `subscribe`, `session`, `write` |
| #15 (line 657) Don't decide the status after the stream has started, or throw mid-stream (SSE-6, SSE-14) | wrapped in `async function __fragment()`; free names declared `any`: `session`, `send`, `sseEvent`, `controller` |

#### Don't half (expected to be wrong; recorded, not failed)

| Fence | Outcome |
| --- | --- |
| #08 (line 603) Don't start a heartbeat or subscription with no release path (SSE-15) | does not parse (a method-body fragment, not a whole statement or module): 1,19 TS1005: ';' expected.; 3,2 TS1128: Declaration or statement expected. |
| #10 (line 623) Don't fan out through a module-level listener set (SSE-21) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #12 (line 635) Don't pass headers to `EventSource` or put a bearer token in its URL (SSE-7) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #14 (line 650) Don't decide the status after the stream has started, or throw mid-stream (SSE-6, SSE-14) | compiles (the mistake is a runtime, security or caching rule, not a type error) |

#### JSON fences

- line 377 parses as JSON.

## FIX①

Branch `wip/nextjs-typescript-best-practices-reference/server-sent-events-and-streaming-responses-fix`, cut from
`origin/feat/nextjs-typescript-best-practices-reference` at `8188c54`. Files touched: `references/nextjs/sse-and-streaming.md`,
`assets/tests/test_nextjs_topic_sse_and_streaming.py` and this story folder.

### Result

| Id | Result | Verified by |
| --- | --- | --- |
| R1-C1 | fixed | `test_sse_route_handlers_read_a_nullable_session_not_a_redirecting_one`; harness `R1-C1` (signed-out GET and POST: 307 -> /login before, 401 after) |
| R1-C9 (this file's side) | fixed | same guard: both route fences import `getSession` from `@/lib/dal`; no `@/lib/auth`, no `verifySession(` |
| R1-C2 | fixed | `test_sse_route_holds_live_events_until_the_replay_is_written`; harness `R1-C2` (101,98,99,100[,101] before; 98,99,100,101 after) |
| R1-C3 | fixed | `test_sse_vercel_json_keys_use_the_src_prefix`; harness `R1-C3` (`path.matchesGlob` of the `src/app/api/*/route.ts` files against the keys) |
| R1-C10 | fixed | `test_sse_route_checks_desired_size_before_enqueueing`; harness `R1-C10` (4,808,907 bytes queued before; 1,048,666 and self-closed after) |
| R1-C11 | fixed | `test_sse_route_unsubscribes_inside_after`; harness `R1-C11` (no after() task before; the task settles only after the unsubscribe after) |
| R1-C12 | fixed | `test_sse_hook_keys_resume_id_and_status_by_url`; harness `R1-C12` (room b opened with lastEventId=5 and status 'open' before) |
| R1-C13 | fixed | `test_sse_fetch_reader_stops_on_a_final_4xx`; harness `R1-C13` (401/403/400 retried 5 times in 300 ms before; reject after 1 open after; 503 still retries) |
| R1-C14 | fixed | `test_sse_plain_text_ai_stream_has_its_own_reader`; harness `R1-C14` (chat route body through readSse: "" before; readTextStream: "Hello, world" after) |
| R1-C20 | fixed | `test_sse_fetch_readers_cancel_the_body_on_failure`; harness `R1-C20` (body cancelled=false for a 500 and for a throwing onMessage before) |
| R1-C21 | fixed | `test_sse_fetch_reader_tracks_id_only_blocks`; harness `R1-C21` (reconnected with 1 after `id: 7` before; 7 after) |
| R1-C22 | fixed | `test_sse_hook_listens_for_stream_error`; harness `R1-C22` (source open and status 'open' after stream-error before) |
| R1-C23 | fixed | `test_sse_backoff_wait_removes_its_abort_listener`; harness `R1-C23` (listeners 0,1,2,3,4,5 before; 0 at every reconnect after) |
| R1-C24 | fixed | `test_sse_frames_to_stream_takes_the_request_signal`; harness `R1-C24` and strict tsc (TS2554 on `framesToStream(..., request.signal)` before) |

No item was not-reproducible or blocked. Every pytest guard above was run against the pre-fix file (a scratch copy of the test module
pointed at `git show origin/feat/…:…/sse-and-streaming.md`) and failed: the 13 new guards plus
`test_sse_route_handler_example_releases_on_abort_and_cancel`, whose needle moved from `verifySession` to `getSession(`. Gates on this
branch: pytest `1039 passed`; ruff `All checks passed!`.

### What changed

- SSE-6 and both route fences use `getSession()` from `@/lib/dal` (the run's session-helper contract); the `redirect` page is cited for
  the 307 and added to Sources.
- Route: live events go to a `held` buffer until the `replaySince` result is written, then only those the replay didn't send (matched by
  id). `send()` checks `controller.desiredSize` under a 1 MiB `ByteLengthQueuingStrategy` and closes a client that far behind. The
  unsubscribe runs in `release()` on the subscription promise and settles the promise returned from `after(() => cleanedUp)`. SSE-16,
  SSE-19, SSE-20, the "How it meets the rules" bullets, the SSE-15 Do block and Not-confirmed item 10 say so.
- `framesToStream(frames, signal)` closes the generator on `abort` and in `cancel()`, and removes its listener.
- `vercel.json` keys are `src/app/api/events/**/*` and `src/app/api/chat/**/*`. Re-read live on 2026-10-04: the duration page says a
  `src` project must "prefix your function routes with `/src/`" and writes its key as `src/api/*.js`; the vercel.json page lists
  `src/pages/**/*` as a key. Not-confirmed item 9 was wrong and is gone; items 10 and 11 are now 9 and 10.
- Hook: the resume id and the status are stored with their URL, so a new URL starts at `'connecting'` with no `lastEventId`, while a
  re-run on the same URL still resumes; `stream-error` closes the source and reports `'closed'`.
- fetch reader: `HttpStatusError` and `bodyReader()` (cancels a non-OK body); `readSse` cancels its reader in `finally` and reports ids
  through `onId`, so an `id:`-only block moves the resume id (WHATWG dispatch step 1 sets the last event ID before the empty-data return,
  re-read live); `readSseWithReconnect` rethrows a 4xx other than 408 and 429; `wait()` removes its abort listener. `parseBlock` uses
  `.pop()` instead of `.at(-1)`, so the fence no longer needs `lib` ES2022 (TEST① TS2550; the `lib` itself is typescript.md's, R1-C4).
- AI SDK: new `src/shared/utils/read-text-stream.ts` (`readTextStream`) for `toTextStreamResponse()`; the "as in the previous section"
  pointer to `readSse` is gone. Checklist items for auth, SSE-16, SSE-20 and the fetch reader updated, and one added for plain text.
- Length: the Rules and Not-confirmed sections are one line per item or sub-bullet now, as route-handlers-and-apis.md and
  routing-and-metadata.md already are; no rule or item was dropped. 786 lines (limit 800).

### Harness (run under Node, before and after)

Scratch folder `scratchpad/fix1-sse/`, copied to `evidence/fix1-harness/`. `extract.mjs` writes every `// src/...` fence and the json
fence of a copy of the file to `out/<label>/`. `loader.mjs` resolves `@/` there and swaps `@/lib/dal` (the contract, using the real
`redirect` from next@16.3.8), `@/lib/realtime`, `next/server` (an `after` recorder) and `ai` for the stubs in `stubs/`. `harness.mjs`
runs the SSE route, the chat route, the hook (react@19.3.0 with react-test-renderer@19.3.0 and a fake `EventSource`), the readers and
`framesToStream`, and turns a thrown redirect into a response the way Next's app-route module does (`module.js` ~486, status from
`getRedirectStatusCodeFromError`). Node v26.0.0, `SSE_LABEL=<label> node --import ./loader.mjs harness.mjs`.

Before (`git show origin/feat/nextjs-typescript-best-practices-reference:…/sse-and-streaming.md`):

```text
FAIL R1-C1 signed-out SSE GET and chat POST answer 401 (not a 307 to /login) :: GET 307 -> /login, POST 307 -> /login
FAIL R1-C2 replayed ids precede live ids, each id once :: snapshot-before-live 101,98,99,100; snapshot-after-live 101,98,99,100,101; want 98,99,100,101
FAIL R1-C10 a client that never reads cannot grow the queue without bound :: 4808907 bytes queued for 20000 unread events (last id 20000)
FAIL R1-C11 unsubscribe runs inside a task registered with after() :: no after()/waitUntil task registered; unsubscribe() runs untracked
FAIL R1-C12 switching url starts the new room fresh; same-url re-runs still resume :: room b opened with lastEventId=5 and status 'open'; same-url re-run resumed from 9
FAIL R1-C22 a stream-error frame closes the source and reports closed :: after stream-error: source.closed=false, status 'open'
FAIL R1-C13 401/403/400 stop the reconnect loop; 503 still retries :: 401: still retrying after 5 open(s); 403: still retrying after 5 open(s); 400: still retrying after 5 open(s); 503: still retrying after 5 opens
FAIL R1-C14 the chat route plain-text body reaches the UI :: readSse (no plain-text reader exists) delivered ""
FAIL R1-C20 readSse cancels the body on a non-OK status and when onMessage throws :: 500 body cancelled=false; onMessage-throws body cancelled=false
FAIL R1-C21 an id-only block moves the resume id :: reconnected with Last-Event-ID 1 after an id-only block "id: 7"
FAIL R1-C23 backoff waits leave no abort listeners behind :: abort listeners at each reconnect: 0,1,2,3,4,5
FAIL R1-C24 aborting the signal passed to framesToStream closes the generator :: framesToStream takes 1 parameter(s); abort left the generator open
FAIL R1-C3 vercel.json functions keys match the src/app route files :: keys app/api/events/**/*, app/api/chat/**/* match none of src/app/api/events/route.ts, src/app/api/chat/route.ts
before: 0 pass, 13 fail
```

After (this branch):

```text
PASS R1-C1 signed-out SSE GET and chat POST answer 401 (not a 307 to /login) :: GET 401, POST 401
PASS R1-C2 replayed ids precede live ids, each id once :: both orders 98,99,100,101
PASS R1-C10 a client that never reads cannot grow the queue without bound :: 1048666 bytes queued, stream ended itself=true, last id 4374
PASS R1-C11 unsubscribe runs inside a task registered with after() :: after() task settled once unsubscribe finished (52 ms after abort)
PASS R1-C12 switching url starts the new room fresh; same-url re-runs still resume :: room b opened with no lastEventId, status 'connecting'; same-url re-run resumed from 9
PASS R1-C22 a stream-error frame closes the source and reports closed :: source closed, status 'closed'
PASS R1-C13 401/403/400 stop the reconnect loop; 503 still retries :: 401: rejected (Stream request failed: 401) after 1 open(s); 403: rejected (Stream request failed: 403) after 1 open(s); 400: rejected (Stream request failed: 400) after 1 open(s); 503: still retrying after 5 opens
PASS R1-C14 the chat route plain-text body reaches the UI :: readTextStream delivered "Hello, world"
PASS R1-C20 readSse cancels the body on a non-OK status and when onMessage throws :: 500 body cancelled=true; onMessage-throws body cancelled=true
PASS R1-C21 an id-only block moves the resume id :: reconnected with 7
PASS R1-C23 backoff waits leave no abort listeners behind :: abort listeners at each reconnect: 0,0,0,0,0,0
PASS R1-C24 aborting the signal passed to framesToStream closes the generator :: generator finally ran on abort (framesToStream takes 2 parameters)
PASS R1-C3 vercel.json functions keys match the src/app route files :: keys src/app/api/events/**/*, src/app/api/chat/**/* match both route files
after: 13 pass, 0 fail
```

Strict tsc (`typecheck.mjs`: typescript.md P1 compilerOptions, so `strict` and `noUncheckedIndexedAccess`, with next@16.3.8 types,
declaration stubs for `@/lib/dal` and `ai`, and `src/usage.ts` calling `framesToStream(tokenFrames(tokens), request.signal)`):

```text
before, TS 5.9.3, lib ES2020:  src/usage.ts(5,87): error TS2554: Expected 1 arguments, but got 2.
before, TS 7.0.2, lib ES2020:  src/shared/utils/read-sse.ts(21,48): error TS2550: Property 'at' does not exist on type '[string, string][]'.
                               src/usage.ts(5,87): error TS2554: Expected 1 arguments, but got 2.
after, TS 5.9.3 and 7.0.2, lib ES2020 and lib ESNext: tsc --strict clean (all eight path fences plus usage.ts)
```

### FIX① assumptions

- R1-C2 drops held live events whose id the replay already sent instead of comparing ids, because the store contract types ids as
  opaque strings (Redis stream ids aren't decimal). A held event the replay didn't send was logged after the replay read, so it's newer.
- R1-C10 closes a client whose unread queue passes 1 MiB rather than dropping frames, because the feed is resumable: the client
  reconnects with `Last-Event-ID` and replays the rest. A byte-length strategy is needed, because the default `highWaterMark` of 1 would
  close the stream after one unread frame.
- R1-C11 uses the documented callback form, `after(() => cleanedUp)`. The callback's promise settles at release, so it holds whether
  Next runs the callback when the handler returns or when the body finishes (Not-confirmed item 10).
- R1-C13 treats 408 and 429 as retryable and every other 4xx as final; 5xx and network errors keep backing off.
- R1-C12 keeps one resume id, for the latest URL. Going back to an earlier room starts from its recent history, which handling by id
  (SSE-20) absorbs.
- R1-C22 stops for good on `stream-error`, and the UI offers the retry, as it already does for `'closed'`.
- R1-C14's reader is a new file because `readSse` is SSE-only; it shares `bodyReader` and `HttpStatusError` with it.
- To stay within 800 lines, the Rules and Not-confirmed sections were reflowed to one line per item instead of dropping prose.
