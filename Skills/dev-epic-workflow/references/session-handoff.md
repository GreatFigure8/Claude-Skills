# Session Handoff Protocol

Sessions are disposable; the epic folder is not. This reference defines the artifact and the automation behind Phase 3.5 of the workflow: how a coding session checkpoints its state to disk, how the next session picks it up, and how the whole loop is enforced by hooks rather than memory.

## The state model — where each kind of truth lives

| State | Home | Lifetime |
|---|---|---|
| Durable conventions, stack rules | `CLAUDE.md` | Permanent |
| Epic-level truth: outcome, work items, decisions, deferred | `docs/epics/<NN-slug>/plan.md` | Life of the epic |
| Mid-item conversational delta | `docs/epics/handoff.md` — **one file per repo, never one per epic** | Until next checkpoint (overwritten) or item merge (deleted) |
| Emergency pre-compact snapshot | `docs/epics/handoff-autosnapshot.md` (fallback: `.claude/handoff-autosnapshot.md`) | Until next SessionStart surfaces it |
| Everything else | git | Permanent |

The handoff carries **only** what exists in conversation and nowhere on disk. If a fact is already in the plan, in a commit message, or derivable from `git status`, it does not belong in the handoff — small handoff, fast resume.

## One handoff per repo — `docs/epics/handoff.md`

**Every session in a repo checkpoints to the same file: `docs/epics/handoff.md`** (in whatever case the repo already spells that folder, e.g. `DOCS/EPICS/handoff.md`). It sits at the root of the epics folder, beside the numbered epic folders, never inside one.

Handoffs are **session** state, not epic state, and one fixed path is what makes a resume cheap: the SessionStart hook opens one known file instead of globbing every epic folder, sorting by mtime and guessing which of several stale handoffs is the live one. Scattering them per epic makes every future session pay to find the one that matters — and makes it easy to resume from the wrong one.

Epic-level truth that must outlive the session does not go here at all: it goes in that epic's `plan.md`, where the status header, the work items and the Deferred parking lot already live. The handoff's `**Epic:**` field is a pointer to that folder, so nothing is lost by having one file.

## handoff.md template

```markdown
# Session Handoff — <epic slug> / work item <N>

**Written:** <ISO timestamp>
**Epic:** <path to the epic folder, e.g. docs/epics/12-oauth-refresh-rotation — or "none">
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

- **One path, always.** `docs/epics/handoff.md`. A handoff written into an epic folder is a defect, however natural it feels while working inside that epic; migrate any that predate this rule by folding what is still live into the single file and `git rm`-ing them.
- **Overwrite, never append.** It is a snapshot, not a log. History lives in git — the handoff is committed, so every checkpoint is recoverable from `git log docs/epics/handoff.md` anyway. Carry a prior session's content forward only where it is still live (unmerged branch, unverified claim, unanswered question).
- **Commit and push it** (`chore(epic): session handoff — <item>`). An unpushed checkpoint is not a checkpoint.
- **Delete it at land-and-reset** (Phase 3 step 10) when nothing else is in flight. A handoff describing a merged item is stale state that the next session will be injected with and made to verify; the epic closes (Phase 5) with no handoff file left behind.

## Checkpoint ritual → the `/handoff` command

The ritual (commit + push, write handoff, commit + push handoff, announce safe-to-clear) is packaged as the `/handoff` slash command in `assets/claude-config/commands/handoff.md`. Run it:

- at end of day,
- when the statusline shows context climbing on a session expected to continue,
- before kicking off a long agentic run,
- on degradation symptoms (re-reading files, forgotten decisions, plan drift),
- any time before `/clear`.

`/handoff` accepts an optional argument for the in-flight section, e.g. `/handoff still chasing the 401 on the OIC connection test — token audience hypothesis`.

## Resume ritual — automatic, then verified

The **SessionStart hook** fires on `startup`, `resume`, `clear`, and `compact`, and injects into context: current branch, short status, recent log, worktree list, the repo's single `docs/epics/handoff.md` (plus the epic plan its `**Epic:**` field names), and — loudly — any `handoff-autosnapshot.md` left by a compaction or a dirty session end (which it then deletes, so warnings never go stale).

It then adds up to three one-line *queue* views, each emitted only when it has something to say — so a session that is simply resuming an epic sees none of them. The first two split the filed-but-not-running epics by which gate they are sitting behind; they share one blank line and render as a single two-line list:

- **Epics awaiting dispatch** — every filed plan at `**Status:** approved`, named in **folder-number order**, because Phase 1 numbers epic folders by implementation sequence: `- 2 epics awaiting dispatch: 05-<slug>, 06-<slug> — dispatch the lowest number first.` This is what makes planning several epics ahead visible: without it a fresh session can see the epic in flight and the newest plan, but not that a queue exists or in what order to take it.
- **Epics awaiting approval** — every filed plan at `**Status:** planning`, same ordering, different gate: ``- 1 epic awaiting approval: 07-<slug> — approve before dispatch; `planning` is never dispatchable.`` These are *proposals*, not work — Phase 1's approval has not happened. The split exists because unattended intake (`issue-intake.md`) opens PRs carrying plans at `planning`, so `planning` epics now arrive without a human having read them, and one line calling them "awaiting dispatch" would invite precisely the mistake the approval gate exists to prevent.

  Both are pure local filesystem work — no tracker call, no network, and no subprocess at all (the header parse, the bucketing and the ordering are shell builtins, so the pair adds ~1ms to session start). `closed` and `in flight …` plans appear in neither: the former is done, the latter is already surfaced by the handoff / newest-plan section above. A plan with an unparseable or missing `Status:` line is listed rather than hidden, so a malformed header never makes queued work invisible — and it is listed as **awaiting approval**, the bucket whose error is harmless, since an approved epic shown as needing approval costs one glance at the header while a `planning` epic shown as dispatchable costs the gate.

- **Open issues with no epic yet** — untriaged tracker items, `- Open issues with no epic yet (N): …`, best-effort and capped at ~2s; a missing `gh`, a non-GitHub remote, or a slow or unauthenticated tracker simply produces no line.

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
