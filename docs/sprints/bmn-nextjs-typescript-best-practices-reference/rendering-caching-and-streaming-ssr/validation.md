# Validation — rendering-caching-and-streaming-ssr

Branch `wip/nextjs-typescript-best-practices-reference/rendering-caching-and-streaming-ssr`, cut from
`origin/feat/nextjs-typescript-best-practices-reference` (skeleton merged). Date: 2026-10-04.
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.

## TDD record

| Step | Command | Result |
| --- | --- | --- |
| RED | `pytest .../test_nextjs_topic_rendering_and_caching.py` against the stub | 24 collected, **24 failed**. Failures are the stub's: `is_stub` true, no `RC-` rules (`0 >= 8` anti-patterns, empty rule list), missing terms and examples, `LookupError: no heading 'Review checklist'`. Committed as `test:` before any content. |
| GREEN | same file, with `R/nextjs/rendering-and-caching.md` written | **24 passed** |
| Generic contract | `pytest test_nextjs_reference.py -rs` | passes for `rendering-and-caching.md` with **no skip**: its 7 generic cases moved from skipped to passed (skips 63 to 56; no `SKIPPED` line names this file) |
| Refactor | wording tightened, imports added to the anti-pattern snippets, AP10 dropped for the line budget | topic and contract tests re-run: green |

## Gates (AC10)

- Full suite `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q -rs`:
  **698 passed, 56 skipped** (73 s). The skeleton's 667 passed + 24 new topic cases + 7 generic cases no
  longer skipped = 698. The 56 skips are 7 generic cases × the 8 other stubs, each with the reason
  `<file> is a stub pending <owning slug>`.
- Lint `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope`: `All checks passed!`.
- Types: none (stack.md). shellcheck: no `.sh` file changed.
- `wc -l R/nextjs/rendering-and-caching.md`: 785 lines (cap 800).
- `git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists only
  `R/nextjs/rendering-and-caching.md`, `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_rendering_and_caching.py`
  and files under `docs/sprints/bmn-nextjs-typescript-best-practices-reference/rendering-caching-and-streaming-ssr/`.

## AC9 grounding evidence

`evidence/sources-verified.md` lists the 46 URLs of the file's `## Sources`, each with the 2026-10-04 fetch date
and the rule ids it backs. The plan's one-off set-equality command (script saved as a file because the harness
refuses heredocs inside compound commands):

```text
file: 46 evidence: 46
equal: True | only in file: [] | only in evidence: []
```

All 44 nextjs.org and vercel.com pages, the security release post and the two react.dev pages were fetched live
again by the coder on 2026-10-04. Claims most likely to drift were grepped against the fetched text (see
`evidence/sources-verified.md`, Method). Every `ts` and `tsx` fence (32) was type-checked in strict mode
against the published `next@16.3.8` and `react@19` types with stand-in declarations for `PageProps`,
`LayoutProps` and the application helpers. The only diagnostic is the deliberate one-argument
`revalidateTag('posts')` in the anti-pattern Don't block (TS2554 "Expected 2 arguments"), which confirms the
documented TypeScript error.

## Assumptions

1. **Anti-pattern format follows the merged contract, not the plan's default.** The contract defines
   `### Don't …` H3 headings, each with at least one fenced block. Each heading here names its `RC-` ids, holds
   the Don't block, then a `**Do:**` marker line, then the Do block. The topic test parses exactly that shape.
2. **Nine anti-patterns, not ten.** AP10 (random value in a prerendered component) was dropped for the line
   budget (785 of 800 lines); the plan allowed this. The content stays covered by RC-17 and the
   "Non-deterministic values" pattern.
3. **Sources.** The version-source post (the security release) is the first Sources bullet, as in the stub and in
   `nextjs.md`, because the as-of line rests on it. The sheet's rendering-philosophy page (S4) is cited by no
   rule, so it is not listed. The file has 46 Sources.
4. **Not confirmed items need a prose URL (contract).** The first item names the nonexistent
   `getting-started/cache-components` path as inline code and links the Caching page it checked instead.
5. **Wording on "throws".** Only `updateTag` is documented to throw outside a Server Action (the page's own error
   example). RC-33 and the decision table say `refresh` "cannot be used" elsewhere, which is what its page says.
