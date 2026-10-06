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
3. **Skill symlinks point at the working checkout.** `~/.claude/skills/*` link directly into
   `~/Source/claude-skills` (no agent symlinks: executors ship inside the dev-story-flow plugin) — there
   is no separate worktree pinned to `main`. This means whatever is currently checked out there
   (branch, and any uncommitted edit) is what every repo on the machine loads, live, the moment
   it's on disk. Nothing refreshes this automatically on push — re-run each skill's
   `assets/install.sh` (or the plain `ln -s` for a markdown-only skill) whenever you want the
   global copies to pick up a change. Land work on `dev`/`main` before relying on it being
   stable in other repos; a feature branch or a mid-edit file is visible everywhere the instant
   it's saved. See "The checkout is shared" below — the same caution applies to what other
   sessions load, not just to what they commit.
   **Exception: dev-story-flow and dev-bother-me-nope.** Each ships as a plugin (`Skills/<name>/.claude-plugin/`)
   from this repo's own local marketplace (`.claude-plugin/marketplace.json` at repo root) —
   installed and updated through the Claude Code plugin manager (UI or `claude plugin`),
   not a raw `~/.claude/skills` symlink. A local-path marketplace still re-reads this checkout
   live on update, so the "land on dev/main before relying on it" caution still applies; there
   is just no `install.sh` and no manual copy into `~/.claude/agents` or `~/.claude/hooks` for
   these two.
   **Every other skill is in the marketplace too**, one plugin per skill, so the plugin manager
   lists them all and installs each with one click. Those entries have no `plugin.json`: the
   marketplace entry is the manifest (`source: <skill dir>`, `strict: false`, `skills: ["./"]`,
   plus a `category` for its type). A new skill folder needs its own entry in
   `.claude-plugin/marketplace.json`, or it won't appear. A plugin install only loads the
   skill; anything a skill's `assets/install.sh` does beyond the symlink (e.g. dev-story-sprint's
   settings.json allowlist merge) still has to be run separately.

## The checkout is shared

Concurrent sessions work in this same checkout and switch its branch out from under each
other. Before any commit or merge, either check `git branch --show-current` in the same
command, or work in a detached scratch worktree and push with `HEAD:main`.
