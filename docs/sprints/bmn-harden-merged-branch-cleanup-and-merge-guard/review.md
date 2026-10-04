# Review — bmn-harden-merged-branch-cleanup-and-merge-guard

## REVIEW1

Pass 1, whole run. Scope: `git diff d8b709f...79dd1b0`, which covers both stories. TEST① reported no failures (`[]`).
Gates at 79dd1b0: pytest passed (596) on the default Python and on /usr/bin/python3 (3.9.6). `ruff check` is clean.
Method: `/code-review` at high effort, then the lenses guarding-destructive-operations,
keeping-git-repos-clean and auditing-python-security. The lens skills are not installed on this machine, so their rules came from
the stories and stack.md. Every guard claim below was probed through `deploy-guard.py` at 79dd1b0, with the cwd set to the
run worktree. Every git claim was reproduced in a scratch repo under the session scratchpad.

Counts: CRITICAL 0 · HIGH 0 · MEDIUM 1 · LOW 5.

### R1-1 · MEDIUM · references/move-computers.md:29 · owner cleanup-helper-local-only-mode-and-wider-caches
**What's wrong:** Step 5 of the machine-move procedure ("Then tidy this machine") still removes the run worktree and the harness
worktrees with a plain `git worktree remove` and `git branch -D`. That is the same hand-run path R2-1 removed from CLEANUP.
**Why it matters:** Without `--force`, git refuses untracked files but deletes ignored ones without warning. This was reproduced: a
worktree whose only extra file was a gitignored `.env` was removed, exit 0, and the `.env` was gone. The step also skips the
helper's rebase/bisect check.
**Failure scenario:** Jonathan has a `.env` in the run worktree and says "moving computers". The `.env` is lost.
**Fix direction:** Route this step through `merged-branch-cleanup.py`, or run the same ignored-file check (`is_cache`) before any
`worktree remove`. Keep and report a worktree that holds a non-cache ignored file.

### R1-2 · LOW · assets/bin/deploy-guard.py:357 (ref_destination) / :387 (deleted_protected_ref) · owner deploy-guard-protected-deletes-and-wrapper-gaps
**What's wrong:** The branch guard misses a protected delete written as `heads/<name>`, because `ref_destination` strips only
`refs/heads/`. git resolves a push destination with the rev-parse rules, so `heads/dev` resolves to `refs/heads/dev`.
**Evidence:** In a scratch bare repo, `git push origin --delete heads/feature` and `git push origin :heads/other` deleted
`refs/heads/feature` and `refs/heads/other`.
**Failure scenario:** `git push origin --delete heads/dev` and `BMN_USER_APPROVED_DEPLOY=1 git push origin :heads/main`
both exit 0 through the guard. R2-4's "a protected branch is never deleted inside a run" does not hold.
**Fix direction:** Normalise the destination with git's DWIM prefixes (`heads/`, `refs/heads/`) before comparing it to
DELETE_PROTECTED.

### R1-3 · LOW · assets/bin/deploy-guard.py:228 (shell_command_string) · owner deploy-guard-protected-deletes-and-wrapper-gaps
**What's wrong:** The guard does not read fish's `-C` / `--init-command`. fish's documentation says this option evaluates its
commands "before executing command specified by -c or reading interactive input". The R2-5 work added fish
`--command`, and deploy-guards.md now says the fish forms are read, but it lists `-C` neither as covered nor as a blind spot.
**Failure scenario:** `fish -C 'git merge --squash x' -c true` and `fish --init-command='git merge --squash x' -c true`
exit 0 through the guard. fish is not installed on this machine, so this was probed through the guard only.
**Fix direction:** Read `-C`, `--init-command` and `--init-command=` the way `--command` is read, or list them under Known blind spots.

### R1-4 · LOW · references/deploy-guards.md:130 (Known blind spots) · owner deploy-guard-protected-deletes-and-wrapper-gaps
**What's wrong:** The story's out-of-scope note says "the GitHub MCP's branch tools — listed blind spots stay as they are". The blind-spot
paragraph lists neither those tools nor `gh api -X DELETE repos/<o>/<r>/git/refs/heads/<protected>`.
**Failure scenario:** `gh api -X DELETE repos/o/r/git/refs/heads/dev` exits 0 through the guard and deletes dev on GitHub. The
doc tells the reader that protected deletes are guarded, with exceptions only for `git push --prune` and local `git branch -D`.
**Fix direction:** Name both in the blind spots, or guard `gh api` DELETE requests on `git/refs/heads/<protected>`.

### R1-5 · LOW · assets/bin/deploy-guard.py:429 (branch_reason) · owner deploy-guard-protected-deletes-and-wrapper-gaps
**What's wrong:** Every `git push` segment now runs `push_parts` twice, once for the branch guard and once for `check_git`. In delete
mode, `deleted_protected_ref` starts a `git symbolic-ref` subprocess for each refspec, at most two per refspec, and it now does so on
approved segments too.
**Failure scenario:** `git push origin --delete a b c d` spawns up to 8 subprocesses on every hook call. This is cost only; behaviour
is correct.
**Fix direction:** Parse once per segment, and look up the default branch once (lazily) per segment.

