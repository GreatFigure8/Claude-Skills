---
title: dev-story-flow finds a stopping point at 160k tokens
slug: flow-stopping-point-160k
sprint: 2026-09-11-002
kind: service
created: 2026-09-11T17:27:49Z
---

# dev-story-flow finds a stopping point at 160k tokens

## Statement

> as a user, I want the skill dev-story-flow to find a stopping point when the token count
> gets to 160k in the current conversation

Restated: today the context-budget gate is a PreToolUse hook that only runs when the main
session tries to spawn an agent. It warns from 150k and denies the spawn from 165k. A
dev-story-flow orchestrator that is waiting on executors, running Bash, or reading files
makes no `Agent` calls, so nothing checks the count and the session can drift past 165k
before the next spawn attempt. The story adds a third, **stop** threshold at 160k that is
checked on every tool call in the main session, and gives each dev-story-flow phase a
concrete, per-phase stopping procedure it must follow when the count reaches it. The 150k
soft and 165k hard thresholds stay as they are.

## Requirements

- R1. When the current conversation's token count reaches 160k, dev-story-flow stops looking
  for new work and finds a stopping point (Jonathan's words: "find a stopping point when the
  token count gets to 160k in the current conversation").
- R2. The check must fire while the orchestrator is *not* spawning agents — waiting on
  executors, running Bash, editing files — because that is where the count currently drifts
  unobserved (assumption, Q2 below).
- R3. 160k is a new threshold between the existing 150k soft and 165k hard; neither existing
  number changes (assumption, Q1).
- R4. Each phase (CREATE, PLAN, EXECUTE) has a stated stopping procedure at 160k that leaves
  `sprint.json` committed and pushed and truthful, then hands off through `clear-prompt`
  (assumption, Q3).
- R5. Executors still running at the stop are left to finish and push; they are not
  cancelled. The next session picks up their branches from `sprint.json` (assumption, Q4).
- R6. Only dev-story-flow gains the 160k rule. dev-story-sprint keeps its existing prose
  guard; dev-epic-workflow's 120k/150k epic mode is unchanged (assumption, Q5).
- R7. The threshold is configurable the same three ways as soft/hard: env var, then
  `.claude/context-budget`, then the mode default (assumption, Q6).

## Specification

### 1. Gate script — third threshold `STOP`

File: `Skills/dev-epic-workflow/assets/claude-config/hooks/context-budget-gate.sh`
(installed user-level to `~/.claude/hooks/context-budget-gate.sh` by
`Skills/dev-epic-workflow/assets/claude-config/install.sh` line 65).

Threshold resolution, mirroring the existing `SOFT`/`HARD` block at lines 182-216:

| Source (first wins) | Soft | Stop (new) | Hard |
|---|---|---|---|
| env | `CONTEXT_BUDGET_SOFT_TOKENS` | `CONTEXT_BUDGET_STOP_TOKENS` | `CONTEXT_BUDGET_HARD_TOKENS` |
| `.claude/context-budget` | `soft=` | `stop=` | `hard=` |
| sprint-mode default | 150000 | **160000** | 165000 |
| epic-mode default | 120000 | *(= hard, i.e. disabled)* | 150000 |

Rules:
- `stop` is optional at every source. When absent it defaults to the resolved `hard`, which
  makes the stop band empty and preserves today's behaviour exactly. Epic mode therefore
  behaves as before unless someone sets `stop=` deliberately.
- Validation extends the existing `soft >= hard → fail open` rule to
  `soft <= stop <= hard`; anything else fails open (`exit 0`) as the script does today.
- Env override semantics stay all-or-nothing for soft/hard as today; `CONTEXT_BUDGET_STOP_TOKENS`
  alone is honoured on top of whichever soft/hard source resolved.

Decision table, replacing lines 225-256:

| Band | `Agent`/`Task` (dispatch) | Any other tool (main session only) |
|---|---|---|
| `USED < SOFT` | allow, silent | allow, silent |
| `SOFT <= USED < STOP` | allow + existing soft `additionalContext` | allow, silent |
| `STOP <= USED < HARD` | allow + **stop** `additionalContext` | allow + **stop** `additionalContext` |
| `USED >= HARD` | **deny** (`exit 2`, existing stderr text) | allow + **stop** `additionalContext` |

The stop text (one paragraph, same voice as the soft text):

> Context budget: this session is at ${MEASURE}, past the STOP threshold of ${STOP}
> (hard stop ${HARD}). Find a stopping point now, per ${RULE}: do not wait for running
> agents, do not start any new step. Make the on-disk state truthful (${STATE}), commit,
> push, then produce ${HANDOFF}. Everything already pushed is safe.

where in sprint mode `STATE` is "sprint.json, with every in-flight story's pushed branch in
its detail field" and `RULE`/`HANDOFF` are the existing sprint-mode strings. The
non-`Agent` path never denies: a stop must be able to run `git`, `sprint-state.sh`, and the
`clear-prompt` skill.

Tool-name handling: the guard at line 82 currently exits 0 for anything but `''|Agent|Task`.
It becomes: `Agent|Task` → full table; anything else → only the stop/hard rows emit context,
and only when `agent_id` is empty (the existing subagent exemption at lines 91-93 applies
first, so executors and planners never see the hook output).

Rate: the hook reads one small sentinel file per tool call. No caching is added (YAGNI); if
the fixtures show it matters, the planner may add an `epoch`-keyed "already warned within N
seconds" guard, but that is not required by this story.

### 2. Hook registration — fire on every main-session tool call

`Skills/dev-epic-workflow/assets/claude-config/settings-hooks.json` line 50 registers the
gate under matcher `Agent`; the installed `~/.claude/settings.json` uses `Agent|Task`. Both
change to an empty matcher (all tools) for this hook only. The other hooks in that block keep
their matchers. `install.sh`'s merge into `~/.claude/settings.json` must produce the new
matcher on re-run (verify the merge is idempotent; `dev-story-sprint`'s
`merge-settings-fixtures.sh` is the model).

### 3. Sprint mode during PLAN

`context-budget-gate.sh` picks sprint mode only when `.claude/signals/active-epic` names a
path under `.claude/stories/` (lines 158-170). The coder writes that signal at claim
(`references/dev-story-coder.md` line 49) and removes it at close (line 163); CREATE and PLAN
do not, so today PLAN runs under epic thresholds (120k/150k). The planner doc gains the same
two lines: write `.claude/stories/<sprint>` into the signal on `planning` claim, remove the
signal when the sprint is set `planned`. CREATE stays under epic mode (it is conversational
and short; the creator's 160k action below is prose only).

### 4. Phase docs — the stopping procedure

`Skills/dev-story-flow/SKILL.md` rule 10 becomes three sentences: 150k stop dispatching,
**160k find a stopping point**, 165k hard deny; and points at the per-phase procedure. Each
reference doc gains a "Stopping point at 160k" subsection:

- `references/dev-story-creator.md` — finish writing and committing the story in hand (do
  not start intake of another); if the sprint has ≥ 1 story, set it `ready-to-plan`, commit,
  push, and post the `run clean` hand-off (creator step 5, second variant); if it has none,
  leave it `drafting` and post the `create` line. Either way the session clears.
- `references/dev-story-planner.md` — stop launching planner sub-agents; wait for none; each
  story whose plan file already exists on disk is set `planned` at story level; the sprint
  stays `planning` with its claim (the next planner is the same `--by` id or a stale
  takeover); commit, push, `Skill({skill: "clear-prompt", args: "dev-story-flow plan
  <sprint>"})`.
- `references/dev-story-coder.md` — extend the existing "Budget" section (lines 186-195):
  at 160k stop waiting on executors; merge only items already verified against the
  integration branch; for every story with an executor still running or returned-but-not-
  verified, `story set <sprint> <slug> executing --detail "branch <b> pushed, not merged"`
  (or `validating` with the same detail); leave the sprint `executing` with its claim;
  commit, push, `Skill({skill: "clear-prompt", args: "dev-story-flow execute <sprint>"})`.
  Executors are not cancelled (R5). 165k is never spent finishing a merge — same sentence
  dev-story-sprint already carries at `SKILL.md` line 168.

The resumption path is unchanged: the same `/goal using dev-story-flow …` objective in a
fresh chat, which reclaims the sprint and reads `detail`.

### 5. Fixtures

`Skills/dev-epic-workflow/assets/claude-config/hooks/tests/context-budget-gate-fixtures.sh`
(282 lines, the only gate test) gains cases for: stop default 160000 in sprint mode; stop
absent → equals hard in epic mode (no behaviour change); `stop=` from file and env; invalid
ordering (`stop < soft`, `stop > hard`) fails open; non-Agent tool at 159,999 is silent; at
160,000 emits stop context and exits 0; Agent at 160,000 emits stop context and exits 0;
Agent at 165,000 still denies; non-Agent at 165,000 allows with stop context; subagent
(`agent_id` set) is silent at any count for any tool.

## Dependencies, risks, and breaking changes

- No dependency on other stories in this sprint. Sprint 2026-09-11-001 (executing) does not
  touch the gate, the hooks JSON, or the three phase docs (Jonathan: "no").
- **Shared hook.** The gate is one user-level script serving dev-epic-workflow,
  dev-story-sprint and dev-story-flow. Epic mode behaviour must be bit-for-bit unchanged;
  the fixture suite is the proof.
- **Matcher widening** means the hook runs on every main-session tool call in every repo
  where it is installed. It fails open on any error and reads one small file; the risk is
  latency, not correctness. The stop context is emitted on every call above 160k, which is
  intentional: the model should not be able to miss it.
- The `Agent|Task` deny at 165k is unchanged, so the hard floor dev-story-sprint relies on
  is preserved.
- Install path: this repo's symlinks load skills from `~/Source/claude-skills-main` on
  `main`, but the hook is a *copy* under `~/.claude/hooks/`. The change is live on this
  machine only after `install.sh --user` is re-run; the integration test below runs the repo
  copy directly and does not depend on the install.
- No new dependencies. bash + jq/python3 fallbacks as today.

## Acceptance criteria

- AC-U: unit tests pass —
  `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/context-budget-gate-fixtures.sh`
  exits 0 and `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` exits 0.
- AC-I: integration test exists at
  `Skills/dev-story-flow/assets/tests/stop-threshold-integration.sh` and exits 0. It runs
  the repo's `context-budget-gate.sh` end to end from a temp git repo: writes
  `.claude/signals/active-epic` naming `.claude/stories/x`, writes a `context-usage`
  sentinel, feeds real PreToolUse JSON on stdin for tool names `Bash`, `Read`, `Agent`, and
  asserts exit codes and stdout/stderr per the decision table at 159,999 / 160,000 /
  165,000 tokens.
- AC-1: with a fresh sprint-mode sentinel at `used_tokens=160000` and `tool_name=Bash`, the
  gate exits 0 and its stdout is a JSON object whose
  `hookSpecificOutput.additionalContext` contains "STOP threshold of 160000"; at
  `used_tokens=159999` stdout is empty.
- AC-2: with the same sentinel at 165000 and `tool_name=Agent`, the gate exits 2 (deny); with
  `tool_name=Bash` it exits 0 with the stop context.
- AC-3: with no `active-epic` signal (epic mode) and no `stop=` configured, the gate's
  output at 120000, 149999, 150000 and 200000 for `tool_name=Agent` is byte-identical to the
  pre-change script's output (the fixture keeps a golden copy of the old text).
- AC-4: `CONTEXT_BUDGET_STOP_TOKENS=100000` with sprint defaults (soft 150000) makes the
  gate fail open (exit 0, no stdout) at any count — invalid ordering is never enforced.
- AC-5: `settings-hooks.json` registers `context-budget-gate.sh` with an empty matcher, and
  `install.sh --user` against a temp `HOME` produces a `settings.json` where that hook's
  matcher is empty while `cancel-gate.sh`'s matcher is unchanged; running it twice yields the
  same file.
- AC-6: `grep -n "160" Skills/dev-story-flow/SKILL.md references/dev-story-creator.md
  references/dev-story-planner.md references/dev-story-coder.md` finds the stopping-point
  rule in all four files, and the planner doc contains both the `active-epic` write on claim
  and its removal at `planned`.
- AC-7: a dry-run of the coder stopping procedure — in a temp repo with a sprint in
  `executing`, running the doc's exact commands for one "running" story — leaves
  `sprint.json` committed with that story `executing` and a `detail` naming a branch, and
  `sprint-state.sh get` shows the sprint still `executing` with its claim intact.

## Out of scope

- Changing the 150k soft or 165k hard numbers, or dev-epic-workflow's 120k/150k.
- Cancelling running executors at the stop (they finish and push).
- Any change to `clear-prompt`'s template, `statusline.sh`, or how `used_tokens` is measured.
- A dev-story-sprint 160k hook band; its prose guard at `SKILL.md` line 168 stays as is.
- Rate-limiting the stop context (see Specification §1, last paragraph).

## Open questions

Jonathan answered the intake round with "no", read as "no amendments, write it". Every
proposal proceeds as an assumption:

- Q1. 160k is a third threshold between 150k and 165k, not a replacement for 150k.
- Q2. The check fires on every main-session tool call (empty matcher), subagents exempt.
- Q3. Per-phase stopping procedures are as written in Specification §4.
- Q4. Running executors are left to finish; not cancelled.
- Q5. Only dev-story-flow adopts the rule; sprint and epic siblings are untouched except that
  the shared script gains an optional, default-disabled `stop` band in epic mode.
- Q6. Threshold source order is env → `.claude/context-budget` → mode default, like soft/hard.
- Q7. Nothing in sprint 2026-09-11-001 touches these files ("no").
- Q8. Should the widened matcher be applied at install for *all* users of the hook, or gated
  behind a flag? Proceeding with: applied for all, because the non-Agent path never denies.
