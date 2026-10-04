# Plan: Server-sent events and streaming responses from Route Handlers

**Story:** [story.md](story.md) · **Owns:** `R/nextjs/sse-and-streaming.md` (prefix `SSE`) and
`Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_sse_and_streaming.py`.
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.
**Planner research date:** 2026-10-04. Every URL below was fetched live that day, as raw Markdown
(`<url>.md` on nextjs.org / vercel.com) or as HTML (MDN, WHATWG, react.dev), and read in full
for the sections cited.

## 1. Approach

1. Replace the stub `R/nextjs/sse-and-streaming.md` with a full topic file that follows the
   skeleton's **Authoring contract** exactly: H1, as-of line, then `Scope`, `Rules`, `Patterns`,
   `Anti-patterns`, `Version notes`, `Review checklist`, `Not confirmed by the docs`, `Sources`.
2. The content is the verified rule sheet in §7. It has 29 `SSE-` rules, each with an inline
   allowed-host link or `(convention)`, and the reference code in §8. The coder transcribes it.
   The coder doesn't do new research, but does re-check a page when a sentence needs one.
3. The file is grounded in what nextjs.org and vercel.com said on 2026-10-04 (Next.js 16.3.8),
   with MDN and WHATWG for the wire format and `EventSource`, and react.dev for hooks. Anything
   the docs don't confirm goes to `## Not confirmed by the docs` (§11).
4. Guidance applied:
   - stack.md routes **no build skill** (Markdown repo), and `nextjs-fullstack-standards` isn't
     loadable, so it isn't approximated.
   - The skeleton story's contract governs the format.
   - Jonathan's coding-style rules shape the examples: no `any`, explicit error handling, no
     silent catch, named constants, small functions.
   - The canonical folder layout in `R/nextjs.md` sets the example paths: `src/app/api/...`,
     `src/shared/utils`, `src/shared/hooks` and `src/lib`.
5. One new pytest file asserts the story's own criteria (§3) through `nextjs_doc_helpers`.
   It is offline, stdlib + pytest only, and ruff-clean.

## 2. Files

| File | Action | Purpose |
| --- | --- | --- |
| `R/nextjs/sse-and-streaming.md` | replace stub | The SSE and streaming topic file. At most 800 lines (budget ≈ 620). |
| `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_sse_and_streaming.py` | create | The story's topic tests (§3). |
| `docs/sprints/bmn-nextjs-typescript-best-practices-reference/server-sent-events-and-streaming-responses/evidence/sources-verified.md` | create | Lists every Sources URL with the fetch date (2026-10-04) and the rule ids it backs (§12). |
| `docs/sprints/bmn-nextjs-typescript-best-practices-reference/server-sent-events-and-streaming-responses/validation.md` | create (validation step) | Gate output and the one-off Sources-equals-evidence check. Any defect found in shared files is logged under Assumptions. |

The coder touches nothing else (AC11). In particular it never edits `nextjs.md`,
`nextjs_doc_helpers.py`, `test_nextjs_reference.py` or other topic files.

## 3. Test plan (written first; all `[unit]`, no browser)

File: `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_sse_and_streaming.py`.

**Imports and constants**

- It imports from `nextjs_doc_helpers`: `TOPICS_DIR`, `read`, `is_stub`, `section`,
  `code_blocks`, `has_block_with`, `rule_items`, `source_urls`, `as_of_version` and
  `missing_terms`. They're importable because pytest's default `prepend` import mode puts
  `assets/tests/` on `sys.path`. If the skeleton's tests use another idiom, copy it.
- Module constants:
  - `SSE_MD = TOPICS_DIR / "sse-and-streaming.md"`;
  - `TERMS`, the exact 24 terms from AC3;
  - `MIN_RULES = 15`;
  - `ANY_TYPE = re.compile(r":\s*any\b|<any>|\bas any\b|\bany\[\]")`.

**Mapping from criteria to tests**

| AC | Test name | Asserts |
| --- | --- | --- |
| 1 | (generic, skeleton) `test_nextjs_reference.py` contract tests | The skeleton's generic tests run on this file with no skip, because it is no longer a stub. Nothing to write here; validation runs the suite. |
| 1 | `test_sse_topic_uses_only_sse_rule_ids` | Every id from `rule_items(text)` matches `^SSE-\d+$`. |
| 2 | `test_sse_topic_is_no_longer_a_stub` | `is_stub(text) is False`. |
| 2 | `test_sse_topic_has_at_least_15_rules` | `len(rule_items(text)) >= MIN_RULES`. |
| 3 | `test_sse_topic_names_every_required_concept` | `missing_terms(text, TERMS) == []`. |
| 4 | `test_sse_topic_has_route_handler_example` | `has_block_with(text, "text/event-stream", "ReadableStream", "request.signal")`. |
| 4 | `test_sse_topic_has_frame_encoding_example` | `has_block_with(text, "controller.enqueue", "TextEncoder")`. |
| 4 | `test_sse_topic_has_heartbeat_cleared_example` | `has_block_with(text, "setInterval", "clearInterval")`. |
| 4 | `test_sse_topic_has_last_event_id_resume_example` | `has_block_with(text, "Last-Event-ID")`. |
| 4 | `test_sse_topic_has_client_event_source_hook_example` | `has_block_with(text, "'use client'", "EventSource", "useEffect", ".close()")`. |
| 4 | `test_sse_topic_has_fetch_reader_example` | `has_block_with(text, "getReader(")`. |
| 4 | `test_sse_examples_never_use_any` | No `ts`/`tsx` block body matches `ANY_TYPE`. |
| 5 | `test_sse_route_handler_example_releases_on_abort_and_cancel` | One block holds all of: `"export async function GET"`, `"abort"`, `"cancel("`, `"clearInterval"`, `"text/event-stream"`, `"Cache-Control"`, `"verifySession"` and `"sseEvent("`. |
| 5 | `test_sse_frame_encoder_writes_id_event_data_and_blank_line` | `has_block_with(text, "id: ", "event: ", "data: ", "\\n\\n")`. These are the literal backslash-n characters as they appear in the TS source. |
| 6 | `test_sse_rules_set_max_duration_with_vercel_link` | `section(text, "Rules")` contains `"maxDuration"` and `"https://vercel.com/"`. |
| 7 | `test_sse_rules_state_event_source_client_facts` | `## Rules` contains `"Last-Event-ID"`, `"retry:"`, `"withCredentials"` and `"getReader("`. |
| 7 | `test_sse_sources_include_mdn_or_whatwg` | `source_urls(text)` has a URL whose host is `developer.mozilla.org` or `html.spec.whatwg.org`. |
| 8 | `test_sse_version_notes_name_the_major_and_link_nextjs` | `## Version notes` is non-empty and contains `f"Next.js {major}"`, where `major = as_of_version(text).split(".")[0]`. It also contains `"https://nextjs.org/"`. |
| 9 | `test_sse_review_checklist_items_each_name_an_sse_rule` | Every line in `## Review checklist` that starts with `- [ ]` contains `SSE-`. |
| 9 | `test_sse_checklist_and_anti_patterns_cite_only_defined_rules` | Every `SSE-\d+` in `## Review checklist` and `## Anti-patterns` is an id in `rule_items(text)`. |
| 9 | `test_sse_anti_patterns_pair_every_dont_with_a_do` | In `## Anti-patterns`, the count of `**Do**` markers is at least the count of `**Don't**` markers, and that count is at least 3. Every Don't item names an `SSE-` id. |
| 10 | validation one-off (not pytest) | The `source_urls` set of the topic file equals the URL set in `evidence/sources-verified.md`. The command and its output go in `validation.md`. |
| 11 | gates | The full suite passes, ruff is clean, and `git diff --name-only` is limited to the owned paths. |

**Totals:** 20 new pytest tests in 1 new file, plus the skeleton's generic contract tests, which
now run on this file.

**Test hygiene**

- Each test reads the file through one module-level `TEXT = read(SSE_MD)`, or a cached helper.
- No function is over 50 lines, and there's no network.
- If the skeleton fixes another Don't/Do shape in its Authoring contract, mirror that shape in
  the file. Adjust the pairing test's regex to it and log the change in `validation.md`.

## 4. Data

None. There are no models, migrations or RLS. The repo is Markdown plus pytest.

## 5. Config, env vars and deploy_pending

- Env vars: none.
- Config: none in this repo. The `vercel.json`, `maxDuration` and `supportsCancellation` content
  is *documentation inside the topic file*, not repo config.
- **deploy_pending: `[]`.** There's no Vercel project, no Supabase and no app to deploy.

## 6. Risks and gates

