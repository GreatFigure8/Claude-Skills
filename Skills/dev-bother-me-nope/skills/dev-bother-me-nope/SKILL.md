---
name: dev-bother-me-nope
description: Jonathan's zero-question build pipeline — takes one long free-form story (a bug fix, an error to resolve, a feature, or an ENTIRE system), designs any user interface FIRST in Claude Design and has him pick one direction (the only subjective step, and the only feedback asked for), breaks it into stories, plans each, codes them with the right python skill set (python-web-app for APIs/web apps, python-mcp-servers for MCP servers, python-library-quality for libraries/CLIs, python-llm-features for LLM calls; nextjs-fullstack-standards (when the session has it) plus the plugin's Next.js reference if the repo is TypeScript), merges to dev and tests (TDD pytest + real-browser Playwright), then runs exactly code → review → fix → review → report: ONE code review of everything the run implemented, ONE fix round (each finding reproduced as a failing test first, merged to dev and tested), ONE re-review of the fixes whose findings are reported, never fixed — then writes a summary report, alerts him and is done; anything further is a new goal only he decides. After the design pick it never asks a question and never deploys to Vercel (not even dev) — merges to dev never trigger a Vercel build, Vercel deploys wait for Jonathan's word; migrations go to the Supabase DEV database only, MAIN waits for him; the report says exactly what needs deploying. Use whenever Jonathan says "dev-bother-me-nope", "/dev-bother-me-nope", "/goal execute /dev-bother-me-nope for …", "/goal using dev-bother-me-nope …", "don't bother me, just build …", or pastes a long build story and says to just do it. Also use when Jonathan says "I'm moving computers", "switching machines" or "move-computers" (write a handoff for every open run), and at the start of every coding session (pick up open handoffs from another machine).
---

# dev-bother-me-nope

One long story in, merged-to-dev working code plus a report out. **Jonathan is asked one
thing, at the very start: which UI design he wants** (only when the story touches a user
interface). That is the one subjective call in the process. After he picks, he is not asked
anything else. Every other open question is decided here, written down as an assumption,
and shipped.

```
INTAKE → DESIGN (UI only) → Jonathan picks → SPLIT → PLAN → BUILD (TDD, gates) → MERGE→dev → TEST   [coding complete]
       → REVIEW① → FIX① → MERGE→dev → TEST → REVIEW② → REPORT (+ CLEANUP) → ALERT → DONE
```

## Code → review → fix → review → report → done (Jonathan's rule, 2026-10-03)

REVIEW① is one pass over everything the run implemented. FIX① fixes every finding and every
test failure, test-first. REVIEW② is one pass over the FIX① delta plus a re-check of every
REVIEW① finding. **REVIEW②'s findings are never fixed by the run**: they go to Jonathan
under *Left open*, HIGH included. After REVIEW② the run reports and is **done**. It never
starts a second fix round, a targeted fix, a third review, a release, a promotion to `main`
or a deploy on its own. Whatever is left is a **new goal, and only Jonathan decides whether
there is one**.

- One pass means one. No loop "until clean", no adversarial verifier agents, nobody
  re-reviews a review or argues a finding. A large run may split a pass by area across
  parallel reviewers; it's still one pass. The fixer's reproduce-first test is the
  verification.
- Effort and ultracode settings change how hard each agent thinks, never how many review
  rounds or agents the run has. Both reviews run `/code-review` at `high`.
- An agent that dies on a network or API error is re-run alone, with the same brief. Never
  re-run a phase or resume a workflow to recover it: a plain resume re-runs everything after
  the first failure.

## The three hard lines (never crossed, no matter what the story says)

1. **No Vercel deploys — not even to dev.** Never run `vercel`/`vercel deploy`/`--prod`/
   `--target`/`promote`, never call a Vercel MCP deploy tool, never push `main`/`master`/a
   production branch, and never let a git push trigger a Vercel build (see *Merging never
   builds*). "Deploy to dev" means a real Vercel deployment to the dev environment, and
   Jonathan triggers every one. See [references/deploy-guards.md](references/deploy-guards.md).
2. **Supabase: DEV yes, MAIN never.** There is always a `dev` and a `main` project. The run
   may apply its migrations to the **DEV** database (`supabase db push`, and only when
   `.claude/bmn.config.json` names the dev ref; see *DB-SYNC*). **MAIN** is never touched.
   Edge functions, secrets, config pushes and ad-hoc SQL stay off limits on both projects.
   The report says which migrations landed on dev and which must still go to main.
