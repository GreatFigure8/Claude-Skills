# RELEASE — the release procedure

Read this file only after Jonathan's yes at step 7 (SKILL.md, *Step 7 · RELEASE?*). Until then nothing in it runs.

### RELEASE (after Jonathan's yes; orchestrator + 1 release-prep worker)
Jonathan's yes in chat is the approval for every step on the checklist, for this release
only. Each deploy command is prefixed with `BMN_USER_APPROVED_DEPLOY=1`. The order matters:
nothing reaches `main` until the database is ready for it, and nothing is committed to
either branch after `main` moves, so `dev` and `main` end on the same commit.

A bare "release" approves the checklist as shown, its version and every site included: run
it end to end (release, publish to every site, close the issues) and ask nothing about
version or sites. Release only this run's tested sprint, never `dev` as it stands, because
`dev` can carry another session's untested work; when `dev` holds another unfinished sprint,
release as a hotfix from `main` (`origin/main` + the sprint branch + the release note, then
`main` merged back into `dev`). Offer only release paths that keep these rules, never a
shortcut they exclude (shipping untested `dev`, skipping tests on what ships). When Jonathan
makes this run the release owner for other sessions, ship them together: confirm each
session's work is in `dev`, run every migration and one deploy of the combined tip, then
close all their issues (Jonathan's rules, 2026-10-28).

1. **Preflight (release-prep worker, sonnet, read-only).** Release-prep brief, mode
   `preflight`. In a detached worktree of `origin/dev` it checks: `git log --oneline
   origin/dev..origin/main` is empty (if not, the worker merges `origin/main` into `dev`
   with `--no-ff`, runs the scoped gates and pushes `dev`); `dev`'s code is what the last
   test run tested (only `docs/` and report commits since the last `tests.runs[].sha` —
   otherwise it runs `{full_gates}` on the tip, and a failure stops the release; when
   Jonathan chose no tests there is no tested sha, and this check is skipped: the release
   ships untested code, as the report and the release question said); every CLI the
   checklist needs is signed in (`gh auth status`, `vercel whoami`, the Supabase CLI for the
   main ref); the env vars the checklist names exist on the production project (names only,
   `vercel env ls production`); the tag `v<next>` doesn't exist yet. It returns `{ok,
   problems[]}`. Any problem stops the release before anything changes: record it in
   `bmn.json.release` (`status: failed`) with a `dev` commit, tell Jonathan in one line what
   to fix, and stop. Never enter a credential.
2. **Supabase MAIN** (orchestrator), only when the checklist has main migrations:
   `BMN_USER_APPROVED_DEPLOY=1 supabase link --project-ref <main_ref> && BMN_USER_APPROVED_DEPLOY=1 supabase db push --linked`,
   then `supabase migration list --linked` to confirm every migration on dev is on main. A
   failure stops the release here (`status: failed`, recorded with a `dev` commit; `main` is
   untouched) and goes to Jonathan in one line.
3. **Release commit (release-prep worker, mode `commit`).** In a detached worktree of
   `origin/dev`: bump the version in every version file the release profile names, add the
   changelog entry, and write `bmn.json` with `phase: done` and `release: {status:
   "released", version, tag, bump, at}`. Commit `release: v<next>` and push `HEAD:dev`. When
   the repo has its own release tool (release-please, changesets, `npm version`, a
   `make release`), the worker runs that tool's version step instead of editing files by
   hand. It returns the commit sha.
4. **Main and tag** (orchestrator), in one command:
   `git worktree add --detach ../<repo-name>-<run-slug>-main origin/main && cd ../<repo-name>-<run-slug>-main && git merge --no-ff origin/dev -m "release: v<next>" && git tag -a v<next> -m "v<next>" && BMN_USER_APPROVED_DEPLOY=1 git push origin HEAD:main v<next>`,
   then `git -C <main checkout> worktree remove ../<repo-name>-<run-slug>-main`. The merge is
   a merge commit, never a squash or a fast-forward of `main`.
5. **Sync dev** (orchestrator): `git fetch origin && git push origin origin/main:dev` (a
   fast-forward; it never forces), then confirm `git rev-parse origin/dev origin/main` prints
   the same sha twice. **`dev` and `main` are now the same commit; nothing is committed to
   either after this.**
6. **Vercel production.** When `main`'s git-triggered production build is on (the release
   profile says so), the push in step 4 started it: wait for it with `vercel ls`/`vercel
   inspect` until it is `READY` or `ERROR`. Otherwise run
   `BMN_USER_APPROVED_DEPLOY=1 vercel deploy --prod` from a detached worktree at the release
   commit, linked to the project the profile names, and remove that worktree. A Vercel MCP
   deploy tool is never used.
7. **GitHub release** (orchestrator), when the repo is on GitHub:
   `gh release create v<next> --title "v<next>" --notes-file <changelog entry>`. When the
   repo's own CI publishes on the tag, wait for that workflow instead and report its result.
   Then close every GitHub issue the shipped work resolves (`gh issue close <n> --reason
   completed`, comment "Shipped in v<next>: <one line>"); an unclear link is named in the
   result, not closed (Jonathan's rule, 2026-10-20).
8. **Smoke check (release-prep worker, mode `verify`).** Production answers on its health
   route or home page (HTTP 200, no server error in `vercel logs` for the deployment), the
   main database lists every released migration, and the tag points at `origin/main`. It
   returns `{ok, checks[]}`.
9. **Done.** Send one `PushNotification` line ("v<next> released" or what failed), and post
   the release result in chat: the version, the main sha, the deploy URL, each step's
   result. A failure after step 4 is reported, never rolled back or retried on its own:
   `main` already has the release, and whether to roll back or fix forward is Jonathan's
   call, a new goal. The record of the result lives in the chat, the notification and the
   GitHub release, never in a new commit, so `dev` and `main` stay in sync.

The release doesn't fix, review or deploy anything outside its checklist, and the approval
doesn't carry over to a later release or another run.
