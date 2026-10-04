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
