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

## TEST1 content

Run 2026-10-04 on a detached worktree at `origin/dev` `59279a3` (branch `wip/nextjs-typescript-best-practices-reference/tests-content-1`). This repo ships Markdown, so the black-box surface is the content: live sources, and the TypeScript snippets compiled in a real Next.js 16.3.8 project. File under test: `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs.md`.

### 1. Live sources

Command (per URL, 8 in parallel): `curl -sL -A <desktop browser UA> --max-time 20 --max-redirs 10 -o /dev/null -w "%{http_code}|%{url_effective}|%{num_redirects}" <url>`. A URL passes only when the final status is 2xx and the final URL is the same page (host without `www.`, path without trailing slash). Scope: every URL in the file.

Result: **13 URLs, 13 pass, 0 fail**. (Across all ten files: 283 unique URLs, 283 pass, 0 fail; every one returned HTTP 200 with no redirect.)

| URL | HTTP | Redirects | Result |
| --- | --- | --- | --- |
| https://nextjs.org/blog/next-16 | 200 | 0 | pass |
| https://nextjs.org/blog/next-16-3 | 200 | 0 | pass |
| https://nextjs.org/blog/september-2026-security-release | 200 | 0 | pass |
| https://nextjs.org/docs | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/proxy | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/route | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/route-groups | 200 | 0 | pass |
| https://nextjs.org/docs/app/api-reference/file-conventions/src-folder | 200 | 0 | pass |
| https://nextjs.org/docs/app/getting-started/project-structure | 200 | 0 | pass |
| https://nextjs.org/docs/app/getting-started/route-handlers | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/environment-variables | 200 | 0 | pass |
| https://nextjs.org/docs/app/guides/upgrading/version-16 | 200 | 0 | pass |

### 2. Snippet type-check

`nextjs.md` has no ```` ```ts ```` or ```` ```tsx ```` fence (its fences are `text`, `bash`, `json` and `css`), so there is nothing to compile for this story. Result: **0 fences, 0 fail**.

Method (same for every story; the scratch project lives outside the repo and is not committed):

- Scratch dir `/private/tmp/claude-501/-Users-jonathanstevenson-Source-claude-skills/b71aefe4-ae21-4000-aa3e-8b70fbcfbe94/scratchpad/tscheck-test1/w1/app`, `npm install --save-exact next@16.3.8 react react-dom typescript@7.0.2 @types/react @types/react-dom @types/node zod server-only client-only vitest @playwright/test @testing-library/react vite-tsconfig-paths @vitejs/plugin-react shiki jose ai @vercel/otel @vercel/firewall @opentelemetry/api` (resolved: next 16.3.8, react and react-dom 19.3.0, typescript 7.0.2, @types/react and @types/react-dom 19.3.0, @types/node 26.6.4, zod 4.6.5, server-only 0.0.1, client-only 0.0.1, vitest 5.0.3, @playwright/test 1.63.0, @testing-library/react 16.3.3, vite-tsconfig-paths 6.1.1, @vitejs/plugin-react 6.1.1, shiki 4.5.0, jose 6.2.12, ai 7.0.127, @vercel/otel 2.1.3, @vercel/firewall 1.2.5, @opentelemetry/api 1.9.1; all from npm). typescript 6.0.3 and 5.9.3 were installed beside it for the cross-check and the parse pass.
- Every ```` ```ts ```` and ```` ```tsx ```` fence of the ten files was extracted (218 fences: 160 Do/Pattern/rule, 58 inside the Don't half of an Anti-patterns entry). Each doc becomes one virtual Next.js project under `app/proj/<doc>/`: a fence whose first line is a `// path/to/file.ts` comment is written at that path (first occurrence only, Don't halves never), so `@/` and relative imports between fences resolve to the real fence; every other fence is its own module under `_loose/`. `next typegen` runs per project so the global `PageProps`, `LayoutProps` and `RouteContext` types exist; dummy `page.tsx`, `layout.tsx`, `route.ts` and `@slot` files are created for the route literals the fences use.
- Compiler config: the doc's own P1 `tsconfig.json` (`strict: true`, `noUncheckedIndexedAccess`, `lib: ES2020`, `moduleResolution: bundler`, ...) with `paths` `@/*` -> `./*` and `./src/*`; command `node node_modules/typescript/bin/tsc --noEmit --pretty false -p tsconfig.json` (TypeScript 7.0.2) in each project. Cross-checks: TypeScript 6.0.3 with the same config, and TypeScript 7.0.2 with the `create-next-app` default compilerOptions (`strict`, `target ES2017`, `lib dom/dom.iterable/esnext`).
- Prelude (declared, never silent): a fence that is a fragment gets only (a) `export {}` when it has no import or export, (b) a wrapper `async function __fragment() {` ... `}` when it is a bare statement list (TS1108 `return` outside a function), (c) an `import` of a well-known Next.js, React or Zod name (`z`, `redirect`, `notFound`, `revalidateTag`, `updateTag`, `cookies`, `Suspense`, ...) that the fence uses but does not import, (d) `declare var name: any` for any other free name the fence uses but does not define, (e) an any-typed stub module for a local `@/` or `./` import that no fence in the doc defines, (f) a typed export on the doc's own module when the doc says the module holds more than it shows. The records below say which fence got which.
- A fence with a parse error cannot be typechecked, so it is parked outside the project and reported on its own.

