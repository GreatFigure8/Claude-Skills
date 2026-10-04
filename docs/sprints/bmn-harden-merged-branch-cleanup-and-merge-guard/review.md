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
