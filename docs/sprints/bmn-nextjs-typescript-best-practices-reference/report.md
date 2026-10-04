# Next.js + TypeScript best-practices reference — dev-bother-me-nope report

**Run:** `bmn-nextjs-typescript-best-practices-reference` · **Finished:** 2026-10-04 · **Outcome:** ✅ done, merged to `dev`, stopped for you
**Stack:** library (skills repo, Markdown + pytest) · skills used: none routed (`nextjs-fullstack-standards` is not installed on this machine)
**Design:** no UI in this run
**Merged to dev:** `59279a3` (MERGE①), `7acb627` (MERGE②), plus the report merge

## Stopped for Jonathan — the run is done

code → review → fix → review → report. The run did REVIEW①, one fix round (FIX①) and
REVIEW②, then stopped. Nothing REVIEW② found was fixed. Nothing was released, promoted to
`main` or deployed, and no further round was started. Anything below is a **new goal, and
only you decide whether there is one**.

**Built:** Your `references/nextjs.md` draft is now the entry point to a Next.js 16 + TypeScript standard, **as of Next.js 16.3.8, verified 2026-10-04**. It keeps your folder structure as the canonical layout and adds `src/proxy.ts` and `src/instrumentation.ts`. It also has non-negotiables, an authoring contract and an index to nine topic files in `references/nextjs/`, each 726–799 lines:
- `typescript.md` (TS-*): strict tsconfig matching create-next-app 16, typed routes, PageProps/LayoutProps/RouteContext, Zod at boundaries, env typing.
- `routing-and-metadata.md` (RT-*): App Router file conventions, parallel and intercepting routes, navigation, the Metadata API, and a safe redirect guard.
- `rendering-and-caching.md` (RC-*): Server and Client Components, Cache Components, `use cache` with cacheLife/cacheTag, revalidateTag/updateTag/refresh, streaming SSR, and persistence on Vercel.
- `data-fetching-and-mutations.md` (DF-*): the DAL/DTO pattern, Server Actions with typed state, useActionState/useOptimistic, and `after()`.
- `route-handlers-and-apis.md` (API-*): REST design, the ApiErrorBody envelope, validation, auth plus Origin checks, webhooks with constant-time HMAC, bounded pagination, and choosing a runtime.
- `sse-and-streaming.md` (SSE-*): a full reference SSE route and client hook. It covers replay then live, Last-Event-ID, heartbeats, backpressure, abort and cancel cleanup, closing before maxDuration, `supportsCancellation`, AI streaming, and when to use WebSockets.
- `proxy-auth-and-security.md` (SEC-*): `proxy.ts` (renamed from `middleware.ts` in 16), sessions, the single `@/lib/dal` contract, Server Action security, CSP and headers, env and secrets, and the 2025–26 advisories with patched versions.
- `performance-and-vercel.md` (PERF-*): image, font and script handling, bundles, Turbopack, Fluid compute, function limits, CDN caching, crons, and the AVIF advisory.
- `testing-and-observability.md` (TEST-*): Vitest/Jest, Playwright E2E, error boundaries (`retry`), `instrumentation.ts` with onRequestError, logging, and the gate commands.

bmn now reads `nextjs.md` for every TypeScript story (stack-routing, the briefs, SKILL.md, and a `routed_references[]` scout field). The TS test-surface row and gates are `next typegen && tsc --noEmit` → the repo's linter → `next build`, with Vitest/Jest and `@playwright/test`. The plugin is bumped to **1.7.0**. There are 1247 tests, all green.

**FIX① fixed:** 66 of 66 REVIEW① findings (1 critical, 13 high, 22 medium, 30 low) and 1 of 1 TEST① failure. Every fix was reproduced first as a failing test, and snippet bugs were also reproduced by running or compiling them.
**FIX① not reproducible / blocked:** none.
**Left open:** REVIEW② found 0 critical, 0 high, 8 medium and 22 low; there are 0 TEST② failures and 0 REVIEW① items still open. All of them are listed under *Left open* below.

