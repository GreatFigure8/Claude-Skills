# dev-story-coder — phase 3 of dev-story-flow

Finds every sprint in `planned`, claims it, and executes it to `complete` without a go-ahead:
every story built by silent executors with maximum parallelism, every acceptance criterion
validated against the running result, failures fixed and re-validated, the sprint merged to
live. Then the next planned sprint. It stops only when no `planned` sprint remains, when a
story exhausts its fix attempts, or at the token budget.

The mechanics are `dev-story-sprint`'s Steps 2–4 (dispatch, cold verify, merge, reset), reused
as-is; this document only says what differs. State moves `planned → executing → complete`
(or `blocked`); see [sprint-state.md](sprint-state.md).

## Folders

- Base: `docs/sprints`; sprint `YYYY-MM-DD-NNN`; story `<sprint>/<slug>/`
- Read: `impl-plan.md`, each `<slug>-plan.md`, each `story.md`'s *Acceptance criteria*
- Write: `<slug>/validation.md` (final validation results), `sprint.json`

## Process

### 1. Find sprints that are planned and not being executed

```bash
SS=~/.claude/skills/dev-story-flow/assets/bin/sprint-state.sh
git fetch -q && git pull --ff-only
$SS list planned                          # candidates, oldest first
$SS list executing                        # anyone else's? for each: $SS stale <sprint> && echo reclaimable
```

A sprint in `executing` with a **fresh** claim belongs to another session — skip it. A
**stale** one (claim older than `DSF_STALE_HOURS`, default 6, and no commits on its branches
in that window per `git log --since`) may be reclaimed; say so in one line. No candidates →
one line ("No planned sprints.") and end.

### 2. Pick up one sprint and claim it

```bash
ID="coder-$(hostname)-$(date -u +%Y%m%dT%H%M%SZ)"            # once per session
$SS set <sprint> executing --by "$ID"
git add docs/sprints/<sprint>/sprint.json && git commit -qm "chore(sprint): <sprint> executing" && git push -q
```

Then the `dev-story-sprint` pre-dispatch setup, with the sprint as the slug:

```bash
mkdir -p .claude/stories/<sprint>/status .claude/signals
grep -qx '.claude/stories/' .gitignore || printf '.claude/stories/\n' >> .gitignore
grep -qx '.claude/signals/' .gitignore || printf '.claude/signals/\n' >> .gitignore
printf '.claude/stories/<sprint>\n' > .claude/signals/active-epic
```

**Integration branch.** When `branch.integration` is `sprint/<sprint>`, cut it now from live
if it does not exist: `git push origin origin/<live>:refs/heads/sprint/<sprint>`. When it is
`none`, items merge straight to live and the last story's merge closes the sprint.

Post **one** message per sprint — the model table covering every item of every story, taken
from the plans:

```
Executing sprint 2026-09-10-001 — 3 stories, 9 items   live=main integration=sprint/2026-09-10-001

| Story / item | Branch | Wave | Model |
|---|---|---|---|
| add-chat-endpoint 1 | feat/add-chat-endpoint-route | 1 | Sonnet 5 |
| add-chat-endpoint 2 | test/add-chat-endpoint-integration | 2 | Sonnet 5 |
| create-home-page 1 | test/create-home-page-tdd | 1 | Sonnet 5 |
| … | | | |
```

No go-ahead is awaited: `planned` **is** the approval. Dispatch wave 1 in the same message.

### 3. Execute each story using its plan — waves across stories

Build one item list across **all** stories in the sprint, honouring `impl-plan.md`'s order:
an item is ready when its own dependencies and its story's prerequisite stories are merged.
Dispatch **every ready item in one message**, one `Agent` call each:

- `subagent_type: "story-item-executor"`, `model` from the plan (explicit), `isolation:
  "worktree"`, `run_in_background: true` when more than one is in flight.
- `prompt`: the `dev-story-sprint` dispatch template, with `Status dir:
  .claude/stories/<sprint>/status/`, no `Issue:` line (this flow files no issues), and the first line reading
  `dev-story-flow dispatch — <sprint> / <slug> item <n>`. Copy *Scope / Done when / Not / Files
  owned / Gates* from the plan row verbatim.

As each executor returns: cold verify (`git log`/`git diff --stat` against the plan row, grep
for promised symbols), merge with `--no-ff` into integration, delete the branch, prune, remove
the status file, then dispatch whatever that merge unblocked — `dev-story-sprint` Step 3,
unchanged. Conflicts go to a one-line Sonnet rebase item, never resolved in the main checkout.
Mark the story `executing` on its first dispatch:

```bash
$SS story set <sprint> <slug> executing
```

### 4. Once a story's items are all merged, validate its acceptance criteria

```bash
$SS story set <sprint> <slug> validating
```

Run the plan's **Validation table**, every row, against the integration branch:

