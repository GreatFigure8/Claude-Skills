# Worktree provisioning and the gate declaration

The capability surface: how a freshly-cut worktree is made **able to run its gates**, and
what "the gates" means for a given item. Implemented by
`assets/claude-config/bin/worktree-provision.sh`; the permission surface it sits beside is
`references/autonomy-control-surface.md`.

**Epic 11 item 2b shipped the mechanism; item 3 is the caller.**
`PROVISION_DISPATCH_WIRED=yes` in the library is that claim in a form a fixture asserts.
`bin/dispatch.sh` calls `provision_preflight` before every executor it starts and refuses
the dispatch outright when the smoke check fails — see `references/l2-dispatch.md`. There
is exactly **one** caller, and it is a dispatch path, which is what keeps "a drafting
worktree is never provisioned" true by construction rather than by care.

## Why this exists

Measured on the first real dispatch, 2026-08-21, not anticipated. A fresh `git worktree add`
produces a checkout that **cannot run its own test suite**:

- the environment file the suite reads is **gitignored**, so it is not in the worktree — the
  run died with `RuntimeError: DB_PASSWORD is not set`
- `node_modules` is per-worktree and absent until something installs it

The attended executor hit `7 failed, 1554 passed, 9 errors`, recognised the shape as
provisioning rather than regression, copied the file, ran the install and carried on. **An
unattended executor has no such nerve.** The failure looks exactly like a broken change, so
the outcomes available to it are a false `blocked`, a false red pull request, or — worst — a
run that decides the gates are unrunnable, reports them skipped, and opens the PR anyway.

**Second finding, same dispatch: the gate set is per item type, not per repo.** That repo's
repo-wide gate script is `ruff` plus `pytest` twice and covers **zero TypeScript**. It runs
none of the tests covering a `.tsx` work item. The dispatch brief that said "the gate is
`test-both.sh`" was the orchestrator's, and it was wrong; the executor ran the right gates
from repo precedent rather than from instruction. That is judgement, and judgement is the one
thing an unattended runner does not have — so the gate set is **declared**, per item type,
and handed to the executor in its brief.

## A repo that declares nothing gets today's behaviour

A bare worktree: no copy, no install, no smoke check, and not one extra line of log. That is
a definition-of-done clause, not a nicety, and `provision_resolve` takes a deliberately
silent path for it — the same silent path `autonomy_resolve` takes for a repo with no
section, for the same reason.

## The config file

```
~/.config/claude-intake/provisioning        overridable with INTAKE_PROVISION_FILE
```

Same INI shape as the autonomy config: `[section]` headers that are either a checkout
**path** (starts with `/` or `~`) or an `owner/name` **slug**, with `key = value` lines under
them. `[global]` has no meaning here and is refused — every key in this file is per repo.

```ini
[/Users/jonathanstevenson/Source/LODE]
env-files        = .env, apps/api/.env.local
install          = pnpm install --frozen-lockfile
smoke            = pnpm --filter web exec tsc --noEmit
gates.api        = bash scripts/test-both.sh
gates.web        = pnpm --filter web test
gates.tsx        = pnpm --filter web test
integration-test = pnpm run test:e2e
```

| Key | Meaning |
|---|---|
| `env-files` | comma-separated **repo-relative** paths, copied from the source checkout into the worktree |
| `install` | one shell command, run with the worktree as cwd |
| `smoke` | one shell command that **proves the gates can run**. Required of any section that declares anything |
| `gates.<type>` | the gate command for an item type. `<type>` is letters, digits, dot, dash or underscore |
| `integration-test` | **one** command, run once per **issue** — after every one of its work items has merged and before it closes, never per item type. Consumed by `session-loop.sh` (epic 21 item 5), not by `provision_preflight`: it runs against the canonical checkout at the integration branch's tip, post-merge, never inside a per-item dispatch worktree |

**A section that declares anything must declare `smoke`.** It is claiming "a worktree of this
repo can run its gates", and `smoke` is the only part of that claim which is ever *checked* —
the same rule, for the same reason, as a repo above L0 having to state a size ceiling. A gate
that has never been shown to run is a hope, and this whole item exists because a hope failed.

`env-files` entries must be repo-relative with no `..` and no glob. Absolute paths and `~`
are refused because "provisioning" that reaches outside the source checkout is not
provisioning. Globs are refused because a glob that matches nothing copies nothing and says
nothing, which is the silent-degrade failure this item exists to remove.

### Why a third sibling file and not more keys in `autonomy`

1. **`autonomy` is a permission surface.** `env-files`, `install`, `smoke` and `gates.*` grant
   nothing — they are **capability**: how to make a checkout able to run, and what running
   means. Editing a permission file for a non-permission reason is what the `repos`-versus-
   `autonomy` split already refused, and the argument does not weaken for a third concern.
2. **Blast radius.** Any error anywhere in `autonomy` pins *every* repo to L0. A typo in an
   install command should not silently revoke a rung, and a revoked rung should not be how
   you find out about a typo.
3. **Version skew.** The autonomy parser refuses any key it does not know, so putting
   provisioning keys there would make an older copy of `autonomy.sh` refuse the whole file. A
   file the other reader never opens cannot do that to it.

### This file contains executable configuration, and says so

`install`, `smoke` and every `gates.*` value are shell commands the library runs. There is no
way to provision a checkout without running something, so the honest response is to guard the
source rather than pretend otherwise: the file must be a **regular file, owned by the user
running this, and not writable by group or other**. Anything else is refused and **nothing is
run** — the same standard the credential file is already held to. Commands run with the
worktree as cwd and are not sandboxed beyond that; a machine that can write your provisioning
file can already run code as you.

