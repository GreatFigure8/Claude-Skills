# Sprint 2026-09-11-004 — implementation plan

Branch line: live=dev  integration=sprint/2026-09-11-004
Stories: 2   Items: 2   Waves: 1

## Execution order
| Wave | Story | Items | Depends on | Model(s) |
|---|---|---|---|---|
| 1 | fix-install-matcher-upgrade | 1 | none | Sonnet 5 |
| 1 | fix-refresh-live-git-c-cwd | 2 (sequential: fix, then its fixture) | none | Sonnet 5 |

## Cross-story dependencies and gotchas
No shared files between the two stories (`install.sh`+its fixture vs. `refresh-live-post-push.sh`
+ a new fixture file) — both can execute concurrently. Within `fix-refresh-live-git-c-cwd`, item 2
(the fixture) depends on item 1 (the hook fix) landing first, since the fixture proves the fixed
behavior. Both stories' fixture harnesses must sandbox `$HOME`/throwaway git repos and never touch
the real `~/.claude` or the real `claude-skills-main` worktree.

## Open questions
None — both plans report none.

## Definition of sprint-complete
- Both stories `done` in `sprint.json`, their Validation tables all-pass.
- `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/install-matcher-fixtures.sh` and
  `bash Skills/dev-story-sprint/assets/tests/refresh-live-post-push-fixtures.sh` both exit 0 on the
  integration branch.
- Integration branch (`sprint/2026-09-11-004`) merged into `dev`.
