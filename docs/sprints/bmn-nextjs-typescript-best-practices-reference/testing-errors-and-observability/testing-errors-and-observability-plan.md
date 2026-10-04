# Plan — testing-errors-and-observability

Story: [story.md](story.md) · Run: `bmn-nextjs-typescript-best-practices-reference` · Planner date: 2026-10-04.
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.
Owns `R/nextjs/testing-and-observability.md` (prefix `TEST`) and
`Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_testing_and_observability.py`.

## 1. Approach

1. **Research first, write second.** Every page below was fetched live on 2026-10-04. nextjs.org and vercel.com pages were fetched as raw Markdown (`curl <url>.md` returns `text/markdown`), so the snippets in this plan are copied, not paraphrased. vitest.dev and playwright.dev pages were read with WebFetch. The coder writes the topic file from the **Verified rule sheet** (section 7) and adds no rule that isn't on it.
2. **Version.** The latest stable release is **Next.js 16.3.8**: npm `dist-tags.latest = 16.3.8`, published 2026-09-30T16:07Z, and `https://nextjs.org/docs/llms.txt` reports `@doc-version: 16.3.8`. The coder copies the as-of line verbatim from the merged `R/nextjs.md`. If the skeleton chose a different version, the coder re-reads the Version notes candidates against that version.
3. **Contract first.** The skeleton story's Authoring contract fixes the section order, the rule format, citations, floors, Sources, the 800-line cap and the hygiene rules. The coder reads the merged `nextjs_doc_helpers.py` and `test_nextjs_reference.py` before writing a word, and matches their parsers exactly.
4. **Honesty labels.** A docs fact carries an inline nextjs.org / vercel.com link (or vitest.dev / playwright.dev for those tools' own APIs). A house rule carries `(convention)`. The 80% coverage floor is Jonathan's rule and is labelled that way. Route Handler and Server Action unit testing is a convention, because no Next.js page describes it. Unconfirmed items go only under `## Not confirmed by the docs`.
5. **Skill guidance applied.** The brief routes no skill (stack.md: Markdown content; `nextjs-fullstack-standards` isn't loadable, so it is never approximated). The guidance applied is the repo's own: tests first (`rules/ecc/common/testing.md`), Don't/Do pairs, and short typed examples with no `any` (story AC4).
6. **No overlap.** Route conventions for `not-found` belong to `routing-and-metadata.md`, the Server Action typed-state pattern to `data-fetching-and-mutations.md`, the handler API design to `route-handlers-and-apis.md`, proxy details to `proxy-auth-and-security.md`, Speed Insights depth to `performance-and-vercel.md`, and tsconfig to `typescript.md`. This file states its rule and links to the owner by relative file link.

## 2. Files to create or change

| File | Purpose |
| --- | --- |
| `R/nextjs/testing-and-observability.md` | Replaces the stub entirely with the topic standard (section 8 gives the outline). |
| `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_testing_and_observability.py` | The topic tests (section 3). Stdlib only, plus the shared `nextjs_doc_helpers`. Ruff-clean. |
| `docs/sprints/bmn-nextjs-typescript-best-practices-reference/testing-errors-and-observability/evidence/sources-verified.md` | AC9 evidence. One row per `## Sources` URL, giving the URL, `2026-10-04` (fetched live this run), the fetch method and the rule ids it backs (from section 7). |
| `docs/sprints/bmn-nextjs-typescript-best-practices-reference/testing-errors-and-observability/validation.md` | Written by validation: the AC results, the one-off URL-set equality check (AC9), the no-skip proof (AC1), the diff-scope proof (AC10), and any shared-file defects for REVIEW①. |

No other file is touched (AC10). The shared files (`nextjs.md`, `stack-routing.md`, the helpers and the generic tests) are read-only for this story.

## 3. Test plan (written first; RED before the topic file exists)

All topic tests live in `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_testing_and_observability.py`, type **unit** (pytest, offline). The module:

- imports `nextjs_doc_helpers as h`. pytest's default `prepend` import mode puts the test directory on `sys.path`, because the directory has no `__init__.py` and there is no pytest config in the repo;
- sets `TOPIC = h.TOPICS_DIR / "testing-and-observability.md"`;
- reads the file once through a module-level helper `_text()` that returns `h.read(TOPIC)`.

Before writing, the coder confirms each helper's exact signature in the merged module. Two calls are guesses: `h.section(text, "Rules")` (heading text without `## `) and `h.as_of_version(text)` (returns `"16.3.8"`). If the merged helper differs, the coder adapts the call, not the intent.

`TERMS` is the exact tuple from AC3:
`("vitest", "@vitejs/plugin-react", "jsdom", "async Server Components", "next/jest", "playwright", "webServer", "next build", "next start", "instrumentation.ts", "register", "onRequestError", "@vercel/otel", "instrumentation-client", "error.tsx", "global-error.tsx", "not-found.tsx", "'use client'", "expected errors", "useReportWebVitals", "logging")`.

| AC | Test name | Asserts |
| --- | --- | --- |
| 1 | the generic tests in `test_nextjs_reference.py`, parametrised over every non-stub topic (skeleton-owned) | The as-of line equals `nextjs.md`'s, plus section order, rule format, citations, floors, Sources hosts, ≤800 lines, tagged fences and resolving links, all for `testing-and-observability.md`. Validation proves **no skip** with `pytest …/test_nextjs_reference.py -q -rs` and checks that no `SKIPPED` line names `testing-and-observability.md`. |
| 1 | `test_rule_ids_use_only_the_test_prefix` | Every id from `h.rule_items(text)` matches `^TEST-\d+$`, and the whole file has no `**TS-n**` / `**RT-n**` / `**RC-n**` / `**DF-n**` / `**API-n**` / `**SSE-n**` / `**SEC-n**` / `**PERF-n**` token (regex `\*\*(?:TS\|RT\|RC\|DF\|API\|SSE\|SEC\|PERF)-\d+\*\*`). |
| 2 | `test_topic_file_is_not_a_stub` | `h.is_stub(text) is False`. |
| 2 | `test_topic_file_has_at_least_15_test_rules` | `len(h.rule_items(text)) >= 15`. |
| 3 | `test_required_terms_are_present` | `h.missing_terms(text, TERMS) == []`. |
| 4 | `test_has_vitest_config_example` | `h.has_block_with(text, "defineConfig", "jsdom")`. |
| 4 | `test_has_playwright_config_example` | `h.has_block_with(text, "defineConfig", "webServer")`. |
| 4 | `test_has_instrumentation_example` | `h.has_block_with(text, "register", "onRequestError")`. |
| 4 | `test_has_global_error_example` | `h.has_block_with(text, "'use client'", "<html", "<body")`. |
| 4 | `test_has_segment_error_boundary_example` | Some `ts`/`tsx` block from `h.code_blocks(text, ("ts", "tsx"))` contains `'use client'`, `digest` and `retry`, and does **not** contain `<html`. Without that last check the global-error block alone would satisfy it. |
| 4 | `test_typescript_examples_never_use_any` | No `ts`/`tsx` block matches `r":\s*any\b\|<any>\|\bas any\b\|any\[\]"`. |
| 5 | `test_rules_state_async_server_component_limit_with_testing_guide_link` | `section(text, "Rules")` contains `async Server Components` (exact case) and matches `https://nextjs\.org/docs/app/guides/testing`. |
| 5 | `test_rules_map_onto_bmn_test_surfaces` | The Rules section contains `../stack-routing.md`, `unit` and `browser`, and a rule containing `Playwright` also contains `async Server Components`. |
| 6 | `test_rules_separate_expected_errors_from_global_error` | The Rules section contains `expected errors` and `global-error`, plus `<html>` and `<body>` (what global-error must render). |
| 7 | `test_version_notes_name_the_major_and_link_nextjs` | `major = h.as_of_version(text).split(".")[0]`. `section(text, "Version notes")` is non-empty, contains `f"Next.js {major}"` and contains `https://nextjs.org/`. |
| 8 | `test_every_review_checklist_item_names_a_rule` | Every line of `section(text, "Review checklist")` that starts (after whitespace) with `- [ ]` contains `TEST-`, and there are at least 8 such lines. |
| 8 | `test_every_anti_pattern_pairs_dont_with_do` | The Anti-patterns section splits on the Don't marker (default `### Don't:`, see section 8). There are at least 3 chunks. Each chunk holds a `**Do:**` line and at least 2 fenced blocks. The marker is a module constant, `DONT_MARKER`, so it follows whatever format the generic test parses. |
| 9 | validation-only, not a pytest | The `## Sources` URL set equals the URL set in `evidence/sources-verified.md`. The command is in section 6, and its output is recorded in `validation.md`. |
| 10 | validation-only | `git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists only the two owned files plus this story folder. The full suite and ruff are green. |

**Count:** 16 new topic tests (AC1–8), the skeleton's generic tests running on the new file, and 2 one-off validation checks (AC9, AC10). No browser criteria: the story is all `[unit]` and the repo has no UI, so there are no Playwright tests.

RED order: write the test module, then run `pytest …/test_nextjs_topic_testing_and_observability.py -q`. The file is still a stub, so `is_stub` and every content test must fail. Only then does the coder write the topic file and turn it GREEN.

## 4. Data

None. There are no models, migrations or Supabase changes (stack.md: `supabase: false`).

## 5. Config, env vars and deploy_pending

- This repo gets no new env vars or config.
- Env var **names quoted in the topic file**, for documentation only: `NEXT_RUNTIME`, `NEXT_OTEL_VERBOSE`, `NEXT_OTEL_FETCH_DISABLED`, `NODE_OPTIONS`, `NODE_ENV`, `CI`, and `E2E_PORT` (convention).
- `deploy_pending: []`. This is Markdown plus tests: no Vercel, no Supabase.

## 6. Risks and gate commands

**Risks.**

1. **Helper or contract drift.** The skeleton is being planned in parallel. The coder therefore reads the merged `nextjs_doc_helpers.py`, `test_nextjs_reference.py` and `R/nextjs.md` (Authoring contract) first. Anything that differs from this plan follows the merged code, and the difference is logged in validation.md.
2. **The 800-line cap.** Budget: H1 + as-of 3, Scope ~14, Rules ~95 (38 one-line rules + 5 H3s), Patterns ~260, Anti-patterns ~150, Version notes ~20, Checklist ~22, Not confirmed ~16, Sources ~52, for about 630 lines. Check with `wc -l`.
3. **Citation parsing.** Keep each rule on **one physical line**, with its links on that line. Use **no `#fragment`, query string or trailing-slash variants** in any URL, so that prose URLs equal the Sources entries exactly. Link to other topics only with relative links (`data-fetching-and-mutations.md`, `../stack-routing.md`).
4. **A false-positive segment example.** The global-error block also holds `'use client'` and `digest`. The custom test therefore excludes `<html`.
5. **Doc drift after 2026-10-04.** The file is pinned by its as-of line. Version notes cite the release posts.
6. **Overlap with sibling topics.** State the rule here, link the owner, and don't duplicate its patterns (section 1, item 6).
7. **Case.** `missing_terms` is case-insensitive, but the AC5/AC6 checks are exact-substring. Write `async Server Components` and `expected errors` exactly like that inside Rules.

**Gates** (the coder runs them in the run worktree or its own worktree):

```bash
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_testing_and_observability.py -q   # RED first, then GREEN
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests/test_nextjs_reference.py -q -rs | grep -i "testing-and-observability" || true   # AC1: expect no SKIPPED line
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q          # full suite (~110 s)
uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope
wc -l Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/testing-and-observability.md   # ≤ 800
git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD                # AC10 scope
```

AC9 one-off check, recorded in validation.md and never added to the suite:

```bash
python3 - <<'EOF'
import re, sys
sys.path.insert(0, "Skills/dev-bother-me-nope/assets/tests")
import nextjs_doc_helpers as h
topic = h.read(h.TOPICS_DIR / "testing-and-observability.md")
ev = open("docs/sprints/bmn-nextjs-typescript-best-practices-reference/testing-errors-and-observability/evidence/sources-verified.md").read()
a, b = set(h.source_urls(topic)), set(re.findall(r"https://[^\s)|>`]+", ev))
print("EQUAL" if a == b else f"MISSING_IN_EVIDENCE={sorted(a-b)} EXTRA_IN_EVIDENCE={sorted(b-a)}")
EOF
```

## 7. Verified rule sheet

Each entry gives:

- **Rule:** the imperative to write, in substance, as one physical line under `## Rules`. The coder may tighten the wording but not add claims.
- **Src:** the URL(s) to link inline.
- **Says:** a one-line paraphrase of what the page says.
- **Verified snippet:** the code checked against the page (only where an example is used).

**⚠ 16.x change** flags an API that changed in the latest major.

### A. Test surfaces and unit tools

- **TEST-1**
  - **Rule:** Map every acceptance criterion onto bmn's test surfaces in [stack-routing.md](../stack-routing.md) (convention).
    - The **unit** surface (Vitest or Jest) covers pure functions, schema parsing, hooks, Client Components, synchronous Server Components and the logic behind Server Actions and Route Handlers.
    - The **browser** surface (Playwright) covers async Server Components, full user flows, error boundaries and not-found UI.
    - The **HTTP** surface covers Route Handlers through Playwright's `request` fixture.
  - **Src:** https://nextjs.org/docs/app/guides/testing
  - **Says:** Defines unit, component, integration, E2E and snapshot tests. Async Server Components are better covered by E2E.
- **TEST-2**
  - **Rule:** Test async Server Components end to end with Playwright, never with a Vitest or Jest render. Unit-test only synchronous Server Components and Client Components.
  - **Src:**
    - https://nextjs.org/docs/app/guides/testing
    - https://nextjs.org/docs/app/guides/testing/vitest
    - https://nextjs.org/docs/app/guides/testing/jest
  - **Says:** "`async` Server Components are new to the React ecosystem". Vitest and Jest currently don't support them. Unit tests still work for synchronous Server and Client Components, and the docs recommend E2E for `async` components.
- **TEST-3**
  - **Rule:** Keep a repo's existing test runners (convention). On a repo with none, add Vitest for unit tests and Playwright for E2E, which both have official Next.js setup guides. Where Cypress is already used, keep it and run it against `npm run build && npm run start`. Its Component Testing doesn't support async Server Components either.
  - **Src:**
    - https://nextjs.org/docs/app/guides/testing/vitest
    - https://nextjs.org/docs/app/guides/testing/playwright
    - https://nextjs.org/docs/app/guides/testing/cypress
  - **Says:** On the Cypress page: "Cypress currently doesn't support Component Testing for `async` Server Components". For E2E it says "Run `npm run build && npm run start` …".
- **TEST-4**
  - **Rule:** Set up Vitest exactly as the Next.js guide does:
    - install `vitest @vitejs/plugin-react jsdom @testing-library/react @testing-library/dom vite-tsconfig-paths` as dev dependencies;
    - write `vitest.config.mts` with `defineConfig` from `vitest/config`, `plugins: [tsconfigPaths(), react()]` and `test.environment: 'jsdom'`.
  - **Src:**
    - https://nextjs.org/docs/app/guides/testing/vitest
    - https://vitest.dev/config/environment
  - **Says:** The guide shows this exact config. vitest.dev: `environment` defaults to `'node'`, and `jsdom` / `happy-dom` give a browser-like environment.
  - **Verified snippet** (guide, `vitest.config.mts`):

    ```ts
    import { defineConfig } from 'vitest/config'
    import react from '@vitejs/plugin-react'
    import tsconfigPaths from 'vite-tsconfig-paths'

    export default defineConfig({
      plugins: [tsconfigPaths(), react()],
      test: {
        environment: 'jsdom',
      },
    })
    ```
- **TEST-5**
  - **Rule:** Configure Jest only through `next/jest`:
    - `nextJest({ dir: './' })`, with `testEnvironment: 'jsdom'` and `coverageProvider: 'v8'`;
    - `export default createJestConfig(config)`;
    - add `moduleNameMapper` entries for path aliases.
  - **Src:** https://nextjs.org/docs/app/guides/testing/jest
  - **Says:** `next/jest` sets the transform to the Next.js Compiler (SWC). It also:
    - auto-mocks stylesheets, images and `next/font`;
    - loads `.env*` into `process.env`;
    - ignores `node_modules` and `.next`;
    - loads `next.config.js`.

    The export pattern exists "to ensure that next/jest can load the Next.js config which is async".
  - **Verified snippet:** `import type { Config } from 'jest'`, `import nextJest from 'next/jest.js'`, `const createJestConfig = nextJest({ dir: './' })`.
- **TEST-6**
  - **Rule:** Run unit tests once in gates with `vitest run` (or `jest`). The `vitest` script watches by default.
  - **Src:**
    - https://nextjs.org/docs/app/guides/testing/vitest
    - https://vitest.dev/guide/
  - **Says:** "When you run `npm run test`, Vitest will **watch** for changes … by default." vitest.dev: "To run tests once without watching for file changes, use `vitest run`."
- **TEST-7**
  - **Rule:** Write each test before its code (RED, then GREEN) and hold unit coverage at **80% or more**. Both are Jonathan's bmn rule (convention), not a docs requirement. Enforce the floor:
    - in Vitest, through `coverage.thresholds` with the v8 provider (`@vitest/coverage-v8`), and set `coverage.include` so untested files count;
    - in Jest, through `coverageProvider: 'v8'`.
  - **Src:**
    - https://vitest.dev/config/coverage
    - https://vitest.dev/guide/coverage
    - https://nextjs.org/docs/app/guides/testing/jest
  - **Says:** A positive `thresholds` number is the minimum percentage. v8 is the default provider and needs `@vitest/coverage-v8`. "By default Vitest will show only files that were imported during test run"; use `include: ['src/**/*.{ts,tsx}']`.
- **TEST-8**
  - **Rule:** Commit test defaults in `.env.test`, and never depend on `.env.local` in tests. In Vitest, load env vars the way Next.js does with `loadEnvConfig(process.cwd())` from `@next/env` in a setup file. `next/jest` already loads `.env` files.
  - **Src:**
    - https://nextjs.org/docs/app/guides/environment-variables
    - https://nextjs.org/docs/app/guides/testing/jest
  - **Says:** In the `test` environment, `.env.local` isn't loaded and `.env.test` should be committed. For unit tests, use `loadEnvConfig` from `@next/env`.
- **TEST-9**
  - **Rule:** Unit-test a Route Handler as a plain function (convention): import its exported `GET`/`POST`, call it with a Web `Request`, and assert on the returned `Response`. Run those files with `// @vitest-environment node`.
  - **Src:**
    - https://nextjs.org/docs/app/api-reference/file-conventions/route
    - https://vitest.dev/config/environment
  - **Says:** Route Handlers "use the Web Request and Response APIs", for example `export async function GET(request: Request) {}`. Vitest supports a per-file `// @vitest-environment <env>` comment.
- **TEST-10**
  - **Rule:** Move Server Action logic into plain functions that take parsed input and return a typed result, and unit-test those (convention). Cover the `'use server'` action itself end to end, because:
    - Request-time APIs such as `cookies()` and `headers()` must run inside a request scope;
    - `redirect()` throws a `NEXT_REDIRECT` error.
  - **Src:**
    - https://nextjs.org/docs/messages/next-dynamic-api-wrong-context
    - https://nextjs.org/docs/app/api-reference/functions/redirect
  - **Says:** Calling a Request-time API "outside a request scope" is an error. Invoking `redirect()` "throws a `NEXT_REDIRECT` error and terminates rendering".
- **TEST-11**
  - **Rule:** Unit-test `proxy.ts` matching and rewrites with the experimental helpers from `next/experimental/testing/server`: `unstable_doesProxyMatch`, `isRewrite` and `getRewrittenUrl`. Detail lives in [proxy-auth-and-security.md](proxy-auth-and-security.md).
  - **Src:** https://nextjs.org/docs/app/api-reference/file-conventions/proxy
  - **Says:** Under "Unit testing (experimental)" (since 15.1): `unstable_doesProxyMatch({ config, nextConfig, url })`, `isRewrite(response)` and `getRewrittenUrl(response)`. `getRedirectUrl` is also mentioned.

### B. End-to-end tests

- **TEST-12**
  - **Rule:** Run Playwright E2E against a production build. Use `webServer` with `command: 'npm run build && npm run start'`, `url`, `reuseExistingServer: !process.env.CI` and `use.baseURL`. Raise `webServer.timeout` above its 60000 ms default when the build needs longer. Using one command that both builds and starts is a (convention) joining two documented pieces.
  - **Src:**
    - https://nextjs.org/docs/app/guides/testing/playwright
    - https://playwright.dev/docs/test-webserver
  - **Says:** Next.js: "We recommend running your tests against your production code". Run `npm run build` and `npm run start`, then `npx playwright test`; "alternatively, you can use the `webServer` feature". Playwright documents the `webServer` options (`command`, `url`, `reuseExistingServer`, `timeout` default 60000, `stdout`, `stderr`). It recommends `baseURL` in `use`.
  - **Verified snippet** (playwright.dev):

    ```ts
    import { defineConfig } from '@playwright/test'
    export default defineConfig({
      webServer: { command: 'npm run start', url: 'http://localhost:3000', reuseExistingServer: !process.env.CI },
      use: { baseURL: 'http://localhost:3000' },
    })
    ```
- **TEST-13**
  - **Rule:** Give each worktree's E2E run its own port: pass `next start -p <port>` and point `webServer.url` and `baseURL` at it. That way `reuseExistingServer` never attaches to another checkout's server (convention).
  - **Src:**
    - https://nextjs.org/docs/app/api-reference/cli/next
    - https://playwright.dev/docs/test-webserver
  - **Says:** `next start -p/--port` (default 3000). `reuseExistingServer: true` "will re-use an existing server on the `port` or `url` when available".
- **TEST-14**
  - **Rule:** Use visibility-aware locators in E2E: `getByRole`, `getByLabel`, `getByPlaceholder`, or `.filter({ visible: true })`. Cache Components keeps previously visited routes in the DOM as hidden Activity, so a bare `locator()` can match hidden elements.
  - **Src:** https://nextjs.org/docs/app/guides/preserving-ui-state
  - **Says:** Under "Testing": hidden Activity content stays in the document with `display: none`. "DOM queries can find hidden elements". `getByRole` "filter[s] by visibility automatically"; the fallback is `.filter({ visible: true })`.
- **TEST-15**
  - **Rule:** Cover a Route Handler's HTTP contract with Playwright's `request` fixture against the same `webServer`. It honours `use.baseURL`, and it is bmn's HTTP black-box surface for a Next.js repo (convention).
  - **Src:** https://playwright.dev/docs/api-testing
  - **Says:** "Playwright can be used to get access to the REST API of your application". The `request` fixture respects `baseURL`. Example: `const res = await request.post(...); expect(res.ok()).toBeTruthy()`.
- **TEST-16**
  - **Rule:** When a story promises an instant navigation (Cache Components), assert it with `instant()` from `@next/playwright`. Against `next start`, set `experimental.exposeTestingApiInProductionBuild: true`. **⚠ 16.x change:** new in 16.3.
  - **Src:**
    - https://nextjs.org/docs/app/guides/instant-navigation
    - https://nextjs.org/blog/next-16-3
  - **Says:** `instant(page, async () => { … }, { baseURL })` scopes assertions to the instantly available UI. The testing API is on automatically under `next dev`; for `next start` it needs `exposeTestingApiInProductionBuild`.
- **TEST-17**
  - **Rule:** Give every error and not-found path an E2E test (convention). Force the failure, assert that the `error.tsx` fallback renders and that `retry()` recovers. Request a missing resource and assert the `not-found.tsx` UI. Unit tools can't render these async boundaries.
  - **Src:**
    - https://nextjs.org/docs/app/guides/testing
    - https://nextjs.org/docs/app/api-reference/file-conventions/error
  - **Says:** Use E2E for async components. Error boundaries show fallback UI, and `retry()` re-renders the segment.

### C. Error handling

- **TEST-18**
  - **Rule:** Return expected errors (validation failures, failed requests) as values, never by throwing:
    - in a Server Function, return state that `useActionState` reads;
    - in a Server Component, render the error or call `redirect()`.

    The typed-state pattern lives in [data-fetching-and-mutations.md](data-fetching-and-mutations.md). The phrase `expected errors` must appear literally in this rule.
  - **Src:** https://nextjs.org/docs/app/getting-started/error-handling
  - **Says:** "Expected errors are those that can occur during the normal operation". For these errors, "avoid using `try`/`catch` blocks and throw errors. Instead, model expected errors as return values."
- **TEST-19**
  - **Rule:** Throw for uncaught exceptions (bugs), and let error boundaries catch them. Add an `error.tsx` to each route segment that needs its own fallback; errors bubble up to the nearest parent boundary. `error.tsx` doesn't catch errors from the `layout.tsx`/`template.tsx` of its own segment.
  - **Src:**
    - https://nextjs.org/docs/app/getting-started/error-handling
    - https://nextjs.org/docs/app/api-reference/file-conventions/error
  - **Says:** Uncaught exceptions "should be handled by throwing errors, which will then be caught by error boundaries". `error.js` wraps `loading.js`, `not-found.js`, `page.js` and nested layouts, but "does **not** wrap the `layout.js` or `template.js` above it in the same segment".
- **TEST-20**
  - **Rule:** Start every `error.tsx` and `global-error.tsx` with `'use client'`.
    - Type the props `{ error: Error & { digest?: string }; retry: () => void }`.
    - Recover with `retry()`, which re-fetches and re-renders the boundary's children.
    - Use `reset()` only to clear error state without re-fetching.

    **⚠ 16.x change:** `retry` became stable in 16.3; `unstable_retry` arrived in 16.2.
  - **Src:**
    - https://nextjs.org/docs/app/api-reference/file-conventions/error
    - https://nextjs.org/blog/next-16-3
  - **Says:** "Error boundaries must be Client Components". `retry()` "will try to re-fetch and re-render the error boundary's children". "In most cases, you should use `retry()` instead" of `reset()`. Version history: `v16.3.0` `retry` stable, `v16.2.0` `unstable_retry` added.
  - **Verified snippet** (props shape): `{ error, retry }: { error: Error & { digest?: string }; retry: () => void }`.
- **TEST-21**
  - **Rule:** Show a generic message in error UI and correlate it through `error.digest`. Never present `error.message` from a Server Component error as detail: production forwards only a generic message plus the digest. Handing the user the digest as a reference id is (convention).
  - **Src:**
    - https://nextjs.org/docs/app/api-reference/file-conventions/error
    - https://vercel.com/kb/guide/add-structured-application-logs-to-vercel-functions
  - **Says:** "Errors forwarded from Server Components show a generic message with an identifier". `digest` is "an automatically generated hash … to match the corresponding error in server-side logs". The KB says: "Pass `errorId` to the client response instead of raw error messages or stack traces."
- **TEST-22**
  - **Rule:** Add `app/global-error.tsx`.
    - It renders its own `<html>` and `<body>`.
    - It imports the global styles and fonts it needs.
    - It sets the page title with React `<title>`, because `metadata` / `generateMetadata` exports aren't supported there.

    It replaces the root layout while active. The literal `global-error` must appear in Rules.
  - **Src:**
    - https://nextjs.org/docs/app/api-reference/file-conventions/error
    - https://nextjs.org/docs/app/guides/production-checklist
  - **Says:** "Global error UI must define its own `<html>` and `<body>` tags, global styles, fonts, or other dependencies". "`metadata` and `generateMetadata` exports are not supported in `global-error.jsx`". The checklist says: "Add `app/global-error.tsx` to provide consistent, accessible fallback UI".
- **TEST-23**
  - **Rule:** Call `redirect()`, `permanentRedirect()`, `notFound()`, `forbidden()` and `unauthorized()` outside any `try` block, since each one works by throwing. Where a `catch` can't be avoided, call `unstable_rethrow(err)` first in it. It is unstable, so prefer moving the call out of the `try`.
  - **Src:**
    - https://nextjs.org/docs/app/api-reference/functions/redirect
    - https://nextjs.org/docs/app/api-reference/functions/permanentRedirect
    - https://nextjs.org/docs/app/api-reference/functions/not-found
    - https://nextjs.org/docs/app/api-reference/functions/forbidden
    - https://nextjs.org/docs/app/api-reference/functions/unstable_rethrow
  - **Says:**
    - `redirect` "throws an error so it should be called **outside** the `try` block".
    - `notFound()` throws `NEXT_HTTP_ERROR_FALLBACK;404`, and "A `try/catch` around the call suppresses it".
    - `forbidden` is the same (experimental, `authInterrupts`).
    - `unstable_rethrow` "should be called at the top of the catch block" and is "not recommended for production".
- **TEST-24**
  - **Rule:** Build component-level error boundaries with `catchError` from `next/error`, not a hand-rolled React class boundary. `catchError` lets `redirect()`/`notFound()` pass through, its `retry()` re-renders Server Components, and its state clears on client navigation. Don't wrap an `error.tsx` export in it. **⚠ 16.x change:** stable since 16.3 (`unstable_catchError` was 16.2).
  - **Src:** https://nextjs.org/docs/app/api-reference/functions/catchError
  - **Says:**
    - The fallback receives `(props, { error, retry, reset }: ErrorInfo)` and must be a Client Component.
    - It is "framework-aware"; "you don't need to wrap `error.js` default exports with `catchError`".
    - Version history: `v16.3.0` stable, `v16.2.0` `unstable_catchError` introduced.
- **TEST-25**
  - **Rule:** Catch errors from event handlers and async callbacks yourself, and keep them in `useState`/`useReducer`; error boundaries only catch errors during rendering. Errors thrown inside `startTransition` do bubble to the nearest boundary.
  - **Src:** https://nextjs.org/docs/app/getting-started/error-handling
  - **Says:** "Error boundaries don't catch errors inside event handlers". "catch the error manually and store it using `useState` or `useReducer`". "unhandled errors inside `startTransition` … will bubble up to the nearest error boundary".
- **TEST-26**
  - **Rule:** Pair every `notFound()` with a `not-found.tsx`. The root `app/not-found.tsx` also serves unmatched URLs. A streamed response returns `200` (with `noindex`), and only a non-streamed one returns `404`. Route-level conventions live in [routing-and-metadata.md](routing-and-metadata.md).
  - **Src:**
    - https://nextjs.org/docs/app/api-reference/file-conventions/not-found
    - https://nextjs.org/docs/app/api-reference/functions/not-found
  - **Says:** "Next.js will return a `200` HTTP status code for streamed responses, and `404` for non-streamed responses". Version history: `v13.3.0` "Root `app/not-found` handles global unmatched URLs". `not-found` is a Server Component by default, can be `async`, and takes no props.

### D. Observability

- **TEST-27**
  - **Rule:** Put `instrumentation.ts` in the project root (or in `src/`), never inside `app/`.
    - Export `register()`. It runs once per server instance and finishes before requests are served.
    - Do side-effect imports inside `register`.
    - Import Node-only SDKs only when `process.env.NEXT_RUNTIME === 'nodejs'`.
  - **Src:**
    - https://nextjs.org/docs/app/guides/instrumentation
    - https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation
  - **Says:** `register` is "called **once** when a new Next.js server instance is initiated, and must complete before the server is ready". The file must sit in the project root, "not inside the `app` or `pages` directory". The page recommends importing inside `register`, and `register` runs "in all environments", so code is gated on `NEXT_RUNTIME`.
- **TEST-28**
  - **Rule:** Export `onRequestError`, typed `Instrumentation.onRequestError` from `next`, to report server errors with route context.
    - `await` all async work inside it.
    - Narrow `err: unknown` before reading `message`/`digest`.
    - Report `request.path`, `request.method`, `context.routePath` and `context.routeType`, and not the raw headers.
  - **Src:** https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation
  - **Says:** "track **server** errors to any custom observability provider". "If you're running any async tasks in `onRequestError`, make sure they're awaited". The error "might not be the original error instance … use `digest`". The context carries `routeType: 'render' | 'route' | 'action' | 'proxy'`. Version history: `onRequestError` added in `v15.0.0`.
  - **Verified snippet:** `import { type Instrumentation } from 'next'`, `export const onRequestError: Instrumentation.onRequestError = async (err, request, context) => { … }`.
- **TEST-29**
  - **Rule:** Use `@vercel/otel` for OpenTelemetry: call `registerOTel({ serviceName })` inside `register()`.
    - Configure `NodeSDK` by hand only in a Node-only module (`instrumentation.node.ts`). Edge support needs `@vercel/otel`.
    - Set `NEXT_OTEL_VERBOSE=1` for more spans.
    - Set `NEXT_OTEL_FETCH_DISABLED=1` when a custom fetch instrumentation replaces the built-in fetch span.
  - **Src:**
    - https://nextjs.org/docs/app/guides/open-telemetry
    - https://vercel.com/docs/tracing/instrumentation
  - **Says:**
    - Next.js "supports OpenTelemetry instrumentation out of the box", and `@vercel/otel` is the quick start.
    - "`NodeSDK` is not compatible with edge runtime". "If edge runtime support is necessary, you will have to use `@vercel/otel`".
    - Both env flags are documented.
    - Vercel shows `registerOTel({ serviceName: 'your-project-name' })`.
- **TEST-30**
  - **Rule:** Add custom spans with `@opentelemetry/api` (`trace.getTracer(...).startActiveSpan(...)`) and always end the span in `finally`.
  - **Src:**
    - https://nextjs.org/docs/app/guides/open-telemetry
    - https://vercel.com/docs/tracing/instrumentation
  - **Says:** Both pages show a `try { … } finally { span.end() }` example. Vercel: "Custom spans from functions using the Edge runtime are not supported."
- **TEST-31**
  - **Rule:** Put client-side error tracking and analytics that must start before hydration in `instrumentation-client.ts` (root or `src/`).
    - Keep it synchronous and light: development warns when it takes over 16 ms, and async work isn't awaited.
    - Wrap tracking code in `try/catch`.
    - Export `onRouterTransitionStart(url, navigationType)` for navigation breadcrumbs.
  - **Src:** https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation-client
  - **Says:** It runs after the HTML loads and before hydration. "Next.js monitors initialization time … will log warnings if it takes longer than 16ms". "Only synchronous, top-level code is guaranteed to complete before hydration". It recommends try-catch blocks. Version history: `v15.3` introduced; `v16.3.0` adds an experimental transition start event.
- **TEST-32**
  - **Rule:** Report Web Vitals with `useReportWebVitals` from `next/web-vitals`.
    - Call it in a small `'use client'` `WebVitals` component that the root layout renders.
    - Pass a module-level callback, so its reference never changes and nothing is reported twice.
    - Send with `navigator.sendBeacon`, falling back to `fetch(…, { keepalive: true })`.

    On Vercel, `<SpeedInsights />` from `@vercel/speed-insights/next` in the root layout is the managed option; detail lives in [performance-and-vercel.md](performance-and-vercel.md).
  - **Src:**
    - https://nextjs.org/docs/app/api-reference/functions/use-report-web-vitals
    - https://nextjs.org/docs/app/guides/analytics
    - https://vercel.com/docs/speed-insights/quickstart
  - **Says:** "ensure that the callback function reference does not change". "create a separate component that the root layout imports". The `sendBeacon`/`fetch keepalive` example comes from the docs. Vercel quickstart: `import { SpeedInsights } from '@vercel/speed-insights/next'` inside `<body>`.
  - **Verified snippet:** `type ReportWebVitalsCallback = Parameters<typeof useReportWebVitals>[0]`.
- **TEST-33**
  - **Rule:** Treat the `logging` option in `next.config.ts` as development-terminal configuration only. Its keys are `fetches`, `serverFunctions`, `incomingRequests` and `browserToTerminal`; none of them produces production logs.
  - **Src:**
    - https://nextjs.org/docs/app/api-reference/config/next-config-js/logging
    - https://vercel.com/kb/guide/add-structured-application-logs-to-vercel-functions
  - **Says:** It configures logging "when running Next.js in development mode". `incomingRequests` "doesn't affect production builds". The KB says: "`logging` config is dev-only". Version history: `v16.2.0` `browserToTerminal` added.
- **TEST-34**
  - **Rule:** Write production logs as one JSON object per `console.*` call, and use `console.error` for errors (stderr is the Error level in Vercel Runtime Logs). Stay within 256 lines, 256 KB per line and 1 MB per request.
  - **Src:**
    - https://vercel.com/docs/logs/runtime
    - https://vercel.com/kb/guide/add-structured-application-logs-to-vercel-functions
  - **Says:**
    - The level table: `stdout` → info, `stderr` (`console.error`) → error, and `console.warn` → warning (streaming) / error (non-streaming).
    - The limits are those three.
    - The KB says JSON fields "become filterable", and the dashboard level "reads the level inferred from the console method".
- **TEST-35**
  - **Rule:** Strip secrets and PII before anything reaches `console.*` or an error reporter. Return an error id (or the `digest`) to the client instead of raw messages or stacks.
  - **Src:** https://vercel.com/kb/guide/add-structured-application-logs-to-vercel-functions
  - **Says:** Under "Follow secure logging practices": "Remove passwords, tokens, and Personally Identifiable Information (PII) before any field reaches `console.*`", and "Use error IDs for correlation".

### E. Debugging and gates

- **TEST-36**
  - **Rule:** Debug with the documented flags:
    - `next dev --inspect` (16.1+) and `next start --inspect` (16.2+);
    - `NODE_OPTIONS=--inspect-brk next dev` to break on start;
    - `next build --debug-prerender` for prerender errors (never deploy that build);
    - `next build --debug` for verbose build output;
    - React DevTools to toggle error boundaries while testing error states.
  - **Src:**
    - https://nextjs.org/docs/app/guides/debugging
    - https://nextjs.org/docs/app/api-reference/cli/next
    - https://nextjs.org/blog/next-16-1
    - https://nextjs.org/blog/next-16-2
    - https://nextjs.org/docs/app/api-reference/file-conventions/error
  - **Says:**
    - Debugging guide: `npm run dev -- --inspect`, and "To use `--inspect-brk` or `--inspect-wait`, you have to specify `NODE_OPTIONS`".
    - CLI: `--debug-prerender` is "for debugging in development only. Do not deploy"; `-d/--debug` gives verbose output.
    - Blogs: 16.1 adds `next dev --inspect`, 16.2 adds `next start --inspect`.
    - error.js: "React DevTools allow you to toggle error boundaries".
- **TEST-37**
  - **Rule:** Gate a Next.js repo with, in order:
    1. `eslint .` (the ESLint CLI with `eslint-config-next` flat config);
    2. `next typegen && tsc --noEmit`;
    3. `vitest run --coverage` (or `jest --coverage`);
    4. `next build`;
    5. `playwright test`.

    Never use `next lint`: it was removed in Next.js 16, and `next build` no longer lints. Never set `typescript.ignoreBuildErrors: true`. tsconfig detail lives in [typescript.md](typescript.md).
  - **Src:**
    - https://nextjs.org/docs/app/api-reference/config/eslint
    - https://nextjs.org/docs/app/guides/upgrading/version-16
    - https://nextjs.org/docs/app/api-reference/cli/next
    - https://nextjs.org/docs/app/api-reference/config/next-config-js/typescript
  - **Says:**
    - "Starting with Next.js 16, `next lint` is removed". "Use Biome or ESLint directly. `next build` no longer runs linting."
    - `next typegen && tsc --noEmit`.
    - "Next.js fails your **production build** (`next build`) when TypeScript errors are present". `ignoreBuildErrors` "completely skips the TypeScript type checking step".
  - **⚠ 16.x change:** `next lint` removal.
- **TEST-38**
  - **Rule:** Never run two `next build` or two `next dev` processes in the same project directory at once: a lockfile blocks it. `next dev` writes to `.next/dev`, so one dev server and one build can run side by side.
  - **Src:** https://nextjs.org/docs/app/guides/upgrading/version-16
  - **Says:** Under "Concurrent `dev` and `build`": the two use separate output directories, and "a lockfile mechanism prevents multiple `next dev` or `next build` instances on the same project". **⚠ 16.x change.**

### Version notes (`## Version notes`, headed "Next.js 16")

Each item gets its link. Every item was confirmed on the cited page:

- **16.0**
  - `next lint` and the `eslint` config option were removed; `next build` no longer lints. Codemod: `npx @next/codemod@canary next-lint-to-eslint-cli .`. Sources: `…/guides/upgrading/version-16`, `…/config/eslint`, `…/blog/next-16`.
  - `@next/eslint-plugin-next` defaults to flat config (upgrade guide).
  - Turbopack is the default for `next dev`/`next build` (`--webpack` opts out). Minimums are Node.js 20.9+ and TypeScript 5.1+ (upgrade guide).
  - `next dev` writes to `.next/dev`, and a lockfile is added (upgrade guide).
  - Dev request logs gain Compile/Render timing, and build steps print their durations (`blog/next-16`, "Logging Improvements").
  - Next.js DevTools MCP (`next-devtools-mcp`) gives coding agents dev-server errors and logs (`guides/mcp`, `blog/next-16`).
- **16.1:** `next dev --inspect` (`blog/next-16-1`).
- **16.2** (`blog/next-16-2`):
  - `next start --inspect`;
  - Server Function logging in dev (`logging.serverFunctions`);
  - `logging.browserToTerminal` (moved from `experimental.browserDebugInfoInTerminal`; logging reference version history);
  - a redesigned default error page;
  - `Error.cause` chains in the dev overlay;
  - `unstable_retry` and `unstable_catchError` added.
- **16.3:**
  - the `retry` prop and `catchError` became stable (error.js and catchError version histories, `blog/next-16-3`);
  - the `@next/playwright` `instant()` helper (`blog/next-16-3`, `guides/instant-navigation`);
  - an experimental router transition start event in `instrumentation-client` (its version history);
  - `next build` type-checks with the project-local `tsc` CLI by default, which enables TypeScript 7 (`config/next-config-js/useTypeScriptCli`, `blog/next-16-3`).
- **Unchanged in 16:** `register`/`onRequestError` (`onRequestError` since v15.0.0) and `instrumentation-client` (since v15.3). Their version-history tables list no 16.x change apart from the 16.3 experimental event. The upgrade guide lists nothing for testing setup.

### Not confirmed by the docs (`## Not confirmed by the docs`; nothing here becomes a rule)

| Item | URLs checked |
| --- | --- |
| Calling a `'use server'` action or a Route Handler export directly from a unit test. This is why TEST-9 and TEST-10 are tagged convention. | the four testing guides, `getting-started/mutating-data`, `file-conventions/route` |
| Mocking `next/navigation`, `next/headers` or `server-only` inside Vitest or Jest | `guides/testing/vitest`, `guides/testing/jest`, the full docs text (`llms-full.txt`) |
| The `next/experimental/testmode/playwright` fetch-mocking test mode. It isn't on nextjs.org (searched `llms-full.txt`). | `https://nextjs.org/docs/app/guides/testing/playwright` |
| Whether `unstable_retry` still works as an alias in 16.3. The version history records only the rename to `retry`. | `file-conventions/error` |
| Whether `ErrorInfo` from `next/error` is the documented prop type for an `error.tsx` default export in 16.3. The 16.2 blog used it with `unstable_retry`, but the 16.3 reference types the props inline, so the file uses the inline type. | `file-conventions/error`, `functions/catchError`, `blog/next-16-2` |
| The exact `message` of the error thrown by `redirect()` / `notFound()`. Tests must not assert on it. | `functions/redirect`, `functions/not-found` |
| `@testing-library/jest-dom` matchers under Vitest (the Next.js Vitest guide doesn't set them up) | `guides/testing/vitest` |
| Any coverage percentage. No Next.js page sets one, so the 80% floor is Jonathan's convention. | the four testing guides |
| That `webServer` should run a production build. Next.js says `webServer` starts "the development server" and separately recommends testing production code; TEST-12 joins the two and labels that. | `guides/testing/playwright`, `playwright.dev/docs/test-webserver` |
| Whether `onRequestError`'s `routeType: 'proxy'` replaced a `'middleware'` value in 16. No version-history entry says so. | `file-conventions/instrumentation`, `guides/upgrading/version-16` |

Put these URLs into the topic file **without fragments**. Each one must also be in `## Sources`, or the prose-URL check fails. Add `https://nextjs.org/docs/app/getting-started/mutating-data` to Sources if it is cited here.

### Sources (exact list; the evidence file mirrors it)

**nextjs.org guides:**

- https://nextjs.org/docs/app/guides/testing
- https://nextjs.org/docs/app/guides/testing/vitest
- https://nextjs.org/docs/app/guides/testing/jest
- https://nextjs.org/docs/app/guides/testing/playwright
- https://nextjs.org/docs/app/guides/testing/cypress
- https://nextjs.org/docs/app/guides/preserving-ui-state
- https://nextjs.org/docs/app/guides/instant-navigation
- https://nextjs.org/docs/app/guides/environment-variables
- https://nextjs.org/docs/app/guides/production-checklist
- https://nextjs.org/docs/app/guides/instrumentation
- https://nextjs.org/docs/app/guides/open-telemetry
- https://nextjs.org/docs/app/guides/analytics
- https://nextjs.org/docs/app/guides/debugging
- https://nextjs.org/docs/app/guides/mcp
- https://nextjs.org/docs/app/guides/upgrading/version-16

**nextjs.org getting started:**

- https://nextjs.org/docs/app/getting-started/error-handling
- https://nextjs.org/docs/app/getting-started/mutating-data

**nextjs.org file conventions:**

- https://nextjs.org/docs/app/api-reference/file-conventions/route
- https://nextjs.org/docs/app/api-reference/file-conventions/proxy
- https://nextjs.org/docs/app/api-reference/file-conventions/error
- https://nextjs.org/docs/app/api-reference/file-conventions/not-found
- https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation
- https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation-client

**nextjs.org functions:**

- https://nextjs.org/docs/app/api-reference/functions/catchError
- https://nextjs.org/docs/app/api-reference/functions/redirect
- https://nextjs.org/docs/app/api-reference/functions/permanentRedirect
- https://nextjs.org/docs/app/api-reference/functions/not-found
- https://nextjs.org/docs/app/api-reference/functions/forbidden
- https://nextjs.org/docs/app/api-reference/functions/unstable_rethrow
- https://nextjs.org/docs/app/api-reference/functions/use-report-web-vitals

**nextjs.org config, CLI and messages:**

- https://nextjs.org/docs/app/api-reference/config/next-config-js/logging
- https://nextjs.org/docs/app/api-reference/config/next-config-js/typescript
- https://nextjs.org/docs/app/api-reference/config/next-config-js/useTypeScriptCli
- https://nextjs.org/docs/app/api-reference/config/eslint
- https://nextjs.org/docs/app/api-reference/cli/next
- https://nextjs.org/docs/messages/next-dynamic-api-wrong-context

**nextjs.org blog:**

- https://nextjs.org/blog/next-16 (published 2025-10-21)
- https://nextjs.org/blog/next-16-1 (2025-12-18)
- https://nextjs.org/blog/next-16-2 (2026-03-18)
- https://nextjs.org/blog/next-16-3 (2026-08-03)

**vercel.com:**

- https://vercel.com/docs/tracing/instrumentation
- https://vercel.com/docs/logs/runtime
- https://vercel.com/docs/speed-insights/quickstart
- https://vercel.com/kb/guide/add-structured-application-logs-to-vercel-functions

**vitest.dev:**

- https://vitest.dev/config/environment
- https://vitest.dev/config/coverage
- https://vitest.dev/guide/coverage
- https://vitest.dev/guide/

**playwright.dev:**

- https://playwright.dev/docs/test-webserver
- https://playwright.dev/docs/api-testing

Evidence fetch method:

- nextjs.org and vercel.com: `curl -sSL <url>.md` (served as `text/markdown`; frontmatter `version: 16.3.8`). The blog `.md` endpoints work too.
- vitest.dev and playwright.dev: WebFetch.
- All on 2026-10-04.

Of the 50 URLs, 44 are on nextjs.org or vercel.com, well above the contract's 3.

## 8. Topic file outline (for the coder)

```text
# <keep the stub's H1>
> As of Next.js <copy from R/nextjs.md>, verified 2026-10-04.

## Scope            what it covers; reading order; owners of adjacent topics (relative links)
## Rules            TEST-1…TEST-38, one physical line each, `N. **TEST-N** …` with N == id,
                    grouped under H3s: Test surfaces and unit tools / End-to-end tests /
                    Error handling / Observability / Debugging and gates (drop the H3s if the
                    merged rule_items cannot parse across them)
## Patterns         short typed examples (below)
## Anti-patterns    7 Don't/Do pairs (below)
## Version notes    "Next.js 16" — the list in section 7
## Review checklist ≥ 16 `- [ ]` items, each naming its TEST-n
## Not confirmed by the docs   the table in section 7
## Sources          the exact list in section 7
```

**Patterns.** Each pattern is an H3, one sentence, and one fenced block with its `ts`/`tsx`/`json` tag. All are typed, with no `any`. Every API used appears on a page cited by the named rule.

1. **`vitest.config.mts` (TEST-4, TEST-7).** The guide's config verbatim, plus:

   ```ts
   test: { environment: 'jsdom', coverage: { provider: 'v8', include: ['src/**/*.{ts,tsx}'], thresholds: { lines: 80, functions: 80, branches: 80, statements: 80 } } }
   ```

   Add the comment `// 80% floor: bmn convention (TEST-7)`. The block must hold `defineConfig` and `jsdom`.
2. **Unit test of a synchronous page or Client Component (TEST-2, TEST-4).** The guide's `__tests__/page.test.tsx` (`render`, `screen.getByRole('heading', { level: 1, name: 'Home' })`, `toBeDefined()`).
3. **Route Handler unit test (TEST-9).** `app/api/hello/route.ts` contains `export async function GET(request: Request) { const name = new URL(request.url).searchParams.get('name') ?? 'world'; return Response.json({ message: \`Hello ${name}\` }) }`. The test opens with `// @vitest-environment node`, calls `await GET(new Request('http://localhost/api/hello?name=Ada'))`, and asserts `status` 200 and the JSON body.
4. **Server Action logic as a pure function (TEST-10, TEST-18).** `src/features/posts/services/validate-post.ts` exports `type ValidationResult = { ok: true; value: { title: string } } | { ok: false; message: string }` and `validatePost(formData: FormData): ValidationResult`. Its test builds a `FormData` with a blank title and expects `{ ok: false, message: 'Title is required.' }`.
5. **`playwright.config.ts` (TEST-12, TEST-13).**
   - `const PORT = Number(process.env.E2E_PORT ?? 3100)` and `const baseURL = \`http://localhost:${PORT}\``;
   - `webServer: { command: \`npm run build && npm run start -- -p ${PORT}\`, url: baseURL, reuseExistingServer: !process.env.CI, timeout: 180_000 }`;
   - `use: { baseURL }`.

   The block must hold `defineConfig` and `webServer`. Don't use `devices` or `testDir`; neither was verified on a cited page.
6. **E2E specs (TEST-2, TEST-14, TEST-15, TEST-17).** Three tests:
   - `page.goto('/dashboard')` with `getByRole('heading', { name: 'Dashboard' })` and `toBeVisible()`;
   - `/blog/does-not-exist` → the not-found heading is visible;
   - `request.get('/api/hello?name=Ada')` with `expect(res.ok()).toBeTruthy()` and the JSON equality.
7. **`instrumentation.ts` (TEST-27, TEST-28, TEST-29, TEST-35).** `registerOTel({ serviceName: 'next-app' })` in `register()`, plus the docs' `onRequestError` with the unknown-narrowing (`err instanceof Error`; `'digest' in err`). Post only `message`, `digest`, `request.path`, `request.method`, `context.routePath` and `context.routeType`, with a comment that headers can carry cookies and tokens. Use a placeholder endpoint `https://errors.example.com/report` (code is exempt from the Sources check). The block must hold `register` and `onRequestError`.
8. **Custom span (TEST-30).** `trace.getTracer('app').startActiveSpan('loadDashboard', async (span) => { try { return await loadDashboard() } finally { span.end() } })`, with an import of `loadDashboard` from a feature service.
9. **`app/dashboard/error.tsx` (TEST-20, TEST-21).**
   - `'use client'`; `export default function ErrorPage({ error, retry }: { error: Error & { digest?: string }; retry: () => void })`;
   - `useEffect(() => { console.error(error) }, [error])`;
   - `<div role="alert"><h2>Something went wrong.</h2>{error.digest ? <p>Reference: {error.digest}</p> : null}<button type="button" onClick={() => retry()}>Try again</button></div>`.

   No `<html>`.
10. **`app/global-error.tsx` (TEST-22).** `'use client'`, `import './globals.css'`, the same props, `<html lang="en"><body><title>Something went wrong</title>…retry button…</body></html>`.
11. **`unstable_rethrow` when a catch is unavoidable (TEST-23).** The docs' `notFound`/`unstable_rethrow` example, typed `catch (err: unknown)`.
12. **`catchError` boundary (TEST-24).** The docs' `custom-error-boundary.tsx` (`catchError(ErrorFallback)` with `(props: { title: string }, { error, retry }: ErrorInfo)`).
13. **`instrumentation-client.ts` (TEST-31).** A `try { performance.mark('app-init'); window.addEventListener('error', (event: ErrorEvent) => { navigator.sendBeacon('/api/client-errors', JSON.stringify({ message: event.message })) }) } catch (e: unknown) { console.error(e) }` block, plus `export function onRouterTransitionStart(url: string, navigationType: 'push' | 'replace' | 'traverse') { performance.mark(\`nav-start-${url}\`) }`.
14. **`WebVitals` component (TEST-32).** `'use client'`; `type ReportWebVitalsCallback = Parameters<typeof useReportWebVitals>[0]`; a module-level `reportWebVitals` using `sendBeacon` with a `fetch` keepalive fallback; `useReportWebVitals(reportWebVitals); return null`.
15. **Structured error logger (TEST-34, TEST-35).** `src/lib/log.ts` with `type LogFields = Record<string, string | number | boolean | null>`. `logError(message: string, err: unknown, fields: LogFields = {}): string` makes `crypto.randomUUID()`, writes one `console.error(JSON.stringify({ level: 'error', message, errorId, errorType: err instanceof Error ? err.name : typeof err, ...fields }))`, and returns `errorId`.
16. **Gate scripts (TEST-6, TEST-37).** A `json` block with `"lint": "eslint ."`, `"typecheck": "next typegen && tsc --noEmit"`, `"test": "vitest"`, `"test:ci": "vitest run --coverage"`, `"build": "next build"`, `"start": "next start"` and `"e2e": "playwright test"`.

If the line budget is tight, drop pattern 2 first (it duplicates the guide).

**Anti-patterns.** Default format (follow the merged generic test if it parses a different one):

````text
### Don't: <short title> (TEST-n)

```tsx
…bad…
```

**Do:** <one line>

```tsx
…good…
```
````

1. **Unit-rendering an async Server Component (TEST-2).** Don't: `render(await Page())` in Vitest. Do: Playwright `page.goto` + `getByRole`.
2. **`redirect()` inside `try` (TEST-23).** Don't: `try { await savePost(formData); redirect('/posts') } catch (err: unknown) { console.error(err) }`. Do: `await savePost(formData)` and then `redirect('/posts')` outside any `try`.
3. **Throwing for a validation failure (TEST-18).** Don't: `if (!title) throw new Error('Title is required')` in a Server Action. Do: `return { message: 'Title is required.' }`, linking [data-fetching-and-mutations.md](data-fetching-and-mutations.md).
4. **A Server-style error boundary (TEST-20, TEST-21).** Don't: an `error.tsx` without `'use client'`, typed `{ error: Error; reset: () => void }`, rendering `error.message`. Do: the pattern 9 shape (it may be referenced by name, but the Do block must still be present, shortened).
5. **`global-error.tsx` returning a `<div>` (TEST-22).** Don't: `return <div>…</div>`. Do: `<html><body>…</body></html>`.
6. **E2E against the dev server (TEST-12).** Don't: `webServer: { command: 'npm run dev' }`. Do: build + start on its own port.
7. **`next lint` in scripts (TEST-37).** Don't: a `json` block with `"lint": "next lint"` (removed in 16). Do: `"lint": "eslint ."`.

**Review checklist.** At least 16 items, each naming its rule id or ids:

- TEST-1/2: every AC is mapped to a surface, and async Server Components have Playwright coverage;
- TEST-4/5: the runner config matches the guide;
- TEST-6/7: the gate runs once, with coverage ≥80% and `include` set;
- TEST-9/10: handler and action logic is unit-tested, and request-scope paths are E2E;
- TEST-12/13: production build on its own port;
- TEST-14: visibility-aware locators;
- TEST-17: error and not-found E2E tests;
- TEST-18: expected errors are returned;
- TEST-20: `'use client'` plus typed props with `digest` plus `retry`;
- TEST-21: no server `error.message` shown;
- TEST-22: global-error has `<html>`/`<body>` and no `metadata`;
- TEST-23: no interrupt inside `try`;
- TEST-25: event-handler errors go to state;
- TEST-27/28: instrumentation location, runtime gating, awaited `onRequestError`, narrowed `unknown`;
- TEST-31/32: client instrumentation is sync and light, with a stable vitals callback;
- TEST-34/35: JSON logs, `console.error` for errors, no PII/headers;
- TEST-37/38: gates are `eslint .` / typegen + tsc / `next build` / playwright, with no `next lint` and no `ignoreBuildErrors`.

## 9. Assumptions

1. **No commit.** The orchestrator's run note ("Do NOT commit or push; write only your plan file") overrides the brief's "Commit on feat/…". The orchestrator commits all plans together.
2. **The version is 16.3.8** (npm latest plus the docs' `@doc-version`, both read 2026-10-04). The coder copies the as-of line from the merged `R/nextjs.md` and never retypes it.
3. **Helper signatures are inferred** from the skeleton story (`section(text, heading)` with bare heading text; `as_of_version` returning a dotted string). The coder adapts calls to the merged helpers and logs any difference in validation.md.
4. **Anti-pattern markup.** The default is `### Don't:` + `**Do:**`. If the merged generic test parses another shape, both the topic file and `DONT_MARKER` follow it.
5. **The error prop is `retry`**, per 16.3.8's `error.js` reference. `reset` is documented as secondary, and `unstable_retry` is history only (Version notes).
6. **The lint gate is `eslint .`**, because `next lint` was removed in 16. Biome is mentioned only as the upgrade guide's alternative and is not used as a rule.
7. **Route Handler and Server Action unit testing is a convention**, because no Next.js page documents it (see Not confirmed). The docs facts it rests on are linked.
8. **The E2E port variable `E2E_PORT`** (default 3100) is a convention, chosen so parallel worktrees don't collide on :3000.
9. **No URL fragments** anywhere, so prose URLs equal the Sources entries exactly.
10. **A possible shared-file defect, for REVIEW①.** The `R/stack-routing.md` "Test surfaces" table names Python tooling (`pytest-playwright`, `httpx`) and "or the repo's runner". This file maps the TypeScript equivalents (Vitest/Jest, `@playwright/test`, the `request` fixture) and links the table without editing it. The coder records this in validation.md.
11. **Snippets are not compiled**, because the repo has no Next.js project. REVIEW① spot-checks them against the linked pages.
12. **No UI** (stack.md `ui: false`), so no `design.md` input applies.
