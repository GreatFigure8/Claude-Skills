# Epic: name the Agent-tool worktree-isolation mechanism in Phase 2/3

**Status:** in flight (item 1 of 1)
**Live branch:** main
**Integration branch:** main
**Pre-epic tag:** n/a
**Source:** GH #79

## Outcome
SKILL.md's Phase 2 worktree paragraph and Phase 3 dispatch-setup step (line 89, line 117) both state explicitly that when the orchestrator is Claude Code dispatching through the `Agent` tool, passing `isolation: "worktree"` on that call is how Phase 2's isolation requirement is satisfied — as the Agent-tool-native equivalent of the manual `git worktree add ../<repo>-<branch-slug> -b <branch> <integration>` command, not a separate or optional step.

## Grounding
- Verified: `Skills/dev-epic-workflow/SKILL.md` lines 89 and 117 are the only two Phase 2/3 passages describing worktree creation, and both give only the raw shell `git worktree add` command — neither names the `Agent` tool's `isolation: "worktree"` parameter.
- Verified live in this session (epic 13, 2026-08-27): dispatching a `work-item-executor` via the `Agent` tool with no `isolation` parameter caused the executor's `git switch -c <branch>` (work-item-executor.md lifecycle step 2) to run in the orchestrator's shared main checkout — confirmed via `git reflog` showing `HEAD` move from `main` to the item branch with no preceding `git worktree add`. No damage that run (no concurrent orchestrator writes to `main`), but it is the exact hazard the same SKILL.md paragraph cites from epic 01 / GH #3.
- Verified: no drift fixture currently guards SKILL.md's worktree prose (fixtures under `assets/claude-config/hooks/tests/` test worktree *provisioning scripts* and *executor behavior*, not this specific sentence) — this is a prose-only gap, not a logic bug.
- Assumed: work-item-executor.md's own lifecycle step 2 ("If you were dispatched into a worktree, the worktree already has the branch — verify, don't re-create") is already correct and needs no change — the gap is entirely on the orchestrator-facing side of the doc, not the executor's.

## Invariants
- No change to `work-item-executor.md` — its lifecycle already handles both the worktree and non-worktree case correctly.
- No change to the underlying requirement (every dispatch gets an isolated worktree) — this only names the mechanism a Claude Code orchestrator already has available to satisfy it.

## Work items

### 1. Name the Agent-tool isolation mechanism in SKILL.md Phase 2 and Phase 3
- **Branch:** `docs/name-agent-tool-worktree-isolation`
- **Depends on:** none
- **Scope:** in `Skills/dev-epic-workflow/SKILL.md`, add one clarifying sentence to the Phase 2 worktree paragraph (line 89) and the Phase 3 dispatch-setup step (line 117) stating that when the orchestrator is Claude Code itself, dispatching through the `Agent` tool, passing `isolation: "worktree"` on that call is the concrete mechanism that satisfies this requirement — equivalent to, and preferred over, running `git worktree add` by hand from the orchestrator session. Keep both edits to 1–2 sentences each; no restructuring of the surrounding paragraphs.
- **Touches:**
  - `Skills/dev-epic-workflow/SKILL.md`
- **Not in scope:** no change to `work-item-executor.md`; no new drift fixture (this is prose guidance for a human/orchestrator reading the skill, not a machine-checked contract — same category as other unfixtured SKILL.md prose); no change to `references/executor-control-plane.md` or `references/worktree-provisioning.md` (those describe the worktree's *contents* and lifecycle once created, not how the orchestrator creates it).
- **Definition of done:** both passages name the `isolation: "worktree"` Agent-tool parameter explicitly, in language a fresh orchestrator session would act on without having to infer it from the Agent tool's own schema description.
- **Verification:** `grep -n 'isolation.*worktree' Skills/dev-epic-workflow/SKILL.md` returns matches at both the Phase 2 and Phase 3 locations; read the surrounding paragraphs to confirm the sentence reads naturally and doesn't contradict the manual-command guidance (the manual command stays as the underlying mechanism description, for direct-mode/non-Claude-Code orchestrators).
- **Rollback:** revert the merge commit.

## Sequence
Single item.

## Risks
| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| Wording implies `isolation: "worktree"` is the *only* valid mechanism, confusing a non-Claude-Code orchestrator (direct mode, a hand-rolled dispatch script) | Low | Low (doc clarity only) | Keep the manual `git worktree add` command as the primary/underlying description; frame the Agent-tool parameter as "the concrete way to do this when dispatching via the Agent tool," not a replacement for the concept |

## Deferred / out of scope
- A drift fixture asserting the Agent tool call always includes `isolation: "worktree"` would need to inspect orchestrator behavior at dispatch time, not static file content — out of scope for this doc-only fix; the existing `output-discipline-drift-fixtures.sh` pattern doesn't transfer directly since there's no single "canonical statement" file to diff against, unlike the narration rule.

## Log
- 2026-08-27 — epic filed from GH #79, root-caused during epic 13's close (executor ran outside an isolated worktree; no damage, caught via `git reflog`).
