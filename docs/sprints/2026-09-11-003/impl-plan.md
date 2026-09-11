# Sprint 2026-09-11-003 — implementation plan

Branch line: live=dev  integration=sprint/2026-09-11-003
Stories: 1   Items: 6   Waves: 2

## Execution order
| Wave | Story | Items | Depends on | Model(s) |
|---|---|---|---|---|
| 1 | assert-branch-before-merge | 1 (cmd), 2 (sprint-state.md), 3 (dev-story-coder.md), 4 (SKILL.md) | — | Sonnet 5 |
| 2 | assert-branch-before-merge | 5 (unit tests), 6 (integration test) | item 1 | Sonnet 5 |

## Cross-story dependencies and gotchas
Single-story sprint, no cross-story concerns. Within the story: items 2-4 (docs) only need the
subcommand's name/flags/exit contract from story.md, not item 1's merged code, so all of wave 1
runs concurrently — but items 5-6 (tests) invoke the real `assert-branch` subcommand and must wait
for item 1 to land first.

Two things the coder must get exactly right (see the story plan's Risks section for detail):
- The die-message text (`assert-branch: expected on '<sprint>' <target> branch '<expected>', but
  currently on '<actual>'`) is grepped verbatim by the tests — item 1 and items 5/6 must agree on it.
- `dev-story-sprint/SKILL.md` Step 4 has no existing `git merge --no-ff` line today (prose only);
  item 4 introduces one so AC5's `grep -B2` check has something to match in that file.

## Open questions
None — story.md's Open questions was "none" (Jonathan confirmed requirements/AC as-is), and the
planner raised none.

## Definition of sprint-complete
- assert-branch-before-merge `done` in sprint.json, its Validation table all-pass (AC-U, AC-I,
  AC1-AC5)
- `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` and the new
  `sprint-state-assert-branch-integration.sh` both exit 0 on the integration branch
- integration branch (`sprint/2026-09-11-003`) merged to live (`dev`)
