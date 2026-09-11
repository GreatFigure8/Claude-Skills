# claude-skills — repo conventions

## Branching: `dev` integrates, `main` is prod, one branch per sprint

1. **`dev` is the integration branch. `main` is prod.** Work merges to `dev`; `dev` merges to
   `main` (`--no-ff`) when it is ready to go live. Push both.
2. **Every sprint gets its own branch**, `sprint/<sprint>`, cut from `origin/dev` and merged back
   to `dev` when the sprint completes. Parallel sprints may use worktrees but never have to.
   For dev-story-flow this means `sprint-state.sh new --live dev` (integration defaults to
   `sprint/<sprint>`); in a `dev-story-sprint` plan message the branch line reads
   `live=dev  integration=sprint/<slug>`.
3. **Skill symlinks always point at `main`.** `~/.claude/skills/*` and
   `~/.claude/agents/story-item-executor.md` link into `~/Source/claude-skills-main`, a worktree
   permanently checked out on branch `main` and never switched. A push to `main` fast-forwards it
   automatically (dev-story-sprint's post-push hook). `~/Source/claude-skills` is the working
   checkout (`dev` and sprint branches) and its branch never affects what Claude Code loads.
   Only when Jonathan explicitly says so, during a sprint, do the symlinks move to test
   something — rare, because changes are tested after they land on `dev` and `main`.

## The checkout is shared

Concurrent sessions work in this same checkout and switch its branch out from under each
other. Before any commit or merge, either check `git branch --show-current` in the same
command, or work in a detached scratch worktree and push with `HEAD:main`.
