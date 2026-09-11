# Sprint 2026-09-11-002 — implementation plan

Branch line: live=dev  integration=sprint/2026-09-11-002
Stories: 2   Items: 15   Waves: 7

## Execution order
| Wave | Story | Items | Depends on | Model(s) |
|---|---|---|---|---|
| 1 | flow-stopping-point-160k | 1 gate script, 2 matcher JSON, 3 phase docs | — | Sonnet 5 |
| 2 | flow-stopping-point-160k | 4 gate fixtures, 5 integration test, 6 install-merge test, 7 coder dry-run test | wave 1 | Sonnet 5 |
| 3 | auto-clear-prompt-at-stop | 1 `context-budget-lib.sh` extraction | story 1 done (validated + merged) | Opus 5 |
| 4 | auto-clear-prompt-at-stop | 2 gate stop sentence, 3 session-start surfacing | wave 3 | Sonnet 5 |
| 5 | auto-clear-prompt-at-stop | 4 Stop hook, 5 clear-prompt SKILL.md | wave 4 | Opus 5, Sonnet 5 |
| 6 | auto-clear-prompt-at-stop | 6 registration/install, 7 budget doc sentences | wave 5 | Sonnet 5 |
| 7 | auto-clear-prompt-at-stop | 8 integration test | wave 6 | Sonnet 5 |

Plans: `flow-stopping-point-160k/flow-stopping-point-160k-plan.md`,
`auto-clear-prompt-at-stop/auto-clear-prompt-at-stop-plan.md`.

## Cross-story dependencies and gotchas
- **Strictly serial across stories.** Both stories edit `context-budget-gate.sh`, its
  `context-budget-gate-fixtures.sh`, `settings-hooks.json`, `install.sh`,
  `Skills/dev-story-flow/SKILL.md` and `references/dev-story-coder.md`. Story 2 starts only
  after story 1 is `done` on the integration branch; story 2's plans were written against the
  gate as story 1 leaves it (STOP threshold, stop band, per-tool table).
- **Epic-mode output must stay byte-identical** through both stories. Story 1 item 4 adds the
  golden-output fixture (story 1 AC-3); story 2 item 1's lib extraction is gated on it (story
  2 AC-7).
- **Fixture line counts drifted from the stories:** `context-budget-gate-fixtures.sh` is 321
  lines, not 282; executors re-read the live file. `session-start-fixtures.sh` already fails 2
  cases on `dev`; its gate for this sprint is "still exactly 2 failures, new cases pass".
- **`UNIT` derivation** (story 2 §1): the segment *after* `.claude/stories/`, not the last
  path segment — the gate's own fixture writes deeper paths.
- **`session-end-guard.sh`** exits 0 early on a clean tree (line 17); story 2's marker sweep
  goes above that guard.
- **Stop hook contract** (confirmed against the docs by the planner): block is top-level
  `{"decision":"block","reason":…}` on stdout with exit 0; `matcher` is meaningless for `Stop`;
  non-JSON stdout with exit 0 is reported as a hook error; Claude Code caps consecutive
  blocks at 8 — the once-per-session marker is still required.
- **Installed copy is not the repo copy.** `~/.claude/hooks/context-budget-gate.sh` changes
  only when `install.sh --user` is re-run; every validation runs the repo scripts directly.
  The sprint's closing message must say the local install is stale until Jonathan re-runs it.
- `.claude/signals/` is already git-ignored (verified).

## Open questions
none — both stories' intake assumptions (story 1 Q1–Q8, story 2 Q2 and the once-per-session
block) are adopted as written; the coder takes them as defaults.

## Definition of sprint-complete
- every story `done` in sprint.json, its Validation table all-pass
- sprint gates green on the integration branch; integration merged to live (`dev`)
