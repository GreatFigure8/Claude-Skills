# Validation: typescript-config-and-typing-patterns

Branch `wip/nextjs-typescript-best-practices-reference/typescript-config-and-typing-patterns`, cut
from `origin/feat/nextjs-typescript-best-practices-reference` (skeleton merged). Date: 2026-10-04.
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.

## TDD record

| Step | Command | Result |
| --- | --- | --- |
| RED | `pytest .../test_nextjs_topic_typescript.py` against the stub | 17 failed, 0 passed. Every failure is the stub: no rules, `is_stub` true, no `Patterns` or `Anti-patterns` section, no code blocks, the stub's one Source not linked in the body |
| GREEN, first draft | the topic file plus `test_nextjs_reference.py` | 145 passed, 1 failed: `test_file_is_at_most_800_lines`, 880 lines. The draft was trimmed (no rule, pattern or anti-pattern dropped) |
| GREEN | same two files, `-rs` | **146 passed, 56 skipped**. The 56 skips are the seven generic tests for each of the eight other stubs; nothing is skipped for `typescript.md` |
| Full suite | `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q` | **691 passed, 56 skipped** (69 s). Base was 667 passed, 63 skipped: +17 new tests and 7 generic tests that no longer skip |
| Lint | `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` | `All checks passed!` |

## Acceptance criteria

| AC | Evidence |
| --- | --- |
| 1 Contract | `test_nextjs_reference.py` runs every generic check on `typescript.md` with no skip and passes. `test_typescript_topic_uses_only_ts_rule_ids` passes: TS-1 to TS-34, no gap, no other prefix anywhere in the file |
| 2 Not a stub, 15 rules | `test_typescript_topic_is_not_a_stub`, `test_typescript_topic_has_at_least_15_rules` (34 rules) |
| 3 Terms | `test_typescript_topic_mentions_every_required_term` (all 20 terms, the last one with backticks) |
| 4 Examples | five `has_block_with` tests: P1 (json, `"strict": true`), P2 (`NextConfig`, `typedRoutes`), P4 (`PageProps<'/`, `await`), P6 (`RouteContext<'/`, `await`), P4 and P6 (`safeParse`); `test_typescript_topic_examples_never_use_any` scans every `Patterns` block |
| 5 Helpers and `Promise` | `test_typescript_rules_say_how_route_helpers_are_generated` (TS-5 and TS-16), `test_typescript_topic_awaits_search_params_in_tsx` (P4) |
| 6 No build-error bypass, no `any` | `test_typescript_rules_forbid_ignore_build_errors_and_ban_any` (TS-6, TS-28) |
| 7 Version notes | `test_typescript_version_notes_name_major_and_link_nextjs`. Eight bullets: all five candidates the story lists (sync access removal, `typedRoutes` status, route helpers and `next typegen`, `next lint` removal, minimum TypeScript) plus image-file promises, `revalidateTag`, runtime config, `proxy.ts` and the 16.3 CLI checker, each with its link |
| 8 Reviewer-ready | `test_typescript_review_checklist_items_cite_rule_ids` (20 items), `test_typescript_anti_patterns_pair_each_dont_with_a_do` (7 pairs, each marker followed by a fence) |
| 9 Grounding evidence | `evidence/sources-verified.md`, 41 rows. One-off check below |
| 10 Scope and gates | diff check below; full suite and ruff above |

## One-off checks

- **AC9 URL sets equal.** `python3 -c` importing `nextjs_doc_helpers`: `source_urls(topic)` and the
  URLs of the evidence table rows, both normalised with `normalize_url`. Output:
  `sources 41 evidence 41 symmetric difference []`.
- **AC10 scope.** `git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD`
  on the code commits lists exactly `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_typescript.py`
  and `R/nextjs/typescript.md`. The docs commit adds only files under this story folder.
- **Every Source is used.** `test_typescript_every_source_is_linked_in_the_body` (permanent) checks
  that each `## Sources` URL is linked in the body, so no Source is decoration.
