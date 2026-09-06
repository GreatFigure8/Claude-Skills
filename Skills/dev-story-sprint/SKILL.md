---
name: dev-story-sprint
description: Jonathan's fast lane for shipping ONE user story — plan in the chat where the story is written, then go straight to code via silent, parallel dispatched executors. No TDD, no epic docs, no planning session, Sonnet 5 by default with Opus 5 only for the hard items, orchestrator capped at 150k tokens with an automatic handoff prompt near the cap. Use whenever Jonathan writes or pastes a user story, says "sprint", "story", "just build it", "fast lane", "slim workflow", "no epic", "let's ship this one", "quiet mode", "get it done", or wants a code change in his repos (FastAPI/FastMCP, Oracle Fusion MCP tooling, OIC, Next.js, OCI, Supabase) WITHOUT the full dev-epic-workflow ceremony. Also trigger when resuming a story from a handoff prompt ("resume story", "continue the sprint", a pasted `dev-story-sprint handoff` block), or when asked whether the orchestrator is near its token budget. Do NOT use for multi-story epics, issue-tracker intake, or when Jonathan explicitly asks for an epic plan — that is dev-epic-workflow.
---

# Dev Story Sprint

The slim, fast sibling of `dev-epic-workflow`. Same bones — one branch and one executor per work item, commit and push early, verify what actually landed, land-and-reset — with the ceremony cut out and the throttle open. **One orchestrator, one user story, zero documents, as many silent coders as the story can absorb at once.** The story is authored in the chat, the plan is stated in the chat, and then code happens in parallel. The point of this skill is to spend tokens on shipping, not on narrating.

## The rules (Jonathan's spec)

1. **One story per orchestrator.** A second story is a new chat. Never two stories in flight in one context.
2. **No epic, no documents.** No `plan.md`, no epic folder, no PR template chore, no retro, no tracker linking. The plan is one chat message and lives in the dispatches.
3. **No TDD.** This skill **overrides** the global testing rules (tests-first, 80% coverage). Executors do not write tests first and do not chase a coverage number. Existing suites must still pass as a gate. New tests are written only when the dispatch says so, or when the item changes a tested contract and the old test is now wrong.
4. **Executors are silent.** No text between tool calls. No "now I'll…", no progress, no plan, no questions. Their only output is one return summary to the orchestrator, ≤ 20 lines. They never address Jonathan. A question is a `blocked` state, not a sentence.
5. **The orchestrator is silent.** It speaks exactly four times: the plan message, a decision it genuinely cannot make, the closing message, and the handoff. No progress narration, no "dispatching wave 2", no recaps, no restating the plan, no verification chatter. Silence is consent; Jonathan interrupts if he wants to.
6. **Maximum parallelism.** Decompose the story for independence, then dispatch **every** item whose dependencies are met in the **same message** — one `Agent` call per item. Waves, not a queue. The only serialisation is a real code dependency.
7. **The orchestrator picks the model per item, always explicitly.** `model: "sonnet"` (Sonnet 5) is the default and is used whenever it can do the job. `model: "opus"` (Opus 5) only for items meeting the complexity bar below. Never leave `model` to inherit.
8. **Every dispatch runs in its own worktree** — `isolation: "worktree"` on the `Agent` call, no exceptions, single-item flow included. The orchestrator keeps the main checkout; no executor ever switches its branch.
9. **The orchestrator never exceeds 150k tokens.** Hard cap. Approaching it → clean stopping point → handoff prompt → alert Jonathan → stop.
10. **Have fun.** Terse is not grim. The four messages the orchestrator does send can have a pulse.

## Flow at a glance

```
story in chat ──► ground (targeted reads) ──► ONE plan message ──► dispatch wave 1 (all items, one message)
                                                                            │
      ┌──── each executor returns ──► cold verify ──► merge ──► reset ──► dispatch anything now unblocked
      │                                                                     │
      └──────────── story done: ONE closing message ◄───────────────────────┘
                    (or: ~120k → stopping point → handoff prompt → alert)
```

## Step 1 — Ground, then plan in one message

