# Validation — data-fetching-server-actions-and-forms

Branch `wip/nextjs-typescript-best-practices-reference/data-fetching-server-actions-and-forms`, cut from
`origin/feat/nextjs-typescript-best-practices-reference` (fetched first). Date: 2026-10-04.
Owned files: `references/nextjs/data-fetching-and-mutations.md` (`DF`),
`assets/tests/test_nextjs_topic_data_fetching_and_mutations.py`, and this folder.

## TDD record

| Step | Command | Result |
| --- | --- | --- |
| RED | `pytest .../test_nextjs_topic_data_fetching_and_mutations.py` against the stub | 18 collected, **18 failed**, 0 passed. Reasons: `is_stub` is true; `## Rules`, `## Patterns`, `## Anti-patterns`, `## Version notes` and `## Review checklist` don't exist (`LookupError: no heading` or empty tuples); no rules, terms, examples, checklist or Don't/Do pairs. Two tests first passed vacuously on empty input (no `any` found, no checklist ids), so they were tightened to assert that something is there, then failed too. |
| GREEN | same file plus `test_nextjs_reference.py` | topic file written: 147 passed, 56 skipped. The 56 are the 8 other stubs times 7 generic cases; nothing skips for `data-fetching-and-mutations.md`. |
| First GREEN attempt | same | 1 failure: the file was 845 lines against the 800 cap. Fixed by compacting citation lines, dropping pattern P10 and the React 19.2 version bullet, and simplifying two anti-pattern blocks (file is now 780 lines). |
| Full suite | `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q` | **692 passed, 56 skipped, 0 failed** (70 s). The skeleton's 667 passed + 63 skipped became 667 + 18 topic cases + 7 generic cases un-skipped = 692, and 63 - 7 = 56. |
| Lint | `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` | `All checks passed!` |
| Types | none (stack.md) | n/a |

## AC10 scope

`git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists exactly:

```text
Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_data_fetching_and_mutations.py
Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/data-fetching-and-mutations.md
docs/sprints/bmn-nextjs-typescript-best-practices-reference/data-fetching-server-actions-and-forms/evidence/sources-verified.md
docs/sprints/bmn-nextjs-typescript-best-practices-reference/data-fetching-server-actions-and-forms/validation.md
```

No shared file (`nextjs.md`, helpers, `test_nextjs_reference.py`, wiring files) and no other topic file changed.

## AC9 grounding evidence

`evidence/sources-verified.md` lists the 39 URLs of the file's `## Sources`, each with fetch date 2026-10-04 and
the rule ids or sections that cite it. Every page was fetched live in this run (the `.md` rendering for
nextjs.org, vercel.com and react.dev; HTML for zod.dev) and every one returned HTTP 200. The one-off set check
(not a permanent test) compares `source_urls(topic)` with the URLs in the evidence file:

```text
cited: 39 listed: 39
only cited: []
only listed: []
table rows: 39 with 2026-10-04: 39
exit=0
```

The plan's own rule sheet was checked quote by quote against the fetched pages. The differences are listed at
the end of the evidence file ("Claims reworded, added or dropped after the live read").

## Gates not applicable

- Supabase: `supabase: false`, no migration files, no `supabase start` / `db reset` needed.
- Env vars: none created. `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY` appears only as documented guidance in DF-27.
- Browser tests: `ui: false`, no Playwright.
- shellcheck: no `.sh` file changed.
- Deploy: nothing to deploy (`deploy_pending: []`).

## Assumptions

1. **Contract wins over the plan's default syntax.** The skeleton contract defines an anti-pattern as a
   `### Don't <title>` H3 with at least one fenced block, so each of the 8 anti-patterns is one such H3. Inside it
   the Don't block follows a `**Don't:**` line and the Do block follows a `**Do:**` line, each followed directly by
   a `ts`/`tsx` fence. The topic test `test_every_dont_is_paired_with_a_do` enforces that shape and that each
   anti-pattern names a `DF-` rule. The plan's `- **Don't:**` bullet syntax was not used.
2. **Test count.** The plan said 14 test functions and 18 cases but its table listed 13 functions and 17 cases.
   The 14th is `test_redirect_rule_says_outside_try_and_after_revalidation`, which asserts one rule ties
   `redirect(` to `try`, revalidation and "outside" (a stronger form of AC6). Total: 14 functions, 18 cases.
3. **Rules in two H3 groups.** `## Rules` has `### Reading data` and `### Mutating data` H3s. The contract allows
   H3s inside a section, and rule numbers run 1 to 28 across both. The shared helpers append such a heading line to
   the preceding rule's item text, which no test is affected by.
