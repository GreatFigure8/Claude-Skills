# Validation — performance-and-vercel-platform

Branch `wip/nextjs-typescript-best-practices-reference/performance-and-vercel-platform`, cut from
`origin/feat/nextjs-typescript-best-practices-reference` (skeleton merged). Date: 2026-10-04.
`deploy_pending: []` — no migration, no env var, no config change; Markdown and a pytest file only.

## TDD record

| Step | Command | Result |
| --- | --- | --- |
| RED | `pytest test_nextjs_topic_performance_and_vercel.py` against the stub | 21 collected: 14 failed, 7 passed. Failures: `is_stub` true, no rules, missing terms, the five examples, no Edge rule, no Version notes, no checklist, no Anti-patterns, no Patterns section (`LookupError: no heading 'Patterns'`). The 7 passes are the four unit-check self-tests, the no-`any` check, and the number-link and deploy-command checks, which are vacuous on a stub. |
| GREEN | same file after the topic was written | 21 passed |
| GREEN, contract | `pytest test_nextjs_topic_performance_and_vercel.py test_nextjs_reference.py -rs` | 150 passed, 56 skipped; the skips are the 8 remaining stubs x 7 generic tests, none for `performance-and-vercel.md` |
| REFACTOR | file first came out at 944 lines, failing `test_file_is_at_most_800_lines`; trimmed and re-wrapped | 783 lines, all green |

## Gates

- Full suite: `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q -rs` gives
  **695 passed, 56 skipped** (76 s). The skeleton's count was 667 passed, 63 skipped (730 total). Now 751 total: 21 new
  tests, and the 7 generic contract tests for this topic moved from skipped to passed.
- Lint: `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` gives `All checks passed!`.
- Types: none (stack.md). As an extra, the 24 `ts`/`tsx` fences of Patterns and Anti-patterns were written to a scratch
  folder and compiled with `tsc` 7.0.2 under `strict` against `next@16.3.8`, `react@19`, `@types/react@19` and
  `shiki`, with a stub for `./chart`: no errors. Nothing from that folder is committed.