| Risk | Mitigation |
| --- | --- |
| A factual claim drifts from the cited page. | Every rule in §7 carries the paraphrase that was checked. Reviewers spot-check the links, and anything not confirmed lives in §11. |
| Snippets aren't compiled. | §8 code was checked line by line against the cited APIs. It has no `any` (a test checks this). It avoids `TextDecoderStream` + `pipeThrough` typing and uses `TextDecoder.decode(value, { stream: true })` instead. |
| The skeleton's helper semantics differ from what's assumed here, for example `section()` stopping at H3. | No H3 goes inside `## Rules`. H3 is used only in `## Patterns` and `## Anti-patterns`. The coder reads `nextjs_doc_helpers.py` docstrings before writing the test. |
| A URL in prose is missing from Sources, or an anchored URL doesn't match. | Use **no `#anchor` URLs** anywhere in prose. Every prose URL is copied verbatim from §12. Run the set check before committing. |
| Over 800 lines. | The budget is ≈ 620 lines. Check with `wc -l`. |
| `TODO`/`TBD` text trips the hygiene check. | Never write either string, even in prose about "to be decided". |
| Relative links don't resolve. | Link only `route-handlers-and-apis.md`, `rendering-and-caching.md`, `performance-and-vercel.md` and `proxy-auth-and-security.md` (siblings that exist as stubs), plus `../nextjs.md`. |

**Gates, run in the run worktree**

```bash
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q
uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope
wc -l Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/sse-and-streaming.md   # <= 800
grep -nE 'TODO|TBD' Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/sse-and-streaming.md  # no output
git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD
# one-off AC10 check (record command + output in validation.md):
python3 - <<'EOF'
import re, sys
sys.path.insert(0, "Skills/dev-bother-me-nope/assets/tests")
from nextjs_doc_helpers import TOPICS_DIR, read, source_urls
topic = set(source_urls(read(TOPICS_DIR / "sse-and-streaming.md")))
ev = set(re.findall(r"https://[^\s|)>]+", open("docs/sprints/bmn-nextjs-typescript-best-practices-reference/server-sent-events-and-streaming-responses/evidence/sources-verified.md").read()))
print("missing from evidence:", sorted(topic - ev)); print("extra in evidence:", sorted(ev - topic))
EOF
```

UI: none. stack.md has `ui: false`, so `design.md` doesn't apply.

## 7. Verified rule sheet

The "As-of" line is copied verbatim from `R/nextjs.md` once the skeleton merges. Its expected
value is `> As of Next.js 16.3.8, verified 2026-10-04.`

How 16.3.8 was confirmed:

- npm `next` dist-tag `latest` is `16.3.8`.
- Every nextjs.org `.md` page fetched carries `version: 16.3.8` in its frontmatter.

Format for the coder: each rule below is the **exact rule text** to put in `## Rules`, written as
`N. **SSE-N** …`, with the links inline as shown. Under each rule:

- **Verified** is what the cited page says (paraphrased) and is not copied into the topic file;
- **Snippet** is code that was checked against the page.

> Short link names used below → full URL in §12. In the topic file, write full inline links
> (`[text](https://…)`), never reference-style, never with `#anchors`.

### Choosing the transport

**SSE-1** Choose SSE for one-way server-to-client updates (live feeds, job progress, AI token
streams). Choose WebSockets only when the client also pushes a continuous stream. Poll or fetch
on demand when a few seconds of staleness is acceptable ([WebSockets KB], [realtime pub/sub KB]).
On Vercel, WebSockets are in public beta on Fluid compute. Next.js needs
`experimental_upgradeWebSocket()` from `@vercel/functions` in a `GET` Route Handler
([Vercel WebSockets]). Hosts that run Route Handlers as lambda functions may not support
WebSockets at all ([BFF guide]).

- Verified:
  - WebSockets KB:
    - "Use SSE when data only flows from the server to the client". WebSockets are for when the
      client pushes continuously.
    - WebSockets have been in public beta since June 22, 2026, on all plans, and require Fluid
      compute.
    - Next.js has no built-in upgrade API, so use `experimental_upgradeWebSocket()`.
  - Pub/sub KB table:
    - "One-way AI or data streaming → SSE";
    - "Low-frequency updates → On-demand fetch or polling";
    - "Backend event fan-out → Vercel Queues";
    - "High-volume client fan-out → A managed provider".
  - Vercel WebSockets doc: "WebSockets (Beta) are available on all plans". It shows the Next.js
    route.
  - BFF guide, "Deployment environment": "WebSockets won't work because the connection closes on
    timeout, or after the response is generated" on hosts that deploy Route Handlers as lambda
    functions.
- Snippet (Vercel WebSockets doc, not reproduced as a rule example):

  ```ts
  import { experimental_upgradeWebSocket, type WebSocketData } from '@vercel/functions';
  export async function GET() { return experimental_upgradeWebSocket((ws) => { ws.on('message', (data: WebSocketData) => { ws.send(data); }); }); }
  ```

### Route Handler and response

**SSE-2** Return `new Response(stream)` from a `route.ts` handler, where `stream` is a Web
`ReadableStream` you build. Next.js documents raw streaming from Route Handlers with the Web
Streams API, "useful for Server-Sent Events" ([route.js], [Streaming guide]).

- Verified:
  - route.js "Streaming" section: the `iteratorToStream` + `new Response(stream)` example. "You
    can also use the underlying Web APIs directly."
  - Streaming guide, "Streaming in Route Handlers": "Route Handlers can stream raw responses using
    the Web Streams API. This is useful for Server-Sent Events…". Its example uses
    `start(controller)`, `controller.enqueue(encoder.encode(...))` and `controller.close()`.

**SSE-3** Set `Content-Type: text/event-stream` exactly. `EventSource` fails the connection, and
stops reconnecting, when the status isn't 200 or the type is anything else ([MDN SSE], [WHATWG SSE]).

- Verified:
  - MDN: "The server-side script that sends events needs to respond using the MIME type
    text/event-stream."
  - WHATWG processing model: "if res's status is not 200, or if res's `Content-Type` is not
    `text/event-stream`, then fail the connection". Fail means `readyState` becomes CLOSED and
    there's "no attempt to reconnect".

**SSE-4** Send `Cache-Control: no-cache, no-transform`. MDN's SSE server sends `no-cache`, and
`no-transform` tells every intermediary not to transform the body ([MDN SSE], [MDN Cache-Control])
(convention).

- Verified:
  - MDN SSE example headers: `X-Accel-Buffering: no`, `Content-Type: text/event-stream` and
    `Cache-Control: no-cache`.
  - MDN Cache-Control: "no-transform indicates that any intermediary (regardless of whether it
    implements a cache) shouldn't transform the response contents."
  - Combining both is the house rule, hence `(convention)`.

**SSE-5** Never set `Connection` or `Keep-Alive` response headers. They're prohibited in HTTP/2
and HTTP/3, and Safari won't load a response that carries them ([MDN Connection]).

- Verified (MDN Connection): "Connection-specific header fields such as Connection and Keep-Alive
  are prohibited in HTTP/2 and HTTP/3. Chrome and Firefox ignore them in HTTP/2 responses, but
  Safari … does not load any response that contains them."

**SSE-6** Authenticate and authorize before you construct the stream, and return 401/403 as a
plain response. The status and headers can't change once streaming starts, and `EventSource`
doesn't retry a non-200 answer ([Auth guide], [Streaming guide], [WHATWG SSE]). Implement the
session check as described in [route-handlers-and-apis.md](route-handlers-and-apis.md).

- Verified:
  - Auth guide, "Route Handlers": "Treat Route Handlers with the same security considerations as
    public-facing API endpoints". Its example is `verifySession()`, then 401, then 403.
  - Streaming guide, "The HTTP contract": "You cannot change the status code or headers after
    streaming starts."
  - WHATWG: see SSE-3.

**SSE-7** Authenticate `EventSource` with cookies. `withCredentials` is its only option, so it
can't send an `Authorization` header. A same-origin request sends cookies by default. A
cross-origin one needs `withCredentials: true`, plus an explicit `Access-Control-Allow-Origin` and
`Access-Control-Allow-Credentials: true` ([WHATWG SSE], [WHATWG fetching], [MDN EventSource()],
[MDN CORS]).

- Verified:
  - WHATWG IDL: `dictionary EventSourceInit { boolean withCredentials = false; }`. There are no
    other members.
  - The constructor uses corsAttributeState `Anonymous` unless `withCredentials` is true. In "create
    a potential-CORS request", Anonymous means credentials mode `"same-origin"`, and Use
    Credentials means `"include"`.
  - MDN constructor: the only option is `withCredentials`.
  - MDN CORS, "Credentialed requests and wildcards": the server "must not specify the * wildcard
    for the Access-Control-Allow-Origin" and must specify an explicit origin.
  - MDN CORS also shows `Access-Control-Allow-Credentials: true`.

