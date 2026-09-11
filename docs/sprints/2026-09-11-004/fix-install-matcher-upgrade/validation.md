# fix-install-matcher-upgrade — validation

Run against integration branch `sprint/2026-09-11-004` at commit `88714cf`, UTC 2026-09-11T20:55Z.

Command: `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/install-matcher-fixtures.sh`
Result: exit 0, 17 cases, 0 failures.

| AC | Check | Result |
|---|---|---|
| AC-U | fresh-install run1/run2 cases still pass unchanged (5 + 4 = 9 rows) | PASS — all 9 rows PASS |
| AC-I | new upgrade case: stale `context-budget-gate.sh` matcher reconciled to source (`""`), exactly one PreToolUse group owns the command (no duplicate appended) | PASS — 3 rows PASS |
| AC1 | idempotence of the upgrade case (second run byte-identical) | PASS |
| AC2 | absent-matcher reconciliation: `cancel-gate.sh` group with an erroneous matcher key ends up with no matcher key, exactly one group | PASS — 2 rows PASS |

Pre-fix-fails confirmation (development-time only, per plan's Risks section): executor confirmed
via `git apply -R` / `git apply` round-trip on the fix commit that the new upgrade/absent-matcher
cases fail against the pre-fix `install.sh`, then restored the fix and re-ran to the passing
result above.

All acceptance criteria pass. Story done.
