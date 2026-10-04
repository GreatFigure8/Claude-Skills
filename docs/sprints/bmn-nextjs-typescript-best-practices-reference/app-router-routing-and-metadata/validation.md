# Validation — app-router-routing-and-metadata

Branch `wip/nextjs-typescript-best-practices-reference/app-router-routing-and-metadata`, cut from
`origin/feat/nextjs-typescript-best-practices-reference` (efff2ea). Date: 2026-10-04.

## TDD record

| Step | Command | Result |
| --- | --- | --- |
| RED | `pytest .../test_nextjs_topic_routing_and_metadata.py -q` (file still a stub) | 16 collected: 15 failed, 1 passed. Failures were `LookupError: no heading 'Not confirmed by the docs'` and the assertions `not is_stub`, rule count, terms, examples, checklist, anti-patterns. They fail for the right reason: the file is a stub. The one pass is `test_routing_topic_examples_never_type_as_any`, which holds trivially with no code blocks. |
| GREEN | same command after writing the topic file | 16 passed |
| GREEN, generic contract | `pytest test_nextjs_topic_routing_and_metadata.py test_nextjs_reference.py -q -rs` | 145 passed, 56 skipped. The 56 skips are 7 generic tests x 8 other stubs. No skip names `routing-and-metadata` (was 63 before this story). |

## Gates (AC10)

- Full suite: `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`
  gives **690 passed, 56 skipped** (76 s). Baseline on the run branch was 667 passed, 63 skipped:
  +16 story tests, +7 generic tests that no longer skip for this topic.
- Lint: `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` gives `All checks passed!`.
- Types: none (stack.md). The topic's snippets were nevertheless compiled, see below.
- Line cap: the topic file is 712 lines (cap 790 in the plan, 800 in the contract).

## AC9 grounding evidence

