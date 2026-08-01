# Git conventions

## Branch line

Three roles, named explicitly at the start of every epic:

| Role | Purpose | Rule |
|---|---|---|
| Live / cutover | what's deployed or about to be | untouched during an epic; receives one merge at close |
| Integration | where work items land and get exercised together | target of every work-item PR |
| Work item | one plan item, one PR | short-lived; deleted after merge |

If the repo has drifted (a stale long-running branch, divergent history), reconcile
it as step zero — collapse, tag, branch fresh — instead of carrying divergence into
every item.

## Branch naming

`<type>/<epic-slug>-<item-slug>`

Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `perf`, `build`.

```
feat/fusion-platform-core-foundation
refactor/transport-oic-client
fix/oic-transport-scope-precedence
chore/uv-workspace-lockfile
```

Lowercase, hyphenated, no ticket-number-only names — the slug should still mean
something in `git branch -a` six months later.

## Tags

Tag before anything expensive to reconstruct: platform restructures, framework
migrations, monorepo moves, dependency-manager swaps.

```
git tag -a pre-<epic-slug> -m "state before <epic name>"
git push origin pre-<epic-slug>
```

Tag the live branch again at epic close.

## Commits

Conventional commits with a scope that names the package or module:

```
feat(core): two-slot session store with per-slot credential resolution
refactor(move): relocate admin UI to ui/ — no behavior change
fix(oic): honor scope precedence when both call and session set it
test(core): parity fixture for envelope decrypt
chore(build): add root uv lockfile
```

Rules that matter more than the format:

- **One reversible idea per commit.** If the message needs "and", it's two commits.
- **Pure moves are their own commit**, prefixed `refactor(move):`, containing zero
  logic change, and the body says so. This is the only thing that makes a large
  restructure reviewable — a reviewer can trust the move commits and read the rest.
- **Commit early.** The tree should be committable within the first few minutes of
  real work, not at the end.
- **Commit often.** Before every sync, before every context switch, before every
  session ends. Uncommitted work is unbacked work.
- **The body carries the why**, especially for anything a reviewer would otherwise
  have to reconstruct: a proven-parity fixture, a deliberate deviation, a deferred
  follow-up (reference the plan's Deferred entry by name).

## Sync

- Push the work-item branch on its first commit — `git push -u origin <branch>` —
  then keep pushing as you go.
- Rebase onto the integration branch at least daily and always immediately before
  opening the PR:
  ```
  git fetch origin
  git rebase origin/<integration-branch>
  ```
- Rebase work-item branches (linear, reviewable). Merge into the integration and
  live branches (preserves the landing points, keeps merge-revert available as
  rollback).
- Configure pulls to fail rather than create surprise merges: `git config pull.ff only`.
- Never rebase a branch someone else has based work on; merge instead.

## PR body template

```markdown
## Work item
Epic <name>, item <N> — <title>. Plan: <link/path>

## In scope
- <bullet per change, matching the plan's scope>

## Deliberately not in scope
- <the adjacent thing that was tempting; where it went in Deferred>

## Verification
- <command run> → <result>
- <grep/query that proves the promised deletion or addition>
- Gates: <lint / types / tests / build results>

## Rollback
Revert this merge commit. | Restore from tag <tag>.
```

## Verification commands

Before claiming any item is done:

```
git log --oneline <base>..HEAD          # is the story of the branch the planned story?
git diff --stat <base>...HEAD           # do the touched paths match the scope?
git diff <base>...HEAD -- <path>        # read the actual change in the risky file
git grep -n "<symbol>"                  # does the promised addition exist?
git grep -n "<removed-symbol>"          # does the promised deletion really return nothing?
```

The deletion check is the one that catches "reported complete but silently did not
land." Run it every time an item claims to remove, replace, or align something.
