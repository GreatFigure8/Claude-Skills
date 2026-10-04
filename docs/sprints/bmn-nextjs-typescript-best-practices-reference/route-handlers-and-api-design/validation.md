# Validation — route-handlers-and-api-design

Branch `wip/nextjs-typescript-best-practices-reference/route-handlers-and-api-design`, cut from
`origin/feat/nextjs-typescript-best-practices-reference` (skeleton merged). Date: 2026-10-04.
Owns `references/nextjs/route-handlers-and-apis.md` (prefix `API`) and
`assets/tests/test_nextjs_topic_route_handlers_and_apis.py`.

## TDD record

| Step | Command | Result |
| --- | --- | --- |
| RED | `pytest test_nextjs_topic_route_handlers_and_apis.py` against the stub | 22 failed, 0 passed. Failures were `LookupError: no heading 'Patterns'` and the assertions that the stub has no rules, terms, examples or sections. One test (`test_examples_contain_no_any`) first passed vacuously on the stub, so it now asserts that at least one `ts`/`tsx` block exists, and the run then showed 22 failed. |
| GREEN | same file after the topic file replaced the stub | 22 passed |
| Generic contract | `pytest test_nextjs_reference.py -rs` | 129 passed, 56 skipped. The 56 skips are 7 generic tests x the 8 remaining stubs. No skip names `route-handlers-and-apis.md`, so every generic check runs on it and passes. |

## Gates

- Full suite: `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`
  gives **696 passed, 56 skipped** (76 s). The skeleton baseline was 667 passed, 63 skipped:
  22 new topic tests plus the 7 generic tests that no longer skip for this file.
- Lint: `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` gives `All checks passed!`.
- Types: none configured (stack.md). As a one-off outside the repo, the eight Pattern blocks were laid out as a throwaway Next.js project in the scratchpad (`next@16.3.8`, `zod@4.6.5`, `@vercel/firewall`, `typescript@5.9.3`, `next typegen`, stub `@/lib/*` modules) and `tsc --noEmit --strict` exited 0. A deliberate type error in the same project was reported, so the check was live. The 16 anti-pattern Don't/Do blocks also compile with a declaration prelude. Nothing from the scratch project is committed.
- File length: 718 lines (cap 800).

## Acceptance criteria