4. **Pattern P10 dropped.** The `next/form` search-form example was removed to keep the file under the 800-line
   cap with headroom (780 lines). It was not one of the five required examples, and DF-18 still states the rule
   and cites its page.
5. **Snippet corrections against the live pages.** `.trim()` was removed from the Zod schemas, because zod.dev
   pages cited in Sources don't show it, and no cited page confirms how it combines with `.min()`. Everything
   else in the snippets follows the cited pages. Snippets are not compiled (no Next.js project here), and REVIEW
   spot-checks them against the links.
6. **Illustrative modules.** `verifySession` follows the Authentication guide's DAL helper. `@/lib/dal/*`,
   `@/lib/dto`, `@/lib/audit` and `canDeleteRecords` are placeholders, which the Patterns intro says.
7. **Rule changes from the plan sheet** (each recorded in the evidence file): DF-1 lost an unconfirmed
   "no Client Component effects" prohibition; DF-12 allows the check inside the DAL and says "cookies or headers";
   DF-16 words `refresh(` as the page does; DF-18 separates Server Component and Client Component progressive
   enhancement; DF-21 tags the separate-module advice `(convention)`; DF-24 dropped "or in a Route Handler"; DF-25
   scopes the Vercel claim to request cancellation; DF-26 says `allowedOrigins` matters only when the proxy
   doesn't forward the public host.
8. **Version notes.** The v16 upgrade guide lists no other Server Action change; the 16.1 post and the September
   2026 security release were also grepped and name none. Next.js 15 carry-overs are labelled as such.
9. **No defects found in shared files.** `test_nextjs_reference.py` and `nextjs_doc_helpers.py` accepted the file
   unchanged.

## TEST1: unit (2026-10-04)

Branch `wip/nextjs-typescript-best-practices-reference/tests-unit-1`, cut from the detached run base `origin/dev` `59279a3` (the run branch tip after
the wave-2 merges, with origin/dev merged in). Tester: `tests-unit-1`. No code was changed; this is a
verification pass.

### Commands and results

| Step | Command | Result |
| --- | --- | --- |
| Full suite with coverage | `uv run --quiet --with pytest --with pytest-cov python -m pytest Skills/dev-bother-me-nope/assets/tests -q --cov=Skills/dev-bother-me-nope/assets/tests --cov-report=term` | **1026 passed in 95.32s (0:01:35)**, exit 0, 0 failed, 0 skipped. Log: `docs/sprints/bmn-nextjs-typescript-best-practices-reference/nextjs-standard-entry-point-and-skill-wiring/evidence/test1-unit-full-suite.txt` |
| Lint | `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` | `All checks passed!` |
| Story tests, verbose | `pytest test_nextjs_topic_data_fetching_and_mutations.py test_nextjs_reference.py ... -v` (483 tests across the nextjs files and `test_skill_text_rules.py`) | 483 PASSED, 0 other. The tests this map cites are listed in `evidence/test1-unit-results.txt` |
| TERMS and example needles | one-off script comparing this story's criterion 3 and 4 lists with the test | story TERMS (22) equal the test's TERMS (22), same order: True; story example needles missing from the test source: 0 |
| URL sets | one-off script comparing `## Sources` of `references/nextjs/data-fetching-and-mutations.md` with the URLs in `evidence/sources-verified.md` | 39 cited, 39 listed, nothing only in one of them. All 39 evidence rows carry fetch date 2026-10-04 and a non-empty Backs cell |
| Scope | one-off `git diff --name-only <merge>^1 <merge>` for this story's merge `57dd82b` | 4 files, all inside the story scope (the topic file, `test_nextjs_topic_data_fetching_and_mutations.py`, and files under `docs/sprints/bmn-nextjs-typescript-best-practices-reference/data-fetching-server-actions-and-forms/`); outside scope: none |

### Coverage

- `references/nextjs/data-fetching-and-mutations.md`: Markdown, coverage n/a. It is exercised by the generic contract tests and by `test_nextjs_topic_data_fetching_and_mutations.py`; the file is 28 rules, 781 lines (cap 800).
- `nextjs_doc_helpers.py` (shared parser the tests use): **99%** (243 of 245 statements). Uncovered: line 180 (an unterminated code fence at end of file) and line 294 (`h1` of an empty file). Target 80% met.
- `test_nextjs_topic_data_fetching_and_mutations.py`: **100%** (85 of 85 statements). Whole suite: **99%** (3604 of 3635).

### Criterion map