### R1-6 · LOW · assets/bin/merged-branch-cleanup.py:328 (plan_cleanup) · owner cleanup-helper-local-only-mode-and-wider-caches
**What's wrong:** `--local-only` is applied after planning. `plan_cleanup` builds the full remote plan, removes the `<remote>:<branch>`
entry from `left` by matching the ref string, then appends its own entry.
**Failure scenario:** If `plan_remote` or `plan_unmerged` later report the remote copy under another ref spelling, the filter
misses it, and the copy is reported twice or with a stale reason. Today's tests pin only the current string.
**Fix direction:** Pass `local_only` into `plan_remote` and `plan_unmerged` so the remote entry is decided in one place.

### Checked, no finding
- `is_cache` matches exactly and case-sensitively with `fnmatchcase`, only on ignored `!! ` entries. Directories are matched per
  component and file names only on the last component. Every near-miss in criterion 11 stays blocking. The helper is 398 lines (under 400).
- `--local-only` sends no push, delete or lease. The ancestry, rebase/bisect, dirty-worktree and refusal checks all still run.
  `--dry-run` does not fetch.
- The xargs flag split matches GNU getopt: `--replace`, `--max-lines` and `--eof` are optional-argument flags. All BSD value flags are
  still consumed.
- The parity test compares the live constants and checks the documented lists. The approval prefix still lets real deploys through.
- No secrets. Every subprocess call takes an argument list (no shell). No new mutable module state.

### Notes for Jonathan (not findings)
- In this session the live PreToolUse hook is the **1.5.0** copy
  (`~/.claude/plugins/cache/claude-skills/dev-bother-me-nope/1.5.0/assets/bin/deploy-guard.py`). It blocked a scratch
  `git push origin main` to a local bare repo. The 1.6.x branch-guard changes are therefore not what guards sessions yet, which
  bears on the "update the plugin" ask.

## REVIEW2

Pass 2, whole run. Scope: the FIX① delta `git diff 79dd1b0...7e990c1`. This run's own changes are `5c27dfd..62ac692` (both fixers)
plus `976c2f4` (Python 3.9 `zip(strict=)` fix). The Next.js reference content arrived through the origin/dev merge `b2dbdf4`, which merged
cleanly; it belongs to another run and was checked only for contract clashes (none found). TEST② failure: criterion 15 version pin, see R2-5.
Gates at 2f20d46: pytest passed (1114) on the default Python and on /usr/bin/python3 (3.9.6). `ruff check` is clean.
Method: `/code-review` at high effort, then the lenses guarding-destructive-operations,
keeping-git-repos-clean and auditing-python-security. The lens skills are not installed, so their rules came from the stories and stack.md.
Guard claims were probed through the run branch's `deploy-guard.py`, with the cwd set to the run worktree. fish's option table was read from
fish-shell `src/bin/fish.rs` (`SHORT_OPTS = "+hPilNnvc:C:p:d:f:D:o:"`); fish is not installed, so no fish command was executed. The helper's
fetch-failure plan was checked by calling `plan_cleanup` directly. A scratch-repo `git push origin main` was blocked by the live 1.5.0
deploy guard, and that path was dropped.

Counts: CRITICAL 0 · HIGH 0 · MEDIUM 0 · LOW 6.

### Re-check of REVIEW1 at 7e990c1
| Id | Status | Note |
| --- | --- | --- |
| R1-1 | fixed | MOVE-OUT step 6 runs `merged-branch-cleanup.py --pushed` / `--local-only` per branch, and a worktree holding a `.env` is kept (`test_pushed_keeps_a_worktree_holding_an_ignored_env`). |
| R1-2 | fixed | `git push origin --delete heads/dev` and `BMN_USER_APPROVED_DEPLOY=1 git push origin :heads/main` exit 2 (branch guard). `refs/heads/heads/dev` stays allowed. |
| R1-3 | fixed | `fish -C '…' -c true`, `--init-command[=]` and `-C'…'` are read. See R2-2 for the forms that remain unread. |
| R1-4 | fixed | The blind spots name `gh api -X DELETE …/git/refs/heads/<protected>` and the GitHub MCP branch tools. These are documented, not guarded, as the fixer recorded. |
| R1-5 | fixed | One `push_parts` per segment, and the default-branch lookup is lazy (at most once). |
| R1-6 | fixed | `Survey.local_only` is decided in `plan_remote`. `plan_cleanup` no longer post-filters. |

### R2-1 · LOW · references/move-computers.md:41 · owner cleanup-helper-local-only-mode-and-wider-caches
**What's wrong:** Step 6 now says to name every kept item "in the handoff under *Left on <host>*". But step 5 has already committed
and pushed `handoff.md`, and step 6 itself removes the run worktree, which holds the handoff, whenever that worktree is clean.
**Failure scenario:** Clean run worktree. The helper removes it, and the agent is then told to edit a file that exists only on origin, while the main checkout may not be switched. The agent either
improvises a new worktree or commit path, or leaves the pushed *Left on <host>* section unfilled. The fixer recorded this ordering as pre-existing (FIX①
assumption 3), but the new sentence makes the instruction one that cannot be followed. The closing message still carries the list.
**Fix direction:** Run the tidy in `--dry-run` before step 5 and write its `left` into the handoff, or drop the handoff clause and keep only the closing message.

