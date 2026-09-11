---
title: refresh-live-post-push.sh must recognize `git -C <worktree> push`
slug: fix-refresh-live-git-c-cwd
sprint: 2026-09-11-004
kind: service
created: 2026-09-11T00:00:00Z
---

# refresh-live-post-push.sh must recognize `git -C <worktree> push`

## Statement

Jonathan (verbatim, from the prior session's handoff, describing an open question raised while
reading the hook): "Fix Skills/dev-story-sprint/assets/hooks/refresh-live-post-push.sh's
cwd-matching so a push run via `git -C <worktree> push` (cwd stays at the caller's actual
directory, not the worktree) is still recognized as coming from the same repo as the live
worktree — currently only a literal `cd <repo> && git push` triggers the auto-refresh." He has
now said "go ahead and fix them now."

Restatement: the PostToolUse hook only fast-forwards `~/Source/claude-skills-main` when it can
prove the `git push` it just observed came from a checkout of the same repository as that live
worktree. It does this by comparing `git -C "$LIVE" rev-parse --git-common-dir` against
`git -C "$CWD" rev-parse --git-common-dir`, where `$CWD` is `tool_input.cwd` from the PostToolUse
JSON payload — the Bash tool's actual working directory for that call. `claude-skills`'s own
`CLAUDE.md` (repo convention) recommends exactly the pattern this hook fails on: "work in a
detached scratch worktree and push with `HEAD:main`" or otherwise use `git -C <path> push`
without `cd`-ing there first, specifically so concurrent sessions sharing the checkout don't
switch each other's branch. When a push is issued as `git -C /path/to/some/worktree push`
from an unrelated cwd (e.g. the orchestrator's own working directory, not inside the repo at
all), `$CWD` never reflects `/path/to/some/worktree`, so `CWD_COMMON` resolves to the wrong
repository (or errors) and the refresh never fires — even though the push target was, in fact,
the tracked repo.

## Requirements

R1. The hook must resolve the actual git working directory the `git push` command operated
    against by parsing `-C <path>` argument(s) out of the observed shell command, not solely by
    trusting `tool_input.cwd`.
R2. Multiple `-C` flags on the same `git` invocation must compose the way real `git` composes
    them: each subsequent `-C <path>` is resolved relative to the previous one (git's own
    documented `-C` semantics), starting from `tool_input.cwd` as the base for the first.
R3. A relative `-C <path>` resolves relative to the preceding directory (first `-C`: relative to
    `tool_input.cwd`); an absolute `-C <path>` is used as-is.
R4. When there is no `-C` flag on the `git` invocation that runs `push`, behavior is unchanged:
    fall back to `tool_input.cwd` exactly as today (covers the working `cd <repo> && git push`
    case and plain `git push` from inside the repo).
R5. The command-string parsing must not break on the existing guard clauses — still exit 0 with
    no output when `tool_name != Bash`, when the command isn't a real push (`--dry-run`, or no
    `git push` substring), when stdin is empty, or when python3 is unavailable.
R6. Everything downstream of the CWD resolution (the `$LIVE_COMMON` / `$CWD_COMMON` comparison,
    the fetch/merge, the settings-allowlist re-merge) is untouched.

## Specification

File: `Skills/dev-story-sprint/assets/hooks/refresh-live-post-push.sh`.

Extend the existing `python3` one-shot JSON parser (currently emitting
`TOOL|PUSH|CWD` joined by `|`) to also compute and emit a resolved git-target directory:

```python
import json, os, shlex, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
cmd = (d.get("tool_input") or {}).get("command") or ""
push = "git push" in cmd and "--dry-run" not in cmd
cwd = str(d.get("cwd") or "")

git_dir = cwd
try:
    tokens = shlex.split(cmd)
except ValueError:
    tokens = []
i = 0
while i < len(tokens):
    if tokens[i] == "git":
        j, resolved = i + 1, cwd
        while j + 1 < len(tokens) and tokens[j] == "-C":
            p = tokens[j + 1]
            resolved = p if os.path.isabs(p) else os.path.join(resolved, p)
            j += 2
        git_dir = resolved
        i = j
    else:
        i += 1

print("|".join([str(d.get("tool_name", "")), "PUSH" if push else "NOPUSH", cwd, git_dir]))
```

