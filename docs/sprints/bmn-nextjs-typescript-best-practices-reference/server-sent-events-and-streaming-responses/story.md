# Server-sent events and streaming responses from Route Handlers

**Slug:** `server-sent-events-and-streaming-responses`
**Run:** `bmn-nextjs-typescript-best-practices-reference` · plugin `Skills/dev-bother-me-nope/`
**Owns:** `R/nextjs/sse-and-streaming.md` (rule prefix `SSE`) and `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_sse_and_streaming.py`.
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.

## Story

**As** a dev-bother-me-nope planner, coder, reviewer or fixer working in a Next.js +
TypeScript repo,
**I want** sourced rules and complete examples for streaming from Route Handlers: SSE wire format, headers, `ReadableStream` with abort and cleanup, heartbeats, resuming with `Last-Event-ID`, Vercel streaming and duration limits, and the client side (`EventSource` with reconnection, or `fetch` + reader when custom headers or POST are needed),
**so that** live updates and token streams I build never leak timers or subscriptions when the client leaves, survive the function's time limit by reconnecting cleanly, and work the same locally and on Vercel.

## Context

- The skeleton story `nextjs-standard-entry-point-and-skill-wiring` has merged first. `R/nextjs/sse-and-streaming.md` exists as a stub
  marked ``> Stub: pending story `server-sent-events-and-streaming-responses`.``. `R/nextjs.md` holds the canonical folder
  structure, this file's index row (prefix `SSE`), the as-of version and the
  **Authoring contract**. Read the contract before writing anything.
  `Skills/dev-bother-me-nope/assets/tests/test_nextjs_reference.py` enforces the contract on
  every non-stub topic file. `Skills/dev-bother-me-nope/assets/tests/nextjs_doc_helpers.py`
  holds the parsing helpers this story's test imports.
