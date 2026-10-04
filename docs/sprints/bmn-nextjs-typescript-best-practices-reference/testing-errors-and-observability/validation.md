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
