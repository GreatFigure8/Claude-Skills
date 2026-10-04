# App Router routing, navigation and metadata

**Slug:** `app-router-routing-and-metadata`
**Run:** `bmn-nextjs-typescript-best-practices-reference` · plugin `Skills/dev-bother-me-nope/`
**Owns:** `R/nextjs/routing-and-metadata.md` (rule prefix `RT`) and `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_routing_and_metadata.py`.
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.

## Story

**As** a dev-bother-me-nope planner, coder, reviewer or fixer working in a Next.js +
TypeScript repo,
**I want** sourced rules for App Router file conventions, dynamic segments, route groups, private folders, parallel and intercepting routes, static params, navigation and the Metadata API (including sitemap, robots and generated OG images),
**so that** routes, links and SEO metadata I build use the conventions the current Next.js documents, render statically where they can, and never break on a slot or segment rule that changed in the latest major.

## Context

- The skeleton story `nextjs-standard-entry-point-and-skill-wiring` has merged first. `R/nextjs/routing-and-metadata.md` exists as a stub
  marked ``> Stub: pending story `app-router-routing-and-metadata`.``. `R/nextjs.md` holds the canonical folder
  structure, this file's index row (prefix `RT`), the as-of version and the
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
  - https://nextjs.org/docs/app/getting-started/project-structure
  - https://nextjs.org/docs/app/getting-started/layouts-and-pages
  - https://nextjs.org/docs/app/getting-started/linking-and-navigating
  - https://nextjs.org/docs/app/api-reference/functions/generate-static-params
  - https://nextjs.org/docs/app/getting-started/metadata-and-og-images
  - https://nextjs.org/docs/app/api-reference/file-conventions/parallel-routes
- The reader is an agent. Write imperative, checkable rules with short, correct, typed
  examples and Don't/Do pairs, not essays.

## Acceptance criteria

1. **[unit]** **Contract.** `R/nextjs/routing-and-metadata.md` replaces the stub entirely. Every generic check in `test_nextjs_reference.py` runs on it with no skip and passes:
   - an as-of line whose version matches `R/nextjs.md`;
   - the section order;
   - the rule format and citations;
   - the floors and Sources;
   - at most 800 lines;
   - tagged code fences and resolving links.

   It uses only `RT-` rule ids.
2. **[unit]** **Not a stub, deep enough.** `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_routing_and_metadata.py` imports `nextjs_doc_helpers` and asserts that `is_stub` is false. It also asserts the file has at least 15 `RT-` rules.
3. **[unit]** **Required concepts.** The test asserts `missing_terms(text, TERMS) == []`. TERMS: `layout.tsx`, `page.tsx`, `loading.tsx`, `not-found.tsx`, `template.tsx`, `default.tsx`, `[slug]`, `[...slug]`, `[[...slug]]`, `route group`, `private folder`, `parallel route`, `intercepting route`, `(.)`, `generateStaticParams`, `dynamicParams`, `<Link`, `prefetch`, `useRouter`, `usePathname`, `useSearchParams`, `redirect(`, `permanentRedirect`, `notFound(`, `generateMetadata`, `metadataBase`, `generateViewport`, `sitemap.ts`, `robots.ts`, `opengraph-image`, `ImageResponse`, `MetadataRoute`. A cited doc must confirm each concept before it is stated as a rule or pattern. Anything unconfirmed goes under `## Not confirmed by the docs` with the URLs checked.
4. **[unit]** **Examples.** The test asserts, through `has_block_with`, that the file has:
   - a `ts`/`tsx` block containing `generateStaticParams`, `params`: a dynamic segment page with static params;
   - a `ts`/`tsx` block containing `generateMetadata`, `Metadata`: typed dynamic metadata;
   - a `ts`/`tsx` block containing `MetadataRoute.Sitemap`: `app/sitemap.ts`;
   - a `ts`/`tsx` block containing `notFound()`: a page that 404s on a missing record;
   - a `ts`/`tsx` block containing `'use client'`, `useSearchParams`: a client component reading search params;

   Each example is short, uses only APIs the cited pages show, and is TypeScript-typed (no `any`).