| AC | Result |
| --- | --- |
| 1 Contract | Pass. All generic checks run on the file with no skip. Only `API-` ids appear (`test_topic_uses_only_api_rule_ids`). |
| 2 Not a stub, deep | Pass. `is_stub` is false and there are 39 `API-` rules (floor 18). |
| 3 Required concepts | Pass. `missing_terms(TEXT, TERMS) == []` for all 24 terms. Every term is confirmed by a cited page, so none is parked under Not confirmed. |
| 4 Examples | Pass. The validated POST (P2), the `RouteContext` handler (P4), the webhook on `request.text()` (P5) and the CORS preflight (P6) are `ts` blocks with no `any`. |
| 5 One error shape | Pass. `ApiErrorBody` is declared once, under Patterns, tagged `(convention)`. The POST example and every error-returning Patterns handler use it. |
| 6 Auth per mutating handler | Pass. P2, P4 (DELETE) and P7 call `getSession()`. P5 (webhook) verifies a signature on `request.text()` instead. |
| 7 Route Handler versus Server Action | Pass. The docs frame it, so it is a rule (API-5), and API-6 forbids a Server Component fetching its own Route Handler. Both link the Backend for Frontend page. |
| 8 Version notes | Pass. Seven bullets for Next.js 16, each with its link. Includes the not-new-in-16 note. |
| 9 Reviewer-ready | Pass. 17 checklist items, each naming existing `API-n` ids. 8 anti-patterns, each a Don't block and a Do block. |
| 10 Grounding evidence | Pass. See the one-off check below. |
| 11 Scope and gates | Pass. `git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists the topic file, the topic test and files under this story folder only. |

## AC10 one-off check

The plan's command, run from the worktree root:

```text
equal: True | only in Sources: set() | only in evidence: set() | counts: 48 48
```

Every one of the 48 Sources URLs is also used in prose. A second one-off compared each rule's
links with the evidence table's "Backs" column. Two rows were corrected in
`evidence/sources-verified.md`, in the same commit as the topic file: `revalidateTag` now backs
API-24 as well as API-27, and `proxy` no longer backs API-16, which cites Backend for Frontend
and Authentication instead.

## Live re-verification

The planner's rule sheet was re-checked against the pages themselves on 2026-10-04: route.js,
Route Handlers, Backend for Frontend, after, revalidateTag, updateTag, route segment config,
runtime, edge-runtime-deprecated, maxDuration, forbidden, redirect, cookies, NextRequest,
NextResponse, caching without Cache Components, the version 16 upgrade guide, proxy,
authentication, data security, Server Actions, mutating data, the Next.js 16 and 16.3 posts, and
the Vercel pages for Functions API, `@vercel/functions`, limits, duration, Edge, webhooks and its
API, request headers, the CDN cache, WAF rate limiting and its SDK, and the raw-body guide. MDN,
Zod and TypeScript 4.9 were spot-checked for the facts they own (`Request.json()` SyntaxError,
status definitions, `Vary: Origin`, credentialed wildcard, preflight 200 or 204, `z.flattenError`
shape, `z.uuid`, `z.int`, `z.coerce`, `.pipe`, `satisfies`). Every claim held. Differences from the
sheet, all toward saying less than the pages confirm:

- API-3 and API-5: dropped "mobile" (the pages say "any client").
- API-18: scoped to `forbidden()`, the only function whose page was fetched. `unauthorized()` is
  not claimed.
- API-19: dropped the example endpoint list (sign-in, exports, AI calls), which no fetched page states.
- API-27: dropped `revalidatePath`, whose page is not among the sources.
- API-34: dropped "instead of un-awaited promises", which no page states.
- API-35: the segment-config table marks `preferredRegion` deprecated but Vercel's Functions API
  page still lists it, so the rule says "don't add it" and the tension is listed under Not
  confirmed. The sheet said "remove it".
- API-36: dropped the 1800 s beta maximum.
- Not confirmed: added the `preferredRegion` item. The sheet's WebSocket item now cites the
  `@vercel/functions` page's `experimental_upgradeWebSocket`.

## Assumptions

1. **Helper adaptations (no assertion weakened).** `section()` takes the bare title
   (`"Patterns"`), not `"## Patterns"`. `anti_patterns()` reads `### Don't …` H3 headings, so the
   Anti-patterns are written as H3s, each with a `**Do**` marker and two fenced blocks. The plan's
   `- **Don't**` bullets would not satisfy the skeleton's floor. The topic test splits
   `anti_patterns(TEXT)` and checks a `ts`/`tsx` fence before and after `**Do**`.
2. **Pattern headings are H3**, not H4 as the plan wrote, so no heading level is skipped under the
   H2 `## Patterns`.
3. **Own-prefix check.** `test_topic_uses_only_api_rule_ids` builds its foreign-prefix regex from the
   helpers' `TOPICS` table minus `API`, as the plan specified.
4. **Snippet hardening beyond the sheet.** P5 wraps `JSON.parse(rawBody)` in `try`/`catch` and
   answers `400 invalid_json`, so a signed but non-JSON body is not a `500` (API-9). P7 rejects a
   missing `APP_ORIGIN` as well as a mismatched `Origin`.
5. **Envelope inline.** Examples build `ApiErrorBody` inline with `satisfies` rather than through a
   helper, so every error site literally references the type (plan assumption 2).
6. **Status choices.** 400 (not 422) for schema failures, preflight `200` (not `204`) following MDN's
   browser note, and `401` for a bad webhook signature following the Next.js example. Vercel's own
   sample answers `403`, which the P5 prose says.
