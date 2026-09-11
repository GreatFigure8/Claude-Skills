# assert-branch-before-merge — validation

Sprint: 2026-09-11-003   Story: assert-branch-before-merge
Run against: `sprint/2026-09-11-003` @ a467187 (all 6 items merged)
Time: 2026-09-11T18:40Z

| AC | Check | Command | Result | Pass |
|---|---|---|---|---|
| AC-U | unit | `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` | `53 passed, 0 failed`, exit 0 | ✅ |
| AC-I | integration | `bash Skills/dev-story-flow/assets/tests/sprint-state-assert-branch-integration.sh` | `12 passed, 0 failed`, exit 0 | ✅ |
| AC1 | unit | correct-integration-branch checks (item 5, part of AC-U run) | included in the 53 passing | ✅ |
| AC2 | unit | wrong-branch checks, stderr names both branches (item 5, part of AC-U run) | included in the 53 passing | ✅ |
| AC3 | integration | `--target live` correct/wrong-branch pair (item 6, part of AC-I run) | included in the 12 passing | ✅ |
| AC4 | unit | `--integration none` redirect-to-live (item 5, part of AC-U run) | included in the 53 passing | ✅ |
| AC5 | docs | `grep -B2 'git merge --no-ff' Skills/dev-story-flow/references/dev-story-coder.md Skills/dev-story-sprint/SKILL.md` | 4 merge lines total (coder steps 3+6, SKILL.md steps 3+4), `assert-branch` present in the 2 lines above each | ✅ |

## Real-manifest sanity check (beyond the fixtures)

Run directly against this sprint's own `sprint.json` from the integration branch worktree
(`SPRINTS_DIR=docs/sprints bash Skills/dev-story-flow/assets/bin/sprint-state.sh assert-branch 2026-09-11-003 [--target live]`):

- Default target, on `sprint/2026-09-11-003`: exit 0, silent.
- `--target live`, on `sprint/2026-09-11-003`: exit 1, stderr —
  `assert-branch: expected on '2026-09-11-003' live branch 'dev', but currently on 'sprint/2026-09-11-003'`

Confirms the subcommand behaves correctly against a real manifest, not just the throwaway
fixture repos the unit/integration scripts construct.

## Notes

- Item 1's executor reported the sandbox denied writes to the repo-root status path and wrote
  status to a mirrored path inside its own worktree instead; the commit stream (the source of
  truth per dev-story-coder.md) was unaffected and every item verified cleanly from `git log`/
  `git diff --stat` before merge.
- Items 3 and 4 each found their target doc section held only prose (no literal `git merge
  --no-ff` line) where the plan assumed one existed; both added a small fenced command block
  in place, consistent with the plan's own flagged risk and AC5's requirement.