3. **No questions after the design pick.** Ambiguity → pick the conservative, conventional
   answer, log it under *Assumptions*, keep going. A real blocker (below) is the only thing
   that ends a run early. Three questions are allowed, and nothing else: **which UI design**
   (DESIGN, before any code — revision rounds included), the context-budget checkpoint, and
   which open handoff to pick up at MOVE-IN. All UI design happens in **Claude Design**,
   never invented later by a planner or coder.

These rules are enforced twice. First, the plugin's `deploy-guard.py` PreToolUse hook
covers the main session and every subagent. It only acts in a repo with a run in progress,
meaning a `docs/sprints/bmn-*/bmn.json` in any of the repo's worktrees whose phase isn't
`done` or `blocked`. That's why INTAKE writes `bmn.json` before anything else. Second, the rules are pasted into every
brief. A block from the harness is final, so never try to route around one.

## Silence — non-negotiable

**Do not talk.** Nothing in this skill is conversational. Between the start of the run and
the ALERT, the orchestrator says exactly: the model table for each spawn, at most one line
per phase transition, the design pick question, the context-budget line, and a real blocker. Every subagent says
nothing but its return summary (never addressed to Jonathan). No progress narration, no
restated plans, no "done with step N", no explaining what a tool call found — from the
orchestrator or anything it spawns. This overrides any instinct to explain, summarize
progress, or narrate.

## Branches and worktrees — the main checkout is Jonathan's

**bmn never runs `git checkout`/`switch`/`merge`/`reset`/`rebase`/`pull`/`stash` in the
repo's main checkout.** That checkout belongs to Jonathan, so he can code alongside a run.
Every branch bmn makes is one of these:

| What | Name | Lives | Deleted |
| --- | --- | --- | --- |
| **Run branch** (the integration branch; permanent until merged) | `<type>/<run-slug>`, type `feat`\|`fix`\|`hotfix`\|`chore` from the story's intent, cut from `origin/dev` | the **run worktree** `../<repo-name>-<run-slug>` (sibling of the main checkout) | at CLEANUP, after its last merge to `dev` — not after MERGE→dev①, because FIX① still branches from it |
| Story, fix and test branches (temporary) | `wip/<run-slug>/<slug>` | a harness worktree (`isolation: "worktree"`) | as soon as the integrator has merged it — local, origin and every worktree on it |
| Dev-merge scratch (temporary) | detached, no branch | `../<repo-name>-<run-slug>-dev` | in the same command that made it |

Temp branches never sit under the run branch's name: git can't hold `feat/x` and
`feat/x/y` at once. All integrator, merger and orchestrator git work happens in the run
worktree. Jonathan may open it and commit there too, so the integrator and merger pull
(`--rebase=merges`) before they push, never force-push, and never stash, reset or check out
over changes they didn't make. Every ref and worktree the run creates is recorded in
`bmn.json` (`integration`, `worktree`, `temp_refs`). Cleanup only ever touches those refs,
plus every worktree that has one of them checked out (from `git worktree list --porcelain`),
even one bmn didn't create; the main checkout is never removed or switched.

**Cleanup is a step, not advice.** Deleting a merged branch always goes through one tested
helper, never a hand-written sequence:
`python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py --repo <path> --branch <branch> --target <ref>`.
It proves the branch is merged with `git merge-base --is-ancestor <branch> <target>` (never
`git branch -d`, which checks against HEAD/upstream), removes every worktree that has the
branch checked out, deletes the local branch, and deletes the origin copy once that is also an
ancestor of the target — never with `--force`. A dirty or locked worktree, the main checkout
and a branch that isn't proven merged are left in place. It prints JSON with `deleted`
(`worktree:`, `local:` and `origin:` entries) and `left` (`[{ref, why}]`). The orchestrator
appends both to `bmn.json.cleanup`, and the report's *Git cleanup* section lists them. When
the helper refuses (exit 2, an unresolvable target say), record the branch in `left` with the
error as `why` and carry on.

## Merging never builds

**Merging** means merging the run branch into the repo's `dev` **git branch** and pushing
it. That happens after BUILD, after FIX① and with the report. It is not a deploy, and
it must not cause one. If the repo has no `dev` branch, INTAKE creates it from the default
branch. Story work never merges straight into `main`.

For a Vercel app, INTAKE ensures every `vercel.json` (repo root and each app dir linked to a
Vercel project) turns off git-triggered deployments for every branch the run pushes. It
merges the setting into the file without touching other keys:

```json
{ "git": { "deploymentEnabled": { "dev": false, "wip/**": false, "bmn/**": false, "<type>/<run-slug>": false } } }
```

