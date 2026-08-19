# Session Handoff Protocol

Sessions are disposable; the epic folder is not. This reference defines the artifact and the automation behind Phase 3.5 of the workflow: how a coding session checkpoints its state to disk, how the next session picks it up, and how the whole loop is enforced by hooks rather than memory.

## The state model — where each kind of truth lives

| State | Home | Lifetime |
|---|---|---|
| Durable conventions, stack rules | `CLAUDE.md` | Permanent |
| Epic-level truth: outcome, work items, decisions, deferred | `docs/epics/<NN-slug>/plan.md` | Life of the epic |
| Mid-item conversational delta | `docs/epics/<NN-slug>/handoff.md` | Until next checkpoint (overwritten) or item merge (deleted) |
| Emergency pre-compact snapshot | `docs/epics/<NN-slug>/handoff-autosnapshot.md` (fallback: `.claude/handoff-autosnapshot.md`) | Until next SessionStart surfaces it |
| Everything else | git | Permanent |

The handoff carries **only** what exists in conversation and nowhere on disk. If a fact is already in the plan, in a commit message, or derivable from `git status`, it does not belong in the handoff — small handoff, fast resume.

## handoff.md template

```markdown
# Session Handoff — <epic slug> / work item <N>

**Written:** <ISO timestamp>
**Branch:** <branch> (pushed: yes — non-negotiable)
**Last commit:** <short-hash> <subject>
**Worktree:** <path, or "main checkout">

## Verified this session
<!-- Only things actually checked against the repo/gates. -->
- <fact> — verified by <command / gate / diff read>

## Claimed but NOT yet verified
<!-- Anything believed done but not re-checked. Next session verifies these FIRST. -->
- <claim>

## In-flight (debugging / hypothesis state)
<!-- Only when mid-debug. The chain of reasoning that lives in conversation. -->
- Symptom:
- Hypotheses ruled out (and how):
- Current hypothesis:
- Next experiment:

## Exact next action
<!-- One imperative sentence. The next session starts here after re-grounding. -->

## Environment state
<!-- Running services, applied-but-unmerged migrations, env vars set, tunnels, test data seeded. -->

## Open questions for Jonathan
```

Rules:

- **Overwrite, never append.** It is a snapshot, not a log. History lives in git — the handoff is committed, so every checkpoint is recoverable from `git log` anyway.
- **Commit and push it** (`chore(epic): session handoff — <item>`). An unpushed checkpoint is not a checkpoint.
- **Delete it at land-and-reset** (Phase 3 step 10). A handoff for a merged item is stale state; the epic closes (Phase 5) with no handoff files anywhere.

## Checkpoint ritual → the `/handoff` command

The ritual (commit + push, write handoff, commit + push handoff, announce safe-to-clear) is packaged as the `/handoff` slash command in `assets/claude-config/commands/handoff.md`. Run it:

- at end of day,
- when the statusline shows context climbing on a session expected to continue,
- before kicking off a long agentic run,
- on degradation symptoms (re-reading files, forgotten decisions, plan drift),
- any time before `/clear`.

`/handoff` accepts an optional argument for the in-flight section, e.g. `/handoff still chasing the 401 on the OIC connection test — token audience hypothesis`.

## Resume ritual — automatic, then verified

The **SessionStart hook** fires on `startup`, `resume`, `clear`, and `compact`, and injects into context: current branch, short status, recent log, worktree list, the newest `handoff.md` under `docs/epics/`, and — loudly — any `handoff-autosnapshot.md` left by a compaction or a dirty session end (which it then deletes, so warnings never go stale).

The session then applies Phase 0's resume rule: **the handoff describes where the previous session believed it was; the repo is where the work is.** Everything under "Claimed but NOT yet verified" gets verified before anything is built on it. If the handoff says a test passed, run it.

## Compaction — the exception, instrumented

- Guided `/compact <focus>` is allowed only mid-debug when the hypothesis chain can't be cheaply written down, followed by a real checkpoint at the next stable point.
- The **PreCompact hook** fires before *any* compaction (manual or auto) and snapshots branch, status, log, and diffstat to `handoff-autosnapshot.md` with a banner instructing the post-compact context to treat all prior claims as unverified and re-ground from disk.
- The **SessionEnd hook** appends a warning to the same autosnapshot if a session terminates with a dirty tree, so the next SessionStart surfaces "previous session ended with uncommitted changes" deterministically.
- Auto-compact firing is an incident: it means a checkpoint trigger was missed. Note it in the next handoff.

## Parallel sessions — worktree quick reference

One session per worktree, one worktree per in-flight (independent) work item:

```bash
# start item N in parallel (from the main checkout, integration synced)
git worktree add ../<repo>-<branch-slug> -b <branch> <integration>
# → open a NEW Claude Code session in that directory

# at land-and-reset for that item
git worktree remove ../<repo>-<branch-slug>
git worktree prune
```

Worktrees share the repo's committed `.claude/` config — hooks, `/handoff`, and the statusline work identically in every worktree. Each worktree's SessionStart injection reports its own branch, so parallel sessions never cross-contaminate. Never open two sessions in the same working tree.

## Installing the automation — once per machine, not per repo

**User-level (default, run once per machine):**

```bash
bash <skill-path>/assets/claude-config/install.sh --user
```

Installs into `~/.claude/` — hooks, `/handoff`, and statusline then apply to **every repo and worktree on the machine**, with nothing committed into any repo (the right default for client repos). Repeat once on each machine (e.g. the Mac and the Windows VM).

**Repo-level (only when the repo must carry it — cloud sessions, teammates, self-contained repos):**

```bash
bash <skill-path>/assets/claude-config/install.sh --commit   # from inside the repo
```

Installs into the repo's `.claude/`, gitignores the autosnapshot fallback, and commits (omit `--commit` to review first).

Both modes **merge** into any existing `settings.json` (never clobbering an existing statusline or hooks — idempotent, keyed on command paths), and re-running the installer is how updated scripts roll out. Don't install both modes for the same repo — hooks append, so both would fire and duplicate the SessionStart injection. Hooks take effect on the next session started.

The scripts parse hook JSON with `jq` when present and fall back to `python3` (verified working with neither missing entirely — they degrade to branch-only output rather than erroring). Hook field names in the statusline input evolve with Claude Code releases; `statusline.sh` probes several known field paths and omits what it can't find — if context % stops rendering after an update, check the current statusline docs and adjust the probes.

## What stays manual — by design

An interactive session cannot kill itself and spawn its replacement. The irreducible human actions are:

1. `/handoff` (one command — everything it does is automated),
2. `/clear` or opening the next worktree's terminal.

Everything before, between, and after those two keystrokes — capture, commit, push, warning surfacing, re-injection, re-grounding — is deterministic.
