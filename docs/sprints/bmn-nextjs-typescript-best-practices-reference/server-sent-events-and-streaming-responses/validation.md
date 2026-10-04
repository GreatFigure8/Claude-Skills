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