(`git.deploymentEnabled` takes a branch map with minimatch patterns — Vercel docs,
project-configuration/git-configuration.) `wip/**` is permanent; `bmn/**` covers runs from
before 1.4.0. The run branch is listed by its **exact name**, so Jonathan's own `feat/*`
branches keep their previews; CLEANUP removes that key again in its final commit to `dev`.
Not `ignoreCommand`: an ignored build still creates a (cancelled) deployment that counts
against quotas and build slots. This commit is the **first commit** on the run branch, made
before its first push. Vercel doesn't document whether a commit's own `vercel.json` governs
that same push, so the report says the run branch's first push *may* have produced one
build.

A CI workflow can also deploy on push to `dev`, for example `vercel deploy` in GitHub
Actions, or anything that touches Supabase **main**. The stack-scout checks for this. If it
finds one (`stack.dev_push_deploys: true`), the run doesn't push to `dev`. It merges and
tests on the run branch instead, "merge `<type>/<run-slug>` → `dev`" goes on the Deploy
checklist, and the run branch and worktree stay until that merge has happened.

## Merge commits only — never squash (Jonathan's rule, 2026-10-03)

**bmn never squash-merges.** On 2026-10-03 Jonathan asked for the full history of every
change on `dev` from here on, so every merge bmn makes is a `git merge --no-ff` merge commit
and every story branch's commits stay reachable in `dev`'s history. Merge commits only,
never squash. A brief or the orchestrator never runs any of these forms:

- `git merge --squash`: never.
- `gh pr merge --squash` (or `-s`): never.
- the REST API's `merge_method=squash`: never.

The plugin's deploy guard blocks all three while a run is active
([references/deploy-guards.md](references/deploy-guards.md)), and a block is final. Rebase
merges aren't part of the rule and are left as they are.

Any pull request bmn merges, or that a brief names, is merged one way only:
`gh pr merge <n> --merge --delete-branch --repo <owner>/<repo>`. That is a merge commit, and
the source branch is deleted on the remote. With `--repo`, gh skips its local-branch step, so
the form deletes only the remote head branch and leaves every local checkout alone. The local
branch and every worktree on it go through `merged-branch-cleanup.py` (*Cleanup is a step*).
gh also skips the remote delete for `--auto` and for cross-repo PRs
(cli/cli `pkg/cmd/pr/merge/merge.go`, `deleteRemoteBranch`), so bmn never uses `--auto`; the
repo setting `delete_branch_on_merge=true`, set at INTAKE, is the backstop for a PR merged any
other way.

## State on disk (resume-safe)

Everything lives in `docs/sprints/bmn-<run-slug>/` on the run branch, in the run worktree:

| File | Written by | Holds |
| --- | --- | --- |
| `input.md` | INTAKE | Jonathan's story, verbatim |
| `bmn.json` | orchestrator only | run state machine (below) |
| `stack.md` | INTAKE | stack classification + skill and reference routing ([references/stack-routing.md](references/stack-routing.md)) |
| `design.md` | DESIGN | the picked direction: Claude Design link, tokens, per-screen layout, components, states, copy |
| `design/*.html` | DESIGN | local copy of the picked Claude Design pages (coders and testers read these, not the MCP) |
| `<story-slug>/story.md` | SPLIT | the story, acceptance criteria, assumptions |
| `<story-slug>/<story-slug>-plan.md` | PLAN | implementation plan + test plan |
| `<story-slug>/validation.md` | TEST, FIX① | test commands, results, browser evidence; what FIX① did with each item |
| `review.md` | REVIEW①, REVIEW② | severity-ranked findings (id, file:line, scenario, owning story), one section per review |
| `validation.md` | FIX① | what FIX① did with findings no single story owns |
| `handoff.md` | MOVE-OUT | machine-move handoff; renamed `handoff-<ts>.md` once picked up |
| `report.md` | REPORT | the summary Jonathan reads |

No `sprint.json` in this folder on purpose, so a running dev-story-flow loop never picks
up a bmn run.

`bmn.json`:

```json
{
  "run": "bmn-<run-slug>", "phase": "intake|design|split|plan|build|merge1|test1|review1|fix1|merge2|test2|review2|report|done|blocked",
  "integration": "<type>/<run-slug>", "worktree": "<abs path of ../<repo-name>-<run-slug>>", "live": "dev", "dev_base": "<sha of origin/dev when the run started>",
  "review_shas": {"review1": "<sha TEST① ran on>", "review2": "<sha TEST② ran on>"},
  "stack": {"kind": "web-app|api|mcp-server|library|cli|mixed", "ui": true, "supabase": false, "vercel": false, "vercel_json": [], "dev_push_deploys": false, "supabase_dev_ref": null, "supabase_main_ref": null},
  "stories": [{"slug": "...", "title": "...", "deps": [], "status": "split|planned|built|merged|tested|done|blocked", "branch": "wip/<run-slug>/<slug>", "merges": [{"branch": "...", "tip": "<sha>", "merge": "<sha>"}], "detail": ""}],
  "temp_refs": [{"branch": "wip/<run-slug>/<slug>|<harness branch>", "kind": "wip|harness", "base": "<sha at spawn>", "worktree": "<abs path>|null", "pushed": false}],
  "integration_pushed": false,
  "cleanup": {"deleted": [], "left": [{"ref": "...", "why": "dirty worktree|not merged|..."}]},
  "repo_policy": null,
  "deploy_pending": {"vercel": [], "supabase_migrations": []},
  "supabase_dev_applied": [],
  "design": {"needed": false, "project_id": null, "url": null, "round": 0, "options": [{"key": "a", "name": "...", "open_url": "..."}], "picked": null, "feedback": []},
  "handoff": null,
  "assumptions": [], "blocker": null, "updated": "<iso8601>"
}
```