Never plan from recall. Read the tree, the modules the story touches, `git log --oneline -15`, `git branch -a`, CI config, and the relevant skill for stack specifics. Keep it cheap — `grep -n` and `sed -n` ranges of the files the story names, not a repo tour. Every byte read here counts against the cap.

**Decompose for parallelism.** Split along file/module ownership so that no two items in a wave touch the same files. Shared scaffolding everyone needs (a new type, a migration, a config key, a gitignore line) is wave 1 on its own; everything that consumes it is wave 2. An item that cannot be described in one line, or whose diff would run past a few hundred meaningful lines, is two items. Splitting is cheap; a conflict is not.

**Pick the model per item.** Sonnet 5 unless the item meets the Opus bar: a cross-module refactor with unclear blast radius; debugging where the cause is genuinely unknown; concurrency, data migrations, or auth/security-sensitive changes; anything where a wrong-but-plausible answer would be expensive to detect. "It's big" is not the bar — big-and-mechanical is Sonnet.

Then post **one** plan message and nothing after it until there is something Jonathan must hear:

```
Story: <one line>
Branch line: live=<branch>  integration=<branch>  tag-first: yes/no
Grounded: <what was read>   Assumed: <what wasn't, if anything>

| # | Branch | Scope / Done when / Not | Wave | Model |
|---|---|---|---|---|
| 1 | feat/<story>-<item> | <scope>. Done when: <check>. Not: <exclusion>. | 1 | Sonnet 5 |
| 2 | feat/<story>-<item> | ... | 1 | Sonnet 5 |
| 3 | fix/<story>-<item>  | ... (depends on 1) | 2 | Opus 5 |

Open questions: none   ← if not none, STOP here and ask; that is the one legitimate pause
Going.
```

**This table is the model-announcement table the global rules require** for every agent spawn. It covers every wave of the story; later waves are not re-announced. If a re-dispatch changes an item's model, one line says so.

If **Open questions** is empty, dispatch wave 1 immediately in the very next tool message. If not, end with the question(s) and wait.

Branch line: integration branch named explicitly; live/cutover untouched until the story closes; `pre-<story-slug>` tag before anything painful to reconstruct (restructures, migrations, platform moves).

## Step 2 — Dispatch a wave

**Before the first dispatch** (silently, one Bash call):

```bash
mkdir -p .claude/stories/<slug>/status .claude/signals
grep -qx '.claude/stories/' .gitignore || printf '.claude/stories/\n' >> .gitignore
grep -qx '.claude/signals/' .gitignore || printf '.claude/signals/\n' >> .gitignore
printf '.claude/stories/<slug>\n' > .claude/signals/active-epic
```

The last line matters in repos that also run `dev-epic-workflow`: its subagent-lifecycle hook routes executor telemetry to the "active epic", and with no pointer it falls back to the newest in-flight epic plan — a sprint would silently write into someone else's `status/` tree. The hook honours a pointer to any existing directory without a closed `plan.md`, so pointing it at the story dir keeps the sprint's telemetry in the sprint.

**One `Agent` call per item, all of a wave's items in one message.** Each call:

- `subagent_type: "story-item-executor"`
- `model: "sonnet"` or `model: "opus"` — from the plan table, always explicit
- `isolation: "worktree"` — always
- `run_in_background: true` when the wave has more than one item, so each return wakes the orchestrator to verify and merge that item while the others keep running. A single-item wave may run in the foreground.
- `prompt`: the dispatch below. **The dispatch is the whole contract** — there is no plan file for the executor to read.

**Dispatch template** (fill every line; ≤ 20 lines):

```
dev-story-sprint dispatch — <story-slug> item <n>
Status dir (repo root, not your worktree): .claude/stories/<slug>/status/
Branch: <type>/<slug>-<item>   Integration: <branch>   Final item: yes/no
Scope: <one line>
Done when: <check the orchestrator will run>
Not: <explicit exclusions>
Decisions: <resolved since the plan, or none>
Files you own: <paths — nothing outside these without reporting follow-on>
Gates: <the one or two commands that decide it, or "stack default">
No TDD. No narration. Return the summary and end.
```

If the dispatch and the repo disagree, the executor reports `blocked` — not a judgment call.

