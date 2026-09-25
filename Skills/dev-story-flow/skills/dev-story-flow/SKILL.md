---
name: dev-story-flow
description: Jonathan's silent, file-driven loop for shipping sprints of user stories autonomously — PLAN (parallel sub-agents write each story's plan plus a sprint impl-plan.md) then EXECUTE (parallel executors build every planned story, a code-review sub-agent reviews each story's diff, acceptance criteria are validated, failures fixed and re-validated, a pull request opened from the sprint branch to live, the sprint marked complete), then rescan for the next sprint. Jonathan runs it as `/loop /goal using dev-story-flow run` — each firing is one pass, and the skill re-arms the loop itself, so it keeps picking up new sprints until he stops it. Stories are created by the separate dev-story-intake skill; this one never talks to Jonathan beyond a model table, a blocker, and a closing message. Phases hand off through a committed sprint.json state machine (ready-to-plan → planning → planned → executing → complete), so any phase can run in any session. Use whenever Jonathan says "dev-story-flow", "/goal using dev-story-flow …", "plan the sprints", "execute the planned sprints", "run the flow", "run the flow until all planned sprints are complete", or asks what state a sprint is in. Do NOT use to create or intake a story (dev-story-intake), for a single story with no sprint folder (dev-story-sprint), or for issue-tracker intake and epic planning (dev-epic-workflow).
---

# Dev Story Flow

The silent half of the story pipeline. `dev-story-intake` (its own skill, in this plugin)
talks to Jonathan and writes stories. This skill never talks: the **planner** reads stories
and writes plans; the **coder** reads plans, ships code, has every story's diff **reviewed**,
validates it, and merges it. Each phase finds its work by scanning
`docs/sprints/*/sprint.json` for sprints in its input state, claims them, and advances them.
Nothing is held in chat memory between phases, so `/clear`, a new machine, or a week's gap
change nothing.

```
  dev-story-intake ──stories──► drafting ──► ready-to-plan
                                                   │
                       PLAN ◄──── list ready-to-plan ┘ ──► planning ──► planned
                                                                           │
                    EXECUTE ◄──── list planned ────────────────────────────┘ ──► executing ──► complete (PR to live open)
                     (per story: build → review → validate → done)                          └──► blocked
                     (rescans ready-to-plan + planned after every sprint; a pass ends when both are empty —
                      under /loop the skill re-arms itself and the next firing scans again)
```

Phase documents (read the one you are running — each is the full procedure):

- [references/sprint-state.md](references/sprint-state.md) — the manifest, state machine, claims, folder layout, and `sprint-state.sh` helper every phase uses. **Read first.**
- [references/dev-story-planner.md](references/dev-story-planner.md) — PLAN, `story.md` → `<slug>-plan.md` + `impl-plan.md`.
- [references/dev-story-coder.md](references/dev-story-coder.md) — EXECUTE, plans → merged, reviewed, validated, `complete`.
- [../dev-story-intake/SKILL.md](../dev-story-intake/SKILL.md) — the intake skill that feeds this one; not run from here.

## Invocation — objectives, not commands

The skill takes a free-text objective and maps it to a phase. The `/goal` skill is the
entry point Jonathan uses: `/goal using dev-story-flow <objective>`. Calling
`/dev-story-flow <objective>` directly is identical.

| Objective says… | Phase | Runs until |
|---|---|---|
| "run", "run the flow", "everything", "execute until all the planned sprints are completed", or no objective at all | **one pass**: PLAN every `ready-to-plan` sprint, EXECUTE every `planned` sprint (build → review → validate → PR to live), then rescan both states and repeat within the pass | nothing is `ready-to-plan` or `planned`, or the budget gate fires. Under `/loop` (below) the pass then re-arms the loop instead of ending; a `blocked` sprint is reported and the loop continues |
| "plan", "plan the sprints", "plan what's ready" | PLAN only | no `ready-to-plan` sprint remains |
| "execute", "run the planned sprints" | EXECUTE only | no `planned` sprint remains, or a sprint is `blocked`, or the budget gate fires |
| "status", "where are the sprints", "what's planned" | — | prints `sprint-state.sh list` and stops |
| "create", "new story", "add a story", "new sprint", or a pasted user story / requirements paragraph | intake → PLAN → EXECUTE | hands off in one call: `Skill({skill: "dev-story-flow:dev-story-intake", args: "<the objective>"})`. Intake writes the stories with its own assumptions (no question round), closes the sprint and calls back into `run` in the same turn — Jonathan's paragraph goes to working code with nothing asked of him |

An objective that names a sprint (`… execute sprint 2026-09-10-001`) restricts the phase to
that sprint. Ambiguous objective → run `sprint-state.sh list`; if anything is `ready-to-plan`
or `planned`, run the loop and say which sprint it starts with in one line; if nothing is,
say so in one line ("Nothing to plan or execute — `dev-story-intake` creates stories.") and
stop.

**Jonathan's standing instruction (2026-09-24): story it, plan it, implement it — don't question
him.** Ambiguity is resolved by a recorded assumption, never by a question; a working version
that he changes later beats a stalled one. This applies to every phase and every sub-agent.

**No go-ahead, ever.** The only human gates are outside this skill: `dev-story-intake` closing
a sprint, and Jonathan merging the PR each sprint opens against live. Under `plan` alone there
is a pause between `planned` and EXECUTE where `impl-plan.md` can be read; under `run` there is
none — `planned` **is** the approval. Once a phase starts it does not ask "shall I continue?"
— it finishes, blocks, or hands off. Stories enter through `dev-story-intake`, which closes a
sprint `ready-to-plan`; a running loop picks it up on its next firing with nothing pasted.

## Running it as a loop — Jonathan drives, the skill re-arms

The flow is meant to run unattended for as long as Jonathan wants, inside one session, as a
Claude Code `/loop`. He starts it (nothing else starts it — no daemon, no script, no cron):

```
/loop /goal using dev-story-flow run
```

Each firing runs **one pass** of the `run` objective above. At the end of every pass — after
the closing line, whether or not anything was found — the skill calls `ScheduleWakeup` with
`prompt: "/goal using dev-story-flow run"` (the same text, verbatim, every time) and:

| The pass… | `noop` | `delaySeconds` | `reason` |
|---|---|---|---|
| planned or executed at least one sprint | `false` | 60 — something may have been queued while it ran | "sprint <id> done, PR #<n>; rescanning" |
| found nothing `ready-to-plan` or `planned` | `true` | 1200–1800 | "no sprints queued; next scan in 20 min" |
| left a sprint `blocked` | `false` | 1200 | "sprint <id> blocked on <one line>; other sprints still flow" |

The skill never calls `ScheduleWakeup` with `stop: true` on its own. Only Jonathan ends the
loop (Esc while it waits, or `/clear`), and only the budget gate interrupts it: at 160k the
stopping-point procedure (rule 11) posts the `clear-prompt` hand-off and clears the session,
which ends the loop — the hand-off block tells Jonathan to paste `/loop /goal using
dev-story-flow run` again, and state on disk makes the restart the same as any firing. Idle
firings cost one `sprint-state.sh list` and one `ScheduleWakeup`, so an idle loop is cheap;
a firing that executes a sprint costs what that sprint costs.

Outside a `/loop` (Jonathan typed `/goal using dev-story-flow run` directly), the pass ends
with its closing line and nothing is scheduled — one pass is what he asked for.

## Rules shared by both phases

1. **State lives in `sprint.json`, committed.** Every status change is written by
   `assets/bin/sprint-state.sh` (which enforces legal transitions) and committed in the same
   step. An uncommitted manifest change does not exist to the next session.
2. **Claims prevent double work.** `planning` and `executing` record who holds the sprint.
   Fresh claims are skipped by other sessions; stale ones (default 6 h) may be taken over with
   one line saying so. See sprint-state.md.
3. **Silence — non-negotiable.** Nothing in this skill is conversational. PLAN and EXECUTE
   speak per sprint exactly: the model table, a genuine blocker, the closing message — plus one
   line on a re-dispatch model change or a stale-claim takeover. Every sub-agent, executor and
   reviewer says nothing but its return summary (≤ 20 lines, never addressed to Jonathan; a
   question is a `blocked` state, not a message). No progress narration, no restated plans, no
   "done with step N", from the orchestrator or from anything it spawns. Stay quiet and keep
   every sub-agent quiet unless there is a genuine issue that needs Jonathan's attention — a
   blocker, a stale-claim takeover, or the closing message. This overrides any instinct to
   explain, summarize progress, or narrate what a tool call found.
4. **Every spawn is announced with a model table first**, one table per sprint covering every
   sub-agent, item and reviewer, with a **Model** column. `model:` is always explicit —
   `"sonnet"` (Sonnet 5) by default, `"opus"` (Opus 5.5) only past the complexity bar stated in
   the phase doc. Never inherited.
5. **Maximum parallelism.** Planners: every story of a sprint in one message. Executors: every
   dependency-met item across all stories of the sprint in one message, waves not queues.
   Reviewers: one per story, dispatched the moment that story's last item merges, while other
   stories' items are still building.
6. **Executors run through `story-item-executor`** with `isolation: "worktree"`, always, using
   this skill's own dispatch template, control plane (`status.json`, cancel sentinel) and
   land-and-reset merge — see [references/dev-story-coder.md](references/dev-story-coder.md).
   The agents and their supporting hooks are this plugin's own assets (`agents/`, `hooks/`),
   wired in automatically on plugin install — see "Install" below.
7. **Every sprint ends in a PR to live, not a merge.** When every story is `done`, the coder
   runs the sprint gates on `sprint/<sprint>`, opens one pull request against live with the
   per-story review and validation evidence in its body, records the PR in the manifest, and
   marks the sprint `complete`. It never merges the PR and never deletes the sprint branch;
   both are Jonathan's. (`integration=none` sprints, where intake was told the repo takes work
   straight on live, are the exception: their items already landed and there is nothing to
   PR.)