5. **[unit]** The file states the rule for parallel-route slots and their `default` file exactly as the current docs and upgrade guide give it. A test asserts `## Rules` contains `default`.
6. **[unit]** The file maps Jonathan's canonical layout (route groups `(auth)`, `(dashboard)`, `api/`) to these conventions by linking `../nextjs.md` and never contradicts it. A test asserts a relative link to `../nextjs.md` exists.
7. **[unit]** **Version notes.** `## Version notes` names `Next.js <major>`, using the major from the as-of line. It lists every change to this topic in that major that the upgrade guide or release post confirms, each with its link. Candidates to check (verify, never assume): async `params` in pages, layouts, metadata functions and image/sitemap files; parallel-route `default` file requirement; any Link/prefetch or metadata change in the latest major. If the guide lists no change for this topic, the section says so with the link. A test asserts the section is non-empty and links nextjs.org.
8. **[unit]** **Reviewer-ready.** Every `## Review checklist` item names the `RT-<n>` rule it checks. Every `## Anti-patterns` item pairs a Don't block with the Do it should be. A test asserts every `- [ ]` line contains `RT-`.
9. **[unit]** **Grounding evidence.** `docs/sprints/bmn-nextjs-typescript-best-practices-reference/app-router-routing-and-metadata/evidence/sources-verified.md` lists every URL in the file's `## Sources`. For each URL it gives the fetch date (2026-10-04, fetched live this run) and the rule ids it backs. Validation records a one-off check that the two URL sets are equal in `validation.md`. It is not a permanent test.
10. **[unit]** **Scope and gates.** `git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists only `R/nextjs/routing-and-metadata.md`, `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_routing_and_metadata.py` and files under `docs/sprints/bmn-nextjs-typescript-best-practices-reference/app-router-routing-and-metadata/`. The full suite (`uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`) passes, and `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` is clean.

## Out of scope

- `R/nextjs.md` (index, contract, non-negotiables, version notes) and the wiring files (`stack-routing.md`, `SKILL.md`, `briefs.md`, `plugin.json`, `test_skill_text_rules.py`, `test_nextjs_reference.py`, `nextjs_doc_helpers.py`): owned by `nextjs-standard-entry-point-and-skill-wiring`.
- Every other `R/nextjs/*.md` file, each owned by its own topic story.
- `error.tsx`, `global-error.tsx` and error-handling strategy are `testing-and-observability.md`; this file lists the file convention and links there.
- Static vs dynamic rendering and caching semantics are `rendering-and-caching.md`; this file owns `generateStaticParams`/`dynamicParams` usage.
- `route.ts` internals are `route-handlers-and-apis.md`; redirects done in `proxy.ts` are `proxy-auth-and-security.md`.

## Deps

- `nextjs-standard-entry-point-and-skill-wiring`

## Assumptions

- Grounding outranks every other criterion. If an acceptance criterion asks this file to state something the cited docs don't confirm, it goes under `## Not confirmed by the docs` with the URLs checked. That criterion's test then checks that section instead of `## Rules`, and validation.md records why.
- The starting URLs in Context are hints written before any fetch. Each is fetched live; a moved or 404 page is found again by searching nextjs.org or vercel.com, never assumed.
- A required term the docs don't confirm still appears in the file, but only in `## Not confirmed by the docs` with the URLs checked. The term test then passes without anything unconfirmed being stated as a rule.
- Snippets aren't compiled, because no Next.js project exists in this repo. Their API usage must match the cited page. REVIEW① spot-checks them against the links.
- This story never edits shared files: `nextjs.md`, the wiring files, `test_nextjs_reference.py` and `nextjs_doc_helpers.py`. A defect found there is recorded under Assumptions in this story's `validation.md` for REVIEW① to pick up. That keeps parallel topic stories conflict-free.
- Version facts in this file use the same latest major as `nextjs.md`'s as-of line, which the skeleton story read live.
