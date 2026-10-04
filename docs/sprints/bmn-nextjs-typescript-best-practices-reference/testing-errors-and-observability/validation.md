# Validation — testing-errors-and-observability

Run: `bmn-nextjs-typescript-best-practices-reference` · branch `wip/nextjs-typescript-best-practices-reference/testing-errors-and-observability` · date 2026-10-04.

Owned files: `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/testing-and-observability.md` (751 lines, 38 `TEST-` rules) and `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_testing_and_observability.py` (18 tests).

## TDD record

- RED: the topic test module was written first and run against the stub: **18 failed, 0 passed** (each failed on the stub: `is_stub` true, no `## Rules` section, no examples, no terms).
- GREEN: after the topic file replaced the stub: **18 passed**.
- Generic contract (`test_nextjs_reference.py`) with the topic file in place: all of its parametrised checks ran and passed for `testing-and-observability.md`.
- Full suite: `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q` gave **692 passed, 56 skipped**. The 56 skips are the generic checks of the eight other topic files, which are still stubs owned by parallel stories.
- Lint: `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` gave **All checks passed**. Types: none for this repo.

## Acceptance criteria

| AC | Result | Evidence |
| --- | --- | --- |
| 1 Contract, no skip | Pass | `pytest …/test_nextjs_reference.py -q -rs` prints no `SKIPPED` line naming `testing-and-observability.md` (`grep -ci` count 0). `test_rule_ids_use_only_the_test_prefix` passes. File is 751 lines (cap 800). |
| 2 Not a stub, deep enough | Pass | `test_topic_file_is_not_a_stub`; `test_topic_file_has_at_least_15_test_rules` (38 rules). |
| 3 Required concepts | Pass | `test_required_terms_are_present`: `missing_terms(text, TERMS) == []` for all 21 terms. Every term is stated in a rule or pattern that a cited page confirms; none needed the Not confirmed section. |
| 4 Examples | Pass | `defineConfig` + `jsdom` (vitest config), `defineConfig` + `webServer` (playwright config), `register` + `onRequestError` (instrumentation), `'use client'` + `<html` + `<body>` (global-error), and a segment boundary with `'use client'`, `digest` and `retry` and no `<html`. `test_typescript_examples_never_use_any` passes. |
| 5 Test surfaces | Pass | TEST-1 maps unit and browser surfaces, links `../stack-routing.md` and the testing guide, and names async Server Components; TEST-2 states the docs' limit with three links. |
| 6 Error handling | Pass | TEST-18 (expected errors as values), TEST-19 to TEST-22 (boundaries, `global-error` renders `<html>` and `<body>`). |
| 7 Version notes | Pass | `## Version notes` is headed by "Next.js 16", lists 16.0 to 16.3 with a nextjs.org link on every item, and says `register`, `onRequestError` and `instrumentation-client` are unchanged apart from the 16.3 experimental event. |
| 8 Reviewer-ready | Pass | 20 checklist items, every one names `TEST-<n>`; 7 anti-patterns, each a `### Don't:` with a `**Do:**` line and two fenced blocks. |
| 9 Grounding evidence | Pass | See the one-off URL-set check below. |
| 10 Scope and gates | Pass | See the diff-scope proof below. |

## AC9: URL sets are equal (one-off, not a permanent test)

Command from the plan, run after the topic file and `evidence/sources-verified.md` were final:

```text
EQUAL 50 50
```

The 50 `## Sources` URLs equal the 50 URLs in `evidence/sources-verified.md`. Every page was fetched live on 2026-10-04: nextjs.org and vercel.com as raw Markdown (frontmatter `version: 16.3.8`), vitest.dev and playwright.dev as HTML. The evidence file's Backs column is computed from the topic file, so it cannot drift.

## AC10: diff scope

`git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists only:

- `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_testing_and_observability.py`
- `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/testing-and-observability.md`
- files under `docs/sprints/bmn-nextjs-typescript-best-practices-reference/testing-errors-and-observability/`

## Assumptions

1. The skeleton's merged contract won over the plan wherever they differed. The differences, each following the merged `nextjs_doc_helpers.py` and `test_nextjs_reference.py`:
   - `## Sources` is a flat bullet list. The plan's grouped list with bold group headings would fail `malformed_source_lines`, so the 50 URLs sit in one list in the plan's order, each with a short note after the URL.
   - `## Not confirmed by the docs` is a bullet list with the full URLs checked, not the plan's table. The contract test reads bullet or numbered items only, and each item must hold a URL.
   - Anti-patterns use `### Don't: <title> (TEST-n)` with a `**Do:**` line, which `h.anti_patterns` parses. The topic test uses `h.anti_patterns` directly, so no `DONT_MARKER` constant exists.
   - Rules sit under five H3 groups. The merged `rule_items` parses across them, and ids run 1 to 38 without gaps.
