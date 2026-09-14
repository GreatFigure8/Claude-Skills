# dev-story-coder — phase 3 of dev-story-flow

Finds every sprint in `planned`, claims it, and executes it to `complete` without a go-ahead:
every story built by silent executors with maximum parallelism, every story's diff reviewed
by a silent `story-code-reviewer`, every acceptance criterion validated against the running
result, failures fixed and re-reviewed or re-validated, the sprint merged to live. Then the
next planned sprint — and, under the `run` loop, anything `dev-story-intake` has since closed
`ready-to-plan` goes back through the planner first. It stops only when nothing is `planned`
(or `ready-to-plan`, under `run`), when a story exhausts its fix attempts, or at the token
budget.

Dispatch, cold-verify, merge and reset the way `story-item-executor` items are always run in
Jonathan's story-based workflows (the same mechanics `dev-story-sprint` uses, spelled out in
full below so this document does not depend on that skill being installed or read). State
moves `planned → executing → complete` (or `blocked`); see [sprint-state.md](sprint-state.md).

## Folders

- Base: `docs/sprints`; sprint `YYYY-MM-DD-NNN`; story `<sprint>/<slug>/`
- Read: `impl-plan.md`, each `<slug>-plan.md`, each `story.md`'s *Acceptance criteria*
- Write: `<slug>/review.md` (written by the reviewer, committed here), `<slug>/validation.md`
  (final validation results), `sprint.json`

## Process

### 1. Find sprints that are planned and not being executed

```bash
SS=${CLAUDE_PLUGIN_ROOT}/assets/bin/sprint-state.sh
git fetch -q && git pull --ff-only
$SS list planned                          # candidates, oldest first
$SS list executing                        # anyone else's? for each: $SS stale <sprint> && echo reclaimable
```

A sprint in `executing` with a **fresh** claim belongs to another session — skip it. A
**stale** one (claim older than `DSF_STALE_HOURS`, default 6, and no commits on its branches
in that window per `git log --since`) may be reclaimed; say so in one line. Under the `run`
loop, also `$SS list ready-to-plan`: anything there goes through the planner procedure
([dev-story-planner.md](dev-story-planner.md)) first and comes back here as `planned`. No
candidates in either state → one line ("No planned sprints.") and end.

### 2. Pick up one sprint and claim it

```bash
ID="coder-$(hostname)-$(date -u +%Y%m%dT%H%M%SZ)"            # once per session
$SS set <sprint> executing --by "$ID"
git add docs/sprints/<sprint>/sprint.json && git commit -qm "chore(sprint): <sprint> executing" && git push -q
```

