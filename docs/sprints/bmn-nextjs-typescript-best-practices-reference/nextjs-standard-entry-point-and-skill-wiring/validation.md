# Validation — nextjs-standard-entry-point-and-skill-wiring

Branch `wip/nextjs-typescript-best-practices-reference/nextjs-standard-entry-point-and-skill-wiring`,
cut from `origin/feat/nextjs-typescript-best-practices-reference`. Date: 2026-10-04.

## TDD record

| Step | Command | Result |
| --- | --- | --- |
| RED, helpers | `pytest .../test_nextjs_doc_helpers.py` | collection error, `ModuleNotFoundError: No module named 'nextjs_doc_helpers'` (0 collected) |
| GREEN, helpers | same | 41 passed |
| RED, reference + wiring + renamed version test | `pytest test_nextjs_reference.py test_nextjs_wiring.py test_skill_text_rules.py` | 263 collected: 194 failed, 69 passed. Failures were `FileNotFoundError` (nine topic files absent), `LookupError` (sections missing in the 48-line draft), and `AssertionError` (missing wiring text, version still `1.6.0`) |
| GREEN, new files | `pytest test_nextjs_doc_helpers.py test_nextjs_reference.py test_nextjs_wiring.py -rs` | 191 passed, 63 skipped |
| Generic contract on a complete topic | the 185-case reference file run in a scratch copy with a synthetic contract-complete `typescript.md` | all 17 `typescript` cases passed, 0 skipped |

## AC16 gates

- Full suite: `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`
  gives **667 passed, 63 skipped** (74 s). The 476 pre-existing tests are unchanged, apart from
  the renamed version test.
- Skips: exactly 63 = 7 generic topic tests × 9 stubs, each with the reason
  `<file> is a stub pending <owning slug>` (checked with `-rs`: nine lines, `[7]` each, every slug
  equal to the `TOPICS` slug). Nothing else is skipped.
- Lint: `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` gives
  `All checks passed!`.
- shellcheck: no `.sh` file changed.
- Types: none (stack.md).

## AC15 grounding evidence

`evidence/sources-verified.md` lists 13 URLs, each fetched with WebFetch on 2026-10-04. The one-off
set-equality command (the plan's command, run from this harness worktree root instead of the run
worktree path, with the script saved as a file because the harness refuses heredocs):

```text
files = [NEXTJS_MD, *(topic stubs)]
cited = {u for p in files for u in source_urls(read(p))}
listed = {normalize_url(u) for u in URL_RE.findall(read(sources-verified.md))}
exit status: cited != listed
```

Output:

```text
cited: 13 listed: 13
only cited: []
only listed: []
exit=0
```

The version string `16.3.8` was read from the docs sidebar ("Latest Version 16.3.8") and from the
security-release post ("v16.3.8 (Active LTS)").

## Orchestrator addendum (in scope: this story owns `stack-routing.md`)

The "Test surfaces (drives TEST)" table in `references/stack-routing.md` named only Python tooling.
A `TypeScript / Next.js repo` row now carries the TypeScript tooling:

- unit + integration: the repo's runner (Vitest or Jest) with coverage;
- browser (`ui`): Playwright (`@playwright/test`) against `next build && next start` run locally;
- HTTP black-box: `fetch` against the running server;
- gates: `tsc --noEmit`, `eslint .` (`next lint` was removed in Next.js 16) and `next build`;
- details point to `nextjs/testing-and-observability.md`.

The `next lint` removal is confirmed by the upgrade guide (cited in `nextjs.md`). Wiring tests
`test_stack_routing_test_surfaces_names_typescript_tooling` (asserts the row, its Surface cell and
every tooling phrase) and `test_stack_routing_test_surfaces_keeps_the_python_rows` (the Python rows
are unchanged) cover it.

## Assumptions

