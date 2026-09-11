# claude-skills — repo conventions

## Branching: `dev` integrates, `main` is live

- Cut every work-item branch from `origin/dev`.
- Merge it back to `dev` when it verifies — one merge commit per item.
- Merge `dev` into `main` (`--no-ff`) when the work is ready to go live, and push both.
- `main` is the live branch: `~/.claude/skills/*` and `~/.claude/agents/story-item-executor.md`
  are symlinks **into this checkout** (`~/Source/claude-skills`), so whatever branch is checked
  out here is what Claude Code loads. Keep `main` checked out when not actively developing.
  There is no separate live worktree any more (retired 2026-09-11).

In a `dev-story-sprint` plan message this means the branch line reads
`live=main  integration=dev`.

## The checkout is shared

Concurrent sessions work in this same checkout and switch its branch out from under each
other. Before any commit or merge, either check `git branch --show-current` in the same
command, or work in a detached scratch worktree and push with `HEAD:main`.
