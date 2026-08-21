# The autonomy control surface

The switchboard that governs what the unattended machinery may do without a human.
Implemented by `assets/claude-config/bin/autonomy.sh`; read by
`assets/claude-config/bin/unattended-intake.sh`.

This file is the **permission** surface: what the machine may do. Its sibling
`references/worktree-provisioning.md` is the **capability** surface: whether a worktree can
actually run the gates at all, and what the gates are for a given item type. Separate files
for the same reason `repos` and `autonomy` are separate — see "Why a sibling file" below.

**As shipped by epic 11 item 1 this surface is inert.** Everything below is parsed,
validated, resolved and logged, and **nothing acts on it**. `AUTONOMY_ENFORCED=no` in
the library is that claim in a form a fixture asserts. Item 3 is what wires it.

## The ladder

Per repo, defaulting to `L0`. Silence means `L0`; so does anything the surface refuses.

| Level | The machine may… | Human still owns |
|---|---|---|
| **L0** | draft a proposal PR and stop *(today)* | approval, dispatch, merge |
| **L1** | number the epic, file it, set `Status: approved` | dispatch, merge |
| **L2** | dispatch executors, open the PR, stop before merging | merge |
| **L3** | merge to the **integration** branch when every gate is green | promotion to live |
| **L4** | chain — pick the next admitted item without being asked | promotion to live |

`AUTONOMY_CEILING` is **L2**. L3 and L4 are refused with a message naming the ceiling,
not clamped silently — epic 11 builds one rung and says so.

## The four files

```
~/.config/claude-intake/autonomy        the config: level + policy + budget
~/.config/claude-intake/AUTONOMY-OFF    presence pins EVERY repo to L0
~/.config/claude-intake/STOP            presence prevents a cycle starting at all
~/.config/claude-intake/promotions/     human-authored promotion records
```

Every path is overridable — `INTAKE_AUTONOMY_FILE`, `INTAKE_AUTONOMY_OVERRIDE`,
`INTAKE_STOP_FILE`, `INTAKE_PROMOTIONS_DIR` — which is how fixtures run hermetically and
how you rehearse a change without touching the live config.

### `AUTONOMY-OFF` and `STOP` are not the same control

They are two files because they answer two different questions, and merging them costs
you the ability to ask the more likely one.

| | `AUTONOMY-OFF` | `STOP` |
|---|---|---|
| What it revokes | every rung above L0 | the whole cycle, L0 included |
| What keeps running | **unattended drafting** | nothing |
| Checked | per repo, at resolution | once, before anything else |
| Undo | `rm` the file | `rm` the file |

`AUTONOMY-OFF` is "I do not trust the dispatcher today" — proposals keep arriving while
nothing is dispatched. `STOP` is "stop the machine". It is honoured **before the binary
preflight, before the credential file is read, before the lock is taken and before any
GitHub call**, so it still works when the token has expired or `gh` is missing. A kill
switch that needs a healthy machine is a kill switch that fails when you reach for it.

Both are **presence signals**: contents are never read, `touch` is the whole interface,
and `ls ~/.config/claude-intake/` is the whole status check. No session, no config
archaeology, no knowing which repo is configured.

`STOP` exits **0**, not an error code. A stop is an order that was obeyed. A nonzero exit
on a 600-second launchd timer is noise that teaches a human to ignore the log.

## The config file

```ini
# comments and blank lines are ignored
[global]
budget.max-items        = 1
budget.max-wall-clock   = 60m
promotion.min-cycles.L2 = 1

[/Users/jonathanstevenson/Source/LODE]      # a PATH section (starts with / or ~)
level          = L2
require-labels = epic:planned
forbid-labels  = do-not-automate
deny-paths     = alembic/*, api/config.py
max-files      = 40
max-diff-lines = 800

[GreatFigure8/Claude-Skills]                # a SLUG section (owner/name)
level = L0
```

