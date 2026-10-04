# Route Handlers and API design: validation, errors, auth, CORS, webhooks and runtime

**Slug:** `route-handlers-and-api-design`
**Run:** `bmn-nextjs-typescript-best-practices-reference` · plugin `Skills/dev-bother-me-nope/`
**Owns:** `R/nextjs/route-handlers-and-apis.md` (rule prefix `API`) and `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_route_handlers_and_apis.py`.
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.

## Story

**As** a dev-bother-me-nope planner, coder, reviewer or fixer working in a Next.js +
TypeScript repo,
**I want** sourced rules for building Route Handlers as real APIs: method exports, typed context, request validation, one error-response shape, status codes, auth on every handler, CORS, webhook signature verification on the raw body, caching behaviour, runtime and duration config, and post-response work,
**so that** every endpoint I ship validates input, fails with consistent, non-leaky errors, is authorised independently of `proxy.ts`, and behaves the same under `next dev`, `next build` and on Vercel.

## Context

- The skeleton story `nextjs-standard-entry-point-and-skill-wiring` has merged first. `R/nextjs/route-handlers-and-apis.md` exists as a stub
  marked ``> Stub: pending story `route-handlers-and-api-design`.``. `R/nextjs.md` holds the canonical folder
  structure, this file's index row (prefix `API`), the as-of version and the
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
  - https://nextjs.org/docs/app/getting-started/route-handlers
  - https://nextjs.org/docs/app/api-reference/file-conventions/route
  - https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config
  - https://nextjs.org/docs/app/api-reference/functions/after
  - https://nextjs.org/docs/app/guides/backend-for-frontend
  - https://vercel.com/docs/functions
- The reader is an agent. Write imperative, checkable rules with short, correct, typed
  examples and Don't/Do pairs, not essays.

## Acceptance criteria

1. **[unit]** **Contract.** `R/nextjs/route-handlers-and-apis.md` replaces the stub entirely. Every generic check in `test_nextjs_reference.py` runs on it with no skip and passes:
   - an as-of line whose version matches `R/nextjs.md`;
   - the section order;
   - the rule format and citations;
   - the floors and Sources;
   - at most 800 lines;
   - tagged code fences and resolving links.

   It uses only `API-` rule ids.
2. **[unit]** **Not a stub, deep enough.** `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_route_handlers_and_apis.py` imports `nextjs_doc_helpers` and asserts that `is_stub` is false. It also asserts the file has at least 18 `API-` rules.
3. **[unit]** **Required concepts.** The test asserts `missing_terms(text, TERMS) == []`. TERMS: `route.ts`, `GET`, `POST`, `NextRequest`, `NextResponse`, `Response.json`, `RouteContext`, `OPTIONS`, `Access-Control-Allow-Origin`, `request.text()`, `signature`, `webhook`, `safeParse`, `400`, `401`, `403`, `404`, `runtime`, `maxDuration`, `after(`, `cookies()`, `headers()`, `Server Action`, `page.tsx`. A cited doc must confirm each concept before it is stated as a rule or pattern. Anything unconfirmed goes under `## Not confirmed by the docs` with the URLs checked.
4. **[unit]** **Examples.** The test asserts, through `has_block_with`, that the file has:
   - a `ts`/`tsx` block containing `export async function POST`, `safeParse`, `.json(`, `status:`: a validated POST handler returning the standard error shape;
   - a `ts`/`tsx` block containing `RouteContext<'/`, `await`: a dynamic-segment handler with typed context;
   - a `ts`/`tsx` block containing `request.text()`: webhook signature verification on the raw body;
   - a `ts`/`tsx` block containing `OPTIONS`, `Access-Control-Allow-Origin`: CORS preflight;

   Each example is short, uses only APIs the cited pages show, and is TypeScript-typed (no `any`).
