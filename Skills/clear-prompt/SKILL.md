---
name: clear-prompt
description: Compose and post a "prep-for-clear" prompt — a single chat-posted, fenced block that lets a coding session hand off cleanly to a fresh context window without losing state. Use this whenever an orchestrating session (dev-story-sprint calls it via its rule 9 token-budget gate; dev-epic-workflow calls it right after filing an approved plan and linking the tracker, before anything is dispatched, to post the "epic filed" block Jonathan pastes to start the coding session; any other long-running orchestrator can call it too) has decided it needs to stop and move to a new chat — approaching its token budget, finishing a clean unit of work mid-story, or Jonathan asking to "clear", "prep for clear", "wrap this context", "move to a new window", or "what do I paste into the next session". This is NOT the on-disk /handoff used by dev-epic-workflow mid-epic (docs/epics/handoff.md, committed to the repo) — it produces a copy-paste resumption prompt Jonathan pastes straight into a fresh chat, and touches disk only for a token/context-budget-triggered stop, when it also writes the same block verbatim to a gitignored `.claude/signals/prep-for-clear-<session-slug>.md` so the Stop hook and the next session's start hook can find it; a Jonathan-requested clear touches nothing. Always reach for this instead of improvising an ad hoc summary — the Verified / Claimed-but-NOT-verified split is what makes the next session trustworthy instead of guessing.
---

# Clear Prompt

A small, single-purpose skill: given a session that has already decided it's time to stop, turn what's in that session's head into one complete, pasteable block, post it, and say nothing else. It owns the **template and the posting discipline** — not the decision to stop. The calling skill (or Jonathan, in an ad hoc session) decides *when*; this skill only handles *how*.

## Why this exists separately

`dev-story-sprint` used to carry its own copy of this template inline (rule 9 / "the token budget" section). Pulling it out means:

- Any orchestrator-style session — not just sprints — can hand off cleanly without re-inventing the format.
- The one place that defines "what counts as verified" doesn't drift between skills.
- `dev-story-sprint`'s SKILL.md stays about *sprint* rules (waves, executors, issues), not prompt formatting.

It is deliberately **not** the same mechanism as `/handoff`:

| | `clear-prompt` | `/handoff` |
|---|---|---|
| Medium | Posted in chat, one fenced block | Written to `docs/epics/handoff.md`, committed |
| Persists how | Jonathan pastes it into a new chat himself | Lives in the repo; next session's SessionStart hook auto-injects it |
| Owns | Any orchestrator that needs a resume prompt — `dev-story-sprint` mid-sprint, `dev-epic-workflow` right after filing, before anything is dispatched | `dev-epic-workflow` epics mid-flight, once items are already dispatched |
| Touches git/disk | Only on a budget-triggered stop — writes the block to a gitignored signal file, never commits | Yes — commits and pushes as part of checkpointing |

For `dev-epic-workflow`, which one to use is a distinction, not a refusal. **Mid-epic, with items already dispatched and in flight**, use `/handoff` — the epic folder exists and the next session needs the committed, hook-injected record. **End of intake, with a plan just filed and the tracker linked but nothing dispatched yet**, use `clear-prompt` — there's no in-flight dispatch state to checkpoint, only a fresh plan to hand into a coding session; see the "epic filed, nothing dispatched" shape below. For anything else — a sprint, an ad hoc coding session, or any orchestrator without an epic folder to write into — always use `clear-prompt`.

## When to call it

Not this skill's call to make. The caller has already found its stopping point (a wave boundary, a verified-but-not-yet-merged item, a token-budget threshold, or Jonathan simply saying "let's clear") *before* invoking `clear-prompt`. By the time this skill is loaded, the only remaining question is "what does the block say and how do I post it."

## Gather before writing

Pull these from the conversation and a few cheap, targeted git commands — never from memory of what you *think* happened:

- **Repo / branch state**: `git branch --show-current`, `git log --oneline -5`, `git status`, `git worktree list` if worktrees are in play.
- **What shipped**: items/steps actually merged, with the merge commit hash — check `git log`, don't recall it.
- **What's next**: the smallest next unit of work, with an explicit "done when" check and what's excluded.
- **Decisions made since the plan**: anything resolved in conversation that isn't in the original plan message.
- **Verified vs. claimed**: see below — this is the part worth getting right.
- **In flight**: unmerged pushed branches, still-running background executors, open worktrees, env vars or services set up this session that the next session needs to know exist.

