# auto-clear-prompt-at-stop — validation

Sprint: 2026-09-11-002   Validated against: `sprint/2026-09-11-002` @ `a524458`   UTC: 2026-09-11T19:10:30Z

| AC | Check | Command | Result |
|---|---|---|---|
| AC-U | unit | `bash .../hooks/tests/context-budget-gate-fixtures.sh` | exit 0, cases=119 failures=0 — PASS |
| AC-U | unit | `bash .../hooks/tests/handoff-stop-gate-fixtures.sh` | exit 0, cases=128 failures=0 — PASS |
| AC-U | unit | `bash .../hooks/tests/session-start-fixtures.sh` | exit 0, cases=151 failures=2 (the 2 pre-existing failures noted in the epic-21 handoff, unchanged; new cases from this story all pass) — PASS |
| AC-U | unit | `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` | exit 0, 46 passed, 0 failed — PASS |
| AC-I | integration | `bash Skills/dev-story-flow/assets/tests/handoff-stop-integration.sh` | exit 0, 14 passed, 0 failed — PASS |
| AC-1 | unit case | handoff-stop-gate fixtures (sentinel 160000, no prep-for-clear, `stop_hook_active` false, sprint manifest `executing`) | block, reason names `dev-story-flow execute <sprint>` — PASS |
| AC-2 | unit case | handoff-stop-gate fixtures (159999 / stale sentinel / missing sentinel / `stop_hook_active` true / marker present) | exit 0, empty stdout in every case — PASS |
| AC-3 | unit case | handoff-stop-gate fixtures (epic mode, sentinel 150000, no `handoff.md` → block with the handoff.md sentence; `handoff.md` newer than epoch → allow) | both — PASS |
| AC-4 | unit case | context-budget-gate fixtures §M (stop context at 160000 ends with the literal `Skill({skill: "clear-prompt", args: "dev-story-sprint <UNIT>"})` with no manifest, `dev-story-flow execute <UNIT>` with one) | both — PASS |
| AC-5 | install idempotence | the AC-5 command (double `install.sh --user` into a temp `HOME`, diff, assert exactly one `Stop` entry with no `matcher`, both new scripts executable/present) | exit 0 — PASS |
| AC-6 | doc grep | `grep -n "touches disk" Skills/clear-prompt/SKILL.md` → one rewritten line; `grep -c "never touches disk or git"` → 0; `clear-prompt-filing-fixtures.sh` | exit 0, cases=12 failures=0 — PASS |
| AC-7 | golden output | context-budget-gate fixtures §H (golden-output case from `flow-stopping-point-160k`, re-run after the lib extraction) | byte-identical, PASS — included in the AC-U 119/0 run above |
| AC-doc | doc grep | `grep -ln "Stop hook" SKILL.md dev-story-coder.md dev-story-sprint/SKILL.md \| wc -l` | `3` — PASS |

## Notes

- Item 1 (lib extraction, Opus 5) deviated from the dispatch's literal `dirname`-based path
  resolution: the fixture suite's `nojq`/`bare` sandboxed `PATH` omits `dirname`, so the
  executor used pure shell parameter expansion instead. Item 4's Stop hook copied the same
  builtin-only pattern. Both are load-bearing fixes, not scope creep — recorded here since
  they affect how a future item should resolve a script's own directory in this repo.
- `handoff_sentence()`'s epic-mode repo-root resolution falls back through `git rev-parse
  --path-format=absolute --git-common-dir` → `--show-toplevel` → `pwd`, each guarded; no
  regression observed in either fixture suite.
- Installed copies (`~/.claude/hooks/handoff-stop-gate.sh`, `context-budget-lib.sh`, and the
  `Stop` hook registration) are stale until Jonathan re-runs `install.sh --user` — all
  validation above ran the repo's own scripts (or a fully isolated temp-`HOME` install for
  AC-5/AC-I), per the plan.