**Decisions that are yours**
1. Left-open items: start a new goal for them (they are all MEDIUM/LOW consistency or test-guard gaps), or accept them as they are.
2. Release: promoting `dev` → `main` is ready if you want it; nothing holds it back. Remember that `~/.claude/skills` and the plugin marketplace read this checkout.
3. Deploys: none apply. This repo has no Vercel or Supabase.
4. **Your main checkout:** it still has the untracked draft `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs.md`. `git pull` of `dev` there will refuse to overwrite it, so delete or move that draft first; the merged version contains it.
5. To pick up 1.7.0 in other repos, update the `dev-bother-me-nope` plugin from the local marketplace.

## Deploy checklist — nothing was deployed to Vercel; Supabase MAIN untouched

**Vercel:** not applicable. There is no `vercel.json` or Vercel project, and no build was triggered.
**Supabase:** not applicable. There are no migrations.
**Env vars / secrets to add:** none.

## Summary
You asked to flesh out your Next.js skill draft with expert, current TypeScript and Next.js practices grounded in nextjs.org and Vercel docs. The run checked live that Next.js 16.3.8 is current. It turned the draft into an entry point plus nine topic files: 400+ imperative rules with ids, typed patterns, Don't/Do anti-patterns, checklists, version notes and a "Not confirmed by the docs" section. Every rule cites a page fetched live, about 300 unique sources, all returning 200. Code examples were type-checked against next@16.3.8 in strict mode, and the SSE and security examples were run under Node. The standard is wired into bmn so TypeScript stories read it, and the run is merged to `dev`.

## Stories
| Story | Result | Tests (unit) | REVIEW① C/H/M/L | Fixed in FIX① | Left open (R2) | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| nextjs-standard-entry-point-and-skill-wiring | ✅ | helpers + reference + wiring | 0/3/5/4 (+ run items) | all | R2-A2, A4, A5 | plugin 1.7.0 |
| typescript-config-and-typing-patterns | ✅ | topic + contract | 0/2/0/2 | all | R2-A8 | |
| app-router-routing-and-metadata | ✅ | topic + contract | 1/0/2/2 | all | R2-A1, A7 | critical open redirect fixed |
| rendering-caching-and-streaming-ssr | ✅ | topic + contract | 0/1/1/3 | all | R2-B2, B3 | |
| data-fetching-server-actions-and-forms | ✅ | topic + contract | 0/0/1/1 | all | R2-B7, B9 | |
| route-handlers-and-api-design | ✅ | topic + contract | 0/1/2/5 | all | R2-B1, B4, B6, B10 | |
| server-sent-events-and-streaming-responses | ✅ | topic + contract + Node harness | 0/3/5/5 | all | R2-C3, C5–C8 | |
| proxy-auth-and-security | ✅ | topic + contract | 0/0/2/1 (+C9) | all | R2-C10 | |
| performance-and-vercel-platform | ✅ | topic + contract | 0/0/1/4 | all | R2-C9 | |
| testing-errors-and-observability | ✅ | topic + contract | 0/1/2/2 | all | R2-A3/C1, C2, C4 | |

**Reviews (`/code-review` high, one pass each):** REVIEW① C/H/M/L 1/13/22/30 · REVIEW② re-check 66 fixed / 0 still open / 0 regressed / 0 not reproducible · REVIEW② new C/H/M/L 0/0/8/22 · `docs/sprints/bmn-nextjs-typescript-best-practices-reference/review.md`

## Assumptions I made instead of asking
1. `references/nextjs.md` stays where you put it and is **read** as a reference, not loaded as a Skill. `nextjs-fullstack-standards` is still loaded when a session has it.
2. Your folder structure is kept as the canonical layout. Its tree formatting was cleaned up, and `src/proxy.ts` and `src/instrumentation.ts` were added with doc citations.
3. Deep topics are split into nine files, each ≤ 800 lines (your file-size rule).
4. Grounding: only nextjs.org/vercel.com for Next/Vercel behaviour, and react.dev, typescriptlang.org, MDN, WHATWG, zod, vitest and playwright only for facts they own. Anything a page didn't confirm, or where docs disagree (for example Vercel vs nextjs.org limits, or the Zod 3 forms guide vs Zod 4), went under "Not confirmed by the docs".
5. Session-helper contract across all topics: `src/lib/dal.ts` exports `getSession()` (nullable; Route Handlers/SSE/APIs) and `verifySession()` (redirects; pages, layouts, actions). Server Actions live in `src/lib/actions/`.
6. Lint: new projects use ESLint + eslint-config-next, and a repo already on Biome keeps it. The gate runs the configured linter.
7. Plugin bumped once to 1.7.0. `dev` had moved to 1.6.1 from another run, and the higher version was kept.
8. REVIEW① and REVIEW② diffed this run's own changes, not `dev_base…`, because `dev` took another run's changes mid-run.
9. TEST② content only re-checked what FIX① changed. TEST② and REVIEW② ran in parallel after you asked why the run was slow.
10. The repo merge policy was already set (`already-set`).

