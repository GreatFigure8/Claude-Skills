# claude-skills — repo conventions

## Branching: we work against `main`

`main` is the branch we work against. There is **no per-story or per-epic integration
branch** in this repo.

- Cut every work-item branch from `origin/main`.
- Merge it back to `main` when it verifies — one merge commit per item.
- `main` is therefore both the integration point and the live branch: the skills that
  Claude Code actually loads are a worktree detached at `origin/main`
  (`~/Source/claude-skills-main`), so merging to `main` *is* going live.

In a `dev-story-sprint` plan message this means the branch line reads
`live=main  integration=none`, and the story closes on the last item's merge rather than
on a separate cutover merge.

## The checkout is shared

Concurrent sessions work in this same checkout and switch its branch out from under each
other. Before any commit or merge, either check `git branch --show-current` in the same
command, or work in a detached scratch worktree and push with `HEAD:main`.