7. **Deferred to the reviewer.** The test file is offline and stdlib-only apart from the skeleton's
   helpers, and it never reads the run folder. Spot-checking each rule against its cited page is
   REVIEW①'s job.

## Defects found in shared files

None. The skeleton's helpers and generic tests matched the plan, apart from the anti-pattern shape
in assumption 1, which is a plan-side adaptation and not a skeleton defect.

## Migrations, env vars, deploy

None. No migration, no config, no env var in this repo (names in snippets such as
`VERCEL_WEBHOOK_SECRET` and `APP_ORIGIN` are illustrative). `deploy_pending: []`.

## TEST1 content

Run 2026-10-04 on a detached worktree at `origin/dev` `59279a3` (branch `wip/nextjs-typescript-best-practices-reference/tests-content-1`). This repo ships Markdown, so the black-box surface is the content: live sources, and the TypeScript snippets compiled in a real Next.js 16.3.8 project. File under test: `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/route-handlers-and-apis.md`.

### 1. Live sources

Command (per URL, 8 in parallel): `curl -sL -A <desktop browser UA> --max-time 20 --max-redirs 10 -o /dev/null -w "%{http_code}|%{url_effective}|%{num_redirects}" <url>`. A URL passes only when the final status is 2xx and the final URL is the same page (host without `www.`, path without trailing slash). Scope: every URL in the `## Sources` section.

Result: **48 URLs, 48 pass, 0 fail**. (Across all ten files: 283 unique URLs, 283 pass, 0 fail; every one returned HTTP 200 with no redirect.)

| URL | HTTP | Redirects | Result |
| --- | --- | --- | --- |
| https://developer.mozilla.org/en-US/docs/Glossary/Idempotent | 200 | 0 | pass |
| https://developer.mozilla.org/en-US/docs/Web/API/Request/json | 200 | 0 | pass |
| https://developer.mozilla.org/en-US/docs/Web/API/Response/json_static | 200 | 0 | pass |
| https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS | 200 | 0 | pass |
| https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Methods/OPTIONS | 200 | 0 | pass |
| https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status | 200 | 0 | pass |
| https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status/201 | 200 | 0 | pass |
| https://nextjs.org/blog/next-16 | 200 | 0 | pass |
| https://nextjs.org/blog/next-16-3 | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/headers | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/proxy | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/route | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/maxDuration | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/runtime | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/after | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/cookies | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/forbidden | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/next-request | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/next-response | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/redirect | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/revalidateTag | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/functions/updateTag | 200 | 0 | pass |
| https://nextjs.org/docs/app/getting-started/mutating-data | 200 | 0 | pass |
| https://nextjs.org/docs/app/getting-started/route-handlers | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/authentication | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/backend-for-frontend | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/caching-without-cache-components | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/data-security | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/server-actions | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/upgrading/version-16 | 200 | 0 | pass |
| https://nextjs.org/docs/messages/edge-runtime-deprecated | 200 | 0 | pass |
| https://vercel.com/docs/caching/cdn-cache | 200 | 0 | pass |
| https://vercel.com/docs/functions/configuring-functions/duration | 200 | 0 | pass |
| https://vercel.com/docs/functions/functions-api-reference | 200 | 0 | pass |
| https://vercel.com/docs/functions/functions-api-reference/vercel-functions-package | 200 | 0 | pass |
| https://vercel.com/docs/functions/limitations | 200 | 0 | pass |
| https://vercel.com/docs/functions/runtimes/edge | 200 | 0 | pass |
| https://vercel.com/docs/headers/request-headers | 200 | 0 | pass |
| https://vercel.com/docs/vercel-firewall/vercel-waf/rate-limiting | 200 | 0 | pass |
| https://vercel.com/docs/vercel-firewall/vercel-waf/rate-limiting-sdk | 200 | 0 | pass |
| https://vercel.com/docs/webhooks | 200 | 0 | pass |
| https://vercel.com/docs/webhooks/webhooks-api | 200 | 0 | pass |
| https://vercel.com/kb/guide/how-do-i-get-the-raw-body-of-a-serverless-function | 200 | 0 | pass |
| https://www.typescriptlang.org/docs/handbook/release-notes/typescript-4-9.html | 200 | 0 | pass |
| https://zod.dev/api | 200 | 0 | pass |
| https://zod.dev/basics | 200 | 0 | pass |
| https://zod.dev/error-formatting | 200 | 0 | pass |

