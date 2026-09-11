# assert-branch-before-merge — execution plan

Sprint: 2026-09-11-003   Story: assert-branch-before-merge   Kind: service
Grounded: Skills/dev-story-flow/assets/bin/sprint-state.sh (whole, 179 lines),
Skills/dev-story-flow/references/sprint-state.md (whole), Skills/dev-story-flow/references/dev-story-coder.md
(headings + steps 3/6, merge lines at 82-83 and 154), Skills/dev-story-sprint/SKILL.md (Step 3 merge line
127, Step 4 prose 145-147 — no literal `git merge` line exists there today), Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh
(whole) and sprint-state-list-integration.sh (whole, as the integration-test pattern to copy).
Assumed: SKILL.md Step 4 has no existing `git merge --no-ff ... <live>` command block (only prose) — item 6
adds one alongside the `assert-branch --target live` line so AC5's `grep -B2` check has a merge line to
find in that file; this is a direct consequence of R3/AC5, not a design choice needing confirmation.

## Items
| # | Branch | Scope / Done when / Not | Files owned | Wave | Model | Gates |
|---|---|---|---|---|---|---|
| 1 | feat/assert-branch-before-merge-cmd | Add `cmd_assert_branch(base, args)` to the embedded python3 in sprint-state.sh: parse `<sprint>` + optional `--target integration\|live` (default `integration`); `load()` the manifest; resolve `m["branch"]["integration"]` or `["live"]`, redirecting `--target integration` to `branch.live` when `branch.integration == "none"`, `die()` if neither resolvable; get current branch via `subprocess.run(["git","rev-parse","--abbrev-ref","HEAD"])` in cwd; match → exit 0 silent; mismatch → stderr `assert-branch: expected on '<sprint>' <target> branch '<expected>', but currently on '<actual>'`, exit 1. Register in the `main()` dispatch dict and in the header usage comment (lines 5-13) alongside `new`/`list`/`get`/`set`/`story`/`stale`. Done when: `sprint-state.sh assert-branch --help`-shaped misuse (no args) exits 2 via `die`, matching the other subcommands' usage errors. Not: no change to `cmd_new`/`cmd_set`/`cmd_story`/etc. | Skills/dev-story-flow/assets/bin/sprint-state.sh | 1 | Sonnet 5 | `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` still exits 0 (no regression to existing subcommands) |
| 2 | docs/assert-branch-before-merge-refs | Add `assert-branch` to the command list in sprint-state.md's "The helper" section (after `stale`), one line matching the existing table style: `sprint-state.sh assert-branch <sprint> [--target integration\|live]  → exit 0 if current branch matches; exit 1 + stderr naming both otherwise`. | Skills/dev-story-flow/references/sprint-state.md | 1 | Sonnet 5 | `grep -n 'assert-branch' Skills/dev-story-flow/references/sprint-state.md` shows the new line |
| 3 | docs/assert-branch-before-merge-coder | In dev-story-coder.md: before the `git merge --no-ff -m "merge(<slug>): item <n> ..."` line in "### 3. Execute each story using its plan", insert `sprint-state.sh assert-branch <sprint> || <abort/fix, do not merge>` (or the `$SS assert-branch <sprint>` form matching how `$SS` is used elsewhere in the file). Before the `git merge --no-ff -m "merge(sprint): <sprint> — <k> stories"` line in "### 6. Mark the sprint complete", insert `sprint-state.sh assert-branch <sprint> --target live`. | Skills/dev-story-flow/references/dev-story-coder.md | 1 | Sonnet 5 | `grep -B2 'git merge --no-ff' Skills/dev-story-flow/references/dev-story-coder.md` shows `assert-branch` in the 2 lines above each of the two merge lines |
| 4 | docs/assert-branch-before-merge-sprint-skill | In dev-story-sprint/SKILL.md "## Step 3": before the `git merge --no-ff -m "merge(<slug>): item <n> <branch> (#<n>)" origin/<branch>` line, insert `sprint-state.sh assert-branch <sprint>` (with a one-line prose note that this only fires when a sprint.json manifest exists — a bare dev-story-sprint run without one skips it). In "## Step 4 — Story done": since this section is prose-only today, add a small fenced command block giving Step 4 the same shape as Step 3 — `sprint-state.sh assert-branch <sprint> --target live` immediately followed by `git merge --no-ff -m "merge(sprint): <sprint> — done" origin/<integration-or-branch> && git push origin <live>` — folded into the existing prose paragraph without disturbing the issue-close/retro text after it. | Skills/dev-story-sprint/SKILL.md | 1 | Sonnet 5 | `grep -B2 'git merge --no-ff' Skills/dev-story-sprint/SKILL.md` shows `assert-branch` in the 2 lines above each merge line (2 occurrences total) |
| 5 | test/assert-branch-unit | Append unit checks to sprint-state-fixtures.sh (after the existing `get` checks, before the final echo/exit), following its `check()`/`field()` helpers: create a sprint via `new`, `git checkout -b` the sprint's real `branch.integration` and `branch.live` names in `$TMP`, and assert: on-branch → `assert-branch <sprint>` exit 0; on `git checkout -b other-branch` → exit 1 and stderr (captured via `2>&1`) contains both the expected and actual branch names; `--target live` exit 0 on live branch, exit 1 elsewhere; a second sprint created with `new --integration none` → `assert-branch <sprint>` (default target) checks against `branch.live` and exits 0 when on that branch. Done when: `bash sprint-state-fixtures.sh` reports 0 failed including these new checks. Not: does not touch sprint-state-list-integration.sh or any doc file. | Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh | 2 | Sonnet 5 | `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` |
| 6 | test/assert-branch-integration | New `sprint-state-assert-branch-integration.sh`, copying sprint-state-list-integration.sh's shape (throwaway `git init` repo, `SPRINTS_DIR` override, `check()`/`ok()`/`bad()`): `new` a sprint, explicitly `git checkout -b` its integration and live branch names (don't rely on git's default init branch), run `assert-branch <sprint>` on the correct branch (expect exit 0, empty stdout/stderr) and on an unrelated `git checkout -b elsewhere` branch (expect exit 1, stderr matches both branch names via `grep`), and the same pair for `--target live`. Done when: script exits 0. | Skills/dev-story-flow/assets/tests/sprint-state-assert-branch-integration.sh | 2 | Sonnet 5 | `bash Skills/dev-story-flow/assets/tests/sprint-state-assert-branch-integration.sh` |

