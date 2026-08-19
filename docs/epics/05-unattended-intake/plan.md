# Epic: unattended intake (Tier 2)

**Status:** in flight (item 1 of 2)
**Source:** GH #16
**Live branch:** main   **Integration branch:** main   **Pre-epic tag:** n/a
**Depends on:** epic 04 merged (its session-start surface is extended here)

## Outcome
An issue labelled `claude-intake` produces a reviewed epic plan without anyone present. A
**local scheduled runner** on Jonathan's Mac performs Phase 0 grounding and Phase 1 drafting
headlessly and opens a **pull request** carrying the plan at `Status: planning`. Nothing is approved, nothing is
dispatched, no code is written. Jonathan reviews the PR the way he reviews any PR; merging
it plus setting `Status: approved` is the approval gate, unchanged and still human. No CI, no
repository secret, no new billing surface — the runner uses the machine's existing auth.

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
- **Verified:** `claude` supports `-p/--print` with `--allowed-tools`, `--append-system-prompt`
  and `--add-dir`, so a headless run with an explicit allowlist is possible without ever
  reaching for `--dangerously-skip-permissions`.
- **Verified:** `~/Library/LaunchAgents/` exists and holds only third-party updaters, so adding
  one opt-in agent is clean and precedented.
- **Verified:** there is **no** `~/.claude/.credentials.json` and **no** `ANTHROPIC_API_KEY` in
  the environment — so Claude Code's auth almost certainly lives in the login Keychain. That
  works interactively; whether a launchd job can reach it (especially with the Mac locked) is
  the single biggest unknown in this design and cannot be settled by a manual test.
- **Verified:** the `claude-intake` label does not exist in this repo yet.
- **Rejected after grounding (was the original design):** a GitHub Action. This repo has nothing
  to build, test, or deploy — CI would be serving only as a trigger and a rented machine, at the
  cost of a repository secret, a per-run skill install on the runner, and separate billing. A
  local scheduled run gets the same outcome using auth that already exists. Revisit only if
  someone other than Jonathan ever files issues here, or if runs must happen with the Mac off.
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

### 2. Local scheduled intake runner
- **Branch:** `feat/unattended-intake-local-runner`
- **Depends on:** item 1 (the contract it enforces must exist first)
- **Scope:** `assets/claude-config/bin/unattended-intake.sh` — poll
  `gh issue list --state open --label claude-intake`; for each issue, in a fresh git worktree,
  run `claude -p` with an explicit `--allowed-tools` list seeded from `/intake`'s existing
  declaration, producing a plan at `Status: planning`; commit, push the branch, open a PR
  (`Part of #<n>`, never `Closes`), comment the PR link on the issue, and remove the
  `claude-intake` label. On failure: comment that intake failed with the reason, **leave the
  label off so nothing loops**, exit non-zero. Single-instance lock so overlapping runs cannot
  double-process an issue. Append to a log file. Plus an opt-in launchd agent template under
  `assets/claude-config/launchd/`, and instructions to load it — **not** installed by
  `install.sh`'s default path, since scheduling is a per-machine choice. The runner creates the
  `claude-intake` label if missing.
- **Not in scope:** GitHub Actions or any CI; Azure DevOps; unattended *execution* (dispatching
  work items); auto-approval or auto-merge; changing the interactive `/intake` path.
- **Definition of done:**
  - `--dry-run` reports exactly what it would do and mutates nothing — no branch, no PR, no
    label change, no commit.
  - Against a throwaway labelled issue: produces a branch and a PR containing a plan at
    `Status: planning`; `main` untouched; label removed; PR link commented on the issue.
  - Failure path: comments the reason, does **not** re-apply the label, exits non-zero, and
    leaves no half-open PR.
  - A second invocation while one is running exits immediately on the lock.
  - No `--dangerously-skip-permissions` anywhere in the script.
  - Runs correctly under **launchd's minimal environment** — `git`, `gh`, and `claude` resolved
    by absolute path or an explicitly set PATH, not inherited from an interactive shell.
  - **Auth works under launchd**, or the run fails loudly with a clear message rather than
    silently producing nothing.
- **Verification:** manual `--dry-run`, then a manual real run against a throwaway issue with
  output pasted and `git log origin/main` showing `main` untouched. Then — and this is the part
  that cannot be skipped — **a genuine launchd-triggered run**, with the agent's log pasted,
  because the environment and Keychain questions only appear under the scheduler. Delete the
  throwaway issue and branch afterwards.
- **Rollback:** `launchctl unload` the agent and delete it; remove the script. Nothing else
  depends on it, and the interactive path is untouched.

## Sequence
1 → 2, serial. Item 2 automates a contract that must exist before it can be enforced.

## Risks
| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| An unattended agent with repo write does something unintended | Low | Unwanted commits/PRs | PR-only, never `main`; explicit tool allowlist; hard stop before dispatch or code |
| **launchd cannot reach the login Keychain, so runs fail silently** | **Medium** | Automation appears installed but never produces anything | Fail loudly with a clear message; verification requires a genuine scheduled run, not a manual one |
| Mac asleep or logged out → no runs | Certain | Intake simply waits for the next wake | Accepted: this is a personal repo; the interactive path always works |
| Runaway or looping runs burn credits | Medium | Cost | Opt-in label only; single-instance lock; label removed on completion; **failure comments and never re-labels** (Jonathan's decision) |
| The approval gate erodes in practice — a `planning` plan gets treated as approved | Medium | The load-bearing gate stops bearing | `planning` documented as non-dispatchable; session-start names it "awaiting approval"; the plan arrives as a PR needing human merge |
| Epic-number collision between a CI draft and a locally filed epic | Medium | Two `05-` folders | Number claimed at draft, renumbered at approval; stated in the PR body |
| The runner's `claude` lacks the skill because the run is headless | Medium | Intake runs without its own process | The skill is installed at `~/.claude/skills` on this machine already; asserted by the first real run |

## Deferred / out of scope
- Azure DevOps equivalent.
- A GitHub Action, if issues ever arrive from someone other than Jonathan or runs must happen
  with the Mac off. Rejected for now on cost/complexity grounds, not on principle.
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
- 2026-08-19 — item 2 re-planned after Jonathan challenged the premise: this repo has nothing to
  deploy, so CI would have been a trigger and a rented machine, bought with a repository secret
  and per-run billing. Replaced with a local scheduled runner using existing auth. Item 1 was
  already in flight and is mechanism-agnostic, so it was left running.
