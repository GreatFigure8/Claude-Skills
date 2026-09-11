# dev-story-planner — phase 2 of dev-story-flow

Finds every sprint the creator marked `ready-to-plan`, claims it, and produces an execution
plan per story plus one sprint-level `impl-plan.md`. Planning is delegated to **silent
sub-agents**, one per story, running in parallel. The orchestrator speaks only to announce
the model table and to close — or when a story genuinely cannot be planned without Jonathan.

State moves `ready-to-plan → planning → planned`; see [sprint-state.md](sprint-state.md).

## Folders

- Base: `docs/sprints`
- Sprint: `YYYY-MM-DD-NNN` (e.g. `docs/sprints/2026-09-10-001`)
- Story: `<sprint>/<slug>/story.md`; plan written beside it as `<sprint>/<slug>/<slug>-plan.md`
- Sprint plan: `<sprint>/impl-plan.md`

## Process

### 1. Pick up unplanned sprints

```bash
SS=~/.claude/skills/dev-story-flow/assets/bin/sprint-state.sh
git fetch -q && git pull --ff-only          # manifests are committed; read the latest
$SS list ready-to-plan
```

No rows → one line ("Nothing to plan.") and end. Otherwise process sprints oldest first. For
each: claim it so a concurrent planner skips it, and commit the claim:

```bash
ID="planner-$(hostname)-$(date -u +%Y%m%dT%H%M%SZ)"          # generate once per session
$SS set <sprint> planning --by "$ID"
git add docs/sprints/<sprint>/sprint.json && git commit -qm "chore(sprint): <sprint> planning" && git push -q
```

### 2. Read the stories, decide precedence and model

Read each `story.md` once — frontmatter, *Dependencies*, *Specification* headings, AC list.
Do not read the repo yourself beyond `git log --oneline -10` and the tree; grounding is the
sub-agents' job.

**Precedence:** a story that another story's *Dependencies* names goes first. Shared
scaffolding (a new type, migration, config key, shared component) goes first. Independent
stories run in the same wave. Record the order for `impl-plan.md`.

**Model per story — the Opus bar:** Sonnet 5 unless the story meets one of: cross-module
refactor with unclear blast radius; concurrency, data migration, or auth/security-sensitive
change; a spec whose *Open questions* still leave real design choices; anything where a
wrong-but-plausible plan would be expensive to detect during execution. Big-and-mechanical is
Sonnet.

### 3. Announce, then spawn one silent planner per story

Post **one** message per sprint — the model-announcement table the global rules require:

```
Planning sprint 2026-09-10-001 — 3 stories

| Story | Wave | Model |
|---|---|---|
| add-chat-endpoint | 1 | Sonnet 5 |
| create-home-page (depends on add-chat-endpoint) | 2 | Sonnet 5 |
| migrate-sessions-table | 1 | Opus 5 |
```

Then, in the **same message**, one `Agent` call per story — all of them, so they run
concurrently:

- `subagent_type: "general-purpose"`
- `model: "sonnet"` or `"opus"` — from the table, always explicit
- `run_in_background: true` (each return wakes the orchestrator; no polling)
- no `isolation` — planners only write their own plan file in the main checkout
- `prompt`: the dispatch below

**Planner dispatch template** (≤ 20 lines):

```
dev-story-flow plan — sprint <sprint>, story <slug>
Read: docs/sprints/<sprint>/<slug>/story.md (whole), then ground in the repo with grep -n / sed -n
      on the files the Specification names and their direct callers. Not a repo tour.
Write: docs/sprints/<sprint>/<slug>/<slug>-plan.md using the plan template in
       ~/.claude/skills/dev-story-flow/references/dev-story-planner.md (section "Plan template").
Rules: silent — no text between tool calls, never address Jonathan. Decompose along file
       ownership so no two items in a wave touch the same files. Every AC in the story maps to
       a row in the Validation table with an exact command or browser step. Pick Sonnet 5 per
       item unless it meets the Opus bar stated in the same reference. Do not edit story.md,
       sprint.json, or any source file. Do not commit.
Return: ≤ 15 lines — item count, waves, models chosen, risks, open questions (or none).
```

Sub-agents are **silent**: their only output is the return summary. A question is a line
under *Open questions* in the plan and in the summary, not a conversation.

### 4. Plan template (what each sub-agent writes)

