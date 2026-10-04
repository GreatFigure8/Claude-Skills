# Testing, error handling and observability

**Slug:** `testing-errors-and-observability`
**Run:** `bmn-nextjs-typescript-best-practices-reference` · plugin `Skills/dev-bother-me-nope/`
**Owns:** `R/nextjs/testing-and-observability.md` (rule prefix `TEST`) and `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_testing_and_observability.py`.
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.

## Story

**As** a dev-bother-me-nope planner, coder, reviewer or fixer working in a Next.js +
TypeScript repo,
**I want** sourced rules for unit testing with Vitest (or Jest via `next/jest`), end-to-end testing with Playwright against a production build, what can't be unit-tested (async Server Components), error handling (expected errors as values, `error.tsx`, `global-error.tsx`, `not-found.tsx`), instrumentation, OpenTelemetry, request-error reporting, web vitals and logging,
**so that** every story's TDD tests run on the toolchain the Next.js docs set up, async Server Components are covered end to end, failures render a recoverable UI, and production errors are reported with context.

## Context

- The skeleton story `nextjs-standard-entry-point-and-skill-wiring` has merged first. `R/nextjs/testing-and-observability.md` exists as a stub
  marked ``> Stub: pending story `testing-errors-and-observability`.``. `R/nextjs.md` holds the canonical folder
  structure, this file's index row (prefix `TEST`), the as-of version and the
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
  - https://nextjs.org/docs/app/guides/testing/vitest
  - https://nextjs.org/docs/app/guides/testing/jest
  - https://nextjs.org/docs/app/guides/testing/playwright
  - https://nextjs.org/docs/app/getting-started/error-handling
  - https://nextjs.org/docs/app/guides/instrumentation
  - https://nextjs.org/docs/app/guides/open-telemetry
  - https://vitest.dev/config/
  - https://playwright.dev/docs/test-webserver
- The reader is an agent. Write imperative, checkable rules with short, correct, typed
  examples and Don't/Do pairs, not essays.

## Acceptance criteria

1. **[unit]** **Contract.** `R/nextjs/testing-and-observability.md` replaces the stub entirely. Every generic check in `test_nextjs_reference.py` runs on it with no skip and passes:
   - an as-of line whose version matches `R/nextjs.md`;
   - the section order;
   - the rule format and citations;
   - the floors and Sources;
   - at most 800 lines;
   - tagged code fences and resolving links.

   It uses only `TEST-` rule ids.
2. **[unit]** **Not a stub, deep enough.** `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_testing_and_observability.py` imports `nextjs_doc_helpers` and asserts that `is_stub` is false. It also asserts the file has at least 15 `TEST-` rules.
3. **[unit]** **Required concepts.** The test asserts `missing_terms(text, TERMS) == []`. TERMS: `vitest`, `@vitejs/plugin-react`, `jsdom`, `async Server Components`, `next/jest`, `playwright`, `webServer`, `next build`, `next start`, `instrumentation.ts`, `register`, `onRequestError`, `@vercel/otel`, `instrumentation-client`, `error.tsx`, `global-error.tsx`, `not-found.tsx`, `'use client'`, `expected errors`, `useReportWebVitals`, `logging`. A cited doc must confirm each concept before it is stated as a rule or pattern. Anything unconfirmed goes under `## Not confirmed by the docs` with the URLs checked.
4. **[unit]** **Examples.** The test asserts, through `has_block_with`, that the file has:
   - a `ts`/`tsx` block containing `defineConfig`, `jsdom`: `vitest.config` as the Next.js guide sets it up;
   - a `ts`/`tsx` block containing `defineConfig`, `webServer`: `playwright.config.ts` running the app;
   - a `ts`/`tsx` block containing `register`, `onRequestError`: `instrumentation.ts`;
   - a `ts`/`tsx` block containing `'use client'`, `<html`, `<body`: `app/global-error.tsx`;
   - a `ts`/`tsx` block containing `'use client'`, `digest`: a segment `error.tsx` boundary typed with `error.digest`;

   Each example is short, uses only APIs the cited pages show, and is TypeScript-typed (no `any`).