## FIX① (2026-10-04)

Branch `wip/nextjs-typescript-best-practices-reference/nextjs-standard-entry-point-and-skill-wiring-fix`, cut from `origin/feat/nextjs-typescript-best-practices-reference` at `8188c54`. To reproduce, the tests below were written first and run against the unfixed text. `test_nextjs_wiring.py` + `test_nextjs_reference.py` had 26 failures and `test_nextjs_doc_helpers.py` had 23 (the new tests only). After the fix: `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q` gave **1065 passed**, and `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` gave **All checks passed!**

| id | result | reproducing test(s) (all failed before the fix, pass after) | rule restored |
| --- | --- | --- | --- |
| R1-A2 (= R1-C5) | fixed | `test_nextjs_wiring.py::test_stack_routing_type_gate_runs_typegen_first`, `::test_stack_routing_typescript_gates_run_types_then_lint_then_build`, `::test_stack_routing_test_surfaces_names_typescript_tooling` | TS-5, TEST-37 (`next typegen && tsc --noEmit`; the nextjs.org CLI page, 16.3.8, gives that exact command and says a bare `tsc --noEmit` doesn't validate route types) |
| R1-A5 | fixed | `test_nextjs_reference.py::test_non_negotiable_9_is_one_lint_rule_the_gate_can_run`, `test_nextjs_wiring.py::test_stack_routing_test_surfaces_names_typescript_tooling` (`biome check .`, "the repo's configured linter") | NN-9, TS-12 (the typescript fixer aligns TS-12) |
| R1-A6 (with R1-C6) | fixed | `test_nextjs_reference.py::test_non_negotiable_2_never_adds_middleware` | NN-2, SEC-1 |
| R1-A7 | fixed | `test_nextjs_wiring.py::test_stack_routing_route_table_has_a_read_column`, `::test_stack_routing_typescript_row_reads_the_reference_never_loads_it`, `::test_stack_routing_maps_each_column_to_a_scout_field`, `::test_stack_scout_returns_references_in_their_own_field`, `::test_common_preamble_reads_routed_references`, `::test_skill_intake_routes_references_through_their_own_field` | none (wiring) |
| R1-A8 (= R1-C8) | fixed | `test_nextjs_wiring.py::test_stack_routing_http_black_box_is_the_request_fixture_not_fetch` | TEST-1, TEST-15 |
| R1-A9 | fixed | `test_nextjs_wiring.py::test_tester_brief_uses_the_typescript_row_tooling`, `::test_skill_test1_uses_the_typescript_tooling` | TEST-1, TEST-15 |
| R1-A14 | fixed | `test_nextjs_wiring.py::test_fullstack_standards_is_always_conditional[SKILL.md]`, `[briefs.md]`, `::test_reviewer_brief_keeps_fullstack_standards_when_available` | none (wiring) |
| R1-A15 | fixed | `test_nextjs_doc_helpers.py::test_section_prefers_the_shallowest_heading_over_an_earlier_deeper_one`, `::test_contract_readers_ignore_a_deeper_heading_with_a_contract_name`, `::test_tilde_fences_are_fences`, `::test_stray_rule_lines_flag_a_column_zero_fence_and_prose`, `::test_cites_source_ignores_a_backticked_convention_tag` (`::test_a_backtick_fence_is_not_closed_by_tildes` is a guard: it passed before and after) | none (test harness) |
| R1-B17 | fixed | `test_nextjs_doc_helpers.py::test_uses_any_type_catches_every_spelling`, `::test_uses_any_type_ignores_comments_identifiers_and_strings`, `::test_topic_tests_use_the_shared_any_check_and_major` | none (test harness) |

Evidence for R1-B17: the three old regexes, run on `const e: Record<string, any> = {}`, all returned `False` (rendering, data-fetching, route-handlers). They returned `True` on `Promise<any>` and `any[]`.

What changed:

- `stack-routing.md`: the Route table gains a **Read** column. `references/nextjs.md` moved out of the two Skill columns into it, and a paragraph maps Build with → `routed_build_skills[]`, Review lenses → `routed_review_lenses[]`, Read → `routed_references[]`. The TypeScript test-surfaces row now says: HTTP black-box is Playwright's `request` fixture (TEST-15); the gates, in order, are `next typegen && tsc --noEmit`, then the repo's configured linter (`eslint .` with `eslint-config-next`, or `biome check .` where Biome is already used), then `next build`.
- `briefs.md`: the common preamble adds the Read-tool line `{routed_references}`. stack-scout returns `routed_references[]` and takes TS gates and surfaces from the TypeScript row. The reviewer adds `nextjs-fullstack-standards` only when the session has it. In the tester, the TypeScript row replaces pytest-playwright and httpx.
- `SKILL.md`: the description and REVIEW① both make `nextjs-fullstack-standards` conditional. INTAKE names `routed_references[]`. TEST① names the TypeScript tooling.
- `nextjs.md`: NN-2 says never add `middleware.ts`; keep an existing one only while it depends on Edge, and plan its move to `proxy.ts`. NN-9 is the single lint rule. The ESLint reference was added to Sources.
- `nextjs_doc_helpers.py`: `section(level=)` returns the shallowest match. The contract readers pin H2. `~~~` fences are recognised. New: `stray_rule_lines()`, `uses_any_type()` / `ANY_TYPE_RE`. `cites_source()` reads prose only. The three topic tests use `h.uses_any_type` and `h.major` (only those lines changed).
- Tests that pinned the old wording were updated: `test_stack_routing_typescript_row_names_the_reference_in_both_cells` was replaced. `test_stack_routing_test_surfaces_names_typescript_tooling` dropped `fetch` and bare `tsc --noEmit`. `test_reviewer_brief_keeps_fullstack_standards` became `..._when_available`. The `SKILL_DESCRIPTION_SHA256` pin was moved (renamed `test_skill_frontmatter_description_pinned`). `test_topic_rules_are_well_formed_and_numbered` now uses `h.stray_rule_lines`.

### FIX① assumptions

1. The gate order (types → lint → build) follows the orchestrator's decision. TEST-37 in `testing-and-observability.md` lists `eslint .` first. That file belongs to the testing fixer; if it isn't aligned, the order disagreement stays.
2. `nextjs.org/docs/app/api-reference/edge` (16.3.8) does not call Edge deprecated. So NN-2 rests on `proxy.js` (Proxy defaults to Node.js; `runtime` can't be set in Proxy) and the upgrade guide ("If you want to continue using the `edge` runtime, keep using `middleware`"). It never claims Edge itself is deprecated. "Plan its move" is the house rule, and the `middleware-to-proxy` codemod is quoted from `proxy.js`.
3. NN-9 carries `(convention)` beside its links, because "new projects use ESLint, Biome repos keep Biome" is the house choice. The links back the facts: "use Biome or ESLint directly", `eslint-config-next`, and no `next lint`.
4. `routed_references[]` holds `nextjs.md` only. Each reader picks the topic files per story from its Topic index.
5. `plugin.json` is unchanged. No item needs a new version, and `test_skill_text_rules.py` (not owned here) pins `1.7.0`.
6. The SKILL.md frontmatter description was edited for R1-A14 consistency. Its sha256 pin in `test_nextjs_wiring.py` moved with it.