### Verified vs. Claimed but NOT verified — the part that matters most

This is the single highest-value field in the whole prompt, because it tells the *next* session what to check first instead of what to trust. The discipline:

- **Verified** means you actually ran a command or read a file *this session* and saw the result — not that it "should be true" or "was true when dispatched." A branch that a subagent reported as `pushed` is verified only once you've fetched and looked at `origin/<branch>` yourself.
- **Claimed but NOT verified** is not a confession of failure — it's normal. Anything you believe but haven't rechecked against the repo belongs here: a subagent's self-report you haven't cold-verified, a gate you ran once but not after a later merge, an assumption baked into the plan that was never actually tested.
- When in doubt, put it in "claimed, not verified." A field in the wrong bucket costs the next session either false confidence (worst case: it builds on a merge that never landed) or a few seconds of redundant checking (harmless). The asymmetry means: bias toward "claimed."

## The template

Fill every line. Omit a line only when the caller's workflow genuinely has no such concept (e.g. no tracking issue) — say so explicitly (`Issue: none — no gh remote`) rather than deleting the line silently, so the next session knows it wasn't forgotten.

```
<caller> prep-for-clear — <work-slug>
Repo: <path or remote>   Live: <branch>   Integration: <branch, or "none"> @ <short-hash>
<Task line — the caller's own label: Story: / Task: / Goal:>: <one line, verbatim from the original plan>
Issue: #<n> (open)   ← or "none — <reason>"
Items:
  1. <branch> — DONE (merged <hash>)                                <model used>
  2. <branch> — DONE (merged <hash>)                                <model used>
  3. <branch> — NEXT: <scope>. Done when: <check>. Not: <exclusion>. <model to use>
  4. <branch> — <scope>  (depends on 3)                             <model to use>
Decisions made since the plan: <bullet list, or "none">
Verified: <facts actually checked against the repo this session, and how>
Claimed but NOT verified: <anything believed but unchecked — the next session checks these first>
In flight / environment: <unmerged pushed branches, running executors, open worktrees, env vars — or "none">
Exact next action: <one imperative sentence>
```

`<caller>` is the name of the invoking skill or workflow (`dev-story-sprint`, or whatever session context is handing off — e.g. a plain ad hoc session can use its own short description). `<work-slug>` matches whatever the caller already uses to name branches, status directories, or issues, so the next session can grep for it and land on the same state immediately.

The `Items:` block is written as a flat numbered list, not a table — it copy-pastes cleanly and survives being re-read as plain text by the next session. Keep each line to what fits in one line; if a scope needs more explanation than that, the plan itself was under-decomposed and that's worth a line under "Decisions," not a wrapped `Items` entry.

### The "epic filed, nothing dispatched" shape

`dev-epic-workflow` calls this skill from the filing step — after the plan is written and
the tracker issue is linked, before anything has been dispatched. The template above still
applies; this is the same shape, filled for that specific moment, with these differences:

- The Task line becomes `Epic: <path to plan.md>` rather than a verbatim outcome sentence —
  the plan file itself is what the next session needs to open, and the header's `<caller>`
  is `dev-epic-workflow`.
- Every line in `Items:` is `NEXT` (or blocked on an earlier item) — nothing is `DONE`,
  because filing happens before dispatch, not after it.
- `Verified` stays narrow and mechanical: the filing commit hash, and that the tracker issue
  is linked and labeled. `Claimed but NOT verified` carries forward anything the intake
  session asserted in the plan's Grounding section without checking it against the repo —
  that's what the next session checks first.
- `In flight / environment` is `none` — by definition, nothing has been dispatched yet.
- `Exact next action` is always: `This is a coding session. Dispatch item 1 per Phase 2–3.`
  That sentence is what a fresh session recognizes as a coding-session declaration (see
  `Skills/dev-epic-workflow/SKILL.md` Session mode).

One worked example, from this epic's own filing:

```
dev-epic-workflow prep-for-clear — intake-filing-emits-clear-prompt
Repo: claude-skills   Live: main   Integration: none @ d34139c
Epic: docs/epics/20-intake-filing-emits-clear-prompt/plan.md
Source: GH #94
Items:
  1. feat/intake-filing-emits-clear-prompt — NEXT: Phase 1's filing paragraph names clear-prompt as the last step, on all three surfaces. Done when: all three surfaces name clear-prompt at the filing step and agree on what the block replaces. Not: Phase 3.5, the SessionStart hook, executor text.
  2. feat/clear-prompt-epic-filed-shape — NEXT: add dev-epic-workflow as a second caller with the "epic filed" shape. Done when: the skill description and caller table name dev-epic-workflow, and the example block validates against the template fields. Not: the dev-story-sprint shape, the template's field set. (parallel with 1)
  3. test/clear-prompt-filing-drift-fixture — NEXT: grep-based fixture asserting all three filing surfaces and clear-prompt/SKILL.md carry the contract. Done when: passes on the merged tree, fails under a deliberate mutation. Not: hook behaviour, running any skill. (depends on 1 and 2)
Decisions made since the plan: no docs/epics/handoff.md written at filing; a stale draft-handoff is deleted in the filing commit instead
Verified: filing commit d34139c on main; GH #94 linked and labeled
Claimed but NOT verified: the hook fixture scripts run individually via `bash <file>`, with no aggregating runner to register item 3's fixture in — item 3 checks this first
In flight / environment: none
Exact next action: This is a coding session. Dispatch item 1 per Phase 2–3.
```

## Posting it

One line immediately before the block, naming the trigger honestly (a token count, a natural stopping point, or "Jonathan asked to clear") — for example:

> Orchestrator at ~152k — clean stopping point. Prep for clear — paste this into a fresh chat to continue:

Then the fenced block, complete, nothing abbreviated. Then **say nothing else** — no summary after it, no "let me know if you want changes." The block is a deliverable, not a conversation opener; anything after it just costs the very tokens the handoff exists to save.

**When the trigger is a token/context budget stop** (not Jonathan asking mid-work to "prep for clear," "clear," or similar — that path stops here, unchanged), two more actions follow the posted block, in the same turn:

1. Write the same block, verbatim, to `.claude/signals/prep-for-clear-<session-slug>.md` at the git top level. `<session-slug>` is derived exactly the way `context-budget-gate.sh`/`context-budget-lib.sh` derive it for their own `context-usage-<session-slug>` sentinel: `session_slug_for()` takes the session id and runs it through `tr -c 'A-Za-z0-9._-' '-'` then `cut -c1-64` — same input, same transform, same slug. This file is already covered by the repo's `.claude/signals/` gitignore rule, so it never touches a commit.
2. Call `mcp__ccd_session_mgmt__clear_session` with `session_id: "self"` when that tool is available in the current environment. When it isn't (a plain CLI session), say `/clear` on its own line instead — the same fallback `dev-story-flow`'s creator uses for its `run clean` path.

## Resuming from a posted prompt

When a fresh session receives a pasted `<caller> prep-for-clear` block, it treats the block as a plan that's already been made and approved — it does not re-derive or re-ask for one:

1. **Re-ground from the repo, not the block.** `git log`, `git status`, `git worktree list`, `git branch -r`, and a targeted grep for whatever "Claimed but NOT verified" names. The block is a lead, not a source of truth.
2. **Verify before building.** Anything in "Claimed but NOT verified" gets checked first. Anything in "In flight" gets re-checked — a background executor may have finished or died since the block was written.
3. **If the repo disagrees with the block, the repo wins.** Say so in one line and proceed from what's actually there.
4. **Don't re-post a plan message.** The pasted block *is* the plan — dispatch, continue, or resume work directly from it, reusing whatever issue/branch/slug it names rather than opening new ones.
5. **Start the token count at zero** and live under whatever budget rule the caller's own workflow specifies (e.g. dev-story-sprint's rule 9: 150k soft / 165k hard).

## Install

This skill is markdown — no scripts, hooks, or bundled agents — except for the single gitignored signal file it writes on a budget-triggered stop (see "Posting it"). To make it loadable by name, symlink it into the same pinned worktree the other orchestration skills use, so a `git switch` in the dev checkout never changes what Claude Code loads:

```bash
ln -s ~/Source/claude-skills-main/Skills/clear-prompt ~/.claude/skills/clear-prompt
```

Run once per machine, from a checkout where `~/Source/claude-skills-main` already exists as a worktree detached at `origin/main` (see `dev-story-sprint`'s Install section if it doesn't yet). No separate install script is needed — there's nothing here that needs merging into `settings.json` or registering as a hook.
