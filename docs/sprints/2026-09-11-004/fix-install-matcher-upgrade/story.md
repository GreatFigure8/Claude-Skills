---
title: install.sh settings merge must update a stale matcher on an existing hook
slug: fix-install-matcher-upgrade
sprint: 2026-09-11-004
kind: service
created: 2026-09-11T00:00:00Z
---

# install.sh settings merge must update a stale matcher on an existing hook

## Statement

Jonathan (verbatim, from the prior session's handoff): "Fix install.sh's settings.json merge
to reconcile an existing hook's matcher, not just append new ones — fix the merge logic in
`Skills/dev-epic-workflow/assets/claude-config/install.sh` (python block starting ~line 116) so
a source group whose command already exists but whose matcher differs updates the existing
entry instead of being skipped outright." Deferred earlier in the day pending his go-ahead;
he has now said "go ahead and fix them now."

Restatement: `install.sh --user` (and repo mode) merges `settings-hooks.json` into the target
`settings.json` by, per event, checking whether a source group's hook commands are already a
subset of the destination's commands for that event and skipping the group entirely if so. This
means once a hook is installed, a later change to the *matcher* shipped in `settings-hooks.json`
never reaches an existing installation — only a fresh install picks it up. This was found by
hand: `context-budget-gate.sh`'s PreToolUse matcher had drifted stale on Jonathan's own machine
and had to be hand-edited to `""` because re-running `install.sh --user` silently left it alone.

## Requirements

R1. When a source hook group's command set is already present in the destination (any existing
    group under that event owns all of those commands), and that source group carries a
    `matcher` value different from the destination group's current matcher (including one of
    them lacking a `matcher` key entirely), the merge must update the destination group's
    matcher to match the source's — in place, not by appending a duplicate group.
R2. When the matcher already matches (or the source group also lacks a `matcher` key and so
    does the destination), nothing changes — behavior is unchanged from today's idempotent
    "already up to date" case.
R3. Existing behavior is preserved for the only other two cases the merge handles: a source
    group whose commands are entirely new (append it, as today) and `statusLine` (set only if
    absent, never touched otherwise).
R4. The fresh-install path (`install-matcher-fixtures.sh`'s existing two runs) must keep passing
    unchanged — this is a strictly additive fix to the merge, not a rewrite of its shape.

## Specification

File: `Skills/dev-epic-workflow/assets/claude-config/install.sh`, the inline `python3` heredoc
that starts at the `# 2. Merge hook wiring into settings.json without clobbering.` comment
(around line 84 in the current file; the block Jonathan referred to by its old line number
~116).

Current logic, per event, per source group:

```python
existing_cmds = {
    h.get("command")
    for g in dst_groups if isinstance(g, dict)
    for h in g.get("hooks", []) if isinstance(h, dict)
}
for group in src_groups:
    cmds = {h.get("command") for h in group.get("hooks", [])}
    if cmds <= existing_cmds:
        continue  # already installed
    dst_groups.append(group)
    changed.append(event)
```

New logic: when `cmds <= existing_cmds` (the "already installed" branch), before `continue`,
walk `dst_groups` and, for every existing group that owns at least one command from `cmds`,
compare its `matcher` to the source group's `matcher`:

- If the source group has no `"matcher"` key, the destination group must not have one either —
  if it does, remove it (`g.pop("matcher", None)`).
- If the source group has a `"matcher"` key, set the destination group's `"matcher"` to that
  value if it differs (covers both "different string" and "destination has no matcher key").
- Record the event name in `changed` when an update actually happened, so the printed summary
  at the end (`added: {', '.join(changed)}`) reflects it. Use a distinct marker so the existing
  "(already up to date)" vs "(added: …)" print at the bottom stays truthful — e.g. append
  `f"{event} (matcher)"` to `changed` rather than the bare `event`, so a run that only fixed
  matchers doesn't claim to have "added" a hook.

No other part of `install.sh` changes. The `statusLine` branch, the new-group append branch,
the `.gitignore` block, and the commit/echo tail are untouched.

## Dependencies, risks, and breaking changes

- No dependency on the other story in this sprint (`fix-refresh-live-git-c-cwd`) — different
  file, different concern.
- No external services or credentials.
- Risk: over-matching — a destination group that happens to share one command with a source
  group but is conceptually a different group (not expected given today's `settings-hooks.json`,
  where every group has a distinct single command or a fixed command set) could have its matcher
  overwritten incorrectly. Accepted: the fix only needs to handle the shapes that actually exist
  in `settings-hooks.json` today, proven by the existing fixture's source-shape assertions.
- Not a breaking change: this only changes behavior for machines re-running `install.sh` against
  an already-installed, stale-matcher settings.json — a strict bug fix.

## Acceptance criteria

- AC-U: unit/fixture gate passes — `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/install-matcher-fixtures.sh` exits 0, including its two existing fresh-install runs (AC-U1) unchanged.
- AC-I: a new *upgrade* fixture case, added to `install-matcher-fixtures.sh` (or a sibling
  fixture file run by the same suite), exercises the scenario the existing harness cannot:
  1. Write a synthetic `$FAKE_HOME/.claude/settings.json` that already has a `PreToolUse` group
     for `context-budget-gate.sh`'s command with a **stale** matcher (a value different from
     `settings-hooks.json`'s current source matcher — e.g. a specific tool-name matcher instead
     of the source's `""`).
  2. Run `install.sh --user` against that `$FAKE_HOME` once.
  3. Assert the resulting `settings.json`'s matcher for that command now equals the source's
     current matcher (uses the harness's existing `matcher_shape` helper).
  4. Assert no duplicate group was appended (still exactly one `PreToolUse` group owning that
     command).
  This case must fail against the pre-fix `install.sh` and pass after the fix (proves the
  fixture actually exercises the bug).
- AC1: re-running the new upgrade case a second time (idempotence) leaves `settings.json`
  byte-identical to the first upgrade run's result.
- AC2: a source group whose `matcher` key is entirely absent (e.g. `cancel-gate.sh`'s
  PreToolUse group) reconciles a destination copy that has an erroneous `matcher` key by
  removing it, not by leaving it or erroring.

## Out of scope

- Any change to what `settings-hooks.json` itself declares (its matchers are correct today;
  this fixes only the merge's failure to *propagate* future changes).
- Repo-mode (`install.sh` without `--user`) is not separately fixture-tested here — the merge
  python block is shared code, so the `--user` fixture proves the fix for both modes.
- item 5 (`refresh-live-post-push.sh` cwd-matching) — separate story in this sprint.

## Open questions

None.