**SSE-8** Keep the SSE `GET` handler request-time:

- read runtime data (`cookies()`, `headers()`, `request.headers`) or `await connection()` before
  streaming;
- never export `dynamic = 'force-static'`;
- with Cache Components on, don't wrap those reads in a `try/catch` that swallows the prerender
  bail-out.

Sources: [Route Handlers], [connection], [Migrating to Cache Components].

- Verified:
  - Route Handlers page: "Route Handlers are not cached by default. You can, however, opt into
    caching for `GET` methods … `export const dynamic = 'force-static'`."
  - Route Handlers page, "With Cache Components": GET handlers "can be prerendered when they don't
    access uncached or runtime data". Prerendering stops on `request.headers`, `cookies()`,
    `headers()`, `connection()` and similar.
  - `connection()` reference: "indicate rendering should wait for an incoming user request".
  - Migrating guide: "Reading uncached or runtime data in a `GET` handler bails out of
    prerendering by **throwing**. A `try/catch` you already have around other operations will
    catch that bail-out."
  - Route segment config v16.0.0: `dynamic`, `dynamicParams`, `revalidate` and `fetchCache` are
    removed when Cache Components is enabled. This goes in Version notes.

**SSE-9** Run SSE routes on the default Node.js runtime and don't export `runtime = 'edge'`:

- Next.js marks the Edge Runtime deprecated;
- Cache Components requires Node.js;
- Vercel's request cancellation is Node.js-only;
- Vercel recommends migrating from Edge to Node.js.

Sources: [runtime], [Edge Runtime deprecated], [cacheComponents], [Functions API reference],
[Vercel Edge runtime].

- Verified:
  - runtime page: `'edge'` is "(deprecated)". "The Edge Runtime is deprecated. Remove the
    `runtime` export from your route files."
  - Message page: "The Node.js runtime is the default, so no replacement is needed."
  - cacheComponents: "Cache Components requires the Node.js runtime."
  - Functions API reference, "Cancel requests": "This feature is only available in the Node.js
    runtime."
  - Vercel Edge runtime page: "We recommend migrating from edge to Node.js for improved
    performance and reliability."
  - On Vercel, Edge "must begin sending a response within 25 seconds … can continue streaming
    data for up to 300 seconds" (Vercel limits page). This goes in the Patterns table.

### Wire format and encoding

**SSE-10** Write each event as `id:`, `event:` and `data:` lines, each ended by LF, followed by
one blank line. Split multi-line data into one `data:` line per line. Keep CR and LF out of `id`
and `event`, and never put NULL in `id` ([WHATWG SSE], [MDN SSE]).

- Verified:
  - WHATWG ABNF: `event = *( comment / field ) end-of-line`; `any-char` excludes LF and CR.
  - WHATWG: data lines are appended with LF between them. An `id` value containing U+0000 NULL
    is ignored. "the end of the stream is not enough to trigger the dispatch of the last event"
    without a final blank line.
  - MDN: "Each notification is sent as a block of text terminated by a pair of newlines." With
    multiple `data:` lines, MDN says the client "concatenates them, inserting a newline character
    between each one".
- Snippet (wire, WHATWG/MDN form):

  ```text
  retry: 3000

  : heartbeat

  id: 42
  event: order.updated
  data: {"orderId":"o_1","status":"shipped"}

  ```

**SSE-11** Enqueue bytes, not strings. Encode every frame with one module-level `TextEncoder`, as
the Next.js examples do, or pipe a string stream through `TextEncoderStream` ([route.js],
[Streaming guide], [MDN TextEncoderStream]).

- Verified:
  - route.js: `const encoder = new TextEncoder()` at module scope, `yield encoder.encode(...)`.
  - Streaming guide: `controller.enqueue(encoder.encode(...))`.
  - MDN: `TextEncoderStream` "converts a stream of strings into bytes in the UTF-8 encoding … can
    be used in ReadableStream.pipeThrough()". It has been Baseline since September 2022.
  - WHATWG: event streams "must always be encoded as UTF-8".

**SSE-12** Send `retry: <ms>` once at the start of the stream to set the client's reconnection
delay. The value must be ASCII digits only ([WHATWG SSE], [MDN SSE]).

- Verified:
  - WHATWG: "If the field value consists of only ASCII digits, then interpret the field value as
    an integer in base ten, and set the event stream's reconnection time to that integer.
    Otherwise, ignore the field."
  - MDN `retry`: "The reconnection time … must be an integer, specifying the reconnection time in
    milliseconds."
  - A `retry:`-only block with no `data:` dispatches nothing, because the data buffer is empty.

**SSE-13** Send a comment heartbeat (`: heartbeat`) about every 15 seconds while the stream is
idle. The spec recommends it against proxies that drop idle connections, and Vercel says HTTP/1.1
clients and intermediaries may close idle long-running responses ([WHATWG SSE], [Vercel duration],
[MDN SSE]).

- Verified:
  - WHATWG authoring notes: "authors can include a comment line (one starting with a ':'
    character) every 15 seconds or so."
  - Vercel duration page note: over HTTP/2, Vercel sends PING frames while the response is idle.
    "HTTP/1.1 clients and intermediate network layers may still close idle connections. For those
    cases, stream progress or heartbeat data while work is running."
  - MDN: "The comment line can be used to prevent connections from timing out."

**SSE-14** Report a failure that happens after streaming has started as an `event: error` frame,
then close. The HTTP status can no longer change ([Streaming guide]) (convention).

- Verified: Streaming guide, "The HTTP contract": the status is committed once streaming begins.
  Using an `error` event frame is the house convention.

### Lifecycle, cancellation and limits

**SSE-15** Release every timer, subscription and upstream request in one idempotent `release()`.
Run it on `request.signal`'s `abort` event **and** in the stream's `cancel()`. Stop calling
`controller.enqueue` once released, because it throws a `TypeError` on a closed or cancelled stream
([MDN Request.signal], [MDN ReadableStream()], [MDN enqueue], [Functions API reference]).

- Verified:
  - MDN Request.signal: "returns the AbortSignal associated with the request". The example listens
    with `addEventListener("abort", …)`.
  - MDN ReadableStream(): `cancel(reason)` "will be called if the app signals that the stream is
    to be canceled … should do whatever is necessary to release access to the stream source". The
    page example clears a `setInterval` in `cancel()`.
  - MDN enqueue: "TypeError — Thrown if enqueue() is called when the stream is not readable —
    because it is already closed, canceled, or errored".
  - Functions API reference: on Vercel, with cancellation enabled, "When the client disconnects,
    the signal fires".

**SSE-16** On Vercel, opt each SSE route into `"supportsCancellation": true` in `vercel.json`, so
`request.signal` fires when the client disconnects. Put anything that must still finish in
`after()` or `waitUntil()` ([Functions API reference], [vercel.json], [after]).

- Verified:
  - Functions API reference: "Cancellation is opt-in. In your `vercel.json`, add
    `"supportsCancellation": true` to the specific paths". "Termination on disconnect applies to
    every function matching the glob … Any work not wrapped in `waitUntil` or `after` will be lost
    on cancellation."
  - vercel.json `functions` value definition lists `supportsCancellation`, "only available when
    you're using the Node.js runtime".
  - `after` page: it runs after the response is finished and can be used in Route Handlers.

**SSE-17** Pass `request.signal` to every upstream `fetch` and to the AI SDK's `abortSignal`, so a
disconnect stops upstream work too ([Functions API reference], [Cancellation changelog]).

- Verified:
  - Functions API reference: "`request.signal` is a standard `AbortSignal`. You can pass it
    directly to any API that accepts one, such as `fetch`". The example uses
    `fetch(url, { signal: request.signal })`.
  - Cancellation changelog (2025-04-23): `streamText({ …, abortSignal: req.signal })`.

**SSE-18** Bound every stream with your own timer that calls `controller.close()` a few seconds
before `maxDuration`. A cleanly ended stream makes `EventSource` reconnect with `Last-Event-ID`.
Vercel terminates a function that overruns, and that includes time spent streaming
([Vercel limits], [Vercel duration], [WHATWG SSE]) (convention).

- Verified:
  - Vercel limits, "Max duration": "For request handlers, this includes time spent processing the
    request and sending the response, including streamed responses."
  - Vercel duration: "If a function runs for longer than its set maximum duration, Vercel will
    terminate it."
  - WHATWG: at the end of the response body, if "res is not a network error, then reestablish the
    connection"; the reconnect request sets `Last-Event-ID`.
  - Ending early by the stream's own timer is the convention.

