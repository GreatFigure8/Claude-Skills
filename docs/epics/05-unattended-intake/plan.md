# Epic: unattended intake (Tier 2)

**Status:** in flight (item 1 of 2)
**Source:** GH #16
**Live branch:** main   **Integration branch:** main   **Pre-epic tag:** n/a
**Depends on:** epic 04 merged (its session-start surface is extended here)

## Outcome
An issue labelled `claude-intake` produces a reviewed, filed epic plan without anyone
present. CI runs Phase 0 grounding and Phase 1 drafting headlessly and opens a **pull
request** carrying the plan at `Status: planning`. Nothing is approved, nothing is
dispatched, no code is written. Jonathan reviews the PR the way he reviews any PR; merging
it plus setting `Status: approved` is the approval gate, unchanged and still human.

## Grounding
- **Verified:** the repo has **no CI whatsoever** — no `.github/` directory at all. This is
  net-new infrastructure, not a modification.
- **Verified:** `claude` 2.1.220 is on this machine at `~/.local/bin/claude`, so headless
  `claude -p` is feasible; CI installs its own copy.
- **Verified:** `gh` auth carries the `workflow` scope, so workflow files can be created.
- **Verified (the tension this epic must resolve):** `SKILL.md:50` says "stop and get explicit
  approval before touching code", and `:52` says "**On approval**, file the plan". Filing is
  post-approval by definition. An unattended run has no approver, so "stops at plan-filed"
  cannot mean the current filing ritual. Resolved below by filing at `Status: planning` on a
  branch, via PR — a *proposal*, not a filed epic.
- **Verified:** `/intake`'s command definition already declares a restricted `allowed-tools`
  list (`Bash(git:*)`, `Bash(gh:*)`, `Bash(az:*)`, `Bash(ls:*)`, `Bash(find:*)`,
  `Bash(date:*)`, Read, Write, Edit, Glob, Grep) — a usable starting allowlist for headless.
- **Verified:** no headless/unattended language exists anywhere in the skill yet.
- **Verified (interaction with epic 04, in flight):** epic 04 item 2 lists epics whose Status
  is neither `closed` nor `in flight` as "awaiting dispatch". A `planning` plan produced here
  would be mislabelled — it awaits **approval**, not dispatch. Item 1 below corrects the
  wording rather than changing epic 04 mid-flight.
- **Assumed:** `main` has no branch protection (unverified). The design opens PRs regardless,
  so protection changes nothing; it only affects whether protection *enforces* it.
- **Assumed:** Jonathan will create the CI credential. Claude cannot create repository
  secrets, and must not handle the token value.

## Invariants
- **The approval gate never moves.** No unattended run approves a plan, dispatches an
  executor, writes code, merges anything, or closes an issue.
