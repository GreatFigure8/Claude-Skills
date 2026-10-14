# claude-skills — repo conventions

## Branching: `dev` integrates, `main` is prod, one branch per sprint

1. **`dev` is the integration branch. `main` is prod.** Work merges to `dev`; `dev` merges to
   `main` (`--no-ff`) when it is ready to go live. Push both.
   **After every release, `dev` and `main` are the same commit.** Nothing reaches `main`
   except a release from `dev`: never merge a feature, sprint or plugin branch straight into
   `main`. Before releasing, `git log --oneline origin/dev..origin/main` must print nothing;
   if it doesn't, merge `origin/main` into `dev` first. Right after pushing the release merge
   to `main`, fast-forward `dev` onto it (`git push origin origin/main:dev`, plus
   `git merge --ff-only origin/main` in any checkout on `dev`), and confirm
   `git rev-parse origin/dev origin/main` prints the same sha twice.
2. **Every sprint gets its own branch**, `sprint/<sprint>`, cut from `origin/dev` and merged back
   to `dev` when the sprint completes. Parallel sprints may use worktrees but never have to.
   For dev-story-flow this means `sprint-state.sh new --live dev` (integration defaults to
   `sprint/<sprint>`); in a `dev-story-sprint` plan message the branch line reads
   `live=dev  integration=sprint/<slug>`.
3. **Skills install from this repo's marketplace, not `~/.claude/skills` symlinks.** Every skill
   is a plugin in `.claude-plugin/marketplace.json` (repo root), a local-directory marketplace
   named `claude-skills`, installed and updated through the Claude Code plugin manager (UI or
   `claude plugin install <skill>@claude-skills`). dev-story-flow and dev-bother-me-nope ship
   their own `Skills/<name>/.claude-plugin/`; every other entry has no `plugin.json` — the
   marketplace entry is the manifest (`source: <skill dir>`, `strict: false`, `skills: ["./"]`,
   plus a `category` for its type). A new skill folder needs its own entry there, or it won't
   appear. Do not add symlinks into `~/.claude/skills` for skills in this repo — that loads
   them twice.
   A local-path marketplace reads this checkout, so whatever branch is checked out here (and
   any uncommitted edit) is what `claude plugin marketplace update claude-skills` and a plugin
   update pick up. Land work on `dev`/`main` before updating plugins, and run the update
   (`claude plugin marketplace update claude-skills`, then update the changed plugins) after a
   release so installed copies pick it up. See "The checkout is shared" below.
   A plugin install only loads the skill; anything a skill's `assets/install.sh` does beyond
   that (e.g. dev-story-sprint's settings.json allowlist merge, dev-epic-workflow's commands
   and hooks) still has to be run separately.

## The checkout is shared

Concurrent sessions work in this same checkout and switch its branch out from under each
other. Before any commit or merge, either check `git branch --show-current` in the same
command, or work in a detached scratch worktree and push with `HEAD:main`.