8. **Every story is code-reviewed before it is validated.** When a story's items have all
   merged into integration, the coder dispatches one `story-code-reviewer` sub-agent
   (`isolation: "worktree"`) on the story's diff against live. It runs `/code-review` at max
   effort, applies `nextjs-fullstack-standards` to TypeScript and the `python-library-quality`
   skills to Python, checks Jonathan's global review rules, and writes `<slug>/review.md`.
   A CRITICAL or HIGH finding is a fix item, through the same fix loop as a failed AC; NOTEs
   are recorded, not chased. `claude ultrareview` (billed, cloud) runs only when Jonathan has
   set `DSF_ULTRA_REVIEW=1` in the environment — never by default. Model: Sonnet 5, or Opus 5.5
   when the story's risk surfaces name auth, user input, database queries, filesystem paths,
   external calls, crypto, or money.
9. **Acceptance criteria are proven, not asserted.** A story is `done` only when its review
   verdict is `PASS` and every row of its plan's Validation table passed against the
   integration branch, with the results in `<slug>/validation.md`. Service stories: unit gate
   + integration script against the running app. Interactive stories: TDD tests + browser
   checks by a verifier sub-agent.
10. **Fix loop is uncapped, shared by review and validation.** Review `FIX` or a failed AC →
   one fix item (Opus from attempt 3) → re-review / re-validate, as many rounds as it takes. A
   fix that uncovers new findings is normal progress, not a stall. Never `blocked` on attempt
   count and never `--force`; `attempts` is only a counter. Stop only for a decision Jonathan
   must make, or if the same finding survives two consecutive fixes — then say so.