- **Line count.** `typescript.md` is 787 lines (cap 800).

## Snippet check beyond the plan

The plan said snippets are not compiled. They were compiled anyway, outside the repo, in a scratch
project under the session scratchpad (nothing committed). Next.js 16.3.8, TypeScript 5.9.3, Zod
4.6.5, `@types/react` 19, `@types/node` 22, `server-only`.

- `next typegen && tsc --noEmit` with P1 as the `tsconfig.json`: P2 to P10 and the Do snippets of
  anti-patterns 1, 2, 4, 5 and 6 compile with no error. The files were laid out as the snippets
  assume (`src/app/blog/[slug]/page.tsx`, `src/app/users/[id]/route.ts`, `@analytics` slot with a
  `default.tsx`, `@/*` mapped to `./src/*`).
- The Don't snippet of anti-pattern 5 fails with `TS18046: 'error' is of type 'unknown'`, as TS-34
  says. The Don't snippet of anti-pattern 1 compiles; the file claims only that synchronous access
  was removed in Next.js 16 (upgrade guide), not that it is a type error.
- Runtime check on Zod 4.6.5: P4 falls back when `page` is a `string[]` and defaults `page` to 1 when
  it is missing; `z.flattenError().fieldErrors` is keyed by field name (P6, P7, P9); P7's message
  lists variable names and not the bad values; P8's `.parse()` throws a `ZodError`.

## Assumptions

1. The merged contract wins over the plan's format guesses, and the differences are:
   - Rules wrap across indented continuation lines instead of one physical line each, because the
     contract allows continuations and one-line rules would run past 600 characters.
   - Anti-patterns are `### Don't <title> (TS-n)` H3s, as the contract's `anti_patterns` helper
     requires; each holds one `**Don't**` fenced block and one `**Do**` fenced block.
   - `## Rules` is split with H3 group headings (the contract leaves H3s free), and rule numbers
     run on across the groups.
   - `## Not confirmed by the docs` items are bullets whose checked URLs are bare (not in code), so
     the contract's URL check sees them, and they quote no rule id.
2. One test beyond the plan's 16: `test_typescript_every_source_is_linked_in_the_body`. It is offline
   and reads only the topic file, so it respects "tests never read run folders".
3. `https://nextjs.org/blog/september-2026-security-release` stays in `## Sources`. The stub had it,
   the as-of line rests on it, and Version notes now links it. The plan's list had 40 sources; the
   file has 41. `next-config-js` (N-CFG), the `verbatimModuleSyntax` page (T-VMS) and the
   `exactOptionalPropertyTypes` page were optional in the plan and are not used.
4. Pattern 9 is three blocks, with the state type in its own module, because the `use server` page
   describes async function exports and says nothing about exporting a type from a `'use server'`
   file. That question is the twelfth item under Not confirmed by the docs. The plan's version kept
   the type in the action file.
5. To fit 800 lines the file drops secondary clauses and secondary citations of the sheet without
   changing any rule: the `.cjs`/`.cts` config note, the Vite guide as a second source on TS-1,
   TS-2, TS-3 and TS-10, the SWC-since-Next.js-12 version, the `.env.production*` exclusion of
   `typedEnv`, the `noImplicitAny` and `instanceof` citations on TS-28 and TS-34, and the Data
   Access Layer sentence under TS-24. Every claim that remains still cites its page, and nothing was
   added to a rule that the sheet does not carry.
6. TS-11 says TypeScript 5.1.0 or later (upgrade guide) and notes that async Server Components need
   5.1.3 or later (TypeScript page), because both pages state their number.
7. Grounding: 24 of the 41 pages were re-read in this session, in full or by targeted search of the
   fetched markdown; the other 17 (typescriptlang.org handbook pages, Zod, MDN, React, Vercel and a
   few nextjs.org pages) rest on the plan's verified rule sheet. The evidence file marks each row
   `yes` or `planner read only`. No claim in the sheet was contradicted. The one question raised,
   whether `export type` is allowed in a `'use server'` file, is handled by assumption 4.