All [unit] criteria of `story.md`, mapped to the test or one-off check that covers them. The generic
contract tests are the ones `test_nextjs_reference.py` runs for every topic file; none is skipped
(the suite has no skips), so each ran on `data-fetching-and-mutations.md`.

| AC | Criterion | Covering test(s) / check | Result |
| --- | --- | --- | --- |
| 1 | Contract | generic contract tests (17 x `[data-fetching-and-mutations.md]` + `test_rule_ids_are_unique_across_topic_files`)<br>`test_topic_uses_only_df_rule_ids` | PASS |
| 2 | Not a stub, at least 15 DF rules | `test_topic_is_not_a_stub`<br>`test_topic_has_at_least_15_df_rules` | PASS |
| 3 | Required terms | `test_topic_names_every_required_concept` | PASS |
| 4 | Examples (Promise.all, use server+safeParse, useActionState, useOptimistic, cache(); no `any`) | `test_topic_has_required_example`<br>`test_examples_never_use_any` | PASS |
| 5 | Every `'use server'` block calls an auth check; links proxy-auth-and-security.md | `test_every_use_server_block_calls_an_auth_check`<br>`test_mutation_examples_link_the_security_topic` | PASS |
| 6 | `redirect` and `try` rule in `## Rules` | `test_rules_state_redirect_outside_try_catch`<br>`test_redirect_rule_says_outside_try_and_after_revalidation` | PASS |
| 7 | Version notes name the major and link nextjs.org | `test_version_notes_name_the_major_and_link_nextjs` | PASS |
| 8 | Reviewer-ready | `test_every_checklist_item_names_a_df_rule`<br>`test_checklist_rule_ids_exist`<br>`test_every_dont_is_paired_with_a_do` | PASS |
| 9 | Grounding evidence (one-off) | one-off set-equality check, see below | PASS |
| 10 | Scope and gates (one-off + suite + ruff) | one-off `git diff --name-only` check, full suite, ruff (see below) | PASS |

**Totals:** 10 PASS, 0 FAIL, 0 uncovered.

### TEST1 assumptions

1. AC9 (grounding evidence) is a one-off check by design ("not a permanent test"). It was re-run here with the plan's set-equality method and passed.
2. AC10 scope is checked against the story's merge into the run branch (`git diff --name-only <merge>^1 <merge>`), because `origin/feat/...` has since moved on. The suite and ruff are checked on the final tree.
3. Where the criterion text asks for content beyond what its test asserts (for example, the shape of an example), the test is taken as the verification the story names; factual correctness of the claims against nextjs.org and vercel.com is the REVIEW① lens, not a unit test.

## TEST1 content

Run 2026-10-04 on a detached worktree at `origin/dev` `59279a3` (branch `wip/nextjs-typescript-best-practices-reference/tests-content-1`). This repo ships Markdown, so the black-box surface is the content: live sources, and the TypeScript snippets compiled in a real Next.js 16.3.8 project. File under test: `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/data-fetching-and-mutations.md`.

### 1. Live sources

Command (per URL, 8 in parallel): `curl -sL -A <desktop browser UA> --max-time 20 --max-redirs 10 -o /dev/null -w "%{http_code}|%{url_effective}|%{num_redirects}" <url>`. A URL passes only when the final status is 2xx and the final URL is the same page (host without `www.`, path without trailing slash). Scope: every URL in the `## Sources` section.

Result: **39 URLs, 39 pass, 0 fail**. (Across all ten files: 283 unique URLs, 283 pass, 0 fail; every one returned HTTP 200 with no redirect.)

| URL | HTTP | Redirects | Result |
| --- | --- | --- | --- |
| https://nextjs.org/blog/next-16 | 200 | 0 | pass |
| https://nextjs.org/blog/next-16-2 | 200 | 0 | pass |
| https://nextjs.org/blog/next-16-3 | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/components/form | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/directives/use-server | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/after | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/fetch | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/redirect | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/refresh | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/revalidatePath | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/revalidateTag | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/updateTag | 200 | 0 | pass |
| https://nextjs.org/docs/app/getting-started/error-handling | 200 | 0 | pass |
| https://nextjs.org/docs/app/getting-started/fetching-data | 200 | 0 | pass |
| https://nextjs.org/docs/app/getting-started/mutating-data | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/authentication | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/backend-for-frontend | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/client-side-data-fetching | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/data-security | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/forms | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/interactive-apps | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/offline-support | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/server-actions | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/upgrading/version-15 | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/upgrading/version-16 | 200 | 0 | pass |
| https://react.dev/reference/react-dom/components/form | 200 | 0 | pass |
| https://react.dev/reference/react-dom/hooks/useFormStatus | 200 | 0 | pass |
| https://react.dev/reference/react/cache | 200 | 0 | pass |
| https://react.dev/reference/react/use | 200 | 0 | pass |
| https://react.dev/reference/react/useActionState | 200 | 0 | pass |
| https://react.dev/reference/react/useOptimistic | 200 | 0 | pass |
| https://react.dev/reference/react/useTransition | 200 | 0 | pass |
| https://react.dev/reference/rsc/server-functions | 200 | 0 | pass |
| https://react.dev/reference/rsc/use-server | 200 | 0 | pass |
| https://vercel.com/docs/functions/functions-api-reference | 200 | 0 | pass |
| https://zod.dev/basics | 200 | 0 | pass |
| https://zod.dev/error-formatting | 200 | 0 | pass |
| https://zod.dev/v4/changelog | 200 | 0 | pass |

