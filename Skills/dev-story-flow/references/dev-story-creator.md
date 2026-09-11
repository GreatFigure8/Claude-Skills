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
  story registered, one GitHub issue per story (when `gh` and a remote exist), and — when
  Jonathan says the sprint is documentation-complete — the sprint set to `ready-to-plan`.

## Process

### 1. Find or create the sprint

```bash
SS=~/.claude/skills/dev-story-flow/assets/bin/sprint-state.sh
$SS list drafting            # any sprint still being drafted?
```

- **A `drafting` sprint exists** → reuse it, and say so in one line ("Adding to sprint
  2026-09-10-001, which is still drafting."). Jonathan can reply "new sprint" to override.
- **None exists** → `$SS new` creates `docs/sprints/YYYY-MM-DD-NNN/` with `sprint.json` in
  `drafting`, the index being the next unused one for today. Pass `--integration none` when the
  repo's `CLAUDE.md` says work goes straight against live; otherwise the default
  `sprint/<sprint>` integration branch is recorded and the coder cuts it later.
- Commit: `chore(sprint): open sprint <sprint>` — the manifest's first commit.

All stories written in this session belong to that sprint until step 5 closes it.

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
issue: <n or none>
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

### 4. Register the story and open its issue

```bash
$SS story add <sprint> <slug> --title "<title>" --kind <interactive|service>
gh issue create --title "<title>" --body-file docs/sprints/<sprint>/<slug>/story.md   # if gh + remote
$SS story set <sprint> <slug> drafted --issue <n>                # records the issue on the story
git add docs/sprints/<sprint> && git commit -m "docs(sprint): <sprint> — story <slug>"
```

One issue per story, opened once here; the coder threads `Refs #<n>` through every commit and
closes it at story completion. No remote or no `gh`: say so in one line, set `issue: none`,
proceed. Write the issue number back into the story's frontmatter.

Then post one short confirmation: sprint, slug, kind, issue, path — and wait for the next
story or for the completion phrase.

### 5. Hand off to the planner — the "documentation complete" signal

Jonathan closes the sprint with any clear phrase: **"sprint complete"**, **"documentation
complete"**, **"done with the sprint"**, **"that's all the stories"**, **"send it to
planning"**. On that:

```bash
$SS set <sprint> ready-to-plan --by creator
git add docs/sprints/<sprint>/sprint.json && git commit -m "chore(sprint): <sprint> ready to plan (<k> stories)" && git push
```

That status change **is** the hand-off. The planner discovers work by `sprint-state.sh list
ready-to-plan`; nothing else needs to be told anything. Close with one line naming the sprint,
its stories, and the next command (`/goal using dev-story-flow plan`).

**Alternatives considered for this signal:** a `.ready` marker file (no metadata, can coexist
with stale flags), a line in a central index (merge conflicts across sessions), a GitHub label
(network-bound, invisible to grep). The manifest status won — see sprint-state.md.

### 6. End

The creator does not plan and does not code. A story added after the sprint is
`ready-to-plan` starts a **new** sprint (step 1 will find no `drafting` sprint and create one).

## Rules

- Requirements and acceptance criteria Jonathan states are recorded **verbatim** before being
  restated. His words are the contract; the restatement is the specifier's reading of it.
- Every AC must be checkable by a command or a browser step. "Works correctly" is not an AC.
- Never invent scope. Anything not asked for is *Out of scope* or an *Open question*.
- Never guess repo facts — read them. A story that names a file that does not exist is a bug in
  the story.
- Commit after every story; the manifest and the stories travel together.
