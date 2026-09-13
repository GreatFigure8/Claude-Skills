# dev-story-creator — phase 1 of dev-story-flow

Intakes user stories from Jonathan in chat and turns each into a detailed, specification-grade
`story.md`. A story can arrive as one loose sentence ("as a user I want a chat process that
uses an LLM…") or as a full statement with acceptance criteria. Either way the output is the
same shape, and the sprint it lands in is tracked by the manifest described in
[sprint-state.md](sprint-state.md).

This is the **only conversational phase**. The planner and coder run silent; the creator asks
questions, because this is where ambiguity is cheapest to remove.

## Inputs and outputs

- **In:** Jonathan's story text, in chat. Optionally an existing sprint in `drafting`.
- **Out:** `docs/sprints/<sprint>/<story-slug>/story.md` per story, `sprint.json` with the
  story registered, and — when
  Jonathan says the sprint is documentation-complete — the sprint set to `ready-to-plan`.

## Process

### 1. Find or create the sprint

```bash
SS=${CLAUDE_PLUGIN_ROOT}/assets/bin/sprint-state.sh
$SS list drafting            # any sprint still being drafted?
```

- **A `drafting` sprint exists** → reuse it, and say so in one line ("Adding to sprint
  2026-09-10-001, which is still drafting."). Jonathan can reply "new sprint" to override.
- **None exists** → `$SS new` creates `docs/sprints/YYYY-MM-DD-NNN/` with `sprint.json` in
  `drafting`, the index being the next unused one for today. Pass `--integration none` when the
  repo's `CLAUDE.md` says work goes straight against live; otherwise the default
  `sprint/<sprint>` integration branch is recorded and the coder cuts it later.
- Commit: `chore(sprint): open sprint <sprint>` — the manifest's first commit.

All stories written in this session belong to that sprint until step 5 closes it. Under
`run`, when nothing is `drafting`, `ready-to-plan` or `planned`, this step runs automatically
and the creator's first message is one line: the sprint name and "give me the first story".

### 2. Intake — one batched round of questions

Ground first, cheaply: `grep -n` / `sed -n` the modules the story obviously touches, `git log
--oneline -10`, the stack's config files. Then ask **everything at once, in one message**,
grouped:

- **Behaviour:** what exactly happens, for whom, triggered how; the failure and empty states.
- **Boundaries:** what is explicitly out of scope; what must not change.
- **Kind:** is it `interactive` (a UI Jonathan will click through in a browser) or `service`
  (backend, database, API, MCP, CLI)? Infer it and state the inference; only ask if unsure.
- **Acceptance criteria:** confirm the ones given verbatim; propose the ones missing.
- **Dependencies:** external services, credentials, migrations, other stories in this sprint.

A second round is allowed only when an answer opens a genuinely new ambiguity. Do not ask
about things the repo can answer — read the repo instead. If Jonathan says "just write it",
write it with every assumption listed under *Open questions* in the story.

### 3. Write `story.md`

Choose the slug from the title — lower-case, dashes, no stop-words, ≤ 5 words
(`create-home-page`, `add-chat-endpoint`). Write
`docs/sprints/<sprint>/<slug>/story.md` from this template, every section present:

```markdown
---
title: <one line>
slug: <slug>
sprint: <sprint>
kind: interactive | service
created: <UTC ISO-8601>
---

# <title>

## Statement
<Jonathan's story, verbatim, then a one-paragraph restatement in the specifier's words.>

## Requirements
<Numbered. Everything Jonathan said he needs, verbatim where possible. R1, R2, …>

## Specification
<The detailed design the planner will decompose. Modules and files touched, new types and
signatures, data model changes, API/MCP contract changes with request/response shapes,
config keys, error handling, logging. Concrete enough that two engineers would build the
same thing.>

## Dependencies, risks, and breaking changes
<Other stories this depends on (by slug). External services and credentials. Breaking
changes to any public contract and the migration path. Build/typing/packaging concerns
(new deps, lockfile, mypy/tsc strictness). Anything the model judges critical.>

## Acceptance criteria
<Numbered AC1, AC2, … — each one a check with a yes/no answer. Shape depends on `kind`:>

### kind = service
- AC-U: unit tests pass — `<the exact gate command>` exits 0.
- AC-I: integration tests exist at `<tests/integration/<slug>.sh or the repo's equivalent>`
  and exercise the **running** application over its real interface (curl against the server,
  the MCP client against the tool, the CLI end to end) and exit 0.
- AC-n: <functional criteria, each verifiable by one of the above>

### kind = interactive
- AC-T: TDD tests pass — the item's component/unit tests, written before the implementation.
- AC-B: browser-based checks — for each criterion, the URL, the actions, and the observable
  result (element present, text shown, network call made, state persisted).
- AC-n: <functional criteria, each mapped to a browser check>

## Out of scope
<Explicit exclusions, so the coder cannot drift.>

## Open questions
<Anything unresolved, with the assumption the spec proceeds on. "none" if none.>
```

The `Specification` and `Acceptance criteria` sections are where the value is. Spend the
tokens there, not on prose.

### 4. Register the story

```bash
$SS story add <sprint> <slug> --title "<title>" --kind <interactive|service>
git add docs/sprints/<sprint> && git commit -m "docs(sprint): <sprint> — story <slug>"
```

**No GitHub issues.** dev-story-flow never runs `gh issue create`; the story file and the
manifest are the record, and the sprint's merge commits are the trail.

Then post one short confirmation: sprint, slug, kind, path — and wait for the next
story or for the completion phrase.

### 5. Hand off to the planner — the "documentation complete" signal

Jonathan closes the sprint with any clear phrase: **"I'm done"**, **"sprint complete"**,
**"documentation complete"**, **"done with the sprint"**, **"that's all the stories"**,
**"send it to planning"**. On that:

```bash
$SS set <sprint> ready-to-plan --by creator
git add docs/sprints/<sprint>/sprint.json && git commit -m "chore(sprint): <sprint> ready to plan (<k> stories)" && git push
```

That status change **is** the hand-off. The planner discovers work by `sprint-state.sh list
ready-to-plan`; nothing else needs to be told anything.

**Then kick off the next phases.** How depends on the objective that started this phase:

**Under `run` (default):** continue directly. One line — "Sprint <sprint> ready: <slugs>.
Planning." — then start the planner procedure in this same turn, and the coder after it.
Jonathan is asked nothing further; the next thing he reads is the planner's model table.
The intake context rides along; the 150k/165k gate is the safety net if the sprint is large.

**Under `run clean`, or a standalone `create`:** hand off into an empty context, because the
intake conversation is dead weight for the planner and coder. The creator's last turn does
three things and nothing more:

1. Confirms the working tree is clean and pushed (`git status --short` empty, `git log
   origin/main..HEAD` empty).
2. Posts exactly this, as the last visible text: the sprint name, its story slugs, and the
   line to paste — `/goal using dev-story-flow run` — with one sentence saying the chat is
   about to clear.
3. Calls the desktop app's clear tool on itself: `mcp__ccd_session_mgmt__clear_session` with
   `session_id: "self"`. The transcript empties when the turn ends; Jonathan pastes the one
   line and PLAN then EXECUTE run with nothing else in context. When that tool is not
   available (plain CLI), say `/clear` then paste the line — same effect, one extra keystroke.

A session cannot queue a message to itself after clearing, so one paste is the floor here.
`run` means PLAN then EXECUTE (see SKILL.md); EXECUTE loops until no sprint is `planned`.

**Alternatives considered for this signal:** a `.ready` marker file (no metadata, can coexist
with stale flags), a line in a central index (merge conflicts across sessions), a GitHub label
(network-bound, invisible to grep). The manifest status won — see sprint-state.md.

### 6. End

The creator does not plan and does not code. A story added after the sprint is
`ready-to-plan` starts a **new** sprint (step 1 will find no `drafting` sprint and create one).

### Stopping point at 160k

At 160k, finish writing and committing the story currently in hand — do not start intake of
another one. Then:

- **The sprint has ≥ 1 story:** close it the way step 5's `run clean` variant does. Set it
  `ready-to-plan`, commit, and push:
  ```bash
  $SS set <sprint> ready-to-plan --by creator
  git add docs/sprints/<sprint>/sprint.json && git commit -m "chore(sprint): <sprint> ready to plan (<k> stories)" && git push
  ```
  then post that same variant's hand-off, in its own voice: confirm the working tree is clean
  and pushed, and post exactly the sprint name, its story slugs, and the line to paste —
  `/goal using dev-story-flow run` — with one sentence saying the chat is about to clear.
- **The sprint has zero stories:** leave it `drafting` — no status change, nothing to commit
  on `sprint.json` — and post the existing `create` line instead: the sprint name (still
  drafting) and the line to paste, `/goal using dev-story-flow create`, with the same
  one-sentence notice that the chat is about to clear.

Either way the session then clears: `mcp__ccd_session_mgmt__clear_session` with
`session_id: "self"` when available, else say `/clear` and paste the line.

## Rules

- Requirements and acceptance criteria Jonathan states are recorded **verbatim** before being
  restated. His words are the contract; the restatement is the specifier's reading of it.
- Every AC must be checkable by a command or a browser step. "Works correctly" is not an AC.
- Never invent scope. Anything not asked for is *Out of scope* or an *Open question*.
- Never guess repo facts — read them. A story that names a file that does not exist is a bug in
  the story.
- Commit after every story; the manifest and the stories travel together.