**Control plane (reused from the dev-epic install — no new hooks).**

- Telemetry, truest first: the **commit stream** (`git fetch -q && git log --oneline origin/<branch>`); then `.claude/stories/<slug>/status/<branch-slug>.json`, overwritten atomically by the executor at each milestone `grounding → branched → first-push → implementing → gates-running → gates-passed → pr-opened` (`blocked` / `cancelled` terminal). The orchestrator does not poll these — it reads them only when an executor's return needs checking or when a background task is suspiciously quiet.
- Kill switch: `touch .claude/signals/cancel` denies every further tool call from any active executor via the PreToolUse cancel gate; one branch name per line cancels only matching executors. Remove the sentinel afterward or the next dispatch dies on its first tool call. Cancellation is loss-free because executors push on their first commit.
- **The repo decides, not the task list.** If `status.json` says `pr-opened` and the PR exists on origin, the item is ready regardless of what the agent sidebar claims.

## Step 3 — An executor returns: verify cold, merge, reset, dispatch what's unblocked

The orchestrator never shared the executor's context, so it checks the summary the way it would check a stranger's PR — in one or two Bash calls, silently:

- `git fetch -q && git log --oneline origin/<integration>..origin/<branch>` and `git diff --stat origin/<integration>...origin/<branch>` — does the diff match the scope and the "Files you own" line, nothing more, nothing less?
- Grep for the specific symbols/paths the item promised to add, change, or delete. Deleted-scaffolding items are the easiest to fake and the most important to check.
- Gates: trust the executor's verbatim gate output only if it is re-runnable; re-run the cheapest decisive one on the integration branch after merge.

**If it holds, merge with a merge commit** (keeps merge-revert as rollback) and land-and-reset. From the main checkout, never switching branches:

```bash
gh pr merge <pr> --merge --delete-branch          # or: git merge --no-ff origin/<branch> && git push
git pull --ff-only && git log --oneline -3
git branch -d <branch> 2>/dev/null; git fetch --prune
git worktree prune                                 # Agent-created worktrees are removed by the tool; this clears stale entries
rm -f .claude/stories/<slug>/status/<branch-slug>.json
```

**Concurrent PRs land in return order.** Executors rebase onto integration before opening their PR, but a sibling may have merged since. A stale, conflict-free branch still merges cleanly with a merge commit — proceed. If GitHub or `git merge` reports a conflict, do **not** resolve it in the main checkout: dispatch a one-line Sonnet item — "rebase `<branch>` onto `origin/<integration>`, resolve, re-run gates, `push --force-with-lease`" — with `isolation: "worktree"`, and merge when it returns.

**Then dispatch every not-yet-dispatched item whose dependencies are now all merged**, in one message. Do not wait for the rest of the wave if a next-wave item only needed this one.

**Verification fails?** Re-dispatch with the correction, silently. Jonathan hears about it only if it changes the plan.

**Scope grows mid-item?** The executor finished the agreed slice and proposed the remainder in its summary. Add it as a new item and dispatch it — no announcement unless it changes the story's shape.

**Blocked?** The executor returned a precise question. If the orchestrator can answer it from the story or the repo, re-dispatch. If not, this is a decision point — one short message to Jonathan, then resume.

## Step 4 — Story done

When every item is verified and merged: run the gates once on the integration branch as a whole, merge to live as a drop-in replacement, tag if the story warranted a `pre-` tag. Then **one** closing message: what shipped (PR links, tag), anything deferred, anything claimed-but-unverified. Then `rm -rf .claude/stories/<slug> .claude/signals/active-epic`. That's the whole retro.

## The 150k token budget

The cap is on the **orchestrator's context**, and it is a working limit, not the window. Watch it via the statusline's context readout (installed by dev-epic-workflow) or by counting: every executor return, every file read, every plan message.

Habits that keep the orchestrator small:

- Read only what the plan needs; never read an executor's `.log`; never `cat` a large file to "get a feel".
- Dispatches ≤ 20 lines; executor summaries ≤ 20 lines (the executor agent enforces this).
- Verification is `--stat` and `grep`, never a full diff in context — link the PR.
- Background executors return once; do not poll them.

