# Session Handoff — epic 10 (declared paths) / item 3 merged, item 2 open

**Written:** 2026-08-26T16:00:55Z
**Epic:** docs/epics/10-declared-paths
**Branch:** main (pushed: yes)
**Last commit:** a49f5c2 docs: record the 'dispatch as many as possible' prompt variant
**Worktree:** main checkout

## Verified this session
- Epic 10 items 2 (`feat/intake-declare-touched-paths`) and 3 (`feat/declared-paths-gate`) were dispatched in parallel, each returned `pr-opened` (PR #74, PR #72), both cold-verified OPEN/MERGEABLE via `gh pr view`.
- Ran a high-effort code review (8 finder angles + 1-vote verify, via the code-review skill) against both PRs. PR #74: 9 findings, 3 CONFIRMED-and-fixed (test-harness regex bug, dead code, stale comment), 6 skipped as lower-priority design/cleanup notes. PR #72: 10 findings, all CONFIRMED; 9 fixed (silent path-truncation on malformed Touches lines, git-diff stderr leaking into the path list, missing rename detection, `core.quotepath` non-ASCII mismatch, heading regex rejecting split item ids like "3a", undocumented exit-2 case, missing whitespace-trim in path comparison, a markdown line-wrap bug, truncated/mangled `-h` output); 1 deliberately left unfixed (see below).
- Both fix rounds were pushed and cold-verified independently (fixture suites re-run by me, not just trusted from the agents' self-reports): PR #74 fixture suite 21/21, PR #72 fixture suite 20/20.
- **PR #72 merged** — `gh pr merge 72 --merge`, merge commit `158be6b`, confirmed via `gh pr view` (`state: MERGED`) and `git log` on `main` after a fast-forward pull. Land-and-reset completed: remote+local branch deleted, `git fetch --prune` run, item 3's own control-plane state removed (`status/agent-ac240b829e13c302a.log`, `status/agent-a7ca2472a81bb3419.log` — no `status/feat-declared-paths-gate.json` ever existed under that name). ~59 other `agent-*.log` files remain in `docs/epics/10-declared-paths/status/` from this session's many ad-hoc review/verify agents (angle finders, verifiers, item 2's fix agent) — deliberately left for epic-close cleanup rather than hand-sorted individually; they're gitignored, harmless, no action needed until Phase 5.
- **Diagnosed and fixed a real deploy-drift issue, unrelated to epic 10, surfaced by a pasted transcript from a *different* repo (Oracle-Simple-Convert, epic 269).** `~/.claude/agents/work-item-executor.md` is installed by `install.sh` (copied, not symlinked) and had drifted one version behind this repo's source (dated Aug 24, missing the sharper "re-billed as input on every remaining turn" framing from the recent `test/subagent-output-discipline-drift` work). Re-ran `bash Skills/dev-epic-workflow/assets/claude-config/install.sh --user` twice this session — once mid-session to pick up `main`'s then-current copy, and again just now after PR #72's merge changed `work-item-executor.md` on `main` again. Confirmed identical via `diff` both times. This is machine-wide (`~/.claude/skills/dev-epic-workflow` is itself a symlink into this repo, so skill *content* never drifts — only the copied agent/hook files can, and only until `install.sh` is re-run).
- Confirmed Oracle-Simple-Convert has no repo-local skill or agent override (`.claude/` there has no `skills/` or `agents/` dir) — it was correctly running on the machine-level install the whole time; the install was just stale.

## Claimed but NOT yet verified
- **PR #74 is still open, unmerged.** Its 3 fixes are pushed (`682ef1d`) and its fixture suite passes, but nobody has reviewed/approved it on GitHub yet.
- Whether the sharper Communication-discipline wording (now correctly installed everywhere) actually reduces narration drift in a live dispatch is unproven — only provable by watching the next real executor run, not by reading files.
- Epic 10 item 4 ("Collision detection reads the field") depends on item 1 (done) **and** on epic 09 item 4 having landed — that dependency was never re-checked this session.

## In-flight (deliberately left as a known gap, not a bug)
- **One PR #72 finding was confirmed but intentionally NOT fixed**: the old PR-template line forced a manual "diff vs. **Scope:**" check on every PR; PR #72 replaces it with an automated check against the *optional* `**Touches:**` field, so any item without a Touches block (every pre-epic-10 item, and any future item that omits one) now gets zero scope-vs-diff verification, automated or manual. This is exactly what epic 10 item 3's own plan scope directs ("replacing the manual line at :62"), so fixing it for real means a scoped follow-up (e.g. a Scope-based fallback check when Touches is absent), not a fix folded into this PR. Flagged for Jonathan, not silently dropped.

## Exact next action
- Review and merge PR #74 (item 2) whenever ready — independent of everything else, no ordering requirement.
- After PR #74 merges: re-run `install.sh --user` again ONLY if that PR's diff touches `work-item-executor.md` (it currently doesn't — its 3 fixes are all in `intake-touches-fixtures.sh` and `unattended-intake.sh`), so likely no action needed there.
- Once epic 09 item 4's landed status is confirmed, dispatch epic 10 item 4.
- `.claude/signals/active-epic` still correctly points at `10-declared-paths` — leave it until epic close (Phase 5), not before.

## Environment state
- `.claude/signals/active-epic` = `10-declared-paths`.
- `~/.claude/agents/work-item-executor.md` is current (identical to this repo's `main` source) as of this session's second `install.sh` run.
- `git worktree list` shows only the main checkout — all fix/review worktrees from this session were cleaned up.
- No running services, no applied-but-unmerged migrations.

## Open questions for Jonathan
- Should the "optional Touches field replaces mandatory Scope check" gap (above) become its own follow-up work item inside epic 10, or ride along whenever item 4 is scoped?
- Any preference on how aggressively to hand-sort the ~59 leftover ad-hoc agent logs in `docs/epics/10-declared-paths/status/` before epic close, vs. just letting Phase 5's bulk `status/` directory removal take care of it?
- Carried forward, unanswered, from the 2026-08-22 handoff (epic 11) — still open: do you want L2 enabled once epic 11's live verifications pass; should the `- **Branch:** n/a` convention be filed as its own issue; re-measure epic 09 item 5 or close it on "not measured".