11. **Testing is items, not ceremony.** The planner puts an interactive story's tests in wave 1
    (before its implementation items) and gives every service story an integration-test item.
    No coverage number is chased. Existing suites stay green as a gate. This is the flow's
    reading of the global TDD rule; executors otherwise follow `story-item-executor`'s no-TDD
    instruction because their tests arrive as their own items.
12. **Budget: stop dispatching at 150k, find a stopping point at 160k, never pass 165k** —
    this skill's own `context-budget-gate.sh` (`hooks/`) enforces it. At
    150k, land what is in flight and stop dispatching new work. At 160k, run the per-phase
    stopping-point procedure below (each phase's reference doc has a "Stopping point at 160k"
    subsection), make `sprint.json` truthful, commit, and call `Skill({skill: "clear-prompt",
    args: "dev-story-flow <phase> <sprint>"})`. At 165k the gate hard-denies further tool
    calls. Because state is on disk, resumption is the same objective again in a fresh chat.
    Past the stop threshold, this skill's own Stop hook (`handoff-stop-gate.sh`) won't let the
    turn end until the `clear-prompt` skill has posted the hand-off block, and `clear-prompt`
    clears the session itself once it has posted. Clearing ends a running `/loop`; the
    hand-off block names the `/loop /goal using dev-story-flow run` line to restart it.
13. **Never guess.** Read the manifest, the plan, the repo. "Not verified" is a complete
    sentence and a non-`done` story.

## The sprint folder, at a glance

