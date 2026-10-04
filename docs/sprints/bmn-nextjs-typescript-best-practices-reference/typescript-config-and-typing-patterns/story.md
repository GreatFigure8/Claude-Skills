# TypeScript in Next.js: strict config, route-aware types and validated boundaries

**Slug:** `typescript-config-and-typing-patterns`
**Run:** `bmn-nextjs-typescript-best-practices-reference` · plugin `Skills/dev-bother-me-nope/`
**Owns:** `R/nextjs/typescript.md` (rule prefix `TS`) and `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_typescript.py`.
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.

## Story

**As** a dev-bother-me-nope planner, coder, reviewer or fixer working in a Next.js +
TypeScript repo,
**I want** imperative, sourced rules for `tsconfig.json`, `next.config.ts`, the route-aware type helpers, typed routes, typing async `params`/`searchParams`, env typing and validating every untyped boundary,
**so that** every `.ts`/`.tsx` file I write or review type-checks under `strict`, never trusts `any` or unvalidated input, and uses the type helpers the current Next.js generates instead of hand-rolled prop types.

## Context

- The skeleton story `nextjs-standard-entry-point-and-skill-wiring` has merged first. `R/nextjs/typescript.md` exists as a stub
  marked ``> Stub: pending story `typescript-config-and-typing-patterns`.``. `R/nextjs.md` holds the canonical folder
  structure, this file's index row (prefix `TS`), the as-of version and the
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
  - https://nextjs.org/docs/app/api-reference/config/typescript
  - https://nextjs.org/docs/app/api-reference/config/next-config-js/typedRoutes
  - https://nextjs.org/docs/app/guides/environment-variables
  - https://nextjs.org/docs/app/guides/upgrading/version-16
  - https://www.typescriptlang.org/tsconfig/
  - https://zod.dev/
- The reader is an agent. Write imperative, checkable rules with short, correct, typed
  examples and Don't/Do pairs, not essays.

## Acceptance criteria

1. **[unit]** **Contract.** `R/nextjs/typescript.md` replaces the stub entirely. Every generic check in `test_nextjs_reference.py` runs on it with no skip and passes:
   - an as-of line whose version matches `R/nextjs.md`;
   - the section order;
   - the rule format and citations;
   - the floors and Sources;
   - at most 800 lines;
   - tagged code fences and resolving links.

   It uses only `TS-` rule ids.
2. **[unit]** **Not a stub, deep enough.** `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_typescript.py` imports `nextjs_doc_helpers` and asserts that `is_stub` is false. It also asserts the file has at least 15 `TS-` rules.
3. **[unit]** **Required concepts.** The test asserts `missing_terms(text, TERMS) == []`. TERMS: `"strict": true`, `noUncheckedIndexedAccess`, `next-env.d.ts`, `next.config.ts`, `NextConfig`, `typedRoutes`, `next typegen`, `PageProps`, `LayoutProps`, `RouteContext`, `searchParams`, `Promise<`, `ignoreBuildErrors`, `safeParse`, `unknown`, `satisfies`, `server-only`, `NEXT_PUBLIC_`, `Metadata`, ```any```. A cited doc must confirm each concept before it is stated as a rule or pattern. Anything unconfirmed goes under `## Not confirmed by the docs` with the URLs checked.
4. **[unit]** **Examples.** The test asserts, through `has_block_with`, that the file has:
   - a `json` block containing `"strict": true`: the recommended `tsconfig.json` compiler options;
   - a `ts`/`tsx` block containing `NextConfig`, `typedRoutes`: a typed `next.config.ts`;
   - a `ts`/`tsx` block containing `PageProps<'/`, `await`: a page typed with `PageProps` awaiting its params;
   - a `ts`/`tsx` block containing `RouteContext<'/`, `await`: a Route Handler typed with `RouteContext`;
   - a `ts`/`tsx` block containing `safeParse`: validating an untyped boundary (env, JSON, `FormData`);

   Each example is short, uses only APIs the cited pages show, and is TypeScript-typed (no `any`).
