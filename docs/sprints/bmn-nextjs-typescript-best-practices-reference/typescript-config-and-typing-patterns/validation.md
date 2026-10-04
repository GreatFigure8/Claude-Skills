# Validation: typescript-config-and-typing-patterns

Branch `wip/nextjs-typescript-best-practices-reference/typescript-config-and-typing-patterns`, cut
from `origin/feat/nextjs-typescript-best-practices-reference` (skeleton merged). Date: 2026-10-04.
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.

## TDD record

| Step | Command | Result |
| --- | --- | --- |
| RED | `pytest .../test_nextjs_topic_typescript.py` against the stub | 17 failed, 0 passed. Every failure is the stub: no rules, `is_stub` true, no `Patterns` or `Anti-patterns` section, no code blocks, the stub's one Source not linked in the body |
| GREEN, first draft | the topic file plus `test_nextjs_reference.py` | 145 passed, 1 failed: `test_file_is_at_most_800_lines`, 880 lines. The draft was trimmed (no rule, pattern or anti-pattern dropped) |
| GREEN | same two files, `-rs` | **146 passed, 56 skipped**. The 56 skips are the seven generic tests for each of the eight other stubs; nothing is skipped for `typescript.md` |
| Full suite | `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q` | **691 passed, 56 skipped** (69 s). Base was 667 passed, 63 skipped: +17 new tests and 7 generic tests that no longer skip |
| Lint | `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` | `All checks passed!` |

## Acceptance criteria

| AC | Evidence |
| --- | --- |
| 1 Contract | `test_nextjs_reference.py` runs every generic check on `typescript.md` with no skip and passes. `test_typescript_topic_uses_only_ts_rule_ids` passes: TS-1 to TS-34, no gap, no other prefix anywhere in the file |
| 2 Not a stub, 15 rules | `test_typescript_topic_is_not_a_stub`, `test_typescript_topic_has_at_least_15_rules` (34 rules) |
| 3 Terms | `test_typescript_topic_mentions_every_required_term` (all 20 terms, the last one with backticks) |
| 4 Examples | five `has_block_with` tests: P1 (json, `"strict": true`), P2 (`NextConfig`, `typedRoutes`), P4 (`PageProps<'/`, `await`), P6 (`RouteContext<'/`, `await`), P4 and P6 (`safeParse`); `test_typescript_topic_examples_never_use_any` scans every `Patterns` block |
| 5 Helpers and `Promise` | `test_typescript_rules_say_how_route_helpers_are_generated` (TS-5 and TS-16), `test_typescript_topic_awaits_search_params_in_tsx` (P4) |
| 6 No build-error bypass, no `any` | `test_typescript_rules_forbid_ignore_build_errors_and_ban_any` (TS-6, TS-28) |
| 7 Version notes | `test_typescript_version_notes_name_major_and_link_nextjs`. Eight bullets: all five candidates the story lists (sync access removal, `typedRoutes` status, route helpers and `next typegen`, `next lint` removal, minimum TypeScript) plus image-file promises, `revalidateTag`, runtime config, `proxy.ts` and the 16.3 CLI checker, each with its link |
| 8 Reviewer-ready | `test_typescript_review_checklist_items_cite_rule_ids` (20 items), `test_typescript_anti_patterns_pair_each_dont_with_a_do` (7 pairs, each marker followed by a fence) |
| 9 Grounding evidence | `evidence/sources-verified.md`, 41 rows. One-off check below |
| 10 Scope and gates | diff check below; full suite and ruff above |

## One-off checks

- **AC9 URL sets equal.** `python3 -c` importing `nextjs_doc_helpers`: `source_urls(topic)` and the
  URLs of the evidence table rows, both normalised with `normalize_url`. Output:
  `sources 41 evidence 41 symmetric difference []`.
- **AC10 scope.** `git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD`
  on the code commits lists exactly `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_typescript.py`
  and `R/nextjs/typescript.md`. The docs commit adds only files under this story folder.
- **Every Source is used.** `test_typescript_every_source_is_linked_in_the_body` (permanent) checks
  that each `## Sources` URL is linked in the body, so no Source is decoration.
- **Line count.** `typescript.md` is 787 lines (cap 800).

## Snippet check beyond the plan