### 2. Snippet type-check

Method (same for every story; the scratch project lives outside the repo and is not committed):

- Scratch dir `/private/tmp/claude-501/-Users-jonathanstevenson-Source-claude-skills/b71aefe4-ae21-4000-aa3e-8b70fbcfbe94/scratchpad/tscheck-test1/w1/app`, `npm install --save-exact next@16.3.8 react react-dom typescript@7.0.2 @types/react @types/react-dom @types/node zod server-only client-only vitest @playwright/test @testing-library/react vite-tsconfig-paths @vitejs/plugin-react shiki jose ai @vercel/otel @vercel/firewall @opentelemetry/api` (resolved: next 16.3.8, react and react-dom 19.3.0, typescript 7.0.2, @types/react and @types/react-dom 19.3.0, @types/node 26.6.4, zod 4.6.5, server-only 0.0.1, client-only 0.0.1, vitest 5.0.3, @playwright/test 1.63.0, @testing-library/react 16.3.3, vite-tsconfig-paths 6.1.1, @vitejs/plugin-react 6.1.1, shiki 4.5.0, jose 6.2.12, ai 7.0.127, @vercel/otel 2.1.3, @vercel/firewall 1.2.5, @opentelemetry/api 1.9.1; all from npm). typescript 6.0.3 and 5.9.3 were installed beside it for the cross-check and the parse pass.
- Every ```` ```ts ```` and ```` ```tsx ```` fence of the ten files was extracted (218 fences: 160 Do/Pattern/rule, 58 inside the Don't half of an Anti-patterns entry). Each doc becomes one virtual Next.js project under `app/proj/<doc>/`: a fence whose first line is a `// path/to/file.ts` comment is written at that path (first occurrence only, Don't halves never), so `@/` and relative imports between fences resolve to the real fence; every other fence is its own module under `_loose/`. `next typegen` runs per project so the global `PageProps`, `LayoutProps` and `RouteContext` types exist; dummy `page.tsx`, `layout.tsx`, `route.ts` and `@slot` files are created for the route literals the fences use.
- Compiler config: the doc's own P1 `tsconfig.json` (`strict: true`, `noUncheckedIndexedAccess`, `lib: ES2020`, `moduleResolution: bundler`, ...) with `paths` `@/*` -> `./*` and `./src/*`; command `node node_modules/typescript/bin/tsc --noEmit --pretty false -p tsconfig.json` (TypeScript 7.0.2) in each project. Cross-checks: TypeScript 6.0.3 with the same config, and TypeScript 7.0.2 with the `create-next-app` default compilerOptions (`strict`, `target ES2017`, `lib dom/dom.iterable/esnext`).
- Prelude (declared, never silent): a fence that is a fragment gets only (a) `export {}` when it has no import or export, (b) a wrapper `async function __fragment() {` ... `}` when it is a bare statement list (TS1108 `return` outside a function), (c) an `import` of a well-known Next.js, React or Zod name (`z`, `redirect`, `notFound`, `revalidateTag`, `updateTag`, `cookies`, `Suspense`, ...) that the fence uses but does not import, (d) `declare var name: any` for any other free name the fence uses but does not define, (e) an any-typed stub module for a local `@/` or `./` import that no fence in the doc defines, (f) a typed export on the doc's own module when the doc says the module holds more than it shows. The records below say which fence got which.
- A fence with a parse error cannot be typechecked, so it is parked outside the project and reported on its own.

Result for `data-fetching-and-mutations.md`: **30 fences = 22 Do/Pattern/rule + 8 Don't half. Do/Pattern/rule: 22 pass, 0 fail.**

Cross-checks for this file: TypeScript 6.0.3 with the same config reports 0 Do-fence error(s); TypeScript 7.0.2 with the `create-next-app` default compilerOptions reports 0.