A section header beginning `/` or `~` is a checkout **path**; anything else must be an
`owner/name` **slug**. That is unambiguous, so the file can be written in whichever
identity the author has to hand — the path you configured or the slug the log prints. If
**both** a path section and a slug section match one repo, that is a conflict, not a
merge: the repo is pinned to L0 and told which two sections collided.

**Why a sibling file and not a third field on the `repos` line.** Epic 08 item 2 left the
choice open. The `repos` parse splits on the **last** pipe, because checkout paths contain
spaces and whitespace is not a safe separator — so `~/Source/LODE|dev|L2` parses as
`REPO_DIR=~/Source/LODE|dev`, `BASE_OVERRIDE=L2` under any copy of the reader that predates
the change. That failure is silent and it retargets the integration branch, which is the
exact class of defect epic 09 spent four items removing. Beyond that: `repos` is a
**membership** list and autonomy is a **permission**, and they deserve separate edits and
separate blast radius for the same reason `AUTONOMY-OFF` and `STOP` are separate files.

### Keys

| Section | Key | Meaning |
|---|---|---|
| `[global]` | `budget.max-items` | items a cycle may dispatch. Default **1** — "one item at a time" is an epic 11 invariant, not a preference |
| `[global]` | `budget.max-wall-clock` | `90s` / `45m` / `2h`, or bare seconds. Default **60m** |
| `[global]` | `promotion.min-cycles.L<n>` | clean cycles a promotion record must attest to. Default **1** |
| repo | `level` | `L0`–`L4`, case-insensitive |
| repo | `require-labels` | comma-separated; **all** must be present |
| repo | `forbid-labels` | comma-separated; **any** present refuses |
| repo | `deny-paths` | comma-separated globs, **added** to the built-in floor |
| repo | `max-files` | ceiling on files touched by the diff |
| repo | `max-diff-lines` | ceiling on added + deleted lines |

**A level above L0 must declare `max-files` and `max-diff-lines`.** Labels legitimately
default to empty; a size ceiling does not, because an unstated ceiling reads as *no*
ceiling, which is the opposite of a brake.

**Any error anywhere refuses the whole file** and every repo resolves L0, loudly. Per-section
isolation was considered and rejected: a config with a typo is a config whose author's
intent is unknown, and the safe reading of an unknown intent about permissions is "none".

## The denylist is checked against the diff, never against a declaration

A work item's plan says what it intends to touch in **prose**. That is not machine-readable
— it is why epic 10 exists — so a declaration-based check would be checking the wrong thing.

The denylist is therefore enforced **after the executor returns and before the PR is opened**,
against `git diff --name-only`. The library's function takes paths on **stdin and nothing
else**; there is deliberately no variant that accepts a plan, a scope block or a declaration.

```bash
git -C "$WT" diff --name-only "$BASE...HEAD" | autonomy_deny_diff_paths
# rc 0 = clean;  rc 1 = refused, and every denied path is printed as `<path><TAB><pattern>`
```

Matching is shell `case` globbing over the full repo-relative path, so **`*` crosses `/`**
— `.github/*` matches `.github/workflows/ci.yml`. That is deliberately unlike gitignore,
it is stated rather than discovered, and it errs toward matching more paths. Each pattern
is also tried as `<pattern>/*`, so a bare directory name covers its contents.

### The floor

23 built-in patterns are **always** in force above L0 and **no config key shrinks them** —
`deny-paths` only adds. They cover the classes epic 08's invariant names: CI and workflow
configuration, `install.sh`, the control-plane hooks and the unattended runner itself,
launchd job definitions, and credential material (`.env`, `*.pem`, `*.key`, `*.p12`,
`id_rsa*`, `*/secrets/*`, `.npmrc`, `.netrc`). A system that can remove its own guardrails
by editing config has no guardrails.

A denied path is not a deleted branch. The refusal leaves the work for a human and names
the path and the pattern that caught it.

## The promotion-record contract

**Defined by item 1. The evidence behind it is written by item 2. Read by item 3.**

