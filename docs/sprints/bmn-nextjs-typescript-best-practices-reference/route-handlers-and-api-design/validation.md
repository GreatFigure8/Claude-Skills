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

## TEST1: unit (2026-10-04)

Branch `wip/nextjs-typescript-best-practices-reference/tests-unit-1`, cut from the detached run base `origin/dev` `59279a3` (the run branch tip after
the wave-2 merges, with origin/dev merged in). Tester: `tests-unit-1`. No code was changed; this is a
verification pass.

### Commands and results

| Step | Command | Result |
| --- | --- | --- |
| Full suite with coverage | `uv run --quiet --with pytest --with pytest-cov python -m pytest Skills/dev-bother-me-nope/assets/tests -q --cov=Skills/dev-bother-me-nope/assets/tests --cov-report=term` | **1026 passed in 95.32s (0:01:35)**, exit 0, 0 failed, 0 skipped. Log: `docs/sprints/bmn-nextjs-typescript-best-practices-reference/nextjs-standard-entry-point-and-skill-wiring/evidence/test1-unit-full-suite.txt` |
| Lint | `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` | `All checks passed!` |
| Story tests, verbose | `pytest test_nextjs_topic_route_handlers_and_apis.py test_nextjs_reference.py ... -v` (483 tests across the nextjs files and `test_skill_text_rules.py`) | 483 PASSED, 0 other. The tests this map cites are listed in `evidence/test1-unit-results.txt` |
| TERMS and example needles | one-off script comparing this story's criterion 3 and 4 lists with the test | story TERMS (24) equal the test's TERMS (24), same order: True; story example needles missing from the test source: 0 |
| URL sets | one-off script comparing `## Sources` of `references/nextjs/route-handlers-and-apis.md` with the URLs in `evidence/sources-verified.md` | 48 cited, 48 listed, nothing only in one of them. All 48 evidence rows carry fetch date 2026-10-04 and a non-empty Backs cell |
| Scope | one-off `git diff --name-only <merge>^1 <merge>` for this story's merge `57e8d97` | 4 files, all inside the story scope (the topic file, `test_nextjs_topic_route_handlers_and_apis.py`, and files under `docs/sprints/bmn-nextjs-typescript-best-practices-reference/route-handlers-and-api-design/`); outside scope: none |

### Coverage

- `references/nextjs/route-handlers-and-apis.md`: Markdown, coverage n/a. It is exercised by the generic contract tests and by `test_nextjs_topic_route_handlers_and_apis.py`; the file is 39 rules, 719 lines (cap 800).
- `nextjs_doc_helpers.py` (shared parser the tests use): **99%** (243 of 245 statements). Uncovered: line 180 (an unterminated code fence at end of file) and line 294 (`h1` of an empty file). Target 80% met.
- `test_nextjs_topic_route_handlers_and_apis.py`: **100%** (118 of 118 statements). Whole suite: **99%** (3604 of 3635).

### Criterion map

All [unit] criteria of `story.md`, mapped to the test or one-off check that covers them. The generic
contract tests are the ones `test_nextjs_reference.py` runs for every topic file; none is skipped
(the suite has no skips), so each ran on `route-handlers-and-apis.md`.

| AC | Criterion | Covering test(s) / check | Result |
| --- | --- | --- | --- |
| 1 | Contract | generic contract tests (17 x `[route-handlers-and-apis.md]` + `test_rule_ids_are_unique_across_topic_files`)<br>`test_topic_uses_only_api_rule_ids` | PASS |
| 2 | Not a stub, at least 18 API rules | `test_topic_is_not_a_stub`<br>`test_topic_has_at_least_18_api_rules` | PASS |
| 3 | Required terms | `test_topic_covers_required_terms` | PASS |
| 4 | Examples (validated POST, RouteContext, webhook raw body, CORS preflight; no `any`) | `test_validated_post_example_returns_error_shape`<br>`test_dynamic_segment_example_uses_typed_route_context`<br>`test_webhook_example_verifies_signature_on_raw_body`<br>`test_cors_example_answers_preflight`<br>`test_examples_contain_no_any` | PASS |
| 5 | Error shape declared once under Patterns, tagged (convention), used by the POST example | `test_error_shape_declared_once_under_patterns_as_convention`<br>`test_post_example_references_error_shape`<br>`test_pattern_handlers_returning_errors_use_error_shape` | PASS |
| 6 | Mutating handlers call a session or auth check (webhook exempt) | `test_mutating_handler_examples_check_session_or_auth` | PASS |
| 7 | Route Handler vs Server Action rule; Server Component must not fetch own handler | `test_rules_frame_route_handler_versus_server_action`<br>`test_rules_forbid_server_component_fetching_own_route_handler` | PASS |
| 8 | Version notes name the major and link nextjs.org | `test_version_notes_name_major_and_link_nextjs` | PASS |
| 9 | Reviewer-ready | `test_review_checklist_items_name_existing_api_rules`<br>`test_anti_patterns_pair_dont_with_do` | PASS |
| 10 | Grounding evidence (one-off) | one-off set-equality check, see below | PASS |
| 11 | Scope and gates (one-off + suite + ruff) | one-off `git diff --name-only` check, full suite, ruff (see below)<br>`test_not_confirmed_section_states_no_rules`<br>`test_links_sibling_topics_instead_of_duplicating` | PASS |

**Totals:** 11 PASS, 0 FAIL, 0 uncovered.

### TEST1 assumptions

1. AC9 (grounding evidence) is a one-off check by design ("not a permanent test"). It was re-run here with the plan's set-equality method and passed.
2. AC10 scope is checked against the story's merge into the run branch (`git diff --name-only <merge>^1 <merge>`), because `origin/feat/...` has since moved on. The suite and ruff are checked on the final tree.
3. Where the criterion text asks for content beyond what its test asserts (for example, the shape of an example), the test is taken as the verification the story names; factual correctness of the claims against nextjs.org and vercel.com is the REVIEW① lens, not a unit test.
