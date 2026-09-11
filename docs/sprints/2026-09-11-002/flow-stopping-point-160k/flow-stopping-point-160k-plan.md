# flow-stopping-point-160k — execution plan

Sprint: 2026-09-11-002   Story: flow-stopping-point-160k   Kind: service

Grounded: `Skills/dev-epic-workflow/assets/claude-config/hooks/context-budget-gate.sh` (256
lines, read whole — tool-name guard at line 82, `agent_id` exemption 91-92, MODE block
159-177, threshold-resolution block 183-224, Decide block 225-256 = exit 2 at 256);
`hooks/tests/context-budget-gate-fixtures.sh` (321 lines, read whole); `settings-hooks.json`
(matcher `"Agent"` confirmed at line 50); `install.sh` (172 lines — `context-budget-gate.sh`
copy confirmed at line 65; merge logic is inline python3, keyed on command-set membership, not
on matcher text, so it needs no code change, only a new idempotency test); the installed
`~/.claude/settings.json` (confirmed matcher `"Agent|Task"` today); `Skills/dev-story-flow/
SKILL.md` (rule 10 at line 94); `references/dev-story-creator.md` (step 5 at line 130);
`references/dev-story-planner.md` (whole, incl. "Plan template" section used for this file);
`references/dev-story-coder.md` (whole — `active-epic` write at line 49, removal at line 163,
Budget section at line 186 running to EOF at 207); `Skills/dev-story-flow/assets/bin/
sprint-state.sh` (`story set <sprint> <slug> <status> [--detail][--plan][--force]` confirmed);
`Skills/dev-story-sprint/assets/tests/merge-settings-fixtures.sh` (sandbox-guard pattern: fresh
`mktemp -d`, `HOME`-realpath assertion before touching any settings.json).