Notes on the walk: it scans every `git` token in the command (handles `&&`-chained commands —
`shlex.split` tokenizes across chaining operators the same as words, which is fine since we only
key off the literal token `"git"`), and for each one collects any immediately-following `-C
<path>` pairs, composing them onto the running `resolved` base. The **last** `git` invocation
encountered in the command wins for `git_dir` — matching the existing loose `"git push" in cmd`
check, which already only cares whether a push occurred somewhere in the string, not which exact
invocation. `os.path.isabs` treats a `~`-prefixed path as relative (correct: bash would have
expanded `~` before `git` ever saw it, since `shlex.split` runs on the already-expanded command
string as received in `tool_input.command` — no `os.path.expanduser` needed).

Bash side: change

```bash
IFS='|' read -r TOOL PUSH CWD <<<"$PARSED"
[ "${TOOL:-}" = "Bash" ] && [ "${PUSH:-}" = "PUSH" ] || exit 0
[ -n "${CWD:-}" ] || CWD="${CLAUDE_PROJECT_DIR:-$PWD}"
```

to

```bash
IFS='|' read -r TOOL PUSH CWD GITDIR <<<"$PARSED"
[ "${TOOL:-}" = "Bash" ] && [ "${PUSH:-}" = "PUSH" ] || exit 0
[ -n "${CWD:-}" ] || CWD="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -n "${GITDIR:-}" ] || GITDIR="$CWD"
```

and change the one existing use of `"$CWD"` in the repo-identity check to `"$GITDIR"`:

```bash
CWD_COMMON="$(git -C "$GITDIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
```

`$CWD` stays used only for the `GITDIR` fallback above; nothing else in the file references it.

## Dependencies, risks, and breaking changes

- No dependency on the other story in this sprint (`fix-install-matcher-upgrade`) — different
  file, different concern.
- No external services or credentials. Runs only against synthetic JSON piped to the script in
  tests — no real git push is executed by the fixture.
- Risk: `shlex.split` can raise on a command with an unterminated quote; already guarded by the
  existing `try/except ValueError` pattern used elsewhere in this codebase's hook parsers — keep
  the same guard here (falls back to `git_dir = cwd`, i.e. today's behavior, not a crash).
- Not a breaking change: purely additive detection; every command shape that worked before
  (`cd <repo> && git push`, plain `git push`) still resolves to the same `GITDIR = CWD` fallback
  it did before, since the parser only overrides `git_dir` when it actually sees a `-C` flag on
  a `git` token.

## Acceptance criteria

- AC-I: integration test exists at
  `Skills/dev-story-sprint/assets/tests/refresh-live-post-push-fixtures.sh` and exercises the
  **running** script end to end — piping synthetic PostToolUse JSON payloads to the actual
  `refresh-live-post-push.sh` in a sandboxed `$HOME` with two real throwaway git repos standing
  in for "live worktree" and "caller checkout" (both clones/worktrees of one throwaway origin,
  so their `--git-common-dir` can genuinely match), asserting on the script's stdout/stderr and
  on whether the sandboxed live worktree actually advanced — and exits 0.
- AC1: a payload whose `tool_input.command` is `git -C <path-to-the-matching-worktree> push`
  and whose `tool_input.cwd` is a directory **unrelated** to that repo (e.g. `$HOME` itself)
  is recognized as the same repository as the live worktree and triggers the refresh (this is
  the case that fails against the pre-fix script — prove it fails first, then passes after the
  fix).
- AC2: the existing working case, `cd <repo> && git push` (payload cwd already equal to the
  repo, no `-C` flag), still triggers the refresh unchanged.
- AC3: a plain `git push` from inside the repo (cwd = repo, no `-C`) still triggers the refresh
  unchanged.
- AC4: a `-C` pointing at a directory that is **not** the live worktree's repo (a third,
  unrelated throwaway repo) does **not** trigger the refresh — proves the fix doesn't turn the
  check into a rubber stamp.
- AC5: an untouched-guard case — `tool_name` other than `Bash`, or a command containing
  `--dry-run`, or empty stdin — still exits 0 with no side effects, same as today.

## Out of scope

- Relative `-C` composition beyond two levels is implemented per R2 but not required to be
  separately fixture-tested beyond one representative case — git's own `-C` chaining semantics
  are not this story's subject.
- item 4 (`install.sh` matcher merge) — separate story in this sprint.
- Any change to what triggers a refresh once repo identity is established (fetch/merge/allowlist
  re-merge logic) — untouched.

## Open questions

None.