One-off check (script saved as a file in the scratchpad because the harness refuses heredocs; it is
the plan's command, run from this worktree):

```text
src = set(source_urls(read(routing-and-metadata.md)))
ev  = set(https URLs in evidence/sources-verified.md) minus the llms.txt version source
print('equal:', src == ev, sorted(src ^ ev))
```

Output:

```text
equal: True []
sources count: 58 prose count: 58
sources never cited in prose: []
prose not in sources: []
lines: 712
rules: 40 ts/tsx fences: 24
antis: 6 checklist: 17
```

## Extra check: the snippets compile

Beyond the plan, every `ts`/`tsx` block in `## Patterns` (14 files) and the Do half of each
anti-pattern (5 files) was extracted into a scratch app in the session scratchpad with
`next@16.3.8`, `react@19.2.0`, `typescript@5.9.3` and `strict: true`. Local modules the snippets
import (`post-schema`, `products`, `projects`, `photo-view`) were stubbed. `next typegen` generated
the global `PageProps`/`LayoutProps` route types, and `tsc -p` then reported **no errors** across all
23 source files. Nothing from that scratch tree is committed.

## Live re-check of the verified rule sheet

The brief says to re-fetch anything that looks wrong. Every rule's cited page was re-read on
2026-10-04 (Markdown variants, nextjs.org, vercel.com, react.dev status 200). The rule sheet held, with
these deliberate edits to match the pages exactly:

- **RT-31.** The pages state "not in event handlers" only for `redirect()`. The rule now scopes
  that sentence to `redirect()` and the checklist item follows. Both functions are typed `never`
  and are called outside `try`/`catch`.
- **RT-9.** The `global-error` html/body requirement (error.js page) is folded into the rule.
- **RT-26.** Worded as the layout.js page words it: layouts don't re-render on navigation, so
  they can't read the pathname or the latest search params.
- **RT-11.** The `generateMetadata` awaited `params` is a separate sentence with its own link.
- **Patterns.** The plan's "Verified" and "Design choice" planner notes were turned into one short
  prose paragraph under each pattern, per the plan's rule that planner notes never go in the file.

Facts confirmed live, among others: the v16 guide's async-API list, image-function and sitemap `id`
Promises, `default.js` build failure and the `data-scroll-behavior` opt-in; `generateStaticParams`
(array, `[]`, Cache Components needs one param, top-down and bottom-up); `dynamicParams` removed
under Cache Components (route-segment-config row `v16.0.0`); `partialPrefetching` (`16.3.0`, needs
`cacheComponents`); the `prefetch` export values; `robots` `other` (`v16.3.0`); root params; redirect
status codes and `redirects` running before Proxy; Vercel's 1,024 vs 2,048 limits.

## Assumptions

1. The merged skeleton contract was read first (`nextjs.md` Authoring contract,
   `nextjs_doc_helpers.py`, `test_nextjs_reference.py`, the skeleton `validation.md`). It matches the
   plan's defaults: `section(text, "Rules")` takes the bare title, `read` takes a `Path`, and `TOPICS`
   values are `(prefix, slug)`. Only the Anti-patterns markers needed no widening.
2. The plan's test module is kept assertion for assertion. Two mechanical edits only:
   `test_every_checklist_item_names_an_rt_rule` uses `h.checklist_items` (so a wrapped item is one
   item) instead of a line scan, and `zip(..., strict=True)` in `_anti_pattern_chunks`.
3. `## Rules` is one flat numbered list with no `###` group headings, and each rule is one physical
   line, as the plan's format note requires. A `###` between items would be folded into the previous
   item by `numbered_items`.
4. The H1 is "App Router routing, navigation and metadata" (the plan's outline). The skeleton's
   "Routing and metadata" title applies only to a stub.
5. The as-of line is copied from `nextjs.md`: `> As of Next.js 16.3.8, verified 2026-10-04.`
6. `evidence/sources-verified.md` is unchanged. Its set still equals `## Sources`.
7. The adopting-partial-prefetching page now also links
   `https://nextjs.org/docs/app/guides/optimizing-prefetching`. It was not fetched as a source for any
   rule, so it is not cited.
8. No generateSitemaps block trim was needed: the file is 712 lines.
9. `nextjs-fullstack-standards` was not loaded and no build skill was routed (stack.md). No `.sh`
   file changed, so shellcheck had nothing to check. No migrations, env vars or deploy_pending.

## TEST1: unit (2026-10-04)

Branch `wip/nextjs-typescript-best-practices-reference/tests-unit-1`, cut from the detached run base `origin/dev` `59279a3` (the run branch tip after
the wave-2 merges, with origin/dev merged in). Tester: `tests-unit-1`. No code was changed; this is a
verification pass.

### Commands and results

| Step | Command | Result |
| --- | --- | --- |
| Full suite with coverage | `uv run --quiet --with pytest --with pytest-cov python -m pytest Skills/dev-bother-me-nope/assets/tests -q --cov=Skills/dev-bother-me-nope/assets/tests --cov-report=term` | **1026 passed in 95.32s (0:01:35)**, exit 0, 0 failed, 0 skipped. Log: `docs/sprints/bmn-nextjs-typescript-best-practices-reference/nextjs-standard-entry-point-and-skill-wiring/evidence/test1-unit-full-suite.txt` |
| Lint | `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` | `All checks passed!` |
| Story tests, verbose | `pytest test_nextjs_topic_routing_and_metadata.py test_nextjs_reference.py ... -v` (483 tests across the nextjs files and `test_skill_text_rules.py`) | 483 PASSED, 0 other. The tests this map cites are listed in `evidence/test1-unit-results.txt` |
| TERMS and example needles | one-off script comparing this story's criterion 3 and 4 lists with the test | story TERMS (32) equal the test's TERMS (32), same order: True; story example needles missing from the test source: 0 |
| URL sets | one-off script comparing `## Sources` of `references/nextjs/routing-and-metadata.md` with the URLs in `evidence/sources-verified.md` | 58 cited, 59 listed, nothing only in one of them. The evidence file also names `https://nextjs.org/docs/llms.txt` in its header prose, as the place the version string was read; it is not a per-URL row and the topic file does not cite it, so the row sets are equal. All 58 evidence rows carry fetch date 2026-10-04 and a non-empty Backs cell |
| Scope | one-off `git diff --name-only <merge>^1 <merge>` for this story's merge `d0b022c` | 3 files, all inside the story scope (the topic file, `test_nextjs_topic_routing_and_metadata.py`, and files under `docs/sprints/bmn-nextjs-typescript-best-practices-reference/app-router-routing-and-metadata/`); outside scope: none |

### Coverage

- `references/nextjs/routing-and-metadata.md`: Markdown, coverage n/a. It is exercised by the generic contract tests and by `test_nextjs_topic_routing_and_metadata.py`; the file is 40 rules, 713 lines (cap 800).
- `nextjs_doc_helpers.py` (shared parser the tests use): **99%** (243 of 245 statements). Uncovered: line 180 (an unterminated code fence at end of file) and line 294 (`h1` of an empty file). Target 80% met.
- `test_nextjs_topic_routing_and_metadata.py`: **100%** (68 of 68 statements). Whole suite: **99%** (3604 of 3635).

### Criterion map

All [unit] criteria of `story.md`, mapped to the test or one-off check that covers them. The generic
contract tests are the ones `test_nextjs_reference.py` runs for every topic file; none is skipped
(the suite has no skips), so each ran on `routing-and-metadata.md`.

| AC | Criterion | Covering test(s) / check | Result |
| --- | --- | --- | --- |
| 1 | Contract | generic contract tests (17 x `[routing-and-metadata.md]` + `test_rule_ids_are_unique_across_topic_files`)<br>`test_routing_topic_cites_no_other_topics_rule_ids` | PASS |
| 2 | Not a stub, at least 15 RT rules | `test_routing_topic_replaces_the_stub`<br>`test_routing_topic_has_at_least_fifteen_rt_rules` | PASS |
| 3 | Required terms | `test_routing_topic_covers_required_concepts` | PASS |
| 4 | Examples (generateStaticParams, generateMetadata, sitemap, notFound, useSearchParams; no `any`) | `test_routing_topic_has_worked_example`<br>`test_routing_topic_examples_never_type_as_any` | PASS |
| 5 | Parallel-route `default` rule in `## Rules` | `test_rules_state_the_parallel_route_default_requirement` | PASS |
| 6 | Links `../nextjs.md` (canonical layout) | `test_canonical_layout_is_linked_from_the_topic` | PASS |
| 7 | Version notes name the major and link nextjs.org | `test_version_notes_name_the_major_and_link_nextjs_org` | PASS |
| 8 | Reviewer-ready | `test_every_checklist_item_names_an_rt_rule`<br>`test_every_anti_pattern_pairs_a_dont_with_a_do` | PASS |
| 9 | Grounding evidence (one-off) | one-off set-equality check, see below | PASS |
| 10 | Scope and gates (one-off + suite + ruff) | one-off `git diff --name-only` check, full suite, ruff (see below)<br>`test_not_confirmed_section_lists_the_urls_checked` | PASS |

**Totals:** 10 PASS, 0 FAIL, 0 uncovered.

### TEST1 assumptions

1. AC9 (grounding evidence) is a one-off check by design ("not a permanent test"). It was re-run here with the plan's set-equality method and passed.
2. AC10 scope is checked against the story's merge into the run branch (`git diff --name-only <merge>^1 <merge>`), because `origin/feat/...` has since moved on. The suite and ruff are checked on the final tree.
3. Where the criterion text asks for content beyond what its test asserts (for example, the shape of an example), the test is taken as the verification the story names; factual correctness of the claims against nextjs.org and vercel.com is the REVIEW① lens, not a unit test.