## FIX① — what the fix round did
All 66 findings are **fixed**, each with a named failing-then-passing test in its story's `validation.md` FIX① section. Highlights:
- **R1-A1 (critical):** `toSafePath` now resolves with `new URL(value, base)` and requires the same origin. Against a 28-case hostile corpus it went from 7 cross-origin escapes to 0.
- **R1-A3/C4:** P1 tsconfig now matches create-next-app 16 (`esnext` lib, `.next/dev/types`), which fixed the TEST① TS2550 failure.
- **R1-B2:** cache persistence on Vercel is stated as the docs state it (`use cache` vs `unstable_cache`/fetch cache/`use cache: remote`).
- **R1-C1–C3:** the SSE route returns 401 via `getSession()`, buffers live events until replay finishes, and uses the `/src/` prefix in vercel.json function keys.
- **R1-A2/C5:** the gate runs `next typegen` before `tsc`.
- **R1-A7/A9:** bmn routes references through `routed_references[]`, and the tester uses TypeScript tooling.

## Left open — not fixed by this run
MEDIUM (8):
- **R2-B1** `route-handlers-and-apis.md:106`: `rejectCrossSiteRequest()` needs `APP_ORIGIN`, which no env schema defines, and it rejects a missing Origin. Playwright's `request` fixture, dev servers and preview URLs all get 403.
- **R2-A3 = R2-C1** `testing-and-observability.md:70`: TEST-37 still gates lint before types and allows ESLint only, against stack-routing/NN-9/TS-12.
- **R2-C2** `testing-and-observability.md:632`: the Do config uses `Number(process.env.E2E_PORT)` with no fallback, and nothing sets `E2E_PORT`, so it runs `next start -p NaN`.
- **R2-C3 = R2-B8** `sse-and-streaming.md:574`: the chat POST has no Origin check, uses an ad-hoc error body, and returns a 401 with an empty body.
- **R2-C4** `testing-and-observability.md:94`: coverage doesn't exclude the server-only DAL/session modules, which can pull the 80% floor under.
- **R2-A1** `test_nextjs_topic_routing_and_metadata.py:164`: `zip(strict=True)` fails under Python 3.9.
- **R2-A2** `briefs.md:68`: the scout `gates{}` has no build key and no order, so `next build` can be dropped.

LOW (22): R2-A4–A8, R2-B2–B7, B9, B10 and R2-C5–C12. These are weak test guards (A5, A6, A7, B9, B10), duplicated HMAC and constant-time helpers (B5, C11), env reads outside the env schema (C12), small SSE hook and stream edge cases (C5–C8), a missing `/api/vitals` handler (C9), SEC-4 wording (C10), cursor cache-key growth (B4), missing imports in three Do blocks (B6), a second `actions/posts.ts` example (B2, B3), DF-14 vs a throwing Do block (B7), tsconfig `.mts` wording (A8), and the SKILL.md description length (A4). Full text is in `review.md` → REVIEW②.

## Repo merge settings
`repo-merge-policy.py` → `already-set` on `GreatFigure8/Claude-Skills` (`allow_squash_merge=false`, `delete_branch_on_merge=true`). Unchanged.

## Git cleanup
**Run branch** `feat/nextjs-typescript-best-practices-reference` · worktree `../claude-skills-nextjs-typescript-best-practices-reference`: deleted (local + origin) — merged into `dev`.
**Deleted, per branch:** every `wip/nextjs-typescript-best-practices-reference/*` story, fix and test branch (local + origin) and its paired `worktree-agent-*` harness branch; all harness worktrees removed (99 entries in `bmn.json.cleanup.deleted`).
**Left:** nothing.

## Evidence
Run-level `review.md` (REVIEW① and REVIEW②), per-story `validation.md` (TEST①, FIX①, TEST②) and `evidence/` (sources-verified lists, Node/tsc harness output).
