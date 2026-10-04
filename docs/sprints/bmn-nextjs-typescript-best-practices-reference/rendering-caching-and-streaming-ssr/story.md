# Rendering and caching: Server/Client Components, Cache Components, revalidation and streaming SSR

**Slug:** `rendering-caching-and-streaming-ssr`
**Run:** `bmn-nextjs-typescript-best-practices-reference` · plugin `Skills/dev-bother-me-nope/`
**Owns:** `R/nextjs/rendering-and-caching.md` (rule prefix `RC`) and `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_rendering_and_caching.py`.
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.

## Story

**As** a dev-bother-me-nope planner, coder, reviewer or fixer working in a Next.js +
TypeScript repo,
**I want** sourced rules for the Server/Client Component boundary, static vs dynamic rendering, Cache Components (`'use cache'`, `cacheLife`, `cacheTag`), Partial Prerendering as the current docs define it, revalidation APIs, and streaming HTML with `Suspense`/`loading.tsx`,
**so that** pages I build ship the least client JavaScript, cache exactly what should be cached, invalidate it correctly after writes, and stream slow parts instead of blocking the whole response, using the caching model that this repo actually has enabled.

## Context

- The skeleton story `nextjs-standard-entry-point-and-skill-wiring` has merged first. `R/nextjs/rendering-and-caching.md` exists as a stub
  marked ``> Stub: pending story `rendering-caching-and-streaming-ssr`.``. `R/nextjs.md` holds the canonical folder
  structure, this file's index row (prefix `RC`), the as-of version and the
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
  - https://nextjs.org/docs/app/getting-started/server-and-client-components
  - https://nextjs.org/docs/app/getting-started/cache-components
  - https://nextjs.org/docs/app/api-reference/directives/use-cache
  - https://nextjs.org/docs/app/api-reference/functions/cacheLife
  - https://nextjs.org/docs/app/api-reference/functions/revalidateTag
  - https://nextjs.org/docs/app/api-reference/functions/updateTag
  - https://nextjs.org/docs/app/guides/upgrading/version-16
- The reader is an agent. Write imperative, checkable rules with short, correct, typed
  examples and Don't/Do pairs, not essays.

## Acceptance criteria

1. **[unit]** **Contract.** `R/nextjs/rendering-and-caching.md` replaces the stub entirely. Every generic check in `test_nextjs_reference.py` runs on it with no skip and passes:
   - an as-of line whose version matches `R/nextjs.md`;
   - the section order;
   - the rule format and citations;
   - the floors and Sources;
   - at most 800 lines;
   - tagged code fences and resolving links.

   It uses only `RC-` rule ids.
2. **[unit]** **Not a stub, deep enough.** `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_rendering_and_caching.py` imports `nextjs_doc_helpers` and asserts that `is_stub` is false. It also asserts the file has at least 18 `RC-` rules.
3. **[unit]** **Required concepts.** The test asserts `missing_terms(text, TERMS) == []`. TERMS: `'use client'`, `Server Component`, `Client Component`, `children`, `serializable`, `'use cache'`, `cacheComponents`, `cacheLife`, `cacheTag`, `revalidateTag`, `updateTag`, `revalidatePath`, `refresh`, `Partial Prerendering`, `<Suspense`, `loading.tsx`, `connection()`, `cookies()`, `headers()`, `searchParams`, `streaming`, `provider`. A cited doc must confirm each concept before it is stated as a rule or pattern. Anything unconfirmed goes under `## Not confirmed by the docs` with the URLs checked.
4. **[unit]** **Examples.** The test asserts, through `has_block_with`, that the file has:
   - a `ts`/`tsx` block containing `NextConfig`, `cacheComponents`: enabling Cache Components;
   - a `ts`/`tsx` block containing `'use cache'`, `cacheLife(`: a cached component or function with a lifetime;
   - a `ts`/`tsx` block containing `cacheTag(`: tagging cached data for targeted invalidation;
   - a `ts`/`tsx` block containing `<Suspense`, `fallback`: streaming a slow subtree;
   - a `ts`/`tsx` block containing `'use client'`, `children`: a client wrapper that takes Server Components as children;

   Each example is short, uses only APIs the cited pages show, and is TypeScript-typed (no `any`).