### 2. Snippet type-check

Method (same for every story; the scratch project lives outside the repo and is not committed):

- Scratch dir `/private/tmp/claude-501/-Users-jonathanstevenson-Source-claude-skills/b71aefe4-ae21-4000-aa3e-8b70fbcfbe94/scratchpad/tscheck-test1/w1/app`, `npm install --save-exact next@16.3.8 react react-dom typescript@7.0.2 @types/react @types/react-dom @types/node zod server-only client-only vitest @playwright/test @testing-library/react vite-tsconfig-paths @vitejs/plugin-react shiki jose ai @vercel/otel @vercel/firewall @opentelemetry/api` (resolved: next 16.3.8, react and react-dom 19.3.0, typescript 7.0.2, @types/react and @types/react-dom 19.3.0, @types/node 26.6.4, zod 4.6.5, server-only 0.0.1, client-only 0.0.1, vitest 5.0.3, @playwright/test 1.63.0, @testing-library/react 16.3.3, vite-tsconfig-paths 6.1.1, @vitejs/plugin-react 6.1.1, shiki 4.5.0, jose 6.2.12, ai 7.0.127, @vercel/otel 2.1.3, @vercel/firewall 1.2.5, @opentelemetry/api 1.9.1; all from npm). typescript 6.0.3 and 5.9.3 were installed beside it for the cross-check and the parse pass.
- Every ```` ```ts ```` and ```` ```tsx ```` fence of the ten files was extracted (218 fences: 160 Do/Pattern/rule, 58 inside the Don't half of an Anti-patterns entry). Each doc becomes one virtual Next.js project under `app/proj/<doc>/`: a fence whose first line is a `// path/to/file.ts` comment is written at that path (first occurrence only, Don't halves never), so `@/` and relative imports between fences resolve to the real fence; every other fence is its own module under `_loose/`. `next typegen` runs per project so the global `PageProps`, `LayoutProps` and `RouteContext` types exist; dummy `page.tsx`, `layout.tsx`, `route.ts` and `@slot` files are created for the route literals the fences use.
- Compiler config: the doc's own P1 `tsconfig.json` (`strict: true`, `noUncheckedIndexedAccess`, `lib: ES2020`, `moduleResolution: bundler`, ...) with `paths` `@/*` -> `./*` and `./src/*`; command `node node_modules/typescript/bin/tsc --noEmit --pretty false -p tsconfig.json` (TypeScript 7.0.2) in each project. Cross-checks: TypeScript 6.0.3 with the same config, and TypeScript 7.0.2 with the `create-next-app` default compilerOptions (`strict`, `target ES2017`, `lib dom/dom.iterable/esnext`).
- Prelude (declared, never silent): a fence that is a fragment gets only (a) `export {}` when it has no import or export, (b) a wrapper `async function __fragment() {` ... `}` when it is a bare statement list (TS1108 `return` outside a function), (c) an `import` of a well-known Next.js, React or Zod name (`z`, `redirect`, `notFound`, `revalidateTag`, `updateTag`, `cookies`, `Suspense`, ...) that the fence uses but does not import, (d) `declare var name: any` for any other free name the fence uses but does not define, (e) an any-typed stub module for a local `@/` or `./` import that no fence in the doc defines, (f) a typed export on the doc's own module when the doc says the module holds more than it shows. The records below say which fence got which.
- A fence with a parse error cannot be typechecked, so it is parked outside the project and reported on its own.

Result for `route-handlers-and-apis.md`: **24 fences = 16 Do/Pattern/rule + 8 Don't half. Do/Pattern/rule: 16 pass, 0 fail.**

