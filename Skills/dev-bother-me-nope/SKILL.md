---
name: dev-bother-me-nope
description: Jonathan's zero-question build pipeline — takes one long free-form story (a bug fix, an error to resolve, a feature, or an ENTIRE system), breaks it into stories, plans each, codes them with the right python skill set (python-web-app for APIs/web apps, python-mcp-servers for MCP servers, python-library-quality for libraries/CLIs, python-llm-features for LLM calls; nextjs-fullstack-standards if the repo is TypeScript), code-reviews, merges to dev, tests (TDD pytest + real-browser Playwright), fixes, reviews and tests again, then writes a summary report and alerts him. Never asks a question and never deploys — Vercel deploys and Supabase database changes wait for Jonathan's explicit word, and the report tells him exactly what needs deploying. Use whenever Jonathan says "dev-bother-me-nope", "/dev-bother-me-nope", "/goal execute /dev-bother-me-nope for …", "/goal using dev-bother-me-nope …", "don't bother me, just build …", or pastes a long build story and says to just do it.
hooks:
  PreToolUse:
    - matcher: "Bash|mcp__.*"
      hooks:
        - type: command
          command: "python3 \"$HOME/.claude/skills/dev-bother-me-nope/assets/bin/deploy-guard.py\""
---

# dev-bother-me-nope

One long story in, merged-to-dev working code plus a report out. **Jonathan is not asked
anything between those two points.** Every open question is decided here, written down as an
assumption, and shipped.

```
INTAKE → SPLIT → PLAN → BUILD → REVIEW① → MERGE→dev → TEST① → FIX
       → REVIEW② → MERGE→dev → TEST② → REPORT → ALERT
```

## The three hard lines (never crossed, no matter what the story says)

1. **No deploys.** Never deploy any app — no `vercel`/`vercel --prod`/`vercel deploy`/
   `promote`, no Vercel MCP deploy tool, no push to `main`/`master`/a production branch.
   Jonathan says when. See [references/deploy-guards.md](references/deploy-guards.md).
2. **No remote database changes.** Never apply migrations, DDL, DML, edge functions or
   secrets to **either** Supabase project (there is always a `dev` and a `main` project).
   Migrations are written as files and tested against a **local** Supabase only. The report
   says, in plain words, which changes must be deployed to dev and then main.
3. **No questions.** Ambiguity → pick the conservative, conventional answer, log it under
   *Assumptions*, keep going. A real blocker (below) is the only thing that ends a run early.

These are enforced three times: the `deploy-guard.py` hook in this skill's frontmatter
(main session), the same hook in the `bmn-worker` agent definition (every subagent), and the
rules pasted into every brief. Harness blocks are final — never try to route around one.

"Merge to dev" = merge into the repo's `dev` **git branch** and push it. If the host
auto-builds a *preview* from that push, that's the host's git integration, not a deploy by
us; say so in the report. If the repo has no `dev` branch, INTAKE creates it from the default
branch — never merge story work straight into `main`.

**Unless pushing `dev` itself deploys.** The stack-scout checks for it: a CI workflow that
runs `supabase db push`/`migration up`/`functions deploy` or `vercel deploy --prod` on push
to `dev`, Supabase GitHub integration/branching wired to `dev`, or `dev` configured as a
Vercel production branch. If any is found (`stack.dev_push_deploys: true`), the run stops at
the integration branch `bmn/<run-slug>`: both MERGE steps merge and test there instead, and
"merge `bmn/<run-slug>` → `dev`" goes on the Deploy checklist for Jonathan.

## State on disk (resume-safe)

Everything lives in `docs/sprints/bmn-<run-slug>/` in the target repo:

| File | Written by | Holds |
| --- | --- | --- |
| `input.md` | INTAKE | Jonathan's story, verbatim |
| `bmn.json` | orchestrator only | run state machine (below) |
| `stack.md` | INTAKE | stack classification + skill routing ([references/stack-routing.md](references/stack-routing.md)) |
| `<story-slug>/story.md` | SPLIT | the story, acceptance criteria, assumptions |
| `<story-slug>/<story-slug>-plan.md` | PLAN | implementation plan + test plan |
| `<story-slug>/review.md` | REVIEW | severity-ranked findings, per round |
| `<story-slug>/validation.md` | TEST | test commands, results, browser evidence |
| `report.md` | REPORT | the summary Jonathan reads |

