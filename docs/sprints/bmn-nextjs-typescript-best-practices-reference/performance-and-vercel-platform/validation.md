# Validation — performance-and-vercel-platform

Branch `wip/nextjs-typescript-best-practices-reference/performance-and-vercel-platform`, cut from
`origin/feat/nextjs-typescript-best-practices-reference` (skeleton merged). Date: 2026-10-04.
`deploy_pending: []` — no migration, no env var, no config change; Markdown and a pytest file only.

## TDD record

| Step | Command | Result |
| --- | --- | --- |
| RED | `pytest test_nextjs_topic_performance_and_vercel.py` against the stub | 21 collected: 14 failed, 7 passed. Failures: `is_stub` true, no rules, missing terms, the five examples, no Edge rule, no Version notes, no checklist, no Anti-patterns, no Patterns section (`LookupError: no heading 'Patterns'`). The 7 passes are the four unit-check self-tests, the no-`any` check, and the number-link and deploy-command checks, which are vacuous on a stub. |
| GREEN | same file after the topic was written | 21 passed |
| GREEN, contract | `pytest test_nextjs_topic_performance_and_vercel.py test_nextjs_reference.py -rs` | 150 passed, 56 skipped; the skips are the 8 remaining stubs x 7 generic tests, none for `performance-and-vercel.md` |
| REFACTOR | file first came out at 944 lines, failing `test_file_is_at_most_800_lines`; trimmed and re-wrapped | 783 lines, all green |

## Gates

- Full suite: `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q -rs` gives
  **695 passed, 56 skipped** (76 s). The skeleton's count was 667 passed, 63 skipped (730 total). Now 751 total: 21 new
  tests, and the 7 generic contract tests for this topic moved from skipped to passed.
- Lint: `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` gives `All checks passed!`.
- Types: none (stack.md). As an extra, the 24 `ts`/`tsx` fences of Patterns and Anti-patterns were written to a scratch
  folder and compiled with `tsc` 7.0.2 under `strict` against `next@16.3.8`, `react@19`, `@types/react@19` and
  `shiki`, with a stub for `./chart`: no errors. Nothing from that folder is committed.
- shellcheck: no `.sh` file changed.
- Line cap: `wc -l` gives 783 (limit 800).
- Scope: `git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists the topic file, the
  topic test file, and files under this story's folder only.

## Acceptance criteria

1. Contract: the 7 generic tests parametrised for this file run with no skip and pass. Only `PERF-` ids (1 to 43).
2. `test_performance_topic_is_not_a_stub`; `test_performance_topic_has_at_least_15_perf_rules` (43 rules).
3. `test_performance_topic_names_every_required_concept`: all 22 terms found. None needed to move to Not confirmed.
4. Five `has_block_with` examples, plus `test_typescript_examples_use_no_any_type` over every `ts`/`tsx` fence.
5. `test_every_vercel_number_line_carries_a_platform_link` and three self-tests of the checker (see Assumptions 3).
6. `test_runtime_choice_rule_names_edge_with_a_vercel_link`: PERF-29 holds `Edge` and a vercel.com link in one item.
7. `test_version_notes_name_the_major_and_link_nextjs`: names `Next.js 16`, links nextjs.org.
8. `test_every_checklist_item_names_a_perf_rule` (15 items), `test_checklist_rule_ids_exist_in_rules`,
   `test_anti_patterns_pair_each_dont_with_a_do` (6 pairs).
9. `evidence/sources-verified.md` has one row per Sources URL (51). One-off check, run from
   `Skills/dev-bother-me-nope/assets/tests` with the plan's command (the evidence URLs normalised with
   `normalize_url` before comparing):

   ```text
   True [] 51 51
   ```

   The two URL sets are equal.
10. Scope and gates: above.

## Grounding re-check (done by the coder on 2026-10-04)

- All 51 Sources URLs fetched with `curl -H 'Accept: text/markdown'`: every one returned HTTP 200.
- 174 key phrases from the plan's rule sheet were searched on the saved pages. The first pass found 151 (23 missing);
  the misses were markdown formatting (links, bold, blockquote line wraps). With formatting normalised, 9 remained and
  each was read on its page and confirmed: the `@heroicons/react/*` entries are listed as `@heroicons/react/20/solid`,
  `24/solid`, `24/outline`, so that package is left out of PERF-21; the "`id` for inline scripts" warning is on the
  Scripts guide, not the Script API page (PERF-14 cites both); the other 7 were blockquote wraps or reworded lines
  whose meaning matches.
- Facts not on the plan sheet, each read on the cited page before use: Hobby single region (region page table);
  `iad1` default and "Runs in a single region by default (`iad1`)" (region and runtimes pages); the CDN
  cacheable-response criteria and 1 year maximum (CDN cache page); the `localPatterns` and `remotePatterns` 400
  responses (Image API); `vercel.toml` listed as a static config file (project configuration page).
- The Speed Insights quickstart embeds an agent prompt that says to deploy with a Vercel CLI command. It is page data and
  is not reproduced.

## Assumptions

1. **The merged contract wins over the plan.** Differences found and followed:
   - Anti-patterns are `### Don't …` H3 headings (`h.anti_patterns`), each followed by a fence, a `**Do** …` line and a
     second fence. The plan's `**Don't**` bold lead-ins would not be seen by the generic floor test. The Anti-patterns
     test is written against `h.anti_patterns`.
   - H3 headings are free inside a section, so Rules and Patterns use `###` groupings. `section()` stops only at a
     heading of the same or higher level, so the plan's no-`###` workaround was not needed.
   - Rules are numbered items with indented continuation lines, not single physical lines.
2. **Rule text carries a headline sentence, then wrapped detail.** The rules were re-wrapped to 120 columns with a
   scratch script that keeps each `[text](url)` link whole, to fit the 800-line cap.
3. **Unit-token check groups an item as a column-0 list item plus every indented line under it**, nested bullets
   included. The plan's grouping started a new item at each nested bullet, which would flag a nested number whose link
   sits on the parent line. Self-tests cover: no link flags the line; a link elsewhere in the item passes; a nested
   bullet counts as part of its item; one item's link does not vouch for the next item; fenced numbers are ignored.
4. **Plan content dropped to stay under 800 lines:** the LCP-hero Pattern (the Do block of the second anti-pattern shows
   `loading="eager"`), the Speed Insights/Analytics layout block (PERF-27 gives both imports and the placement), the
   optional CDN-headers snippet, the local-font line of `fonts.ts` (PERF-8 still names `next/font/local`), the
   `$schema` line of the cron `vercel.json`, and the list of three accepted `s-maxage` directive shapes in PERF-37.
5. **PERF-29 is scoped to page, layout and route files.** `nextjs.md` non-negotiable 2 still allows a `middleware.ts`
   for the Edge runtime, so a blanket "never Edge" would contradict it. No defect in a shared file is recorded: the two
   statements are consistent as scoped.
6. **PERF-42 adds `vercel.toml`**, which the project-configuration page lists beside `vercel.json`, and drops the plan's
   `@vercel/config/v1` import line, because that page's example imports more names and the file shows no `vercel.ts` code.
7. **PERF-21 carries `(convention)`** on the analyzer-first workflow sentence; the experimental status is the docs'.
8. **Three more tests than the plan:** 21 collected against 18: two extra checker self-tests (4, plan: 2) and the
   no-`any` test (plan AC4 asks for typed examples).
9. The research date and the coder's re-check date are both 2026-10-04.