1. The plan's helper API (§7.4) is implemented as written. Two points the plan left open:
   - `numbered_items` and `bullet_items` keep the list marker (`1. `, `- `), while `rule_items`
     returns `item_text` without its `N. ` marker so `RULE_RE.match(item_text)` works directly;
   - the list-returning section readers (`source_urls`, `malformed_source_lines`, `rule_items`,
     `checklist_items`, `anti_patterns`) return `()` when their section is absent, so the contract
     test for the missing section reports it. Only `section()` raises `LookupError`.
2. The generic tests also check that the list number equals the rule number (`1. **TS-1**`), that a
   topic has a single H1, that only list items or H3s sit at column 0 under `## Rules`, and that a
   still-stubbed topic keeps its plan §7.3 H1.
3. Jonathan's draft has 37 entries below the root, not the 39 the plan's test sketch mentioned.
   `DRAFT_PATHS` lists all 37 in draft order.
4. After the live read, four non-negotiables and one placement rule were reworded to what the pages
   state (list in `evidence/sources-verified.md`). The notable one: `middleware.ts` is not banned
   outright, because Proxy does not support the Edge runtime.
5. `## Version notes` in `nextjs.md` is a bullet list (13 items). The 16.3 headline changes are
   four separate bullets so each has its own source and owner.
6. The test-surfaces row uses the relative link `nextjs/testing-and-observability.md`, which
   resolves from `references/` to a stub that the testing story fills.
7. `nextjs-fullstack-standards` was not loaded and no build skill was routed (stack.md). No `.sh`
   file changed, so shellcheck had nothing to check.
8. The `evidence` folder and this file sit in the run folder on this branch; tests never read run
   folders (the AC15 check is a one-off).
9. Jonathan's untracked draft in his main checkout was not touched.

## TEST1: unit (2026-10-04)

Branch `wip/nextjs-typescript-best-practices-reference/tests-unit-1`, cut from the detached run base `origin/dev` `59279a3`. Tester: `tests-unit-1`.
No code was changed; this is a verification pass over the whole run (this story owns the shared
helpers, the entry point, the wiring and the generic contract tests every topic story relies on).

### Commands and results

| Step | Command | Result |
| --- | --- | --- |
| Full suite with coverage | `uv run --quiet --with pytest --with pytest-cov python -m pytest Skills/dev-bother-me-nope/assets/tests -q --cov=Skills/dev-bother-me-nope/assets/tests --cov-report=term` | **1026 passed in 95.32s (0:01:35)**, exit 0, 0 failed, 0 skipped. Log: `docs/sprints/bmn-nextjs-typescript-best-practices-reference/nextjs-standard-entry-point-and-skill-wiring/evidence/test1-unit-full-suite.txt` |
| Lint | `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` | `All checks passed!` |
| shellcheck | `git diff --name-only d8b709f 59279a3 -- Skills` | no `.sh` file changed, nothing to check |
| Nextjs tests, verbose | `pytest test_nextjs_doc_helpers.py test_nextjs_reference.py test_nextjs_wiring.py test_nextjs_topic_*.py test_skill_text_rules.py -v` | 483 PASSED, 0 other. The tests this map cites are in `evidence/test1-unit-results.txt` |
| URL sets (AC15) | one-off script: `source_urls` of `nextjs.md` and every stub vs the URLs in `evidence/sources-verified.md` | stubs no longer exist, so the set is `nextjs.md` Sources: 13 cited, 13 listed, nothing only in one of them. All 13 rows carry fetch date 2026-10-04 and a non-empty Backs cell |
| Pre-existing tests unchanged (AC16) | `git diff 6b4e4d45a^1 6b4e4d45a -- Skills/dev-bother-me-nope/assets/tests/test_skill_text_rules.py` (the skeleton merge) | 4 lines changed: the version test renamed to `test_plugin_json_is_version_1_7_0` and `"1.6.0"` to `"1.7.0"`; no other pre-existing test file touched |

### Coverage

