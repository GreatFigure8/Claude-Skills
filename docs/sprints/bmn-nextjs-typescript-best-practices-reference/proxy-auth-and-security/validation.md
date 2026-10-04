# Validation: proxy-auth-and-security

Branch `wip/nextjs-typescript-best-practices-reference/proxy-auth-and-security`, from
`origin/feat/nextjs-typescript-best-practices-reference`. Checked 2026-10-04.

## Test run (TDD)

- RED, against the stub: `test_nextjs_topic_proxy_auth_and_security.py` gave **16 failed, 2 passed**.
  Every failure was the stub's absence of content (`is_stub`, rule count, terms, examples, version
  notes, checklist, anti-patterns, not-confirmed). The 2 passes were vacuous on a stub
  (`test_no_other_topic_rule_ids_are_used`, `test_ts_examples_never_use_any`).
- GREEN, with the topic file: the topic test file gives **18 passed**; with
  `test_nextjs_reference.py` it gives 147 passed, 56 skipped. All 56 skips are the other eight
  topics' stubs (7 generic tests each). Nothing skips for `proxy-auth-and-security.md`.
- Full suite: `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`
  gives **692 passed, 56 skipped**. Lint: `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope`
  gives "All checks passed!". Types: none (stack gate).
- `wc -l` of the topic file: 778 (cap 800).

## Acceptance criteria