A level above L0 is refused unless a promotion record grants it. The record is a
**human act** — the automation never writes this directory, because a system that can
write its own promotion evidence has widened its own permissions by another route.

```
path     <promotions-dir>/<owner>__<name>.<LEVEL>
example  ~/.config/claude-intake/promotions/GreatFigure8__Claude-Skills.L2
```

`ls` on that directory is a complete answer to "what is promoted to what".

```yaml
repo:       GreatFigure8/Claude-Skills
level:      L2
granted:    2026-08-21T10:00:00Z
granted-by: jonathanstevenson
cycles:     3
ledger:     /Users/jonathanstevenson/.config/claude-intake/ledger.jsonl
evidence:   cycles 41,42,43 — clean, no refusal, no blocked executor
```

All seven fields are **required**. A record that cites nothing is not evidence.

| Field | Validated as |
|---|---|
| `repo` | equals the repo's `owner/name` slug |
| `level` | equals the level being requested **and** the filename suffix |
| `granted` | `YYYY-MM-DDTHH:MM:SSZ` |
| `granted-by` | non-empty, and **not** one of `unattended-intake claude claude-code automation runner intake` |
| `cycles` | a non-negative integer, `>= promotion.min-cycles.<LEVEL>` |
| `ledger` | non-empty — the file the cycles were counted from (item 2's `ledger.jsonl`) |
| `evidence` | non-empty — which cycles, and why they were clean |

Every refusal **names what is missing**: `promotion record <path> is missing required
field(s): cycles ledger`, `…grants 'L1', not 'L2'`, `…attests 2 clean cycle(s); L2
requires 3`. Brakes are structural, not disciplinary — a refusal you cannot act on is
just an outage.

**How many clean cycles L3 requires is an open question in epic 11 and no number is
invented for it here.** L3 is refused as above-ceiling regardless.

## Resolution order

Highest precedence first. Every branch that is not the last one resolves **L0**.

1. **`AUTONOMY-OFF` present** — beats even a valid promotion record.
2. **Two sections claim this repo** — a path section and a slug section both match.
3. **Config malformed** — anywhere in the file.
4. **No section for this repo** — *silent*. This is the branch every unconfigured repo
   takes, and its silence is what makes an unconfigured machine byte-identical.
5. **`level = L0`**.
6. **Level above `AUTONOMY_CEILING`**.
7. **No valid promotion record**.
8. Otherwise, the configured level.

## Reading it without a session

```bash
bin/autonomy.sh --check                              # config, override, stop, budget, floor
bin/autonomy.sh --check --repo <path> --slug <owner/name>
bin/autonomy.sh --check --repos ~/.config/claude-intake/repos   # every configured repo
git diff --name-only | bin/autonomy.sh --deny-paths --repo <path> --slug <owner/name>
```

Read-only in every mode. The runner never invokes this path; it exists so a human — and a
fixture — can see the whole resolved surface without opening a session.

## Fixtures

`assets/claude-config/hooks/tests/autonomy-control-fixtures.sh` — 244 cases.

The one that matters is **case K, the inertness proof**: it reconstructs the runner as it
stood before this item by deleting exactly the 83 lines the item added (refusing to run at
all if the count is not 83), executes both against an identical unconfigured fixture, and
compares the gh/git/claude call stream, the log, stdout, stderr, the issue comments and the
drafted plan **byte for byte**. Only the timestamp, the case directory and the sandbox path
are normalised away, and each of those three is a property of the harness.

The suite is built brittle on purpose. It **aborts** rather than passing when the library is
absent or has lost its `AUTONOMY_ENFORCED` marker; case L runs the stop-file scenario against
that pre-item-1 runner and requires the cycle to **run**, so the passing case is
discriminating; and three library mutants — a shrunken denylist floor, an advisory override,
a pass-through promotion check — each break a case that passes on the shipped library.

It never reads or writes `~/.config/claude-intake`: `HOME` and all four control-file paths
are redirected into the sandbox.