The plan said snippets are not compiled. They were compiled anyway, outside the repo, in a scratch
project under the session scratchpad (nothing committed). Next.js 16.3.8, TypeScript 5.9.3, Zod
4.6.5, `@types/react` 19, `@types/node` 22, `server-only`.

- `next typegen && tsc --noEmit` with P1 as the `tsconfig.json`: P2 to P10 and the Do snippets of
  anti-patterns 1, 2, 4, 5 and 6 compile with no error. The files were laid out as the snippets
  assume (`src/app/blog/[slug]/page.tsx`, `src/app/users/[id]/route.ts`, `@analytics` slot with a
  `default.tsx`, `@/*` mapped to `./src/*`).
- The Don't snippet of anti-pattern 5 fails with `TS18046: 'error' is of type 'unknown'`, as TS-34
  says. The Don't snippet of anti-pattern 1 compiles; the file claims only that synchronous access
  was removed in Next.js 16 (upgrade guide), not that it is a type error.
- Runtime check on Zod 4.6.5: P4 falls back when `page` is a `string[]` and defaults `page` to 1 when
  it is missing; `z.flattenError().fieldErrors` is keyed by field name (P6, P7, P9); P7's message
  lists variable names and not the bad values; P8's `.parse()` throws a `ZodError`.

## Assumptions

1. The merged contract wins over the plan's format guesses, and the differences are:
   - Rules wrap across indented continuation lines instead of one physical line each, because the
     contract allows continuations and one-line rules would run past 600 characters.
   - Anti-patterns are `### Don't <title> (TS-n)` H3s, as the contract's `anti_patterns` helper
     requires; each holds one `**Don't**` fenced block and one `**Do**` fenced block.
   - `## Rules` is split with H3 group headings (the contract leaves H3s free), and rule numbers
     run on across the groups.
   - `## Not confirmed by the docs` items are bullets whose checked URLs are bare (not in code), so
     the contract's URL check sees them, and they quote no rule id.
2. One test beyond the plan's 16: `test_typescript_every_source_is_linked_in_the_body`. It is offline
   and reads only the topic file, so it respects "tests never read run folders".
3. `https://nextjs.org/blog/september-2026-security-release` stays in `## Sources`. The stub had it,
   the as-of line rests on it, and Version notes now links it. The plan's list had 40 sources; the
   file has 41. `next-config-js` (N-CFG), the `verbatimModuleSyntax` page (T-VMS) and the
   `exactOptionalPropertyTypes` page were optional in the plan and are not used.
4. Pattern 9 is three blocks, with the state type in its own module, because the `use server` page
   describes async function exports and says nothing about exporting a type from a `'use server'`
   file. That question is the twelfth item under Not confirmed by the docs. The plan's version kept
   the type in the action file.
5. To fit 800 lines the file drops secondary clauses and secondary citations of the sheet without
   changing any rule: the `.cjs`/`.cts` config note, the Vite guide as a second source on TS-1,
   TS-2, TS-3 and TS-10, the SWC-since-Next.js-12 version, the `.env.production*` exclusion of
   `typedEnv`, the `noImplicitAny` and `instanceof` citations on TS-28 and TS-34, and the Data
   Access Layer sentence under TS-24. Every claim that remains still cites its page, and nothing was
   added to a rule that the sheet does not carry.
6. TS-11 says TypeScript 5.1.0 or later (upgrade guide) and notes that async Server Components need
   5.1.3 or later (TypeScript page), because both pages state their number.
7. Grounding: 24 of the 41 pages were re-read in this session, in full or by targeted search of the
   fetched markdown; the other 17 (typescriptlang.org handbook pages, Zod, MDN, React, Vercel and a
   few nextjs.org pages) rest on the plan's verified rule sheet. The evidence file marks each row
   `yes` or `planner read only`. No claim in the sheet was contradicted. The one question raised,
   whether `export type` is allowed in a `'use server'` file, is handled by assumption 4.
8. Observation for REVIEW①, not a rule: in the scratch project, `next typegen` 16.3.8 rewrote
   `tsconfig.json` and added `.next/dev/types/**/*.ts` to `include` by itself. No docs page says so,
   so it stays under Not confirmed by the docs (second item) and P1 does not list it.
9. No defect was found in the shared files (`nextjs.md`, `nextjs_doc_helpers.py`,
   `test_nextjs_reference.py`, the wiring files); none was edited.
10. Supabase, env vars, migrations and deploys: none. `deploy_pending: []`.