Write `bmn.json` atomically (write to a temp file, then `mv`), with a new object each time.
Commit the run folder in the run worktree at the end of every phase. **Moving computers:**
when Jonathan says he's moving machines, run MOVE-OUT. On every start, run MOVE-IN *before*
the resume rule. It finds open handoffs in the run worktrees and on origin's run branches,
and asks which one to pick up. Both procedures are in
[references/move-computers.md](references/move-computers.md).
**Resume rule:** look for run folders in every worktree (`git worktree list`) and on
`origin/dev`. If a `bmn-*` run with `phase` other than `done` exists and the objective
doesn't clearly name a new story, re-read `bmn.json` and continue from `phase`, trusting
only what's on disk. Phases only move forward in enum order; a run resumed at `review2` or
later never fixes again. `report` covers REPORT and CLEANUP: re-run whichever of the two
hasn't committed. A run from before 1.5.0 maps its old phase first: `review1` → `merge1`,
`fix` → `fix1`, `review2` → `merge2`, `review3` → `review2`, `cleanup` → `report`.

**Leftover sweep:** a `done` or `blocked` run whose `cleanup.left` names its run
branch, and that branch is now in `origin/dev` (Jonathan merged it), gets CLEANUP's run
step now:
`python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py --repo <main checkout> --branch <run branch> --target origin/dev`,
adding `--local-only` when that run's `integration_pushed` is false (the sweep never deletes an
origin copy the run didn't push).

A run resumed at `phase: design` with `design.picked: null` re-asks the design question
from the options already in `bmn.json` — it doesn't redesign.

## Orchestrator discipline

The main thread decides and dispatches. It doesn't read source, run test suites, or grep
the codebase. That work is done by subagents, which report back conclusions.

- Every subagent is `subagent_type: "dev-bother-me-nope:bmn-worker"`. Briefs come from
  [references/briefs.md](references/briefs.md) and are filled in, not paraphrased.
  `{skill_dir}` in a brief is this skill's base directory, the path shown when the skill
  loads.
- `${CLAUDE_PLUGIN_ROOT}` is empty in a worker's Bash. The orchestrator fills it like a
  placeholder, with the absolute plugin root (`{skill_dir}/../..`, resolved), in every brief
  and in its own Bash calls when the variable is empty.
- Every spawn is announced with the model table (Item | Branch | Model), one row per agent,
  and the model named explicitly: `model: "opus"` for DESIGN, SPLIT, PLAN, REVIEW①, REVIEW②
  and any FIX① item whose root cause is unclear; `model: "sonnet"` for BUILD, TEST, merges
  and mechanical fixes.
- Independent agents run in one message, all at once. Stories without unmet `deps` build in
  parallel, each in `isolation: "worktree"`. Record every harness worktree path and branch
  the Agent result names, plus each `wip/` branch, in `temp_refs`.
- BUILD, FIX, TEST and DB-SYNC agents always run in `isolation: "worktree"`; every other
  agent works in the run worktree (`{run_worktree}` in the briefs).
- Output to Jonathan while running: see *Silence* below.
- Context: at ~120K say so in one line. At ~150K, write `bmn.json` plus the run folder,
  commit, and post the `clear-prompt` block — the resume line is the same
  `/goal execute /dev-bother-me-nope` invocation. Asking about the context budget is the
  one exception to "no questions", because Jonathan's global rules require it.

## Procedure

### 0 · INTAKE (orchestrator)
1. MOVE-IN check, then the resume check (above). Then `git fetch --prune origin`. Leave the
   main checkout exactly as it is.