5. **[unit]** The file states how a repo gets the route-aware helpers (`next dev`, `next build` or `next typegen`, as the docs say) and that `params`/`searchParams` are typed as `Promise` and awaited. A test asserts a `tsx` block contains `searchParams` and `await`.
6. **[unit]** `## Rules` contains a rule that forbids `typescript.ignoreBuildErrors` (or says when the docs allow it) and a rule that bans `any` in favour of `unknown` + narrowing (convention or typescriptlang.org source). A test asserts both terms appear inside `## Rules`.
7. **[unit]** **Version notes.** `## Version notes` names `Next.js <major>`, using the major from the as-of line. It lists every change to this topic in that major that the upgrade guide or release post confirms, each with its link. Candidates to check (verify, never assume): removal of synchronous access to `params`/`searchParams`/`cookies()`/`headers()`; `typedRoutes` status (stable, Turbopack support); the route-aware type helpers and `next typegen`; `next lint` removal / ESLint CLI; minimum TypeScript version. If the guide lists no change for this topic, the section says so with the link. A test asserts the section is non-empty and links nextjs.org.
8. **[unit]** **Reviewer-ready.** Every `## Review checklist` item names the `TS-<n>` rule it checks. Every `## Anti-patterns` item pairs a Don't block with the Do it should be. A test asserts every `- [ ]` line contains `TS-`.
9. **[unit]** **Grounding evidence.** `docs/sprints/bmn-nextjs-typescript-best-practices-reference/typescript-config-and-typing-patterns/evidence/sources-verified.md` lists every URL in the file's `## Sources`. For each URL it gives the fetch date (2026-10-04, fetched live this run) and the rule ids it backs. Validation records a one-off check that the two URL sets are equal in `validation.md`. It is not a permanent test.
10. **[unit]** **Scope and gates.** `git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists only `R/nextjs/typescript.md`, `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_typescript.py` and files under `docs/sprints/bmn-nextjs-typescript-best-practices-reference/typescript-config-and-typing-patterns/`. The full suite (`uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`) passes, and `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` is clean.

## Out of scope

- `R/nextjs.md` (index, contract, non-negotiables, version notes) and the wiring files (`stack-routing.md`, `SKILL.md`, `briefs.md`, `plugin.json`, `test_skill_text_rules.py`, `test_nextjs_reference.py`, `nextjs_doc_helpers.py`): owned by `nextjs-standard-entry-point-and-skill-wiring`.
- Every other `R/nextjs/*.md` file, each owned by its own topic story.
- What env values are exposed to the browser and how secrets stay server-side is `proxy-auth-and-security.md`. This file covers how env is *typed and validated*.
- Zod inside Server Actions/forms is `data-fetching-and-mutations.md`; inside Route Handlers is `route-handlers-and-apis.md`. This file owns the general boundary-validation rule and the types.
- Metadata objects (`Metadata`, `generateMetadata`) in depth are `routing-and-metadata.md`; this file only covers their types.

## Deps

- `nextjs-standard-entry-point-and-skill-wiring`

## Assumptions

- Grounding outranks every other criterion. If an acceptance criterion asks this file to state something the cited docs don't confirm, it goes under `## Not confirmed by the docs` with the URLs checked. That criterion's test then checks that section instead of `## Rules`, and validation.md records why.
- The starting URLs in Context are hints written before any fetch. Each is fetched live; a moved or 404 page is found again by searching nextjs.org or vercel.com, never assumed.
- A required term the docs don't confirm still appears in the file, but only in `## Not confirmed by the docs` with the URLs checked. The term test then passes without anything unconfirmed being stated as a rule.
- Snippets aren't compiled, because no Next.js project exists in this repo. Their API usage must match the cited page. REVIEW① spot-checks them against the links.
- This story never edits shared files: `nextjs.md`, the wiring files, `test_nextjs_reference.py` and `nextjs_doc_helpers.py`. A defect found there is recorded under Assumptions in this story's `validation.md` for REVIEW① to pick up. That keeps parallel topic stories conflict-free.
- Version facts in this file use the same latest major as `nextjs.md`'s as-of line, which the skeleton story read live.
