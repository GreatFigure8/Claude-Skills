# Dev Epic Workflow — User Guide

**Version:** v2 (orchestrated executors + control plane + issue intake) · **Updated:** 2026-08-19
**Canonical home:** `~/Source/Claude Skills/dev-epic-workflow` · This guide covers the *current* deployment. Tier 1 (session-start backlog check) and Tier 2 (unattended intake) will be appended as they ship.

---

## The mental model in four sentences

You sit in one **orchestrator** session per repo per day. Work items run in disposable **executor** subagents that branch, build, gate, and open a PR, then die. Everything that matters lives **on disk** — the plan, the pushed branch, the status files — never in a session's memory. Your recurring keystrokes are decisions: *approve, dispatch, merge, done for the day.*

```
you ──► orchestrator (your session, lives all day)
              │  holds plan.md, dispatches, verifies, merges
              ├──► executor (item 1) ──► PR ──► dies
              ├──► executor (item 2) ──► PR ──► dies
              └──► /handoff at day end
tracker (GitHub / ADO) = system of record for WHAT & WHY
docs/epics/<NN>-<slug>/ = system of record for HOW & STATUS
```

---

## Quick reference

| You want to… | Do this |
|---|---|
| Report a new bug/feature | Just say it: `bug: <what you observed>` — or `/intake bug: …` |
| Pick up an existing issue | `pick up issue 124` / `pick up AB#4571` / paste the URL |
| See the backlog | `/intake` (no argument) |
| Check on a running executor | `/tasks`, or `cat docs/epics/<NN>-*/status/<branch>.json` |
| Watch an executor live | `tail -f docs/epics/<NN>-*/status/<branch>.log` |
| Cancel ALL executors (this repo) | `touch .claude/signals/cancel` |
| Cancel this epic's executors | `touch docs/epics/<NN>-<slug>/CANCEL` |
| Cancel ONE item | `echo "<branch-name>" >> docs/epics/<NN>-<slug>/CANCEL` |
| Un-cancel | `rm` the sentinel file (required before the next dispatch) |
| End the day | `/handoff`, then close the terminal |
| Resume tomorrow | Just open a session — the handoff injects itself |

---

## A day in the flow

### Morning — open the orchestrator

Open one Claude Code session per repo you're working. The SessionStart hook injects the current epic's `handoff.md` and git state automatically; the session verifies those claims against the repo before building on them (that's Phase 0's resume rule — it does this itself).

You don't declare a session "the orchestrator." Any session that reads a plan and dispatches is one.

### Starting work — three equivalent entry points

The description always comes first; no command is ever a prerequisite.

1. **Natural language** (the normal path): `bug: the OIC retry loop double-applies receipts on Fusion callback timeout` — intake triggers on the phrasing.
2. **`/intake <ref or description>`**: a ref (`#124`, `AB#4571`, a URL) routes to *pickup*; free text routes to *report*.
3. **`/intake` empty**: lists open tracker items with a recommended pickup order; choose one.

**What happens next, in order — and where you're needed:**

| Step | Who | What |
|---|---|---|
| Issue filed first (report path) | Claude | Creates the GH issue / ADO work item from your stated facts; confirms `Filed as GH #124` |
| Grounding | Claude | Reads the actual code, logs, tracker comments |
| Plan presented | **You** | Outcome, `Source:` ref, work items with branches, risks. **Nothing proceeds until you approve.** Small bugs get small plans. |
| Plan filed + linked | Claude | Commits `docs/epics/<NN>-<slug>/plan.md`, comments the link on the issue, labels `epic:planned`, adds the work-item checklist (GH) or child Tasks (ADO) |
| Dispatch | Claude | Item 1 goes to the executor; your session goes quiet |

### While an executor runs (5–20 min typical)

You can watch, or not — the intended steady state is *not*. If you do:

- **Milestones:** `status/<branch>.json` walks `grounding → branched → first-push → implementing → gates-running → gates-passed → pr-opened`. Terminal states: `pr-opened`, `blocked`, `cancelled`.
- **Live feed:** `tail -f status/<branch>.log` — one line per tool call, deterministic (a hook writes it, not the model).
- **Ground truth:** `git log origin/<branch>` — the branch is on origin within minutes because the executor pushes on its first commit. The commit stream cannot be faked by prose.

**Cancelling** is touching a file (see quick reference). The cancel gate denies the executor's tool calls at the system level — it does not depend on the model noticing or cooperating. Nothing is lost: everything pushed stays pushed. **Remember to `rm` the sentinel afterward**, or the next executor dies on its first tool call (loud and harmless, but annoying).

**`blocked` is success, not a stall.** An executor that hits plan ambiguity stops and returns with a precise question instead of guessing. Answer it; the orchestrator re-dispatches.

### When the executor returns

