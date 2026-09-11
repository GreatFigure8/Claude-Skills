# fix-refresh-live-git-c-cwd — execution plan

Sprint: 2026-09-11-004   Story: fix-refresh-live-git-c-cwd   Kind: service
Grounded: Skills/dev-story-sprint/assets/hooks/refresh-live-post-push.sh, Skills/dev-story-sprint/assets/install.sh, Skills/dev-story-sprint/assets/tests/merge-settings-fixtures.sh   Assumed: none

## Items
| # | Branch | Scope / Done when / Not | Files owned | Wave | Model | Gates |
|---|---|---|---|---|---|---|
| 1 | feat/fix-refresh-live-git-c-cwd-hook | Extend the python3 one-shot parser in refresh-live-post-push.sh to walk `tokens` for `git` invocations, compose `-C <path>` args per R1-R3 into `GITDIR`, emit `TOOL|PUSH|CWD|GITDIR`, and switch the bash side's `CWD_COMMON` lookup to use `$GITDIR` (falling back to `$CWD` when GITDIR is empty), exactly per the Specification block in story.md. Done when: `bash -n` passes and the file matches the story's Specification code verbatim. Not: no change to fetch/merge/allowlist logic below the identity check. | Skills/dev-story-sprint/assets/hooks/refresh-live-post-push.sh | 1 | Sonnet 5 | `bash -n Skills/dev-story-sprint/assets/hooks/refresh-live-post-push.sh` |
| 2 | test/fix-refresh-live-git-c-cwd-integration | Write `Skills/dev-story-sprint/assets/tests/refresh-live-post-push-fixtures.sh`, modeled on `merge-settings-fixtures.sh`'s sandboxing style (mktemp -d sandbox, trap cleanup, `assert_sandboxed`-equivalent guard so it never touches `$HOME/.claude`). Build one throwaway bare origin plus a "live worktree" clone and a separate "caller checkout" clone/worktree of that same origin (so their `--git-common-dir` resolve to the origin) and a third, unrelated throwaway repo for AC4. Drive the actual `refresh-live-post-push.sh` via `CLAUDE_SKILLS_LIVE=<live worktree>` with synthetic PostToolUse JSON piped to stdin, asserting stdout/stderr and whether the live worktree's HEAD actually advanced. Cases: AC1 (`git -C <caller-checkout> push`, cwd=$HOME, live worktree advances), AC2 (`cd <caller-checkout> && git push`, cwd=caller-checkout, advances), AC3 (plain `git push`, cwd=caller-checkout, advances), AC4 (`-C <unrelated-repo>`, cwd=$HOME, does NOT advance), AC5 (non-Bash tool_name, `--dry-run` command, and empty stdin — each exits 0, no advance, no output). Done when: script exits 0 with a `cases:/failures:` summary line and all cases PASS. Not: no change to the hook script itself. | Skills/dev-story-sprint/assets/tests/refresh-live-post-push-fixtures.sh | 2 | Sonnet 5 | `bash Skills/dev-story-sprint/assets/tests/refresh-live-post-push-fixtures.sh` |

## Validation — how the coder proves each acceptance criterion
| AC | Check | Command / browser steps | Pass when |
|---|---|---|---|
| AC-I | integration | `bash Skills/dev-story-sprint/assets/tests/refresh-live-post-push-fixtures.sh` | exits 0, all cases PASS |
| AC1 | integration | same script, case "git -C <matching-worktree> push, unrelated cwd" | live worktree HEAD advances (fails pre-fix, passes post-fix) |
| AC2 | integration | same script, case "cd <repo> && git push" | live worktree HEAD advances, unchanged from pre-fix |
| AC3 | integration | same script, case "plain git push from inside repo" | live worktree HEAD advances, unchanged from pre-fix |
| AC4 | integration | same script, case "-C <unrelated-repo>, unrelated cwd" | live worktree HEAD does NOT advance |
| AC5 | integration | same script, cases "tool_name != Bash", "--dry-run", "empty stdin" | each exits 0, no output, live worktree HEAD does NOT advance |

## Order and dependencies
Item 2 depends on item 1 (the fixture asserts the fixed script's behavior, including the pre-fix-fails/post-fix-passes contrast for AC1) — sequential waves, no file overlap. No dependency on the sprint's other story (`fix-install-matcher-upgrade`).

## Risks and gotchas
- The fixture harness must build two clones/worktrees of one throwaway bare origin so `git rev-parse --git-common-dir` for "live" and "caller checkout" can genuinely match — a plain directory copy won't share `--git-common-dir`.
- Must never touch `$HOME/.claude` — replicate `merge-settings-fixtures.sh`'s sandbox-guard pattern before running the real hook script.
- `CLAUDE_SKILLS_LIVE` env var (not a positional arg) is how the hook script locates the live worktree — the fixture must export it per case, pointed at the sandboxed live clone.
- The hook always exits 0 (`set -u` but no `set -e`); use side effects (HEAD advancing, stdout content) to distinguish pass/fail, not exit code alone, except where the story specifies exit-0-with-no-output for guard cases.
- Python3 must be available in the harness environment (already assumed elsewhere in this codebase's fixture harnesses).

## Open questions
None.
