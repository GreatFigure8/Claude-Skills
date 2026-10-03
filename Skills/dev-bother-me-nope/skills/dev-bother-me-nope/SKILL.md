---
name: dev-bother-me-nope
description: Jonathan's zero-question build pipeline — takes one long free-form story (a bug fix, an error to resolve, a feature, or an ENTIRE system), designs any user interface FIRST in Claude Design and has him pick one direction (the only subjective step, and the only feedback asked for), breaks it into stories, plans each, codes them with the right python skill set (python-web-app for APIs/web apps, python-mcp-servers for MCP servers, python-library-quality for libraries/CLIs, python-llm-features for LLM calls; nextjs-fullstack-standards if the repo is TypeScript), code-reviews, merges to dev, tests (TDD pytest + real-browser Playwright), fixes, reviews and tests again, runs a final whole-run code review at max effort, then writes a summary report and alerts him. After the design pick it never asks a question and never deploys to Vercel (not even dev) — merges to dev never trigger a Vercel build, Vercel deploys wait for Jonathan's word; migrations go to the Supabase DEV database only, MAIN waits for him; the report says exactly what needs deploying. Use whenever Jonathan says "dev-bother-me-nope", "/dev-bother-me-nope", "/goal execute /dev-bother-me-nope for …", "/goal using dev-bother-me-nope …", "don't bother me, just build …", or pastes a long build story and says to just do it. Also use when Jonathan says "I'm moving computers", "switching machines" or "move-computers" (write a handoff for every open run), and at the start of every coding session (pick up open handoffs from another machine).
---

# dev-bother-me-nope

One long story in, merged-to-dev working code plus a report out. **Jonathan is asked one
thing, at the very start: which UI design he wants** (only when the story touches a user
interface). That is the one subjective call in the process. After he picks, he is not asked
anything else. Every other open question is decided here, written down as an assumption,
and shipped.

```
INTAKE → DESIGN (UI only) → Jonathan picks → SPLIT → PLAN → BUILD → REVIEW① → MERGE→dev → TEST① → FIX
       → REVIEW② → MERGE→dev → TEST② → REVIEW③ (whole run) → REPORT → CLEANUP → ALERT
```

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
| **Run branch** (the integration branch; permanent until merged) | `<type>/<run-slug>`, type `feat`\|`fix`\|`hotfix`\|`chore` from the story's intent, cut from `origin/dev` | the **run worktree** `../<repo-name>-<run-slug>` (sibling of the main checkout) | at CLEANUP, once it's in `origin/dev` |
| Story, fix and test branches (temporary) | `wip/<run-slug>/<slug>` | a harness worktree (`isolation: "worktree"`) | as soon as the integrator has merged it |
| Dev-merge scratch (temporary) | detached, no branch | `../<repo-name>-<run-slug>-dev` | in the same command that made it |

Temp branches never sit under the run branch's name: git can't hold `feat/x` and
`feat/x/y` at once. All integrator, merger and orchestrator git work happens in the run
worktree. Jonathan may open it and commit there too, so the integrator and merger pull
(`--rebase=merges`) before they push, never force-push, and never stash, reset or check out
over changes they didn't make. Every ref and worktree the run creates is recorded in
`bmn.json` (`integration`, `worktree`, `temp_refs`). Cleanup only ever touches those.

**Cleanup is a step, not advice.** Deleting a branch always goes the same way: verify
`git merge-base --is-ancestor <branch> <target>` (never `git branch -d`, which checks
against HEAD/upstream), `git worktree remove <path>` without `--force`, then `git branch -D`
and `git push origin --delete` when it was pushed. A dirty worktree or an unmerged branch is
left in place and recorded in `cleanup.left` with the reason. The report's *Git cleanup*
section lists both.

## Merging never builds

**Merging** means merging the run branch into the repo's `dev` **git branch** and pushing
it. That happens often: after every review round and every fix wave. It is not a deploy, and
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

## State on disk (resume-safe)