```
docs/sprints/2026-09-10-001/
├── sprint.json                      status, branch line, claim, stories[], history[]
├── impl-plan.md                     planner — order, cross-story gotchas, open questions
└── <slug>/
    ├── story.md                     intake — statement, spec, deps/risks, AC by kind
    ├── <slug>-plan.md               planner — item table, Validation table, risks
    ├── review.md                    reviewer — lenses run, findings by severity, verdict
    └── validation.md                coder — per-AC evidence from the final passing run
```

Helper, from any repo, inside a Claude Code session (the plugin sets `CLAUDE_PLUGIN_ROOT`):

```bash
${CLAUDE_PLUGIN_ROOT}/assets/bin/sprint-state.sh list          # every sprint and its state
${CLAUDE_PLUGIN_ROOT}/assets/bin/sprint-state.sh get <sprint>  # one manifest
```

Running it from your own shell outside a session: find the live path with `claude plugin list`
(plugins install to a versioned directory under `~/.claude/plugins/cache/`).

## Relationship to the siblings

| | dev-story-sprint | dev-story-intake + dev-story-flow | dev-epic-workflow |
|---|---|---|---|
| Unit | one story, planned in chat | many stories, specified in intake, planned to files, executed as sprints | epics with tracked work items |
| Documents | none | `docs/sprints/<sprint>/…` | `docs/epics/<NN>-…/plan.md`, handoff |
| Human gate | "go" before wave 1 | sprint close in intake; merging the sprint PR | plan approval, PR review |
| Code review | none | `story-code-reviewer` per story, before validation | PR review |
| Executor | story-item-executor | story-item-executor (own copy) | work-item-executor |
| Resume | prep-for-clear prompt | manifest on disk (+ prep-for-clear) | handoff.md |

If a story is one-off and Jonathan wants it now, that is a sprint. If it needs issue intake,
epic numbering, PR ceremony, or a retro, that is an epic. Everything in between — a batch of
stories specified once and shipped unattended — is intake plus this flow.

## Install (once — via the Claude Code plugin manager)

This plugin, `dev-story-flow`, ships from a local marketplace at the root of this repo
(`.claude-plugin/marketplace.json`, `pluginRoot: ./Skills`). Add the marketplace once, then
install and update the plugin like any other — through the Claude Code UI's plugin manager,
or from the CLI:

```bash
claude plugin marketplace add ~/Source/claude-skills
claude plugin install dev-story-flow@claude-skills
```

A local-path marketplace re-reads the checkout on `claude plugin marketplace update` (or the
UI's Update action), so committing a change here and updating from the UI is enough — no
symlinks, no `install.sh`, no manual copy into `~/.claude/agents` or `~/.claude/hooks`. The
plugin bundles two skills (`dev-story-intake`, `dev-story-flow`), two agents
(`story-item-executor`, `story-code-reviewer` in `agents/`) and the control-plane hooks
(`hooks/hooks.json` plus the scripts it points at); Claude Code wires them all in on install.

**Not bundled:** `Skills/goal` is shared by dev-story-flow, dev-story-sprint, and
dev-epic-workflow, so it stays on its own standalone symlink into `~/.claude/skills/goal` —
out of this plugin's scope. The reviewer's lenses — the built-in `/code-review` skill,
`anthropic-skills:nextjs-fullstack-standards`, and the `python-library-quality` skills — are
not bundled either; the reviewer falls back to the lens's stated criteria when one is not
installed and says so in `review.md`.

**Not carried over:** the old installer also set the main-session statusline (branch | model |
context usage) when none was configured. A plugin's own `settings.json` can only wire a
`subagentStatusLine`, not the primary session one, so `hooks/statusline.sh` ships for
reference but isn't auto-wired — pointing your own `~/.claude/settings.json` at it (via
`claude plugin list` for the live path) is a manual, one-time step if you want it.

Tests: `bash assets/tests/sprint-state-fixtures.sh`.

## What this skill overrides from the global rules

- **Announce / brief updates:** PLAN and EXECUTE do not narrate (rule 3). The model table is
  the announcement; the closing message is the recap.
- **Context budget:** the 120k/150k `/handoff` rule is replaced by rule 12.
- **Model table per spawn:** satisfied once per sprint per phase (rule 4).
- **TDD / coverage:** read as rule 11.
- **Code review before commit to a shared branch:** read as rule 8 — per story, before
  validation, on the integration branch; the sprint's PR to live carries only reviewed
  stories.
- **Commit at task end:** every manifest change and every merge is a commit; executors commit
  continuously.

Everything else — immutability, error handling, secrets, review severity on auth/DB/money
paths — applies to the code the executors write, and the reviewer checks for it.
