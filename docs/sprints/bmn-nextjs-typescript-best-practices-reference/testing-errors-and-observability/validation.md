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
