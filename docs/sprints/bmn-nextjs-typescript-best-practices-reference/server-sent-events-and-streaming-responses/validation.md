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