Then the pre-dispatch setup, with the sprint as the slug:

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
| add-chat-endpoint review | (integration) | after last item | Opus 5 — touches DB |
| create-home-page review | (integration) | after last item | Sonnet 5 |
```

One review row per story. Its model is decided now, from `story.md`'s *Dependencies, risks,
and breaking changes*: **Opus 5** when it names auth, user input, database queries,
filesystem paths, external calls, crypto, or money; **Sonnet 5** otherwise.

No go-ahead is awaited: `planned` **is** the approval. Dispatch wave 1 in the same message.

### 3. Execute each story using its plan — waves across stories

Build one item list across **all** stories in the sprint, honouring `impl-plan.md`'s order:
an item is ready when its own dependencies and its story's prerequisite stories are merged.
Dispatch **every ready item in one message**, one `Agent` call each:

- `subagent_type: "story-item-executor"`, `model` from the plan (explicit), `isolation:
  "worktree"`, `run_in_background: true` when more than one is in flight.
- `prompt`: the dispatch template below (fill every line; ≤ 20 lines). This is the whole
  contract — there is no plan file for the executor to read.

```
dev-story-flow dispatch — <sprint> / <slug> item <n>
Status dir (repo root, not your worktree): .claude/stories/<sprint>/status/
Branch: <type>/<slug>-<item>   Integration: <integration>   Final item: yes/no
Scope: <one line>
Done when: <check you will run>
Not: <explicit exclusions>
Decisions: <resolved since the plan, or none>
Files you own: <paths — nothing outside these without reporting follow-on>
Gates: <the one or two commands that decide it, or "stack default">
PR: no   ← "yes" only when <integration> is branch-protected and cannot take a direct merge
No TDD. No narration. Return the summary and end.
```

Copy *Scope / Done when / Not / Files owned / Gates* from the plan row verbatim. No `Issue:`
line — this flow files no issues, and the executor proceeds without the commit trailer when
one is absent. If the dispatch and the repo disagree, the executor reports `blocked` — not a
judgment call.

**Control plane.** Telemetry, truest first: the commit stream (`git fetch -q && git log
--oneline origin/<branch>`); then `.claude/stories/<sprint>/status/<branch-slug>.json`,
overwritten atomically by the executor at each milestone `grounding → branched → first-push →
implementing → gates-running → gates-passed → pushed` (`blocked`/`cancelled` terminal). Poll
these only when a return needs checking or a background task is suspiciously quiet — the repo
decides, not the sidebar. Kill switch: `touch .claude/signals/cancel` denies every further
tool call from any active executor via the PreToolUse cancel gate; remove the sentinel before
the next dispatch or it dies on its first tool call. Cancellation is loss-free because
executors push on their first commit.

As each executor returns: cold verify — `git fetch -q && git log --oneline
origin/<integration>..origin/<branch>` and `git diff --stat origin/<integration>...origin/<branch>`
against the plan row's scope and *Files owned*, nothing more, nothing less; grep for the
specific symbols/paths the item promised to add, change, or delete; re-run the cheapest
decisive gate on the integration branch after merge. If it holds, merge into integration:

```bash
$SS assert-branch <sprint> || exit 1        # abort/fix — do not merge on failure
git fetch -q && git merge --no-ff -m "merge(<slug>): item <n> <branch>" origin/<branch> && git push origin <integration>
git push origin --delete <branch>; git branch -d <branch> 2>/dev/null; git fetch --prune
git worktree prune
rm -f .claude/stories/<sprint>/status/<branch-slug>.json
```

Then dispatch every not-yet-dispatched item whose dependencies are now all merged, in one
message — do not wait for the rest of the wave if a next-wave item only needed this one.

**Verification fails?** Re-dispatch with the correction, silently. Jonathan hears about it
only if it changes the plan.

**Scope grows mid-item?** The executor finished the agreed slice and proposed the remainder in
its summary. Add it as a new item and dispatch it — no announcement unless it changes the
story's shape.

**Concurrent branches land in return order.** Executors rebase onto integration before their
final push, but a sibling may have merged since. A stale, conflict-free branch still merges
cleanly — proceed. If `git merge` reports a conflict, `git merge --abort` and do **not**
resolve it in the main checkout: dispatch a one-line Sonnet rebase item — "rebase `<branch>`
onto `origin/<integration>`, resolve, re-run gates, `push --force-with-lease`" — with
`isolation: "worktree"`, and merge when it returns.

**Blocked?** The executor returned a precise question. If it can be answered from the plan or
the repo, re-dispatch. If not, this is a decision point — one short message to Jonathan, then
resume.

Mark the story `executing` on its first dispatch:

```bash
$SS story set <sprint> <slug> executing
```

### 4. Once a story's items are all merged, review its diff

The moment a story's last item merges — while other stories' items are still building —
dispatch its reviewer:

```bash
$SS story set <sprint> <slug> reviewing
```

One `Agent` call: `subagent_type: "story-code-reviewer"`, `model` from the table (explicit),
`isolation: "worktree"` (the worktree is cut from the main checkout, which sits on
integration), `run_in_background: true` when anything else is in flight. `prompt`:

```
dev-story-flow review — <sprint> / <slug>
Live: <live>   Integration: <integration>   Kind: <interactive|service>
Files owned: <union of the story's items' Files owned>
Risk surfaces: <from story.md "Dependencies, risks, and breaking changes", or none>
Gates: <the repo's type-check / lint / test commands, or "stack default">
Write review to: <repo root>/docs/sprints/<sprint>/<slug>/review.md   (repo root, not your worktree)
Attempt: <attempts + 1> of 3
No edits to source. No narration. Return the summary and end.
```

The reviewer runs `/code-review` at max effort on the story's diff against live, applies
`nextjs-fullstack-standards` to TypeScript and the `python-library-quality` skills to Python,
checks Jonathan's global review rules, runs `claude ultrareview` only when
`DSF_ULTRA_REVIEW=1` is set, and writes `review.md`. It returns a verdict:

- **`PASS`** → `git add docs/sprints/<sprint>/<slug>/review.md` (it is committed with the
  story in step 6) and go to step 5.
- **`FIX`** → the CRITICAL/HIGH lines of its summary are a fix item. Run
  `$SS story set <sprint> <slug> executing --bump-attempts --detail "review FIX: <first finding, one line>"`
  and dispatch the fix item exactly as step 6 describes (branch `fix/<slug>-attempt-<k>`, the
  findings verbatim in *Scope*, same *Files owned*). Merge it, then re-dispatch the reviewer
  from the top of this step. The attempt counter is shared with validation; the cap of 3
  applies to both together.
- **`blocked`** → the reviewer could not review (empty diff, a gate it cannot run). If the
  plan or the repo answers it, fix the dispatch and re-run; otherwise one short message to
  Jonathan, as for a blocked executor.

NOTE-level findings stay in `review.md` and are not dispatched. A review is never skipped —
a story with no `review.md` showing `PASS` cannot reach `validating` except by `--force`, and
`--force` is not used here.

### 5. Validate the story's acceptance criteria

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

### 6. Fail → fix → re-validate; pass → complete the story

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
failing AC rows and the observed output verbatim in *Scope* (or, when the fix comes from step
4, the reviewer's CRITICAL/HIGH lines verbatim), the same *Files owned* as the items that
produced the behaviour. Model: Sonnet 5 for attempts 1–2, **Opus 5 for attempt 3** (the cause
is by then genuinely unclear, which is the Opus bar). One line in chat when the model changes.
Merge it as any item, then go back to step 4 — a fix is reviewed again before it is
validated again.

**Attempt cap: 3, shared by review and validation.** After the third failed attempt the
story is `blocked`:

```bash
$SS story set <sprint> <slug> blocked --detail "AC-<x> still failing after 3 attempts: <one line>"
```

Continue with every other story in the sprint — one blocked story does not stop the others.

### 7. Mark the sprint complete

When every story is `done`: run the stack gates once on the integration branch as a whole,
then merge to live (skip when `integration=none` — the last story's merge was the close):

```bash
$SS assert-branch <sprint> --target live
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
review and validation files, NOTE-level findings left in `review.md`, anything deferred,
anything claimed-but-unverified.