## Validation — how the coder proves each acceptance criterion
| AC | Check | Command / browser steps | Pass when |
|---|---|---|---|
| AC-U | unit | `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` | exit 0 |
| AC-I | integration | `bash Skills/dev-story-flow/assets/tests/sprint-state-assert-branch-integration.sh` | exit 0 |
| AC1 | unit | `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` (correct-integration-branch checks from item 5) | exit 0 |
| AC2 | unit | `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` (wrong-branch checks from item 5 assert both names appear in stderr) | exit 0 |
| AC3 | integration | `bash Skills/dev-story-flow/assets/tests/sprint-state-assert-branch-integration.sh` (`--target live` correct/wrong-branch pair) | exit 0 |
| AC4 | unit | `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` (`--integration none` redirect-to-live check from item 5) | exit 0 |
| AC5 | docs | `grep -B2 'git merge --no-ff' Skills/dev-story-flow/references/dev-story-coder.md Skills/dev-story-sprint/SKILL.md` | every matched merge line's preceding 2 lines include `assert-branch` (4 merge lines total: coder steps 3+6, SKILL.md steps 3+4) |

## Order and dependencies
Wave 1 (items 1-4) touch four disjoint files and run together — items 2-4 only need the subcommand's
name/flags/exit contract from the story spec, not the merged implementation. Wave 2 (items 5-6) depends on
item 1 landing first (they invoke the real `assert-branch` subcommand) but not on items 2-4. No dependency
on any other story — this is the only story in sprint 2026-09-11-003.

## Risks and gotchas
- `git init`'s default branch name is environment-dependent (`init.defaultBranch`); items 5 and 6 must
  `git checkout -b <explicit-name>` for every branch they test rather than relying on whatever `git init`
  picked, or the tests will be flaky/false-passing across machines.
- The die-message format in the spec (`assert-branch: expected on '<sprint>' <target> branch '<expected>',
  but currently on '<actual>'`) is exact text the AC2/AC-U checks grep for — item 1 must match it verbatim,
  and items 5/6 must grep for the same substrings, not a paraphrase.
- SKILL.md's Step 4 has no existing `git merge --no-ff` line (prose only today) — item 4 has to introduce
  one to give AC5's `grep -B2` something to match, which is a slightly larger edit than "insert one line"
  for that file; keep it inside the existing paragraph's flow rather than restructuring the section.
- `branch.integration == "none"` redirect (R2/AC4): easy to get backwards — `--target integration` reads
  `branch.live` only when `branch.integration` is literally the string `"none"`; `--target live` always
  reads `branch.live` regardless.
- Items 2-4 are documentation-only and carry no functional gate beyond grep — a reviewer should still
  visually confirm the inserted line reads correctly in context (right variable name, right position
  relative to `&&`-chained commands) since grep only proves presence, not correctness.

## Open questions
none — Jonathan confirmed the requirements and acceptance criteria as-is in story.md.