- `nextjs_doc_helpers.py` (the touched Python): **99%** (243 of 245 statements). Uncovered: line 180 (an unterminated code fence at end of file) and line 294 (`h1` of an empty file). Target 80% met.
- Tests of that code: `test_nextjs_doc_helpers.py` 99%, `test_nextjs_reference.py` 96%, `test_nextjs_wiring.py` 100%. Whole suite: **99%** (3604 of 3635 statements).
- `references/nextjs.md`, `references/nextjs/*.md`, `SKILL.md`, `stack-routing.md`, `briefs.md`: Markdown, coverage n/a. They are exercised by the text tests above.

### Criterion map

| AC | Criterion | Covering test(s) / check | Result |
| --- | --- | --- | --- |
| 1 | Helpers module: constants, functions, matching rules, unit tests on inline samples, stdlib-only, ruff-clean, no function over 50 lines | all 41 tests in `test_nextjs_doc_helpers.py` (paths, `TOPICS` order, read-only mapping, ten allowed hosts, version constants, `read`, `is_stub`, `section`, `code_blocks`, `has_block_with`, `rule_items`, `source_urls`, `all_urls`, `as_of_version`, `missing_terms`, `cites_source`, `url_host`, `test_helpers_module_is_stdlib_only_small_and_immutable`); ruff clean | PASS |
| 2 | Entry point shape: H1, as-of line right after it, seven H2 sections in order | `test_entry_point_h1_is_the_standard_title`<br>`test_entry_point_as_of_line_directly_follows_h1`<br>`test_entry_point_h2_sections_in_order` | PASS |
| 3 | Folder structure kept and cleaned: one text fence, box-drawing only, ` # ` comments, every draft entry at its path, order, comments, `# added:` entries sourced, Placement rules | `test_folder_tree_is_one_text_fence`<br>`test_folder_tree_uses_box_drawing_lines_only`<br>`test_folder_tree_comments_use_space_hash_space`<br>`test_folder_tree_keeps_every_draft_entry_at_its_path`<br>`test_folder_tree_keeps_draft_order`<br>`test_folder_tree_keeps_draft_comments`<br>`test_folder_tree_additions_are_marked_and_sourced`<br>`test_placement_rules_follow_the_tree_and_cite_or_tag`<br>`test_placement_rules_scope_the_layout_to_new_projects` | PASS |
| 4 | Topic index: columns, rows equal `TOPICS` in order, no orphans, links exist | `test_topic_index_columns`<br>`test_topic_index_rows_match_topics_in_order`<br>`test_every_topic_file_on_disk_has_an_index_row`<br>`test_every_indexed_topic_file_exists`<br>`test_topic_index_links_point_into_nextjs_dir` | PASS |
| 5 | Topic stubs: H1, as-of line, marker naming the owning slug, Sources with the version URL; `is_stub` detects the marker | `test_stubs_have_h1_as_of_marker_and_version_source`<br>`test_stub_marker_names_the_owning_story`<br>`test_is_stub_detects_the_marker_line`<br>`test_stub_slug_returns_the_owning_slug`<br>Note: all nine topic files are now filled, so the stub-shape tests find no stub at this commit and pass by design. The stub shape itself was exercised at the skeleton merge (validation TDD record: GREEN `191 passed, 63 skipped` with nine real stubs). | PASS |
| 6 | Authoring contract defined and enforced for every non-stub topic; nothing but stubs skipped | `test_authoring_contract_states_the_contract`<br>generic contract tests on all nine topic files (17 tests x 9 files = 153 runs, all PASSED); 0 skipped in the full suite | PASS |
| 7 | Sources and grounding on all ten files: unique https bullet list, allowed hosts, every prose URL listed, at least 3 nextjs.org or vercel.com URLs | `test_sources_is_a_bullet_list_of_unique_https_urls` x 10<br>`test_every_url_host_is_allowed` x 10<br>`test_every_prose_url_is_listed_in_sources` x 10<br>`test_primary_source_floor` x 10 | PASS |
| 8 | As-of consistency: every topic's version equals `nextjs.md`'s, date 2026-10-04 | `test_topic_as_of_matches_the_entry_point` x 9 | PASS |
| 9 | File hygiene on all ten files: at most 800 lines, no bare fences, relative links resolve, no TODO or TBD | `test_file_is_at_most_800_lines` x 10<br>`test_no_bare_code_fences` x 10<br>`test_relative_links_resolve` x 10<br>`test_no_todo_or_tbd` x 10 | PASS |
| 10 | Entry point content: at most 15 linked, cited non-negotiables; how each agent reads the file; precedence; Version notes with links and owners | `test_non_negotiables_are_few_linked_and_cited`<br>`test_how_agents_use_this_covers_every_agent`<br>`test_how_agents_use_this_states_precedence`<br>`test_entry_version_notes_cite_and_point_to_topics` | PASS |
| 11 | stack-routing.md: TypeScript row names `references/nextjs.md` in both cells, `nextjs-fullstack-standards` kept, Read-not-`Skill(...)` sentence, never-approximate sentence unchanged | `test_stack_routing_typescript_row_names_the_reference_in_both_cells`<br>`test_stack_routing_keeps_fullstack_standards_when_available`<br>`test_stack_routing_says_references_are_read_not_loaded`<br>`test_stack_routing_intro_covers_reference_files`<br>`test_stack_routing_never_approximate_sentence_unchanged`<br>`test_stack_routing_test_surfaces_names_typescript_tooling`<br>`test_stack_routing_test_surfaces_keeps_the_python_rows` | PASS |
| 12 | SKILL.md: INTAKE and REVIEW① link the reference; frontmatter description unchanged | `test_skill_intake_links_the_nextjs_reference`<br>`test_skill_review1_links_the_reference_next_to_fullstack_standards`<br>`test_skill_frontmatter_description_unchanged` | PASS |
| 13 | briefs.md: planner, coder, reviewer, fixer read `nextjs.md` via the plugin root; `rule id` in planner and reviewer; reviewer keeps `nextjs-fullstack-standards`; no other brief changes; squash and helper-path tests still pass | `test_brief_reads_the_nextjs_reference_for_typescript`<br>`test_planner_and_reviewer_briefs_ask_for_rule_ids`<br>`test_reviewer_brief_keeps_fullstack_standards`<br>`test_other_briefs_do_not_mention_the_reference`<br>`test_reviewer_return_json_shape_is_unchanged`<br>`test_brief_lines_say_what_each_agent_does_with_the_rule_ids`<br>`test_squash_is_only_ever_forbidden`<br>`test_every_helper_invocation_uses_the_plugin_root_form` | PASS |
| 14 | Version bump: `plugin.json` is 1.7.0; the pinned test is renamed and asserts 1.7.0; nothing else in `plugin.json` changes | `test_plugin_json_is_version_1_7_0`<br>`test_plugin_json_only_the_version_moved`<br>`test_plugin_json_is_version_1_6_0` no longer exists (grep: none) | PASS |
| 15 | Grounding evidence lists every URL in the Sources of `nextjs.md` and the stubs, with fetch date and what each backs (one-off, not a pytest) | one-off set-equality check, see below | PASS |
| 16 | Gates: full suite passes with pre-existing tests unchanged apart from the renamed version test; ruff clean | full suite 1026 passed in 95.32s (0:01:35); ruff `All checks passed!`; skeleton merge diff touches only the version test among pre-existing tests (see below) | PASS |

**Totals:** 16 PASS, 0 FAIL, 0 uncovered.

### TEST1 assumptions

1. AC5: with all nine topic files filled, no stub remains, so the stub-shape tests are vacuous at this commit. That is the design in the story's Assumptions (topic stories replace stubs and each asserts it is no longer one). The stub criteria were proven at the skeleton merge and are still guarded if a topic file is ever reverted to a stub.
2. AC15: the criterion names "the Sources of `nextjs.md` and of the stubs"; at this commit that is `nextjs.md` alone (13 URLs), and the evidence file lists exactly those 13.
3. AC16 "pre-existing tests unchanged" is checked on the skeleton story's own merge. `origin/dev` also carries unrelated test changes from the merged-branch-cleanup run; they are outside this run's scope and all pass.