2. Pick `<run-slug>`, a descriptive kebab-case summary of the story's intent, and the run
   branch type: `fix` for a bug or error, `hotfix` for something broken in production now,
   `chore` for tooling, deps, config or docs only, `feat` for everything else. Create the
   run branch and worktree in one command, without touching the main checkout:
   `git worktree add --no-track -b <type>/<run-slug> ../<repo-name>-<run-slug> origin/dev`
   (`origin/<default_branch>` when there's no `dev` yet; add `-2`, then `-3`…, to the slug when
   `refs/heads/<type>/<run-slug>`, `refs/remotes/origin/<type>/<run-slug>`, any ref under
   `<type>/<run-slug>/`, a branch named just `<type>`, or the directory exists). In the run worktree, write `input.md` verbatim and `bmn.json` with
   `phase: intake`, `integration` and `worktree` **right away**. The deploy guard is only
   active once this file exists.
3. Dispatch one **stack-scout** (sonnet) with the brief in briefs.md. It returns the stack
   classification and routing. For a TypeScript / Next.js repo the routing also names
   [references/nextjs.md](references/nextjs.md), the plugin's dated Next.js + TypeScript
   standard. The planner, coder, reviewer and fixer read it with the Read tool
   ([references/stack-routing.md](references/stack-routing.md)).
   The scout returns it in `routed_references[]`, never in a skill list; `stack.md`
   records that list, and every brief's `{routed_references}` is filled from it.
   Write `stack.md`, then `bmn.json` with `phase: split`.
   If the scout identified **both** Supabase refs, and each one is unambiguously labelled
   dev or main, write `.claude/bmn.config.json` =
   `{"supabase": {"dev_ref": "…", "main_ref": "…"}}`. The deploy guard reads this file,
   and it's what lets DB-SYNC push to dev. If there's any doubt which ref is which, don't
   write it. Migrations then stay local and go on the checklist for both projects.
4. If `origin/dev` doesn't exist, create it from the default branch with
   `git push origin origin/<default_branch>:refs/heads/dev` (branch creation, not a deploy
   — but if `stack.dev_push_deploys`, skip this and integrate on the run branch only).
   Record `origin/dev`'s sha as `dev_base` in `bmn.json`; REVIEW① diffs against it. In the
   run worktree, commit the `vercel.json` `deploymentEnabled` change for a Vercel app (plus
   `.claude/bmn.config.json` if it was written) **before** the first push, then
   `git push -u origin <type>/<run-slug>`, then set `integration_pushed: true` in `bmn.json`
   (CLEANUP deletes the origin copy only when it is set).
5. **Repo merge settings, once per run.** Skip it when `bmn.json.repo_policy` is already set
   (a resumed run). Otherwise run
   `python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/repo-merge-policy.py --repo-path {run_worktree}`
   and write its JSON verbatim to `bmn.json.repo_policy`
   (`{"repo", "status": "changed|already-set|dry-run|skipped|failed", "changes": {field: {old, new}}, "reason"}`).
   It sets `allow_squash_merge=false` and `delete_branch_on_merge=true` on the GitHub repo.
   That is Jonathan's standing instruction of 2026-10-03, so bmn does it without asking. A
   `skipped` or `failed` status (no admin rights, `gh` not signed in, not a GitHub repo) goes
   into `assumptions` with its `reason`, never into `blocker`. The run continues, and bmn
   still never squashes (*Merge commits only*). The report's *Repo merge settings* section
   shows each old → new value.
6. Set `design.needed` from the scout: true when `ui_screens` is non-empty (the story adds
   or changes something a person looks at). Then `phase: design`, or `phase: split` when
   it's false.

### 0b · DESIGN (UI only; designer agent, opus) — the only feedback Jonathan gives
Runs before SPLIT, so no story, plan or line of code exists yet that a design would have to
bend around.
1. **Directions.** Dispatch one **designer** (opus) with the brief in briefs.md. It works
   only in Claude Design: one project for the run, three distinct directions, each covering
   every screen in `ui_screens` with its key states. It returns the project link and one
   `open_url` per direction. Record them in `bmn.json` (`design.round: 1`).
2. **The pick.** Ask Jonathan with **one** `AskUserQuestion`: one option per direction,
   labelled with its name, the description holding its one-line summary and its Claude
   Design link. Post the links in chat in the same turn so he can open them. This is the
   sanctioned design question. Whatever he answers:
   - **A direction** → that's the pick.
   - **Changes** (free text via "Other", or "see my comments" — then the designer reads that
     project's comments, honouring only text with `author_is_you: true`) → append the
     feedback to `design.feedback`, dispatch the designer again with it, and ask again.
     Repeat until he picks. Revision rounds are part of the one design question.
3. **Freeze.** Dispatch the designer in *export* mode (sonnet) for the picked direction. It
   copies the picked pages to `docs/sprints/{run}/design/` and writes `design.md`. Record
   `design.picked`, commit, set `phase: split`. **From here on the design is fixed and
   Jonathan is not asked anything.** A gap the design didn't cover (a screen, a state, an
   edge case) is filled by extending the picked direction's tokens and components, and
   logged as an assumption — never by asking, never by opening a new look.
