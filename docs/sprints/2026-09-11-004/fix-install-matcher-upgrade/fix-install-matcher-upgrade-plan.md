# fix-install-matcher-upgrade — execution plan

Sprint: 2026-09-11-004   Story: fix-install-matcher-upgrade   Kind: service
Grounded: Skills/dev-epic-workflow/assets/claude-config/install.sh (whole merge heredoc, lines
84-141), Skills/dev-epic-workflow/assets/claude-config/hooks/tests/install-matcher-fixtures.sh
(whole, 146 lines)   Assumed: none

## Items
| # | Branch | Scope / Done when / Not | Files owned | Wave | Model | Gates |
|---|---|---|---|---|---|---|
| 1 | fix/install-matcher-upgrade | In the `PYEOF` python heredoc in `install.sh` (the `for group in src_groups:` loop, currently `if cmds <= existing_cmds: continue`), before the `continue`, walk `dst_groups` for any existing group owning ≥1 command in `cmds` and reconcile its `matcher` to the source group's: pop the dest key if the source has none, set/overwrite it if the source has one and it differs; append `f"{event} (matcher)"` to `changed` only when an update actually happened. Then extend `install-matcher-fixtures.sh` with new cases (inline, after the existing run2 idempotence block, reusing its `SETTINGS`/`matcher_shape`/`check` helpers): (a) seed a fresh sandbox `$FAKE_HOME/.claude/settings.json` with a `PreToolUse` group for `context-budget-gate.sh` carrying a stale matcher (e.g. `"Bash"`, distinct from the source's `""`), run `install.sh --user` once, assert the resulting matcher now equals `$SRC_CBG_SHAPE` and that exactly one `PreToolUse` group still owns that command (count groups via a small python one-liner, not just `matcher_shape`); (b) re-run `install.sh --user` against that same `$FAKE_HOME` a second time and assert the resulting `settings.json` is byte-identical to the first upgrade run's copy; (c) in a second fresh sandbox, seed a `cancel-gate.sh` `PreToolUse` group that has an erroneous `matcher` key (source has none), run once, assert the dest group ends up with `matcher_shape` == `absent`. Done when: `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/install-matcher-fixtures.sh` exits 0 with all cases (old + new) PASS, and manually confirmed during development (via `git stash` on the `install.sh` change only, re-running the new cases, then `git stash pop`) that the new upgrade/removal cases FAIL against the pre-fix merge logic. Not: no change to `settings-hooks.json`, the `statusLine` branch, the new-group append branch, the `.gitignore` block, or the commit/echo tail. | `Skills/dev-epic-workflow/assets/claude-config/install.sh`, `Skills/dev-epic-workflow/assets/claude-config/hooks/tests/install-matcher-fixtures.sh` | 1 | Sonnet 5 | `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/install-matcher-fixtures.sh` |

Single item: the fix and its proof are one small, tightly-coupled change (a test suite proving
a bug fix must be written and validated against both the broken and fixed code in the same
pass); splitting them across a wave boundary would only add branch/merge overhead with no
parallelism gained, since both files must land together for the fixture to be meaningful.

## Validation — how the coder proves each acceptance criterion
| AC | Check | Command / browser steps | Pass when |
|---|---|---|---|
| AC-U | unit/fixture gate | `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/install-matcher-fixtures.sh` | exit 0; run1/run2 fresh-install cases (AC-U1) still PASS unchanged |
| AC-I | integration (new upgrade fixture case) | same command as AC-U; new case seeds a stale `context-budget-gate.sh` matcher into a synthetic `settings.json`, runs `install.sh --user` once, and asserts (i) matcher now equals `settings-hooks.json`'s current source matcher via `matcher_shape`, and (ii) exactly one `PreToolUse` group still owns that command (no duplicate appended) | all new-case rows print PASS; case was confirmed to FAIL against the pre-fix `install.sh` (verified with `git stash` during development, not part of the committed test run) |
| AC1 | idempotence of the upgrade case | same command; second `install.sh --user` run against the same `$FAKE_HOME` used for the AC-I case, compared with `cmp -s` against the first upgrade run's saved copy | `byte_identical` reports `yes` |
| AC2 | absent-matcher reconciliation | same command; new case seeds a destination `cancel-gate.sh` `PreToolUse` group with an erroneous `matcher` key (source has none), runs `install.sh --user` once | `matcher_shape` for that group reports `absent` after the run |

## Order and dependencies
Single item, single wave — no dependency on the sprint's other story (`fix-refresh-live-git-c-cwd`,
different file, different concern, per the story's own Dependencies section).

## Risks and gotchas
- The reconciliation walk must match "any existing group owning ≥1 command from `cmds`" per
  the spec — not require the dest group's command *set* to equal `cmds` exactly — since the
  spec explicitly frames it as "for every existing group that owns at least one command from
  `cmds`." Today's `settings-hooks.json` groups are single-command or fixed-set, so this is
  low-risk in practice (noted as an accepted risk in the story itself), but the implementation
  should still walk `dst_groups`, not assume a single match.
- `changed` currently holds bare event-name strings consumed only by the final
  `', '.join(changed)` printout — appending `f"{event} (matcher)"` is safe and additive; do not
  change the `changed.append(event)` call in the new-group append branch.
- The new fixture cases must each run in their own fresh sandbox/HOME (mirroring the existing
  `SANDBOX="$(mktemp -d ...)"` + `assert_sandboxed` pattern) so they don't interfere with the
  existing run1/run2 pair or each other — do not reuse `$FAKE_HOME`/`$SETTINGS` from the
  existing cases for the new ones without re-seeding first.
- Verifying "fails pre-fix" is a development-time check only (`git stash`); it is not itself a
  committed test step, since the fixture harness has no mechanism to check out old code.

## Open questions
None.