Everything lives in `docs/sprints/bmn-<run-slug>/` on the run branch, in the run worktree:

| File | Written by | Holds |
| --- | --- | --- |
| `input.md` | INTAKE | Jonathan's story, verbatim |
| `bmn.json` | orchestrator only | run state machine (below) |
| `stack.md` | INTAKE | stack classification + skill routing ([references/stack-routing.md](references/stack-routing.md)) |
| `design.md` | DESIGN | the picked direction: Claude Design link, tokens, per-screen layout, components, states, copy |
| `design/*.html` | DESIGN | local copy of the picked Claude Design pages (coders and testers read these, not the MCP) |
| `<story-slug>/story.md` | SPLIT | the story, acceptance criteria, assumptions |
| `<story-slug>/<story-slug>-plan.md` | PLAN | implementation plan + test plan |
| `<story-slug>/review.md` | REVIEW | severity-ranked findings, per round |
| `<story-slug>/validation.md` | TEST | test commands, results, browser evidence |
| `review-final.md` | REVIEW③ | whole-run findings, per round |
| `handoff.md` | MOVE-OUT | machine-move handoff; renamed `handoff-<ts>.md` once picked up |
| `report.md` | REPORT | the summary Jonathan reads |

No `sprint.json` in this folder on purpose, so a running dev-story-flow loop never picks
up a bmn run.

`bmn.json`:

```json
{
  "run": "bmn-<run-slug>", "phase": "intake|design|split|plan|build|review1|merge1|test1|fix|review2|merge2|test2|review3|report|cleanup|done|blocked",
  "integration": "<type>/<run-slug>", "worktree": "<abs path of ../<repo-name>-<run-slug>>", "live": "dev", "dev_base": "<sha of origin/dev when the run started>",
  "stack": {"kind": "web-app|api|mcp-server|library|cli|mixed", "ui": true, "supabase": false, "vercel": false, "vercel_json": [], "dev_push_deploys": false, "supabase_dev_ref": null, "supabase_main_ref": null},
  "stories": [{"slug": "...", "title": "...", "deps": [], "status": "split|planned|built|reviewed|merged|tested|done|blocked", "branch": "wip/<run-slug>/<slug>", "detail": ""}],
  "temp_refs": [{"branch": "wip/<run-slug>/<slug>|<harness branch>", "worktree": "<abs path>|null", "pushed": false}],
  "cleanup": {"deleted": [], "left": [{"ref": "...", "why": "dirty worktree|not merged|..."}]},
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
only what's on disk. **Leftover sweep:** a `done` run whose `cleanup.left` names its run
branch, and that branch is now in `origin/dev` (Jonathan merged it), gets CLEANUP's run
step now. A run resumed
at `phase: design` with `design.picked: null` re-asks the design question from the options
already in `bmn.json` — it doesn't redesign.

## Orchestrator discipline

The main thread decides and dispatches. It doesn't read source, run test suites, or grep
the codebase. That work is done by subagents, which report back conclusions.

- Every subagent is `subagent_type: "dev-bother-me-nope:bmn-worker"`. Briefs come from
  [references/briefs.md](references/briefs.md) and are filled in, not paraphrased.
  `{skill_dir}` in a brief is this skill's base directory, the path shown when the skill
  loads.
- Every spawn is announced with the model table (Item | Branch | Model), one row per agent,
  and the model named explicitly: `model: "opus"` for DESIGN, SPLIT, PLAN, REVIEW and any FIX
  whose root cause is unclear, including REVIEW③; `model: "sonnet"` for BUILD, TEST, merges and mechanical fixes.
- Independent agents run in one message, all at once. Stories without unmet `deps` build in
  parallel, each in `isolation: "worktree"`. Record every harness worktree path and branch
  the Agent result names, plus each `wip/` branch, in `temp_refs`.
- Every non-isolated agent works in the run worktree (`{run_worktree}` in the briefs).
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
   (`origin/<default_branch>` when there's no `dev` yet; add `-2` to the slug if the branch
   or directory exists). In the run worktree, write `input.md` verbatim and `bmn.json` with
   `phase: intake`, `integration` and `worktree` **right away**. The deploy guard is only
   active once this file exists.
3. Dispatch one **stack-scout** (sonnet) with the brief in briefs.md. It returns the stack
   classification and routing. Write `stack.md`, then `bmn.json` with `phase: split`.
   If the scout identified **both** Supabase refs, and each one is unambiguously labelled
   dev or main, write `.claude/bmn.config.json` =
   `{"supabase": {"dev_ref": "…", "main_ref": "…"}}`. The deploy guard reads this file,
   and it's what lets DB-SYNC push to dev. If there's any doubt which ref is which, don't
   write it. Migrations then stay local and go on the checklist for both projects.
4. If `origin/dev` doesn't exist, create it from the default branch with
   `git push origin origin/<default_branch>:refs/heads/dev` (branch creation, not a deploy
   — but if `stack.dev_push_deploys`, skip this and integrate on the run branch only).
   Record `origin/dev`'s sha as `dev_base` in `bmn.json`; REVIEW③ diffs against it. In the
   run worktree, commit the `vercel.json` `deploymentEnabled` change for a Vercel app (plus
   `.claude/bmn.config.json` if it was written) **before** the first push, then
   `git push -u origin <type>/<run-slug>`.
5. Set `design.needed` from the scout: true when `ui_screens` is non-empty (the story adds
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
per branch means no push races. Then, for each branch it merged, it runs the cleanup
(*Branches and worktrees*): harness worktree removed, `wip/` branch and harness branch
deleted locally and on origin. It returns each story's tip sha and merge sha; record them
in `bmn.json` (REVIEW diffs them) along with what was deleted or left. The next wave
branches from the updated run branch.

### 4 · REVIEW① (one agent per story, parallel, opus)
Reviewer brief. Run `/code-review` at `high` on the story's diff, plus the routed
python-library-quality lenses (security, API design, untrusted content, destructive
operations, external behavior, heavy dependencies) that match the diff. A screen that departs
from the picked design (layout, components, tokens, copy) is HIGH. Write `review.md`.
Any CRITICAL or HIGH finding goes to a fixer (sonnet, or opus if unclear) on a fresh
`wip/<run-slug>/<slug>-fix-<n>` branch off the run branch, which the integrator merges and
cleans up, then gets re-reviewed. The loop repeats until there is no CRITICAL or HIGH finding
left.

### 5 · MERGE→dev ① (1 agent, sonnet)
Merger brief. In the run worktree, merge `origin/dev` into the run branch, run the full
gates, push. Then merge into `dev` in a throwaway detached worktree, never by checking out
`dev` anywhere: `git worktree add --detach ../<repo-name>-<run-slug>-dev origin/dev`, there
`git merge --no-ff <type>/<run-slug> && git push origin HEAD:dev`, then `git worktree remove`
it. It never touches `main`. If `stack.dev_push_deploys`, skip the `dev` merge — TEST runs
on the run branch, and the report lists the `dev` merge on the Deploy checklist.

### 5b · DB-SYNC (1 agent, sonnet; after every MERGE that brought new migrations)
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

### 6 · TEST① (1 agent per test surface, parallel, sonnet)
Tester brief, run against the merged `dev`:
- **TDD suite**: the full `pytest` (or `vitest`/`jest`) run, plus coverage. Target is 80% or
  higher on the code the stories touched.
- **Browser** (whenever `stack.ui` is true, or the app serves HTML): start the app locally,
  and start local Supabase if it's used. Drive every story's user-facing acceptance
  criterion in headless Playwright. Screenshot every screen in `design.md` and compare it
  with its `design/*.html` reference; a structural mismatch is a failure. Collect screenshots in `validation.md` as file paths,
  and console errors plus failed network requests as findings.
- **API / MCP surfaces**: black-box calls against the running server (httpx for APIs; an MCP
  client session that lists and calls tools for MCP servers).
Failures go into each story's `validation.md` as findings.

### 7 · FIX (one agent per failing story, parallel, sonnet → opus if the first attempt fails)
Fixer brief. Reproduce the failure as a test first, fix it, and run the gates. The fix goes
on a fresh `wip/<run-slug>/<slug>-fix-<n>` branch off the run branch; the integrator merges
and cleans up fix and test branches serially, same as BUILD. **No attempt cap.**
Keep fixing until the failure is gone or it turns into a real blocker.

### 8–10 · REVIEW② → MERGE→dev ② (+ DB-SYNC) → TEST②
Same as steps 4–6, scoped to what changed since the first merge. If TEST② is not clean, go
back to step 7. The run moves on only when REVIEW② shows no CRITICAL or HIGH findings and
TEST② is fully green.

### 10b · REVIEW③ — whole run (1 agent, opus)
Final-reviewer brief. The per-story reviews never see the stories together, so this one
does. Run `/code-review` at `max` on the whole run's diff, `git diff {dev_base}...<tested sha>`
(the run branch when `stack.dev_push_deploys`). Apply every routed review lens,
plus `nextjs-fullstack-standards` for TypeScript. Look for what only shows up across
stories: duplicated helpers, contracts that disagree, migrations that conflict or run in
the wrong order, config keys that nothing reads, and acceptance criteria no story covered.
Write `review-final.md` (one "Round n" section per pass). Any CRITICAL or HIGH finding
goes back to step 7 (FIX), grouped by the story that owns the file. A finding that no
story owns goes to a run-level `wip/<run-slug>/run-fix-<n>` branch. Then REVIEW② → MERGE② → TEST② → REVIEW③ run
again. The run moves on to REPORT only when REVIEW③ shows no CRITICAL or HIGH findings.
MEDIUM and LOW go in the report under *Left open*.

### 11 · REPORT (orchestrator)
The report names the picked design and links its Claude Design project. Fill in [references/report-template.md](references/report-template.md) and write it to
`report.md`. Set `phase: cleanup`, commit both in the run worktree, and have the merger
merge to `dev`. The **Deploy checklist** comes first.
It lists which migrations were applied to Supabase **dev** and which are waiting for
**main**. It also lists any dev migrations that were held back, and why. It ends with a
ready-to-say Vercel line: "`dev` is ready for a Vercel dev deploy:
`vercel deploy --target=<env>`". Nothing Vercel- or main-related is run. The *Git cleanup*
section is filled in by CLEANUP.

### 11b · CLEANUP (1 agent, sonnet) — mandatory, never skipped
Cleaner brief. Its ref and worktree commands run as `git -C <main checkout>`, which changes
no file or branch there. It touches only what `bmn.json` names:
1. **Sweep.** Every `temp_refs` entry still present: if it's in the run branch
   (`merge-base --is-ancestor`), remove its worktree, delete it locally and on origin;
   otherwise leave it, with the reason.
2. **Run branch.** `git fetch --prune origin`. If the run branch is in `origin/dev`: remove
   the run worktree (no `--force`), `git branch -D` it, `git push origin --delete` it,
   `git worktree prune`. If it isn't (`dev_push_deploys`, blocked before merging) or the
   worktree is dirty, leave it and say why.
3. **Record.** Write the *Git cleanup* section of `report.md` and `bmn.json`
   (`cleanup`; `phase: done` unless it's `blocked`), and commit
   `chore(bmn): record git cleanup for <run-slug>`. When the run branch was merged, that
   commit goes to `dev` through a throwaway detached worktree (`push origin HEAD:dev`, then
   remove it) and also drops the run branch's `deploymentEnabled` key from every
   `vercel.json`. Otherwise it goes on the run branch in the run worktree, key kept.

### 12 · ALERT (orchestrator)
Load `PushNotification` with ToolSearch and send one line: the outcome, the story count,
and whether any deploy is waiting. Then post the report's *Summary*, *Deploy checklist* and
*Git cleanup* sections in chat, with a link to `report.md`. This is the only long message
Jonathan gets.

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