The orchestrator **does not believe the summary.** It verifies cold — `git log`, `git diff --stat`, greps for promised symbols, gates on the branch — then reports to you. **Merging is yours to approve.** On your go: merge commit into integration, branch deleted remote + local, checklist ticked / child Task closed, control-plane files cleaned, and it proposes the next dispatch. No `/handoff`, no `/clear` between items — the executor's death *was* the reset.

### End of day

At a **dispatch boundary** (last executor returned and merged — don't checkpoint with one mid-flight):

```
/handoff
```

Commits and pushes, overwrites the epic's `handoff.md` with orchestrator state (dispatch position, awaiting-merge, blocked items, open decisions), and tells you it's safe to close. Tomorrow's session picks it up automatically. **One ritual per day, not per item.**

---

## Scope, splits, and mid-epic reports

- **Scope grows mid-item** → the branch doesn't. The executor finishes the agreed slice and proposes the remainder as a follow-on item in its return summary; the orchestrator updates the plan.
- **You spot a new problem mid-epic** → if it belongs to the *current* epic, it's a scope/defer decision plus a checklist line or child Task on the existing issue — not a new epic. If it's unrelated, report it (`bug: …`) and it becomes its own tracked epic for later.
- **Issues created outside Claude Code** (web UI, teammates, your phone) sit in the tracker until you ask: `check for new issues` or empty `/intake` in a running orchestrator, any time. *(Tier 1 will make every fresh session open self-briefed on the backlog; Tier 2 will file epics unattended, stopping at plan-filed for your approval.)*

## Pre-v2 epics

Nothing to migrate. Open a fresh session, say `resume epic <NN>` — it orchestrates from the first not-yet-started item. A **half-done item** from an old session: preferably finish it direct-mode (hands-on in the session, still a valid path) and dispatch the *next* item orchestrated; or re-dispatch it with an honest continue-from line ("branch exists at `<hash>`, continue, don't re-create"). Old epics have no `Source:` ref — fine; that's untracked internal work, retro-linkable during a resume if you want.

## Parallel work items

Independent items only (the plan's sequence governs). One **git worktree** per parallel item, one executor per worktree, run as background tasks. Branch-scoped cancel (`echo "<branch>" >> CANCEL`) is how you stop one without stopping the others.

---

## Troubleshooting

| Symptom | Meaning | Fix |
|---|---|---|
| Intake stops immediately citing auth | `gh` / `az` not authenticated | `gh auth login` · `az extension add --name azure-devops` + `az devops configure --defaults …` |
| Next executor dies on its first tool call, "CANCELLED by cancel gate" | Stale sentinel from an earlier cancel | `rm` the `CANCEL` / `.claude/signals/cancel` file |
| Task UI says "in progress" but status.json is terminal and the PR exists | Known UI lag | **The repo decides, not the sidebar.** The item is done; proceed. |
| No START/STOP brackets in the status log on the first run | The lifecycle hook's `agent_id` field name may differ in your Claude Code version | One-line matcher fix in `subagent-lifecycle.sh` — flag it and we patch |
| `status.json` `updated` goes stale mid-run, log stream stops | Executor hung or died | Branch is pushed, nothing lost. Cancel-and-re-dispatch with a continue-from line |
| Hooks not firing in a session | Session predates the install, or wiring missing | Hooks bind at session start — restart the session. Verify: `ls ~/.claude/hooks/ \| wc -l` → 7 |
| Instructions feel stale in a session | Local copy shadowing, or old session | `readlink ~/.claude/skills/dev-epic-workflow` must point at the repo; repo wins on any disagreement |

## Housekeeping facts worth knowing

- **Updates:** edit or pull in `~/Source/Claude Skills/dev-epic-workflow` → instructions are live in the *next* session via the symlink. Payload changed (hooks/agent/commands)? Re-run `install.sh --user` — idempotent, re-run whenever unsure. Save the `.skill` to claude.ai only to keep that surface's copy current; nothing on the machine depends on it.
- **Runtime state is gitignored:** `docs/epics/*/status/`, `docs/epics/*/CANCEL`, `.claude/signals/` — cleaning them is an `rm`, never a commit.
- **Tracker etiquette is built in:** one terse comment per phase boundary; the fine grain lives in the commit stream and `status/`. `Closes #<n>` goes only on the epic's final PR.
- **Epic close (Phase 5) deletes its own scaffolding:** handoff, autosnapshots, `status/`, sentinels, stale worktrees — a closed epic leaves only the plan, the retro, and the merged code.

## Roadmap (placeholders — this guide grows with them)

- **Tier 1 — session-start backlog check:** every fresh orchestrator opens knowing which open issues lack epics. *To be built through the workflow itself as its first intake.*
- **Tier 2 — unattended intake:** labeled issues (`claude-intake`) trigger headless plan-filing via CI, **stopping at plan-filed** — approval, dispatch, and merge remain yours. *To be built after Tier 1, through the workflow.*