- shellcheck: no `.sh` file changed.
- Line cap: `wc -l` gives 783 (limit 800).
- Scope: `git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists the topic file, the
  topic test file, and files under this story's folder only.

## Acceptance criteria

1. Contract: the 7 generic tests parametrised for this file run with no skip and pass. Only `PERF-` ids (1 to 43).
2. `test_performance_topic_is_not_a_stub`; `test_performance_topic_has_at_least_15_perf_rules` (43 rules).
3. `test_performance_topic_names_every_required_concept`: all 22 terms found. None needed to move to Not confirmed.
4. Five `has_block_with` examples, plus `test_typescript_examples_use_no_any_type` over every `ts`/`tsx` fence.
5. `test_every_vercel_number_line_carries_a_platform_link` and three self-tests of the checker (see Assumptions 3).
6. `test_runtime_choice_rule_names_edge_with_a_vercel_link`: PERF-29 holds `Edge` and a vercel.com link in one item.
7. `test_version_notes_name_the_major_and_link_nextjs`: names `Next.js 16`, links nextjs.org.
8. `test_every_checklist_item_names_a_perf_rule` (15 items), `test_checklist_rule_ids_exist_in_rules`,
   `test_anti_patterns_pair_each_dont_with_a_do` (6 pairs).
9. `evidence/sources-verified.md` has one row per Sources URL (51). One-off check, run from
   `Skills/dev-bother-me-nope/assets/tests` with the plan's command (the evidence URLs normalised with
   `normalize_url` before comparing):

   ```text
   True [] 51 51
   ```

   The two URL sets are equal.
10. Scope and gates: above.

## Grounding re-check (done by the coder on 2026-10-04)

- All 51 Sources URLs fetched with `curl -H 'Accept: text/markdown'`: every one returned HTTP 200.
- 174 key phrases from the plan's rule sheet were searched on the saved pages. The first pass found 151 (23 missing);
  the misses were markdown formatting (links, bold, blockquote line wraps). With formatting normalised, 9 remained and
  each was read on its page and confirmed: the `@heroicons/react/*` entries are listed as `@heroicons/react/20/solid`,
  `24/solid`, `24/outline`, so that package is left out of PERF-21; the "`id` for inline scripts" warning is on the
  Scripts guide, not the Script API page (PERF-14 cites both); the other 7 were blockquote wraps or reworded lines
  whose meaning matches.
- Facts not on the plan sheet, each read on the cited page before use: Hobby single region (region page table);
  `iad1` default and "Runs in a single region by default (`iad1`)" (region and runtimes pages); the CDN
  cacheable-response criteria and 1 year maximum (CDN cache page); the `localPatterns` and `remotePatterns` 400
  responses (Image API); `vercel.toml` listed as a static config file (project configuration page).
- The Speed Insights quickstart embeds an agent prompt that says to deploy with a Vercel CLI command. It is page data and
  is not reproduced.

## Assumptions

1. **The merged contract wins over the plan.** Differences found and followed:
   - Anti-patterns are `### Don't …` H3 headings (`h.anti_patterns`), each followed by a fence, a `**Do** …` line and a
     second fence. The plan's `**Don't**` bold lead-ins would not be seen by the generic floor test. The Anti-patterns
     test is written against `h.anti_patterns`.
   - H3 headings are free inside a section, so Rules and Patterns use `###` groupings. `section()` stops only at a
     heading of the same or higher level, so the plan's no-`###` workaround was not needed.
   - Rules are numbered items with indented continuation lines, not single physical lines.
2. **Rule text carries a headline sentence, then wrapped detail.** The rules were re-wrapped to 120 columns with a
   scratch script that keeps each `[text](url)` link whole, to fit the 800-line cap.
3. **Unit-token check groups an item as a column-0 list item plus every indented line under it**, nested bullets
   included. The plan's grouping started a new item at each nested bullet, which would flag a nested number whose link
   sits on the parent line. Self-tests cover: no link flags the line; a link elsewhere in the item passes; a nested
   bullet counts as part of its item; one item's link does not vouch for the next item; fenced numbers are ignored.
4. **Plan content dropped to stay under 800 lines:** the LCP-hero Pattern (the Do block of the second anti-pattern shows
   `loading="eager"`), the Speed Insights/Analytics layout block (PERF-27 gives both imports and the placement), the
   optional CDN-headers snippet, the local-font line of `fonts.ts` (PERF-8 still names `next/font/local`), the
   `$schema` line of the cron `vercel.json`, and the list of three accepted `s-maxage` directive shapes in PERF-37.
5. **PERF-29 is scoped to page, layout and route files.** `nextjs.md` non-negotiable 2 still allows a `middleware.ts`
   for the Edge runtime, so a blanket "never Edge" would contradict it. No defect in a shared file is recorded: the two
   statements are consistent as scoped.
6. **PERF-42 adds `vercel.toml`**, which the project-configuration page lists beside `vercel.json`, and drops the plan's
   `@vercel/config/v1` import line, because that page's example imports more names and the file shows no `vercel.ts` code.
7. **PERF-21 carries `(convention)`** on the analyzer-first workflow sentence; the experimental status is the docs'.
8. **Three more tests than the plan:** 21 collected against 18: two extra checker self-tests (4, plan: 2) and the
   no-`any` test (plan AC4 asks for typed examples).
9. The research date and the coder's re-check date are both 2026-10-04.

## TEST1 content

Run 2026-10-04 on a detached worktree at `origin/dev` `59279a3` (branch `wip/nextjs-typescript-best-practices-reference/tests-content-1`). This repo ships Markdown, so the black-box surface is the content: live sources, and the TypeScript snippets compiled in a real Next.js 16.3.8 project. File under test: `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/performance-and-vercel.md`.

### 1. Live sources

Command (per URL, 8 in parallel): `curl -sL -A <desktop browser UA> --max-time 20 --max-redirs 10 -o /dev/null -w "%{http_code}|%{url_effective}|%{num_redirects}" <url>`. A URL passes only when the final status is 2xx and the final URL is the same page (host without `www.`, path without trailing slash). Scope: every URL in the `## Sources` section.

Result: **51 URLs, 51 pass, 0 fail**. (Across all ten files: 283 unique URLs, 283 pass, 0 fail; every one returned HTTP 200 with no redirect.)

| URL | HTTP | Redirects | Result |
| --- | --- | --- | --- |
| https://nextjs.org/blog/next-16 | 200 | 0 | pass |
| https://nextjs.org/blog/next-16-3 | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/cli/next | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/components/font | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/components/image | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/components/script | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/optimizePackageImports | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/proxyClientMaxBodySize | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/reactCompiler | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/serverExternalPackages | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/turbopackFileSystemCache | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/maxDuration | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/preferredRegion | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/runtime | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/after | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/use-report-web-vitals | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/turbopack | 200 | 0 | pass |
| https://nextjs.org/docs/app/getting-started/fonts | 200 | 0 | pass |
| https://nextjs.org/docs/app/getting-started/images | 200 | 0 | pass |
| https://nextjs.org/docs/app/getting-started/server-and-client-components | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/lazy-loading | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/package-bundling | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/production-checklist | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/scripts | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/third-party-libraries | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/upgrading/version-16 | 200 | 0 | pass |
| https://nextjs.org/docs/messages/edge-runtime-deprecated | 200 | 0 | pass |
| https://vercel.com/docs/analytics/quickstart | 200 | 0 | pass |
| https://vercel.com/docs/caching/cdn-cache | 200 | 0 | pass |
| https://vercel.com/docs/caching/runtime-cache/data-cache | 200 | 0 | pass |
| https://vercel.com/docs/cron-jobs | 200 | 0 | pass |
| https://vercel.com/docs/cron-jobs/manage-cron-jobs | 200 | 0 | pass |
| https://vercel.com/docs/deployments/environments | 200 | 0 | pass |
| https://vercel.com/docs/environment-variables | 200 | 0 | pass |
| https://vercel.com/docs/fluid-compute | 200 | 0 | pass |
| https://vercel.com/docs/functions/configuring-functions/duration | 200 | 0 | pass |
| https://vercel.com/docs/functions/configuring-functions/memory | 200 | 0 | pass |
| https://vercel.com/docs/functions/configuring-functions/region | 200 | 0 | pass |
| https://vercel.com/docs/functions/limitations | 200 | 0 | pass |
| https://vercel.com/docs/functions/runtimes | 200 | 0 | pass |
| https://vercel.com/docs/functions/runtimes/edge | 200 | 0 | pass |
| https://vercel.com/docs/image-optimization | 200 | 0 | pass |
| https://vercel.com/docs/image-optimization/limits-and-pricing | 200 | 0 | pass |
| https://vercel.com/docs/incremental-static-regeneration | 200 | 0 | pass |
| https://vercel.com/docs/limits | 200 | 0 | pass |
| https://vercel.com/docs/project-configuration | 200 | 0 | pass |
| https://vercel.com/docs/project-configuration/vercel-ts | 200 | 0 | pass |
| https://vercel.com/docs/skew-protection | 200 | 0 | pass |
| https://vercel.com/docs/speed-insights/quickstart | 200 | 0 | pass |
| https://vercel.com/kb/guide/how-to-bypass-vercel-body-size-limit-serverless-functions | 200 | 0 | pass |

### 2. Snippet type-check

Method (same for every story; the scratch project lives outside the repo and is not committed):

- Scratch dir `/private/tmp/claude-501/-Users-jonathanstevenson-Source-claude-skills/b71aefe4-ae21-4000-aa3e-8b70fbcfbe94/scratchpad/tscheck-test1/w1/app`, `npm install --save-exact next@16.3.8 react react-dom typescript@7.0.2 @types/react @types/react-dom @types/node zod server-only client-only vitest @playwright/test @testing-library/react vite-tsconfig-paths @vitejs/plugin-react shiki jose ai @vercel/otel @vercel/firewall @opentelemetry/api` (resolved: next 16.3.8, react and react-dom 19.3.0, typescript 7.0.2, @types/react and @types/react-dom 19.3.0, @types/node 26.6.4, zod 4.6.5, server-only 0.0.1, client-only 0.0.1, vitest 5.0.3, @playwright/test 1.63.0, @testing-library/react 16.3.3, vite-tsconfig-paths 6.1.1, @vitejs/plugin-react 6.1.1, shiki 4.5.0, jose 6.2.12, ai 7.0.127, @vercel/otel 2.1.3, @vercel/firewall 1.2.5, @opentelemetry/api 1.9.1; all from npm). typescript 6.0.3 and 5.9.3 were installed beside it for the cross-check and the parse pass.
- Every ```` ```ts ```` and ```` ```tsx ```` fence of the ten files was extracted (218 fences: 160 Do/Pattern/rule, 58 inside the Don't half of an Anti-patterns entry). Each doc becomes one virtual Next.js project under `app/proj/<doc>/`: a fence whose first line is a `// path/to/file.ts` comment is written at that path (first occurrence only, Don't halves never), so `@/` and relative imports between fences resolve to the real fence; every other fence is its own module under `_loose/`. `next typegen` runs per project so the global `PageProps`, `LayoutProps` and `RouteContext` types exist; dummy `page.tsx`, `layout.tsx`, `route.ts` and `@slot` files are created for the route literals the fences use.
- Compiler config: the doc's own P1 `tsconfig.json` (`strict: true`, `noUncheckedIndexedAccess`, `lib: ES2020`, `moduleResolution: bundler`, ...) with `paths` `@/*` -> `./*` and `./src/*`; command `node node_modules/typescript/bin/tsc --noEmit --pretty false -p tsconfig.json` (TypeScript 7.0.2) in each project. Cross-checks: TypeScript 6.0.3 with the same config, and TypeScript 7.0.2 with the `create-next-app` default compilerOptions (`strict`, `target ES2017`, `lib dom/dom.iterable/esnext`).
- Prelude (declared, never silent): a fence that is a fragment gets only (a) `export {}` when it has no import or export, (b) a wrapper `async function __fragment() {` ... `}` when it is a bare statement list (TS1108 `return` outside a function), (c) an `import` of a well-known Next.js, React or Zod name (`z`, `redirect`, `notFound`, `revalidateTag`, `updateTag`, `cookies`, `Suspense`, ...) that the fence uses but does not import, (d) `declare var name: any` for any other free name the fence uses but does not define, (e) an any-typed stub module for a local `@/` or `./` import that no fence in the doc defines, (f) a typed export on the doc's own module when the doc says the module holds more than it shows. The records below say which fence got which.
- A fence with a parse error cannot be typechecked, so it is parked outside the project and reported on its own.

Result for `performance-and-vercel.md`: **24 fences = 18 Do/Pattern/rule + 6 Don't half. Do/Pattern/rule: 18 pass, 0 fail.**

Cross-checks for this file: TypeScript 6.0.3 with the same config reports 0 Do-fence error(s); TypeScript 7.0.2 with the `create-next-app` default compilerOptions reports 0.

#### Failures (Do/Pattern/rule fences)

None.

#### Pass with a declared prelude that deserves a look

None.

#### Prelude record

- 0 of 18 Do/Pattern/rule fences begin with a `// path` comment and sit at that path in the virtual project; the other 18 are standalone modules under `_loose/`.
- `export {}` was appended to 0 fences that had no import or export (fences none); that only makes the fragment a module so names do not collide.
- Other preludes (Do/Pattern/rule fences only):

| Fence | Prelude |
| --- | --- |
| #04 (line 327) Self-hosted fonts, layout and Tailwind (PERF-8 to PERF-11) | any-typed stub module: `_loose/fonts.ts` |
| #07 (line 379) Lazy client widget (PERF-19) | any-typed stub module: `_loose/chart.ts` |

#### Don't half (expected to be wrong; recorded, not failed)

| Fence | Outcome |
| --- | --- |
| #14 (line 508) Don't render a `fill` image without `sizes`, or use a raw `<img>` (PERF-1 to PERF-3) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #16 (line 526) Don't mark every image `priority`, or pair `preload` with `loading` (PERF-4) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #18 (line 546) Don't allow remote images with `domains` or a wildcard host (PERF-5) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #20 (line 572) Don't load fonts with a stylesheet link in the root layout (PERF-8, PERF-9) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #22 (line 606) Don't export `runtime = 'edge'` or `preferredRegion` from a route (PERF-29, PERF-34) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #23 (line 619) Don't leave a cron route open or non-idempotent (PERF-39) | compiles (the mistake is a runtime, security or caching rule, not a type error) |

#### JSON fences

- lines 497 and 613 parse as JSON.
