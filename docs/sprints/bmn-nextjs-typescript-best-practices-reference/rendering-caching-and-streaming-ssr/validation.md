# Validation — rendering-caching-and-streaming-ssr

Branch `wip/nextjs-typescript-best-practices-reference/rendering-caching-and-streaming-ssr`, cut from
`origin/feat/nextjs-typescript-best-practices-reference` (skeleton merged). Date: 2026-10-04.
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.

## TDD record

| Step | Command | Result |
| --- | --- | --- |
| RED | `pytest .../test_nextjs_topic_rendering_and_caching.py` against the stub | 24 collected, **24 failed**. Failures are the stub's: `is_stub` true, no `RC-` rules (`0 >= 8` anti-patterns, empty rule list), missing terms and examples, `LookupError: no heading 'Review checklist'`. Committed as `test:` before any content. |
| GREEN | same file, with `R/nextjs/rendering-and-caching.md` written | **24 passed** |
| Generic contract | `pytest test_nextjs_reference.py -rs` | passes for `rendering-and-caching.md` with **no skip**: its 7 generic cases moved from skipped to passed (skips 63 to 56; no `SKIPPED` line names this file) |
| Refactor | wording tightened, imports added to the anti-pattern snippets, AP10 dropped for the line budget | topic and contract tests re-run: green |

## Gates (AC10)

- Full suite `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q -rs`:
  **698 passed, 56 skipped** (73 s). The skeleton's 667 passed + 24 new topic cases + 7 generic cases no
  longer skipped = 698. The 56 skips are 7 generic cases × the 8 other stubs, each with the reason
  `<file> is a stub pending <owning slug>`.
- Lint `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope`: `All checks passed!`.
- Types: none (stack.md). shellcheck: no `.sh` file changed.
- `wc -l R/nextjs/rendering-and-caching.md`: 785 lines (cap 800).
- `git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists only
  `R/nextjs/rendering-and-caching.md`, `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_rendering_and_caching.py`
  and files under `docs/sprints/bmn-nextjs-typescript-best-practices-reference/rendering-caching-and-streaming-ssr/`.

## AC9 grounding evidence

`evidence/sources-verified.md` lists the 46 URLs of the file's `## Sources`, each with the 2026-10-04 fetch date
and the rule ids it backs. The plan's one-off set-equality command (script saved as a file because the harness
refuses heredocs inside compound commands):

```text
file: 46 evidence: 46
equal: True | only in file: [] | only in evidence: []
```

All 44 nextjs.org and vercel.com pages, the security release post and the two react.dev pages were fetched live
again by the coder on 2026-10-04. Claims most likely to drift were grepped against the fetched text (see
`evidence/sources-verified.md`, Method). Every `ts` and `tsx` fence (32) was type-checked in strict mode
against the published `next@16.3.8` and `react@19` types with stand-in declarations for `PageProps`,
`LayoutProps` and the application helpers. The only diagnostic is the deliberate one-argument
`revalidateTag('posts')` in the anti-pattern Don't block (TS2554 "Expected 2 arguments"), which confirms the
documented TypeScript error.

## Assumptions

1. **Anti-pattern format follows the merged contract, not the plan's default.** The contract defines
   `### Don't …` H3 headings, each with at least one fenced block. Each heading here names its `RC-` ids, holds
   the Don't block, then a `**Do:**` marker line, then the Do block. The topic test parses exactly that shape.
2. **Nine anti-patterns, not ten.** AP10 (random value in a prerendered component) was dropped for the line
   budget (785 of 800 lines); the plan allowed this. The content stays covered by RC-17 and the
   "Non-deterministic values" pattern.
3. **Sources.** The version-source post (the security release) is the first Sources bullet, as in the stub and in
   `nextjs.md`, because the as-of line rests on it. The sheet's rendering-philosophy page (S4) is cited by no
   rule, so it is not listed. The file has 46 Sources.
4. **Not confirmed items need a prose URL (contract).** The first item names the nonexistent
   `getting-started/cache-components` path as inline code and links the Caching page it checked instead.
5. **Wording on "throws".** Only `updateTag` is documented to throw outside a Server Action (the page's own error
   example). RC-33 and the decision table say `refresh` "cannot be used" elsewhere, which is what its page says.
