# Sprint 2026-09-11-001 — implementation plan

Branch line: live=dev  integration=sprint/2026-09-11-001
Stories: 2   Items: 5   Waves: 2 (story-level)

## Execution order
| Wave | Story | Items | Depends on | Model(s) |
|---|---|---|---|---|
| 1 | list-story-counts | 2 (feat/list-story-counts-column, test/list-story-counts-coverage) | none | Sonnet 5 |
| 2 | emphasize-story-counts | 3 (feat/emphasize-story-counts-style, test/emphasize-story-counts-unit, test/emphasize-story-counts-tty) | list-story-counts | Sonnet 5 |

## Cross-story dependencies and gotchas
- Both stories edit `cmd_list` in the same file, `Skills/dev-story-flow/assets/bin/sprint-state.sh`
  — `emphasize-story-counts` item 1 must branch after `list-story-counts` has merged to the
  integration branch, not run concurrently against the pre-merge base.
- `emphasize-story-counts` item 3 extends `assets/tests/sprint-state-list-integration.sh`, which
  `list-story-counts` item 2 creates — same ordering constraint.
- macOS `script` is incompatible for the TTY test; both story plans specify python3 `pty.spawn`.
- NO_COLOR-vs-DSF_FORCE_STYLE precedence: NO_COLOR must always win, even when DSF_FORCE_STYLE=1
  is also set (per `emphasize-story-counts`'s AC-3) — flagged as a risk in that story's plan.

## Open questions
- `emphasize-story-counts` plan: the story spec doesn't state whether `DSF_FORCE_STYLE=1`
  overrides `NO_COLOR`. Default taken: NO_COLOR always wins (matches AC-3). Coder implements
  this default; no Jonathan input needed unless AC-3 as written turns out to be wrong.

## Definition of sprint-complete
- every story `done` in sprint.json, its Validation table all-pass
- sprint gates green on the integration branch (`sprint/2026-09-11-001`); integration merged to
  `dev`
