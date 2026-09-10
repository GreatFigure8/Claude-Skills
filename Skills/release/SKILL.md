---
name: release
description: Cut a release for the current repo — open a PR into the repo's default branch, merge it on confirmation, tag the merged commit as major.minor.build (e.g. 0.1.1757520123), push the tag, then ask whether to release to prod and, if yes, detect and run whatever deploy process the repo actually has. Use whenever Jonathan says "release this", "cut a release", "ship a release", "tag a release", "version bump", "release to prod", or asks to turn the current branch's work into a versioned release. Generic across repos — no claude-skills-specific assumptions; works on any git repo with a `gh`-visible remote. Not for epic/story planning (that's dev-epic-workflow / dev-story-sprint) — this skill only handles the release mechanics once the code is ready to ship.
---

# Release

Turns finished work on a branch into a tagged release on the repo's default branch, and
optionally deploys it. Five steps, each with its own checkpoint — never collapse them into one
silent pass, because step 4 (merge) and step 7 (deploy) are both hard-to-reverse actions on
shared state.

1. Preflight
2. Version decision (major.minor, build)
3. PR into the default branch
4. Merge (on confirmation) and tag
5. Prod release (on confirmation), detected from the repo — never assumed

## 1. Preflight

- `git status` — working tree must be clean. Uncommitted changes: stop, tell Jonathan, do not
  stash or discard anything yourself.
- `git branch --show-current` — the branch being released. If it's already the default branch
  with nothing unmerged ahead of `origin/<default>`, there's no PR to open — skip to step 4's
  tagging with the current HEAD (nothing to merge, but a release can still just be "tag what's
  on main today").
- Determine the default branch: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`,
  falling back to `main`. This is a generic skill — don't assume `main` without checking, and
  don't assume this repo's own branching conventions apply to whatever repo it's invoked in.
- Confirm a `gh`-visible remote exists (`gh repo view`). If not, this skill can still tag
  locally but can't open a PR — say so and ask how Jonathan wants to proceed.

## 2. Version decision

Tags in this scheme are exactly three dot-separated integers: `major.minor.build`, e.g.
`0.1.1757520123`. No `v` prefix — match the existing tag format exactly if one exists.

- Find the latest release tag:
  `git tag --list | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1`
- If none exists, this is the first release: default to `major=0, minor=1` and say so.
- **Ask Jonathan** whether to bump major, bump minor, or keep the current major.minor —
  every release, don't guess or auto-detect from commit types. Show the current value when
  asking (e.g. "current is 0.1 — bump major, bump minor, or keep?").
- **Build number is a Unix epoch timestamp** (`date +%s`) taken at tag time — always
  increasing, needs no tracked state, and can't collide with a previous release. Compute it
  right before tagging in step 4, not earlier, so it reflects when the release actually landed.

## 3. PR into the default branch

- Push the branch: `git push -u origin <branch>` (skip if already pushed and up to date).
- Draft the PR from full history, not just the tip commit — `git log <default>..HEAD` and
  `git diff <default>...HEAD`, per the standard PR workflow: short title (under 70 chars),
  a summary of what changed and why, and a test plan.
- `gh pr create --title "..." --body "..."` targeting the default branch found in step 1.
- Report the PR URL and stop here if Jonathan just wanted the PR opened for review — don't
  assume "release" means "merge immediately." Proceed to step 4 only when he confirms.

## 4. Merge and tag

- **Explicit confirmation required before merging** — this changes the shared default branch.
  Ask plainly: "Merge #<n> into <default> now?"
- On yes: `gh pr merge <n> --merge` (a real merge commit, not squash/rebase, so the tag lands
  on a commit that actually exists in the PR's own history). If the repo's own CONTRIBUTING
  or CLAUDE.md specifies a different merge strategy, follow that instead.
- Fetch and check out the updated default branch locally: `git fetch origin` then
  `git checkout <default> && git reset --hard origin/<default>` — only ever reset a local
  branch that mirrors the remote you just fetched, never a branch with local-only work.
- Compute the build number now (`date +%s`) and tag:
  `git tag -a <major>.<minor>.<build> -m "release <major>.<minor>.<build>"`
- Push the tag: `git push origin <major>.<minor>.<build>`
- Report the final tag name plainly — this is the release identifier Jonathan will reference
  going forward.

## 5. Prod release

Ask exactly: **"Do you want to release this to prod?"**

- **No** → stop here. The tag exists; nothing else happens.
- **Yes** → detect the repo's actual deploy process. Never fabricate a deploy command or guess
  at one that "should" work — if nothing is found, say so and stop. Check in this order, using
  the first match:

  1. `package.json` → `scripts.deploy` present → the deploy command is `npm run deploy`
     (or the repo's package manager equivalent — check for `pnpm-lock.yaml` / `yarn.lock`).
  2. `Makefile` (or `makefile`) → a `deploy:` target → `make deploy`.
  3. `.github/workflows/*.yml` with a job that triggers on tag push (e.g.
     `on: push: tags:`) → nothing to run; the tag push in step 4 already triggered it. Say so
     and point to the workflow run (`gh run list` / the Actions URL) rather than re-running
     anything.
  4. `fly.toml` → `fly deploy` (or `flyctl deploy`).
  5. `render.yaml`, or a Vercel-linked project (`vercel.json` / `.vercel/`) → these platforms
     auto-deploy on push to the default branch; nothing to run manually. Say so. If a manual
     production promote is needed (e.g. `vercel --prod`), use that only if the project is
     clearly configured for preview-by-default.
  6. `Procfile` → Heroku-style; the deploy command is a git push to the platform remote
     (`git push heroku <default>`) — only if a `heroku` remote actually exists
     (`git remote -v`).
  7. `scripts/deploy.sh` or `deploy.sh` at the repo root → run it directly.
  8. `terraform/` with an apply path → flag this explicitly as infrastructure-level and
     confirm the exact plan before applying; never run `terraform apply` without showing
     the plan output first.
  9. None of the above → report plainly: "No deploy process found in this repo — nothing to
     run." Do not invent one.

  Whatever is found, **show the exact command before running it** and get a final go-ahead —
  the "release to prod?" yes authorizes checking for a deploy process, not blindly executing
  whatever turns up. This matters most for step 8 (infra) and anything that isn't a routine,
  clearly-scoped script.

## Install

Stateless markdown, no scripts or hooks. Symlink into the pinned worktree the same way as
the other orchestration skills, so a `git switch` in the dev checkout never changes what
Claude Code loads:

```bash
ln -s ~/Source/claude-skills-main/Skills/release ~/.claude/skills/release
```