**SSE-19** Produce data in `pull()` when the source can wait (async iterators, LLM tokens, paged
queries). The stream then asks for more only as the consumer reads, which is backpressure. For
push sources, check `controller.desiredSize` before enqueueing; zero or negative means the queue
is full ([Vercel backpressure], [MDN ReadableStream()], [MDN desiredSize]).

- Verified:
  - Vercel KB: backpressure is handled "by pushing data into a stream as it's needed, rather than
    as it's ready", using a `pull` handler.
  - MDN ReadableStream(): `pull` "will be called repeatedly when the stream's internal queue of
    chunks is not full, up until it reaches its high water mark". The default strategy is a
    high-water mark of 1.
  - MDN desiredSize: "can be negative if the queue is over-full". The value is `0` when closed and
    `null` when errored.
  - MDN AsyncGenerator.return() "allows the generator to perform any cleanup tasks when combined
    with a try...finally block". This is used in `cancel()` in §8.4.

**SSE-20** Give every event a monotonic `id:` and resume from it:

- read `Last-Event-ID`, which `EventSource` sends on automatic reconnects;
- fall back to a `lastEventId` query parameter, because a brand-new `EventSource` starts with an
  empty last event ID;
- replay newer events from a durable log;
- make client handling idempotent by id.

Sources: [WHATWG SSE], [Realtime pub/sub KB].

- Verified:
  - WHATWG: the last event ID string "must initially be the empty string". `Last-Event-ID` is set
    only in "reestablish the connection".
  - WHATWG authoring note: "include a unique identifier … pass that identifier as part of the URL
    when the connection is established".
  - Pub/sub KB: "browsers reconnect on their own and send a `Last-Event-ID` header that your server
    can resume from". Its table: SSE needs "Resumability only".
  - Dedupe by id is the convention, because the route subscribes before it replays (§8.3).

**SSE-21** Keep subscriptions and history in an external store, for example Redis from the Vercel
Marketplace, never in module-level variables. Share one upstream subscription per function
instance rather than one per client. Route Handlers can't share data between requests, and
instances don't share memory ([BFF guide], [Realtime pub/sub KB], [Vercel WebSockets],
[Vercel limits]).

- Verified:
  - BFF guide: "Route Handlers cannot share data between requests."
  - Pub/sub KB: "Module-level variables look correct in local development … but break as soon as
    production traffic spans two instances." It also says "Run one blocking `XREAD` per instance
    on a duplicated connection".
  - Vercel WebSockets doc: store "pub/sub coordination in an external data store instead of
    relying on in-memory variables".
  - Vercel limits: there are 1,024 file descriptors "shared across all concurrent executions",
    and these include network connections.

**SSE-22** Export `maxDuration` from the SSE route file and keep it within your plan's maximum.
With Fluid compute that's 300 s on Hobby and 800 s on Pro and Enterprise (1800 s extended, beta).
See the table in Patterns ([maxDuration], [Vercel duration], [Vercel limits], [Fluid compute]).

- Verified:
  - Next.js maxDuration: "`export const maxDuration = 5`"; "Deployment platforms can use
    `maxDuration` from the Next.js build output".
  - Vercel duration: "the Next.js app router uses a named maxDuration export".
  - Vercel duration, Duration limits table (Fluid, enabled by default):

    | Plan | Default | Maximum | Extended |
    | --- | --- | --- | --- |
    | Hobby | 300s | 300s | - |
    | Pro | 300s | 800s | 1800s Beta |
    | Enterprise | 300s | 800s | 1800s Beta |

  - Above 800 s must be set per function, in code or `vercel.json`, on the runtimes `nodejs20.x`,
    `nodejs22.x` and `nodejs24.x`, Bun, and Python 3.12–3.14. Secure Compute and Static IPs don't
    support it.
  - Fluid compute page: precedence is function code first, then `vercel.json`, then the
    dashboard, then Fluid defaults.

### Client

**SSE-23** Design every client to reconnect:

- `EventSource` reconnects on its own after the `retry:` delay and sends `Last-Event-ID`;
- a `fetch` reader must reconnect itself, with backoff, and send the last id it saw.

Sources: [MDN SSE], [WHATWG SSE], [WebSockets KB].

- Verified:
  - MDN: "By default, if the connection between the client and server closes, the connection is
    restarted."
  - WHATWG "reestablish the connection": it waits the reconnection time and sets `Last-Event-ID`.
    User agents "might introduce an exponential backoff".
  - WebSockets KB: "SSE streams are still bounded by the function's maximum duration, but the
    browser handles reconnection for you." Its reconnect client backs off from 1 s, doubling to
    30 s.

**SSE-24** Open `EventSource` in a Client Component's `useEffect` and return
`() => source.close()`. Read callbacks through `useEffectEvent`, so new props don't reconnect.
Expect two things:

- in Strict Mode, an extra connect and close during development only;
- a close and reopen when Cache Components hides a route with `<Activity>`.

Sources: [useEffect], [useEffectEvent], [Preserving UI state], [Migrating to Cache Components].

- Verified:
  - react.dev useEffect: setup "may also optionally return a cleanup function". "When Strict Mode
    is on, React will run one extra development-only setup+cleanup cycle." Its chat example does
    connect, then returns disconnect.
  - react.dev useEffectEvent: it's called at the top level of a component or your own Hook. Effect
    Events are called from Effects. Its example passes one to a connection's `on('connected', …)`.
    It is not listed as a dependency.
  - Preserving UI state: "Instead of unmounting pages on navigation, Next.js hides them using
    React's `<Activity>`".
  - Migrating guide: "Effects clean up and re-run normally" across navigations with Cache
    Components.
  - Upgrade guide (v16): the App Router uses React 19.2, including `useEffectEvent` and `Activity`.

**SSE-25** Listen for named events with `addEventListener(name, …)`, because `onmessage` only
receives events without `event:`. Validate each `data` payload before use ([MDN SSE],
[MDN EventSource]).

- Verified: MDN: "Messages sent from the server that don't have an event field are received as
  message events"; for named events, "use addEventListener() to listen for named events. The
  onmessage handler is called if no event name is specified".

**SSE-26** Share one `EventSource` per stream URL per tab, for example through a provider in a
shared layout. Over HTTP/1.1, browsers allow only 6 connections per browser and domain
([MDN SSE], [WHATWG SSE]).

- Verified:
  - MDN warning: "When not used over HTTP/2, SSE suffers from a limitation to the maximum number of
    open connections … (6) … per browser + domain".
  - WHATWG authoring notes: avoid this by "sharing a single EventSource object using a shared
    worker", among other options.

**SSE-27** Use `fetch` plus `response.body.getReader()` when you need POST, a request body or
custom headers, because `EventSource` can only GET, with `withCredentials` as its one option.
Decode with `TextDecoder` and `{ stream: true }`, and split frames on blank lines ([WHATWG SSE],
[MDN reader.read()], [MDN TextDecoder.decode()]).

- Verified:
  - WHATWG IDL: the constructor is `(url, EventSourceInit)` and EventSourceInit only has
    `withCredentials`.
  - MDN read(): the promise is fulfilled with `{ value, done: false }`, or `{ value: undefined,
    done: true }` when closed. The example uses `response.body.getReader()`.
  - MDN TextDecoder.decode(): `stream` is "a boolean flag indicating whether additional data will
    follow in subsequent calls … Set to true if processing the data in chunks".

**SSE-28** End a stream for good by calling `source.close()` on the client, or by answering the
reconnect with `204 No Content`. A server-side `controller.close()` on its own only triggers a
reconnect ([WHATWG SSE], [MDN SSE]).

- Verified:
  - WHATWG intro: "a client can be told to stop reconnecting using the HTTP 204 No Content response
    code". `close()` sets `readyState` to CLOSED and aborts the fetch.
  - MDN: "The connection is terminated with the .close() method."
  - The end-of-body reconnect is covered under SSE-18.

### AI streaming

**SSE-29** Stream LLM output with the AI SDK, as Vercel recommends. Forward `request.signal` as
`abortSignal`, export `maxDuration`, and read the response with `fetch` + `getReader()`, not
`EventSource`, because chat routes take a `POST` body ([Vercel streaming], [Cancellation
changelog], [AI Gateway + AI SDK KB]).

- Verified:
  - Vercel streaming: "Vercel recommends using Vercel's AI SDK to stream responses from LLMs".
  - Its example (last_updated 2026-09-01) is
    `streamText({ model: 'openai/gpt-4o-mini', messages })` followed by
    `response.toTextStreamResponse({ headers: { 'Content-Type': 'text/event-stream' } })`.
  - The same page: "Maximum durations can be configured for Node.js functions to enable streaming
    responses for longer periods."
  - Changelog: `streamText({ model, prompt, abortSignal: req.signal })` →
    `result.toTextStreamResponse()`.
  - The AI Gateway KB (AI SDK 7, 2026-09-23) shows a `POST` route returning
    `createUIMessageStreamResponse({ stream: toUIMessageStream({ stream: result.stream }) })`.
  - So the API names differ by AI SDK major. The topic file says so and sends readers to the
    SDK docs for their installed major, written as plain text with no URL. See §11 item 7.

