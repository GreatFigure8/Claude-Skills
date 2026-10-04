# Performance and the Vercel platform

**Slug:** `performance-and-vercel-platform`
**Run:** `bmn-nextjs-typescript-best-practices-reference` · plugin `Skills/dev-bother-me-nope/`
**Owns:** `R/nextjs/performance-and-vercel.md` (rule prefix `PERF`) and `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_performance_and_vercel.py`.
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.

## Story

**As** a dev-bother-me-nope planner, coder, reviewer or fixer working in a Next.js +
TypeScript repo,
**I want** sourced rules for images, fonts, third-party scripts, lazy loading, bundle size and analysis, the bundler and compiler defaults, and the Vercel function platform (Node.js vs Edge runtime, Fluid compute, duration, memory/CPU, regions, limits),
**so that** pages I ship load fast with no layout shift, the client bundle stays small, and server code is configured for how Vercel actually runs it, with every limit quoted from vercel.com rather than remembered.

## Context

- The skeleton story `nextjs-standard-entry-point-and-skill-wiring` has merged first. `R/nextjs/performance-and-vercel.md` exists as a stub
  marked ``> Stub: pending story `performance-and-vercel-platform`.``. `R/nextjs.md` holds the canonical folder
  structure, this file's index row (prefix `PERF`), the as-of version and the
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
  - https://nextjs.org/docs/app/getting-started/images
  - https://nextjs.org/docs/app/getting-started/fonts
  - https://nextjs.org/docs/app/guides/scripts
  - https://nextjs.org/docs/app/guides/package-bundling
  - https://nextjs.org/docs/app/guides/lazy-loading
  - https://vercel.com/docs/fluid-compute
  - https://vercel.com/docs/functions/limitations
  - https://vercel.com/docs/functions/runtimes
- The reader is an agent. Write imperative, checkable rules with short, correct, typed
  examples and Don't/Do pairs, not essays.

## Acceptance criteria

1. **[unit]** **Contract.** `R/nextjs/performance-and-vercel.md` replaces the stub entirely. Every generic check in `test_nextjs_reference.py` runs on it with no skip and passes:
   - an as-of line whose version matches `R/nextjs.md`;
   - the section order;
   - the rule format and citations;
   - the floors and Sources;
   - at most 800 lines;
   - tagged code fences and resolving links.

   It uses only `PERF-` rule ids.
2. **[unit]** **Not a stub, deep enough.** `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_performance_and_vercel.py` imports `nextjs_doc_helpers` and asserts that `is_stub` is false. It also asserts the file has at least 15 `PERF-` rules.
3. **[unit]** **Required concepts.** The test asserts `missing_terms(text, TERMS) == []`. TERMS: `next/image`, `sizes`, `remotePatterns`, `preload`, `priority`, `next/font`, `next/script`, `strategy`, `next/dynamic`, `optimizePackageImports`, `serverExternalPackages`, `bundle-analyzer`, `Turbopack`, `reactCompiler`, `Fluid compute`, `maxDuration`, `region`, `runtime`, `Edge`, `Node.js`, `vercel.json`, `request body`. A cited doc must confirm each concept before it is stated as a rule or pattern. Anything unconfirmed goes under `## Not confirmed by the docs` with the URLs checked.
4. **[unit]** **Examples.** The test asserts, through `has_block_with`, that the file has:
   - a `ts`/`tsx` block containing `next/image`, `sizes`: a responsive image;
   - a `ts`/`tsx` block containing `next/font`: a self-hosted font;
   - a `ts`/`tsx` block containing `NextConfig`, `remotePatterns`: remote image allow-listing;
   - a `ts`/`tsx` block containing `next/script`, `strategy`: a third-party script with a loading strategy;
   - a `ts`/`tsx` block containing `maxDuration`: per-route function duration;

   Each example is short, uses only APIs the cited pages show, and is TypeScript-typed (no `any`).
