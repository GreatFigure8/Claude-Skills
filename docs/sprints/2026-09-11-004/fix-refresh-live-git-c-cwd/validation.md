# fix-refresh-live-git-c-cwd — validation

Run against integration branch `sprint/2026-09-11-004` at commit `ce1f91a`, UTC 2026-09-11T21:10Z.

Command: `bash Skills/dev-story-sprint/assets/tests/refresh-live-post-push-fixtures.sh`
Result: exit 0, 27 cases, 0 failures.

| AC | Check | Result |
|---|---|---|
| AC-I | fixture harness exists, exercises the running hook script end to end, exits 0 | PASS |
| AC1 | `git -C <caller-checkout> push` with cwd unrelated to the repo (`$HOME`) advances the live worktree | PASS (5 rows) — confirmed FAILS against the reconstructed pre-fix hook (`545e340^`), PASSES against the merged one |
| AC2 | `cd <caller-checkout> && git push` still advances, unchanged | PASS (3 rows) |
| AC3 | plain `git push` from inside the repo still advances, unchanged | PASS (3 rows) |
| AC4 | `-C <unrelated-repo>` does not advance the live worktree | PASS (3 rows) |
| AC5 | guard cases (`tool_name != Bash`, `--dry-run`, empty stdin) exit 0, no output, no advance | PASS (5a/5b/5c, 11 rows) |

## Notes — one fix cycle (attempt 1)

The first pass of item 2 (the fixture harness) surfaced a genuine defect in item 1's already-merged
hook change: the pre-existing push-detection guard, `push = "git push" in cmd`, is a raw substring
check that runs independently of the new `-C` parsing. For `git -C <path> push`, the literal
substring `"git push"` never appears (`-C <path>` sits between the words), so the hook exited before
the `-C` resolution it exists to add was ever reached — the exact case this story fixes never fired.
Confirmed independently (`"git push" in "git -C /tmp/x push"` → `False`) before dispatching a fix.
One Sonnet 5 fix item (`fix/fix-refresh-live-git-c-cwd-attempt-1`) made push-detection token-based
(scanning each `git` invocation's own args for a literal `push` token, excluding `--dry-run`),
without touching the `-C` composition logic or the fixture file. Re-validation above is the result
after that fix — all 27 cases pass, attempts=1.

All acceptance criteria pass. Story done.