Cross-checks for this file: TypeScript 6.0.3 with the same config reports 1 Do-fence error(s) (#18); TypeScript 7.0.2 with the `create-next-app` default compilerOptions reports 0.

#### Failures (Do/Pattern/rule fences)

None.

#### Pass with a declared prelude that deserves a look

- #18 (line 526) Don't verify a webhook over re-serialized JSON: without the prelude it fails with `TS2339` Property 'createHmac' does not exist on type 'Crypto'; `TS2339` Property 'timingSafeEqual' does not exist on type 'Crypto'. `import crypto from 'node:crypto'` added (the file's fence at line 253 has `import crypto from 'crypto'`; this fence omits it)
  - Why it is not counted as a failure: the missing import is defined in the same file (line 253). Why it is still worth fixing: `crypto` is also a global (Web Crypto, type `Crypto`), so the omission is not a "name not found" error, it silently resolves to an object with no `createHmac` or `timingSafeEqual`; a reader who copies this fence alone gets TS2339 and, at runtime, a TypeError.

#### Prelude record

- 8 of 16 Do/Pattern/rule fences begin with a `// path` comment and sit at that path in the virtual project; the other 8 are standalone modules under `_loose/`.
- `export {}` was appended to 3 fences that had no import or export (fences #16, #18, #20); that only makes the fragment a module so names do not collide.
- Other preludes (Do/Pattern/rule fences only):

| Fence | Prelude |
| --- | --- |
| #02 (line 101) Validated POST (create) | any-typed stub module: `lib/auth/session.ts`, `lib/projects.ts` |
| #03 (line 161) Paginated GET (list) | any-typed stub module: `lib/auth/session.ts`, `lib/projects.ts` |
| #04 (line 204) Dynamic segment with RouteContext | any-typed stub module: `lib/auth/session.ts`, `lib/projects.ts` |
| #05 (line 251) Webhook with signature verification on the raw body | any-typed stub module: `lib/webhooks/vercel.ts` |
| #06 (line 315) CORS with preflight | any-typed stub module: `lib/status.ts` |
| #07 (line 347) Rate-limited, origin-checked POST with after() and maxDuration | any-typed stub module: `lib/auth/session.ts`, `lib/exports.ts` |
| #08 (line 391) Cache Components: a cached public GET | any-typed stub module: `lib/catalog.ts` |
| #10 (line 425) Don't fetch your own Route Handler from a Server Component | any-typed stub module: `lib/projects.ts` |
| #14 (line 469) Don't skip the session check because proxy.ts already runs | free names declared `any`: `getSession`, `ApiErrorBody`, `findUserById` |
| #16 (line 498) Don't send error.message to the client | free names declared `any`: `ProjectInput`, `createProject`, `ApiErrorBody` |
| #24 (line 606) Don't call redirect() inside try/catch | import added: `redirect` from `next/navigation`; free names declared `any`: `signOut`, `ApiErrorBody` |

- Typed prelude on `route-handlers-and-apis#18`: `import crypto from 'node:crypto'` added (the file's fence at line 253 has `import crypto from 'crypto'`; this fence omits it).

#### Don't half (expected to be wrong; recorded, not failed)

| Fence | Outcome |
| --- | --- |
| #09 (line 414) Don't fetch your own Route Handler from a Server Component | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #11 (line 439) Don't read params synchronously | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #13 (line 460) Don't skip the session check because proxy.ts already runs | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #15 (line 486) Don't send error.message to the client | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #17 (line 516) Don't verify a webhook over re-serialized JSON | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #19 (line 543) Don't combine a wildcard origin with credentials | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #21 (line 569) Don't use the edge runtime or updateTag in a Route Handler | compiles (the mistake is a runtime, security or caching rule, not a type error) |
| #23 (line 593) Don't call redirect() inside try/catch | compiles (the mistake is a runtime, security or caching rule, not a type error) |