## 8. Reference implementation

These are checked line by line against the pages in §7. Paths follow the canonical layout in
`R/nextjs.md`. `@/` is `src/`.

The topic file shows them in `## Patterns` under these H3s, in order:

1. Wire format (the `text` block in SSE-10).
2. Frame encoder (§8.1).
3. Store contract (§8.2).
4. The SSE Route Handler (§8.3).
5. Pull-based generated streams (§8.4).
6. Vercel configuration and limits (§8.5).
7. Client hook (§8.6).
8. fetch reader for POST (§8.7).
9. AI SDK on Vercel (§8.8).

Put one sentence of context above each block, citing its rules. Directly above the route block,
write: "Auth: `verifySession()` follows [route-handlers-and-apis.md](route-handlers-and-apis.md).
'Complete' means this file plus the encoder it imports."

### 8.1 Frame encoder: `src/shared/utils/sse.ts` (SSE-10, SSE-12, SSE-13)

```ts
// src/shared/utils/sse.ts — encode frames in the WHATWG event-stream format
export type SseEvent = { data: string; event?: string; id?: string }

const LINE_BREAK = /\r\n|\r|\n/
const NOT_ALLOWED_IN_FIELD = /[\r\n\0]/

function assertSingleLine(label: string, value: string): void {
  if (NOT_ALLOWED_IN_FIELD.test(value)) {
    throw new Error(`SSE ${label} must be one line without NULL`)
  }
}

export function sseEvent({ data, event, id }: SseEvent): string {
  if (id !== undefined) assertSingleLine('id', id)
  if (event !== undefined) assertSingleLine('event', event)
  const lines = [
    ...(id === undefined ? [] : [`id: ${id}`]),
    ...(event === undefined ? [] : [`event: ${event}`]),
    ...data.split(LINE_BREAK).map((line) => `data: ${line}`),
  ]
  return `${lines.join('\n')}\n\n`
}

export function sseRetry(milliseconds: number): string {
  if (!Number.isInteger(milliseconds) || milliseconds < 0) {
    throw new RangeError('SSE retry must be a non-negative integer')
  }
  return `retry: ${milliseconds}\n\n`
}

export function sseComment(text: string): string {
  assertSingleLine('comment', text)
  return `: ${text}\n\n`
}
```

### 8.2 Store contract: `src/lib/realtime.ts` (SSE-20, SSE-21)

```ts
// src/lib/realtime.ts — contract only; back it with an external store such as Redis
export type FeedEvent = { id: string; type: string; payload: unknown }

/** Subscribe to live events; resolves to an unsubscribe function. One upstream subscription per instance. */
export declare function subscribe(
  userId: string,
  onEvent: (event: FeedEvent) => void,
): Promise<() => Promise<void>>

/** Events newer than `lastEventId` from the durable log (all recent events when it is null). */
export declare function replaySince(userId: string, lastEventId: string | null): Promise<FeedEvent[]>
```

### 8.3 The SSE Route Handler: `src/app/api/events/route.ts` (SSE-2…SSE-9, SSE-11…SSE-13, SSE-15, SSE-18, SSE-20, SSE-22)

```ts
// src/app/api/events/route.ts
import { verifySession } from '@/lib/auth' // returns { userId } | null — see route-handlers-and-apis.md
import { replaySince, subscribe, type FeedEvent } from '@/lib/realtime'
import { sseComment, sseEvent, sseRetry } from '@/shared/utils/sse'

export const maxDuration = 300 // seconds; never above your plan's maximum

const HEARTBEAT_MS = 15_000
const RETRY_MS = 3_000
const END_EARLY_MS = 10_000
const encoder = new TextEncoder()

export async function GET(request: Request): Promise<Response> {
  const session = await verifySession() // reads cookies(): request-time, never prerendered
  if (!session) return new Response(null, { status: 401 })

  const lastEventId =
    request.headers.get('Last-Event-ID') ?? new URL(request.url).searchParams.get('lastEventId')

  let isReleased = false
  let heartbeat: ReturnType<typeof setInterval> | undefined
  let deadline: ReturnType<typeof setTimeout> | undefined
  let unsubscribe: (() => Promise<void>) | undefined

  const release = (): void => {
    if (isReleased) return
    isReleased = true
    clearInterval(heartbeat)
    clearTimeout(deadline)
    request.signal.removeEventListener('abort', release)
    unsubscribe?.().catch((error: unknown) => console.error('SSE unsubscribe failed', error))
  }

  const stream = new ReadableStream<Uint8Array>({
    async start(controller) {
      const send = (chunk: string): void => {
        if (!isReleased) controller.enqueue(encoder.encode(chunk))
      }
      const write = (event: FeedEvent): void =>
        send(sseEvent({ id: event.id, event: event.type, data: JSON.stringify(event.payload) }))

      request.signal.addEventListener('abort', release, { once: true })
      if (request.signal.aborted) {
        release()
        controller.close()
        return
      }
      send(sseRetry(RETRY_MS))
      heartbeat = setInterval(() => send(sseComment('heartbeat')), HEARTBEAT_MS)
      deadline = setTimeout(() => {
        release()
        controller.close() // clean end: EventSource reconnects with Last-Event-ID
      }, maxDuration * 1_000 - END_EARLY_MS)

      const stop = await subscribe(session.userId, write) // subscribe first: no gap before replay
      if (isReleased) {
        await stop() // the client left while we were subscribing
        return
      }
      unsubscribe = stop
      for (const event of await replaySince(session.userId, lastEventId)) write(event)
    },
    cancel() {
      release()
    },
  })

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      'X-Accel-Buffering': 'no', // nginx-style proxies when self-hosting
    },
  })
}
```

Line-by-line checks:

- `new Response(stream, { headers })` uses the Web `Response` (route.js).
- `ReadableStream` with `start` and `cancel` follows MDN ReadableStream().
- `controller.enqueue(encoder.encode(...))` matches the Streaming guide.
- `request.signal` plus `'abort'` follows MDN and the Vercel Functions API reference.
- `request.headers.get` is case-insensitive under the Fetch spec. The canonical spelling
  `Last-Event-ID` is kept for the test needle.
- `new URL(request.url).searchParams` is standard Web URL.
- `export const maxDuration` matches Next.js maxDuration and the Vercel duration page.
- There's no `runtime` export (SSE-9) and no `dynamic` export (SSE-8).
- `verifySession` returning `null` leads to 401, per the auth guide.
- `X-Accel-Buffering: no` comes from the Next.js self-hosting guide and the MDN example.
- `JSON.stringify` escapes newlines, so `data` stays on one line. The encoder also splits on any
  line break.

### 8.4 Pull-based streams for generated data: `src/shared/utils/sse-stream.ts` (SSE-11, SSE-19)

```ts
// src/shared/utils/sse-stream.ts — produce the next frame only when the consumer pulls
import { sseEvent } from '@/shared/utils/sse'

const encoder = new TextEncoder()

export function framesToStream(frames: AsyncGenerator<string, void>): ReadableStream<Uint8Array> {
  return new ReadableStream<Uint8Array>({
    async pull(controller) {
      const { value, done } = await frames.next()
      if (done) {
        controller.close()
      } else {
        controller.enqueue(encoder.encode(value))
      }
    },
    async cancel() {
      await frames.return() // runs the generator's finally blocks
    },
  })
}

export async function* tokenFrames(tokens: AsyncIterable<string>): AsyncGenerator<string, void> {
  let index = 0
  for await (const token of tokens) {
    yield sseEvent({ id: String(index), event: 'token', data: token })
    index += 1
  }
  yield sseEvent({ event: 'done', data: '' })
}
```

This is the typed form of route.js's `iteratorToStream`. That docs example uses `iterator: any`,
which our file must not copy, and the topic file says so in one line.

### 8.5 Vercel configuration and limits (SSE-16, SSE-22)

Put a `json` block, then the limits table.

```json
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "functions": {
    "app/api/events/**/*": { "supportsCancellation": true },
    "app/api/chat/**/*": { "supportsCancellation": true }
  }
}
```

Add a sentence: "Keys are globs over function source paths. vercel.com shows `app/api/**/*` for
the App Router. For a `src/app` layout, see Not confirmed by the docs." The `$schema` URL sits
inside a code fence, so the prose-URL rule exempts it.

Limits table. Write it with these exact values and the link on each row group:

| Setup on Vercel (verified 2026-10-04) | Default | Maximum |
| --- | --- | --- |
| Fluid compute (on by default for projects created from April 23, 2025), Hobby | 300s | 300s |
| Fluid compute, Pro | 300s | 800s; 1800s extended max (beta, per function, supported Node.js/Bun/Python) |
| Fluid compute, Enterprise | 300s | 800s; 1800s extended max (beta) |
| Not using Fluid compute (existing project deployed before April 23, 2025), Hobby | 10s | 60s |
| Not using Fluid compute, Pro | 15s | 300s |
| Not using Fluid compute, Enterprise | 15s | 900s |
| Edge runtime (deprecated in Next.js) | must begin the response within 25 s | may stream up to 300 s |

The rows come from these pages:

- the Fluid rows from [Vercel duration], [Vercel limits] and [Fluid compute];
- the non-Fluid rows from [Vercel limits overview] (`https://vercel.com/docs/limits`);
- the Edge row from [Vercel limits].

Add underneath:

- Streaming support: "Vercel supports streaming natively" ([Streaming guide]). Vercel's
  streaming page says maximum durations "can be configured for Node.js functions to enable
  streaming responses for longer periods" ([Vercel streaming]).
- When the limit is hit: Vercel terminates the function, and the limit includes streamed
  responses. A function that doesn't complete in time returns 504 `FUNCTION_INVOCATION_TIMEOUT`
  ([Vercel limits], [504 page]). SSE streams are bounded by max duration, "but the browser handles
  reconnection for you" ([WebSockets KB]).
- Cost: on Fluid compute, an idle connection bills Provisioned Memory but not Active CPU
  ([Realtime pub/sub KB]).

### 8.6 Client hook: `src/shared/hooks/use-event-source.ts` (SSE-20, SSE-23…SSE-26)

```ts
'use client'

import { useEffect, useEffectEvent, useRef, useState } from 'react'

export type StreamStatus = 'connecting' | 'open' | 'closed'

type Options<T> = {
  url: string
  eventName: string
  parse: (data: string) => T // validate here: JSON.parse + your schema; throw on bad input
  onEvent: (value: T, eventId: string) => void // idempotent by eventId
}

export function useEventSource<T>({ url, eventName, parse, onEvent }: Options<T>): StreamStatus {
  const [status, setStatus] = useState<StreamStatus>('connecting')
  const lastIdRef = useRef<string | null>(null)

  const handleMessage = useEffectEvent((message: MessageEvent<string>) => {
    try {
      onEvent(parse(message.data), message.lastEventId)
      lastIdRef.current = message.lastEventId || lastIdRef.current
    } catch (error: unknown) {
      console.error(`Rejected "${eventName}" event`, error)
    }
  })

  useEffect(() => {
    // A new EventSource sends no Last-Event-ID, so resume through the query string.
    const target = new URL(url, window.location.href)
    if (lastIdRef.current) target.searchParams.set('lastEventId', lastIdRef.current)
    const source = new EventSource(target)
    source.addEventListener('open', () => setStatus('open'))
    source.addEventListener('error', () => {
      setStatus(source.readyState === EventSource.CLOSED ? 'closed' : 'connecting')
    })
    source.addEventListener(eventName, handleMessage)
    return () => source.close()
  }, [url, eventName])

  return status
}
```

Checks:

- `new EventSource(string | URL)` matches lib.dom typing and WHATWG `USVString url`.
- `'closed'` means a failed connection: non-200, wrong type, or a fatal error. The UI can offer
  to retry or to sign in again, per WHATWG "fail the connection".
- There's no synchronous `setState` in the effect body, which keeps it clear of the React hooks
  lint rule. The status updates only from events.
- `useEffectEvent` is not in the dependency list (react.dev).

### 8.7 fetch reader for POST: `src/shared/utils/read-sse.ts` (SSE-23, SSE-27)

```ts
// src/shared/utils/read-sse.ts — POST, request body or custom headers: fetch + getReader()
export type SseMessage = { event: string; data: string; id: string | undefined }

function parseBlock(block: string): SseMessage | null {
  const fields = block
    .split('\n') // our encoder emits LF only
    .filter((line) => line !== '' && !line.startsWith(':'))
    .map((line): [string, string] => {
      const colon = line.indexOf(':')
      if (colon === -1) return [line, '']
      const value = line.slice(colon + 1)
      return [line.slice(0, colon), value.startsWith(' ') ? value.slice(1) : value]
    })
  const data = fields.filter(([name]) => name === 'data').map(([, value]) => value)
  if (data.length === 0) return null
  const last = (name: string): string | undefined =>
    fields.filter(([field]) => field === name).at(-1)?.[1]
  return { event: last('event') || 'message', data: data.join('\n'), id: last('id') }
}

export async function readSse(
  response: Response,
  onMessage: (message: SseMessage) => void,
): Promise<void> {
  if (!response.ok || !response.body) throw new Error(`SSE request failed: ${response.status}`)
  const reader = response.body.getReader()
  const decoder = new TextDecoder()
  let buffer = ''
  for (;;) {
    const { value, done } = await reader.read()
    if (done) return
    const blocks = (buffer + decoder.decode(value, { stream: true })).split('\n\n')
    buffer = blocks.pop() ?? ''
    for (const block of blocks) {
      const message = parseBlock(block)
      if (message) onMessage(message)
    }
  }
}
```

Usage, a short `tsx` block in the same subsection:

```tsx
'use client'

import { useEffect, useRef } from 'react'
import { readSse } from '@/shared/utils/read-sse'

export function useChatStream(onToken: (token: string) => void) {
  const controllerRef = useRef<AbortController | null>(null)
  useEffect(() => () => controllerRef.current?.abort(), [])

  return async function ask(prompt: string): Promise<void> {
    controllerRef.current?.abort()
    const controller = new AbortController()
    controllerRef.current = controller
    try {
      const response = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt }),
        signal: controller.signal,
      })
      await readSse(response, (message) => {
        if (message.event === 'token') onToken(message.data)
      })
    } catch (error: unknown) {
      if (error instanceof DOMException && error.name === 'AbortError') return // user stopped
      throw error
    }
  }
}
```

Checks:

- `parseBlock` mirrors the WHATWG field rules: comment lines are ignored, one leading space is
  stripped, data lines are joined with LF, the type defaults to `message`, and a block with no
  data dispatches nothing.
- `.at()` needs lib ES2022. The Next.js default tsconfig `lib` includes `esnext`. That claim lives
  in typescript.md, so it isn't stated as a rule here.

### 8.8 AI SDK on Vercel: `src/app/api/chat/route.ts` (SSE-17, SSE-22, SSE-29)

```ts
// src/app/api/chat/route.ts — API names as vercel.com shows them (match your installed `ai` major)
import { streamText } from 'ai'
import { verifySession } from '@/lib/auth'

export const maxDuration = 300

function readPrompt(body: unknown): string | null {
  if (typeof body !== 'object' || body === null || !('prompt' in body)) return null
  return typeof body.prompt === 'string' && body.prompt.length > 0 ? body.prompt : null
}

export async function POST(request: Request): Promise<Response> {
  if (!(await verifySession())) return new Response(null, { status: 401 })
  const prompt = readPrompt(await request.json().catch(() => null))
  if (prompt === null) return Response.json({ error: 'prompt is required' }, { status: 400 })

  const result = streamText({
    model: 'openai/gpt-4o-mini',
    prompt,
    abortSignal: request.signal, // stop generating when the client disconnects
  })
  return result.toTextStreamResponse()
}
```

Checks:

- The model string and `toTextStreamResponse()` come from Vercel streaming.
- `prompt` and `abortSignal: req.signal` come from the Vercel cancellation changelog.
- The `'prompt' in body` narrowing is TypeScript `in` narrowing.
- Fuller validation (zod) lives in route-handlers-and-apis.md.
- Note under the block: a text stream is plain text chunks, so read it with §8.7's reader and use
  the raw bytes. Don't use `EventSource`, because the route takes POST. See §11 item 7 on
  `text/event-stream` labelling.

## 9. Topic file outline and line budget

| Section | Content | ≈ lines |
| --- | --- | --- |
| H1 `# Server-sent events and streaming responses` + as-of line | — | 3 |
| `## Scope` | Covers SSE and raw streaming from Route Handlers, client consumption, and Vercel streaming limits. Points elsewhere: streaming HTML/Suspense → [rendering-and-caching.md](rendering-and-caching.md); validation, auth and error shape → [route-handlers-and-apis.md](route-handlers-and-apis.md); general function config → [performance-and-vercel.md](performance-and-vercel.md); Proxy auth → [proxy-auth-and-security.md](proxy-auth-and-security.md). Entry point: [../nextjs.md](../nextjs.md). | 12 |
| `## Rules` | SSE-1…SSE-29 from §7, numbered `1.`…`29.`, rule text only (no "Verified" notes). No H3 inside. | 150 |
| `## Patterns` | H3s per §8 with code and the limits table. | 300 |
| `## Anti-patterns` | 6 items (§10). | 95 |
| `## Version notes` | §10b. | 25 |
| `## Review checklist` | 15 items (§10c). | 17 |
| `## Not confirmed by the docs` | §11. | 30 |
| `## Sources` | §12, one bullet per URL. | 52 |
| **Total** | | **≈ 685** |