5. **[unit]** The file tells the reader to detect the repo's caching model first. With `cacheComponents` enabled in `next.config`, Cache Components rules apply. Without it, the previous model applies (route segment config such as `dynamic`/`revalidate`, and fetch options), as far as the current docs still document it. Each rule that applies to only one model is labelled with that model. A test asserts `## Rules` contains `cacheComponents` and either `without` or `previous model`.
6. **[unit]** The file gives a decision table: which API to call after a write (`revalidateTag`, `updateTag`, `revalidatePath`, `refresh`), where each may be called (Server Action, Route Handler, both) and what the user sees, all as the docs state. A test asserts `## Patterns` contains a Markdown table naming all four.
7. **[unit]** **Version notes.** `## Version notes` names `Next.js <major>`, using the major from the as-of line. It lists every change to this topic in that major that the upgrade guide or release post confirms, each with its link. Candidates to check (verify, never assume): Cache Components and the `cacheComponents` flag replacing earlier experimental PPR/dynamicIO flags; `revalidateTag` signature change; new `updateTag` and `refresh`; `unstable_cache` vs `'use cache'`; fetch caching defaults; route segment options that conflict with Cache Components. If the guide lists no change for this topic, the section says so with the link. A test asserts the section is non-empty and links nextjs.org.
8. **[unit]** **Reviewer-ready.** Every `## Review checklist` item names the `RC-<n>` rule it checks. Every `## Anti-patterns` item pairs a Don't block with the Do it should be. A test asserts every `- [ ]` line contains `RC-`.
9. **[unit]** **Grounding evidence.** `docs/sprints/bmn-nextjs-typescript-best-practices-reference/rendering-caching-and-streaming-ssr/evidence/sources-verified.md` lists every URL in the file's `## Sources`. For each URL it gives the fetch date (2026-10-04, fetched live this run) and the rule ids it backs. Validation records a one-off check that the two URL sets are equal in `validation.md`. It is not a permanent test.
10. **[unit]** **Scope and gates.** `git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists only `R/nextjs/rendering-and-caching.md`, `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_rendering_and_caching.py` and files under `docs/sprints/bmn-nextjs-typescript-best-practices-reference/rendering-caching-and-streaming-ssr/`. The full suite (`uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`) passes, and `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` is clean.

## Out of scope

- `R/nextjs.md` (index, contract, non-negotiables, version notes) and the wiring files (`stack-routing.md`, `SKILL.md`, `briefs.md`, `plugin.json`, `test_skill_text_rules.py`, `test_nextjs_reference.py`, `nextjs_doc_helpers.py`): owned by `nextjs-standard-entry-point-and-skill-wiring`.
- Every other `R/nextjs/*.md` file, each owned by its own topic story.
- How to fetch (parallel fetching, React `cache`, passing promises to `use`) and where mutations call the revalidation APIs is `data-fetching-and-mutations.md`; this file owns caching semantics and what each invalidation API does.
- Streaming *responses* from Route Handlers (SSE, `ReadableStream`) is `sse-and-streaming.md`; this file owns streaming HTML (SSR) with `Suspense`.
- `generateStaticParams` usage is `routing-and-metadata.md` (linked, not repeated).

## Deps

- `nextjs-standard-entry-point-and-skill-wiring`

## Assumptions

- Grounding outranks every other criterion. If an acceptance criterion asks this file to state something the cited docs don't confirm, it goes under `## Not confirmed by the docs` with the URLs checked. That criterion's test then checks that section instead of `## Rules`, and validation.md records why.
- The starting URLs in Context are hints written before any fetch. Each is fetched live; a moved or 404 page is found again by searching nextjs.org or vercel.com, never assumed.
- A required term the docs don't confirm still appears in the file, but only in `## Not confirmed by the docs` with the URLs checked. The term test then passes without anything unconfirmed being stated as a rule.
- Snippets aren't compiled, because no Next.js project exists in this repo. Their API usage must match the cited page. REVIEW① spot-checks them against the links.
- This story never edits shared files: `nextjs.md`, the wiring files, `test_nextjs_reference.py` and `nextjs_doc_helpers.py`. A defect found there is recorded under Assumptions in this story's `validation.md` for REVIEW① to pick up. That keeps parallel topic stories conflict-free.
- Version facts in this file use the same latest major as `nextjs.md`'s as-of line, which the skeleton story read live.
- Existing repos may not have Cache Components enabled, so rules are labelled by caching model rather than assuming the newest one.