8. Observation for REVIEW①, not a rule: in the scratch project, `next typegen` 16.3.8 rewrote
   `tsconfig.json` and added `.next/dev/types/**/*.ts` to `include` by itself. No docs page says so,
   so it stays under Not confirmed by the docs (second item) and P1 does not list it.
9. No defect was found in the shared files (`nextjs.md`, `nextjs_doc_helpers.py`,
   `test_nextjs_reference.py`, the wiring files); none was edited.
10. Supabase, env vars, migrations and deploys: none. `deploy_pending: []`.

## TEST1: unit (2026-10-04)

Branch `wip/nextjs-typescript-best-practices-reference/tests-unit-1`, cut from the detached run base `origin/dev` `59279a3` (the run branch tip after
the wave-2 merges, with origin/dev merged in). Tester: `tests-unit-1`. No code was changed; this is a
verification pass.

### Commands and results

| Step | Command | Result |
| --- | --- | --- |
| Full suite with coverage | `uv run --quiet --with pytest --with pytest-cov python -m pytest Skills/dev-bother-me-nope/assets/tests -q --cov=Skills/dev-bother-me-nope/assets/tests --cov-report=term` | **1026 passed in 95.32s (0:01:35)**, exit 0, 0 failed, 0 skipped. Log: `docs/sprints/bmn-nextjs-typescript-best-practices-reference/nextjs-standard-entry-point-and-skill-wiring/evidence/test1-unit-full-suite.txt` |
| Lint | `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` | `All checks passed!` |
| Story tests, verbose | `pytest test_nextjs_topic_typescript.py test_nextjs_reference.py ... -v` (483 tests across the nextjs files and `test_skill_text_rules.py`) | 483 PASSED, 0 other. The tests this map cites are listed in `evidence/test1-unit-results.txt` |
| TERMS and example needles | one-off script comparing this story's criterion 3 and 4 lists with the test | story TERMS (20) equal the test's TERMS (20), same order: True; story example needles missing from the test source: 0 |
| URL sets | one-off script comparing `## Sources` of `references/nextjs/typescript.md` with the URLs in `evidence/sources-verified.md` | 41 cited, 41 listed, nothing only in one of them. All 41 evidence rows carry fetch date 2026-10-04 and a non-empty Backs cell |
| Scope | one-off `git diff --name-only <merge>^1 <merge>` for this story's merge `9cbe6a7` | 4 files, all inside the story scope (the topic file, `test_nextjs_topic_typescript.py`, and files under `docs/sprints/bmn-nextjs-typescript-best-practices-reference/typescript-config-and-typing-patterns/`); outside scope: none |

### Coverage

- `references/nextjs/typescript.md`: Markdown, coverage n/a. It is exercised by the generic contract tests and by `test_nextjs_topic_typescript.py`; the file is 34 rules, 788 lines (cap 800).
- `nextjs_doc_helpers.py` (shared parser the tests use): **99%** (243 of 245 statements). Uncovered: line 180 (an unterminated code fence at end of file) and line 294 (`h1` of an empty file). Target 80% met.
- `test_nextjs_topic_typescript.py`: **98%** (95 of 97 statements). Whole suite: **99%** (3604 of 3635).

### Criterion map

All [unit] criteria of `story.md`, mapped to the test or one-off check that covers them. The generic
contract tests are the ones `test_nextjs_reference.py` runs for every topic file; none is skipped
(the suite has no skips), so each ran on `typescript.md`.

