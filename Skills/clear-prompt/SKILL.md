---
name: clear-prompt
description: Compose and post a "prep-for-clear" prompt — a single chat-posted, fenced block that lets a coding session hand off cleanly to a fresh context window without losing state. Use this whenever an orchestrating session (any long-running orchestrator can call it) has decided it needs to stop and move to a new chat — approaching its token budget, finishing a clean unit of work mid-story, or Jonathan asking to "clear", "prep for clear", "wrap this context", "move to a new window", or "what do I paste into the next session". This is NOT the on-disk /handoff (docs/epics/handoff.md, committed to the repo) — it produces a copy-paste resumption prompt Jonathan pastes straight into a fresh chat, and touches disk only for a token/context-budget-triggered stop, when it also writes the same block verbatim to a gitignored `.claude/signals/prep-for-clear-SESSION-SLUG.md` so the Stop hook and the next session's start hook can find it; a Jonathan-requested clear touches nothing. Always reach for this instead of improvising an ad hoc summary — the Verified / Claimed-but-NOT-verified split is what makes the next session trustworthy instead of guessing.
---

# Clear Prompt

A small, single-purpose skill: given a session that has already decided it's time to stop, turn what's in that session's head into one complete, pasteable block, post it, and say nothing else. It owns the **template and the posting discipline** — not the decision to stop. The calling skill (or Jonathan, in an ad hoc session) decides *when*; this skill only handles *how*.

## Why this exists separately

- Any orchestrator-style session can hand off cleanly without re-inventing the format.
- The one place that defines "what counts as verified" doesn't drift between skills.

It is deliberately **not** the same mechanism as `/handoff`:

| | `clear-prompt` | `/handoff` |
|---|---|---|
| Medium | Posted in chat, one fenced block | Written to `docs/epics/handoff.md`, committed |
| Persists how | Jonathan pastes it into a new chat himself | Lives in the repo; next session's SessionStart hook auto-injects it |
| Owns | Any orchestrator that needs a resume prompt | Epics mid-flight, once items are already dispatched |
| Touches git/disk | Only on a budget-triggered stop — writes the block to a gitignored signal file, never commits | Yes — commits and pushes as part of checkpointing |

Mid-epic, with items already dispatched and in flight, use `/handoff` — the epic folder exists and the next session needs the committed, hook-injected record. For anything else — a sprint, an ad hoc coding session, or any orchestrator without an epic folder to write into — use `clear-prompt`.

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

`<caller>` is the name of the invoking skill or workflow (the invoking skill, or whatever session context is handing off — e.g. a plain ad hoc session can use its own short description). `<work-slug>` matches whatever the caller already uses to name branches, status directories, or issues, so the next session can grep for it and land on the same state immediately.

The `Items:` block is written as a flat numbered list, not a table — it copy-pastes cleanly and survives being re-read as plain text by the next session. Keep each line to what fits in one line; if a scope needs more explanation than that, the plan itself was under-decomposed and that's worth a line under "Decisions," not a wrapped `Items` entry.

Then the fenced block, complete, nothing abbreviated. Then **say nothing else** — no summary after it, no "let me know if you want changes." The block is a deliverable, not a conversation opener; anything after it just costs the very tokens the handoff exists to save.

**When the trigger is a token/context budget stop** (not Jonathan asking mid-work to "prep for clear," "clear," or similar — that path stops here, unchanged), two more actions follow the posted block, in the same turn:

1. Write the same block, verbatim, to `.claude/signals/prep-for-clear-<session-slug>.md` at the git top level. `<session-slug>` is derived exactly the way `context-budget-gate.sh`/`context-budget-lib.sh` derive it for their own `context-usage-<session-slug>` sentinel: `session_slug_for()` takes the session id and runs it through `tr -c 'A-Za-z0-9._-' '-'` then `cut -c1-64` — same input, same transform, same slug. This file is already covered by the repo's `.claude/signals/` gitignore rule, so it never touches a commit.
2. Call `mcp__ccd_session_mgmt__clear_session` with `session_id: "self"` when that tool is available in the current environment. When it isn't (a plain CLI session), say `/clear` on its own line instead.

## Resuming from a posted prompt

When a fresh session receives a pasted `<caller> prep-for-clear` block, it treats the block as a plan that's already been made and approved — it does not re-derive or re-ask for one:

1. **Re-ground from the repo, not the block.** `git log`, `git status`, `git worktree list`, `git branch -r`, and a targeted grep for whatever "Claimed but NOT verified" names. The block is a lead, not a source of truth.
2. **Verify before building.** Anything in "Claimed but NOT verified" gets checked first. Anything in "In flight" gets re-checked — a background executor may have finished or died since the block was written.
3. **If the repo disagrees with the block, the repo wins.** Say so in one line and proceed from what's actually there.
4. **Don't re-post a plan message.** The pasted block *is* the plan — dispatch, continue, or resume work directly from it, reusing whatever issue/branch/slug it names rather than opening new ones.
5. **Start the token count at zero** and live under whatever budget rule the caller's own workflow specifies (e.g. a token-budget gate).

## Install

Installed as the `clear-prompt@claude-skills` plugin from this repo's marketplace (`claude plugin install clear-prompt@claude-skills`); no symlink. Markdown only — nothing to merge into `settings.json` or register as a hook.