## The preflight, which is the whole point

```bash
provision_preflight "$REPO_PATH" "$REPO_SLUG" "$WORKTREE"   # rc 0 = may dispatch
```

1. **Resolve** the declaration for this repo. Nothing declared → rc 0, bare worktree, silent.
2. **Copy** each declared environment file. A file missing from the *source* checkout is a
   refusal, not a warning: a worktree cut from this repo cannot run its gates without it.
3. **Install**. A nonzero exit is a refusal carrying the exit code and the last 20 lines.
4. **Smoke**. This is the difference between "we provisioned" and "the gate can run". The
   measured failure had the file copied and *still* could not run, so checking that the copy
   happened is not the check that matters.
5. **Clean tree**, after both the install and the smoke check.

Every failure is a **refusal that names what failed and refuses to dispatch**, never a
warning. `PROVISION_REFUSAL` is a sentence a human can act on without opening a log.

### The clean-tree check, and why it refuses

After provisioning, `git status --porcelain` must be empty. Two different disasters share the
one check:

- a copied environment file that is **not gitignored in the worktree** is now an untracked
  file in a checkout an unattended executor is about to run `git add` in. **That is a
  credential in a pull request**, and the refusal names the file.
- an install that rewrites a lockfile has put changes into the executor's diff that the
  executor did not make and cannot explain.

Both are silent at the moment they happen and expensive later.

### A drafting worktree is never provisioned

Unattended intake (L0) drafts a plan and runs no gate, so it needs no install and no
environment file. Copying credential material into a worktree where a headless drafter holds
Write is a widened blast radius bought for nothing. Provisioning belongs to **dispatch**
worktrees only. The runner sources the library so that a malformed declaration is reported on
the timer rather than discovered at the first dispatch — and that is all it does with it.

## The gate declaration

```bash
provision_gates "$ITEM_TYPE"        # the commands, one per line
provision_gate_brief "$ITEM_TYPE"   # the block a dispatch brief carries verbatim
```

| The brief names… | What comes back |
|---|---|
| a declared type | its commands |
| a type that is **not** declared | **refused**, listing what is declared |
| no type at all | every declared gate, in **declaration** order |

**Never a fallback to "the repo's usual gate."** Running the wrong gate is the defect, and a
fallback is how you get one. Declaration order rather than sorted order, because an author
who wrote `web` before `api` meant something by it.

The brief is prose, because its reader is an executor agent and the measured failure was an
executor being *told* the wrong gate. It says where the list came from, forbids substituting
an equivalent, and forbids skipping one that looks unrelated to the diff.

## Resolution order

1. **No config file** — nothing declared, *silent*. This is today.
2. **Config refused or invalid** — rc 1, nothing provisioned, loud, no dispatch may proceed.
3. **A path section and a slug section both match** — rc 1. One repo, one section.
4. **No section for this repo** — nothing declared, *silent*. This is today.
5. **A section with no keys** — nothing declared, *silent*. It still counts for rule 3.
6. Otherwise, the declaration.

## Reading it without a session

```bash
bin/worktree-provision.sh --check --repo <path> --slug <owner/name>
bin/worktree-provision.sh --gates <type> --repo <path>
bin/worktree-provision.sh --brief <type> --repo <path>
bin/worktree-provision.sh --integration-test --repo <path> --slug <owner/name>
bin/worktree-provision.sh --preflight <worktree> --repo <path> --slug <owner/name>
```

`--check`, `--gates`, `--brief` and `--integration-test` are read-only. **`--preflight` is the only mode that
writes**: it copies, installs and runs the smoke command. Every mode's exit code agrees with
its text — a mode that prints "no dispatch may proceed" and exits 0 is a mode whose exit code
is a lie, and the exit code is the half a script reads.

## Fixtures

`assets/claude-config/hooks/tests/worktree-provision-fixtures.sh` — 178 cases.

The one that carries the item is **case K**: a synthetic repo is built with the measured
shape, the bare worktree is **required** to fail with `RuntimeError: DB_PASSWORD is not set`,
and only then is provisioning allowed to fix it and both declared gate sets run green. No
real product repo is named, touched, or needed for the suite to run.

Inertness is proven twice because the definition of done asks for it twice. At the library
level (cases A, B, C) no config, a config naming other repos, and an empty section all
resolve to a bare worktree with `PROVISION_LOG` empty. At the runner level (case N) the
shipped runner and a reconstruction of the pre-item-2b runner — built by deleting exactly the
40 lines the item added, refusing to run if the count is not 40 — are compared byte for byte
across the log, stdout, stderr and the call stream. **That pair alone would pass on a runner
that does nothing**, so the same pair is run again against a *malformed* config, where the
shipped runner must name the bad key and the reconstruction must be blind to it. Inertness
and discrimination are the same two runs.

Section M was "nothing is wired yet" for the whole of item 2b and is now "wired, and by
exactly one caller": the runner still only loads and validates, and the dispatcher is
asserted to call the preflight, to ask for the declared gate set, and to refuse the
dispatch when the preflight fails.

Four mutants each break a case that passes on the shipped library: an advisory smoke check, a
gate lookup that falls through instead of refusing an undeclared item type, a disabled
clean-tree check, and a disabled source guard.

The suite never reads or writes `~/.config/claude-intake`: `INTAKE_PROVISION_FILE` is set on
every invocation and `HOME` is redirected into the sandbox.