| AC | Criterion | Covering test(s) / check | Result |
| --- | --- | --- | --- |
| 1 | Contract | generic contract tests (17 x `[typescript.md]` + `test_rule_ids_are_unique_across_topic_files`)<br>`test_typescript_topic_uses_only_ts_rule_ids` | PASS |
| 2 | Not a stub, at least 15 TS rules | `test_typescript_topic_is_not_a_stub`<br>`test_typescript_topic_has_at_least_15_rules` | PASS |
| 3 | Required terms (`missing_terms == []`) | `test_typescript_topic_mentions_every_required_term` | PASS |
| 4 | Examples (strict json, NextConfig+typedRoutes, PageProps, RouteContext, safeParse; no `any`) | `test_typescript_topic_has_strict_tsconfig_json_block`<br>`test_typescript_topic_has_typed_next_config_block`<br>`test_typescript_topic_has_page_props_block_awaiting_params`<br>`test_typescript_topic_has_route_context_handler_block`<br>`test_typescript_topic_has_safe_parse_boundary_block`<br>`test_typescript_topic_examples_never_use_any` | PASS |
| 5 | How route helpers are generated; `searchParams` awaited in a tsx block | `test_typescript_rules_say_how_route_helpers_are_generated`<br>`test_typescript_topic_awaits_search_params_in_tsx` | PASS |
| 6 | Rules forbid `ignoreBuildErrors` and ban `any` for `unknown` | `test_typescript_rules_forbid_ignore_build_errors_and_ban_any` | PASS |
| 7 | Version notes name the major and link nextjs.org | `test_typescript_version_notes_name_major_and_link_nextjs` | PASS |
| 8 | Reviewer-ready (checklist cites `TS-`, Don't/Do pairs) | `test_typescript_review_checklist_items_cite_rule_ids`<br>`test_typescript_anti_patterns_pair_each_dont_with_a_do` | PASS |
| 9 | Grounding evidence (one-off) | one-off set-equality check, see below | PASS |
| 10 | Scope and gates (one-off + suite + ruff) | one-off `git diff --name-only` check, full suite, ruff (see below)<br>`test_typescript_every_source_is_linked_in_the_body` | PASS |

**Totals:** 10 PASS, 0 FAIL, 0 uncovered.

### TEST1 assumptions

1. AC9 (grounding evidence) is a one-off check by design ("not a permanent test"). It was re-run here with the plan's set-equality method and passed.
2. AC10 scope is checked against the story's merge into the run branch (`git diff --name-only <merge>^1 <merge>`), because `origin/feat/...` has since moved on. The suite and ruff are checked on the final tree.
3. Where the criterion text asks for content beyond what its test asserts (for example, the shape of an example), the test is taken as the verification the story names; factual correctness of the claims against nextjs.org and vercel.com is the REVIEW① lens, not a unit test.

## TEST1 content

Run 2026-10-04 on a detached worktree at `origin/dev` `59279a3` (branch `wip/nextjs-typescript-best-practices-reference/tests-content-1`). This repo ships Markdown, so the black-box surface is the content: live sources, and the TypeScript snippets compiled in a real Next.js 16.3.8 project. File under test: `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/typescript.md`.

### 1. Live sources

Command (per URL, 8 in parallel): `curl -sL -A <desktop browser UA> --max-time 20 --max-redirs 10 -o /dev/null -w "%{http_code}|%{url_effective}|%{num_redirects}" <url>`. A URL passes only when the final status is 2xx and the final URL is the same page (host without `www.`, path without trailing slash). Scope: every URL in the `## Sources` section.

Result: **41 URLs, 41 pass, 0 fail**. (Across all ten files: 283 unique URLs, 283 pass, 0 fail; every one returned HTTP 200 with no redirect.)

| URL | HTTP | Redirects | Result |
| --- | --- | --- | --- |
| https://developer.mozilla.org/en-US/docs/Web/API/Request/json | 200 | 0 | pass |
| https://nextjs.org/blog/next-15-5 | 200 | 0 | pass |
| https://nextjs.org/blog/next-16 | 200 | 0 | pass |
| https://nextjs.org/blog/next-16-3 | 200 | 0 | pass |
| https://nextjs.org/blog/september-2026-security-release | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/cli/next | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/eslint | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/typedRoutes | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/typescript | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/useTypeScriptCli | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/typescript | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/directives/use-server | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/layout | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/page | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/route | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/src-folder | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/generate-metadata | 200 | 0 | pass |
| https://nextjs.org/docs/app/getting-started/installation | 200 | 0 | pass |
| https://nextjs.org/docs/app/getting-started/server-and-client-components | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/data-security | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/environment-variables | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/forms | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/migrating/from-vite | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/upgrading/version-16 | 200 | 0 | pass |
| https://react.dev/reference/rsc/use-server | 200 | 0 | pass |
| https://vercel.com/docs/environment-variables/system-environment-variables | 200 | 0 | pass |
| https://www.typescriptlang.org/docs/handbook/2/everyday-types.html | 200 | 0 | pass |
| https://www.typescriptlang.org/docs/handbook/2/functions.html | 200 | 0 | pass |
| https://www.typescriptlang.org/docs/handbook/2/narrowing.html | 200 | 0 | pass |
| https://www.typescriptlang.org/docs/handbook/2/objects.html | 200 | 0 | pass |
| https://www.typescriptlang.org/docs/handbook/declaration-files/do-s-and-don-ts.html | 200 | 0 | pass |
| https://www.typescriptlang.org/docs/handbook/release-notes/typescript-3-9.html | 200 | 0 | pass |
| https://www.typescriptlang.org/docs/handbook/release-notes/typescript-4-9.html | 200 | 0 | pass |
| https://www.typescriptlang.org/docs/handbook/release-notes/typescript-6-0.html | 200 | 0 | pass |
| https://www.typescriptlang.org/tsconfig/ | 200 | 0 | pass |
| https://www.typescriptlang.org/tsconfig/isolatedModules.html | 200 | 0 | pass |
| https://www.typescriptlang.org/tsconfig/noUncheckedIndexedAccess.html | 200 | 0 | pass |
| https://zod.dev/api | 200 | 0 | pass |
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

Result for `typescript.md`: **21 fences = 15 Do/Pattern/rule + 6 Don't half. Do/Pattern/rule: 15 pass, 0 fail.**

Cross-checks for this file: TypeScript 6.0.3 with the same config reports 0 Do-fence error(s); TypeScript 7.0.2 with the `create-next-app` default compilerOptions reports 0.

#### Failures (Do/Pattern/rule fences)

None.

#### Pass with a declared prelude that deserves a look

None.

#### Prelude record

- 3 of 15 Do/Pattern/rule fences begin with a `// path` comment and sit at that path in the virtual project; the other 12 are standalone modules under `_loose/`.
- `export {}` was appended to 0 fences that had no import or export (fences none); that only makes the fragment a module so names do not collide.
- No other prelude was needed.

#### Don't half (expected to be wrong; recorded, not failed)

| Fence | Outcome |
| --- | --- |
| #11 (line 475) Don't read params synchronously or hand-type page props (TS-13, TS-16) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #13 (line 496) Don't cast request bodies to a type (TS-19, TS-32) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #15 (line 526) Don't skip type errors in the build (TS-5, TS-6) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #16 (line 551) Don't look up NEXT_PUBLIC_ variables dynamically (TS-25) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #18 (line 569) Don't read error.message on an untyped catch variable (TS-34) | type error as intended: TS18046 'error' is of type 'unknown'. |
| #20 (line 599) Don't type a Server Action's state as any (TS-22, TS-28) | compiles (the mistake is a runtime, security or caching rule, not a type error) |

#### JSON fences

- all five JSON fences (lines 236, 282, 537, 628, 638) parse as JSON. The three with `compilerOptions` (236, 628, 638) were also fed to `tsc --noEmit -p` as a tsconfig on 7.0.2, 6.0.3 and 5.9.3: P1 (line 236) and the Do config (line 638) exit 0 on all three; the Don't `baseUrl` config (line 628) is rejected by 7.0.2 (TS5102 `baseUrl` removed, TS5090 non-relative path) and by 6.0.3 (TS5101 deprecated) and accepted by 5.9.3, which is exactly what TS-9 and the Don't say.
