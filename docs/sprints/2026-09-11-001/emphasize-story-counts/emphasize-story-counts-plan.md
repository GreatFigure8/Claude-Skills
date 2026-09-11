# emphasize-story-counts — execution plan

Sprint: 2026-09-11-001   Story: emphasize-story-counts   Kind: service
Grounded: `Skills/dev-story-flow/assets/bin/sprint-state.sh` (cmd_list, lines ~86-94), `Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` (list section, lines 25-28), `Skills/dev-story-flow/references/sprint-state.md` (helper table, line 106), `docs/sprints/2026-09-11-001/list-story-counts/story.md` (field 5 spec).
Assumed: `list-story-counts` has not landed yet, so `cmd_list` today prints 4 tab-separated fields and `assets/tests/sprint-state-list-integration.sh` does not exist yet. Item 1 assumes field 5 (`<done>/<total>`) exists per that story's spec and wraps only that field; item 3 assumes the integration test file exists per that story's plan and adds one more case to it.

## Items
| # | Branch | Scope / Done when / Not | Files owned | Wave | Model | Gates |
|---|---|---|---|---|---|---|
| 1 | feat/emphasize-story-counts-style | In `cmd_list`, compute `styled = sys.stdout.isatty() and not os.environ.get("NO_COLOR") or os.environ.get("DSF_FORCE_STYLE") == "1"` (NO_COLOR wins over TTY; DSF_FORCE_STYLE=1 forces on regardless of TTY, but NO_COLOR still forces off — see Open questions) once per invocation, and when styled wrap field 5 only as `\033[1m<done>/<total>\033[0m`, tabs outside the escapes. Add one sentence to `references/sprint-state.md` under the helper table naming `NO_COLOR` and `DSF_FORCE_STYLE`. Done when: `DSF_FORCE_STYLE=1` on a plain pipe shows the wrapped field 5 and nothing else changes. Not: no changes to fields 1-4, no header row, no other subcommand touched. | `Skills/dev-story-flow/assets/bin/sprint-state.sh`, `Skills/dev-story-flow/references/sprint-state.md` | 1 | Sonnet 5 | stack default |
| 2 | test/emphasize-story-counts-unit | Extend `assets/tests/sprint-state-fixtures.sh` with three checks after the existing list section: piped `list` has zero `\x1b` bytes; `DSF_FORCE_STYLE=1 list` matches `ESC[1m<done>/<total>ESC[0m` in field 5; `NO_COLOR=1 DSF_FORCE_STYLE=1 list` is byte-identical to plain `list`. Done when: `bash sprint-state-fixtures.sh` exits 0 and the three new `check` lines are present. Not: no changes to the `new`/`story`/`set` sections of the file. | `Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` | 2 | Sonnet 5 | `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` |
| 3 | test/emphasize-story-counts-tty | Add a TTY case to `assets/tests/sprint-state-list-integration.sh`: spawn `list` under a pseudo-terminal with python3's `pty.spawn` (not macOS `script`, which has incompatible flags) and assert the captured output contains `\x1b[1m`. Done when: the integration test exits 0 including this new case. Not: no change to the non-TTY cases already in that file. | `Skills/dev-story-flow/assets/tests/sprint-state-list-integration.sh` | 2 | Sonnet 5 | `bash Skills/dev-story-flow/assets/tests/sprint-state-list-integration.sh` |

## Validation — how the coder proves each acceptance criterion
| AC | Check | Command / browser steps | Pass when |
|---|---|---|---|
| AC-U | unit | `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` | exit 0, output includes the three styling checks with no `FAIL:` lines |
| AC-I | integration | `bash Skills/dev-story-flow/assets/tests/sprint-state-list-integration.sh` | exit 0, including the pseudo-terminal case |
| AC-1 | no escapes when piped | `SS=Skills/dev-story-flow/assets/bin/sprint-state.sh; S=$("$SS" new); "$SS" list \| cat \| grep -Pc '\x1b' \|\| true` | prints `0` (no match) |
| AC-2 | forced styling wraps only field 5 | `DSF_FORCE_STYLE=1 "$SS" list \| cat` | line matches `^[^\t]+\t[^\t]+\t[^\t]+\t[^\t]+\t\x1b\[1m[0-9]+/[0-9]+\x1b\[0m$` and fields 1-4 are unstyled |
| AC-3 | NO_COLOR overrides force | `diff <(NO_COLOR=1 DSF_FORCE_STYLE=1 "$SS" list) <("$SS" list \| cat)` | empty diff, exit 0 |
| AC-4 | TTY renders bold | `python3 -c "import pty,subprocess; pty.spawn(['bash','-c','$SS list'])" \| grep -Pc '\x1b\[1m'` (as exercised inside `sprint-state-list-integration.sh`) | count >= 1 |

## Order and dependencies
- **Cross-story dependency:** this entire story depends on `list-story-counts` (field 5 of `list` must exist before item 1 can wrap it, and `sprint-state-list-integration.sh` must exist before item 3 can extend it). `list-story-counts` must land on the integration branch first; item 1 branches from that point, not from `dev`/pre-dependency history.
- Within this story: item 1 (styling + doc) is wave 1. Items 2 and 3 (the two test files) are wave 2, both depend on item 1's styling behavior existing, and do not touch each other's files so they run in parallel.

## Risks and gotchas
- The two sprint stories both edit `cmd_list` in the same file (`sprint-state.sh`) — sequence this story strictly after `list-story-counts` merges, do not run them as concurrent waves against the same base.
- `isatty()` must be checked on the actual `sys.stdout` inside the `python3 - <<'PY'` heredoc the script execs into; a naive check against a wrapped/buffered stream could misreport under a pager. Verify with the real pty test (item 3), not a stub.
- NO_COLOR precedence: per no-color.org convention NO_COLOR must win even when DSF_FORCE_STYLE=1 is also set (AC-3) — get this branch order right or AC-3 fails silently.
- macOS `script -q` argument order differs from GNU `script`; item 3 must use python3's `pty.spawn`, not `script`, to stay portable per the story's own risk note.
- Field 5's exact format (`<done>/<total>`) is owned by `list-story-counts`; if that story's implementation deviates from its spec, item 1's regex/wrap logic must be re-checked against the actual output, not the spec text.

## Open questions
- The spec says "styled when `isatty()` is true, unless `NO_COLOR` is set" and separately "`DSF_FORCE_STYLE=1` forces styling on regardless of TTY" — it does not say whether `DSF_FORCE_STYLE=1` also overrides `NO_COLOR`. Default taken here (matching AC-3, which pairs `NO_COLOR=1 DSF_FORCE_STYLE=1` and expects plain output): `NO_COLOR` always wins, even over `DSF_FORCE_STYLE`. If Jonathan intended force to override NO_COLOR too, AC-3 as written would need to change.