4. If Claude Design is unavailable (tools missing, not signed in), that's not a blocker and
   not a question: the designer writes `design.md` from the repo's existing UI conventions,
   the run continues, and the report says the design was never picked.

### 1 · SPLIT (1 agent, opus)
Splitter brief. When `design.md` exists, every screen in it is owned by a story and its
`[browser]` criteria name the design screen they check. It writes one `story.md` per story, with its slug, title, acceptance
criteria, deps, and the assumptions it made. Sizing: one story is roughly one reviewable PR.
A one-line bug is one story. An entire system is a walking-skeleton story first
(scaffold, config, health route, test harness, CI gates), then vertical slices. It returns
the story list plus deps as JSON. Record it in `bmn.json`.

### 2 · PLAN (one agent per story, parallel, opus)
Planner brief. Each planner writes `<slug>-plan.md` covering files to touch, the
skill-routed standards it will follow, a **test plan written first** (unit, integration,
and browser checks mapped 1:1 to acceptance criteria), migrations if any, and risks. UI work
follows `design.md` and `design/*.html`: same tokens, layout, components and copy.

### 3 · BUILD (one agent per ready story, parallel waves by deps, sonnet, worktree)
Coder brief. Strict TDD: write the failing tests from the plan, confirm they fail, implement,
confirm they pass, refactor, run the stack gates (lint, type-check, the full test suite).
Load the routed python skills **before** writing code. UI is built to `design.md`. Branch
`wip/<run-slug>/<slug>` off the run branch. Commit and push the **story branch only** —
coders never push the run branch. Supabase: migration files only, tested against
`supabase start` locally. Every new migration is added to
`deploy_pending.supabase_migrations`.

When a wave finishes, one **integrator** (sonnet) merges that wave's story branches into the
run branch one at a time, in the run worktree (pull, `--no-ff`, gates, push). One writer
per branch means no push races. Then, for each branch it merged, it runs
`python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py --repo {run_worktree} --branch <branch> --target origin/{integration}`
(*Cleanup is a step*): every worktree on the branch removed, and the `wip/` branch deleted
locally and on origin, plus the paired harness branch once nothing unique is left on it. It
returns each story's tip sha and merge sha; append them to that story's `merges` in
`bmn.json` (REVIEW② finds the FIX① merges there) along with what was deleted or left.
The next wave branches from the updated run branch. When the last wave is in, set
`phase: merge1`.

### 4 · MERGE→dev ① (`merge1`; 1 agent, sonnet)
Merger brief. In the run worktree, merge `origin/dev` into the run branch, run the full
gates, push. Then merge into `dev` in a throwaway detached worktree, never by checking out
`dev` anywhere: `git worktree add --detach ../<repo-name>-<run-slug>-dev origin/dev`, there
`git merge --no-ff <type>/<run-slug> && git push origin HEAD:dev`, then `git worktree remove`
it. It never touches `main`, never squashes, and doesn't delete the run branch: FIX① still
branches from it, and CLEANUP deletes it after the last merge to `dev`. If
`stack.dev_push_deploys`, skip the `dev` merge — TEST runs on the run branch, and the report
lists the `dev` merge on the Deploy checklist.

### 4b · DB-SYNC (1 agent, sonnet, `isolation: "worktree"`; after every MERGE that brought new migrations)
Record its worktree and branch in `temp_refs`.
This step runs only when `.claude/bmn.config.json` exists and the merged `dev` has
migrations that aren't in `supabase_dev_applied`. Run
`supabase link --project-ref <dev_ref> && supabase db push --linked` in one command, then
`supabase migration list --linked` to confirm. Record the applied files in
`supabase_dev_applied`. Some cases are skipped and go on the checklist instead:
- A migration that destroys data (`DROP TABLE`/`DROP COLUMN`/`TRUNCATE`, or `DELETE`/
  `UPDATE` without `WHERE`).
- The CLI isn't authenticated (no access token or DB password). Never enter a credential.
- The push fails.

Tests don't run against the dev database. They stay on local Supabase.

### 5 · TEST① (`test1`; 1 agent per test surface, parallel, sonnet, each in `isolation: "worktree"`) — coding complete
Record each worktree and branch in `temp_refs`.
Tester brief, run against the merged `dev`:
- **TDD suite**: the full `pytest` (or `vitest`/`jest`) run, plus coverage. Target is 80% or
  higher on the code the stories touched.
