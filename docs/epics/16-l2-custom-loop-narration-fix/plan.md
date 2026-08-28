# Epic: L2 custom executor loop — structural narration fix, opt-in for headless dispatch only

**Status:** in flight (item 2 of 4)
**Source:** GH #75 (continues epics 12, 13, 15 — three prompt-only fixes all recurred; this is the
structural-fix epic epic 15's closure pointed to)
**Live branch:** main   **Integration branch:** main   **Pre-epic tag:** n/a — additive, opt-in path
only; nothing existing changes behavior until explicitly wired in

## Outcome

work-item-executor, when dispatched through L2's headless path, runs on a hand-rolled loop against
the raw Anthropic Messages API instead of the `claude -p --agent` CLI harness — a loop that strips
the model's own intermediate text blocks from its message history before every subsequent turn, so
self-narration cannot re-enter its own context regardless of prompt instructions. This is opt-in and
additive: the interactive/orchestrated dispatch path (Task/Agent tool, full CLI hook telemetry) is
untouched. Success is measured the way epic 15's fix was falsified — inspecting a live run's raw
transcript for text blocks between tool calls, not self-report.

## Grounding

- Verified (`Skills/dev-epic-workflow/assets/claude-config/agents/work-item-executor.md:95-107`):
  current Communication discipline is plain-phrasing prose (post-epic-15/PR #81), no enumerated
  forbidden-phrase list.
- Verified (`docs/epics/handoff.md`, incident record): epic 15's fix failed independent verification
  — 7 narration text blocks found in a raw transcript JSONL despite the executor self-reporting
  none. Three consecutive prompt-only fixes (12, 13, 15) have now failed the same way.
- Verified (`executor-control-plane.md`, hook scripts under `assets/claude-config/hooks/`):
  `status.json` content and CANCEL/cancel sentinels are plain disk-file conventions any process can
  satisfy; `agent-<id>.log`, `agent_id`/`terminal` stamping, and CANCEL *enforcement* are 100%
  dependent on Claude Code CLI hook events (PreToolUse, PostToolUse, SubagentStart/Stop) firing.
- Verified (`dispatch.sh:1189`, `l2-dispatch.md:48,188`): L2 already invokes work-item-executor
  headlessly via `claude -p --agent work-item-executor --model sonnet <brief>` — not the interactive
  Task/Agent tool.
- **Confirmed live (item 1, PR #82, merged):** L2-shaped headless dispatch does NOT get functioning
  lifecycle/tool-call telemetry today. Two independent live runs of the exact `claude -p --agent
  work-item-executor --model sonnet --allowed-tools <L2's list>` invocation shape (one with the
  orchestrating session's env vars intact, one with the session-linking vars — `CLAUDE_CODE_CHILD_
  SESSION`, `CLAUDE_CODE_MESSAGING_SOCKET`, etc. — explicitly stripped) converged: neither run's own
  `status.json` ever received an `agent_id` or `terminal` field (hook-stamped only, never
  self-written); both correlate in time with an orphaned `agent-<id>.log` entry reading "SUBAGENT
  STOP ... no SubagentStart record for this agent; nothing stamped" — some hook activity fires in
  the vicinity but never establishes a start/owner record for a plain `claude -p --agent`
  invocation. Env-var stripping alone did not achieve confirmed process detachment (the child-session
  marker persisted regardless), so full detachment (a real cron/launchd/plain-terminal launch,
  outside any Claude Code process tree) was not achieved or tested — but both runs showed the same
  broken pattern regardless, which is itself evidence the break isn't about detachment specifically.
  **This means item 4's marginal telemetry cost is small: the cancel gate, tool logger, and
  lifecycle stamping are not functioning for this path today, so a custom loop replacing it loses
  little that currently works.** Full findings, raw command output: `item-1-hook-firing-findings.md`.
- Verified (public docs, via research agent): Claude Code hooks are CLI-lifecycle events; a raw
  Messages API loop or the Messages-API Tool Runner gets none of them. The Agent SDK's own
  tooling/permission/hook-equivalent capabilities are not clearly documented — a real gap, not
  resolved by this grounding pass.
- Verified (public docs + this repo's own stated rationale): narration leakage isn't the parent
  orchestrator's context being polluted — a subagent already returns only final text to its parent.
  The fix target is the executor's own turn-by-turn history, not the dispatch call.
- Tested live (Workflow tool, this session): a Workflow-spawned agent given a trivial 3-command task
  and told not to narrate produced zero intermediate text — but that's a single-tool-call task, not
  a real multi-turn stress case, so it's inconclusive on genuinely effortful work. Judged **not** a
  structural fix: same category as the three failed prompt-only attempts, just worded differently.

## Invariants

- The interactive/orchestrated dispatch path (Task/Agent tool, full hook telemetry) is never
  modified or removed by this epic.
- No repo behavior changes until the custom loop is explicitly wired into L2 dispatch — additive
  until the final item.
- Whatever tool surface the custom loop exposes to the model (Bash/Read/Edit/Write/Grep/Glob)
  matches work-item-executor's existing allowlist exactly — no silent capability expansion.

## Work items (draft — sizing may split further at review)

### 1. Verify L2 hook firing today

**Branch:** `chore/verify-l2-hook-firing`
**Touches:** `docs/epics/16-l2-custom-loop-narration-fix/item-1-hook-firing-findings.md`

A real, minimal `claude -p --agent work-item-executor` invocation, using the exact allowlist and
command-line shape `dispatch.sh` uses for L2, against a disposable/self-contained brief — to confirm
or refute whether Claude Code CLI hooks (cancel gate, tool logger, SubagentStart/Stop lifecycle
stamping) fire under this invocation shape. Blocks item 2 — it determines the rest of the epic's
actual marginal telemetry cost.

**Definition of done:** a findings file documenting, with file paths and observed content (not a
summary), whether `agent_id`/`terminal` were stamped into the run's `status.json` by a hook, and
whether an `agent-<id>.log` file was created under the epic's `status/` tree.

**Does not:** touch any other epic, modify `plan.md` beyond this filing, or attempt to fix anything
— this item only observes and reports.

### 2. Prove the text-stripping mechanism on a trivial scripted task

**Branch:** TBD at dispatch
**Touches:** a new throwaway script/directory, not wired into anything

A minimal raw-Messages-API (or Agent-SDK-based, pending resolving the SDK capability gap from
Grounding) loop running a throwaway 3-5 turn tool-use task, stripping assistant text blocks from
message history between turns, verified via raw transcript/log inspection to show zero narration
re-entering context across turns.

**Definition of done:** a live run's raw log shows tool_use blocks only between turns, with any text
block appearing solely in the final turn.

**Does not:** touch work-item-executor.md, dispatch.sh, or any real epic item execution.

### 3. Reimplement enough of work-item-executor's tool surface and lifecycle

**Branch:** TBD at dispatch
**Touches:** TBD — likely a new script/module under `assets/claude-config/`

Reimplement status.json writes and the branch/commit/PR flow on top of item 2's proven loop. The
big item; likely splits further once item 2's real complexity is known.

**Definition of done:** TBD — to be refined once item 2 lands and the real reimplementation surface
is known.

**Does not:** get wired into L2 dispatch yet (that's item 4).

### 4. Wire the custom loop into L2 as the executor invocation, opt-in and reversible

**Branch:** TBD at dispatch
**Touches:** `dispatch.sh` (or wherever L2's invocation point lives)

A config flag so L2 can fall back to the current `claude -p --agent` path instantly if the custom
loop misbehaves.

**Definition of done:** L2 can dispatch a real item through either path via one config toggle, with
the existing `claude -p --agent` path as the default until this epic's evidence says otherwise.

**Does not:** remove or deprecate the existing `claude -p --agent` invocation path.

## Sequence and dependencies

1 → 2 → 3 → 4, strictly. No parallelism — each item's real cost is unknown until the previous one
lands.

## Risk and rollback

- Item 1: read-only findings; worst case is a wasted headless run.
- Item 2: throwaway script, not wired into anything.
- Item 3: largest risk — a bug in reimplemented Bash/Edit/Write execution could corrupt repo state;
  runs only against a disposable worktree until item 4.
- Item 4: reversible by config flag.

## Deferred / out of scope

- Extending the custom loop to the interactive/orchestrated dispatch path — explicitly out of scope
  per the "opt-in, L2 only" decision; the orchestrated path's telemetry works today and isn't
  broken.
- Resolving the Agent SDK's undocumented capabilities in general — only as much as item 2/3 needs to
  decide raw-API vs. SDK-based loop.

## Open questions

- Item 3's real size is unknown until item 2 proves the mechanism — this may turn out to need its
  own follow-on epic rather than fitting as one item here.