5. **[unit]** Every Vercel number (limits, defaults, maximums) is quoted with the plan or condition it applies to and a vercel.com link read on 2026-10-04. A number the page doesn't show is left out. A test asserts every line in the file containing `MB`, ` GB`, `seconds` or `minutes` outside code blocks also contains a vercel.com or nextjs.org link, or sits in a list item that does.
6. **[unit]** The runtime choice rule (Node.js vs Edge) is given as vercel.com and nextjs.org currently recommend it, with the link. A test asserts `## Rules` contains `Edge` and a vercel.com link.
7. **[unit]** **Version notes.** `## Version notes` names `Next.js <major>`, using the major from the as-of line. It lists every change to this topic in that major that the upgrade guide or release post confirms, each with its link. Candidates to check (verify, never assume): Turbopack as the default bundler; React Compiler status; `next/image` default and prop changes (for example `priority`/`preload`, `images.domains`); any font or script change in the latest major. If the guide lists no change for this topic, the section says so with the link. A test asserts the section is non-empty and links nextjs.org.
8. **[unit]** **Reviewer-ready.** Every `## Review checklist` item names the `PERF-<n>` rule it checks. Every `## Anti-patterns` item pairs a Don't block with the Do it should be. A test asserts every `- [ ]` line contains `PERF-`.
9. **[unit]** **Grounding evidence.** `docs/sprints/bmn-nextjs-typescript-best-practices-reference/performance-and-vercel-platform/evidence/sources-verified.md` lists every URL in the file's `## Sources`. For each URL it gives the fetch date (2026-10-04, fetched live this run) and the rule ids it backs. Validation records a one-off check that the two URL sets are equal in `validation.md`. It is not a permanent test.
10. **[unit]** **Scope and gates.** `git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists only `R/nextjs/performance-and-vercel.md`, `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_performance_and_vercel.py` and files under `docs/sprints/bmn-nextjs-typescript-best-practices-reference/performance-and-vercel-platform/`. The full suite (`uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`) passes, and `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` is clean.

## Out of scope

- `R/nextjs.md` (index, contract, non-negotiables, version notes) and the wiring files (`stack-routing.md`, `SKILL.md`, `briefs.md`, `plugin.json`, `test_skill_text_rules.py`, `test_nextjs_reference.py`, `nextjs_doc_helpers.py`): owned by `nextjs-standard-entry-point-and-skill-wiring`.
- Every other `R/nextjs/*.md` file, each owned by its own topic story.
- Caching and rendering strategy are `rendering-and-caching.md`.
- Streaming duration specifics for SSE are `sse-and-streaming.md`; this file owns general function config and limits.
- Handler-level `runtime`/`maxDuration` exports are shown in `route-handlers-and-apis.md`; this file owns choosing their values.

## Deps

- `nextjs-standard-entry-point-and-skill-wiring`

## Assumptions

- Grounding outranks every other criterion. If an acceptance criterion asks this file to state something the cited docs don't confirm, it goes under `## Not confirmed by the docs` with the URLs checked. That criterion's test then checks that section instead of `## Rules`, and validation.md records why.
- The starting URLs in Context are hints written before any fetch. Each is fetched live; a moved or 404 page is found again by searching nextjs.org or vercel.com, never assumed.
- A required term the docs don't confirm still appears in the file, but only in `## Not confirmed by the docs` with the URLs checked. The term test then passes without anything unconfirmed being stated as a rule.
- Snippets aren't compiled, because no Next.js project exists in this repo. Their API usage must match the cited page. REVIEW① spot-checks them against the links.
- This story never edits shared files: `nextjs.md`, the wiring files, `test_nextjs_reference.py` and `nextjs_doc_helpers.py`. A defect found there is recorded under Assumptions in this story's `validation.md` for REVIEW① to pick up. That keeps parallel topic stories conflict-free.
- Version facts in this file use the same latest major as `nextjs.md`'s as-of line, which the skeleton story read live.
- Vercel limits and defaults change over time. Each number is quoted as of 2026-10-04 with its link, so a reader can re-check it. Pricing is out of scope.