- **Browser** (whenever `stack.ui` is true, or the app serves HTML): start the app locally,
  and start local Supabase if it's used. Drive every story's user-facing acceptance
  criterion in headless Playwright. Screenshot every screen in `design.md` and compare it
  with its `design/*.html` reference; a structural mismatch is a failure. Collect screenshots in `validation.md` as file paths,
  and console errors plus failed network requests as findings.
- **API / MCP surfaces**: black-box calls against the running server (httpx for APIs, or
  Playwright's `request` fixture for a TypeScript / Next.js repo; an MCP
  client session that lists and calls tools for MCP servers).
A TypeScript / Next.js repo takes all of this tooling from the TypeScript row of
[references/stack-routing.md](references/stack-routing.md)'s Test surfaces table: Vitest or
Jest, `@playwright/test` and the `request` fixture, never pytest-playwright or httpx.
Failures go into each story's `validation.md` as findings, and on to REVIEW① as input.
Coding is complete here. Record the sha TEST① ran on (the merged `dev`, or the run branch
when `stack.dev_push_deploys`) as `review_shas.review1`.

### 6 · REVIEW① — one pass over what the run implemented (`review1`; 1 agent, opus)
Reviewer brief, pass 1. Run `/code-review` at `high` on the whole run's diff,
`git diff {dev_base}...{review1_sha}`, plus the routed python-library-quality lenses
(security, API design, untrusted content, destructive operations, external behavior, heavy
dependencies) that match it, and for TypeScript `nextjs-fullstack-standards` (when the session
has it) plus [references/nextjs.md](references/nextjs.md), each finding citing the rule id it
breaks. Beyond per-file
bugs, it looks for what only shows up across stories: duplicated helpers, contracts that
disagree, migrations that conflict or run in the wrong order, config keys nothing reads, and
acceptance criteria no test covers. A screen that departs from the picked design (layout,
components, tokens, copy) is HIGH. Findings go into the run-level `review.md`, ranked
CRITICAL/HIGH/MEDIUM/LOW, each with an id, file:line, a concrete failure scenario and its
owning story (`run` when no story owns it). A large run may split the pass by area (stories
or directories) across parallel reviewers in one message. Each returns its JSON without
writing, and the orchestrator writes `review.md` from them, one section per area. It is
still one pass, and no verifier agent checks the findings.

### 7 · FIX① — the only fix round (`fix1`; one agent per owning story, parallel, each in `isolation: "worktree"`)
Record each worktree and branch in `temp_refs`.
Fixer brief. Input: every REVIEW① finding, every severity, plus every TEST① failure, grouped
by owning story. Findings no story owns go to one `run` fixer. Sonnet for mechanical fixes,
opus when the root cause is unclear. Each fixer first reproduces each item as a failing test
— that reproduction **is** the verification — then fixes it and runs the gates. An item it
can't reproduce is recorded as not-reproducible, with evidence, not argued and not retried.
An item it can't fix is recorded as blocked, with the reason. One attempt per fixer, no
retry loop. Each fixer works on a fresh `wip/<run-slug>/<owner>-fix` branch off the run
branch; the integrator merges each fix and test branch and deletes it with
`merged-branch-cleanup.py`, serially, same as BUILD.
When REVIEW① found nothing and TEST① was green, skip straight to REPORT.

### 8 · MERGE→dev ② (+ DB-SYNC) → TEST② (`merge2`, `test2`)
Same as steps 4, 4b and 5. Record the sha TEST② ran on as `review_shas.review2`. TEST②
failures aren't fixed. They go to REVIEW② as input and into the report.

### 9 · REVIEW② — the last review (`review2`; 1 agent, opus)
Reviewer brief, pass 2. One pass over the FIX① delta, `git diff {review1_sha}...{review2_sha}`,
plus a re-check of every REVIEW① finding at `{review2_sha}`: fixed, still open, regressed, or
not-reproducible (as the fixer recorded it, not re-argued). Same `/code-review` level and
lenses, and it may split by area the same way. It adds a REVIEW② section to `review.md`,
ranking new findings in the delta and the TEST② failures the same way. **Nothing REVIEW②
finds is fixed.** Every item, HIGH included, goes straight to the report under *Left open*.

### 10 · REPORT (`report`; orchestrator)
The report names the picked design and links its Claude Design project. Fill in [references/report-template.md](references/report-template.md) and write it to
`report.md`. Keep `phase: report`, commit both in the run worktree, and have the merger
merge to `dev` (a `--no-ff` merge commit, never squash). **Stopped for Jonathan** comes
first: what was built, what FIX① fixed, what
is left open (every REVIEW② finding and TEST② failure, HIGH included), and the decisions
that are his — whether any of it becomes a new goal, release/promotion to `main`, deploys,
DB. The **Deploy checklist** comes next.
It lists which migrations were applied to Supabase **dev** and which are waiting for
**main**. It also lists any dev migrations that were held back, and why. It ends with a
ready-to-say Vercel line: "`dev` is ready for a Vercel dev deploy:
`vercel deploy --target=<env>`". Nothing Vercel- or main-related is run. The *Git cleanup*
section is filled in by CLEANUP.