#### Failures (Do/Pattern/rule fences)

None.

#### Pass with a declared prelude that deserves a look

None.

#### Prelude record

- 14 of 22 Do/Pattern/rule fences begin with a `// path` comment and sit at that path in the virtual project; the other 8 are standalone modules under `_loose/`.
- `export {}` was appended to 6 fences that had no import or export (fences #16, #22, #24, #26, #28, #30); that only makes the fragment a module so names do not collide.
- Other preludes (Do/Pattern/rule fences only):

| Fence | Prelude |
| --- | --- |
| #01 (line 183) P1 Parallel fetching in an async Server Component (DF-4) | any-typed stub module: `lib/dal/artists.ts`, `app/artist/[username]/albums.ts` |
| #02 (line 206) P2 Request-scoped deduplication with React `cache` in the DAL (DF-2, DF-6) | any-typed stub module: `lib/db.ts`, `lib/dto.ts` |
| #03 (line 223) P3 Preload before blocking work (DF-7) | any-typed stub module: `lib/dal/items.ts` |
| #04 (line 237) P3 Preload before blocking work (DF-7) | any-typed stub module: `lib/dal/items.ts` |
| #05 (line 252) P4 Stream a promise to a Client Component with `use(` (DF-8) | any-typed stub module: `lib/dal/comments.ts` |
| #06 (line 269) P4 Stream a promise to a Client Component with `use(` (DF-8) | any-typed stub module: `lib/dto.ts` |
| #08 (line 305) P5 Validate `FormData`, return typed state, invalidate, then redirect (DF-12 to DF-17, DF-21) | any-typed stub module: `lib/dal/session.ts`, `lib/dal/posts.ts` |
| #11 (line 398) P7 Extra arguments with `.bind(` (DF-13, DF-19) | any-typed stub module: `lib/dal/session.ts` |
| #13 (line 447) P8 Optimistic toggle from an event handler (DF-16, DF-22, DF-23) | any-typed stub module: `lib/dal/session.ts`, `lib/dal/likes.ts` |
| #14 (line 467) P9 Post-response work with `after(` in a Server Action (DF-15, DF-25) | any-typed stub module: `lib/dal/session.ts`, `lib/dal/posts.ts`, `lib/audit.ts` |
| #16 (line 507) Don't await independent requests one after another | free names declared `any`: `getArtist`, `username`, `getAlbums` |
| #18 (line 526) Don't fetch your own Route Handler from a Server Component | any-typed stub module: `lib/dal/posts.ts` |
| #20 (line 551) Don't check the session only in the page | free names declared `any`: `verifySession`, `canDeleteRecords`, `db` |
| #22 (line 581) Don't call `redirect(` inside `try`/`catch` | wrapped in `async function __fragment()`; import added: `revalidatePath` from `next/cache`, `redirect` from `next/navigation`; free names declared `any`: `createPost`, `userId`, `data` |
| #24 (line 603) Don't throw expected errors or return raw records | wrapped in `async function __fragment()`; import added: `z` from `zod`; free names declared `any`: `parsed`, `updatePost`, `userId`, `id` |
| #26 (line 624) Don't use a Server Action to fetch data | import added: `Suspense` from `react`; free names declared `any`: `Posts`, `getPosts` |
| #28 (line 643) Don't call `revalidateTag` with one argument | import added: `updateTag` from `next/cache`, `revalidateTag` from `next/cache` |
| #30 (line 661) Don't copy Zod 3 error APIs into Zod 4 | import added: `z` from `zod`; free names declared `any`: `input` |

- Typed prelude on `data-fetching-and-mutations#02`: typed export `updateUserName(userId: string, name: string): Promise<void>` added to `lib/dal/users.ts`, which fence #11 imports but #02 does not show.

#### Don't half (expected to be wrong; recorded, not failed)

| Fence | Outcome |
| --- | --- |
| #15 (line 500) Don't await independent requests one after another | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #17 (line 519) Don't fetch your own Route Handler from a Server Component | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #19 (line 538) Don't check the session only in the page | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #21 (line 570) Don't call `redirect(` inside `try`/`catch` | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #23 (line 596) Don't throw expected errors or return raw records | type error as intended: TS18004 No value exists in scope for the shorthand property 'id'. Either declare one or provide an initializer. |
| #25 (line 615) Don't use a Server Action to fetch data | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #27 (line 637) Don't call `revalidateTag` with one argument | type error as intended: TS2554 Expected 2 arguments, but got 1. |
| #29 (line 654) Don't copy Zod 3 error APIs into Zod 4 | type error as intended: TS2769 No overload matches this call. |

## FIX①

Branch `wip/nextjs-typescript-best-practices-reference/data-fetching-server-actions-and-forms-fix`, cut from `origin/feat/nextjs-typescript-best-practices-reference` (`8188c54`). Date 2026-10-04. Items: R1-B4, R1-B13 and this file's side of R1-B15 (REVIEW① table in `../review.md`). Files touched: `references/nextjs/data-fetching-and-mutations.md`, `assets/tests/test_nextjs_topic_data_fetching_and_mutations.py` (new tests appended at the end; the `ANY_TYPE` and `major()` lines are untouched), and this story folder (`validation.md`, `evidence/sources-verified.md`).

### Result per item

| id | result |
| --- | --- |
| R1-B4 | **fixed**. Failing first: `test_patterns_intro_defines_the_two_caching_models`, `test_every_pattern_names_the_caching_model_it_assumes`, `test_a_rule_sends_cache_components_params_into_suspense`, `test_cache_components_patterns_do_not_await_params_in_the_page`, `test_top_level_await_params_sits_only_in_previous_model_patterns` (all five failed before the edit, pass now). Also reproduced for real: a scratch Next.js 16.3.8 app with `cacheComponents: true` fails `next build` on the pre-fix P1 (`Route "/old/[username]": Next.js encountered uncached or runtime data during prerendering`) and on P3 (`Route "/item/[id]"`, same error). The fixed P1 and P4 build as `◐ Partial Prerender`. Without `cacheComponents` all four build (`ƒ Dynamic`). |
| R1-B13 | **fixed**. Failing first: `test_df14_forbids_returning_void_when_a_check_fails`, `test_validating_actions_return_typed_state_never_void` (P7 `updateUserNameAction ... Promise<void>` with bare `return`s, P8 `toggleLikeAction ... Promise<void>`). Both pass now. |
| R1-B15 (this file's side) | **fixed**. Failing first: `test_session_helpers_are_imported_from_the_dal_module` (`@/lib/dal/session` in P5, P7, P8, P9), `test_server_actions_live_in_src_lib_actions` (4 `'use server'` modules under `app/`), `test_snippet_paths_use_the_src_layout` (14 snippet paths without `src/`). All pass now. The other topic files' side belongs to their own fixers. |

### What changed

- **R1-B4.** The Patterns intro names the two caching models and links the Caching guide and `rendering-and-caching.md` (ids are not cited, because `test_topic_cites_only_its_own_rule_ids` forbids other topics' ids). Every pattern heading ends with `both models` or `previous model`. P1 and P4 pass the un-awaited `params` promise into `<Suspense>` (P4 uses `params.then(...)`, the shape the Caching page shows). P3 stays `previous model`, with a pointer to P1 for Cache Components. DF-5 gained the Cache Components sentence and the Caching page link, and the checklist gained a DF-5 item.
- **R1-B13.** P7 is now a `.bind(`-ed action used with `useActionState`, returning `UpdateNameState` (`{ message? }`) for a failed ownership check and for a failed `safeParse`; P8's `toggleLikeAction` returns `{ ok: true } | { ok: false; message }` and the button shows the message (the update after the `await` is wrapped in `startTransition`, per DF-22). DF-14 and its checklist item say a failed check never returns `void` or a bare `return`.
- **R1-B15.** `verifySession` and `getSession` come from `@/lib/dal` (`src/lib/dal.ts`, `server-only`; the Patterns intro describes the split and points at `proxy-auth-and-security.md`). Snippet paths use `src/`, Server Actions sit in `src/lib/actions/` (`posts.ts`, `users.ts`, `likes.ts`, `archive-post.ts`), shared schemas and state types in `src/features/<feature>/definitions.ts`. DF-11 and DF-12 say so.

### Commands and results

| Step | Command | Result |
| --- | --- | --- |
| RED | `pytest .../test_nextjs_topic_data_fetching_and_mutations.py -q` after appending 10 new tests | **10 failed, 18 passed**. Messages: `name both caching models`; `patterns whose heading names no caching model: ['P1 ...', ...]`; `no rule links the caching page and rendering-and-caching.md for params`; `no pattern is labelled for Cache Components`; `patterns awaiting params at the top without saying previous model: ['P1 ...', 'P3 ...', 'P4 ...']`; `DF-14 does not say a failed check must not return void`; `app/users/[id]/actions.ts: returns Promise<void>`; `the session helpers do not live in lib/dal/session`; `'use server' modules outside src/lib/actions/: [4 paths]`; `snippet paths without the src/ prefix: [14 paths]`. |
| GREEN (one test fix) | same file plus `test_nextjs_reference.py` | One new test failed first because the needle `Cache Components` was split across a line break in the Markdown. The test now normalises whitespace (a test bug, not a content bug). After that: **213 passed**. |
| Line cap | `wc -l references/nextjs/data-fetching-and-mutations.md` | **798** (cap 800, `test_file_is_at_most_800_lines` green). |
| Full suite | `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q` | **1036 passed** in 107 s (1026 before + the 10 new tests). |
| Lint | `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` | `All checks passed!` |
| Sources vs evidence | one-off set check (`source_urls(topic)` against the URLs in `evidence/sources-verified.md`) | `cited: 40 listed: 40`, only cited: `[]`, only listed: `[]`, 40 rows all dated 2026-10-04. The new URL `https://nextjs.org/docs/app/getting-started/caching` returns HTTP 200 with no redirect and its front matter reads `version: 16.3.8`. |

### Snippet compile (scratch, not committed)

Scratch project `/private/tmp/claude-501/-Users-jonathanstevenson-Source-claude-skills/b71aefe4-ae21-4000-aa3e-8b70fbcfbe94/scratchpad/fix1-datafetching/app`: `npm install --save-exact next@16.3.8 react react-dom typescript @types/react @types/react-dom @types/node zod server-only` (react and react-dom 19.3.0, typescript 7.0.2, zod 4.6.5). Every ts/tsx fence of `## Patterns` (14 fences) was written at its `// path` comment by `extract.py`; the DAL, DTO, DB and audit modules the snippets import are declared stubs (`src/lib/dal.ts` mirrors `proxy-auth-and-security.md`; `updateUserName` is a declared export added to the P2 module). `tsconfig.json`: `strict`, `noUncheckedIndexedAccess`, `moduleResolution: bundler`, `target ES2017`, `lib dom/dom.iterable/esnext`, `@/*` mapped to `./src/*`.

| Check | Result |
| --- | --- |
| `next typegen` then `tsc --noEmit -p tsconfig.json` (TypeScript 7.0.2) | exit 0, no output (the global `PageProps<'/artist/[username]'>`, `'/item/[id]'` and `'/posts/[id]'` resolve) |
| Same with TypeScript 5.9.3 | exit 0 |
| Negative control (a file with `const x: number = 'a'`) | exit 1, `TS2322`, so the harness does report errors |
| `next build` with `cacheComponents: true`, fixed P1 and P4 only | succeeds; both routes `◐ (Partial Prerender)` |
| Same, plus pre-fix P3 | fails: `Route "/item/[id]": Next.js encountered uncached or runtime data during prerendering` |
| Same, pre-fix P1 (from `origin/feat/...`) without P3 | fails: `Route "/old/[username]": ...` |
| `next build` without `cacheComponents`, all four pages | succeeds; all `ƒ (Dynamic)`, so "the previous model raises no blocking-route error" holds |

### FIX① assumptions

1. **Rule ids are not cited across topics.** The brief says to link `rendering-and-caching.md` RC-15 and RC-16, but `test_topic_cites_only_its_own_rule_ids` fails on any other topic's id in prose, so DF-5 and the Patterns intro link the file and the Caching page and describe the rules without ids.
2. **No new rule.** DF numbers must run consecutively and the contract test pins them, so the Cache Components `params` guidance extends DF-5 (the Suspense rule) instead of adding a rule.
3. **P3 stays previous-model.** Its body needs `id` before the blocking await, so a Cache Components version needs a child component; the file's line cap (800) made a second variant impossible. Its heading says `previous model` and points at P1. The build above shows it fails under `cacheComponents`, which is why it is labelled and not hidden.
4. **Entity modules stay at `@/lib/dal/<entity>`.** TypeScript resolves `@/lib/dal` to `src/lib/dal.ts` first and `@/lib/dal/artists` to the folder beside it (both compile above). The Patterns intro says the entity modules are illustrative.
5. **State type location.** `UpdateNameState` lives in `src/features/users/definitions.ts` (no directive), following DF-21's convention that State types stay out of `'use server'` modules.
6. **`.bind(` with `useActionState` is not in the docs together.** Recorded under "Not confirmed by the docs" (P7). It type-checks and builds; no page confirms or denies progressive enhancement for the combination.
7. **Line budget.** To stay under 800 lines two items were cut and re-verified against the contract tests: P3's `item.tsx` fence merged into `page.tsx` (the helper stays next to the component it serves, as DF-7 asks), and the "Don't call `revalidateTag` with one argument" anti-pattern removed (DF-16 and the Version notes carry the same claim, and the compiler reports it). Eight anti-patterns became seven; the floor is three.
8. **`PageProps` helper.** The three rewritten page signatures use the global `PageProps<'/route'>` helper (NN-7) instead of hand-typed `{ params: Promise<...> }`.

## TEST2 content

Run 2026-10-04 on a detached worktree at `origin/dev` `7acb627` (branch `wip/nextjs-typescript-best-practices-reference/tests-content-2`). Delta only: `references/nextjs/data-fetching-and-mutations.md` between `5d7550d` (run branch at TEST1) and `7acb627`. Everything else was TEST1's.

### 1. Live sources (delta)

No `## Sources` URL is new or changed in this file (the URL set equals TEST1's). Result: **0 URLs to check, 0 fail**.

Extended check: every URL on an added or changed line of this file, in prose and rules as well as `## Sources` (14 distinct), fetched the same way: **14 pass, 0 fail**.

### 2. Snippet type-check (delta fences)

New or changed fences (text differs from every TEST1 fence): **14 = 14 Do/Pattern/rule + 0 Don't half**.

Result: **Do/Pattern/rule: 14 pass, 0 fail.** Cross-checks with the same config: TypeScript 6.0.3 reports 0 Do-fence error(s), TypeScript 5.9.3 reports 0.

#### Failures (Do/Pattern/rule fences)

None.

#### Pass with a declared prelude that deserves a look

None.

#### Prelude record (delta fences)

- 14 of 14 Do/Pattern/rule fences begin with a `// path` comment and sit at that path in the virtual project; the other 0 are standalone modules under `_loose/`.
- `export {}` appended to 0 Do/Pattern/rule fence(s).
- Other preludes (Do/Pattern/rule fences only):

| Fence | Prelude |
| --- | --- |
| #01 (line 193) P1 Parallel fetching with `params` awaited inside `<Suspense>` (DF-4, DF-5; both models) | any-typed stub module: `src/lib/dal/artists.ts`, `src/app/artist/[username]/albums.ts` |
| #02 (line 226) P2 Request-scoped deduplication with React `cache` in the DAL (DF-2, DF-6; both models) | any-typed stub module: `src/lib/db.ts`, `src/lib/dto.ts` |
| #03 (line 245) P3 Preload before blocking work (DF-7; previous model) | any-typed stub module: `src/lib/dal/items.ts` |
| #04 (line 269) P4 Stream a promise to a Client Component with `use(` (DF-8; both models) | any-typed stub module: `src/lib/dal/comments.ts` |
| #05 (line 287) P4 Stream a promise to a Client Component with `use(` (DF-8; both models) | any-typed stub module: `src/lib/dto.ts` |
| #07 (line 323) P5 Validate `FormData`, return typed state, invalidate, then redirect (DF-12 to DF-17, DF-21; both models) | any-typed stub module: `src/lib/dal.ts`, `src/lib/dal/posts.ts` |
| #11 (line 426) P7 Extra arguments with `.bind(` and typed failure state (DF-13, DF-14, DF-19; both models) | any-typed stub module: `src/lib/dal.ts` |
| #13 (line 487) P8 Optimistic toggle from an event handler (DF-14, DF-16, DF-22, DF-23; both models) | any-typed stub module: `src/lib/dal.ts`, `src/lib/dal/likes.ts` |
| #14 (line 510) P9 Post-response work with `after(` in a Server Action (DF-15, DF-25; both models) | any-typed stub module: `src/lib/dal.ts`, `src/lib/dal/posts.ts`, `src/lib/audit.ts` |

#### Don't half (expected to be wrong; recorded, not failed)

No Don't-half fence is new or changed in this file.

### 3. Session-helper consistency (text only)

| Line | Import | From | Context |
| --- | --- | --- | --- |
| 324 | `verifySession` | `@/lib/dal` | Server Action |
| 427 | `verifySession` | `@/lib/dal` | Server Action |
| 488 | `verifySession` | `@/lib/dal` | Server Action |
| 511 | `verifySession` | `@/lib/dal` | Server Action |

- Prose rule DF-12 says to call `verifySession()` from `@/lib/dal` "(or `auth()`)": text only, no snippet imports `auth`. Recorded, not a failure. Fragments at lines 582 and 595 (Don't check the session only in the page) call `verifySession()` with no import line.

Result: **0 fail**. Each session helper is imported from `@/lib/dal`; `getSession` appears in Route Handlers and SSE/API routes, `verifySession` in Server Actions and pages.