```markdown
# <slug> — execution plan

Sprint: <sprint>   Story: <slug>   Kind: <interactive|service>
Grounded: <files read>   Assumed: <what was not verifiable, or none>

## Items
| # | Branch | Scope / Done when / Not | Files owned | Wave | Model | Gates |
|---|---|---|---|---|---|---|
| 1 | feat/<slug>-<item> | <scope>. Done when: <check>. Not: <exclusion>. | <paths> | 1 | Sonnet 5 | <cmd or "stack default"> |
| 2 | test/<slug>-integration | Write tests/integration/<slug>.sh exercising the running app. Done when: exits 0 against a fresh start. | tests/integration/<slug>.sh | 2 | Sonnet 5 | bash tests/integration/<slug>.sh |

## Validation — how the coder proves each acceptance criterion
| AC | Check | Command / browser steps | Pass when |
|---|---|---|---|
| AC-U | unit | `<exact command>` | exit 0 |
| AC-I | integration | `bash tests/integration/<slug>.sh` (server started by `<cmd>`) | exit 0 |
| AC-B1 | browser | open `<url>`; click `<selector/text>`; read `<element>` | shows "<text>" |

## Order and dependencies
<Which items depend on which; which other stories must be done first.>

## Risks and gotchas
<Breaking changes, migrations, typing, build, env/credentials, anything the coder must know.>

## Open questions
<Decisions the coder cannot make from the repo. "none" if none.>
```

Rules baked into the template: an `interactive` story always has a TDD test item **in wave
1** (tests before implementation) and browser rows in Validation; a `service` story always has
an integration-test item and an `AC-I` row. Items ≤ one line of scope; a diff that would run
past a few hundred meaningful lines is two items.

### 5. Verify each return, then write `impl-plan.md`

As each planner returns, check its plan exists, has all five sections, and every story AC
appears in the Validation table (`grep -c '^| AC' <plan>` against the story's AC count). A
plan that fails the check is re-dispatched with the gap named, silently. Record the plan path:

```bash
$SS story set <sprint> <slug> planned --plan <slug>/<slug>-plan.md
```

When every story is planned, the orchestrator writes `docs/sprints/<sprint>/impl-plan.md`
itself (it is short) — or, for a sprint over ~6 stories, dispatches one more Sonnet sub-agent
to write it from the plans:

```markdown
# Sprint <sprint> — implementation plan

Branch line: live=<branch>  integration=<sprint/<sprint> | none>
Stories: <k>   Items: <total>   Waves: <n>

## Execution order
| Wave | Story | Items | Depends on | Model(s) |
|---|---|---|---|---|

## Cross-story dependencies and gotchas
<Shared files two stories touch (serialise them). Migrations ordering. Env/credentials.>

## Open questions
<Aggregated from the story plans. Each with the default the coder will take if unanswered.>

## Definition of sprint-complete
- every story `done` in sprint.json, its Validation table all-pass
- sprint gates green on the integration branch; integration merged to live (or, with
  integration=none, the last story's merge is the close)
```

### 6. Hand off to the coder — mark the sprint planned

```bash
$SS set <sprint> planned
git add docs/sprints/<sprint> && git commit -qm "docs(sprint): <sprint> planned — <k> stories, <n> items" && git push -q
```

That status change **is** the hand-off; the coder discovers work with `sprint-state.sh list
planned`. Then one closing line per sprint: stories, items, waves, any open questions, and
where `impl-plan.md` is so Jonathan can review before running
`/goal using dev-story-flow execute until all planned sprints are completed`.

**Open questions do not block planning.** They are written down with the default the coder
will take. Only a story that cannot be planned at all (spec contradicts the repo, dependency
missing) stops the phase — one short message to Jonathan, sprint left in `planning`.

**Alternatives considered for this signal:** a `PLANNED` marker file, a row in a central
index, a GitHub label — rejected for the reasons in sprint-state.md. The manifest carries
per-story `plan` paths too, so the coder never has to guess file names.

### 7. Repeat for the next `ready-to-plan` sprint, then end.

## Rules

- The orchestrator is quiet: the table message, a genuine blocker, the closing line. Nothing
  between.
- Every spawn is announced in a table with a **Model** column before it starts. Never let
  `model` inherit.
- Never edit `story.md`. If a story is wrong, the plan's *Open questions* says so.
- Every AC gets a Validation row with a real command or a real browser step. No row, no plan.