At most 800 lines, so trim prose before code if it's over.

## 10. Anti-patterns, Version notes and Review checklist content

### 10a. Anti-patterns

Shape for each item (unless the skeleton fixed another):

```
- **Don't** <what> (SSE-n).
  ```ts
  <bad code>
  ```
  **Do** <what instead>.
  ```ts
  <good code, 3–8 lines>
  ```
```

1. **Don't** start a heartbeat or subscription with no release path (SSE-15).
   - Bad: `start(controller) { setInterval(() => controller.enqueue(ping), 15_000) }` with no
     `cancel` and no abort listener.
   - **Do:** one `release()` from both `request.signal` `abort` and `cancel()`. Show the 6-line
     core from §8.3.
2. **Don't** fan out through a module-level `Set<(e: FeedEvent) => void>` (SSE-21).
   - Bad: `const listeners = new Set<...>()` exported, with a POST handler that loops over it.
   - **Do:** `await subscribe(userId, write)` against the external store from §8.2.
3. **Don't** export `runtime = 'edge'` or send `Connection: keep-alive` (SSE-5, SSE-9).
   - **Do:** omit `runtime` and send only the three headers from §8.3.
4. **Don't** pass headers to `EventSource` or put a bearer token in its URL (SSE-7).
   - Bad: `new EventSource('/api/events', { headers: { Authorization: `Bearer ${token}` } })`.
     TypeScript rejects it, because `EventSourceInit` only has `withCredentials`.
   - The token-in-URL half is `(convention)`: URLs land in logs.
   - **Do:** same-origin `new EventSource('/api/events')` with the session cookie.
     Cross-origin: `{ withCredentials: true }` plus explicit CORS headers.
5. **Don't** open `EventSource` during render or without cleanup (SSE-24).
   - Bad: `const source = new EventSource(url)` in a component body.
   - **Do:** `useEffect(() => { const source = new EventSource(url); …; return () => source.close() }, [url])`.
6. **Don't** decide the status after the stream has started, or throw mid-stream (SSE-6, SSE-14).
   - Bad: `return new Response(stream)` first, then `if (!session) controller.error(...)`.
   - **Do:** `if (!session) return new Response(null, { status: 401 })` before building the
     stream, plus `send(sseEvent({ event: 'error', data: JSON.stringify({ message }) }))` and then
     `controller.close()` for later failures.

### 10b. Version notes

The section names **Next.js 16** (from `16.3.8`). Each bullet carries its link:

- **Route Handler streaming is unchanged in 16.** route.js version history has no 16.x entry. The
  latest are v15.0.0-RC: `GET` default changed from static to dynamic, and `context.params` became
  a promise. The v16 upgrade guide lists no Route Handler streaming change ([route.js], [Upgrade
  guide 16]).
- **Cache Components (new in 16).** "All dynamic code in any page, layout, or API route is
  executed at request time by default" ([Next.js 16 blog]). With it on, `GET` handlers can be
  prerendered when they read no runtime data ([Route Handlers]). `dynamic`, `dynamicParams`,
  `revalidate` and `fetchCache` are removed (v16.0.0, [Route segment config]) → SSE-8.
- **Edge Runtime deprecated.** The 16.3.8 docs mark `runtime = 'edge'` deprecated ([runtime],
  [Edge Runtime deprecated]). `proxy` doesn't support Edge ([Upgrade guide 16]) → SSE-9.
- **React 19.2 in the App Router.** `useEffectEvent` and `<Activity>` arrive ([Upgrade guide 16]).
  With Cache Components, routes are hidden with Activity, so Effects clean up and re-run on
  navigation ([Migrating to Cache Components]) → SSE-24.
- **Docs drift to watch.** route.js's AI SDK snippet still shows `StreamingTextResponse` and
  `toAIStream()`. vercel.com shows `streamText(...).toTextStreamResponse()` and, for AI SDK 7,
  `createUIMessageStreamResponse` ([route.js], [Vercel streaming], [AI Gateway + AI SDK KB]) →
  SSE-29.
- **Vercel (platform, not versioned with Next.js).**
  - Fluid compute has been on by default for new projects since April 23, 2025 ([Fluid compute]).
  - Durations are in the §8.5 table.
  - Per-path request cancellation was announced on September 26, 2025 ([Per-path cancellation
    changelog]).
  - WebSockets entered public beta on June 22, 2026 ([WebSockets KB]).

### 10c. Review checklist

Each item names its rules:

- [ ] Auth runs before the stream exists and failures return 401/403 (SSE-6, SSE-7).
- [ ] Headers: exactly `text/event-stream`, `Cache-Control: no-cache, no-transform`, no `Connection`/`Keep-Alive` (SSE-3, SSE-4, SSE-5).
- [ ] No `runtime = 'edge'`, no `force-static`; the handler reads runtime data (SSE-8, SSE-9).
- [ ] Frames: `id:`/`event:`/`data:` lines plus a blank line; single-line ids and event names; bytes via `TextEncoder` (SSE-10, SSE-11).
- [ ] `retry:` sent once; heartbeat comment every ~15 s (SSE-12, SSE-13).
- [ ] Mid-stream failures go out as `event: error` frames (SSE-14).
- [ ] One idempotent `release()` from `abort` and `cancel()`; no `enqueue` after release (SSE-15).
- [ ] On Vercel, `supportsCancellation` is set; must-finish work is in `after`/`waitUntil` (SSE-16).
- [ ] `request.signal` is forwarded to upstream `fetch` / `abortSignal` (SSE-17, SSE-29).
- [ ] `maxDuration` is exported within the plan maximum; the stream closes itself before it (SSE-18, SSE-22).
- [ ] Pausable producers use `pull()`; push sources respect `desiredSize` (SSE-19).
- [ ] Every event has an id; the server resumes from `Last-Event-ID` or `lastEventId` (SSE-20).
- [ ] No module-level pub/sub; one upstream subscription per instance (SSE-21).
- [ ] Client: `EventSource` in `useEffect` with `close()` cleanup, named listeners, validated payloads, one source per URL per tab (SSE-24, SSE-25, SSE-26).
- [ ] POST or custom-header streams use `fetch` + `getReader()` with an `AbortController` and reconnect logic (SSE-23, SSE-27, SSE-28).

## 11. Not confirmed by the docs (content for that section; each item lists the URLs checked)

1. **Next.js self-hosted disconnects.** Neither nextjs.org page says whether `request.signal`
   aborts, or whether Next.js calls the response stream's `cancel()`, when the client disconnects
   under `next start` or `next dev`. Checked: [route.js], [Route Handlers], [Streaming guide],
   [Self-hosting]. vercel.com documents the abort only on Vercel with `supportsCancellation`
   ([Functions API reference]). So SSE-15 wires both hooks, and SSE-18's deadline bounds a missed
   disconnect.
2. **What the client sees at max duration.** No page says what arrives when Vercel ends a stream
   that already sent 200: a dropped connection, or bytes. The 504 is documented for functions that
   "don't complete" ([Vercel limits], [504 page], [Vercel duration]).
3. **`maxDuration` under `next start`.** The page only says "deployment platforms can use" it
   ([maxDuration]).
4. **Built-in gzip buffering.** It isn't stated whether Next.js's built-in gzip (`compress`)
   buffers `text/event-stream` under `next start`. The docs only say compression "can buffer
   chunks" ([compress], [Streaming guide]).
5. **`charset` on the Content-Type.** It's unconfirmed whether
   `Content-Type: text/event-stream; charset=utf-8` passes `EventSource`'s type check. The spec
   text compares against `text/event-stream`, so the examples use the bare value ([WHATWG SSE]).
6. **`no-transform` on Vercel's CDN.** No page says what it changes there ([Vercel streaming],
   [MDN Cache-Control]).
7. **The AI text stream body.** vercel.com's example labels `toTextStreamResponse()`
   `text/event-stream`, but no allowed page says the body is SSE-framed. route.js still shows
   `StreamingTextResponse`. Which API matches a given `ai` major isn't confirmed on an allowed
   host ([Vercel streaming], [route.js], [AI Gateway + AI SDK KB]). That's why SSE-29 reads the
   response with `fetch`.