6. **Examples.** The webhook Route Handler uses `POST` with a signature check (the docs' example uses `GET`), still
   `revalidateTag(tag, 'max')`; the Server Action example carries the auth-check shape from the Server Actions
   guide. Application helpers (`db`, `auth`, `getProfile`, `verifyWebhook`, `postExists`, `Nav`, `List` and
   the like) are placeholders, not Next.js APIs.
7. **Tests are stricter than the plan's 15 cases (24 here):** at least 8 anti-patterns, a model label on every
   rule, RC-1 starting with "Detect", the decision table's `Call from` and `What the user sees` columns, three
   tables in Patterns, at least 10 linked version notes, and at least 12 `ts`/`tsx` fences.
8. **Defects in shared files:** none found. `nextjs.md`, the helpers and `test_nextjs_reference.py` were read-only
   and the contract matched the plan apart from item 1.
9. **No migrations, env vars, Vercel or Supabase work** (stack.md: no UI, no Supabase, no Vercel). `deploy_pending: []`.

## TEST1 content

Run 2026-10-04 on a detached worktree at `origin/dev` `59279a3` (branch `wip/nextjs-typescript-best-practices-reference/tests-content-1`). This repo ships Markdown, so the black-box surface is the content: live sources, and the TypeScript snippets compiled in a real Next.js 16.3.8 project. File under test: `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/rendering-and-caching.md`.

### 1. Live sources

Command (per URL, 8 in parallel): `curl -sL -A <desktop browser UA> --max-time 20 --max-redirs 10 -o /dev/null -w "%{http_code}|%{url_effective}|%{num_redirects}" <url>`. A URL passes only when the final status is 2xx and the final URL is the same page (host without `www.`, path without trailing slash). Scope: every URL in the `## Sources` section.

Result: **46 URLs, 46 pass, 0 fail**. (Across all ten files: 283 unique URLs, 283 pass, 0 fail; every one returned HTTP 200 with no redirect.)

| URL | HTTP | Redirects | Result |
| --- | --- | --- | --- |
| https://nextjs.org/blog/next-16 | 200 | 0 | pass |
| https://nextjs.org/blog/next-16-3 | 200 | 0 | pass |
| https://nextjs.org/blog/september-2026-security-release | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/cacheComponents | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/partialPrefetching | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/directives/use-cache | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/directives/use-cache-private | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/directives/use-cache-remote | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/directives/use-client | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/loading | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/page | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/dynamicParams | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/instant | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/cacheLife | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/cacheTag | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/connection | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/cookies | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/fetch | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/headers | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/io | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/refresh | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/revalidatePath | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/revalidateTag | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/unstable_cache | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/unstable_noStore | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/updateTag | 200 | 0 | pass |
| https://nextjs.org/docs/app/getting-started/caching | 200 | 0 | pass |
| https://nextjs.org/docs/app/getting-started/fetching-data | 200 | 0 | pass |
| https://nextjs.org/docs/app/getting-started/revalidating | 200 | 0 | pass |
| https://nextjs.org/docs/app/getting-started/server-and-client-components | 200 | 0 | pass |
| https://nextjs.org/docs/app/glossary | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/caching-without-cache-components | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/how-revalidation-works | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/incremental-static-regeneration | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/incremental-static-regeneration-cache-components | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/migrating-to-cache-components | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/server-actions | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/server-and-client-boundary | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/streaming | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/upgrading/version-15 | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/upgrading/version-16 | 200 | 0 | pass |
| https://react.dev/reference/react/Suspense | 200 | 0 | pass |
| https://react.dev/reference/rsc/use-client | 200 | 0 | pass |
| https://vercel.com/docs/caching/runtime-cache | 200 | 0 | pass |
| https://vercel.com/docs/frameworks/full-stack/nextjs | 200 | 0 | pass |

### 2. Snippet type-check

Method (same for every story; the scratch project lives outside the repo and is not committed):

- Scratch dir `/private/tmp/claude-501/-Users-jonathanstevenson-Source-claude-skills/b71aefe4-ae21-4000-aa3e-8b70fbcfbe94/scratchpad/tscheck-test1/w1/app`, `npm install --save-exact next@16.3.8 react react-dom typescript@7.0.2 @types/react @types/react-dom @types/node zod server-only client-only vitest @playwright/test @testing-library/react vite-tsconfig-paths @vitejs/plugin-react shiki jose ai @vercel/otel @vercel/firewall @opentelemetry/api` (resolved: next 16.3.8, react and react-dom 19.3.0, typescript 7.0.2, @types/react and @types/react-dom 19.3.0, @types/node 26.6.4, zod 4.6.5, server-only 0.0.1, client-only 0.0.1, vitest 5.0.3, @playwright/test 1.63.0, @testing-library/react 16.3.3, vite-tsconfig-paths 6.1.1, @vitejs/plugin-react 6.1.1, shiki 4.5.0, jose 6.2.12, ai 7.0.127, @vercel/otel 2.1.3, @vercel/firewall 1.2.5, @opentelemetry/api 1.9.1; all from npm). typescript 6.0.3 and 5.9.3 were installed beside it for the cross-check and the parse pass.
- Every ```` ```ts ```` and ```` ```tsx ```` fence of the ten files was extracted (218 fences: 160 Do/Pattern/rule, 58 inside the Don't half of an Anti-patterns entry). Each doc becomes one virtual Next.js project under `app/proj/<doc>/`: a fence whose first line is a `// path/to/file.ts` comment is written at that path (first occurrence only, Don't halves never), so `@/` and relative imports between fences resolve to the real fence; every other fence is its own module under `_loose/`. `next typegen` runs per project so the global `PageProps`, `LayoutProps` and `RouteContext` types exist; dummy `page.tsx`, `layout.tsx`, `route.ts` and `@slot` files are created for the route literals the fences use.
- Compiler config: the doc's own P1 `tsconfig.json` (`strict: true`, `noUncheckedIndexedAccess`, `lib: ES2020`, `moduleResolution: bundler`, ...) with `paths` `@/*` -> `./*` and `./src/*`; command `node node_modules/typescript/bin/tsc --noEmit --pretty false -p tsconfig.json` (TypeScript 7.0.2) in each project. Cross-checks: TypeScript 6.0.3 with the same config, and TypeScript 7.0.2 with the `create-next-app` default compilerOptions (`strict`, `target ES2017`, `lib dom/dom.iterable/esnext`).
- Prelude (declared, never silent): a fence that is a fragment gets only (a) `export {}` when it has no import or export, (b) a wrapper `async function __fragment() {` ... `}` when it is a bare statement list (TS1108 `return` outside a function), (c) an `import` of a well-known Next.js, React or Zod name (`z`, `redirect`, `notFound`, `revalidateTag`, `updateTag`, `cookies`, `Suspense`, ...) that the fence uses but does not import, (d) `declare var name: any` for any other free name the fence uses but does not define, (e) an any-typed stub module for a local `@/` or `./` import that no fence in the doc defines, (f) a typed export on the doc's own module when the doc says the module holds more than it shows. The records below say which fence got which.
- A fence with a parse error cannot be typechecked, so it is parked outside the project and reported on its own.

Result for `rendering-and-caching.md`: **32 fences = 23 Do/Pattern/rule + 9 Don't half. Do/Pattern/rule: 23 pass, 0 fail.**

Cross-checks for this file: TypeScript 6.0.3 with the same config reports 0 Do-fence error(s); TypeScript 7.0.2 with the `create-next-app` default compilerOptions reports 0.

#### Failures (Do/Pattern/rule fences)

None.

#### Pass with a declared prelude that deserves a look

None.

#### Prelude record

- 10 of 23 Do/Pattern/rule fences begin with a `// path` comment and sit at that path in the virtual project; the other 13 are standalone modules under `_loose/`.
- `export {}` was appended to 0 fences that had no import or export (fences none); that only makes the fragment a module so names do not collide.
- Other preludes (Do/Pattern/rule fences only):

| Fence | Prelude |
| --- | --- |
| #02 (line 107) Cache data with a lifetime and a tag | any-typed stub module: `lib/db.ts` |
| #04 (line 168) Pass runtime values into a cache as arguments | any-typed stub module: `lib/profile.ts` |
| #05 (line 198) Push dynamic access down to widen the static shell | any-typed stub module: `app/shop/[slug]/sidebar.ts` |
| #08 (line 267) Server and Client composition | any-typed stub module: `app/ui/cart.ts` |
| #11 (line 323) Invalidate after a write | any-typed stub module: `lib/db.ts`, `lib/auth.ts` |
| #12 (line 350) Invalidate after a write | any-typed stub module: `lib/webhooks.ts` |
| #13 (line 371) Return a real 404 before streaming starts | any-typed stub module: `app/post/[slug]/post-content.ts`, `lib/posts.ts` |
| #16 (line 447) Don't mark a whole page `'use client'` for one widget (RC-5) | any-typed stub module: `_loose/product-details.ts`, `_loose/quantity-picker.ts` |
| #20 (line 498) Don't import a Server Component into a `'use client'` file (RC-8) | any-typed stub module: `_loose/cart.ts`, `_loose/modal.ts` |
| #22 (line 525) Don't read `cookies()` inside `'use cache'` (RC-23) | free names declared `any`: `List`, `getRecommendations` |
| #24 (line 556) Don't await `cookies()` at the top of a layout under Cache Components (RC-16) | any-typed stub module: `_loose/nav.ts` |
| #28 (line 627) Don't decide "not found" after streaming started (RC-40) | free names declared `any`: `postExists`, `PostContent` |
| #30 (line 652) Don't keep route segment caching config with `cacheComponents` on (RC-2) | free names declared `any`: `getData` |
| #32 (line 676) Don't nest a short-lived cache in `'use cache'` without an explicit `cacheLife` (RC-22) | any-typed stub module: `components/short-lived-widget.ts` |

#### Don't half (expected to be wrong; recorded, not failed)

| Fence | Outcome |
| --- | --- |
| #15 (line 429) Don't mark a whole page `'use client'` for one widget (RC-5) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #17 (line 463) Don't pass a plain function from a Server Component (RC-7) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #19 (line 487) Don't import a Server Component into a `'use client'` file (RC-8) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #21 (line 513) Don't read `cookies()` inside `'use cache'` (RC-23) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #23 (line 543) Don't await `cookies()` at the top of a layout under Cache Components (RC-16) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #25 (line 583) Don't call `updateTag` or a one-argument `revalidateTag` in a Route Handler (RC-32, RC-33) | type error as intended: TS2554 Expected 2 arguments, but got 1. |
| #27 (line 606) Don't decide "not found" after streaming started (RC-40) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #29 (line 640) Don't keep route segment caching config with `cacheComponents` on (RC-2) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #31 (line 665) Don't nest a short-lived cache in `'use cache'` without an explicit `cacheLife` (RC-22) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
