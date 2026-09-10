# The autonomy control surface

**Retired as a ladder (epic 21 item 1, 2026-09-10).** Epics 11 and 19 built a five-rung
permission ladder (`L0`–`L4`) here, gated on a human-authored grant record, that let an
unattended cycle escalate from drafting through execute, approve, merge and chain. No such
grant record has ever existed on this machine — the ladder never actually ran live. Epic 21
replaces it outright: a session-scoped loop that Jonathan starts explicitly *is* the grant
of full autonomy for that session, with a harm floor (epic 21 item 2) as the only in-flight
brake. Both epics are closed; see their plans for the full retros.

Implemented by `assets/claude-config/bin/autonomy.sh`. What's left of it is no longer a
permission surface — it is a small, ladder-independent policy surface: a sensitive-path
denylist, an optional per-repo size ceiling, and the two kill-switch presence files. Every
function that granted or checked a level (`autonomy_may_approve`, `autonomy_may_merge`,
`autonomy_may_chain`, the promotion-record reader, the per-cycle budget) no longer exists.

## What survives

| Piece | Function(s) | Purpose |
|---|---|---|
| Denylist floor | `AUTONOMY_DENY_FLOOR`, `autonomy_deny_diff_paths` | Sensitive paths (CI config, credentials, the control plane itself) that no diff may touch, whatever else is configured |
| Size ceiling | `autonomy_check_size`, `autonomy_diff_size` | Optional per-repo `max-files` / `max-diff-lines` |
| Kill switches | `autonomy_stop_requested`, `autonomy_override_active` | `STOP` and `AUTONOMY-OFF`, unchanged in meaning |

## The three files that remain

```
~/.config/claude-intake/autonomy        the config: deny-paths / size ceiling, per repo
~/.config/claude-intake/AUTONOMY-OFF    presence pins every repo to the built-in floor only
~/.config/claude-intake/STOP            presence prevents a cycle starting at all
```

`~/.config/claude-intake/promotions/` is gone — nothing reads or writes a grant record.

Every remaining path is overridable — `INTAKE_AUTONOMY_FILE`, `INTAKE_AUTONOMY_OVERRIDE`,
`INTAKE_STOP_FILE` — which is how fixtures run hermetically.

### `AUTONOMY-OFF` and `STOP` are still not the same control

| | `AUTONOMY-OFF` | `STOP` |
|---|---|---|
| What it revokes | this repo's own `deny-paths`/size-ceiling additions | the whole cycle |
| What keeps running | the built-in denylist floor | nothing |
| Checked | per repo, at resolution | once, before anything else |
| Undo | `rm` the file | `rm` the file |

Both are **presence signals**: contents are never read, `touch` is the whole interface, and
`ls ~/.config/claude-intake/` is the whole status check.

## The config file

```ini
# comments and blank lines are ignored
[/Users/jonathanstevenson/Source/LODE]      # a PATH section (starts with / or ~)
deny-paths     = alembic/*, api/config.py
max-files      = 40
max-diff-lines = 800

[GreatFigure8/Claude-Skills]                # a SLUG section (owner/name)
deny-paths = generated/*
```

A section header beginning `/` or `~` is a checkout **path**; anything else must be an
`owner/name` **slug**. If **both** a path section and a slug section match one repo, that
is a conflict, not a merge: the repo resolves the built-in floor only, and the log names
which two sections collided.

There is no `[global]` section any more — the only things left to configure are per-repo,
so there is nothing left for a global section to hold.

### Keys

| Key | Meaning |
|---|---|
| `deny-paths` | comma-separated globs, **added** to the built-in floor |
| `max-files` | ceiling on files touched by the diff (optional) |
| `max-diff-lines` | ceiling on added + deleted lines (optional) |

**Any error anywhere refuses the whole file** and every repo resolves the built-in floor
only, loudly. A config with a typo is a config whose author's intent is unknown, and the
safe reading of an unknown intent about a size ceiling is "the floor only, nothing looser".

## The denylist is checked against the diff, never against a declaration

A work item's plan says what it intends to touch in **prose**. That is not machine-readable
— it is why epic 10 exists — so a declaration-based check would be checking the wrong
thing. The denylist function takes paths on **stdin and nothing else**:

```bash
git -C "$WT" diff --name-only "$BASE...HEAD" | autonomy_deny_diff_paths
# rc 0 = clean;  rc 1 = refused, and every denied path is printed as `<path><TAB><pattern>`
```

Matching is shell `case` globbing over the full repo-relative path, so **`*` crosses `/`**
— `.github/*` matches `.github/workflows/ci.yml`. Each pattern is also tried as
`<pattern>/*`, so a bare directory name covers its contents.

23 built-in patterns are **always** in force and **no config key shrinks them** —
`deny-paths` only adds. They cover CI and workflow configuration, `install.sh`, the
control-plane hooks and this file itself, launchd job definitions, and credential material
(`.env`, `*.pem`, `*.key`, `*.p12`, `id_rsa*`, `*/secrets/*`, `.npmrc`, `.netrc`).

## Reading it without a session

```bash
bin/autonomy.sh --check                              # config, override, stop, floor
bin/autonomy.sh --check --repo <path> --slug <owner/name>
bin/autonomy.sh --check --repos ~/.config/claude-intake/repos   # every configured repo
git diff --name-only | bin/autonomy.sh --deny-paths --repo <path> --slug <owner/name>
```

Read-only in every mode.

## What comes next

Epic 21 item 2 combines the pieces above with two new guards (an irreversible-git-op guard
and a cross-epic collision guard) into a single `autonomy_harm_check()` — the harm floor
that runs before every merge or chain action inside the session-scoped loop (epic 21 item
3). See `docs/epics/21-session-scoped-issue-loop/plan.md`.