- **Unit / TDD rows** — run the exact command from the main checkout (it is on integration).
- **Integration rows (`service`)** — start the app as the plan says, run
  `bash tests/integration/<slug>.sh` (or the repo's equivalent), stop the app. Exit code
  decides.
- **Browser rows (`interactive`)** — dispatch one silent **verifier** sub-agent
  (`subagent_type: "general-purpose"`, `model: "sonnet"`, background) with the browser rows,
  the start command, and the URL. It uses the Browser pane tools (`preview_start`, `read_page`,
  `find`, `computer`) and returns ≤ 20 lines: one `pass`/`fail` per AC with the observed value.
  Screenshots stay in its context, not the orchestrator's. If it reports the browser tools are
  unavailable to it, the orchestrator runs the rows itself, preferring `read_page`/`find` over
  screenshots.

Write the results to `docs/sprints/<sprint>/<slug>/validation.md`: one row per AC, the
command or step, the observed result, pass/fail, UTC time. This file is the evidence the
closing message points at.

### 5. Fail → fix → re-validate; pass → complete the story

**All rows pass →**

```bash
$SS story set <sprint> <slug> done --detail "validated <UTC>"
git add docs/sprints/<sprint> && git commit -qm "docs(sprint): <sprint>/<slug> done" && git push -q
```

**Any row fails →**

```bash
$SS story set <sprint> <slug> executing --bump-attempts --detail "AC-<x> failed: <one line>"
```

then dispatch **one fix item** — `fix/<slug>-attempt-<k>`, `isolation: "worktree"`, the
failing AC rows and the observed output verbatim in *Scope*, the same *Files owned* as the
items that produced the behaviour. Model: Sonnet 5 for attempts 1–2, **Opus 5 for attempt 3**
(the cause is by then genuinely unclear, which is the Opus bar). One line in chat when the
model changes. Merge it as any item, then go back to step 4.

**Attempt cap: 3.** After the third failed validation the story is `blocked`:

```bash
$SS story set <sprint> <slug> blocked --detail "AC-<x> still failing after 3 attempts: <one line>"
```

Continue with every other story in the sprint — one blocked story does not stop the others.

### 6. Mark the sprint complete

When every story is `done`: run the stack gates once on the integration branch as a whole,
then merge to live (skip when `integration=none` — the last story's merge was the close):

```bash
git fetch -q && git merge --no-ff -m "merge(sprint): <sprint> — <k> stories" origin/sprint/<sprint> && git push origin <live>
git push origin --delete sprint/<sprint>
```

then

```bash
$SS set <sprint> complete
git add docs/sprints/<sprint>/sprint.json && git commit -qm "chore(sprint): <sprint> complete" && git push -q
rm -rf .claude/stories/<sprint> .claude/signals/active-epic
```

`status: complete` in the committed manifest **is** the completion mark — `sprint-state.sh
list complete` shows history, `list planned` shows what is left, and the manifest's `history`
array is the timeline. Post **one** closing message per sprint: stories shipped (merge hashes),
validation files, anything deferred, anything claimed-but-unverified.

Any story `blocked` instead → `$SS set <sprint> blocked`, commit, and one message naming each
blocked story, its last failing AC, and the fix paths tried. Jonathan resolves and re-admits
with `sprint-state.sh set <sprint> planned --force`.

**Alternatives considered for the completion mark:** a `DONE` file in the sprint folder (no
history, no per-story detail), deleting or archiving the folder (destroys the evidence),
closing a GitHub milestone (external, invisible to the next phase's `list`). The manifest
status won — see sprint-state.md.

### 7. Next sprint, or end

Go back to step 1. When `list planned` is empty, one final line: sprints completed this
session, sprints blocked, and that the flow is idle. That line satisfies "execute until all
the planned sprints are completed".

## Budget — the same 150k / 165k rule as dev-story-sprint

`context-budget-gate.sh` denies new dispatches at 165k. At 150k: no new dispatch, land what is
in flight (merge what verifies), make `sprint.json` truthful (stories `executing` with
`detail` naming pushed-but-unmerged branches), commit, push, then `Skill({skill:
"clear-prompt", args: "dev-story-flow execute <sprint>"})`. Because all state is on disk, the
resumption prompt is short: the next orchestrator runs `/goal using dev-story-flow execute
until all planned sprints are completed`, reclaims the sprint (its own claim is stale-or-own
by definition — pass the same `--by` id from the prompt, or `--force`), merges any pushed
branches named in `detail`, and continues from step 3.

### Stopping point at 160k

At 160k, stop waiting on executors for new dispatch decisions and merge only items already
verified against the integration branch. For every story that still has an executor running,
or one that returned but is not yet verified, run:

```bash
$SS story set <sprint> <slug> executing --detail "branch <b> pushed, not merged"
```

Substitute the real branch name for `<b>`. Use `validating` in place of `executing` if that
story was already in `validating` when the trigger hit. Leave the sprint itself `executing`
with its claim intact — do not touch `sprint.json`'s sprint-level status or claim. Commit,
push, then `Skill({skill: "clear-prompt", args: "dev-story-flow execute <sprint>"})`.

## Rules

- Silent between the sprint's table message and its closing message, except: a model change on
  re-dispatch (one line), a stale-claim takeover (one line), a `blocked` story (one message).
- Never resolve a merge conflict in the main checkout. Never switch its branch.
- Never mark `done` without a `validation.md` that shows every AC row passing. "Not verified"
  is a `validating` story, not a `done` one.
- The repo decides, not the sidebar: `status.json` `pushed` plus commits on `origin/<branch>`
  means the item is ready, whatever the agent list says.
- Kill switch: `touch .claude/signals/cancel` stops every executor; remove it before the next
  dispatch.