- Grounding is the hard requirement (input.md: "Don't assume or lie. ground all your findings
  in NextJS and Vercel documentation"). Fetch every page live on 2026-10-04 with
  WebFetch/WebSearch. Every Next.js or Vercel behaviour claim cites nextjs.org or vercel.com.
  react.dev, typescriptlang.org, MDN/WHATWG, zod.dev, vitest.dev and playwright.dev back only
  the facts they own.
- Starting points to verify live (hints, not sources until fetched):
  - https://nextjs.org/docs/app/api-reference/file-conventions/route
  - https://vercel.com/docs/functions/streaming-functions
  - https://vercel.com/docs/functions/configuring-functions/duration
  - https://vercel.com/docs/fluid-compute
  - https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events
  - https://html.spec.whatwg.org/multipage/server-sent-events.html
- The reader is an agent. Write imperative, checkable rules with short, correct, typed
  examples and Don't/Do pairs, not essays.

## Acceptance criteria

1. **[unit]** **Contract.** `R/nextjs/sse-and-streaming.md` replaces the stub entirely. Every generic check in `test_nextjs_reference.py` runs on it with no skip and passes:
   - an as-of line whose version matches `R/nextjs.md`;
   - the section order;
   - the rule format and citations;
   - the floors and Sources;
   - at most 800 lines;
   - tagged code fences and resolving links.

   It uses only `SSE-` rule ids.
2. **[unit]** **Not a stub, deep enough.** `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_sse_and_streaming.py` imports `nextjs_doc_helpers` and asserts that `is_stub` is false. It also asserts the file has at least 15 `SSE-` rules.
3. **[unit]** **Required concepts.** The test asserts `missing_terms(text, TERMS) == []`. TERMS: `text/event-stream`, `ReadableStream`, `TextEncoder`, `controller.enqueue`, `controller.close`, `request.signal`, `abort`, `cancel(`, `data:`, `event:`, `id:`, `retry:`, `heartbeat`, `Cache-Control`, `EventSource`, `Last-Event-ID`, `withCredentials`, `getReader(`, `reconnect`, `backpressure`, `maxDuration`, `Fluid compute`, `useEffect`, `.close()`. A cited doc must confirm each concept before it is stated as a rule or pattern. Anything unconfirmed goes under `## Not confirmed by the docs` with the URLs checked.
4. **[unit]** **Examples.** The test asserts, through `has_block_with`, that the file has:
   - a `ts`/`tsx` block containing `text/event-stream`, `ReadableStream`, `request.signal`: the SSE Route Handler;
   - a `ts`/`tsx` block containing `controller.enqueue`, `TextEncoder`: encoding SSE frames;
   - a `ts`/`tsx` block containing `setInterval`, `clearInterval`: a heartbeat that is cleared on abort/cancel;
   - a `ts`/`tsx` block containing `Last-Event-ID`: resuming from the last delivered event id;
   - a `ts`/`tsx` block containing `'use client'`, `EventSource`, `useEffect`, `.close()`: a client hook that closes on unmount;
   - a `ts`/`tsx` block containing `getReader(`: a fetch-based stream reader for POST or custom headers;

   Each example is short, uses only APIs the cited pages show, and is TypeScript-typed (no `any`).
5. **[unit]** The SSE Route Handler example is complete as written:
   - it exports the HTTP method;
   - it authenticates and links `route-handlers-and-apis.md`;
   - it sets the SSE response headers;
   - it writes frames as `id:`/`event:`/`data:` lines ended by a blank line;
   - it sends a heartbeat comment on an interval;
   - it releases every timer and subscription both when `request.signal` aborts and in the stream's `cancel()` callback.

   A test asserts that one `ts` block contains `export async function GET`, `abort` and `cancel(`.
6. **[unit]** The Vercel section quotes the streaming support, maximum function duration and default duration, each with the plan or config it applies to (Fluid compute on or off), exactly as vercel.com shows them on 2026-10-04, with the link. It gives the rule to set `maxDuration` and to design the client to reconnect when the function ends. Any number vercel.com doesn't show is left out. A test asserts `## Rules` contains `maxDuration` and a vercel.com link.
7. **[unit]** The client section says, sourced to MDN or WHATWG:
   - `EventSource` reconnects automatically;
   - `EventSource` sends `Last-Event-ID` on reconnect;
   - `retry:` sets the reconnection delay;
   - `EventSource` cannot set custom request headers, which is why the `fetch` + `getReader()` pattern exists.

   A test asserts `developer.mozilla.org` or `html.spec.whatwg.org` is in `## Sources`.
8. **[unit]** **Version notes.** `## Version notes` names `Next.js <major>`, using the major from the as-of line. It lists every change to this topic in that major that the upgrade guide or release post confirms, each with its link. Candidates to check (verify, never assume): any Route Handler streaming change in the latest major (if the upgrade guide lists none, say so with the link); Vercel Fluid compute defaults as currently documented. If the guide lists no change for this topic, the section says so with the link. A test asserts the section is non-empty and links nextjs.org.
9. **[unit]** **Reviewer-ready.** Every `## Review checklist` item names the `SSE-<n>` rule it checks. Every `## Anti-patterns` item pairs a Don't block with the Do it should be. A test asserts every `- [ ]` line contains `SSE-`.
10. **[unit]** **Grounding evidence.** `docs/sprints/bmn-nextjs-typescript-best-practices-reference/server-sent-events-and-streaming-responses/evidence/sources-verified.md` lists every URL in the file's `## Sources`. For each URL it gives the fetch date (2026-10-04, fetched live this run) and the rule ids it backs. Validation records a one-off check that the two URL sets are equal in `validation.md`. It is not a permanent test.
11. **[unit]** **Scope and gates.** `git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists only `R/nextjs/sse-and-streaming.md`, `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_sse_and_streaming.py` and files under `docs/sprints/bmn-nextjs-typescript-best-practices-reference/server-sent-events-and-streaming-responses/`. The full suite (`uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`) passes, and `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` is clean.

## Out of scope

- `R/nextjs.md` (index, contract, non-negotiables, version notes) and the wiring files (`stack-routing.md`, `SKILL.md`, `briefs.md`, `plugin.json`, `test_skill_text_rules.py`, `test_nextjs_reference.py`, `nextjs_doc_helpers.py`): owned by `nextjs-standard-entry-point-and-skill-wiring`.
- Every other `R/nextjs/*.md` file, each owned by its own topic story.
- Streaming HTML (SSR with `Suspense`/`loading.tsx`) is `rendering-and-caching.md`.
- General handler validation, auth and error shape are `route-handlers-and-apis.md`; the SSE route example calls an auth check and links there.
- General function config and Vercel limits beyond streaming are `performance-and-vercel.md`.

## Deps

- `nextjs-standard-entry-point-and-skill-wiring`

## Assumptions

- Grounding outranks every other criterion. If an acceptance criterion asks this file to state something the cited docs don't confirm, it goes under `## Not confirmed by the docs` with the URLs checked. That criterion's test then checks that section instead of `## Rules`, and validation.md records why.
- The starting URLs in Context are hints written before any fetch. Each is fetched live; a moved or 404 page is found again by searching nextjs.org or vercel.com, never assumed.
- A required term the docs don't confirm still appears in the file, but only in `## Not confirmed by the docs` with the URLs checked. The term test then passes without anything unconfirmed being stated as a rule.
- Snippets aren't compiled, because no Next.js project exists in this repo. Their API usage must match the cited page. REVIEW① spot-checks them against the links.
- This story never edits shared files: `nextjs.md`, the wiring files, `test_nextjs_reference.py` and `nextjs_doc_helpers.py`. A defect found there is recorded under Assumptions in this story's `validation.md` for REVIEW① to pick up. That keeps parallel topic stories conflict-free.
- Version facts in this file use the same latest major as `nextjs.md`'s as-of line, which the skeleton story read live.
- The SSE wire format (`data:`/`id:`/`retry:`, comment heartbeats, `Last-Event-ID`) and `EventSource` behaviour are web-platform facts, so they are grounded in MDN and the WHATWG spec. Next.js and Vercel docs ground only the Route Handler and function side.
- With no first-party SSE helper, the Route Handler returns a standard `Response` wrapping a `ReadableStream`, as the Route Handler docs' streaming example does. Third-party streaming SDKs are out of scope.