### R2-2 · LOW · assets/bin/deploy-guard.py:249 (shell_command_strings) · owner deploy-guard-protected-deletes-and-wrapper-gaps
**What's wrong:** The rewritten parser still reads fish with sh rules in two places. fish's getopt takes `-c` with an attached value, and
`-d`, `-p`, `-f`, `-D`, `--profile`, `--debug`, `--features`, `--debug-stack-frames` and `--profile-startup` all take a value. The guard treats each value
word as the end of the options.
**Failure scenario:** `fish -c'git merge --squash x'`, `fish -lc'git merge --squash x'`, `fish -d 3 -c 'git merge --squash x'`,
`fish --profile /tmp/p -c '…'` and `fish -f x -C 'git merge --squash x' -c true` all exit 0 through the guard. The last one defeats the new R1-3
read. deploy-guards.md lists none of these as blind spots.
**Fix direction:** For fish, treat `c` like `C` in `FISH_INIT_SHORT` (an attached remainder is the string) and add fish's value flags to a
fish-only value-flag set. If the 800-line cap does not allow that, list these forms as blind spots.

### R2-3 · LOW · assets/bin/merged-branch-cleanup.py:314 (plan_remote) · owner cleanup-helper-local-only-mode-and-wider-caches
**What's wrong:** The `local_only` branch returns before the `fetch_error` check. Under `--local-only`, and so under `--pushed`, a failed
`git fetch --prune` therefore appears nowhere in the JSON, and `plan_local` still deletes the local branch.
**Failure scenario:** The network is down during a machine move. `--pushed` returns `delete_local=True`, and `left` holds only "origin copy kept: --local-only".
The move-computers claim "only once git proves its tip is on origin" then rests on a stale `origin/<branch>`, and nothing tells
Jonathan so. If origin lost the branch meanwhile, a later `fetch --prune` drops the last ref to those commits.
`test_local_only_plan_reports_the_origin_copy_once_whatever_the_state[merged-both-fetch-failed]` pins the swallow.
**Fix direction:** Carry the fetch error in the kept entry's reason. For `--pushed`, keep the local branch when the fetch failed.

### R2-4 · LOW · assets/bin/deploy-guard.py:415 (deleted_protected_ref docstring) · owner deploy-guard-protected-deletes-and-wrapper-gaps
**What's wrong:** The docstring says the default branch is read "only when no refspec is a protected name already". In fact the lookup runs whenever a
non-protected delete refspec comes before a protected one.
**Failure scenario:** `git push origin --delete a dev` runs `git symbolic-ref` once. That is harmless, but the contract is misstated, and the test only pins the `dev a b` order.
**Fix direction:** Reword it to "read at most once, lazily, at the first non-protected delete refspec".

### R2-5 · LOW · cleanup-helper-local-only-mode-and-wider-caches/story.md:124, evidence/smoke.py:424 · owner cleanup-helper-local-only-mode-and-wider-caches
**What's wrong:** This is the TEST② failure. Criterion 15, the story title "(plugin 1.6.1)" and the committed smoke script all pin 1.6.1. plugin.json is
1.7.0, because dev's Next.js wiring (66eeb2b) was already at 1.7.0 and the hardening now ships inside that version.
**Failure scenario:** Re-running `evidence/smoke.py` at the run tip fails S1.C15. Someone auditing the story expects a 1.6.1 release that never existed.
**Fix direction:** Amend the criterion and the smoke check to 1.7.0. Do not downgrade.

### R2-6 · LOW · references/move-computers.md:29 (step 6) · owner cleanup-helper-local-only-mode-and-wider-caches
**What's wrong:** Each per-branch helper call runs its own `git fetch --prune origin`.
**Failure scenario:** A run with eight local wip branches makes nine-plus network fetches during a move. This is cost only.
**Fix direction:** Fetch once at the start of step 6 and pass `--no-fetch` to each call.

### Checked, no finding
- `heads/` stripping is applied once (`count=1`) and in both the branch and deploy paths. `HEAD:heads/main` is a deploy block that the approval prefix lifts.
- The `--pushed` target must equal `refs/remotes/<remote>/<branch>` after `rev-parse --symbolic-full-name`. An ambiguous local `origin/<branch>`
  ref resolves to `refs/heads/…` and is refused. Protected and default-branch names are still refused, and all worktree, rebase, bisect and compare-and-swap checks still run.
- The pruned origin copy under `--pushed` raises the "no longer resolves" Refusal, and the local branch is kept.
- No secrets, no shell-string subprocesses, and no new mutable module state. The parsed push is a tuple. The helper is 399 lines and the guard 797.

### Notes for Jonathan (not findings)
- The live PreToolUse hook in this session is still the **1.5.0** copy. It blocked a scratch-repo `git push origin main`. The plugin cache
  holds up to 1.6.0. Updating the plugin to 1.7.0 brings in both this hardening and the Next.js reference.
