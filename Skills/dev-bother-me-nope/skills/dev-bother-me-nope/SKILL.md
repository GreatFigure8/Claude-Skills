---
name: dev-bother-me-nope
description: Jonathan's seven-step build pipeline — one long free-form story in (a bug fix, an error to resolve, a feature, or an ENTIRE system), then 1 create the sprint (any user interface is designed FIRST in Claude Design and Jonathan picks one direction), 2 plan each story, 3 code ONLY — no test is written or run, just lint and the type-check — using the right python skill set (python-web-app for APIs/web apps, python-mcp-servers for MCP servers, python-library-quality for libraries/CLIs, python-llm-features for LLM calls; nextjs-fullstack-standards (when the session has it) plus the plugin's Next.js reference if the repo is TypeScript) and merge to dev, 4 once ALL coding is done ask Jonathan "run a test cycle?" and, on yes, how many test → fix → test cycles he wants (he enters a number), 5 run exactly that many cycles (the first test run writes the plans' tests and runs ONE code review beside them; each cycle fixes what failed, test-first, then tests again; what the last run still finds is reported, never fixed), 6 report, a silent retro that turns what went wrong into lessons the next run's briefs carry, and alert, 7 ask Jonathan "release?" — yes runs the whole release (Supabase MAIN migrations, version bump and tag, dev merged into main with dev and main left on the same commit, Vercel production deploy, smoke check); no, and Jonathan decides what's next. Those three questions are the only ones: between them it never asks anything and never deploys — merges to dev never trigger a Vercel build and migrations go to the Supabase DEV database only. Use whenever Jonathan says "dev-bother-me-nope", "/dev-bother-me-nope", "/goal execute /dev-bother-me-nope for …", "/goal using dev-bother-me-nope …", "don't bother me, just build …", or pastes a long build story and says to just do it. Also use when Jonathan says "I'm moving computers", "switching machines" or "move-computers" (write a handoff for every open run), when Jonathan says "/dev-bother-me-nope learn" or "bmn learn" (backfill lessons from past runs and propose promoting the proven ones into the plugin), and at the start of every coding session (pick up open handoffs from another machine).
---

# dev-bother-me-nope

One long story in. Seven steps:

```
1 SPRINT    intake → DESIGN (UI only: Jonathan picks) → split into stories     [manual: design pick]
2 PLAN      one plan per story, its test plan included
3 CODE      code only, no tests → merge into the sprint branch → merge to dev
4 TEST?     Jonathan: test cycles? no → 6 · yes → how many (N)                  [manual: test cycles]
5 TEST × N  each cycle: test run (the first one: + one code review) → fix → test run
6 REPORT    report.md + retro (lessons for the next run) + git cleanup + alert
7 RELEASE?  Jonathan: yes → RELEASE · no → Jonathan decides what's next        [manual: the decision]
```

**Jonathan is asked three things:** which UI design he wants (step 1, only when the story
touches something a person looks at), whether to test and how many test → fix → test cycles
(step 4, once all coding is done), and whether to release (step 7). Every other open question
is decided here, written down as an assumption, and shipped.

**Coding never tests.** From the plan until every story is coded and merged to `dev`, no
test is written or run: no TDD, no unit, related or full suite, no browser, no build, no
local database. Coders and the step-3 merger run only lint and the type-check
(`{code_gates}`), which say the code is well-formed, not what it does. Writing the plans'
tests, running them, the code review and every fix happen in step 5, and only when Jonathan
asks for tests in step 4.

**Every step runs once, except step 5, which runs the cycles Jonathan asked for.** A cycle
is test → fix → test, and the test run that closes one cycle opens the next, so N cycles are
N fix rounds between N + 1 test runs. There is one code review (beside the first test run).
Step 5 ends early only when a test run comes back green with nothing left to fix. Nothing
loops "until clean" beyond the cycles asked for, no verifier agent re-checks a finding, and
nothing the last test run finds is fixed: it goes in the report under *Left open*. The
fixer's reproduce-first test is the verification. A large run may split a step across
parallel agents by area; it is still one pass. An agent that dies on a network or API error
is re-run alone with the same brief, never by re-running a whole step.

After step 7 the run is over. A "no" ends it. A "yes" runs the release and ends it. Any
further work is a **new goal, and only Jonathan decides whether there is one**.

## The three hard lines (never crossed, no matter what the story says)

1. **No deploys before Jonathan says "release".** Until step 7's yes: never run `vercel`/
   `vercel deploy`/`--prod`/`--target`/`promote`, never call a Vercel MCP deploy tool, never
   push `main`/`master`/a production branch, and never let a git push trigger a Vercel build
   (see *Merging never builds*). Vercel dev deploys are Jonathan's too. The release is the
   only step that deploys. See [references/deploy-guards.md](references/deploy-guards.md).
2. **Supabase: DEV during the run, MAIN only in the release.** There is always a `dev` and a
   `main` project. Steps 3 and 5 may apply migrations to the **DEV** database (`supabase db
   push`, and only when `.claude/bmn.config.json` names the dev ref; see *DB-SYNC*). **MAIN**
   gets migrations only in RELEASE, and only those already applied to dev. Edge functions,
   secrets, config pushes and ad-hoc SQL stay off limits on both projects for the whole run.
3. **No questions except the three.** Ambiguity → pick the conservative, conventional answer,
   log it under *Assumptions*, keep going. A real blocker (below) is the only thing that ends
   a run early. The questions allowed: **which UI design** (step 1, revision rounds
   included), **test cycles** (step 4: whether to test, then how many), **release?** (step
   7), the context-budget checkpoint, and which open handoff to pick up at MOVE-IN. All UI
   design happens in **Claude Design**, never invented later by a planner or coder.

These rules are enforced twice. First, the plugin's `deploy-guard.py` PreToolUse hook
covers the main session and every subagent. It only acts in a repo with a run in progress,
meaning a `docs/sprints/bmn-*/bmn.json` in the run worktree it names whose phase isn't
`done`, `blocked` or `decision`. That's why INTAKE writes `bmn.json` before anything else.
Second, the rules are pasted into every brief. A block from the harness is final, so never
try to route around one.

## Silence — non-negotiable

**Do not talk.** Nothing in this skill is conversational. Between the start of the run and
the ALERT, the orchestrator says exactly: the model table for each spawn, at most one line
per step (the first one states the story count, the waves and a time estimate — see *Speed
rules*), the design pick question, the test-cycle questions, the context-budget line, a
one-line acknowledgement when Jonathan asks for speed, and a real blocker. Every subagent
says nothing but its return summary (never addressed to Jonathan). No progress narration, no
restated plans, no "done with step N", no explaining what a tool call found — from the
orchestrator or anything it spawns. This overrides any instinct to explain, summarize
progress, or narrate.

## Branches and worktrees — the main checkout is Jonathan's

**bmn never runs `git checkout`/`switch`/`merge`/`reset`/`rebase`/`pull`/`stash` in the
repo's main checkout.** That checkout belongs to Jonathan, so he can code alongside a run.
Every branch bmn makes is one of these:

| What | Name | Lives | Deleted |
| --- | --- | --- | --- |
| **Sprint branch** (the run's integration branch; permanent until merged) | `sprint/<run-slug>`, cut from `origin/dev` | the **run worktree** `../<repo-name>-<run-slug>` (sibling of the main checkout) | at CLEANUP (step 6), after its last merge to `dev` — not after step 3, because FIX still branches from it |
| Story, fix and test branches (temporary) | `wip/<run-slug>/<slug>` | a harness worktree (`isolation: "worktree"`) | as soon as the merger has merged it — local, origin and every worktree on it |
| Dev-merge, release and record scratch (temporary) | detached, no branch | `../<repo-name>-<run-slug>-dev` (`-main` for the release merge) | in the same command that made it |

Temp branches never sit under the sprint branch's name: git can't hold `sprint/x` and
`sprint/x/y` at once. All merger and orchestrator git work happens in the run worktree.
Jonathan may open it and commit there too, so the merger pulls (`--rebase=merges`) before it
pushes, never force-pushes, and never stashes, resets or checks out over changes it didn't
make. Every ref and worktree the run creates is recorded in `bmn.json` (`integration`,
`worktree`, `temp_refs`). Cleanup only ever touches those refs, plus every worktree that has
one of them checked out (from `git worktree list --porcelain`), even one bmn didn't create;
the main checkout is never removed or switched.

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

**Merging** means merging the sprint branch into the repo's `dev` **git branch** and pushing
it. That happens in steps 3, 5 and 6. It is not a deploy, and it must not cause one. If the
repo has no `dev` branch, INTAKE creates it from the default branch. Story work never merges
straight into `main`: only RELEASE merges `dev` into `main`.

For a Vercel app, INTAKE ensures every `vercel.json` (repo root and each app dir linked to a
Vercel project) turns off git-triggered deployments for every branch the run pushes. It
merges the setting into the file without touching other keys:

```json
{ "git": { "deploymentEnabled": { "dev": false, "wip/**": false, "bmn/**": false, "sprint/<run-slug>": false } } }
```

(`git.deploymentEnabled` takes a branch map with minimatch patterns — Vercel docs,
project-configuration/git-configuration.) `wip/**` is permanent; `bmn/**` covers runs from
before 1.4.0. The sprint branch is listed by its **exact name**, so Jonathan's other branches
keep their previews; CLEANUP removes that key again in its final commit to `dev`. `main` is
never listed: its git-triggered production build is what RELEASE relies on. Not
`ignoreCommand`: an ignored build still creates a (cancelled) deployment that counts against
quotas and build slots. This commit is the **first commit** on the sprint branch, made before
its first push. Vercel doesn't document whether a commit's own `vercel.json` governs that same
push, so the report says the sprint branch's first push *may* have produced one build.

A CI workflow can also deploy on push to `dev`, for example `vercel deploy` in GitHub
Actions, or anything that touches Supabase **main**. The stack-scout checks for this. If it
finds one (`stack.dev_push_deploys: true`), the run doesn't push to `dev` before step 7. It
merges and tests on the sprint branch instead, and RELEASE merges the sprint branch into
`dev` first; the sprint branch and worktree stay until then.

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

Everything lives in `docs/sprints/bmn-<run-slug>/` on the sprint branch, in the run worktree:

| File | Written by | Holds |
| --- | --- | --- |
| `input.md` | INTAKE | Jonathan's story, verbatim |
| `bmn.json` | orchestrator only (the cleaner and the release-prep worker write it at steps 6 and 7) | run state machine (below) |
| `stack.md` | INTAKE | stack classification, skill and reference routing ([references/stack-routing.md](references/stack-routing.md)), release profile |
| `lessons.md` | INTAKE | the lessons served to this run, one `## <brief>` section per brief ([references/learning.md](references/learning.md)) |
| `design.md` | DESIGN | the picked direction: Claude Design link, tokens, per-screen layout, components, states, copy |
| `design/*.html` | DESIGN | local copy of the picked Claude Design pages (coders and testers read these, not the MCP) |
| `<story-slug>/story.md` | SPLIT | the story, acceptance criteria, deps and the interfaces it consumes, assumptions |
| `<story-slug>/<story-slug>-plan.md` | PLAN | implementation plan + test plan + interfaces provided |
| `<story-slug>/validation.md` | step 5's test runs and fixers | test commands, results, browser evidence per test run; what each FIX did with each item |
| `review.md` | the reviewer, beside test run 1 | severity-ranked findings (id, file:line, scenario, owning story) |
| `validation.md` | FIX | what FIX did with findings no single story owns |
| `handoff.md` | MOVE-OUT | machine-move handoff; renamed `handoff-<ts>.md` once picked up |
| `report.md` | REPORT | the summary Jonathan reads, with the release checklist |
| `retro.md` | RETRO | what this run taught, each lesson with its evidence |

No `sprint.json` in this folder on purpose, so a running dev-story-flow loop never picks
up a bmn run. One file lives outside it: RETRO's `docs/bmn/lessons/<run>.jsonl`, this run's
events in the repo's lessons ledger (*Learning*).

`bmn.json`:

```json
{
  "run": "bmn-<run-slug>", "estimate": "<first step line's estimate, e.g. ~2 h>",
  "phase": "intake|design|split|plan|code|testask|test|fix|report|decision|done|blocked",
  "integration": "sprint/<run-slug>", "worktree": "<abs path of ../<repo-name>-<run-slug>>", "live": "dev", "dev_base": "<sha of origin/dev when the run started>",
  "tests": {"wanted": null, "cycles": 0, "cycle": 0, "runs": [{"n": 1, "sha": "<sha the test run tested>", "pass": 0, "fail": 0, "branches": []}]},
  "stack": {"kind": "web-app|api|mcp-server|library|cli|mixed", "ui": true, "supabase": false, "vercel": false, "vercel_json": [], "dev_push_deploys": false, "supabase_dev_ref": null, "supabase_main_ref": null},
  "stories": [{"slug": "...", "title": "...", "deps": [], "interfaces": [{"dep": "<slug>", "contract": "<what this story consumes>", "plannable": true}], "status": "split|planned|built|merged|tested|done|blocked", "branch": "wip/<run-slug>/<slug>", "merges": [{"branch": "...", "tip": "<sha>", "merge": "<sha>"}], "detail": ""}],
  "temp_refs": [{"branch": "wip/<run-slug>/<slug>|<harness branch>", "kind": "wip|harness", "base": "<sha at spawn>", "worktree": "<abs path>|null", "pushed": false}],
  "integration_pushed": false,
  "cleanup": {"deleted": [], "left": [{"ref": "...", "why": "dirty worktree|not merged|..."}]},
  "repo_policy": null,
  "deploy_pending": {"vercel": [], "supabase_migrations": [], "env": []},
  "supabase_dev_applied": [],
  "design": {"needed": false, "project_id": null, "url": null, "round": 0, "options": [{"key": "a", "name": "...", "open_url": "..."}], "picked": null, "feedback": []},
  "release": {"status": "pending|declined|released|failed", "version": null, "tag": null, "bump": "major|minor|patch|none", "at": null, "steps": [{"step": "...", "result": "..."}]},
  "handoff": null,
  "speed": {"requested": false, "skipped_gates": []},
  "lessons": {"served": [], "retro": null},
  "feedback": [{"at": "<iso8601>", "step": "<phase when he said it>", "text": "<Jonathan's words, verbatim>"}],
  "assumptions": [], "blocker": null, "updated": "<iso8601>"
}
```

`lessons.served` holds the lesson ids INTAKE gave the briefs; `lessons.retro` is RETRO's
commit sha once it has run. `feedback` starts empty and gets an entry whenever Jonathan
corrects or instructs the run in chat (*Learning*).

`tests.wanted` is `null` until Jonathan answers step 4, then `true` or `false`; `cycles` is
the number he entered; `cycle` is the fix round in progress (0 before the first); `runs[]`
holds one entry per test run, in order.

Write `bmn.json` atomically (write to a temp file, then `mv`), with a new object each time.
Commit the run folder in the run worktree at the end of every step. **Moving computers:**
when Jonathan says he's moving machines, run MOVE-OUT. On every start, run MOVE-IN *before*
the resume rule. It finds open handoffs in the run worktrees and on origin's sprint branches,
and asks which one to pick up. Both procedures are in
[references/move-computers.md](references/move-computers.md).

**Resume rule:** look for run folders in every worktree (`git worktree list`) and on
`origin/dev`. If a `bmn-*` run with `phase` other than `done` or `blocked` exists and the
objective doesn't clearly name a new story, re-read `bmn.json` and continue from `phase`,
trusting only what's on disk. Phases only move forward in enum order, except inside step 5,
where `test` and `fix` alternate while `tests.cycle` counts up; a resumed step 5 continues at
its `phase` and `tests.cycle`. A fix round never runs for a cycle above `tests.cycles`, so a
run resumed at its last test run never fixes again. A run resumed at `testask` asks the
test-cycle questions again. `report` covers REPORT, RETRO and CLEANUP: re-run whichever of
the three hasn't committed (RETRO has when `lessons.retro` is set). A run resumed at
`decision` reads `bmn.json` from `origin/dev`: if the release already started (a `release: v<version>` commit on `origin/dev`, or its tag on
origin), it finishes the remaining RELEASE steps, because Jonathan already said yes;
otherwise it asks the release question again. A run resumed at `design` with `design.picked:
null` re-asks the design question from the options already in `bmn.json` — it doesn't
redesign.

A run from before 3.0.0 (its `bmn.json` has `test_shas` and no `tests`) maps its old phase
first: `build` and `merge1` → `code`; `review1` and `test1` → `testask` (its code was built
test-first, but Jonathan still chooses the cycles); `fix1`, `merge2` and `fix` → `fix` in
cycle 1 of 1 (`tests: {wanted: true, cycles: 1, cycle: 1}`, with `test_shas.test1` as run 1);
`test2` → `test`, the run that closes that one cycle, so nothing it finds is fixed; `review2`,
`review3` and `cleanup` → `report` (a `review2`'s findings go under *Left open*). Its
integration branch keeps its old `<type>/<run-slug>` name; `integration` in `bmn.json` is the
source of truth for every branch name.

**Leftover sweep:** a `done`, `blocked` or `decision` run whose `cleanup.left` names its
sprint branch, and that branch is now in `origin/dev` (Jonathan merged it), gets CLEANUP's
sprint-branch step now:
`python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py --repo <main checkout> --branch <sprint branch> --target origin/dev`,
adding `--local-only` when that run's `integration_pushed` is false (the sweep never deletes an
origin copy the run didn't push).

## Orchestrator discipline

The main thread decides and dispatches. It doesn't read source, run test suites, or grep
the codebase. That work is done by subagents, which report back conclusions. The only
commands the orchestrator runs itself are INTAKE's git setup and its lessons `select`, the
`bmn.json` commits, and RELEASE's approved deploy commands (the only place the approval
prefix is used).

- Every subagent is `subagent_type: "dev-bother-me-nope:bmn-worker"`. Briefs come from
  [references/briefs.md](references/briefs.md) and are filled in, not paraphrased.
  `{skill_dir}` in a brief is this skill's base directory, the path shown when the skill
  loads.
- `${CLAUDE_PLUGIN_ROOT}` is empty in a worker's Bash. The orchestrator fills it like a
  placeholder, with the absolute plugin root (`{skill_dir}/../..`, resolved), in every brief
  and in its own Bash calls when the variable is empty.
- Every spawn is announced with the model table (Item | Branch | Model), one row per agent,
  and the model named explicitly: `model: "opus"` for DESIGN, SPLIT, PLAN, the reviewer,
  RETRO and any FIX item whose root cause is unclear; `model: "sonnet"` for CODE, TEST, merges,
  mechanical fixes, DB-SYNC, CLEANUP and release-prep.
- Independent agents run in one message, all at once. A story is ready when every one of its
  `deps` is merged or has a planned, stated interface (*Speed rules*); ready stories build in
  parallel, each in `isolation: "worktree"`. Record every harness worktree path and branch
  the Agent result names, plus each `wip/` branch, in `temp_refs`.
- CODE, FIX, TEST and DB-SYNC agents always run in `isolation: "worktree"`; every other
  agent works in the run worktree (`{run_worktree}` in the briefs).
- Output to Jonathan while running: see *Silence* above.
- Context: at ~120K say so in one line. At ~150K, write `bmn.json` plus the run folder,
  commit, and post the `clear-prompt` block — the resume line is the same
  `/goal execute /dev-bother-me-nope` invocation. Asking about the context budget is one of
  the allowed questions, because Jonathan's global rules require it.

## Speed rules (Jonathan's rule, 2026-10-05)

A run of three small changes once took about four hours. These rules keep the safety of the
pipeline and drop the repeated work:

- **Coding runs no tests.** Coders and the step-3 merger gate on lint + type-check only
  (`{code_gates}` in the briefs). No test of any kind and no build runs before step 5.
- **The full suite runs once per test run.** Fixer and step-5 merger gates are scoped:
  lint + type-check + the tests for the files the agent touched (or the merge changed) and
  their related tests (`{gates}` in the briefs). None of them runs the full test suite or
  the build. The full suite, coverage and the build (`next build`, or the stack's
  equivalent) run only in step 5's test runs, by the tester (`{full_gates}`).
- **Review beside test.** The first test run dispatches the reviewer and the testers in one
  message, so the review costs no wall-clock time of its own.
- **Deps by interface.** A dependency only serializes stories when its interface can't be
  planned. The splitter names the interface each dependent story consumes, and the providing
  story's planner pins it in its plan (*Interfaces provided*, `plannable: true`). When every
  dep of a story has a planned, stated interface, that story builds in the **same wave**
  against the interface (its coder codes against the stated contract) and the merger merges
  deps first. Only a dep whose interface is truly unplannable (`plannable: false`) makes a
  story wait for the next wave.
- **One merge agent per step, gates once.** Step 3 and every step-5 cycle each end with a
  single merger. It merges every branch of the step into the sprint branch (`--no-ff`, deps
  first), runs its gates **once** over the combined change (`{code_gates}` in step 3, the
  scoped `{gates}` in step 5), and only when they fail reverts branch by branch to find the
  one that broke them. Then it merges the sprint branch into `dev`.
- **Up-front time estimate.** The orchestrator's first step line states the story count,
  the waves and a rough wall-clock estimate up to step 4, e.g. "4 stories, 1 wave, ~1.5 h to
  code". Rough guide: about 20 min each for SPRINT (plus however long the design pick takes),
  PLAN, a merge and REPORT; 20–40 min per CODE wave; and, when Jonathan asks for tests,
  30–45 min per test → fix → test cycle (the first a little longer: it writes the plans'
  tests and runs the review beside them). Step 4's question states the per-cycle estimate.
  Record the estimate in `bmn.json.estimate`; the report shows estimate vs actual.
- **Speed on request.** When Jonathan asks in chat for speed mid-run, the orchestrator
  acknowledges it in one line and sends every in-flight agent a message (load `SendMessage`
  with ToolSearch) to skip non-essential gates: coverage, lint or related tests on files the
  agent didn't change, screenshots of screens the run didn't touch, and the build outside
  a test run. Never skipped: a fixer's reproducing test, the type-check, each test run's full
  suite, and every hard line. Agents spawned after that get the same instruction in their
  brief. The report lists what was skipped.

## Learning — every run teaches the next one (3.1.0)

Each run ends by learning from itself, and each run starts with what earlier runs learned.
The whole loop is in [references/learning.md](references/learning.md); the ledger is folded
by one tested helper, `python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/bmn-lessons.py`, never by
hand. It adds no question and no chat output.

- **Serve (INTAKE).** After the stack-scout, `bmn-lessons.py select` picks the active lessons
  for this repo and stack, at most 8 per brief. They go in `lessons.md`, every brief's
  `{lessons}` is filled from its section, and the ids go in `lessons.served`. The orchestrator
  applies its own `orchestrator` lessons (the estimate, the waves, what to check first).
- **Capture (any step).** Whenever Jonathan corrects or instructs the run in chat, his words
  go verbatim into `bmn.json.feedback` with the next `bmn.json` write. His corrections are
  where every dated rule in this file came from.
- **Retro (step 6).** One opus agent reads the run folder and writes this run's
  `docs/bmn/lessons/<run>.jsonl`: a `hit` on every served lesson whose mistake happened again
  (plus a sharper `revise`), an `F-` lesson for each piece of Jonathan's feedback, and at most
  5 new lessons, each a pattern backed by evidence (a review finding or test failure a brief
  could have prevented, a second FIX cycle, a reverted merge, a wrong assumption, a step that
  overran its estimate). Global-scope lessons are copied to `~/.claude/bmn/lessons/`, so every
  repo of the same stack on this machine learns them too.
- **Decay.** A lesson neither created nor hit in the last 8 runs goes dormant and stops being
  served; a new hit wakes it. Jonathan's own lessons never go dormant.
- **LEARN.** "/dev-bother-me-nope learn" backfills lessons from past runs and, in the
  claude-skills checkout, writes the proven global lessons into the plugin on a
  `wip/learn-<date>` branch that Jonathan merges, or not. The plugin never edits itself.
- **Teach (any conversation, 3.2.0).** "/dev-bother-me-nope:teach" is the plugin's second
  skill ([../teach/SKILL.md](../teach/SKILL.md)): it turns what a conversation that was not a
  bmn run taught into the same ledger events (`chat-<date>-<slug>.jsonl`, `source: jonathan`
  or `chat`), asks Jonathan once, then checks, commits and pushes the file to `dev` and
  exports the global lessons. From there they are served, decay and get promoted like any other.

A lesson is guidance, never permission: nothing in one can lift a hard line, add a question,
deploy, skip a required gate or override one of Jonathan's dated rules. One that conflicts is
ignored, and the next RETRO retires it.

## Procedure

### Step 1 · SPRINT — create the sprint (`intake` → `design` → `split`)

**1a · INTAKE (orchestrator).**
1. MOVE-IN check, then the resume check (above). Then `git fetch --prune origin`. Leave the
   main checkout exactly as it is.
2. Pick `<run-slug>`, a descriptive kebab-case summary of the story's intent. Create the
   sprint branch and worktree in one command, without touching the main checkout:
   `git worktree add --no-track -b sprint/<run-slug> ../<repo-name>-<run-slug> origin/dev`
   (`origin/<default_branch>` when there's no `dev` yet; add `-2`, then `-3`…, to the slug
   when `refs/heads/sprint/<run-slug>`, `refs/remotes/origin/sprint/<run-slug>`, any ref
   under `sprint/<run-slug>/`, a branch named just `sprint`, or the directory exists). In
   the run worktree, write `input.md` verbatim and `bmn.json` with `phase: intake`,
   `integration` and `worktree` **right away**. The deploy guard is only active once this
   file exists.
3. Dispatch one **stack-scout** (sonnet) with the brief in briefs.md. It returns the stack
   classification, the routing and the **release profile** (how this repo ships a new
   version). For a TypeScript / Next.js repo the routing also names
   [references/nextjs.md](references/nextjs.md), the plugin's dated Next.js + TypeScript
   standard. The planner, coder, reviewer and fixer read it with the Read tool
   ([references/stack-routing.md](references/stack-routing.md)).
   The scout returns it in `routed_references[]`, never in a skill list; `stack.md`
   records that list, and every brief's `{routed_references}` is filled from it.
   Write `stack.md`. Then serve the lessons (*Learning*):
   `python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/bmn-lessons.py select --repo {run_worktree} --stack <kind> --tag <t>...`,
   one `--tag` per routed skill plus `supabase`, `vercel` and `ui` when the stack has them.
   Write each brief's `text` under a `## <brief>` heading in `lessons.md` and the `served` ids
   to `lessons.served`. A helper failure is an assumption ("no lessons served: <error>"),
   never a blocker; `{lessons}` is then "none yet".
   If the scout identified **both** Supabase refs, and each one is unambiguously labelled
   dev or main, write `.claude/bmn.config.json` =
   `{"supabase": {"dev_ref": "…", "main_ref": "…"}}`. The deploy guard reads this file,
   and it's what lets DB-SYNC push to dev and RELEASE push to main. If there's any doubt
   which ref is which, don't write it. Migrations then stay local and go on the release
   checklist as manual items for both projects.
4. If `origin/dev` doesn't exist, create it from the default branch with
   `git push origin origin/<default_branch>:refs/heads/dev` (branch creation, not a deploy
   — but if `stack.dev_push_deploys`, skip this and integrate on the sprint branch only).
   Record `origin/dev`'s sha as `dev_base` in `bmn.json`; the review diffs against it. In
   the run worktree, commit the `vercel.json` `deploymentEnabled` change for a Vercel app
   (plus `.claude/bmn.config.json` if it was written) **before** the first push, then
   `git push -u origin sprint/<run-slug>`, then set `integration_pushed: true` in `bmn.json`
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

**1b · DESIGN (UI only; designer agent, opus) — Jonathan's first decision.** Runs before
SPLIT, so no story, plan or line of code exists yet that a design would have to bend around.
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
   Jonathan is not asked anything until all coding is done (step 4).** A gap the design
   didn't cover (a screen, a state, an edge case) is filled by extending the picked
   direction's tokens and components, and logged as an assumption — never by asking, never
   by opening a new look.
4. If Claude Design is unavailable (tools missing, not signed in), that's not a blocker and
   not a question: the designer writes `design.md` from the repo's existing UI conventions,
   the run continues, and the report says the design was never picked.

**1c · SPLIT (1 agent, opus).** Splitter brief. When `design.md` exists, every screen in it
is owned by a story and its `[browser]` criteria name the design screen they check. It writes
one `story.md` per story, with its slug, title, acceptance criteria, deps, the interface it
consumes from each dep, and the assumptions it made. Sizing: one story is roughly one
reviewable PR. A one-line bug is one story. An entire system is a walking-skeleton story
first (scaffold, config, health route, test harness config, CI gates), then vertical slices.
It returns the story list plus deps and interfaces as JSON. Record it in `bmn.json`, state
the estimate (*Speed rules*), set `phase: plan`.

### Step 2 · PLAN (`plan`; one agent per story, parallel, opus)
Planner brief. Each planner writes `<slug>-plan.md` covering files to touch, the
skill-routed standards it will follow, a **test plan** (unit, integration, and browser checks
mapped 1:1 to acceptance criteria, with test names and paths: nobody writes or runs these
until step 5's first test run, and only when Jonathan asks for tests), the interfaces it
provides to dependent stories, migrations if any, and risks. UI work follows `design.md` and
`design/*.html`: same tokens, layout, components and copy. Set `phase: code`.

### Step 3 · CODE (`code`; one coder per ready story, parallel waves, sonnet, worktree; then one merger)
Coder brief. **Code only:** implement the plan, then run `{code_gates}` (lint + type-check).
No test is written or run — no TDD, no unit, related or full suite, no browser, no build.
Load the routed python skills **before** writing code. UI is built to `design.md`. Branch
`wip/<run-slug>/<slug>` off the sprint branch. Commit and push the **story branch only** —
coders never push the sprint branch. Supabase: migration files only, never run against any
database here (not even a local `supabase start`). Every new migration is added to
`deploy_pending.supabase_migrations`.

When a wave finishes, one **merger** (sonnet) merges that wave's story branches into the
sprint branch in the run worktree (*One merge agent per step*), runs `{code_gates}` once, and
cleans each one up with
`python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py --repo {run_worktree} --branch <branch> --target origin/{integration}`
(*Cleanup is a step*): every worktree on the branch removed, and the `wip/` branch deleted
locally and on origin, plus the paired harness branch once nothing unique is left on it. It
returns each story's tip sha and merge sha; append them to that story's `merges` in
`bmn.json` along with what was deleted or left. The next wave branches from the updated
sprint branch. After the **last** wave, the same merger also merges `origin/dev` into the
sprint branch and the sprint branch into `dev`, in a throwaway detached worktree, never by
checking out `dev` anywhere: `git worktree add --detach ../<repo-name>-<run-slug>-dev
origin/dev`, there `git merge --no-ff sprint/<run-slug> && git push origin HEAD:dev`, then
`git worktree remove` it. It never touches `main` and never squashes. If
`stack.dev_push_deploys`, it skips the `dev` merge and step 5 tests the sprint branch.
Then DB-SYNC, then `phase: testask`.

**DB-SYNC (1 agent, sonnet, `isolation: "worktree"`; after every merge to `dev` that brought new migrations).**
Record its worktree and branch in `temp_refs`.
This runs only when `.claude/bmn.config.json` exists and the merged `dev` has migrations that
aren't in `supabase_dev_applied`. Run
`supabase link --project-ref <dev_ref> && supabase db push --linked` in one command, then
`supabase migration list --linked` to confirm. Record the applied files in
`supabase_dev_applied`. Some cases are skipped and go on the release checklist instead:
- A migration that destroys data (`DROP TABLE`/`DROP COLUMN`/`TRUNCATE`, or `DELETE`/
  `UPDATE` without `WHERE`).
- The CLI isn't authenticated (no access token or DB password). Never enter a credential.
- The push fails.

Tests don't run against the dev database. They stay on local Supabase.

### Step 4 · TEST? — Jonathan decides on test cycles (`testask`)
Only once **all** coding is done: every story of every wave merged, the sprint branch merged
into `dev` (left on the sprint branch when `stack.dev_push_deploys`), and DB-SYNC finished.
Never per wave, never earlier. A blocked run is not asked: it reports and stops.

1. **Test or not.** Ask **one** `AskUserQuestion`: "All <n> stories are coded and merged to
   dev, and nothing has been tested yet. Run a test cycle?". Two options:
   - **Test** — description: "Next you choose how many test → fix → test cycles. The first
     test run writes the plans' tests and runs the one code review beside them; about
     <estimate> per cycle."
   - **No tests** — description: "Nothing is tested or reviewed. The report says the code is
     untested, then you get the release question."

   Never mark either option as recommended. **No tests** → set `tests.wanted: false`,
   `phase: report`. A whole number typed through "Other" counts as **Test** with that many
   cycles (0 counts as **No tests**).
2. **How many.** On **Test**, ask a second `AskUserQuestion`: "How many test → fix → test
   cycles?". Options `1`, `2` and `3`, each described in one line (`1` — "test, fix what
   fails, test again; whatever still fails is reported"), and Jonathan can enter any other
   number through "Other". An answer that isn't a whole number of 1 or more is asked again
   (0 counts as **No tests**). Never mark an option as recommended. Record
   `tests: {wanted: true, cycles: <N>, cycle: 0, runs: []}` and set `phase: test`.

The two questions are one interaction; Jonathan is not asked anything else until step 7.

### Step 5 · TEST × N — the test → fix → test cycles (`test` ⇄ `fix`)
Runs only when `tests.wanted` is true, with N = `tests.cycles`. Test run *k* finds failures,
FIX *k* fixes them, and test run *k* + 1 checks the fixes and opens the next cycle. So the
step is test run 1, then for each cycle *k* = 1…N: FIX *k*, then test run *k* + 1.

**5a · Test run k (`phase: test`; testers per surface, plus the reviewer in run 1, all in one message).**
Record the sha the merged `dev` is at (the sprint branch when `stack.dev_push_deploys`) as
`tests.runs[k-1].sha`, then dispatch the testers and, in run 1, the reviewer together.

**Testers** (1 per test surface, parallel, sonnet, each in `isolation: "worktree"`; record
each worktree and branch in `temp_refs`). Tester brief, run against that sha, `{run_n}` = k:
- **Run 1 writes the tests first.** The coders wrote none, so each tester writes every test
  its surface owns from every story's test plan (`<slug>-plan.md`), one or more per
  acceptance criterion, then runs them. From run 2 on, a test run adds no tests.
- **Unit + integration**: the full `pytest` (or `vitest`/`jest`) run, plus coverage, plus
  the build. Target is 80% or higher on the code the stories touched.
- **Browser** (whenever `stack.ui` is true, or the app serves HTML): start the app locally,
  and start local Supabase if it's used. Drive every story's user-facing acceptance
  criterion in headless Playwright. Screenshot every screen in `design.md` and compare it
  with its `design/*.html` reference; a structural mismatch is a failure. Collect
  screenshots in `validation.md` as file paths, and console errors plus failed network
  requests as findings.
- **API / MCP surfaces**: black-box calls against the running server (httpx for APIs, or
  Playwright's `request` fixture for a TypeScript / Next.js repo; an MCP
  client session that lists and calls tools for MCP servers).
- **From run 2 on**, also re-run every failure of run *k* − 1 and every fixer's reproducing
  test, each reported PASS/FAIL.

A TypeScript / Next.js repo takes all of this tooling from the TypeScript row of
[references/stack-routing.md](references/stack-routing.md)'s Test surfaces table: Vitest or
Jest, `@playwright/test` and the `request` fixture, never pytest-playwright or httpx.
Failures go into each story's `validation.md`. Record each run's pass and fail counts and
its branches in `tests.runs[k-1]`.

**Reviewer** (run 1 only; 1, opus; a large run may split by area across parallel reviewers
in the same message). Reviewer brief. Run `/code-review` at `high` on the whole run's diff,
`git diff {dev_base}...{test_sha}` (run 1's sha), plus the routed python-library-quality
lenses (security, API design, untrusted content, destructive operations, external behavior,
heavy dependencies) that match it, and for TypeScript `nextjs-fullstack-standards` (when the
session has it) plus [references/nextjs.md](references/nextjs.md), each finding citing the
rule id it breaks. Beyond per-file bugs, it looks for what only shows up across stories:
duplicated helpers, contracts that disagree, migrations that conflict or run in the wrong
order, config keys nothing reads, and acceptance criteria no test covers. A screen that
departs from the picked design (layout, components, tokens, copy) is HIGH. Findings go into
the run-level `review.md`, ranked CRITICAL/HIGH/MEDIUM/LOW, each with an id, file:line, a
concrete failure scenario and its owning story (`run` when no story owns it). When the pass
is split, each reviewer returns its JSON without writing, and the orchestrator writes
`review.md` from them, one section per area.

When every tester (and in run 1 the reviewer) has returned:
- **Green, with nothing to fix** (and, in run 1, a review that found nothing): the cycles end
  early, because another run would find the same. Set `phase: report`; the report says how
  many of the N cycles ran.
- **Run N + 1**, the run that closes the last cycle: **nothing it finds is fixed.** Every
  failure, HIGH included, goes straight to the report under *Left open*. Set `phase: report`.
- **Otherwise**: set `tests.cycle: k` and `phase: fix`.

**5b · FIX k (`phase: fix`; one fixer per owning story, parallel, each in `isolation: "worktree"`; then one merger).**
Record each worktree and branch in `temp_refs`.
Fixer brief. Input: every failure of test run *k*, plus, in cycle 1 only, every review
finding, every severity, grouped by owning story. Findings no story owns go to one `run`
fixer. Sonnet for mechanical fixes, opus when the root cause is unclear. Each fixer first
reproduces each item as a failing test — that reproduction **is** the verification — then
fixes it and runs the scoped gates. The tests came from test run 1, not from the coder, so a
fixer that finds the test itself wrong fixes the test and records it as such. An item it
can't reproduce is recorded as not-reproducible, with evidence, not argued. An item it can't
fix is recorded as blocked, with the reason. One attempt per fixer per cycle, no retry loop
inside it: an item that fails again in run *k* + 1 comes back in cycle *k* + 1 (when one is
left), with what earlier cycles tried (`{prior}`), so its fixer takes a different approach.
Each fixer works on a fresh `wip/<run-slug>/<owner>-fix-<k>` branch off the sprint branch.

Then one merger merges every fix branch and every test-run-*k* `tests-` branch into the
sprint branch, gates once (`{gates}`), cleans each up with `merged-branch-cleanup.py`, and
merges the sprint branch into `dev` exactly as in step 3. DB-SYNC if the fixes brought
migrations. Set `phase: test` for run *k* + 1.

### Step 6 · REPORT (`report`; orchestrator, then the cleaner)
Fill in [references/report-template.md](references/report-template.md) and write it to
`report.md` in the run worktree. The report names the picked design and links its Claude
Design project. **Your decision: release?** comes first: what was built, how it was tested
(the cycles Jonathan asked for and how many ran, each test run's pass and fail counts — or
**untested** when he chose no tests), what FIX fixed, what is left open (every failure of the
last test run, HIGH included, and every review finding no fix closed), and the proposed
release. The **Release checklist** comes next. It is built from the scout's release profile
and lists, in the order RELEASE will run them: the preflight (including the env vars or
secrets that must exist first, names only), the Supabase migrations that will go to **main**
(only ones already applied to dev; held-back ones are listed as manual items with the
reason), the release commit (the version bump `<current> → <next>` and why that bump, plus
the changelog entry), the `dev` → `main` merge and tag, `dev` fast-forwarded onto `main`, the
Vercel production deploy (git-triggered by the push to `main`, or `vercel deploy --prod`),
the GitHub release, and the smoke check. Nothing on it runs yet. Commit `report.md`.

**RETRO (still `report`; 1 agent, opus) — mandatory, never skipped, blocked runs included.**
Retro brief ([references/learning.md](references/learning.md)). In the run worktree it judges
the served lessons, turns Jonathan's feedback and the run's evidence (review findings, test
failures, FIX rounds, reverted merges, assumptions, estimate vs actual, the blocker) into
`docs/bmn/lessons/{run}.jsonl`, checks it with `bmn-lessons.py check`, exports its global
lessons with `bmn-lessons.py export-global`, writes `retro.md` and the report's *What I
learned* section, and commits all three on the sprint branch, so CLEANUP lands them on `dev`
with the report. Record its commit sha in `lessons.retro`. A RETRO that fails is recorded as
an assumption and the step goes on: learning never holds up the report.

**CLEANUP (still `report`; 1 agent, sonnet) — mandatory, never skipped.** Cleaner brief. It
first merges the sprint branch (the report, plus the last test run's branches: evidence, and
the tests run 1 wrote when no fix round followed it) into `dev` without re-running gates,
then sweeps. It runs the helper (*Cleanup is a step*) with `--repo <main checkout>`, which
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
2. **Sprint branch.** After the fetch, run
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
   (`cleanup`; `phase: blocked` when `blocker` is non-null, else `decision`) and every
   `vercel.json` (dropping the sprint branch's `deploymentEnabled` key, only when the origin
   copy was deleted too: an origin copy that stays keeps its key) inside that worktree,
   commit `chore(bmn): record git cleanup for <run-slug>`, push `HEAD:dev`, and remove it.
   Otherwise edit and commit in the run worktree, staging only `docs/sprints/bmn-<run-slug>/`,
   key kept.

**ALERT.** Load `PushNotification` with ToolSearch and send one line: the outcome, the story
count, the test cycles run (or "untested"), how many items are left open, how many lessons
the run learned, and the proposed version. Then post the report's *Your decision: release?*,
*Release checklist*, *What I learned* and *Git cleanup* sections in chat, with a link to
`report.md`. This is the only long message Jonathan gets.

### Step 7 · RELEASE? — Jonathan decides (`decision`)
Right after the ALERT, ask **one** `AskUserQuestion`: "Release v<next>?". Two options:
- **Release** — description: the checklist in one line (e.g. "2 migrations to Supabase main,
  dev → main, tag v1.4.0, Vercel production") plus how it was tested and what's still open
  ("2 cycles; 1 HIGH and 2 test failures left open", or "untested: you chose no test cycles").
- **Not now** — description: "Nothing is released. The run ends; you decide what's next."

Never mark either option as recommended. A blocked run (`phase: blocked`) is not asked: it
reports and stops.

- **Release** → run RELEASE below.
- **Not now** → in a throwaway detached worktree of `origin/dev`, set `bmn.json`
  `release.status: "declined"` and `phase: done`, commit `chore(bmn): <run-slug> not
  released`, push `HEAD:dev`, remove the worktree. Say one line: the run is done and nothing
  was released. Then **stop**: dispatch nothing, start nothing.
- **Anything else** (free text via "Other") → it's Jonathan deciding what's next. Treat it
  as "Not now" for this run, with his words added to `feedback` in that same `bmn.json`
  commit (the next RETRO in this repo learns from them), then do what he said as a new
  goal. If what he said is "release" with changes ("release, but skip Vercel"), run RELEASE
  with exactly those changes.

### RELEASE (after Jonathan's yes; orchestrator + 1 release-prep worker)
Jonathan's yes in chat is the approval for every step on the checklist, for this release
only. Each deploy command is prefixed with `BMN_USER_APPROVED_DEPLOY=1`. The order matters:
nothing reaches `main` until the database is ready for it, and nothing is committed to
either branch after `main` moves, so `dev` and `main` end on the same commit.

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

## Real blockers (the only early stop)

Stop, set `phase: blocked` and `blocker`, then run REPORT, RETRO, CLEANUP and ALERT with what
did ship (no test-cycle or release question). Do this only when:
- the work **requires** a credential, account, or paid resource that doesn't exist locally
  (never invent or enter one — see the prohibited-actions rules),
- the only path forward before step 7 is a deploy or a remote database change (hard lines 1
  and 2),
- or the story contradicts itself in a way where either reading would destroy data.

Everything else is an assumption, not a blocker.

## LEARN — when Jonathan says "/dev-bother-me-nope learn"

A maintenance pass outside any run, in the repo it's started in. It asks nothing, deploys
nothing and touches no run: on its own `wip/learn-<date>` branch and worktree it re-exports the
repo's ledger to the global one, backfills a ledger file for every past `bmn-*` run that has
none (the retro brief in `backfill` mode, at most 10 runs), and, only in the claude-skills
checkout, writes each proven global lesson into the plugin's own files and drops any edit the
plugin's tests reject. It pushes the branch, **never merges it**, and says in one short message
what it backfilled, what is ready to promote, and the branch to merge. Steps:
[references/learning.md](references/learning.md#learn--when-jonathan-says-dev-bother-me-nope-learn).

## When Jonathan says "deploy" outside step 7

This only applies when Jonathan says it in chat, in this session, naming the target (for
example "deploy to Vercel dev"). Run only that step, prefixed with
`BMN_USER_APPROVED_DEPLOY=1`, then confirm what landed. For Supabase main, check that every
migration is already on dev first. Approval covers one step and doesn't carry over to the
next one. "Release" always means step 7's RELEASE, with its whole checklist.
