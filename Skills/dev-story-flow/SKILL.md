---
name: dev-story-flow
description: Jonathan's three-phase, file-driven pipeline for shipping a whole sprint of user stories autonomously — CREATE (conversational intake that turns each story into a specification-grade story.md under docs/sprints/<sprint>/), PLAN (silent parallel sub-agents write one execution plan per story plus a sprint impl-plan.md), EXECUTE (silent parallel executors build every planned sprint, validate each story's acceptance criteria against the running result, fix and re-validate, merge to live, mark the sprint complete — no go-ahead awaited). Phases hand off through a committed sprint.json state machine (drafting → ready-to-plan → planning → planned → executing → complete), so any phase can run in any session and pick up where the last left off. Use whenever Jonathan says "dev-story-flow", "/goal using dev-story-flow …", "new sprint", "add a story to the sprint", "sprint complete / documentation complete / send it to planning", "plan the sprints", "execute the planned sprints", "run the flow until all planned sprints are complete", or asks what state a sprint is in. Do NOT use for a single story with no sprint folder (that is dev-story-sprint) or for issue-tracker intake and epic planning (dev-epic-workflow).
---

# Dev Story Flow

Three skills in one folder, chained by files, not by conversation. The **creator** talks to
Jonathan and writes stories. The **planner** reads stories and writes plans. The **coder** reads
plans and ships code. Each phase finds its work by scanning `docs/sprints/*/sprint.json` for
sprints in its input state, claims them, and advances them. Nothing is held in chat memory
between phases, so `/clear`, a new machine, or a week's gap change nothing.

```
  Jonathan ──stories──► CREATE ──► drafting ──► ready-to-plan
                                                      │
                          PLAN ◄──── list ready-to-plan ┘ ──► planning ──► planned
                                                                              │
                       EXECUTE ◄──── list planned ────────────────────────────┘ ──► executing ──► complete
                                      (loops until `list planned` is empty)                    └──► blocked
```

Phase documents (read the one you are running — each is the full procedure):

- [references/sprint-state.md](references/sprint-state.md) — the manifest, state machine, claims, folder layout, and `sprint-state.sh` helper every phase uses. **Read first.**
- [references/dev-story-creator.md](references/dev-story-creator.md) — phase 1, intake → `story.md`.
- [references/dev-story-planner.md](references/dev-story-planner.md) — phase 2, `story.md` → `<slug>-plan.md` + `impl-plan.md`.
- [references/dev-story-coder.md](references/dev-story-coder.md) — phase 3, plans → merged, validated, `complete`.

## Invocation — objectives, not commands

The skill takes a free-text objective and maps it to a phase. The `/goal` skill is the
entry point Jonathan uses: `/goal using dev-story-flow <objective>`. Calling
`/dev-story-flow <objective>` directly is identical.

| Objective says… | Phase | Runs until |
|---|---|---|
| "create", "new story", "add a story", "new sprint", or just a pasted user story | CREATE | Jonathan says the sprint is documentation-complete (→ `ready-to-plan`); standalone `create` then posts the `run` line and clears the session |
| "plan", "plan the sprints", "plan what's ready" | PLAN | no `ready-to-plan` sprint remains |
| "execute", "run the planned sprints", "execute until all the planned sprints are completed" | EXECUTE | no `planned` sprint remains, or a sprint is `blocked`, or the budget gate fires |
| "run", "run the flow", "everything" | **the whole pipeline in this session**: CREATE if no sprint is `drafting`/`ready-to-plan`/`planned`, then PLAN, then EXECUTE | Jonathan says "I'm done" (or any completion phrase) to end intake; nothing else is asked of him until the closing message, a `blocked` sprint, or the budget gate |
| "run clean" | same as `run`, but CREATE ends by clearing the session and handing Jonathan the `run` line to paste | one paste from him after "I'm done"; PLAN and EXECUTE then start with an empty context |
| "status", "where are the sprints", "what's planned" | — | prints `sprint-state.sh list` and stops |

An objective that names a sprint (`… execute sprint 2026-09-10-001`) restricts the phase to
that sprint. Ambiguous objective → run `sprint-state.sh list`, pick the phase the states
call for (anything `ready-to-plan` → PLAN; else anything `planned` → EXECUTE; else CREATE), and
say which in one line.

**No go-ahead in PLAN or EXECUTE.** The human gates are (a) Jonathan closing a sprint in CREATE
and (b) the pause between `planned` and running EXECUTE, where `impl-plan.md` can be reviewed.
Once EXECUTE starts it does not ask "shall I continue?" — it finishes, blocks, or hands off.

**Hand-off from CREATE.** Under `run` (the default) the creator's completion step flows
straight into PLAN in the same session — Jonathan says "I'm done" and says nothing more. The
intake conversation stays in context, which is affordable for a handful of stories and is
what the 150k/165k gate is for. Under `run clean` or a standalone `create`, the creator instead
posts `/goal using dev-story-flow run` and clears its own session (creator doc, step 5), so the
planner and coder start from zero at the cost of one paste.

## Rules shared by all three phases

1. **State lives in `sprint.json`, committed.** Every status change is written by
   `assets/bin/sprint-state.sh` (which enforces legal transitions) and committed in the same
   step. An uncommitted manifest change does not exist to the next session.
