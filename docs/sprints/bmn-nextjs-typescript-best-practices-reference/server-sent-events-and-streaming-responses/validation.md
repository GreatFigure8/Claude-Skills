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