Any story `blocked` instead → `$SS set <sprint> blocked`, commit, and one message naming each
blocked story, its last failing AC, and the fix paths tried. Jonathan resolves and re-admits
with `sprint-state.sh set <sprint> planned --force`.

**Alternatives considered for the completion mark:** a `DONE` file in the sprint folder (no
history, no per-story detail), deleting or archiving the folder (destroys the evidence),
closing a GitHub milestone (external, invisible to the next phase's `list`). The manifest
status won — see sprint-state.md.

### 8. Next sprint, or end

Go back to step 1. Under the `run` loop, step 1 also runs `$SS list ready-to-plan` after every
sprint: `dev-story-intake` may have closed a new sprint in another session while this one was
executing, and that sprint goes through the planner procedure before it is picked up here.
When both `list ready-to-plan` (under `run`) and `list planned` are empty, one final line:
sprints completed this session, sprints blocked, and that the flow is idle. That line
satisfies "execute until all the planned sprints are completed".

## Budget — 150k / 165k

`context-budget-gate.sh` denies new dispatches at 165k. At 150k: no new dispatch, land what is
in flight (merge what verifies), make `sprint.json` truthful (stories `executing` with
`detail` naming pushed-but-unmerged branches), commit, push, then `Skill({skill:
"clear-prompt", args: "dev-story-flow execute <sprint>"})`. Because all state is on disk, the
resumption prompt is short: the next orchestrator runs `/goal using dev-story-flow execute
until all planned sprints are completed`, reclaims the sprint (its own claim is stale-or-own
by definition — pass the same `--by` id from the prompt, or `--force`), merges any pushed
branches named in `detail`, and continues from step 3 (or from step 4 for a story whose `detail` says its review was
pending).

### Stopping point at 160k

At 160k, stop waiting on executors for new dispatch decisions and merge only items already
verified against the integration branch. For every story that still has an executor running,
or one that returned but is not yet verified, run:

```bash
$SS story set <sprint> <slug> executing --detail "branch <b> pushed, not merged"
```

Substitute the real branch name for `<b>`. Use `reviewing` or `validating` in place of
`executing` if that story was already in that state when the trigger hit; a reviewer still
running is simply re-dispatched by the next session. Leave the sprint itself `executing`
with its claim intact — do not touch `sprint.json`'s sprint-level status or claim. Commit,
push, then `Skill({skill: "clear-prompt", args: "dev-story-flow execute <sprint>"})`. Past that
threshold, a Stop hook (`handoff-stop-gate.sh`) won't let the turn end until `clear-prompt` has
posted the hand-off block, and `clear-prompt` clears the session itself once it has posted.

## Rules

- **Silence is non-negotiable** (SKILL.md rule 3): silent between the sprint's table message
  and its closing message, except a model change on re-dispatch (one line), a stale-claim
  takeover (one line), or a `blocked` story (one message). Every executor and verifier
  sub-agent returns only its summary. Stay quiet and keep every sub-agent quiet unless
  something genuinely needs Jonathan's attention.
- Never resolve a merge conflict in the main checkout. Never switch its branch.
- Never mark `done` without a `review.md` whose verdict is `PASS` and a `validation.md` that
  shows every AC row passing. "Not verified" is a `reviewing` or `validating` story, not a
  `done` one.
- The reviewer is read-only on source and never runs `claude ultrareview` unless
  `DSF_ULTRA_REVIEW=1` is set — every ultra run is billed, so it is Jonathan's call, made in
  the environment, not the orchestrator's.
- The repo decides, not the sidebar: `status.json` `pushed` plus commits on `origin/<branch>`
  means the item is ready, whatever the agent list says.
- Kill switch: `touch .claude/signals/cancel` stops every executor; remove it before the next
  dispatch.
