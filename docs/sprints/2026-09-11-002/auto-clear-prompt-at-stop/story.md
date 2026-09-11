---
title: System runs clear-prompt at a token-limit stopping point
slug: auto-clear-prompt-at-stop
sprint: 2026-09-11-002
kind: service
created: 2026-09-11T17:40:00Z
---

# System runs clear-prompt at a token-limit stopping point

## Statement

> as a user, I would like the system to run the clear-prompt skill when reaching a stopping
> point due to token limits

Restated: today clear-prompt is invoked only because a skill's prose tells the orchestrator
to call it, and nothing checks that it did. A hook cannot call a skill, so "the system runs
it" is delivered in two halves: the budget gate's stop-band output names the exact
`Skill({skill: "clear-prompt", …})` call to make, and a new **Stop hook** refuses to let the
turn end while the session is past the stop threshold and no prep-for-clear block has been
posted. Once the block is posted, clear-prompt records it on disk and clears the session
itself, and the next session's start hook surfaces the block for pasting. This applies to
every orchestrator that shares the gate; in epic mode the hand-off artefact is
`docs/epics/handoff.md`, so the Stop hook checks for that file instead.

## Requirements

- R1. When a stopping point is reached because of the token limit, the clear-prompt skill
  runs (Jonathan's words: "run the clear-prompt skill when reaching a stopping point due to
  token limits").
- R2. Guarantee level is *enforce*, not just *instruct*: a Stop hook blocks the turn from
  ending, past the stop threshold, until the hand-off has been produced (Q1: yes).
- R3. After posting the block, the system clears the session itself, as the creator's `run
  clean` path already does (Q2: yes).
- R4. Scope is every orchestrator that shares `context-budget-gate.sh`: dev-story-flow,
  dev-story-sprint and dev-epic-workflow. In epic mode the hand-off is `handoff.md`, not
  clear-prompt (Q3: yes).
- R5. The Stop hook must not fight normal turns: it acts only when the sentinel is fresh and
  past the stop threshold, honours `stop_hook_active`, and blocks at most once per session
  (Q4: yes).
- R6. "The block was posted" is detected through a sentinel file written by clear-prompt,
  not by parsing the transcript (Q5: yes, the recommended option).
- R7. Lands after `flow-stopping-point-160k`; same script, same fixture suite (Q6: yes).

## Specification

### 1. Gate stop text names the literal call

`Skills/dev-epic-workflow/assets/claude-config/hooks/context-budget-gate.sh` — the stop
band text introduced by `flow-stopping-point-160k` ends with the exact call instead of the
generic `${HANDOFF}` phrase:

| Mode | Last sentence of the stop context |
|---|---|
| sprint | `Then call Skill({skill: "clear-prompt", args: "${CALLER} ${UNIT}"}) — it posts the hand-off and clears this session.` |
| epic | `Then write docs/epics/handoff.md per dev-epic-workflow's /handoff and commit it.` |

`${CALLER}` and `${UNIT}` come from `.claude/signals/active-epic`: the file already holds
`.claude/stories/<slug-or-sprint>`; `UNIT` is its last path segment. `CALLER` is
`dev-story-flow <phase>` when a `docs/sprints/<UNIT>/sprint.json` exists at the git top
level (phase = its `status`, mapped `planning→plan`, `executing→execute`), else
`dev-story-sprint`. When neither resolves, the sentence falls back to the current
`${HANDOFF}` wording. The hard-band stderr (deny) text gets the same last sentence.

### 2. clear-prompt writes a sentinel and clears the session

`Skills/clear-prompt/SKILL.md` gains a final step, run only when its args or the caller's
intro line name a token/context budget as the trigger (the skill already requires "one intro
line naming the trigger honestly"):

1. After posting the fenced block, write it verbatim to
   `.claude/signals/prep-for-clear-<session-slug>.md` at the git top level, where
   `<session-slug>` is the same derivation `context-budget-gate.sh` uses for its
   `context-usage-<session-slug>` sentinel (lines 96-107), so the Stop hook can match the
   two. The file is ignored by git (`.claude/signals/` already is; verify in `.gitignore`).
2. Call `mcp__ccd_session_mgmt__clear_session` with `session_id: "self"` when the tool is
   available. In a plain CLI say `/clear` in one line, as the creator doc already does.

The SKILL.md sentence "clear-prompt never touches disk or git" (line 3) and the Install note
"stateless markdown — no scripts" (line 135) are rewritten to describe the one file it now
writes and why. Not-budget triggers (Jonathan asking to "prep for clear" mid-work) keep the
old behaviour: post, nothing else.

### 3. Stop hook — `handoff-stop-gate.sh`

New file `Skills/dev-epic-workflow/assets/claude-config/hooks/handoff-stop-gate.sh`,
installed beside the gate by `install.sh`, registered in `settings-hooks.json` under a new
`Stop` event with no matcher. Same shell conventions as `context-budget-gate.sh`: jq, then
python3, then fail open; every error path `exit 0`.

Input (Stop hook stdin JSON): `session_id`, `transcript_path`, `stop_hook_active`.

Decision, in order — the first matching row wins:

| Condition | Result |
|---|---|
| `stop_hook_active` is true | allow, silent (loop guard) |
| `.claude/signals/handoff-stop-gate-<session-slug>` exists | allow, silent (blocked once already) |
| no fresh `context-usage-<session-slug>` sentinel (missing, unreadable, older than `CONTEXT_BUDGET_MAX_AGE_SECONDS`) | allow, silent |
| `USED < STOP` (thresholds resolved exactly as the gate does, shared via a sourced `context-budget-lib.sh` extracted from the gate) | allow, silent |
| sprint mode and `prep-for-clear-<session-slug>.md` exists | allow, silent |
| epic mode and `docs/epics/handoff.md` is newer than the sentinel's `epoch` | allow, silent |
| otherwise | **block**: write the `handoff-stop-gate-<session-slug>` marker, print `{"decision":"block","reason":"<text>"}` to stdout, `exit 0` |

The block reason is the same stop text as §1, prefixed `This turn may not end yet:`. Because
the marker is written on the first block, the second Stop for the same session always passes
— the model gets one forced retry, never a loop, even if it fails to post the block. The
marker is removed by `session-end-guard.sh` alongside its other per-session cleanup, and by
`session-start-context.sh` on `clear`.

Shared threshold code: the gate's mode detection (lines 158-170) and threshold resolution
(182-216) move into `context-budget-lib.sh`, sourced by both hooks. The gate's behaviour and
its fixture output must be unchanged by the extraction; `flow-stopping-point-160k`'s AC-3
golden-output fixture is the proof.

### 4. Surfacing the block after the clear

`session-start-context.sh` (SessionStart, matchers `startup|resume|clear|compact`): when
one or more `.claude/signals/prep-for-clear-*.md` files exist, print the newest one's content
under a heading `### Prep-for-clear from the previous session` and delete every one of them.
This is how the block survives R3's self-clear: the fresh session starts with the block in
front of Jonathan, and pasting it is one action. The creator's `run clean` line is unaffected.

### 5. Registration and install

- `settings-hooks.json`: add a `Stop` block with one command,
  `$CLAUDE_PROJECT_DIR/.claude/hooks/handoff-stop-gate.sh`.
- `install.sh` copies `handoff-stop-gate.sh` and `context-budget-lib.sh`; the `--user` merge
  into `~/.claude/settings.json` adds the Stop block idempotently.
- `Skills/dev-story-flow/SKILL.md` rule 10, `references/dev-story-coder.md` budget section,
  and `Skills/dev-story-sprint/SKILL.md` budget section each gain one sentence: the Stop hook
  will not let the turn end past the stop threshold until clear-prompt has posted, and
  clear-prompt clears the session itself.

### 6. Fixtures

- New `Skills/dev-epic-workflow/assets/claude-config/hooks/tests/handoff-stop-gate-fixtures.sh`
  covering every row of the §3 table, both modes, jq/python3/bare fallbacks, and the
  once-per-session marker.
- `context-budget-gate-fixtures.sh` gains the §1 last-sentence cases: sprint mode with a
  `docs/sprints/<UNIT>/sprint.json` in `executing` → `dev-story-flow execute <UNIT>`; sprint
  mode without one → `dev-story-sprint <UNIT>`; epic mode → the handoff.md sentence.
- `session-start-fixtures.sh` gains: two prep-for-clear files → newest printed, both deleted;
  none → nothing printed.

## Dependencies, risks, and breaking changes

- **Depends on `flow-stopping-point-160k`** (same sprint): the `STOP` threshold, the stop
  band, and the per-tool decision table. Must be planned and executed after it.
- **First Stop hook in the repo.** `session-end-guard.sh` line 5 records why one was avoided:
  "Stop fires on every turn end and would fight normal iterative flow / risk hook loops". The
  §3 table answers both: it is silent below the threshold, honours `stop_hook_active`, and
  blocks at most once per session. That sentence in `session-end-guard.sh` is updated to
  point at this hook rather than deleted.
- **Self-clear loses the visible block** unless §4 lands with it; the planner must keep §2
  step 2 and §4 in the same wave or order §4 first.
- **Shared hook, three orchestrators.** Epic mode is affected for the first time by a
  turn-end block. Its condition is narrow (past stop, fresh sentinel, no newer handoff.md)
  and the stop default in epic mode equals hard (150k), so epic sessions see the block only
  where today they would already be denied a dispatch.
- Extracting `context-budget-lib.sh` touches the gate's code paths; the golden-output fixture
  from story 1 guards against drift.
- `mcp__ccd_session_mgmt__clear_session` exists only in the desktop app; CLI sessions get the
  one-line `/clear` instruction instead, matching the creator doc.
- No new dependencies. `.claude/signals/` must be git-ignored; verify rather than assume.

## Acceptance criteria

- AC-U: unit tests pass —
  `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/context-budget-gate-fixtures.sh`,
  `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/handoff-stop-gate-fixtures.sh`,
  `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/session-start-fixtures.sh`
  (its 2 pre-existing failures noted in the handoff are not counted against this story;
  the new cases must pass) and
  `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` exit 0.
- AC-I: integration test exists at
  `Skills/dev-story-flow/assets/tests/handoff-stop-integration.sh` and exits 0. In a temp git
  repo with the hooks installed by `install.sh` it: writes a sprint-mode `active-epic` and a
  `context-usage` sentinel at 160000; runs `handoff-stop-gate.sh` with real Stop JSON and
  asserts a `block` decision whose reason contains `Skill({skill: "clear-prompt"`; writes
  `prep-for-clear-<slug>.md`; re-runs and asserts allow; then removes that file, re-runs and
  asserts allow again because the once-per-session marker exists; finally runs
  `session-start-context.sh` with `clear` and asserts the block content is printed and the
  file deleted.
- AC-1: sentinel at 160000, no prep-for-clear file, `stop_hook_active` false → stdout is
  `{"decision":"block","reason":…}` with the reason naming the exact Skill call and args
  `dev-story-flow execute <sprint>` when `docs/sprints/<sprint>/sprint.json` is `executing`.
- AC-2: any of: sentinel at 159999; sentinel older than `CONTEXT_BUDGET_MAX_AGE_SECONDS`;
  sentinel missing; `stop_hook_active` true; marker file present → exit 0 with empty stdout.
- AC-3: epic mode (no `active-epic`), sentinel at 150000, `docs/epics/handoff.md` absent →
  block with the handoff.md sentence; same with `handoff.md` mtime newer than the sentinel's
  `epoch` → allow.
- AC-4: the gate's stop context at 160000 in sprint mode ends with the literal
  `Skill({skill: "clear-prompt", args: "dev-story-sprint <UNIT>"})` when no sprint manifest
  matches `UNIT`, and with `dev-story-flow execute <UNIT>` when one does.
- AC-5: `install.sh --user` into a temp `HOME` twice yields an identical `settings.json`
  containing exactly one `Stop` hook entry for `handoff-stop-gate.sh`, and both new scripts
  under `hooks/`.
- AC-6: `Skills/clear-prompt/SKILL.md` documents the sentinel write and the self-clear for
  budget triggers, and no longer claims "never touches disk"; `grep -n "touches disk"` on it
  returns only the rewritten sentence.
- AC-7: `context-budget-gate-fixtures.sh`'s golden-output case from `flow-stopping-point-160k`
  still passes after `context-budget-lib.sh` is extracted.

## Out of scope

- Parsing the Claude Code transcript (`transcript_path`); detection is by sentinel only.
- Changing what the prep-for-clear block contains, or clear-prompt's non-budget behaviour.
- Blocking more than once per session, or any Stop-hook action below the stop threshold.
- Auto-pasting the block into the new session; Jonathan pastes it (one action) after the
  start hook prints it.
- Cancelling running executors (story 1 leaves them to finish).

## Open questions

Jonathan answered "yes to all, write it". Assumptions carried:

- Q2 read as: yes, clear the session itself after posting. If the intent was "stop at
  posting", delete §2 step 2 and §4 — the Stop hook and sentinel stand on their own.
- The once-per-session block (R5) means a model that ignores the forced retry ends its turn
  on the second attempt without a hand-off. Chosen over a hard loop because the alternative
  can wedge a session; the marker plus the next SessionStart warning is the safety net.
- `<session-slug>` derivation is reused from the gate; if the Stop hook input's `session_id`
  ever differs from the PreToolUse one, both hooks fall back to the unsuffixed sentinel name,
  as the gate already does.
- `.claude/signals/` is assumed git-ignored; the executor verifies and adds the rule if not.