8. **`vercel.json` keys for a `src/app` layout.** vercel.com shows `app/api/**/*` for the App
   Router and `src/pages/**/*` for Pages, but no `src/app` key ([vercel.json], [Vercel duration]).
9. **When Edge was deprecated.** No version-history row says which Next.js 16.x minor deprecated
   the Edge Runtime ([runtime], [Route segment config], [Edge Runtime deprecated]).
10. **`after()` and streams.** It isn't stated whether an `after()` callback runs when a streamed
    body finishes or when the handler returns. The page says "after the response … is finished"
    ([after]).

## 12. Sources (exact URLs for `## Sources` and the evidence file)

All were fetched live on 2026-10-04. "Rules" means the SSE rule ids the URL backs, plus the
sections it supports. Use exactly these URLs, with no anchors.

| Short name | URL | Rules |
| --- | --- | --- |
| route.js | https://nextjs.org/docs/app/api-reference/file-conventions/route | 2, 11, 19, 29; Version notes; NC 1, 7 |
| Route Handlers | https://nextjs.org/docs/app/getting-started/route-handlers | 8; Version notes; NC 1 |
| Streaming guide | https://nextjs.org/docs/app/guides/streaming | 2, 6, 11, 14; Patterns; NC 1, 4 |
| Self-hosting | https://nextjs.org/docs/app/guides/self-hosting | Patterns (X-Accel-Buffering); NC 1 |
| BFF guide | https://nextjs.org/docs/app/guides/backend-for-frontend | 1, 21 |
| Auth guide | https://nextjs.org/docs/app/guides/authentication | 6 |
| Route segment config | https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config | Version notes; NC 9 |
| runtime | https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/runtime | 9; NC 9 |
| maxDuration | https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/maxDuration | 22; NC 3 |
| connection | https://nextjs.org/docs/app/api-reference/functions/connection | 8 |
| cacheComponents | https://nextjs.org/docs/app/api-reference/config/next-config-js/cacheComponents | 9 |
| Migrating to Cache Components | https://nextjs.org/docs/app/guides/migrating-to-cache-components | 8, 24; Version notes |
| Preserving UI state | https://nextjs.org/docs/app/guides/preserving-ui-state | 24 |
| after | https://nextjs.org/docs/app/api-reference/functions/after | 16; NC 10 |
| compress | https://nextjs.org/docs/app/api-reference/config/next-config-js/compress | NC 4 |
| Upgrade guide 16 | https://nextjs.org/docs/app/guides/upgrading/version-16 | 24; Version notes |
| Edge Runtime deprecated | https://nextjs.org/docs/messages/edge-runtime-deprecated | 9; Version notes; NC 9 |
| Next.js 16 blog | https://nextjs.org/blog/next-16 | Version notes |
| Vercel streaming | https://vercel.com/docs/functions/streaming-functions | 29; Patterns; NC 6, 7 |
| Vercel duration | https://vercel.com/docs/functions/configuring-functions/duration | 13, 18, 22; Patterns; NC 2, 8 |
| Vercel limits | https://vercel.com/docs/functions/limitations | 18, 21, 22; Patterns; NC 2 |
| Vercel limits overview | https://vercel.com/docs/limits | Patterns (non-Fluid row) |
| Fluid compute | https://vercel.com/docs/fluid-compute | 22; Patterns; Version notes |
| 504 page | https://vercel.com/docs/errors/function_invocation_timeout | Patterns; NC 2 |
| Functions API reference | https://vercel.com/docs/functions/functions-api-reference | 9, 15, 16, 17; NC 1 |
| vercel.json | https://vercel.com/docs/project-configuration/vercel-json | 16; NC 8 |
| Vercel Edge runtime | https://vercel.com/docs/functions/runtimes/edge | 9 |
| Vercel WebSockets | https://vercel.com/docs/functions/websockets | 1, 21 |
| WebSockets KB | https://vercel.com/kb/guide/do-vercel-serverless-functions-support-websocket-connections | 1, 23; Patterns; Version notes |
| Realtime pub/sub KB | https://vercel.com/kb/guide/publish-and-subscribe-to-realtime-data-on-vercel | 1, 20, 21; Patterns |
| Vercel backpressure | https://vercel.com/kb/guide/handling-backpressure | 19 |
| Cancellation changelog | https://vercel.com/changelog/node-js-vercel-functions-now-support-request-cancellation | 17, 29 |
| Per-path cancellation changelog | https://vercel.com/changelog/node-js-vercel-functions-now-support-per-path-request-cancellation | Version notes |
| AI Gateway + AI SDK KB | https://vercel.com/kb/guide/ai-gateway-and-ai-sdk | 29; Version notes; NC 7 |
| MDN SSE | https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events | 3, 4, 10, 12, 13, 23, 25, 26, 28 |
| MDN EventSource | https://developer.mozilla.org/en-US/docs/Web/API/EventSource | 25 |
| MDN EventSource() | https://developer.mozilla.org/en-US/docs/Web/API/EventSource/EventSource | 7 |
| MDN ReadableStream() | https://developer.mozilla.org/en-US/docs/Web/API/ReadableStream/ReadableStream | 15, 19 |
| MDN enqueue | https://developer.mozilla.org/en-US/docs/Web/API/ReadableStreamDefaultController/enqueue | 15 |
| MDN desiredSize | https://developer.mozilla.org/en-US/docs/Web/API/ReadableStreamDefaultController/desiredSize | 19 |
| MDN AsyncGenerator.return() | https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/AsyncGenerator/return | 19 (Patterns §8.4) |
| MDN Request.signal | https://developer.mozilla.org/en-US/docs/Web/API/Request/signal | 15 |
| MDN TextEncoderStream | https://developer.mozilla.org/en-US/docs/Web/API/TextEncoderStream | 11 |
| MDN TextDecoder.decode() | https://developer.mozilla.org/en-US/docs/Web/API/TextDecoder/decode | 27 |
| MDN reader.read() | https://developer.mozilla.org/en-US/docs/Web/API/ReadableStreamDefaultReader/read | 27 |
| MDN Cache-Control | https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cache-Control | 4; NC 6 |
| MDN Connection | https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Connection | 5 |
| MDN CORS | https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS | 7 |
| WHATWG SSE | https://html.spec.whatwg.org/multipage/server-sent-events.html | 3, 6, 7, 10, 12, 13, 18, 20, 23, 26, 27, 28; NC 5 |
| WHATWG fetching | https://html.spec.whatwg.org/multipage/urls-and-fetching.html | 7 |
| useEffect | https://react.dev/reference/react/useEffect | 24 |
| useEffectEvent | https://react.dev/reference/react/useEffectEvent | 24 |

That's 52 URLs. 34 are on nextjs.org or vercel.com, well above the floor of 3. Every host is in
`ALLOWED_SOURCE_HOSTS`. The evidence file lists all 52 with "fetched 2026-10-04 (live, this run)"
and the Rules column. "NC n" means item n of Not confirmed by the docs.

## Assumptions

1. **As-of line.** The as-of line is copied from `R/nextjs.md` after the skeleton merges. The
   expected value is 16.3.8: npm `latest` and the nextjs.org docs frontmatter both show 16.3.8 on
   2026-10-04. If the skeleton records another version, use the skeleton's value. It owns the
   version read.
2. **"Complete as written" (AC5).** This is the route block plus the encoder module it imports,
   both shown in Patterns. The route test asserts the route block's needles, and a separate test
   asserts the encoder block writes `id: `, `event: `, `data: ` and a blank line.
3. **No anchors.** No URL in prose carries a `#anchor`, so the prose-URL ⊆ Sources check can't
   trip on fragment normalization in the skeleton's helper.
4. **Rules section shape.** `## Rules` has no H3 subheadings, in case `section()` stops at any
   heading. Grouping is by order only. The H3 groups in §7 are for this plan.
5. **Don't/Do shape.** Anti-patterns use `- **Don't** …` / `**Do** …`. If the skeleton's contract
   fixes another shape, the coder follows it and adjusts `test_sse_anti_patterns_pair_every_dont_with_a_do`.
6. **`'use client'` on a hook module.** The client hook block starts with `'use client'` to
   satisfy AC4's needle. It's harmless on a module only Client Components import, and no rule
   claims it's required.
7. **Excluded sources.** The AI SDK's own site and npm aren't allowed hosts, so they're used only
   to confirm the planner's understanding: the text stream is plain text, and the `next` latest
   version. Neither is cited.
8. **Hybrid rules.** SSE-4, SSE-14 and SSE-18 mix sourced facts with house policy and carry both
   links and `(convention)`. That's allowed, because the contract accepts either.
9. **Rule count.** There are 29 rules, above the 15 required, to give the expert depth Jonathan
   asked for. If the line budget runs tight, cut prose in Patterns before cutting any rule.