**Trigger:** ~120k tokens (80% of cap), or any sign of degradation (re-reading a file already read, forgetting a resolved decision, drifting from the plan). At the trigger, do **not** start a new dispatch. Find the nearest **valid stopping point**, in order of preference:

1. Between waves — everything dispatched so far merged and reset.
2. Executors have returned and been verified but not merged → merge, reset, stop.
3. Executors are running → let each reach `pr-opened` or `blocked`, merge what verifies, stop. Their branches are pushed either way.

At the stopping point, write the handoff prompt (template below) to `.claude/stories/<slug>/handoff.md` **and** post it in chat as a single fenced block, preceded by one line: *"Orchestrator at ~<N>k — clean stopping point reached. Paste this into a fresh chat to continue:"*. Then say nothing more.

**Handoff prompt template** (fill every line; omit nothing that lives only in this conversation):

```
dev-story-sprint handoff — <story-slug>
Repo: <path or remote>   Live: <branch>   Integration: <branch> @ <short-hash>
Story: <the one-line story, verbatim>
Items:
  1. <branch> — DONE (merged <hash>)                       Sonnet 5
  2. <branch> — DONE (merged <hash>)                       Sonnet 5
  3. <branch> — NEXT: <scope>. Done when: <check>. Not: <exclusion>.   Opus 5
  4. <branch> — <scope>  (depends on 3)                    Sonnet 5
Decisions made since the plan: <bullet list, or none>
Verified: <facts checked against the repo>
Claimed but NOT verified: <anything believed but unchecked — the new orchestrator checks these first>
In flight / environment: <open PRs, running executors' branches, worktrees, env vars — or none>
Exact next action: <one imperative sentence>
```

**Resuming from a handoff:** the new orchestrator treats the block as a story plus a plan already made. It re-grounds from the repo (`git log`, `git status`, `git worktree list`, `gh pr list`, a grep for whatever "Claimed but NOT verified" names), verifies before building, and dispatches every unblocked item without re-posting a plan — the handoff *is* the plan message and its model table. If the repo disagrees with the handoff, the repo wins and the orchestrator says so in one line.

## Install (once per machine)

Both live pieces are **symlinks into this repo**, so edits here are live immediately and nothing needs re-running after a change:

- `~/.claude/skills/dev-story-sprint` → `<repo>/Skills/dev-story-sprint`
- `~/.claude/agents/story-item-executor.md` → `<repo>/Skills/dev-story-sprint/assets/agents/story-item-executor.md`

`bash <skill-path>/assets/install.sh` creates both symlinks idempotently (a pre-existing plain copy is moved aside as `.bak`). The control plane (cancel gate, subagent lifecycle, statusline) comes from the `dev-epic-workflow` user-level install — run that first if `~/.claude/hooks/cancel-gate.sh` is missing. When Claude has shell access it checks and installs rather than describing the steps.

## What this skill overrides from the global rules

Stated explicitly so nobody has to reconcile it mid-story:

- **Testing:** no TDD, no coverage target (rule 3). Gates still run.
- **Model table per spawn:** satisfied once by the plan message's table, for all waves (Step 1).
- **Announcing what you're about to do / brief updates:** the orchestrator does not narrate (rule 5). The plan message is the announcement; the closing message is the recap.
- **Commit at task end:** executors commit continuously and push on the first commit; the orchestrator's merges are the story's commits.

Everything else — immutability, error handling, secrets, code review severity on auth/DB/money paths — still applies to the code the executors write.

## What this skill deliberately does not have

No epic folder, no `plan.md`, no `/handoff` or `/intake` commands, no PR-template chore, no retro, no tracker linking, no status-log tailing by the orchestrator, no tests-first. If a story needs any of those, it isn't a sprint — use `dev-epic-workflow`.

## Working-style notes (kept from the parent)

- Don't assert that something works, exists, or landed without having looked. "Not verified" is a complete sentence.
- Prefer doing the mechanical step over describing it.
- The handoff block is always complete — never a fragment to merge by hand.
- At land-and-reset the orchestrator proactively dispatches whatever is unblocked; at the story's end it closes; at the budget trigger it hands off. It never idles and never asks "shall I continue?".