No `sprint.json` in this folder on purpose, so a running dev-story-flow loop never picks
up a bmn run.

`bmn.json`:

```json
{
  "run": "bmn-<run-slug>", "phase": "intake|split|plan|build|review1|merge1|test1|fix|review2|merge2|test2|report|done|blocked",
  "integration": "bmn/<run-slug>", "live": "dev",
  "stack": {"kind": "web-app|api|mcp-server|library|cli|mixed", "ui": true, "supabase": false, "vercel": false, "dev_push_deploys": false},
  "stories": [{"slug": "...", "title": "...", "deps": [], "status": "split|planned|built|reviewed|merged|tested|done|blocked", "branch": "bmn/<run-slug>/<slug>", "detail": ""}],
  "deploy_pending": {"vercel": [], "supabase_migrations": []},
  "assumptions": [], "blocker": null, "updated": "<iso8601>"
}
```

Write `bmn.json` atomically (write to a temp file, then `mv`), with a new object each time.
Commit the run folder at the end of every phase. **Resume rule:** if a `bmn-*` run folder
with `phase` other than `done` exists and the objective doesn't clearly name a new story,
re-read `bmn.json` and continue from `phase`, trusting only what's on disk.

## Orchestrator discipline

The main thread decides and dispatches. It doesn't read source, run test suites, or grep
the codebase. That work is done by subagents, which report back conclusions.

- Every subagent is `subagent_type: "bmn-worker"`. It runs with the deploy guard active.
  Briefs come from [references/briefs.md](references/briefs.md) and are filled in, not
  paraphrased.
- Every spawn is announced with the model table (Item | Branch | Model), one row per agent,
  and the model named explicitly: `model: "opus"` for SPLIT, PLAN, REVIEW and any FIX
  whose root cause is unclear; `model: "sonnet"` for BUILD, TEST, merges and mechanical fixes.
- Independent agents run in one message, all at once. Stories without unmet `deps` build in
  parallel, each in `isolation: "worktree"`.
- Output to Jonathan while running: the model tables and, at most, one line per phase
  transition. Nothing else until the report.
- Context: at ~120K say so in one line. At ~150K, write `bmn.json` plus the run folder,
  commit, and post the `clear-prompt` block — the resume line is the same
  `/goal execute /dev-bother-me-nope` invocation. Asking about the context budget is the
  one exception to "no questions", because Jonathan's global rules require it.

## Procedure

### 0 · INTAKE (orchestrator)
1. Resume check (above). Then `git fetch`, and record the branch that's checked out.
2. Pick `<run-slug>`, a descriptive kebab-case summary of the story's intent. Write
   `input.md` verbatim.
3. Dispatch one **stack-scout** (sonnet) with the brief in briefs.md. It returns the stack
   classification and routing. Write `stack.md`, then `bmn.json` with `phase: split`.
4. If `origin/dev` doesn't exist, create `dev` from the default branch and push it (that
   push is branch creation, not a deploy — but if `stack.dev_push_deploys`, skip this and
   integrate on `bmn/<run-slug>` only). Cut `bmn/<run-slug>` from `origin/dev` and push it.
   This is the integration branch.

### 1 · SPLIT (1 agent, opus)
Splitter brief. It writes one `story.md` per story, with its slug, title, acceptance
criteria, deps, and the assumptions it made. Sizing: one story is roughly one reviewable PR.
A one-line bug is one story. An entire system is a walking-skeleton story first
(scaffold, config, health route, test harness, CI gates), then vertical slices. It returns
the story list plus deps as JSON. Record it in `bmn.json`.

### 2 · PLAN (one agent per story, parallel, opus)
Planner brief. Each planner writes `<slug>-plan.md` covering files to touch, the
skill-routed standards it will follow, a **test plan written first** (unit, integration,
and browser checks mapped 1:1 to acceptance criteria), migrations if any, and risks.

### 3 · BUILD (one agent per ready story, parallel waves by deps, sonnet, worktree)
Coder brief. Strict TDD: write the failing tests from the plan, confirm they fail, implement,
confirm they pass, refactor, run the stack gates (lint, type-check, the full test suite).
Load the routed python skills **before** writing code. Branch
`bmn/<run-slug>/<slug>` off the integration branch. Commit and push the **story branch
only** — coders never push the integration branch. Supabase: migration files only, tested
against `supabase start` locally. Every new migration is added to
`deploy_pending.supabase_migrations`.

