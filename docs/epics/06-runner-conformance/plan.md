# Epic: runner conformance — no number reservation, multiple repos

**Status:** closed
**Source:** GH #22, GH #23, GH #34
**Live branch:** main   **Integration branch:** main   **Pre-epic tag:** n/a

## Outcome
The unattended runner stops contradicting the workflow it implements. It no longer reserves
an epic number at draft time — Phase 1 assigns numbers at approval, so proposals land in
`docs/epics/proposed-<issue>-<slug>/` and collisions become structurally impossible rather
than merely rarer. And it serves an explicit list of repos instead of one hardcoded path, so
working across several repos at once is supported rather than accidental.

## Grounding
- **Verified:** `unattended-intake.sh` computes `NEXT` from `ls -d docs/epics/[0-9][0-9]-*`
  on `main`, so every run before a merge sees the same highest number. Both live proposals
  (#20, #21) claim `06`.
- **Verified:** `SKILL.md` Phase 1 states the number is assigned **at approval**, not at
  drafting. Reservation was the runner's own invention and contradicts it.
- **Verified:** `REPO_DIR="${INTAKE_REPO_DIR:-$HOME/Source/claude-skills}"` pins the poller to
  one repo; `INTAKE_REPO_DIR` already overrides it, so multi-repo works today only by running
  one agent per repo.
- **Verified:** everything else is already per-repo — `docs/epics/`, numbering, `status/`,
  sentinels, worktrees, the pointer, the backlog query. Confirmed by running the session hook
  against three repos: each reported its own tree root and tracker.
- **Verified:** `docs/epics/` is committed, tracked content, so two synced clones of one repo
  agree about epics. An earlier claim that checkouts disagree was wrong and is withdrawn.
- **Assumed:** a `proposed-` prefix sorts and reads acceptably beside numbered folders. It is
  also a visible signal that a draft is unapproved, reinforcing the `Status: planning` gate.

## Invariants
- The approval gate never moves: proposals stay `Status: planning`, never dispatchable.
- Every existing guard keeps working: credential refusals, lock, dry-run inertness, redaction,
  no token in argv or plist, `install.sh` untouched.
- One repo failing must never stop the others.
- A missing or empty repo list falls back to today's single-repo behaviour — nothing breaks
  for the current setup.
- Runs under bash 3.2 with launchd's minimal environment.

## Work items

### 1. Proposal naming and an explicit repo list
- **Branch:** `fix/runner-conformance`
- **Depends on:** none
- **Scope:** `bin/unattended-intake.sh` — drop `NEXT` entirely; proposals go to
  `docs/epics/proposed-<issue>-<slug>/plan.md` on branch `intake/proposed-<issue>-<slug>`.
  Read `~/.config/claude-intake/repos` (one absolute path per line, `#` comments, blank lines
  ignored); for each entry resolve the repo, poll, and process, isolating per repo and
  continuing past failures. Keep ONE lock for the whole run. Update
  `references/issue-intake.md` where it documents numbering-as-reservation, and the PR body
  text the runner generates.
- **Not in scope:** the interactive `/intake` path; the launchd template's schedule; anything
  outside the runner and that one reference section.
- **Definition of done:**
  - No epic number is claimed at draft time; the folder is `proposed-<issue>-<slug>`.
  - Two issues labelled at once produce two proposals that cannot collide.
  - Repo list honoured; missing/empty list falls back to `INTAKE_REPO_DIR`.
  - A listed path that is not a git repo, or has no GitHub remote, is logged and skipped
    without aborting the run.
  - All prior guards still pass: missing credential `rc=3`, `0644` `rc=3`, empty token `rc=3`,
    missing binary `rc=1`, lock held `rc=2`, `--dry-run` mutates nothing, redaction holds.
  - `bash -n` clean; runs under launchd.
- **Verification:** re-run the full guard battery; dry-run against a two-repo list; then live —
  close the two colliding proposals, re-label #15 and #12, and let one run regenerate both
  under the new scheme. Two proposals, no collision, is the proof.
- **Rollback:** revert the merge commit. The runner returns to reserving numbers, which is
  today's behaviour.

### 2. The runner tells the agent where its contract is
- **Branch:** `fix/runner-contract-paths`
- **Source:** GH #34
- **Depends on:** item 1 (merged)
- **Scope:** `bin/unattended-intake.sh` — the prompt-construction block. Derive `SKILL_DIR`
  from `BASH_SOURCE` (the script sits at `<skill>/assets/claude-config/bin/`, so the skill
  root is three levels up) and pass **absolute** paths to `references/issue-intake.md` and
  `references/plan-template.md` instead of repo-relative `Skills/...`, which resolves only
  inside this repo. Grant read access with `--add-dir "$SKILL_DIR"`. Drop `Bash(find:*)`
  from `--allowed-tools`. Resolve the target repo's epics directory from its own tracked
  files once per repo — for the prompt, the `--dry-run` message, and the generated PR body —
  rather than hardcoding lowercase `docs/epics`.
- **Not in scope:** the interactive `/intake` path; the launchd schedule; item 1's repo-list
  logic; anything outside this one file.
- **Definition of done:**
  - Prompt carries absolute, existing reference paths; `--add-dir` present; no `find` in
    `--allowed-tools`. **The allowlist is not a sandbox** — a live run proved `find` still
    executes inside a compound command (`ls ...; find ...`), so removing it withdraws the
    sanctioned path but is not a hard boundary. The absolute paths are what actually stop
    the escalation, by removing the reason to hunt.
  - Preflight fails `rc=1` when the references are not where `SKILL_DIR` says.
  - Epics dir resolves `DOCS/EPICS` for Oracle-Simple-Convert, `docs/epics` for this repo,
    and falls back to `docs/epics` in a repo with none. `--dry-run` reports the same path a
    real run would write.
  - Full guard battery unchanged: missing credential `rc=3`, `0644` `rc=3`, empty token
    `rc=3`, missing binary `rc=1`, lock held `rc=2`, `--dry-run` inert, redaction holds.
  - `bash -n` clean.
- **Verification:** guard battery; dry-run against the two-repo list asserting the per-repo
  epics path; then one live issue (#730) — pass is a proposal PR whose transcript contains
  **no `find /`** and whose plan lands under `DOCS/EPICS/`.
- **Rollback:** revert the merge; the runner returns to repo-relative paths.

## Sequence
Item 1 then item 2 — both touch the same file, and item 2 builds on the repo loop item 1 added.

## Risks
| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| Looping over repos breaks the single-repo path | Medium | The working setup regresses | Empty/missing list falls back to `INTAKE_REPO_DIR`; guard battery re-run unchanged |
| One bad repo aborts the whole run | Medium | Other repos silently skipped | Per-repo failures logged and skipped, asserted by a fixture with a non-repo path |
| `proposed-` folders linger after approval | Medium | Clutter that looks like queued work | Approval renames to `NN-slug`; documented in the contract, and the queue line lists them as awaiting approval regardless |
| Built inline again, so author and reviewer are the same | Certain | No independent check | Guard battery is mechanical; the live two-proposal run is the real test |
| `--add-dir` widens what the headless agent may read | Low | Agent reads the skill tree | It is the skill's own contract, read-only in practice, and narrower than the `find /` it replaces |
| A future move of the script breaks `SKILL_DIR` | Low | Runner refuses to start | Preflight asserts both references exist and exits `rc=1` with the fix in the message |

## Deferred / out of scope
- Retrofitting the sandbox guard to the three older harnesses (GH #15 — a proposal exists).
- Branch-name cancel selectors (GH #12 — a proposal exists).
- The `agent_id` extraction block in three copies; `stack-gates.md` shell section.
- Multi-epic simultaneity.

## Log
- 2026-08-19 — filed from GH #22 and #23, approved directly. Phase 0 confirmed the runner's
  number reservation contradicts Phase 1, and that only the poller (not the workflow) was
  single-repo.
- 2026-08-20 — item 1 merged (PR #24). GH #27, #31, #29 were filed and fixed directly
  against this same runner without their own plans; recorded here rather than pretended away.
- 2026-08-20 — item 2 filed from GH #34 after a live LODE drain showed the headless agent
  running `find /` to locate its own contract, raising macOS TCC prompts on an unattended
  run. The 7-issue drain was stopped after issue #731 (PR #732) for this reason; #730–#725
  remain labelled and resume when the agent is reloaded.
- 2026-08-20 — item 2 verified live on #730: PR #733, plan at `DOCS/EPICS/proposed-730-.../`,
  and **zero** full-disk `find /` calls against two in the #731 baseline. Correction recorded
  above: dropping `Bash(find:*)` did not prevent `find` from running at all — two bounded
  `find` calls executed inside compound commands. The fix works because the agent no longer
  needs to search, not because searching was blocked.

## Retro

**Outcome.** Both work items merged and verified. The runner no longer reserves an epic number
at draft time, serves an explicit list of repos, and tells the headless agent where its own
contract is by absolute path. Verified live end to end: seven LODE issues drafted into seven
proposal PRs across two drains, with **zero** full-disk `find /` calls in the final four
transcripts against two in the pre-fix baseline.

**What got split.** Item 2 did not exist when the epic was filed — it emerged from a live run.
Item 1 made other repos reachable, and that immediately exposed a coupling nobody had noticed:
the prompt named `Skills/dev-epic-workflow/references/…`, a path that resolves only inside this
repo. The bug was always there; item 1 is what made it reachable. A third candidate item was
scoped and then **deliberately dropped** — see the root-cause finding below.

**What surprised us, in order of how much it should change future behaviour:**

1. **The verification was wrong, not just thin.** Item 2 was declared proven on a *single* live
   issue (#730, zero `find /`). The very next issue (#729) ran `find /` twice. The behaviour is
   probabilistic, and one passing sample was never evidence — it was a coin landing heads once.
   The corrected standard, applied before this epic closed: four independent runs, each checked
   automatically against a failure condition stated in advance. Where a fix changes what a model
   *chooses* to do, n=1 proves nothing.
2. **The root cause was not in this repo.** `find /` was a symptom. Oracle-Simple-Convert
   carried its own copy of this skill at `.claude/skills/dev-epic-workflow/`, committed
   2026-08-04 so "cloud sessions and teammates inherit it" — neither of which existed. It rotted
   to 3 of 7 references while its `CLAUDE.md` declared it **canonical for this project**. The
   agent was not malfunctioning; it was obeying the target repo's instructions, failing to find
   a missing reference, and searching. The planned item 3 — harden the runner's prompt to
   override the local copy — would have set the runner in direct conflict with a repo's own
   `CLAUDE.md`. Deleting the stale copy (LODE #736/#737) removed the conflict and made item 3
   unnecessary. **When two authorities disagree, resolve which one is authoritative; do not
   make one shout louder.**
3. **`--allowed-tools` is not a sandbox.** Removing `Bash(find:*)` did not stop `find` from
   running: it executes inside a compound command that begins with an allowed binary
   (`ls …; find …`). The allowlist withdraws the *sanctioned* path; it is not a boundary. What
   actually eliminated the disk walk was giving the agent absolute paths, removing its reason to
   search. A guard that constrains intent beats one that enumerates binaries.
4. **Duplication rots silently and asymmetrically.** "Keep the two copies identical" survived
   zero days past the commit that wrote it. Copies drift toward *incomplete*, and an incomplete
   copy that claims primacy is worse than no copy at all.

**Process debt, recorded rather than hidden.** GH #27, #31 and #29 were filed as issues and
fixed directly against this same runner during this epic, each merged without a plan of its own
(PRs #28, #32, #33). That deviates from Phase 1. They are recorded in the log above rather than
retro-fitted as work items, because inventing plans after the fact would misrepresent how they
were built. The honest lesson: under time pressure the plan step is what gets dropped first, and
three unplanned fixes to a file already under an open epic should have been that epic's items.

**Deferred, unchanged.** GH #15 and GH #12 still have open proposals (PRs #25, #26). The
`agent_id` extraction block still exists in three copies. Multi-epic simultaneity untouched.

**Left for someone to judge.** Seven unattended-drafted plans now exist for LODE (#732, #733,
#735, #738, #739, #740, #741). Six were merged as `Status: planning` drafts; none is approved,
numbered, or dispatchable. The *mechanism* is verified — the drafting *judgement* has still not
been reviewed by anyone.