### 10b · CLEANUP (still `report`; 1 agent, sonnet) — mandatory, never skipped
Cleaner brief. It runs the helper (*Cleanup is a step*) with `--repo <main checkout>`, which
changes no file or branch there, so the helper never removes the worktree it runs from. It
touches only what `bmn.json` names:
1. **Sweep.** `git fetch --prune origin`, then, for every `temp_refs` entry, run
   `python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py --repo <main checkout> --branch <ref> --target origin/{integration}`.
   Temp refs go first, while `origin/{integration}` still resolves. The helper checks each
   copy separately (including after a machine move, when no local ref exists), so the local
   copy and the origin copy are each deleted only if they are an ancestor of the target. Every
   worktree on the ref is removed (no `--force`) once the ref qualifies. A copy that fails its
   check is left and recorded in `left` with the reason. A `harness` ref the helper leaves as
   not merged is still deleted (`git branch -D`, its worktree is already gone) when its tip
   equals `base`, or when it has no commits unique to it (`git rev-list <ref> --not
   --exclude=refs/heads/<ref> --branches --remotes` prints nothing).
2. **Run branch.** After the fetch, run
   `python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py --repo <main checkout> --branch <integration> --target origin/dev`.
   The local branch, the origin copy and every worktree on the branch (the run worktree
   included, when clean) go only if the branch is an ancestor of `origin/dev`. Anything the
   helper leaves ("origin has commits not in dev", `dev_push_deploys`, blocked before merging,
   a dirty run worktree) is recorded with its reason. Never run `git worktree prune`: it is
   repo-wide and would discard another branch's worktree record.
   Only the origin copy is gated on `integration_pushed`. When it is false, append
   `--local-only` to that command:
   `python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py --repo <main checkout> --branch <integration> --target origin/dev --local-only`.
   If `origin/<integration>` exists anyway, this run didn't push that copy, so the helper never
   pushes to, deletes or leases it and lists it in `left` as `origin:<integration>`; record that
   entry as "origin copy not pushed by this run" (replacing the helper's reason). The local
   branch and every worktree on it are still deleted, with all of the helper's checks: ancestry
   of `origin/dev`, the rebase and bisect check, no `--force`, and a worktree holding ignored
   files other than regenerable build output is kept.
3. **Record.** When step 2 deleted the branch, first `git -C <repo> worktree add --detach
   <dev_worktree> origin/dev`; then edit `report.md` (the *Git cleanup* section), `bmn.json`
   (`cleanup`; `phase: blocked` when `blocker` is non-null, else `done`) and every
   `vercel.json` (dropping the run branch's `deploymentEnabled` key, only when the origin copy
   was deleted too: an origin copy that stays keeps its key) inside that worktree,
   commit `chore(bmn): record git cleanup for <run-slug>`, push `HEAD:dev`, and remove it.
   Otherwise edit and commit in the run worktree, staging only `docs/sprints/bmn-<run-slug>/`,
   key kept.

### 11 · ALERT → DONE (orchestrator)
Load `PushNotification` with ToolSearch and send one line: the outcome, the story count,
how many items are left open, and whether any deploy is waiting. Then post the report's
*Stopped for Jonathan*, *Deploy checklist* and *Git cleanup* sections in chat, with a link
to `report.md`. This is the only long message Jonathan gets.

Then the run is **done**. Dispatch nothing else: no fix, no review, no release, no
promotion to `main`, no deploy. Further work is a new goal, and only Jonathan decides that.

## Real blockers (the only early stop)

Stop, set `phase: blocked` and `blocker`, then run REPORT, CLEANUP and ALERT with what did ship. Do
this only when:
- the work **requires** a credential, account, or paid resource that doesn't exist locally
  (never invent or enter one — see the prohibited-actions rules),
- the only path forward is a deploy or a remote database change (hard lines 1 and 2),
- or the story contradicts itself in a way where either reading would destroy data.

Everything else is an assumption, not a blocker.

## When Jonathan says "deploy"

This only applies when Jonathan says it in chat, in this session, naming the target (for
example "deploy to Vercel dev", "push main's database" or "deploy prod"). Run only that step,
from the report's Deploy checklist. Prefix each command with `BMN_USER_APPROVED_DEPLOY=1` so
the guard lets it through, then confirm what landed. For Supabase main, check that every
migration is already on dev first. Approval covers one step and doesn't carry over to the
next one.