2. Two topic tests were added beyond the plan's 16: `test_gate_commands_agree_with_stack_routing` (the orchestrator asked that `tsc --noEmit`, `eslint .` and `next build` match the stack-routing TypeScript row) and `test_gate_scripts_example_uses_eslint_never_next_lint`. `test_typescript_examples_never_use_any` also asserts that it has blocks to check, so it cannot pass on an empty file.
3. Claims reworded or dropped after re-reading the cited pages (details in `evidence/sources-verified.md`):
   - `unauthorized()` was dropped from TEST-23, because no cited page states that it throws.
   - TEST-7 no longer says Jest enforces the floor through `coverageProvider: 'v8'`, which only selects the provider. Enforcing a floor in Jest is listed under Not confirmed by the docs.
   - The plan's note that the Playwright guide's `webServer` starts "the development server" is kept as a Not confirmed item next to TEST-12.
   - The `llms-full.txt` search the plan mentioned was not repeated; the Not confirmed items cite only pages read in full this run.
4. Two items were added to Not confirmed by the docs: enforcing a coverage floor in Jest, and whether `import './globals.css'` is the documented way to style `global-error.tsx` (the Patterns show it, following the not-found.js page's `global-not-found.tsx` example).
5. Snippets are not compiled, because the repo has no Next.js project. Each was checked by hand against the cited page: `defineConfig` and `jsdom` (Vitest guide), `onRequestError` and `Instrumentation` (instrumentation.js), `catchError` and `ErrorInfo` (catchError), `ReportWebVitalsCallback` (useReportWebVitals), and `instant()` and `webServer` (their pages). The Patterns use placeholder endpoints only in code.
6. Supabase, migrations, env vars and deploys: none. The topic file only names `NEXT_RUNTIME`, `NEXT_OTEL_VERBOSE`, `NEXT_OTEL_FETCH_DISABLED`, `NODE_OPTIONS`, `CI` and, as a convention, `E2E_PORT`.

## Shared-file observations for REVIEW① (nothing here was edited)

- `references/stack-routing.md`, TypeScript / Next.js row: it says the HTTP black-box surface is "`fetch` against the running server". TEST-1 and TEST-15 say Playwright's `request` fixture against the same `webServer` (convention). Both hit the same server, and the row's gate commands (`tsc --noEmit`, `eslint .`, `next build`) agree with TEST-37. The row could name the `request` fixture.
- `references/nextjs.md` non-negotiables 9 and 10 and its 16.3 `catchError` version note agree with TEST-37, TEST-28 and TEST-24. No defect found there.
- The merged helpers and generic tests needed no change for this topic.

## TEST1: unit (2026-10-04)

Branch `wip/nextjs-typescript-best-practices-reference/tests-unit-1`, cut from the detached run base `origin/dev` `59279a3` (the run branch tip after
the wave-2 merges, with origin/dev merged in). Tester: `tests-unit-1`. No code was changed; this is a
verification pass.

### Commands and results

| Step | Command | Result |
| --- | --- | --- |
| Full suite with coverage | `uv run --quiet --with pytest --with pytest-cov python -m pytest Skills/dev-bother-me-nope/assets/tests -q --cov=Skills/dev-bother-me-nope/assets/tests --cov-report=term` | **1026 passed in 95.32s (0:01:35)**, exit 0, 0 failed, 0 skipped. Log: `docs/sprints/bmn-nextjs-typescript-best-practices-reference/nextjs-standard-entry-point-and-skill-wiring/evidence/test1-unit-full-suite.txt` |
| Lint | `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` | `All checks passed!` |
| Story tests, verbose | `pytest test_nextjs_topic_testing_and_observability.py test_nextjs_reference.py ... -v` (483 tests across the nextjs files and `test_skill_text_rules.py`) | 483 PASSED, 0 other. The tests this map cites are listed in `evidence/test1-unit-results.txt` |
| TERMS and example needles | one-off script comparing this story's criterion 3 and 4 lists with the test | story TERMS (21) equal the test's TERMS (21), same order: True; story example needles missing from the test source: 0 |
| URL sets | one-off script comparing `## Sources` of `references/nextjs/testing-and-observability.md` with the URLs in `evidence/sources-verified.md` | 50 cited, 50 listed, nothing only in one of them. All 50 evidence rows carry fetch date 2026-10-04 and a non-empty Backs cell |
| Scope | one-off `git diff --name-only <merge>^1 <merge>` for this story's merge `a5bb5b2` | 4 files, all inside the story scope (the topic file, `test_nextjs_topic_testing_and_observability.py`, and files under `docs/sprints/bmn-nextjs-typescript-best-practices-reference/testing-errors-and-observability/`); outside scope: none |

### Coverage

- `references/nextjs/testing-and-observability.md`: Markdown, coverage n/a. It is exercised by the generic contract tests and by `test_nextjs_topic_testing_and_observability.py`; the file is 38 rules, 752 lines (cap 800).
- `nextjs_doc_helpers.py` (shared parser the tests use): **99%** (243 of 245 statements). Uncovered: line 180 (an unterminated code fence at end of file) and line 294 (`h1` of an empty file). Target 80% met.
- `test_nextjs_topic_testing_and_observability.py`: **100%** (94 of 94 statements). Whole suite: **99%** (3604 of 3635).

### Criterion map

All [unit] criteria of `story.md`, mapped to the test or one-off check that covers them. The generic
contract tests are the ones `test_nextjs_reference.py` runs for every topic file; none is skipped
(the suite has no skips), so each ran on `testing-and-observability.md`.

| AC | Criterion | Covering test(s) / check | Result |
| --- | --- | --- | --- |
| 1 | Contract | generic contract tests (17 x `[testing-and-observability.md]` + `test_rule_ids_are_unique_across_topic_files`)<br>`test_rule_ids_use_only_the_test_prefix` | PASS |
| 2 | Not a stub, at least 15 TEST rules | `test_topic_file_is_not_a_stub`<br>`test_topic_file_has_at_least_15_test_rules` | PASS |
| 3 | Required terms | `test_required_terms_are_present` | PASS |
| 4 | Examples (vitest config, playwright config, instrumentation, global-error, error.tsx digest; no `any`) | `test_has_vitest_config_example`<br>`test_has_playwright_config_example`<br>`test_has_instrumentation_example`<br>`test_has_global_error_example`<br>`test_has_segment_error_boundary_example`<br>`test_typescript_examples_never_use_any` | PASS |
| 5 | Rules map onto bmn test surfaces; async Server Components limit with a testing-guide link | `test_rules_map_onto_bmn_test_surfaces`<br>`test_rules_state_async_server_component_limit_with_testing_guide_link` | PASS |
| 6 | Expected errors vs error boundaries; what `global-error` renders | `test_rules_separate_expected_errors_from_global_error` | PASS |
| 7 | Version notes name the major and link nextjs.org | `test_version_notes_name_the_major_and_link_nextjs` | PASS |
| 8 | Reviewer-ready | `test_every_review_checklist_item_names_a_rule`<br>`test_every_anti_pattern_pairs_dont_with_do` | PASS |
| 9 | Grounding evidence (one-off) | one-off set-equality check, see below | PASS |
| 10 | Scope and gates (one-off + suite + ruff) | one-off `git diff --name-only` check, full suite, ruff (see below)<br>`test_gate_commands_agree_with_stack_routing`<br>`test_gate_scripts_example_uses_eslint_never_next_lint` | PASS |

**Totals:** 10 PASS, 0 FAIL, 0 uncovered.

### TEST1 assumptions

1. AC9 (grounding evidence) is a one-off check by design ("not a permanent test"). It was re-run here with the plan's set-equality method and passed.
2. AC10 scope is checked against the story's merge into the run branch (`git diff --name-only <merge>^1 <merge>`), because `origin/feat/...` has since moved on. The suite and ruff are checked on the final tree.
3. Where the criterion text asks for content beyond what its test asserts (for example, the shape of an example), the test is taken as the verification the story names; factual correctness of the claims against nextjs.org and vercel.com is the REVIEW① lens, not a unit test.

## TEST1 content

Run 2026-10-04 on a detached worktree at `origin/dev` `59279a3` (branch `wip/nextjs-typescript-best-practices-reference/tests-content-1`). This repo ships Markdown, so the black-box surface is the content: live sources, and the TypeScript snippets compiled in a real Next.js 16.3.8 project. File under test: `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/testing-and-observability.md`.

### 1. Live sources

Command (per URL, 8 in parallel): `curl -sL -A <desktop browser UA> --max-time 20 --max-redirs 10 -o /dev/null -w "%{http_code}|%{url_effective}|%{num_redirects}" <url>`. A URL passes only when the final status is 2xx and the final URL is the same page (host without `www.`, path without trailing slash). Scope: every URL in the `## Sources` section.

Result: **50 URLs, 50 pass, 0 fail**. (Across all ten files: 283 unique URLs, 283 pass, 0 fail; every one returned HTTP 200 with no redirect.)

| URL | HTTP | Redirects | Result |
| --- | --- | --- | --- |
| https://nextjs.org/blog/next-16 | 200 | 0 | pass |
| https://nextjs.org/blog/next-16-1 | 200 | 0 | pass |
| https://nextjs.org/blog/next-16-2 | 200 | 0 | pass |
| https://nextjs.org/blog/next-16-3 | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/cli/next | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/eslint | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/logging | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/typescript | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/useTypeScriptCli | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/error | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation-client | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/not-found | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/proxy | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/route | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/catchError | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/forbidden | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/not-found | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/permanentRedirect | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/redirect | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/unstable_rethrow | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/use-report-web-vitals | 200 | 0 | pass |
| https://nextjs.org/docs/app/getting-started/error-handling | 200 | 0 | pass |
| https://nextjs.org/docs/app/getting-started/mutating-data | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/analytics | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/debugging | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/environment-variables | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/instant-navigation | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/instrumentation | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/mcp | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/open-telemetry | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/preserving-ui-state | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/production-checklist | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/testing | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/testing/cypress | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/testing/jest | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/testing/playwright | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/testing/vitest | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/upgrading/version-16 | 200 | 0 | pass |
| https://nextjs.org/docs/messages/next-dynamic-api-wrong-context | 200 | 0 | pass |
| https://playwright.dev/docs/api-testing | 200 | 0 | pass |
| https://playwright.dev/docs/test-webserver | 200 | 0 | pass |
| https://vercel.com/docs/logs/runtime | 200 | 0 | pass |
| https://vercel.com/docs/speed-insights/quickstart | 200 | 0 | pass |
| https://vercel.com/docs/tracing/instrumentation | 200 | 0 | pass |
| https://vercel.com/kb/guide/add-structured-application-logs-to-vercel-functions | 200 | 0 | pass |
| https://vitest.dev/config/coverage | 200 | 0 | pass |
| https://vitest.dev/config/environment | 200 | 0 | pass |
| https://vitest.dev/guide/ | 200 | 0 | pass |
| https://vitest.dev/guide/coverage | 200 | 0 | pass |

### 2. Snippet type-check

Method (same for every story; the scratch project lives outside the repo and is not committed):

- Scratch dir `/private/tmp/claude-501/-Users-jonathanstevenson-Source-claude-skills/b71aefe4-ae21-4000-aa3e-8b70fbcfbe94/scratchpad/tscheck-test1/w1/app`, `npm install --save-exact next@16.3.8 react react-dom typescript@7.0.2 @types/react @types/react-dom @types/node zod server-only client-only vitest @playwright/test @testing-library/react vite-tsconfig-paths @vitejs/plugin-react shiki jose ai @vercel/otel @vercel/firewall @opentelemetry/api` (resolved: next 16.3.8, react and react-dom 19.3.0, typescript 7.0.2, @types/react and @types/react-dom 19.3.0, @types/node 26.6.4, zod 4.6.5, server-only 0.0.1, client-only 0.0.1, vitest 5.0.3, @playwright/test 1.63.0, @testing-library/react 16.3.3, vite-tsconfig-paths 6.1.1, @vitejs/plugin-react 6.1.1, shiki 4.5.0, jose 6.2.12, ai 7.0.127, @vercel/otel 2.1.3, @vercel/firewall 1.2.5, @opentelemetry/api 1.9.1; all from npm). typescript 6.0.3 and 5.9.3 were installed beside it for the cross-check and the parse pass.
- Every ```` ```ts ```` and ```` ```tsx ```` fence of the ten files was extracted (218 fences: 160 Do/Pattern/rule, 58 inside the Don't half of an Anti-patterns entry). Each doc becomes one virtual Next.js project under `app/proj/<doc>/`: a fence whose first line is a `// path/to/file.ts` comment is written at that path (first occurrence only, Don't halves never), so `@/` and relative imports between fences resolve to the real fence; every other fence is its own module under `_loose/`. `next typegen` runs per project so the global `PageProps`, `LayoutProps` and `RouteContext` types exist; dummy `page.tsx`, `layout.tsx`, `route.ts` and `@slot` files are created for the route literals the fences use.
- Compiler config: the doc's own P1 `tsconfig.json` (`strict: true`, `noUncheckedIndexedAccess`, `lib: ES2020`, `moduleResolution: bundler`, ...) with `paths` `@/*` -> `./*` and `./src/*`; command `node node_modules/typescript/bin/tsc --noEmit --pretty false -p tsconfig.json` (TypeScript 7.0.2) in each project. Cross-checks: TypeScript 6.0.3 with the same config, and TypeScript 7.0.2 with the `create-next-app` default compilerOptions (`strict`, `target ES2017`, `lib dom/dom.iterable/esnext`).
- Prelude (declared, never silent): a fence that is a fragment gets only (a) `export {}` when it has no import or export, (b) a wrapper `async function __fragment() {` ... `}` when it is a bare statement list (TS1108 `return` outside a function), (c) an `import` of a well-known Next.js, React or Zod name (`z`, `redirect`, `notFound`, `revalidateTag`, `updateTag`, `cookies`, `Suspense`, ...) that the fence uses but does not import, (d) `declare var name: any` for any other free name the fence uses but does not define, (e) an any-typed stub module for a local `@/` or `./` import that no fence in the doc defines, (f) a typed export on the doc's own module when the doc says the module holds more than it shows. The records below say which fence got which.
- A fence with a parse error cannot be typechecked, so it is parked outside the project and reported on its own.

Result for `testing-and-observability.md`: **28 fences = 22 Do/Pattern/rule + 6 Don't half. Do/Pattern/rule: 22 pass, 0 fail.**

Cross-checks for this file: TypeScript 6.0.3 with the same config reports 0 Do-fence error(s); TypeScript 7.0.2 with the `create-next-app` default compilerOptions reports 0.

#### Failures (Do/Pattern/rule fences)

None.

#### Pass with a declared prelude that deserves a look

None.

#### Prelude record

- 0 of 22 Do/Pattern/rule fences begin with a `// path` comment and sit at that path in the virtual project; the other 22 are standalone modules under `_loose/`.
- `export {}` was appended to 0 fences that had no import or export (fences none); that only makes the fragment a module so names do not collide.
- Other preludes (Do/Pattern/rule fences only):

| Fence | Prelude |
| --- | --- |
| #03 (line 111) Route Handler unit test (TEST-9) | any-typed stub module: `_loose/route.ts` |
| #05 (line 141) Server Action logic as a pure function (TEST-10, TEST-18) | any-typed stub module: `_loose/validate-post.ts` |
| #09 (line 234) Custom span (TEST-30) | any-typed stub module: `features/dashboard/services/load-dashboard.ts` |
| #20 (line 491) Don't: call redirect() inside try (TEST-23) | any-typed stub module: `features/posts/services/save-post.ts` |

#### Don't half (expected to be wrong; recorded, not failed)

| Fence | Outcome |
| --- | --- |
| #17 (line 450) Don't: unit-render an async Server Component (TEST-2) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #19 (line 473) Don't: call redirect() inside try (TEST-23) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #21 (line 505) Don't: throw for a validation failure (TEST-18) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #23 (line 534) Don't: write a server-style error boundary (TEST-20, TEST-21) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #25 (line 572) Don't: return a div from global-error (TEST-22) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #27 (line 601) Don't: run E2E against the dev server (TEST-12) | compiles (the mistake is a runtime, security or caching rule, not a type error) |

#### JSON fences

- lines 432, 626 and 632 parse as JSON.

## FIX①

Branch `wip/nextjs-typescript-best-practices-reference/testing-errors-and-observability-fix`, cut from `origin/feat/nextjs-typescript-best-practices-reference` `8188c54`. Files touched: `references/nextjs/testing-and-observability.md` (773 lines), `test_nextjs_topic_testing_and_observability.py` (+8 tests, 26 in all) and this story folder (`evidence/sources-verified.md`, this file).

Method: every item was reproduced first, twice over. (1) Eight pytest text guards were added and run against the unfixed topic file: **8 failed, 18 passed**. (2) The behaviour behind each finding was shown in a scratch project outside the repo (`/private/tmp/claude-501/-Users-jonathanstevenson-Source-claude-skills/b71aefe4-ae21-4000-aa3e-8b70fbcfbe94/scratchpad/fix1-testing/cov`: next 16.3.8, vitest 5.0.3 with `@vitest/coverage-v8`, `@playwright/test` 1.63.0, `@vercel/otel`, strict TypeScript; not committed). After the fix: the 26 topic tests pass, the full suite gave **1034 passed**, ruff gave **All checks passed**, and the changed fences (vitest config, Playwright config, `instrumentation.ts`, the `unstable_rethrow` page, `logError`, `error.tsx`, `global-error.tsx`, `instrumentation-client.ts`, the Route Handler, `validatePost`) pass `tsc --noEmit` under TypeScript 5.9.3 and 7.0.2 (`strict`, `noUncheckedIndexedAccess`, `create-next-app` target and lib). The `## Sources` URL set still equals the evidence file (`EQUAL 50 50`).

| Id | Result | Test and evidence |
| --- | --- | --- |
| R1-C7 | fixed | `test_vitest_coverage_excludes_what_test_2_and_test_10_keep_off_the_unit_surface`. Repro: the old config run with `vitest run --coverage` over a mini App Router project (async `page.tsx`, `layout.tsx`, `instrumentation.ts`, a `'use server'` file under `src/lib/actions`, a generated file, a test helper, plus one tested pure function) reported 6.25% statements and four `does not meet global threshold (80%)` errors. The new config passes at 100%, and a deliberately untested file under `src/features` still fails it (33% lines), so the excludes hide only the TEST-2 and TEST-10 files. Keys checked on vitest.dev: `coverage.exclude` defaults to `[]` (so tests and test folders are listed), patterns match like `coverage.include`. |
| R1-C18 | fixed | `test_playwright_config_gives_each_checkout_its_own_port`, `test_playwright_reuses_an_existing_server_only_on_request`. Repro: the old config loaded from two checkout directories gave `http://localhost:3100` and `reuse true` for both. The new one gave 3416 and 3279 with `reuse false`; `E2E_PORT=4555 E2E_REUSE_SERVER=1` gave `4555 / true`, and the same with `CI` set gave `false`. Playwright's page says `false` throws when something already listens on the port, so a path-hash collision fails loudly instead of testing another checkout. |
| R1-C19 | fixed | `test_on_request_error_example_redacts_the_message_and_guards_the_reporter`. Repro (node, stubbed `fetch` that never answers): the old handler posted `jane@example.com` from the message and the path with its `token=` query, and was still pending after 1000 ms. The new handler posted neither, and settled (the abort fired, the catch logged `reporterError` and `digest` only). The Instrumentation page types `request.path` as `/blog?name=foo`, so it is dropped as well as the message. |
| R1-C29 | fixed | `test_unstable_rethrow_example_renders_the_post_it_loaded`. Repro (vitest, `renderToStaticMarkup(await Page())`, stubbed `fetch` returning 200): the old page rendered `<p>The post is unavailable.</p>`. The new page renders `<h1>Hello</h1>` on success and the unavailable text on a 500. |
| R1-C30 | fixed | `test_log_error_spreads_caller_fields_before_the_reserved_keys`. Repro (node): the old `logError('boom', err, { errorId: 'caller-supplied', level: 'info' })` logged `errorId` different from the id it returned and `level: info`. The new one logs the returned id and `level: error`. |
| R1-C31 | fixed | `test_web_vitals_reporter_is_owned_by_perf_26_and_not_copied`. The `WebVitals` component pattern is deleted; TEST-32 says to copy the component, callback and endpoint from rule `PERF-26` in `performance-and-vercel.md` (inline-code id, because the generic contract bans bare foreign rule ids in prose). The checklist item split into TEST-31 and TEST-32. No `useReportWebVitals` fence remains here. |
| R1-C9 (this file's side) | fixed | `test_snippets_and_rules_use_the_canonical_src_layout`. Paths now read `src/app/api/hello/route.ts`, `src/app/dashboard/error.tsx`, `src/app/global-error.tsx`, `src/instrumentation.ts`, `src/instrumentation-client.ts`, `src/app/not-found.tsx` and `@/app/dashboard/page`; the four `'use server'` fences start `// src/lib/actions/create-post.ts` and TEST-10 says to keep action files in `src/lib/actions/`. This file has no session helper, so the `getSession()` / `verifySession()` contract needed no edit here. |

TEST① failures: none belong to this story (TEST① listed `sse-and-streaming.md`, `route-handlers-and-apis.md` and the routing as-of source).

### FIX① assumptions

1. The per-checkout port is `E2E_PORT` when the runner sets it, else 3100 + (first two bytes of a SHA-256 of `process.cwd()`) mod 900. Reuse needs `E2E_REUSE_SERVER=1` and no `CI`. Both names are bmn conventions, tagged as such in TEST-13.
2. Vitest excludes files by glob, never by directive, so the `'use server'` exclusion relies on the placement rule in TEST-10 (`src/lib/actions/`, the nextjs.md layout). The excluded route files are `page`, `layout`, `template`, `default`, `loading`, `error`, `global-error` and `not-found` under `src/app`; `route.ts` and `proxy.ts` stay in, because TEST-9 and TEST-11 unit-test them.
3. `request.path` was dropped from the `onRequestError` report, beyond what R1-C19 named, because the page shows it carrying the query string. `context.routePath` carries the route instead.
4. The `unstable_rethrow` page loads a plain-text title (`res.text()`), so the example needs no unvalidated `res.json()` cast against non-negotiable 14.
5. `/api/vitals` no longer appears in this file; the endpoint now belongs to the reporter in `performance-and-vercel.md`.

## TEST2 content

Run 2026-10-04 on a detached worktree at `origin/dev` `7acb627` (branch `wip/nextjs-typescript-best-practices-reference/tests-content-2`). Delta only: `references/nextjs/testing-and-observability.md` between `5d7550d` (run branch at TEST1) and `7acb627`. Everything else was TEST1's.

### 1. Live sources (delta)

No `## Sources` URL is new or changed in this file (the URL set equals TEST1's). Result: **0 URLs to check, 0 fail**.

Extended check: every URL on an added or changed line of this file, in prose and rules as well as `## Sources` (18 distinct, leaving out 3 example hostname(s) that appear only inside code samples), fetched the same way: **18 pass, 0 fail**.

### 2. Snippet type-check (delta fences)

New or changed fences (text differs from every TEST1 fence): **11 = 8 Do/Pattern/rule + 3 Don't half**.

Result: **Do/Pattern/rule: 8 pass, 0 fail.** Cross-checks with the same config: TypeScript 6.0.3 reports 0 Do-fence error(s), TypeScript 5.9.3 reports 0.

#### Failures (Do/Pattern/rule fences)

None.

#### Pass with a declared prelude that deserves a look

None.

#### Prelude record (delta fences)

- 1 of 8 Do/Pattern/rule fences begin with a `// path` comment and sit at that path in the virtual project; the other 7 are standalone modules under `_loose/`.
- `export {}` appended to 0 Do/Pattern/rule fence(s).
- Other preludes (Do/Pattern/rule fences only):

| Fence | Prelude |
| --- | --- |
| #19 (line 506) Don't: call redirect() inside try (TEST-23) | any-typed stub module: `src/features/posts/services/save-post.ts` |

#### Don't half (expected to be wrong; recorded, not failed)

| Fence | Outcome |
| --- | --- |
| #16 (line 464) Don't: unit-render an async Server Component (TEST-2) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #18 (line 487) Don't: call redirect() inside try (TEST-23) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #20 (line 521) Don't: throw for a validation failure (TEST-18) | compiles (the mistake is a runtime, security or caching rule, not a type error) |

### 3. Session-helper consistency (text only)

No snippet in this file imports a session helper.

Result: **0 fail** (nothing to check).
