# Session Handoff — epic 15 closed (superseded); next: file structural-fix epic

**Written:** 2026-08-27 (see git log for real timestamp)
**Epic:** none in flight — epic 15 closed this session; the replacement epic has not been filed yet
**Branch:** main (pushed: yes)
**Last commit:** (this handoff commit)
**Worktree:** main checkout only — clean. Epic 15's item worktree, branch, and `status/` directory
were all removed at land-and-reset after PR #81 merged (below).

## Claimed but NOT yet verified
- None outstanding — everything below is either a direct doc citation (URLs given) or a repo
  state change made and confirmed in this session.

## What happened this session
1. Dispatched epic 15 item 1 (replace `work-item-executor.md`'s legalistic Communication
   discipline section with plain phrasing). Executor landed clean gates and opened **PR #81**,
   self-reporting no narration.
2. Per the item's own definition of done, independently verified that self-report against the
   raw transcript JSONL (not trusted) — **it failed**: 7 narration text blocks between tool
   calls, the same pattern epic 13 already tried to ban by name. Third consecutive wording-only
   attempt (epics 12, 13, 15) that read as fixed and wasn't. Did not merge PR #81; recorded the
   finding in epic 15's plan Log and reported it to Jonathan as a blocker.
3. Jonathan's decision: **pivot to a structural fix** — strip narration text blocks
   programmatically instead of instructing the model not to produce them.
4. Before drafting a plan, researched feasibility live against real docs (two research passes;
   the first returned zero tool calls and was discarded as a guess, redispatched with an explicit
   requirement to fetch real pages). **Finding, confirmed against source:**
   - Claude Code's Hooks Reference (https://code.claude.com/docs/en/hooks) and the Claude Agent
     SDK Hooks docs (https://code.claude.com/docs/en/agent-sdk/hooks) — neither exposes
     block-level interception of assistant message content.
   - The only hook that touches assistant text at all, `MessageDisplay`, is explicitly
     display-only/read-only.
   - Every other hook (`PreToolUse`, `PostToolUse`, `Stop`, `SubagentStart`/`SubagentStop`,
     `PreCompact`, `UserPromptSubmit`, etc.) fires around tool calls or session boundaries, never
     on message content — confirmed against this repo's own existing hooks too
     (`subagent-tool-logger.sh` only ever sees `PostToolUse` payloads keyed on `tool_name`/
     `tool_input`, never freestanding text).
   - **The only way to actually strip a `text` content block before it re-enters a subagent's own
     context is to bypass the Task/Agent tool's built-in dispatch loop entirely and drive the raw
     Anthropic Messages API in a custom loop** — owning the conversation array directly, filtering
     `type: "text"` blocks out of each assistant turn before appending it to history and sending
     the next request.
5. Presented that trade-off (this is a bespoke executor harness — tool execution, permissions,
   context management all reimplemented — not a prompt edit) to Jonathan via AskUserQuestion.
   **He chose to build it, explicitly starting next session**, not this one ("we're going to do 1
   after a clear").
6. Closed epic 15 as superseded (`docs/epics/15-plain-phrasing-communication-discipline/plan.md`,
   Status now `closed (superseded)`, full retro in the Log). GH #75 (the underlying narration
   issue) was deliberately left open and its label (`epic:in-progress`) left untouched — the next
   session's epic filing is what should move it, not a guess made here. Removed
   `.claude/signals/active-epic` since no epic is in flight now.
7. Jonathan called it: merge PR #81 anyway — "it's harmless." Merged (`3513c74`), pulled main,
   deleted the item branch and worktree remotely and locally, `git fetch --prune`, removed
   `docs/epics/15-plain-phrasing-communication-discipline/status/`. `git worktree list` shows
   only the main checkout. The plain-phrasing text is live in
   `Skills/dev-epic-workflow/assets/claude-config/agents/work-item-executor.md` now — it's a
   fine instruction on its own terms, just not sufficient by itself (per the epic's own
   validation failure), which is exactly why the structural fix is still the next epic.

## Exact next action
**File a new epic** (Phase 0 → Phase 1 of dev-epic-workflow) for a custom Messages-API-driven
executor loop that replaces the Task/Agent tool's dispatch for `work-item-executor` runs, filtering
narration `text` blocks out of the conversation before each subsequent turn. Ground it properly
before drafting — this is a materially different engineering shape than anything this repo has
built so far (a hosting loop around the raw Anthropic Messages API, not a Claude Code
config/prompt/hook change), so Phase 0 should cover at minimum:
- What the Task/Agent tool currently gives `work-item-executor` for free that a custom loop would
  have to reimplement or explicitly forgo: tool registration/execution, permission prompts,
  context/compaction handling, the existing hooks this repo already relies on (cancel gate,
  subagent lifecycle telemetry, tool logger) — do those hooks even fire for a custom-loop-driven
  agent, or does this approach silently lose the whole control-plane telemetry system Phase 2/3
  currently depend on?
- Where this loop would actually run from — a script invoked by the orchestrator (Bash), a
  separate long-running process, or something inside this repo's existing `assets/claude-config/`
  tooling — and whether `Workflow`/the SDK's scripting surface is a better fit than a fully
  hand-rolled loop.
- Scope it small for a first item: prove the text-block-stripping mechanism works end to end on a
  trivial scripted task before trying to replicate `work-item-executor`'s full lifecycle on top
  of it.

**Open questions for Jonathan, to resolve at or before filing:**
- Does the custom loop fully replace `work-item-executor` dispatch, or run alongside it as an
  opt-in path — given the control-plane/telemetry dependency question above, a full replacement
  may be a much bigger lift than Jonathan intends.