6. **Examples.** The webhook Route Handler uses `POST` with a signature check (the docs' example uses `GET`), still
   `revalidateTag(tag, 'max')`; the Server Action example carries the auth-check shape from the Server Actions
   guide. Application helpers (`db`, `auth`, `getProfile`, `verifyWebhook`, `postExists`, `Nav`, `List` and
   the like) are placeholders, not Next.js APIs.
7. **Tests are stricter than the plan's 15 cases (24 here):** at least 8 anti-patterns, a model label on every
   rule, RC-1 starting with "Detect", the decision table's `Call from` and `What the user sees` columns, three
   tables in Patterns, at least 10 linked version notes, and at least 12 `ts`/`tsx` fences.
8. **Defects in shared files:** none found. `nextjs.md`, the helpers and `test_nextjs_reference.py` were read-only
   and the contract matched the plan apart from item 1.
9. **No migrations, env vars, Vercel or Supabase work** (stack.md: no UI, no Supabase, no Vercel). `deploy_pending: []`.

## TEST1: unit (2026-10-04)

Branch `wip/nextjs-typescript-best-practices-reference/tests-unit-1`, cut from the detached run base `origin/dev` `59279a3` (the run branch tip after
the wave-2 merges, with origin/dev merged in). Tester: `tests-unit-1`. No code was changed; this is a
verification pass.

### Commands and results

| Step | Command | Result |
| --- | --- | --- |
| Full suite with coverage | `uv run --quiet --with pytest --with pytest-cov python -m pytest Skills/dev-bother-me-nope/assets/tests -q --cov=Skills/dev-bother-me-nope/assets/tests --cov-report=term` | **1026 passed in 95.32s (0:01:35)**, exit 0, 0 failed, 0 skipped. Log: `docs/sprints/bmn-nextjs-typescript-best-practices-reference/nextjs-standard-entry-point-and-skill-wiring/evidence/test1-unit-full-suite.txt` |
| Lint | `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` | `All checks passed!` |
| Story tests, verbose | `pytest test_nextjs_topic_rendering_and_caching.py test_nextjs_reference.py ... -v` (483 tests across the nextjs files and `test_skill_text_rules.py`) | 483 PASSED, 0 other. The tests this map cites are listed in `evidence/test1-unit-results.txt` |
| TERMS and example needles | one-off script comparing this story's criterion 3 and 4 lists with the test | story TERMS (22) equal the test's TERMS (22), same order: True; story example needles missing from the test source: 0 |
| URL sets | one-off script comparing `## Sources` of `references/nextjs/rendering-and-caching.md` with the URLs in `evidence/sources-verified.md` | 46 cited, 46 listed, nothing only in one of them. All 46 evidence rows carry fetch date 2026-10-04 and a non-empty Backs cell |
| Scope | one-off `git diff --name-only <merge>^1 <merge>` for this story's merge `356a2f9` | 4 files, all inside the story scope (the topic file, `test_nextjs_topic_rendering_and_caching.py`, and files under `docs/sprints/bmn-nextjs-typescript-best-practices-reference/rendering-caching-and-streaming-ssr/`); outside scope: none |

### Coverage

- `references/nextjs/rendering-and-caching.md`: Markdown, coverage n/a. It is exercised by the generic contract tests and by `test_nextjs_topic_rendering_and_caching.py`; the file is 47 rules, 786 lines (cap 800).
- `nextjs_doc_helpers.py` (shared parser the tests use): **99%** (243 of 245 statements). Uncovered: line 180 (an unterminated code fence at end of file) and line 294 (`h1` of an empty file). Target 80% met.
- `test_nextjs_topic_rendering_and_caching.py`: **100%** (149 of 149 statements). Whole suite: **99%** (3604 of 3635).

### Criterion map

All [unit] criteria of `story.md`, mapped to the test or one-off check that covers them. The generic
contract tests are the ones `test_nextjs_reference.py` runs for every topic file; none is skipped
(the suite has no skips), so each ran on `rendering-and-caching.md`.

| AC | Criterion | Covering test(s) / check | Result |
| --- | --- | --- | --- |
| 1 | Contract | generic contract tests (17 x `[rendering-and-caching.md]` + `test_rule_ids_are_unique_across_topic_files`)<br>`test_rendering_topic_uses_only_rc_rule_ids` | PASS |
| 2 | Not a stub, at least 18 RC rules | `test_rendering_topic_is_not_a_stub`<br>`test_rendering_topic_has_at_least_18_rc_rules` | PASS |
| 3 | Required terms | `test_rendering_topic_names_every_required_concept` | PASS |
| 4 | Examples (NextConfig+cacheComponents, use cache+cacheLife, cacheTag, Suspense, client wrapper with children; no `any`) | `test_rendering_topic_has_required_example`<br>`test_rendering_topic_examples_have_no_any` | PASS |
| 5 | Detect the caching model first; model labels; `cacheComponents` with `without`/`previous model` | `test_first_rule_tells_the_reader_to_detect_the_caching_model`<br>`test_rules_section_labels_the_caching_model`<br>`test_patterns_tells_the_reader_how_to_detect_the_model`<br>`test_every_rule_carries_a_caching_model_label`<br>`test_scope_explains_the_model_labels` | PASS |
| 6 | Decision table naming revalidateTag, updateTag, revalidatePath, refresh | `test_patterns_has_revalidation_decision_table`<br>`test_decision_table_says_where_each_api_may_be_called_and_what_the_user_sees` | PASS |
| 7 | Version notes name the major and link nextjs.org | `test_version_notes_name_the_major_and_link_nextjs`<br>`test_version_notes_give_every_item_a_link` | PASS |
| 8 | Reviewer-ready | `test_every_review_checklist_item_names_an_existing_rc_rule`<br>`test_every_checklist_line_in_the_section_is_a_checkbox_item`<br>`test_every_anti_pattern_pairs_dont_with_do`<br>`test_anti_patterns_name_existing_rules` | PASS |
| 9 | Grounding evidence (one-off) | one-off set-equality check, see below | PASS |
| 10 | Scope and gates (one-off + suite + ruff) | one-off `git diff --name-only` check, full suite, ruff (see below)<br>`test_patterns_has_rendering_strategies_and_migration_tables` | PASS |

**Totals:** 10 PASS, 0 FAIL, 0 uncovered.

### TEST1 assumptions

1. AC9 (grounding evidence) is a one-off check by design ("not a permanent test"). It was re-run here with the plan's set-equality method and passed.
2. AC10 scope is checked against the story's merge into the run branch (`git diff --name-only <merge>^1 <merge>`), because `origin/feat/...` has since moved on. The suite and ruff are checked on the final tree.
3. Where the criterion text asks for content beyond what its test asserts (for example, the shape of an example), the test is taken as the verification the story names; factual correctness of the claims against nextjs.org and vercel.com is the REVIEW① lens, not a unit test.
