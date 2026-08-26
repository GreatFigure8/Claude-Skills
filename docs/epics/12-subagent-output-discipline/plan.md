# Epic: subagent output discipline on every spawn

**Source:** GH #68
**Status:** in flight (item 2 of 2)
**Live branch:** `main`   **Integration branch:** `main`   **Pre-epic tag:** n/a — documentation and one fixture; revert the merge commit

## Outcome
Every subagent this skill spawns — the `work-item-executor` and the ad-hoc ones (Phase 0 claim-verification, search sweeps, mechanical test runs) — carries the same output-discipline rule, stated once and pointed at from everywhere else. A subagent produces visible text only for a blocking question, a major issue, or its return summary, and the reason given is the true one: nobody reads the transcript, and every self-narrating line is re-billed as input on each remaining turn of that agent's context. A drift fixture fails if any surface loses the clause.

## Grounding
- Verified: `433a259` is a single-file, +19/−0 commit adding `## Communication discipline` to `assets/claude-config/agents/work-item-executor.md:95-112` (`git show --stat`). It is the only file in `assets/claude-config/agents/`. `SKILL.md:108` names the ad-hoc spawn types but only to impose the model table. `SKILL.md:100` lists what dispatch names — output discipline is not on it. `executor-control-plane.md:403-404` states the orchestrator does not accumulate executor transcripts. `dispatch.sh:642-644`, `:706-710` already tell the headless executor that `status.json`, not prose, is the runner's channel. No rule anywhere states the return value is the only thing read. Fixture harnesses live in `assets/claude-config/hooks/tests/`; `l2-dispatch-fixtures.sh` covers `dispatch.sh`.
- Assumed: that the ad-hoc spawns are frequent enough to matter in practice — file evidence that they are unguarded, not usage telemetry proving the cost. That the fixture harness can assert on a *skill* markdown file, not just shell scripts; the existing harnesses all target scripts, so item 2 may need a different assertion style than its neighbours.

## Invariants
- The signal channel is never narrowed. Blockers, questions, and anything the orchestrator needs still flow — this restricts narration only.
- `status.json` remains the progress channel; the status contract is untouched.
- The orchestrator's own model-table announcement (`SKILL.md:108`) is unaffected — that is the orchestrator reporting to Jonathan, not a subagent talking to itself.
- The three permitted exceptions stay exactly as `work-item-executor.md:103-109` defines them — a blocking question, a major issue, the completion return summary. No new exception, none removed; Jonathan confirmed the mid-run "major issue" exception stays, since a subagent must be able to flag anything it needs help with, not just wait for the return.

## Work items

### 1. One output-discipline rule, applied to every spawn — done, merged `14dd9f4`
- **Branch:** `docs/subagent-output-discipline-every-spawn`
- **Depends on:** none
- **Scope:** `Skills/dev-epic-workflow/SKILL.md` — add a named **Output discipline** block in Phase 3, stated once, scoped to *any* subagent the orchestrator spawns, and add the clause to the dispatch payload list at `:100` so an ad-hoc spawn with no agent file still receives it. `Skills/dev-epic-workflow/assets/claude-config/agents/work-item-executor.md:95-112` — keep the three exceptions verbatim, replace the readability rationale ("something Jonathan has to read past") with the cost one, drop the opening that frames the transcript as visible and readable, and mark it as the same canonical rule rather than a second statement of it.
- **Not in scope:** no change to the status contract, the cancel mechanism, the model-table rule, or `dispatch.sh` (its existing prose already points at `status.json`; restating the rule there is the duplication this item is trying to avoid).
- **Definition of done:** the rule appears in `SKILL.md` Phase 3 as a named block covering all spawn types; `SKILL.md:100`'s dispatch list includes it; `work-item-executor.md`'s section gives the cost rationale and no longer implies a reader.
- **Verification:** `grep -n "Output discipline" Skills/dev-epic-workflow/SKILL.md` returns the block; `grep -c "read past" Skills/dev-epic-workflow/assets/claude-config/agents/work-item-executor.md` returns 0; `git diff --stat main...HEAD` touches exactly those two files.
- **Rollback:** revert the merge commit.

### 2. Drift fixture for the discipline clause
- **Branch:** `test/subagent-output-discipline-drift`
- **Depends on:** item 1
- **Scope:** a fixture under `Skills/dev-epic-workflow/assets/claude-config/hooks/tests/` asserting that both surfaces from item 1 still carry the three-exception list and that `work-item-executor.md` does not reacquire a reader-facing rationale. Registered wherever the other harnesses are run.
- **Not in scope:** no refactor of the existing harnesses, no fix for the sandbox-escape defect in #15 or the 2/125 failure in #54 — both are pre-existing and get their own epics.
- **Definition of done:** the fixture passes on item 1's branch and fails when the clause is deleted from either file.
- **Verification:** run the fixture green; delete the clause locally and confirm it goes red; restore.
- **Rollback:** drop the branch.

## Sequence
1 → 2. Serial: the fixture asserts on text item 1 writes, so it cannot be authored against the current wording.

## Risks
| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| A silenced subagent swallows something Jonathan needed | Low | One work item runs blind | The three exceptions are preserved verbatim; `blocked` in `status.json` stays a terminal milestone with its `detail` field |
| The rule is restated in a third place later and drifts | Medium | Contradictory instructions to executors | Item 2 exists for exactly this; item 1 deliberately does not touch `dispatch.sh` |
| Fixture can't assert on markdown in the existing harness style | Medium | Item 2 needs a different shape than planned | Flagged in Grounding as an assumption; item 2 is small enough to re-scope without touching item 1 |

## Deferred / out of scope
- The ad-hoc spawns still have no persisted agent-definition file. Giving them one is a larger change than this issue needs — item 1 solves it by putting the clause in the dispatch payload instead.
- `dispatch.sh`'s headless brief keeps its existing prose unchanged.

## Log
- 2026-08-26 — filed from GH #68. Approved with the mid-run "major issue" exception kept.
- 2026-08-26 — item 1 merged (PR #69, merge commit `14dd9f4`). Verified cold against the diff: `grep -n "Output discipline" Skills/dev-epic-workflow/SKILL.md` matches, `grep -c "read past" .../work-item-executor.md` is 0, `git diff --stat` touched exactly the two claimed files. Branch/worktree removed; issue #68 checklist ticked.