- CI never pushes to `main`. Its only write is a branch plus a PR.
- **No `--dangerously-skip-permissions`, ever** — headless runs use an explicit tool
  allowlist. (Standing rule in Jonathan's global CLAUDE.md.)
- Opt-in only: absent the `claude-intake` label, nothing runs.
- A failed or partial run leaves no half-filed epic on `main` — the branch/PR is the unit.
- The existing interactive `/intake` path is unchanged.

## Work items

### 1. The unattended-intake contract, written into the skill
- **Branch:** `docs/unattended-intake-contract`
- **Depends on:** none
- **Scope:** `references/issue-intake.md` — a section defining unattended intake: trigger
  (`claude-intake` label), what it does (Phase 0 + Phase 1 draft), what it produces (a branch
  and PR containing `docs/epics/<NN>-<slug>/plan.md` at `Status: planning`, plus the tracker
  link-back comment), and the hard stops (no approval, no dispatch, no code, no merge, no
  issue closure). Numbering: the run claims the next free `NN` at draft time and states in the
  PR body that a collision is resolved by renumbering at approval. `SKILL.md` — one paragraph
  in the Intake section pointing at it, making explicit that `Status: planning` means *not yet
  approved* and is never dispatchable. `session-start-context.sh` — distinguish the two queues
  in the line epic 04 item 2 introduces: `awaiting approval` for `planning`, `awaiting
  dispatch` for `approved`.
- **Not in scope:** the workflow file or any CI plumbing (item 2); changing the interactive
  intake path; Azure DevOps pipelines.
- **Definition of done:** the contract is stated in one place and referenced from `SKILL.md`;
  `planning` is documented as non-dispatchable; the session-start line names the two queues
  separately, with fixtures covering `planning` only, `approved` only, both, and neither;
  existing injection byte-identical when both queues are empty.
- **Verification:** extend epic 04 item 2's fixture harness with the four cases and paste
  output; re-run every other harness unchanged as regression; `bash -n`.
- **Rollback:** revert the merge commit.

### 2. The GitHub Action
- **Branch:** `feat/unattended-intake-action`
- **Depends on:** item 1 (the contract it enforces must exist first)
- **Scope:** `.github/workflows/claude-intake.yml` — trigger on `issues: [labeled]` filtered to
  `claude-intake`, plus `workflow_dispatch` with an issue-number input for testing without
  touching a label. Steps: checkout, install `claude`, make the skill discoverable (copy
  `Skills/dev-epic-workflow` into the runner's `~/.claude/skills/` and run
  `assets/claude-config/install.sh --user`), then a headless `claude -p` run with an explicit
  tool allowlist derived from `/intake`'s existing `allowed-tools`, invoking intake for that
  issue. Guardrails: `concurrency` keyed on the issue number so a re-label cannot double-run;
  a job timeout; `permissions:` narrowed to `contents: write`, `issues: write`,
  `pull-requests: write`; the credential read from a repository secret. On success the job
  removes the `claude-intake` label and comments the PR link on the issue; on failure it
  comments that intake failed and leaves the label off so it cannot loop.
- **Not in scope:** dispatching executors; running gates or tests; any ADO pipeline equivalent;
  auto-approving or auto-merging anything.
- **Definition of done:**
  - `workflow_dispatch` against a real issue produces a branch + PR containing a plan at
    `Status: planning`, and nothing on `main`.
  - The run writes no code outside `docs/epics/`, and opens no second PR.
  - Label removed and PR link commented on success; failure comments and does not loop.
  - Re-labelling while a run is in flight does not start a second run.
  - No `--dangerously-skip-permissions` anywhere in the workflow.
  - Absent the secret, the job fails fast with a clear message rather than running unauthenticated.
- **Verification:** exercise via `workflow_dispatch` on a disposable throwaway issue; paste the
  run log, the resulting PR diff, and `git log origin/main` showing `main` untouched. Then a
  real label-triggered run on a second throwaway issue. Delete both afterwards.
- **Rollback:** delete the workflow file (revert the merge); no runtime state persists.

## Sequence
1 → 2, serial. Item 2 automates a contract that must exist before it can be enforced, and both
touch documentation the other references.

## Risks
| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| An unattended agent with repo write does something unintended | Low | Unwanted commits/PRs in the repo | PR-only, never `main`; narrowed `permissions:`; explicit tool allowlist; hard stop before dispatch or code |
| Runaway or looping runs burn credits | Medium | Cost | Opt-in label only; `concurrency` per issue; job timeout; label removed on completion; failure does not re-label |
| The approval gate erodes in practice — a `planning` plan gets treated as approved | Medium | The load-bearing gate stops bearing | `planning` documented as non-dispatchable; session-start names it "awaiting approval"; the plan arrives as a PR needing human merge |
| Epic-number collision between a CI draft and a locally filed epic | Medium | Two `05-` folders | Number claimed at draft, renumbered at approval; stated in the PR body |
| Secret handling | Certain to be needed | Credential exposure if mishandled | Jonathan creates the repository secret; Claude never sees or handles the token value |
| CI runner lacks the skill/hooks | High without the install step | Intake runs without its own process | Explicit install step in the workflow, asserted by the first `workflow_dispatch` run |

## Deferred / out of scope
- Azure DevOps pipeline equivalent.
- A `claude-auto` label for approval-free trivial issues — explicitly parked until this has
  soaked for weeks (original roadmap decision, unchanged).
- Unattended *execution* (dispatching work items from CI). Out of scope by design: the gate.
- #12 branch selectors · the `stack-gates.md` shell section · the `agent_id` block in three
  copies · a `/dispatch` command writing worktree + pointer in one step.
- Multi-epic simultaneity — the larger redesign, and the thing that actually delivers
  "several epics running at once". Queuing (epic 04) and unattended intake (this) both feed it.

## Log
- 2026-08-19 — drafted while epic 04's two items ran in parallel. Phase 0 confirmed the repo has
  no CI at all, that `claude` 2.1.220 supports headless runs, and that Phase 1's "file on
  approval" rule forces unattended intake to produce a *proposal PR* at `Status: planning`
  rather than a filed epic.