5. **[unit]** The file defines one error-response shape once, under `## Patterns`, as a TypeScript type tagged `(convention)`. Every handler example that returns an error uses it. A test asserts a `ts` block under `## Patterns` declares the shape (`type` or `interface`) and that the POST example references its name.
6. **[unit]** Every `ts` block exporting `POST`, `PUT`, `PATCH` or `DELETE` calls a session or auth check (`(?i)(session|auth)\w*\(`), except the webhook example (the block containing `request.text()`), which verifies a signature instead. A test asserts this per block.
7. **[unit]** `## Rules` gives the Route Handler vs Server Action choice as the docs frame it: public, third-party or webhook endpoints use Route Handlers, and the app's own UI mutations use Server Actions. It also says a Server Component must not fetch the app's own Route Handler, if the docs say so. Otherwise that point goes to `## Not confirmed by the docs`.
8. **[unit]** **Version notes.** `## Version notes` names `Next.js <major>`, using the major from the as-of line. It lists every change to this topic in that major that the upgrade guide or release post confirms, each with its link. Candidates to check (verify, never assume): GET handlers not cached by default; `RouteContext` and async `params`; Route Handler behaviour with Cache Components; any `after()` or segment-config change in the latest major. If the guide lists no change for this topic, the section says so with the link. A test asserts the section is non-empty and links nextjs.org.
9. **[unit]** **Reviewer-ready.** Every `## Review checklist` item names the `API-<n>` rule it checks. Every `## Anti-patterns` item pairs a Don't block with the Do it should be. A test asserts every `- [ ]` line contains `API-`.
10. **[unit]** **Grounding evidence.** `docs/sprints/bmn-nextjs-typescript-best-practices-reference/route-handlers-and-api-design/evidence/sources-verified.md` lists every URL in the file's `## Sources`. For each URL it gives the fetch date (2026-10-04, fetched live this run) and the rule ids it backs. Validation records a one-off check that the two URL sets are equal in `validation.md`. It is not a permanent test.
11. **[unit]** **Scope and gates.** `git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists only `R/nextjs/route-handlers-and-apis.md`, `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_route_handlers_and_apis.py` and files under `docs/sprints/bmn-nextjs-typescript-best-practices-reference/route-handlers-and-api-design/`. The full suite (`uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`) passes, and `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` is clean.

## Out of scope

- `R/nextjs.md` (index, contract, non-negotiables, version notes) and the wiring files (`stack-routing.md`, `SKILL.md`, `briefs.md`, `plugin.json`, `test_skill_text_rules.py`, `test_nextjs_reference.py`, `nextjs_doc_helpers.py`): owned by `nextjs-standard-entry-point-and-skill-wiring`.
- Every other `R/nextjs/*.md` file, each owned by its own topic story.
- Streaming and SSE responses are `sse-and-streaming.md` (linked).
- Session/DAL design, CSP and `proxy.ts` are `proxy-auth-and-security.md`; this file requires an auth check per handler and links there.
- Vercel function limits, regions and runtime trade-offs in depth are `performance-and-vercel.md`; this file owns the handler-level config exports.
- Testing handlers is `testing-and-observability.md`.

## Deps

- `nextjs-standard-entry-point-and-skill-wiring`

## Assumptions

- Grounding outranks every other criterion. If an acceptance criterion asks this file to state something the cited docs don't confirm, it goes under `## Not confirmed by the docs` with the URLs checked. That criterion's test then checks that section instead of `## Rules`, and validation.md records why.
- The starting URLs in Context are hints written before any fetch. Each is fetched live; a moved or 404 page is found again by searching nextjs.org or vercel.com, never assumed.
- A required term the docs don't confirm still appears in the file, but only in `## Not confirmed by the docs` with the URLs checked. The term test then passes without anything unconfirmed being stated as a rule.
- Snippets aren't compiled, because no Next.js project exists in this repo. Their API usage must match the cited page. REVIEW① spot-checks them against the links.
- This story never edits shared files: `nextjs.md`, the wiring files, `test_nextjs_reference.py` and `nextjs_doc_helpers.py`. A defect found there is recorded under Assumptions in this story's `validation.md` for REVIEW① to pick up. That keeps parallel topic stories conflict-free.
- Version facts in this file use the same latest major as `nextjs.md`'s as-of line, which the skeleton story read live.