5. **[unit]** The file maps its rules onto bmn's test surfaces from `stack-routing.md`. The unit surface covers pure functions, schemas, Client Components and Server Action logic, and the browser surface covers Playwright for async Server Components and full flows. It states the docs' limit on unit-testing async Server Components, with the link. A test asserts `## Rules` contains `async Server Components` and a nextjs.org testing-guide link.
6. **[unit]** The error-handling rules separate expected errors (returned as values) from uncaught exceptions (error boundaries), as the docs do. They state what `global-error.tsx` must render. A test asserts `## Rules` contains `expected errors` and `global-error`.
7. **[unit]** **Version notes.** `## Version notes` names `Next.js <major>`, using the major from the as-of line. It lists every change to this topic in that major that the upgrade guide or release post confirms, each with its link. Candidates to check (verify, never assume): `instrumentation-client` and `onRequestError` availability; any error-boundary prop or testing-guide change in the latest major. If the guide lists no change for this topic, the section says so with the link. A test asserts the section is non-empty and links nextjs.org.
8. **[unit]** **Reviewer-ready.** Every `## Review checklist` item names the `TEST-<n>` rule it checks. Every `## Anti-patterns` item pairs a Don't block with the Do it should be. A test asserts every `- [ ]` line contains `TEST-`.
9. **[unit]** **Grounding evidence.** `docs/sprints/bmn-nextjs-typescript-best-practices-reference/testing-errors-and-observability/evidence/sources-verified.md` lists every URL in the file's `## Sources`. For each URL it gives the fetch date (2026-10-04, fetched live this run) and the rule ids it backs. Validation records a one-off check that the two URL sets are equal in `validation.md`. It is not a permanent test.
10. **[unit]** **Scope and gates.** `git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists only `R/nextjs/testing-and-observability.md`, `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_testing_and_observability.py` and files under `docs/sprints/bmn-nextjs-typescript-best-practices-reference/testing-errors-and-observability/`. The full suite (`uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`) passes, and `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` is clean.

## Out of scope

- `R/nextjs.md` (index, contract, non-negotiables, version notes) and the wiring files (`stack-routing.md`, `SKILL.md`, `briefs.md`, `plugin.json`, `test_skill_text_rules.py`, `test_nextjs_reference.py`, `nextjs_doc_helpers.py`): owned by `nextjs-standard-entry-point-and-skill-wiring`.
- Every other `R/nextjs/*.md` file, each owned by its own topic story.
- Route conventions for `not-found` and `notFound()` usage are `routing-and-metadata.md` (linked); this file owns error-handling strategy and the error boundaries.
- Returning expected errors from Server Actions as typed state is shown in `data-fetching-and-mutations.md`; this file states the rule and links there.

## Deps

- `nextjs-standard-entry-point-and-skill-wiring`

## Assumptions

- Grounding outranks every other criterion. If an acceptance criterion asks this file to state something the cited docs don't confirm, it goes under `## Not confirmed by the docs` with the URLs checked. That criterion's test then checks that section instead of `## Rules`, and validation.md records why.
- The starting URLs in Context are hints written before any fetch. Each is fetched live; a moved or 404 page is found again by searching nextjs.org or vercel.com, never assumed.
- A required term the docs don't confirm still appears in the file, but only in `## Not confirmed by the docs` with the URLs checked. The term test then passes without anything unconfirmed being stated as a rule.
- Snippets aren't compiled, because no Next.js project exists in this repo. Their API usage must match the cited page. REVIEW① spot-checks them against the links.
- This story never edits shared files: `nextjs.md`, the wiring files, `test_nextjs_reference.py` and `nextjs_doc_helpers.py`. A defect found there is recorded under Assumptions in this story's `validation.md` for REVIEW① to pick up. That keeps parallel topic stories conflict-free.
- Version facts in this file use the same latest major as `nextjs.md`'s as-of line, which the skeleton story read live.