2. **Claims prevent double work.** `planning` and `executing` record who holds the sprint.
   Fresh claims are skipped by other sessions; stale ones (default 6 h) may be taken over with
   one line saying so. See sprint-state.md.
3. **Silence.** CREATE is conversational. PLAN and EXECUTE speak per sprint exactly: the model
   table, a genuine blocker, the closing message — plus one line on a re-dispatch model change
   or a stale-claim takeover. Sub-agents and executors say nothing but their return summary
   (≤ 20 lines, never addressed to Jonathan; a question is a `blocked` state).
4. **Every spawn is announced with a model table first**, one table per sprint covering every
   sub-agent or item, with a **Model** column. `model:` is always explicit — `"sonnet"`
   (Sonnet 5) by default, `"opus"` (Opus 5) only past the complexity bar stated in the phase
   doc. Never inherited.
5. **Maximum parallelism.** Planners: every story of a sprint in one message. Executors: every
   dependency-met item across all stories of the sprint in one message, waves not queues.
6. **Executors run through `story-item-executor`** with `isolation: "worktree"`, always, using
   `dev-story-sprint`'s dispatch template, control plane (`status.json`, cancel sentinel) and
   land-and-reset merge. This skill adds no new agents or hooks.
7. **Acceptance criteria are proven, not asserted.** A story is `done` only when every row of
   its plan's Validation table passed against the integration branch and the results are in
   `<slug>/validation.md`. Service stories: unit gate + integration script against the running
   app. Interactive stories: TDD tests + browser checks by a verifier sub-agent.
8. **Fix loop capped at 3.** Validate → fail → one fix item (Opus on attempt 3) → re-validate.
   After three failures the story is `blocked`, the rest of the sprint continues, and the
   sprint closes `blocked` with one message naming what and why.
9. **Testing is items, not ceremony.** The planner puts an interactive story's tests in wave 1
   (before its implementation items) and gives every service story an integration-test item.
   No coverage number is chased. Existing suites stay green as a gate. This is the flow's
   reading of the global TDD rule; executors otherwise follow `story-item-executor`'s no-TDD
   instruction because their tests arrive as their own items.
10. **Budget: stop dispatching at 150k, never pass 165k** — `context-budget-gate.sh` enforces
    it. At the trigger, land what is in flight, make `sprint.json` truthful, commit, and call
    `Skill({skill: "clear-prompt", args: "dev-story-flow <phase> <sprint>"})`. Because state
    is on disk, resumption is the same objective again in a fresh chat.
11. **Never guess.** Read the manifest, the plan, the repo. "Not verified" is a complete
    sentence and a non-`done` story.

## The sprint folder, at a glance

```
docs/sprints/2026-09-10-001/
├── sprint.json                      status, branch line, claim, stories[], history[]
├── impl-plan.md                     planner — order, cross-story gotchas, open questions
└── <slug>/
    ├── story.md                     creator — statement, spec, deps/risks, AC by kind
    ├── <slug>-plan.md               planner — item table, Validation table, risks
    └── validation.md                coder — per-AC evidence from the final passing run
```

Helper, from any repo:

```bash
~/.claude/skills/dev-story-flow/assets/bin/sprint-state.sh list          # every sprint and its state
~/.claude/skills/dev-story-flow/assets/bin/sprint-state.sh get <sprint>  # one manifest
```

## Relationship to the siblings

| | dev-story-sprint | dev-story-flow | dev-epic-workflow |
|---|---|---|---|
| Unit | one story, planned in chat | many stories, planned to files, executed as sprints | epics with tracked work items |
| Documents | none | `docs/sprints/<sprint>/…` | `docs/epics/<NN>-…/plan.md`, handoff |
| Human gate | "go" before wave 1 | sprint close in CREATE; review before EXECUTE | plan approval, PR review |
| Executor | story-item-executor | story-item-executor (reused) | work-item-executor |
| Resume | prep-for-clear prompt | manifest on disk (+ prep-for-clear) | handoff.md |

If a story is one-off and Jonathan wants it now, that is a sprint. If it needs issue intake,
epic numbering, PR ceremony, or a retro, that is an epic. Everything in between — a batch of
stories specified once and shipped unattended — is this flow.

## Install (once per machine)

```bash
bash ~/Source/claude-skills-main/Skills/dev-story-flow/assets/install.sh
```

Symlinks `~/.claude/skills/dev-story-flow` and `~/.claude/skills/goal` into the live worktree
(`~/Source/claude-skills-main`, detached at `origin/main` — see dev-story-sprint's Install for
why the dev checkout is never linked). Requires dev-story-sprint's install (for
`story-item-executor`) and dev-epic-workflow's user-level install (cancel gate, lifecycle hook,
context-budget gate); the installer warns when either is missing. Going live is automatic on
push via dev-story-sprint's refresh hook. Tests: `bash assets/tests/sprint-state-fixtures.sh`.

## What this skill overrides from the global rules

- **Announce / brief updates:** PLAN and EXECUTE do not narrate (rule 3). The model table is
  the announcement; the closing message is the recap.
- **Context budget:** the 120k/150k `/handoff` rule is replaced by rule 10.
- **Model table per spawn:** satisfied once per sprint per phase (rule 4).
- **TDD / coverage:** read as rule 9.
- **Commit at task end:** every manifest change and every merge is a commit; executors commit
  continuously.

Everything else — immutability, error handling, secrets, review severity on auth/DB/money
paths — applies to the code the executors write.