When a wave finishes, one **integrator** (sonnet) merges that wave's story branches into the
integration branch one at a time (rebase, `--no-ff`, gates, push). One writer per branch
means no push races. The next wave branches from the updated integration branch.

### 4 · REVIEW① (one agent per story, parallel, opus)
Reviewer brief. Run `/code-review` at `high` on the story's diff, plus the routed
python-library-quality lenses (security, API design, untrusted content, destructive
operations, external behavior, heavy dependencies) that match the diff. Write `review.md`.
Any CRITICAL or HIGH finding goes to a fixer (sonnet, or opus if unclear) on the story
branch, then gets re-reviewed. The loop repeats until there is no CRITICAL or HIGH finding
left.

### 5 · MERGE→dev ① (1 agent, sonnet)
Merger brief. Rebase or merge `origin/dev` into integration, run the full gates, then
`git checkout dev && git merge --no-ff bmn/<run-slug> && git push origin dev`. The merger
checks `git branch --show-current` in the same command as the merge. It never touches
`main`. If `stack.dev_push_deploys`, skip the `dev` merge — TEST runs on the integration
branch, and the report lists the `dev` merge on the Deploy checklist.

### 6 · TEST① (1 agent per test surface, parallel, sonnet)
Tester brief, run against the merged `dev`:
- **TDD suite**: the full `pytest` (or `vitest`/`jest`) run, plus coverage. Target is 80% or
  higher on the code the stories touched.
- **Browser** (whenever `stack.ui` is true, or the app serves HTML): start the app locally,
  and start local Supabase if it's used. Drive every story's user-facing acceptance
  criterion in headless Playwright. Collect screenshots in `validation.md` as file paths,
  and console errors plus failed network requests as findings.
- **API / MCP surfaces**: black-box calls against the running server (httpx for APIs; an MCP
  client session that lists and calls tools for MCP servers).
Failures go into each story's `validation.md` as findings.

### 7 · FIX (one agent per failing story, parallel, sonnet → opus if the first attempt fails)
Fixer brief. Reproduce the failure as a test first, fix it, and run the gates. The fix goes
on a fresh branch off the integration branch; the integrator merges fix branches serially,
same as BUILD. **No attempt cap.**
Keep fixing until the failure is gone or it turns into a real blocker.

### 8–10 · REVIEW② → MERGE→dev ② → TEST②
Same as steps 4–6, scoped to what changed since the first merge. If TEST② is not clean, go
back to step 7. The run moves on only when REVIEW② shows no CRITICAL or HIGH findings and
TEST② is fully green.

### 11 · REPORT (orchestrator)
Fill in [references/report-template.md](references/report-template.md) and write it to
`report.md`. Commit it, merge it to `dev`, and push. The **Deploy checklist** section comes
first whenever `deploy_pending` is non-empty. It lists exactly what must go to Supabase
**dev**, then **main**, and what Vercel deploy is waiting, with the exact commands for
Jonathan to approve. Nothing on that list is run.

### 12 · ALERT (orchestrator)
Load `PushNotification` with ToolSearch and send one line: the outcome, the story count,
and whether any deploy is waiting. Then post the report's *Summary* and *Deploy checklist*
sections in chat, with a link to `report.md`. Set `phase: done`. This is the only long
message Jonathan gets.

## Real blockers (the only early stop)

Stop, set `phase: blocked` and `blocker`, then run REPORT and ALERT with what did ship. Do
this only when:
- the work **requires** a credential, account, or paid resource that doesn't exist locally
  (never invent or enter one — see the prohibited-actions rules),
- the only path forward is a deploy or a remote database change (hard lines 1 and 2),
- or the story contradicts itself in a way where either reading would destroy data.

Everything else is an assumption, not a blocker.

## When Jonathan says "deploy"

This only applies when Jonathan says it in chat, in this session, naming the target (for
example "deploy the dev database" or "push it to Vercel prod"). Run only that step, from
the report's Deploy checklist. Prefix each command with `BMN_USER_APPROVED_DEPLOY=1` so the
guard lets it through, then confirm what landed. Dev comes before main for Supabase, every
time. Approval covers one step and doesn't carry over to the next one.
