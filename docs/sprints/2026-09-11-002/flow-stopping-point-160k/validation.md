# flow-stopping-point-160k — validation

Sprint: 2026-09-11-002   Validated against: `sprint/2026-09-11-002` @ `e68dc55`   UTC: 2026-09-11T18:38:47Z

| AC | Check | Command | Result |
|---|---|---|---|
| AC-U | unit | `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/context-budget-gate-fixtures.sh` | exit 0, cases=113 failures=0 — PASS |
| AC-U | unit | `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` | exit 0, 46 passed, 0 failed — PASS |
| AC-I | integration | `bash Skills/dev-story-flow/assets/tests/stop-threshold-integration.sh` | exit 0, 9 passed, 0 failed — PASS |
| AC-1 | unit case | gate fixtures §G (Bash/Agent at 159999 vs 160000, sprint default STOP=160000) | stop context present at 160000 ("STOP threshold of 160000"), silent at 159999 — PASS |
| AC-2 | unit case | gate fixtures §G (used=165000, Agent vs Bash) | Agent exits 2 (deny); Bash exits 0 with stop context — PASS |
| AC-3 | unit case | gate fixtures §H (epic mode, no `active-epic`, no `stop=`, used=120000/149999/150000/200000, `tool_name=Agent`) | byte-identical to the golden pre-change output at every count — PASS |
| AC-4 | unit case | gate fixtures §K (invalid stop ordering: `stop<soft`, `stop>hard`) | exit 0, empty stdout, at any tested count — PASS |
| AC-5 | unit | `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/install-matcher-fixtures.sh` | exit 0, cases=9 failures=0 (empty matcher on the gate hook, `cancel-gate.sh` unchanged, two installs byte-identical) — PASS |
| AC-6 | doc grep | `grep -n "160" SKILL.md references/dev-story-{creator,planner,coder}.md` + `grep -n "active-epic" references/dev-story-planner.md` | matches in all four files; planner doc shows both a write (line 40) and a removal (line 178) — PASS |
| AC-7 | integration | `bash Skills/dev-story-flow/assets/tests/coder-stop-dry-run.sh` | exit 0, 4 passed, 0 failed (sprint.json committed, story `executing` with branch `detail`, claim intact) — PASS |

## Notes

- A real precedence bug was found by item 4's fixture run (not a story requirement gap): item 1's
  STOP-threshold addition widened the file-read guard so it also fired whenever `STOP` was
  unresolved, and then unconditionally overwrote env-resolved `SOFT`/`HARD` with file values —
  breaking the documented env-over-file "all-or-nothing" precedence for soft/hard (Specification
  §1). Fixed in one Sonnet follow-on item (`fix(context-budget): restore env-over-file precedence
  for soft/hard`, merged as `b3df35d`) before this validation ran. All 113 fixture cases pass with
  the fix in place, including the pre-existing "F: threshold resolution order" cases.
- Fixture line count in the story (282) was stale; the live file was 321 lines before this story's
  edits and item 4's executor re-read it live rather than trusting the story doc, as the plan's
  Risks section anticipated.
- Installed copy is stale until Jonathan re-runs `install.sh --user` — `~/.claude/hooks/
  context-budget-gate.sh` is a copy, not a symlink. All validation above ran the repo's own script
  directly, per the plan.