| AC | Result | Evidence |
| --- | --- | --- |
| 1 Contract | pass | The generic tests in `test_nextjs_reference.py` run on the file with no skip and pass; `test_no_other_topic_rule_ids_are_used` passes. |
| 2 Not a stub, at least 18 rules | pass | `test_topic_file_is_not_a_stub`, `test_topic_has_at_least_18_sec_rules` (45 rules, SEC-1..SEC-45). |
| 3 Required concepts | pass | `test_required_terms_are_present`. Every term appears as a stated rule or pattern; none needed the Not-confirmed section. |
| 4 Examples | pass | `test_example_block_is_present` x5 and `test_ts_examples_never_use_any`. |
| 5 Optimistic Proxy and DAL | pass | `test_rules_keep_proxy_optimistic_and_recheck_in_the_dal`. |
| 6 Rename stated exactly | pass | `test_version_notes_state_the_middleware_to_proxy_rename`. File name, function name, runtime, codemod and renamed config keys are stated from the upgrade guide, proxy.js and the codemods page. The `edge`-runtime follow-up, the removal release and the codemod dist-tag are in Not confirmed. |
| 7 Auth before write | pass | `test_every_use_server_block_checks_auth_before_writing` (covers the Don't blocks too). |
| 8 Version notes | pass | `test_version_notes_name_the_major_and_link_nextjs_org`, `test_version_notes_list_the_topic_security_advisories`. |
| 9 Reviewer-ready | pass | `test_every_review_checklist_item_names_a_sec_rule` (21 items), `test_every_anti_pattern_dont_is_paired_with_a_do` (7 items). |
| 10 Evidence | pass | One-off check below. |
| 11 Scope and gates | pass | `git diff --name-only` below, plus the gates above. |

### AC10 one-off: Sources equals the evidence list

```text
sources: 43 evidence: 43
missing from evidence: []
extra in evidence: []
```

### AC11 one-off: changed files

```text
Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_proxy_auth_and_security.py
Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/proxy-auth-and-security.md
docs/sprints/bmn-nextjs-typescript-best-practices-reference/proxy-auth-and-security/validation.md
```

## Re-verification done by the coder (2026-10-04)

The brief asked for advisories and patched versions to be re-checked before writing. Fetched live and
matched against the plan's rule sheet; nothing was dropped:

- CVE-2025-66478: fixed in 16.0.7, CVSS 10.0, rotate secrets after patching and redeploying.
- CVE-2025-55184, CVE-2025-67779 and CVE-2025-55183: 16.0.10.
- July 2026: 16.2.11 (and 15.5.21); CVE-2026-64642, 64641, 64643, 64649 and 64645 as the plan lists. The
  post says 16.3.0 will include the fixes once stable, so the file says only "fixed in 16.2.11".
- August 2026: 16.3.3 (and 15.5.24); AVIF RCE (GHSA only) and the Windows-hosted RCE, which the page
  gives as CVE-2026-75604 (added to the file; it is on the cited page).
- 2026-09-22: 16.3.6 (and 15.5.26); the Node.js `ImageResponse` RCE, affects `>=16.2.0 <16.3.6`.
- 2026-09-30: 16.3.8 Active LTS and 15.5.27 Maintenance LTS; the five items the plan lists, with the
  CVE ids the post gives (added: CVE-2026-94483, 94543, 94484, 94544, 94486).
- Postmortem: CVE-2025-29927, fixed in 15.2.3 and 14.2.25; the "sole method of protecting routes" sentence.
- Also re-read: proxy.js (runtime, matcher, `next({ request: { headers } })` versus `next({ headers })`,
  execution-order note, version history, `@canary` codemod), the CSP guide (proxy example, `missing`
  matcher, `unsafe-eval`, PPR, version history ending at v14.0.0), serverActions config
  (`allowedOrigins`, `bodySizeLimit`, no-`Origin` behaviour), the Vercel Config and Secret changelog,
  Deployment Protection (Standard Protection) and the codemods page. All matched the sheet.

## Strict TypeScript check (extra, outside the repo)

The story says snippets are not compiled. They were compiled anyway in a scratch project
(`next@16.3.8`, `react@19`, `typescript@5`, `jose`, `zod`, `server-only`; `strict` and
`noUncheckedIndexedAccess`; a typed stub for `@/lib/prisma` and `@/lib/reports`). The 7 Patterns
files compile as written. The 13 anti-pattern fragments compile once a prelude of the imports a real
file would have is added. Nothing from the scratch project is committed.

## Assumptions

1. The skeleton's contract won over the plan on three points. (a) Anti-pattern items are `### Don't ...`
   H3 headings, each holding a why line and a fenced Don't block, then a `**Do**` marker and a fenced Do
   block; the plan's `**Don't**`-after-H3 guess was dropped, so the topic test reads the pairs through
   `anti_patterns()` and only `DO_MARKER` is used. (b) The H1 stays the stub's `# Proxy, auth and
   security`, because the skeleton owns the title; the plan's `Proxy, authentication and security` was
   not used. (c) `## Rules` is a flat numbered list: the contract allows H3s there, but the 800-line cap
   did not leave room for the group headings.
2. `section()` raises `LookupError` in the merged helpers, so the test's `_section` wrapper returns an
   empty string for a missing heading and the assertion reports the gap. No assertion was weakened.
3. `TOPICS` values are `(prefix, slug)` tuples, as the plan assumed.
4. Prose links carry no `#fragment`, so prose URLs equal the Sources bullets exactly (43 URLs).
5. The Not-confirmed items name pages by link rather than by the plan's short names, because the generic
   test requires a URL in each item. Item 7 (Vercel team secrets policy) is carried from the planner's
   reading of the sensitive-variables page; only the changelog half was re-fetched here.
6. SEC-42 says "pre-announced security releases" and drops the plan's "monthly": the July 2026 post
   confirms the pre-announced model, and the "roughly once a month" sentence was not re-fetched.
7. `authInterrupts` (`forbidden()`/`unauthorized()`) stays out, as the plan says.
8. No defect was found in the shared files (`nextjs.md`, `nextjs_doc_helpers.py`,
   `test_nextjs_reference.py`).
9. No deploy, no Supabase, no env vars or migrations. Env var names (`SESSION_SECRET`,
   `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY`, `DANGEROUSLY_DEPLOY_VULNERABLE_CVE_2025_66478`) appear only
   as documentation text. No `deploy_pending` entries.

## TEST1: unit (2026-10-04)

Branch `wip/nextjs-typescript-best-practices-reference/tests-unit-1`, cut from the detached run base `origin/dev` `59279a3` (the run branch tip after
the wave-2 merges, with origin/dev merged in). Tester: `tests-unit-1`. No code was changed; this is a
verification pass.

### Commands and results

| Step | Command | Result |
| --- | --- | --- |
| Full suite with coverage | `uv run --quiet --with pytest --with pytest-cov python -m pytest Skills/dev-bother-me-nope/assets/tests -q --cov=Skills/dev-bother-me-nope/assets/tests --cov-report=term` | **1026 passed in 95.32s (0:01:35)**, exit 0, 0 failed, 0 skipped. Log: `docs/sprints/bmn-nextjs-typescript-best-practices-reference/nextjs-standard-entry-point-and-skill-wiring/evidence/test1-unit-full-suite.txt` |
| Lint | `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` | `All checks passed!` |
| Story tests, verbose | `pytest test_nextjs_topic_proxy_auth_and_security.py test_nextjs_reference.py ... -v` (483 tests across the nextjs files and `test_skill_text_rules.py`) | 483 PASSED, 0 other. The tests this map cites are listed in `evidence/test1-unit-results.txt` |
| TERMS and example needles | one-off script comparing this story's criterion 3 and 4 lists with the test | story TERMS (21) equal the test's TERMS (21), same order: True; story example needles missing from the test source: 0 |
| URL sets | one-off script comparing `## Sources` of `references/nextjs/proxy-auth-and-security.md` with the URLs in `evidence/sources-verified.md` | 43 cited, 43 listed, nothing only in one of them. All 43 evidence rows carry fetch date 2026-10-04 and a non-empty Backs cell |
| Scope | one-off `git diff --name-only <merge>^1 <merge>` for this story's merge `89f3dc9` | 3 files, all inside the story scope (the topic file, `test_nextjs_topic_proxy_auth_and_security.py`, and files under `docs/sprints/bmn-nextjs-typescript-best-practices-reference/proxy-auth-and-security/`); outside scope: none |

### Coverage

- `references/nextjs/proxy-auth-and-security.md`: Markdown, coverage n/a. It is exercised by the generic contract tests and by `test_nextjs_topic_proxy_auth_and_security.py`; the file is 45 rules, 779 lines (cap 800).
- `nextjs_doc_helpers.py` (shared parser the tests use): **99%** (243 of 245 statements). Uncovered: line 180 (an unterminated code fence at end of file) and line 294 (`h1` of an empty file). Target 80% met.
- `test_nextjs_topic_proxy_auth_and_security.py`: **98%** (80 of 82 statements). Whole suite: **99%** (3604 of 3635).

### Criterion map

All [unit] criteria of `story.md`, mapped to the test or one-off check that covers them. The generic
contract tests are the ones `test_nextjs_reference.py` runs for every topic file; none is skipped
(the suite has no skips), so each ran on `proxy-auth-and-security.md`.

| AC | Criterion | Covering test(s) / check | Result |
| --- | --- | --- | --- |
| 1 | Contract | generic contract tests (17 x `[proxy-auth-and-security.md]` + `test_rule_ids_are_unique_across_topic_files`)<br>`test_no_other_topic_rule_ids_are_used` | PASS |
| 2 | Not a stub, at least 18 SEC rules | `test_topic_file_is_not_a_stub`<br>`test_topic_has_at_least_18_sec_rules` | PASS |
| 3 | Required terms | `test_required_terms_are_present` | PASS |
| 4 | Examples (proxy+matcher, server-only+cache, use server, CSP nonce, httpOnly; no `any`) | `test_example_block_is_present`<br>`test_ts_examples_never_use_any` | PASS |
| 5 | Rules keep the proxy optimistic and re-check in the Data Access Layer | `test_rules_keep_proxy_optimistic_and_recheck_in_the_dal` | PASS |
| 6 | middleware-to-proxy change stated in Version notes | `test_version_notes_state_the_middleware_to_proxy_rename` | PASS |
| 7 | Every `'use server'` block checks auth before writing | `test_every_use_server_block_checks_auth_before_writing` | PASS |
| 8 | Version notes name the major and link nextjs.org | `test_version_notes_name_the_major_and_link_nextjs_org`<br>`test_version_notes_list_the_topic_security_advisories` | PASS |
| 9 | Reviewer-ready | `test_every_review_checklist_item_names_a_sec_rule`<br>`test_every_anti_pattern_dont_is_paired_with_a_do` | PASS |
| 10 | Grounding evidence (one-off) | one-off set-equality check, see below | PASS |
| 11 | Scope and gates (one-off + suite + ruff) | one-off `git diff --name-only` check, full suite, ruff (see below)<br>`test_not_confirmed_section_lists_the_urls_checked` | PASS |

**Totals:** 11 PASS, 0 FAIL, 0 uncovered.

### TEST1 assumptions

1. AC9 (grounding evidence) is a one-off check by design ("not a permanent test"). It was re-run here with the plan's set-equality method and passed.
2. AC10 scope is checked against the story's merge into the run branch (`git diff --name-only <merge>^1 <merge>`), because `origin/feat/...` has since moved on. The suite and ruff are checked on the final tree.
3. Where the criterion text asks for content beyond what its test asserts (for example, the shape of an example), the test is taken as the verification the story names; factual correctness of the claims against nextjs.org and vercel.com is the REVIEW① lens, not a unit test.

## TEST1 content

Run 2026-10-04 on a detached worktree at `origin/dev` `59279a3` (branch `wip/nextjs-typescript-best-practices-reference/tests-content-1`). This repo ships Markdown, so the black-box surface is the content: live sources, and the TypeScript snippets compiled in a real Next.js 16.3.8 project. File under test: `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/proxy-auth-and-security.md`.

### 1. Live sources

Command (per URL, 8 in parallel): `curl -sL -A <desktop browser UA> --max-time 20 --max-redirs 10 -o /dev/null -w "%{http_code}|%{url_effective}|%{num_redirects}" <url>`. A URL passes only when the final status is 2xx and the final URL is the same page (host without `www.`, path without trailing slash). Scope: every URL in the `## Sources` section.

Result: **43 URLs, 43 pass, 0 fail**. (Across all ten files: 283 unique URLs, 283 pass, 0 fail; every one returned HTTP 200 with no redirect.)

| URL | HTTP | Redirects | Result |
| --- | --- | --- | --- |
| https://nextjs.org/blog/CVE-2025-66478 | 200 | 0 | pass |
| https://nextjs.org/blog/august-2026-security-release | 200 | 0 | pass |
| https://nextjs.org/blog/july-2026-security-release | 200 | 0 | pass |
| https://nextjs.org/blog/next-16 | 200 | 0 | pass |
| https://nextjs.org/blog/next-16-1 | 200 | 0 | pass |
| https://nextjs.org/blog/next-16-2 | 200 | 0 | pass |
| https://nextjs.org/blog/next-16-3 | 200 | 0 | pass |
| https://nextjs.org/blog/next-security-release-program | 200 | 0 | pass |
| https://nextjs.org/blog/nextjs-security-update-september-22-2026 | 200 | 0 | pass |
| https://nextjs.org/blog/security-nextjs-server-components-actions | 200 | 0 | pass |
| https://nextjs.org/blog/security-update-2025-12-11 | 200 | 0 | pass |
| https://nextjs.org/blog/september-2026-security-release | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/headers | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/taint | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/directives/use-server | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/proxy | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/cookies | 200 | 0 | pass |
| https://nextjs.org/docs/app/getting-started/proxy | 200 | 0 | pass |
| https://nextjs.org/docs/app/getting-started/server-and-client-components | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/authentication | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/authentication-with-cache-components | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/backend-for-frontend | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/content-security-policy | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/data-security | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/environment-variables | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/self-hosting | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/server-actions | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/upgrading/codemods | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/upgrading/version-16 | 200 | 0 | pass |
| https://react.dev/reference/react/cache | 200 | 0 | pass |
| https://react.dev/reference/react/experimental_taintObjectReference | 200 | 0 | pass |
| https://react.dev/reference/react/experimental_taintUniqueValue | 200 | 0 | pass |
| https://react.dev/reference/rsc/use-server | 200 | 0 | pass |
| https://vercel.com/blog/postmortem-on-next-js-middleware-bypass | 200 | 0 | pass |
| https://vercel.com/changelog/environment-variables-now-use-config-and-secret-types | 200 | 0 | pass |
| https://vercel.com/changelog/new-deployments-of-vulnerable-next-js-applications-are-now-blocked-by | 200 | 0 | pass |
| https://vercel.com/docs/deployment-protection | 200 | 0 | pass |
| https://vercel.com/docs/environment-variables | 200 | 0 | pass |
| https://vercel.com/docs/environment-variables/rotating-secrets | 200 | 0 | pass |
| https://vercel.com/docs/environment-variables/sensitive-environment-variables | 200 | 0 | pass |
| https://vercel.com/docs/vercel-firewall | 200 | 0 | pass |
| https://zod.dev/basics | 200 | 0 | pass |

### 2. Snippet type-check

Method (same for every story; the scratch project lives outside the repo and is not committed):

- Scratch dir `/private/tmp/claude-501/-Users-jonathanstevenson-Source-claude-skills/b71aefe4-ae21-4000-aa3e-8b70fbcfbe94/scratchpad/tscheck-test1/w1/app`, `npm install --save-exact next@16.3.8 react react-dom typescript@7.0.2 @types/react @types/react-dom @types/node zod server-only client-only vitest @playwright/test @testing-library/react vite-tsconfig-paths @vitejs/plugin-react shiki jose ai @vercel/otel @vercel/firewall @opentelemetry/api` (resolved: next 16.3.8, react and react-dom 19.3.0, typescript 7.0.2, @types/react and @types/react-dom 19.3.0, @types/node 26.6.4, zod 4.6.5, server-only 0.0.1, client-only 0.0.1, vitest 5.0.3, @playwright/test 1.63.0, @testing-library/react 16.3.3, vite-tsconfig-paths 6.1.1, @vitejs/plugin-react 6.1.1, shiki 4.5.0, jose 6.2.12, ai 7.0.127, @vercel/otel 2.1.3, @vercel/firewall 1.2.5, @opentelemetry/api 1.9.1; all from npm). typescript 6.0.3 and 5.9.3 were installed beside it for the cross-check and the parse pass.
- Every ```` ```ts ```` and ```` ```tsx ```` fence of the ten files was extracted (218 fences: 160 Do/Pattern/rule, 58 inside the Don't half of an Anti-patterns entry). Each doc becomes one virtual Next.js project under `app/proj/<doc>/`: a fence whose first line is a `// path/to/file.ts` comment is written at that path (first occurrence only, Don't halves never), so `@/` and relative imports between fences resolve to the real fence; every other fence is its own module under `_loose/`. `next typegen` runs per project so the global `PageProps`, `LayoutProps` and `RouteContext` types exist; dummy `page.tsx`, `layout.tsx`, `route.ts` and `@slot` files are created for the route literals the fences use.
- Compiler config: the doc's own P1 `tsconfig.json` (`strict: true`, `noUncheckedIndexedAccess`, `lib: ES2020`, `moduleResolution: bundler`, ...) with `paths` `@/*` -> `./*` and `./src/*`; command `node node_modules/typescript/bin/tsc --noEmit --pretty false -p tsconfig.json` (TypeScript 7.0.2) in each project. Cross-checks: TypeScript 6.0.3 with the same config, and TypeScript 7.0.2 with the `create-next-app` default compilerOptions (`strict`, `target ES2017`, `lib dom/dom.iterable/esnext`).
- Prelude (declared, never silent): a fence that is a fragment gets only (a) `export {}` when it has no import or export, (b) a wrapper `async function __fragment() {` ... `}` when it is a bare statement list (TS1108 `return` outside a function), (c) an `import` of a well-known Next.js, React or Zod name (`z`, `redirect`, `notFound`, `revalidateTag`, `updateTag`, `cookies`, `Suspense`, ...) that the fence uses but does not import, (d) `declare var name: any` for any other free name the fence uses but does not define, (e) an any-typed stub module for a local `@/` or `./` import that no fence in the doc defines, (f) a typed export on the doc's own module when the doc says the module holds more than it shows. The records below say which fence got which.
- A fence with a parse error cannot be typechecked, so it is parked outside the project and reported on its own.

Result for `proxy-auth-and-security.md`: **20 fences = 14 Do/Pattern/rule + 6 Don't half. Do/Pattern/rule: 14 pass, 0 fail.**

Cross-checks for this file: TypeScript 6.0.3 with the same config reports 0 Do-fence error(s); TypeScript 7.0.2 with the `create-next-app` default compilerOptions reports 0.

#### Failures (Do/Pattern/rule fences)

None.

#### Pass with a declared prelude that deserves a look

None.

#### Prelude record

- 6 of 14 Do/Pattern/rule fences begin with a `// path` comment and sit at that path in the virtual project; the other 8 are standalone modules under `_loose/`.
- `export {}` was appended to 3 fences that had no import or export (fences #09, #11, #20); that only makes the fragment a module so names do not collide.
- Other preludes (Do/Pattern/rule fences only):

| Fence | Prelude |
| --- | --- |
| #02 (line 265) Data Access Layer | any-typed stub module: `lib/prisma.ts` |
| #04 (line 347) Server Action that authorises before it mutates | any-typed stub module: `lib/prisma.ts` |
| #05 (line 378) Route Handler | any-typed stub module: `lib/reports.ts` |
| #09 (line 493) Don't make Proxy the only gate (SEC-4, SEC-5) | free names declared `any`: `decrypt`, `request`, `verifySession` |
| #11 (line 516) Don't check auth only on the page (SEC-21) | free names declared `any`: `verifySession`, `prisma` |
| #13 (line 540) Don't trust the client's row (SEC-21, SEC-22) | import added: `z` from `zod`; free names declared `any`: `verifySession`, `prisma` |
| #16 (line 583) Don't return raw records to the client (SEC-13, SEC-16, SEC-23) | import added: `z` from `zod`; free names declared `any`: `verifySession`, `prisma` |
| #18 (line 607) Don't mutate cookies during render (SEC-10) | any-typed stub module: `_loose/actions.ts` |
| #20 (line 627) Don't set secrets in Proxy response headers (SEC-6) | wrapped in `async function __fragment()`; import added: `NextResponse` from `next/server`; free names declared `any`: `headers` |

#### Don't half (expected to be wrong; recorded, not failed)

| Fence | Outcome |
| --- | --- |
| #08 (line 481) Don't make Proxy the only gate (SEC-4, SEC-5) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #10 (line 502) Don't check auth only on the page (SEC-21) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #12 (line 529) Don't trust the client's row (SEC-21, SEC-22) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #15 (line 572) Don't return raw records to the client (SEC-13, SEC-16, SEC-23) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #17 (line 597) Don't mutate cookies during render (SEC-10) | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #19 (line 618) Don't set secrets in Proxy response headers (SEC-6) | compiles (the mistake is a runtime, security or caching rule, not a type error) |

## FIX①

Branch `wip/nextjs-typescript-best-practices-reference/proxy-auth-and-security-fix`, from
`origin/feat/nextjs-typescript-best-practices-reference`. Items: R1-C9, R1-C15, R1-C16, R1-C32 (full
text in the REVIEW① tables of `../review.md`). Each was reproduced first, then fixed.

| id | result | evidence |
| --- | --- | --- |
| R1-C9 | fixed (`test_one_rule_states_the_session_helper_contract_other_topics_import`, `test_ts_examples_name_files_in_the_canonical_src_layout`, `test_server_action_files_live_in_src_lib_actions`) | RED: 3 of the 6 new guards failed on the unfixed file (no rule named `src/lib/dal.ts` + `getSession` + `verifySession` + `src/lib/actions/`; snippets were named `lib/session.ts`, `proxy.ts`, `app/posts/actions.ts`, `app/api/reports/route.ts`). Behavioural: the 7 Patterns fences extracted to the paths their first-line comments name, under a strict tsc project with `@/*` -> `src/*`, gave 4 x TS2307 (`@/lib/dal` and `@/lib/session` not found from `app/api/reports/route.ts`, `app/posts/actions.ts`, `lib/dal.ts`, `proxy.ts`). After: new rule **SEC-46** states the contract (`src/lib/dal.ts`, imported as `@/lib/dal`; `getSession(): Promise<Session \| null>` never redirects; `verifySession(): Promise<Session>` redirects to `/login`; Server Actions in `src/lib/actions/`; snippets use the `src/` layout) and the Scope, the Patterns and the checklist cite it. Snippets are now `src/lib/session.ts`, `src/lib/dal.ts`, `src/proxy.ts`, `src/lib/actions/posts.ts`, `src/app/...` and root `next.config.ts`; the logout import is `@/lib/actions/auth`. The same extraction compiles with **tsc exit 0** (strict, `noUncheckedIndexedAccess`). The other topics' own snippets are their fixers' scope. |
| R1-C15 | fixed (`test_proxy_and_get_session_share_one_validity_function`) | RED: the guard failed (role check lived in `dal.ts`, Proxy gated on `session?.userId`). Behavioural (vitest, `next@16.3.8` real `NextRequest`, `jose`; `next/headers`, `next/navigation` and `server-only` stubbed): a validly signed token with `role: 'superuser'` gave `getSession() === null` and `proxy(/login)` redirecting to `/dashboard`, so `/dashboard` -> `/login` -> `/dashboard` loops (`loops: true`). After: the validity rule (good signature, unexpired, string `userId`, known `role`) lives in one function, `decrypt` in `src/lib/session.ts`, returning `Session \| null`; `getSession` and the Proxy both call it and gate on the returned session; SEC-4 states the rule. The same vitest case now passes (`loops: false`), and the admin-token case still redirects `/login` -> `/dashboard` with `getSession()` returning `{ userId, role }`. |
| R1-C16 | fixed (`test_security_headers_pattern_sends_the_frame_ancestors_sec_36_asks_for`) | RED: the guard failed (the `securityHeaders` array had HSTS, `nosniff`, Referrer-Policy and Permissions-Policy only). Behavioural: `await nextConfig.headers()` from the extracted `next.config.ts` had no `X-Frame-Options` and no `Content-Security-Policy` with `frame-ancestors`. Docs re-read (see `evidence/sources-verified.md` notes): the headers page says `X-Frame-Options` "has been superseded by CSP's `frame-ancestors` option" and the CSP guide's no-nonce example sets `Content-Security-Policy` from `next.config` `headers()` with `frame-ancestors 'none'`. After: the pattern sends `{ key: 'Content-Security-Policy', value: "frame-ancestors 'none'" }`; SEC-36 and its checklist item name it (CSP guide added as a source for that rule); a note says to keep `frame-ancestors` identical where `proxy.ts` also sets the nonce CSP (SEC-31), or drop it here `(convention)`. The vitest case passes. |
| R1-C32 | fixed (`test_session_secret_is_read_lazily_but_still_fails_closed`) | RED: the guard failed (`const secret = process.env.SESSION_SECRET` at module scope, then a module-level `throw`). Behavioural, real build: the extracted snippets plus a `/dashboard` page calling `verifySession()` under `next@16.3.8`, run as `next build` with `SESSION_SECRET` unset, exit 1: `Failed to collect page data for /dashboard`, cause `Error: SESSION_SECRET is not set at module evaluation (src/lib/session.ts:10:20)`. After: `getKey()` reads the secret inside the function that signs or verifies, and `decrypt` calls it outside its `try`, so a missing secret is a server error, not a silent "signed out". The same `next build` with the secret unset exits 0 (`/dashboard` and `/api/reports` dynamic, Proxy compiled). Vitest: importing the session module with no secret resolves, and `encrypt` still rejects with `SESSION_SECRET is not set`. SEC-8 and its checklist item state the lazy read. |

### Gates (after the fix)

- New text guards in `test_nextjs_topic_proxy_auth_and_security.py`: 6 added; **6 failed on the unfixed
  file** (24 collected: 6 failed, 18 passed) and all **24 pass** after.
- With `test_nextjs_reference.py`: 209 passed. Full suite
  `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`: **1032 passed**.
  Lint `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope`: All checks passed!
- `wc -l` of the topic file: 798 (cap 800).
- Sources equals evidence: 43 and 43, none missing, none extra, no prose URL outside Sources.
- Strict tsc over the 7 Patterns fences (scratch project in the session scratchpad, `next@16.3.8`,
  `react@19`, `jose`, `zod`, `server-only`, typed stubs for `@/lib/prisma` and `@/lib/reports`): exit 0.
  Nothing from the scratch project is committed.

### Assumptions

1. The session-helper contract is a new rule, SEC-46, appended so no SEC id moves. `Session` is
   `{ userId: string; role: 'admin' | 'user' }` in the snippets and "carries `userId` and `role`" in the
   rule, so a project can widen the role union.
2. `SessionPayload` (with `expiresAt`) is gone: the JWT carries `userId` and `role` and its own `exp`;
   the cookie `expires` is computed in `createSession`. `decrypt` returns `Session | null` (it returned
   the loose JWT payload or `undefined`).
3. The frame-ancestors header is `frame-ancestors 'none'` (matching the nonce CSP pattern), with no
   `X-Frame-Options` sent beside it, because the docs call that header superseded.
4. Rewriting the other topics' session-helper imports (`@/lib/dal/session`, `@/lib/auth/session`,
   `@/lib/auth`) belongs to their own fixers; this file only defines the contract they align to.

## TEST2: unit (2026-10-04)

Branch `wip/nextjs-typescript-best-practices-reference/tests-unit-2`, cut from the detached run base `origin/dev` `7acb627` (the run branch after the FIX① merges). Tester: `tests-unit-2`. No code was changed; verification pass after FIX①.

| Step | Command | Result |
| --- | --- | --- |
| Full suite with coverage | `uv run --quiet --with pytest --with pytest-cov python -m pytest Skills/dev-bother-me-nope/assets/tests -q --cov=Skills/dev-bother-me-nope/assets/tests --cov-report=term` | **1247 passed in 199.90s (0:03:19)**, exit 0, 0 failed, 0 skipped. Log: `docs/sprints/bmn-nextjs-typescript-best-practices-reference/nextjs-standard-entry-point-and-skill-wiring/evidence/test2-unit-full-suite.txt` |
| Per-test outcomes | same suite with `-v -p no:cacheprovider` | 1247 PASSED, 0 other (117.86s). Per-story lists: `docs/sprints/bmn-nextjs-typescript-best-practices-reference/proxy-auth-and-security/evidence/test2-unit-results.txt` |
| Lint | `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` | `All checks passed!` |

### Coverage

- `test_nextjs_topic_proxy_auth_and_security.py`: **98%** (131 of 134 statements; lines 63-64, 167).
- `references/nextjs/proxy-auth-and-security.md`: Markdown, coverage n/a.
- Whole suite: **99%** (4605 of 4642 statements). Target 80% met; `nextjs_doc_helpers.py` is the shared parser every story's tests use.

### FIX① tests

- **6 of 6** test names this story's FIX① section lists exist and PASS (none missing, none failing).

### [unit] criteria still map to passing tests

- TEST1 criterion map: 11 PASS, 0 FAIL. Re-checked now: **15 of 15** tests it cites exist and PASS. Every criterion still maps to at least one passing test; the one-off criteria (grounding evidence, scope) are unchanged and not re-run here.

**Result:** 6 FIX① tests PASS, 11 criteria PASS, 0 FAIL.

## TEST2 content

Run 2026-10-04 on a detached worktree at `origin/dev` `7acb627` (branch `wip/nextjs-typescript-best-practices-reference/tests-content-2`). Delta only: `references/nextjs/proxy-auth-and-security.md` between `5d7550d` (run branch at TEST1) and `7acb627`. Everything else was TEST1's.

### 1. Live sources (delta)

No `## Sources` URL is new or changed in this file (the URL set equals TEST1's). Result: **0 URLs to check, 0 fail**.

Extended check: every URL on an added or changed line of this file, in prose and rules as well as `## Sources` (3 distinct), fetched the same way: **3 pass, 0 fail**.

### 2. Snippet type-check (delta fences)

New or changed fences (text differs from every TEST1 fence): **13 = 9 Do/Pattern/rule + 4 Don't half**.

Result: **Do/Pattern/rule: 9 pass, 0 fail.** Cross-checks with the same config: TypeScript 6.0.3 reports 0 Do-fence error(s), TypeScript 5.9.3 reports 0.

#### Failures (Do/Pattern/rule fences)

None.

#### Pass with a declared prelude that deserves a look

None.

#### Prelude record (delta fences)

- 6 of 9 Do/Pattern/rule fences begin with a `// path` comment and sit at that path in the virtual project; the other 3 are standalone modules under `_loose/`.
- `export {}` appended to 0 Do/Pattern/rule fence(s).
- Other preludes (Do/Pattern/rule fences only):

| Fence | Prelude |
| --- | --- |
| #02 (line 285) Data Access Layer | any-typed stub module: `src/lib/prisma.ts` |
| #04 (line 360) Server Action that authorises before it mutates | any-typed stub module: `src/lib/prisma.ts` |
| #05 (line 391) Route Handler | any-typed stub module: `src/lib/reports.ts` |
| #18 (line 624) Don't mutate cookies during render (SEC-10) | any-typed stub module: `src/lib/actions/auth.ts` |

#### Don't half (expected to be wrong; recorded, not failed)

| Fence | Outcome |
| --- | --- |
| #08 (line 498) Don't make Proxy the only gate (SEC-4, SEC-5) | compiles (the mistake is a runtime, security or caching rule, not a type error); prelude: import added: `NextRequest`, `NextResponse`; free names declared `any`: `prisma` |
| #10 (line 519) Don't check auth only on the page (SEC-21) | compiles (the mistake is a runtime, security or caching rule, not a type error); prelude: free names declared `any`: `verifySession`, `prisma` |
| #17 (line 614) Don't mutate cookies during render (SEC-10) | compiles (the mistake is a runtime, security or caching rule, not a type error); prelude: import added: `cookies`; free names declared `any`: `Profile` |
| #19 (line 635) Don't set secrets in Proxy response headers (SEC-6) | compiles (the mistake is a runtime, security or caching rule, not a type error); prelude: import added: `NextResponse`; free names declared `any`: `request`, `token`; wrapped |

### 3. Session-helper consistency (text only)

| Line | Import | From | Context |
| --- | --- | --- | --- |
| 286 | `decrypt, type Session` | `@/lib/session` | proxy/DAL |
| 324 | `decrypt` | `@/lib/session` | proxy/DAL |
| 361 | `verifySession` | `@/lib/dal` | Server Action |
| 392 | `getSession` | `@/lib/dal` | Route Handler |

- `src/lib/dal.ts` (line 286) and `src/proxy.ts` (line 324) import `decrypt` (and `type Session`) from `@/lib/session`. That is the doc's cookie and crypto module (`src/lib/session.ts`, line 222), shared only by the DAL and the Proxy so that the Proxy's validity rule is the one `getSession()` uses (SEC-46); the consumer-facing contract is `@/lib/dal`, and no Route Handler, SSE route, API, page or action in any file imports `@/lib/session`. Recorded, not a failure.

- The Don't-half fences at lines 511, 520 (page), 534, 547, 558, 590 and 601 call `verifySession()` with no import line (fragments); nothing there names another path.

Result: **0 fail**. Each session helper is imported from `@/lib/dal` (the two `@/lib/session` imports are the contract's own internals, see above); `getSession` appears in Route Handlers and SSE/API routes, `verifySession` in Server Actions and pages.