Assumed: story's line citations for the threshold block (`182-216`) and decision table
(`225-256`) are off by a few lines against the actual file (`183-224` / `225-256`) — the
decision-table citation is exact, the threshold-block one is close enough that the described
edit region is unambiguous; no repo disagreement worth blocking on. One real disagreement: the
story states the fixture file is "282 lines" — it is 321. Recorded under Risks so the item 4
executor re-reads the live file rather than trusting the story's line count. No test file for
`install.sh`'s merge exists yet (AC-5) — planned as new, not a rename of `merge-settings-
fixtures.sh`, which belongs to a different script (`dev-story-sprint`'s `merge-settings.sh`)
and is only the *pattern* to copy, per the story's own wording ("is the model").

## Items
| # | Branch | Scope / Done when / Not | Files owned | Wave | Model | Gates |
|---|---|---|---|---|---|---|
| 1 | feat/flow-stopping-point-160k-gate | Add the `STOP` threshold (env `CONTEXT_BUDGET_STOP_TOKENS` → `.claude/context-budget` `stop=` → mode default 160000 sprint / disabled-equals-hard epic), extend validation to `soft<=stop<=hard`, and rewrite the decision block per the story's decision table (4 bands × tool-name split, non-`Agent` never denies, `agent_id` subagent exemption unchanged, tool-name guard widened from `''|Agent|Task` to "any name reaches the stop/hard rows, only `Agent\|Task` reaches soft"). Done when the script parses under `bash -n` and each new band's `additionalContext` text matches the story's wording. Not: touching the `agent_id`/session/sentinel-parsing code above line 159, not adding rate-limiting/caching (YAGNI per spec §1). | `Skills/dev-epic-workflow/assets/claude-config/hooks/context-budget-gate.sh` | 1 | Sonnet 5 | `bash -n Skills/dev-epic-workflow/assets/claude-config/hooks/context-budget-gate.sh` |
| 2 | feat/flow-stopping-point-160k-matcher | Widen the `context-budget-gate.sh` hook's matcher from `"Agent"` to `""` (empty = all tools) in `settings-hooks.json` line 50; leave `cancel-gate.sh`'s ungated (already matcher-less) group untouched. Done when the JSON is valid and only that one hook entry changed. Not: touching `install.sh`'s merge code (it already keys on command sets, not matcher text). | `Skills/dev-epic-workflow/assets/claude-config/settings-hooks.json` | 1 | Sonnet 5 | `python3 -c "import json;json.load(open('Skills/dev-epic-workflow/assets/claude-config/settings-hooks.json'))"` |
| 3 | feat/flow-stopping-point-160k-docs | Update all four phase docs per Specification §4: `SKILL.md` rule 10 → three sentences (150k/160k/165k) pointing at the per-phase procedure; `dev-story-creator.md` gains a "Stopping point at 160k" subsection (finish story in hand, set `ready-to-plan` or leave `drafting`, commit/push, hand off); `dev-story-planner.md` gains the same subsection (stop launching sub-agents, mark on-disk-planned stories `planned`, commit/push, `clear-prompt`) plus the two `active-epic` signal lines (write on `planning` claim, remove at `planned`) into its own process steps 1 and 6; `dev-story-coder.md` extends its existing "Budget" section (line 186) with the 160k stop procedure (stop waiting on executors, merge only verified items, `story set ... executing --detail "branch <b> pushed, not merged"` for the rest, commit/push, `clear-prompt`). Done when `grep -n "160"` finds a match in all four files. Not: renumbering existing rules/sections, editing `story.md` or `sprint.json`. | `Skills/dev-story-flow/SKILL.md`, `Skills/dev-story-flow/references/dev-story-creator.md`, `Skills/dev-story-flow/references/dev-story-planner.md`, `Skills/dev-story-flow/references/dev-story-coder.md` | 1 | Sonnet 5 | `grep -c "160" Skills/dev-story-flow/SKILL.md Skills/dev-story-flow/references/dev-story-{creator,planner,coder}.md` (each ≥ 1) |
| 4 | feat/flow-stopping-point-160k-gate-fixtures | Extend `context-budget-gate-fixtures.sh` with the cases in Specification §5 / AC-1..AC-4: sprint-mode stop default 160000; epic-mode stop absent = hard (no behaviour change, byte-identical golden-text case for AC-3); `stop=` from file and from env; invalid ordering (`stop<soft`, `stop>hard`) fails open; non-`Agent` at 159999 silent, at 160000 emits stop context exit 0; `Agent` at 160000 emits stop context exit 0; `Agent` at 165000 still denies (exit 2); non-`Agent` at 165000 allows with stop context; subagent (`agent_id` set) silent at any count for any tool. Depends on item 1's new bands existing. Done when the suite's own `FAILURES` counter is 0. Not: touching `sprint-state-fixtures.sh` (unrelated). | `Skills/dev-epic-workflow/assets/claude-config/hooks/tests/context-budget-gate-fixtures.sh` | 2 | Sonnet 5 | `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/context-budget-gate-fixtures.sh` |
| 5 | feat/flow-stopping-point-160k-integration-test | New integration test per AC-I: from a temp git repo, write `.claude/signals/active-epic` naming `.claude/stories/x` (sprint mode), write a `context-usage` sentinel, feed real PreToolUse JSON on stdin for `Bash`, `Read`, `Agent` at 159,999 / 160,000 / 165,000 tokens against the repo's own `context-budget-gate.sh`, assert exit codes and stdout/stderr per the decision table. Depends on item 1. Done when it exits 0 on a correct gate and would exit 1 against the pre-change script (self-check, not committed as a case). Not: reusing or modifying the fixtures file (item 4 owns it). | `Skills/dev-story-flow/assets/tests/stop-threshold-integration.sh` (new) | 2 | Sonnet 5 | `bash Skills/dev-story-flow/assets/tests/stop-threshold-integration.sh` |
| 6 | feat/flow-stopping-point-160k-install-test | New fixture harness for AC-5, modeled on `merge-settings-fixtures.sh`'s sandbox-guard pattern (fresh `mktemp -d` used as `HOME`, realpath-asserted never `$HOME/.claude` on the real machine): run `install.sh --user` twice against a temp `HOME` and assert the resulting `settings.json` has an empty matcher on the `context-budget-gate.sh` hook group and an unchanged matcher on `cancel-gate.sh`'s group, and that the second run produces a byte-identical file to the first (idempotent). Depends on item 2's matcher change existing in `settings-hooks.json` (the fixture's fixture, not the SUT). Done when the harness's own pass/fail counter is 0 failures. Not: touching `install.sh` itself — no source change was identified as necessary. | `Skills/dev-epic-workflow/assets/claude-config/hooks/tests/install-matcher-fixtures.sh` (new) | 2 | Sonnet 5 | `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/install-matcher-fixtures.sh` |
| 7 | feat/flow-stopping-point-160k-coder-dry-run | New script for AC-7: build a temp repo with `sprint-state.sh new`, put one story into `executing` with a fake pushed branch, run the exact commands `dev-story-coder.md`'s new 160k subsection specifies for one "running" story (`story set <sprint> <slug> executing --detail "branch <b> pushed, not merged"`, commit, push to a bare remote), then assert `sprint-state.sh get <sprint>` still reports `executing` with its claim intact and the story's `detail` field names the branch. Depends on item 3's doc wording (copies its exact command, not just the intent) — sequence after item 3 lands to avoid drift. Not: exercising `clear-prompt` itself (out of scope; the doc only calls the skill, it does not need to run here). | `Skills/dev-story-flow/assets/tests/coder-stop-dry-run.sh` (new) | 2 | Sonnet 5 | `bash Skills/dev-story-flow/assets/tests/coder-stop-dry-run.sh` |

## Validation — how the coder proves each acceptance criterion
| AC | Check | Command / browser steps | Pass when |
|---|---|---|---|
| AC-U | unit | `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/context-budget-gate-fixtures.sh && bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` | both exit 0 |
| AC-I | integration | `bash Skills/dev-story-flow/assets/tests/stop-threshold-integration.sh` | exit 0 |
| AC-1 | unit case | `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/context-budget-gate-fixtures.sh` (case: sprint sentinel `used_tokens=160000`/`tool_name=Bash` vs `159999`) | stdout contains "STOP threshold of 160000" at 160000, empty at 159999 |
| AC-2 | unit case | same suite (case: sentinel `165000`, `tool_name=Agent` then `Bash`) | `Agent` exits 2; `Bash` exits 0 with stop context |
| AC-3 | unit case | same suite (case: no `active-epic` signal, no `stop=`, `tool_name=Agent` at 120000/149999/150000/200000, diffed against a golden copy of the pre-change output) | byte-identical to the golden text at each count |
| AC-4 | unit case | same suite (case: `CONTEXT_BUDGET_STOP_TOKENS=100000`, sprint defaults) | exit 0, no stdout, at any tested count |
| AC-5 | unit | `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/install-matcher-fixtures.sh` | exit 0 (empty matcher on the gate hook, `cancel-gate.sh` unchanged, two runs byte-identical) |
| AC-6 | doc grep | `grep -n "160" Skills/dev-story-flow/SKILL.md Skills/dev-story-flow/references/dev-story-creator.md Skills/dev-story-flow/references/dev-story-planner.md Skills/dev-story-flow/references/dev-story-coder.md && grep -n "active-epic" Skills/dev-story-flow/references/dev-story-planner.md` | first grep matches in all four files; second shows both a write and a removal line |
| AC-7 | integration | `bash Skills/dev-story-flow/assets/tests/coder-stop-dry-run.sh` | exit 0 (sprint.json committed, story `executing` with branch `detail`, claim intact) |

## Order and dependencies
Wave 1 (items 1-3) touch disjoint files and have no dependency on each other — run
concurrently. Wave 2 (items 4-7) each depend on their wave-1 counterpart (4→1, 5→1, 6→2, 7→3)
but not on each other, and each owns a distinct new/existing file — run concurrently once wave
1 lands. No dependency on any other story in this sprint (story.md: "no").

## Risks and gotchas
- **Shared hook, epic mode must be bit-for-bit unchanged.** `context-budget-gate.sh` also
  serves dev-epic-workflow and dev-story-sprint; item 1's rewrite of the Decide block must
  keep epic-mode output byte-identical when `stop` is unset (AC-3 is the proof — item 4 must
  keep a golden copy of the pre-change text, taken from the CURRENT repo file before item 1
  edits it, not retyped from the story).
- **Fixture line count in the story is stale.** The story's spec says the fixtures file is 282
  lines; it is actually 321. Item 4's executor must re-read the live file rather than assume
  the story's count, and insert new cases using its own structure (helper functions already
  defined: `newproj`, `write_sentinel`, `path_for`).
- **Matcher widening runs the gate on every main-session tool call in every repo that has it
  installed** (dev-epic-workflow and dev-story-sprint too, once `install.sh --user` is
  re-run) — fails open on error, reads one small file, so the risk is latency/noise, not
  correctness; nothing in this plan needs to bound that further.
- **This machine's live hook is a copy, not a symlink.** `install.sh --user` must be re-run
  by Jonathan after merge for the matcher change to take effect in `~/.claude/hooks/`; item 5's
  and item 6's tests run the repo copy directly and do not depend on that re-run.
- **Do not preempt `auto-clear-prompt-at-stop`.** A sibling story in this same sprint will
  later extract the shared soft/stop/hard threshold-resolution code out of
  `context-budget-gate.sh` into a new `context-budget-lib.sh` and add a Stop hook. This plan
  keeps all threshold logic inline in the existing script (no new lib file, no refactor of the
  resolution block beyond adding the `stop` variable) so that extraction has a stable,
  unrefactored block to lift from — item 1 must resist the temptation to "clean up while
  in there."
- Kind is `service`; items 5 and 7 are this story's required integration tests (AC-I and the
  AC-7 dry-run) — both are new files, no existing integration test collides.

## Open questions
None — the story's own Open Questions (Q1-Q8) are all answered as assumptions and carried
into the items above (Q3 → item 3's exact per-phase text; Q8 → item 2/6, matcher widened for
all installs, ungated by flag).
