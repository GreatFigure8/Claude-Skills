# Session Handoff — epic 15 filed and approved, ready to dispatch

**Written:** 2026-08-27T11:52:00Z
**Epic:** docs/epics/15-plain-phrasing-communication-discipline
**Branch:** main (pushed: yes)
**Last commit:** 36b9b6c chore(epic-15): file and approve plan — plain-phrasing Communication discipline
**Worktree:** main checkout

## Verified this session
- Cleaned up three orphaned local `worktree-agent-*` branches (from earlier `isolation: "worktree"` dispatches whose worktrees were removed without deleting the branch) — confirmed each had zero commits ahead of `main` (`git log main..<branch>` empty) before deleting. Gone.
- Jonathan reported the subagent output-discipline fix (epics 12 and 13) still isn't holding on real dispatches — 4th occurrence. Root-caused live rather than guessed: read the actual transcript JSONL of this session's own epic-14 dispatch and confirmed 9 narration violations in exactly the shapes epic 13's "Forbidden phrasing" list already named as banned.
- Ran 6 diagnostic subagent dispatches to isolate the cause (full detail in `docs/epics/15-plain-phrasing-communication-discipline/plan.md` Grounding section): ruled out a Claude-Code-harness-level competing "give updates" instruction (a zero-instruction control stayed silent); ruled out `work-item-executor.md`'s file length/persona diluting the rule (the real agent type, full file, stayed silent on a scripted task); ruled out "enable extended thinking" as an available lever (it's already active — 13 thinking blocks recorded on the narrating epic-14 transcript, alongside the 9 narration blocks); found the trigger is specifically real judgment across a *long interleaved* trajectory (a single-shot judgment task stayed clean; the real 38-call dispatch didn't).
- Tested Jonathan's own dispatch-prompt phrasing style (short, direct, single "unless there's a blocker" exception) against the current legalistic instruction on a real interleaved judgment task (audit 3 closed epics' retros against their outcomes). The plain-phrasing run executed 6 real tool calls across 3 judgment cycles with zero narration — the first clean result anywhere in the investigation on genuinely judgment-heavy work. (Not a fair paired A/B — the control run was refused by the executor as an unauthorized override attempt, so there's no matched comparison; this is a real positive signal, not proof.)
- Filed epic 15 from that diagnosis, **already approved** by Jonathan in this session (he said "approve and run" before clearing) — replaces `work-item-executor.md`'s Communication discipline section with short plain phrasing (same three exceptions SKILL.md's canonical rule defines, no forbidden-phrasing bullet list, no violation narrative). Linked to source issue [GH #75](https://github.com/GreatFigure8/Claude-Skills/issues/75) (comment posted, labeled `epic:planned`). Committed and pushed (`36b9b6c`).

## Claimed but NOT yet verified
- None outstanding from this session — everything above was checked against a repo command or a live subagent transcript, not recalled.

## Exact next action
- **Dispatch epic 15 item 1** (`docs/epics/15-plain-phrasing-communication-discipline/plan.md`, single item, branch `docs/plain-phrasing-communication-discipline`, Sonnet 5, `isolation: "worktree"`). It is `approved` and this repo's only dispatchable work.
- **Before merging that item's PR, read its own dispatch transcript** for narration — the same way epic-14's failure was found — per the item's definition of done. If the executor building/opening its own PR still narrates, the item is genuinely done in terms of the doc edit but the *fix itself* is not verified; report that plainly rather than merging on "the text is present," which is exactly how epics 12 and 13 each looked done and weren't.
- If a different real work item becomes available first (e.g. from `/intake` on one of the open issues below), that dispatch can serve as the validation transcript instead — the definition of done just needs one real dispatch's transcript read before merge, not necessarily this item's own.

## Environment state
- None — no running services, no unmerged migrations, no env vars set this session. Local `main` is at `36b9b6c`, matching `origin/main`. No worktrees other than the main checkout (`git worktree list` clean).

## Open questions for Jonathan
- None blocking — epic 15 is approved and ready to dispatch on its own. (Carried forward, low priority, not blocking: the Agent-tool `isolation: "worktree"` branch-naming gap logged in epic 14's Deferred section — worth its own item only if it recurs.)
