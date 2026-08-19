# Epic: session-start backlog check

**Status:** closed
**Source:** GH #1
**Live branch:** main   **Integration branch:** main   **Pre-epic tag:** n/a

## Outcome
Starting a session in a GitHub repo surfaces open issues that have no epic yet, as one
line inside the existing dev-epic-workflow grounding injection — so untriaged work is
visible without anyone running `gh issue list` by hand. When the tracker is unreachable,
unauthenticated, absent, or the repo isn't on GitHub, the line simply doesn't appear and
the git grounding renders exactly as it does today.

## Grounding
- **Verified:** `session-start-context.sh` (repo copy, 96 lines) injects git state,
  autosnapshot, and handoff/plan sections; guards on `git rev-parse`; `exit 0` always;
  parses hook JSON via jq with a python3 fallback.
- **Verified:** `gh` authed as `jstevenson81` (scopes `repo`, `workflow`); this repo is
  private with issues enabled; `gh issue list` returns in ~0.4s warm.
- **Verified:** `timeout` AND `gtimeout` are both absent on this machine.
- **Verified:** `/bin/bash` is 3.2.57 — no `wait -n`, no bash-4 syntax.
- **Verified:** in a repo with no remote, `gh issue list` prints "no git remotes found"
  and must be silenced explicitly.
- **Verified:** `shellcheck` and `bats` are not installed; `stack-gates.md` has no
  shell section.
- **Assumed:** the epic↔issue link is discoverable via `Source: GH #<n>` in
  `docs/epics/*/plan.md` (per the linking contract) — no epic exists yet to confirm
  against, so item 1's own filed plan is the first real test of the correlation.

## Invariants
- The hook exits 0 on every path. A tracker failure never fails a session start.
- Existing git/autosnapshot/handoff output is byte-identical when the tracker query is
  skipped or fails.
- No new hard dependency: correct behaviour with `gh` absent, `jq` absent, `python3`
  absent, network absent.
- Runs under bash 3.2.
- No credential material read, written, or logged.

## Work items

### 1. Backlog query in the session-start hook
- **Branch:** `feat/session-start-backlog-check-hook`
- **Depends on:** none
- **Scope:** `Skills/dev-epic-workflow/assets/claude-config/hooks/session-start-context.sh`.
  Add a final section that (a) returns immediately unless `gh` is on PATH and the repo has
  a GitHub remote, (b) runs `gh issue list --state open --json number,title,labels` under a
  portable ~2s cap (background the call, poll, kill on expiry — no `timeout` binary), (c)
  excludes any issue that already has an epic: referenced by `Source: GH #<n>` in
  `docs/epics/*/plan.md`, or carrying an `epic:planned` / `epic:in-progress` label, (d)
  emits one line naming up to 5 issues plus a count when more, and nothing at all when the
  set is empty or anything failed.
- **Not in scope:** Azure DevOps intake (the same hook will eventually want `az boards`);
  adding a shell gate to `stack-gates.md`; changing any other hook; caching results
  between sessions.
- **Definition of done:**
  - In this repo with #1 open and no epic filed → the line names #1.
  - After this epic's own plan is filed with `Source: GH #1` → #1 no longer appears.
  - In a repo with no GitHub remote → no backlog output, git block intact, exit 0.
  - With `gh` removed from PATH → same as above.
  - With a stubbed `gh` that sleeps 30s → hook still returns in under ~3s wall.
  - Executes under `/bin/bash` 3.2 with no syntax errors.
- **Verification:** run the hook directly with simulated stdin and paste output for each
  of the six conditions above; `bash -n` for the 3.2 parse check; `time` for the cap; then
  `install.sh --user` and `diff` the installed copy against the repo copy.
- **Rollback:** revert the merge commit. The hook is self-contained and its failure mode
  is silence, so a bad revert degrades to today's behaviour.

## Sequence
Single item. Nothing to serialise.

## Risks
| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| Portable timeout pattern misbehaves under bash 3.2 (orphaned subshell, zombie) | Medium | Session start hangs — worst failure available here | Explicit stub test with a 30s `gh`; assert wall time; kill the watcher on the success path |
| Network call now fires on every start incl. `compact` | High (by design) | Latency on every session | 2s hard cap; silent failure; measured warm cost ~0.4s |
| Correlation misses an epic and nags about a picked-up issue | Medium | Noise, not damage | Two independent signals (plan `Source:` line + tracker label); DoD tests the transition |
| Hook is user-level, so it runs in every repo on the machine | Certain | Wrong-repo output or stderr noise | Hard guard on GitHub remote before any `gh` call; all stderr silenced |

## Deferred / out of scope
- Add a shell/hook section to `references/stack-gates.md` (`bash -n`, `shellcheck` when
  present, the stdin-simulation harness). Discovered during Phase 0: this repo's primary
  artifact is shell, and the gates file covers none of it.
- Azure DevOps equivalent of the backlog query (`az boards`).
- Roadmap Tier 2 — unattended intake via CI on `claude-intake`.
- **GH #2** — `cancel-gate.sh` cannot distinguish orchestrator tool calls from executor
  ones (marker-existence test only), so a cancel sentinel would deny the orchestrator too and
  block its own `rm` of the sentinel. Found during item 1's dispatch; filed separately.

- Timeout kill covers the query and children present at kill time; a grandchild spawned
  after that snapshot would survive. Theoretical for real `gh` (single process); a proper
  fix needs `set -m` plus process-group kill, at the cost of job-control chatter on stderr.
- **GH #5** — `subagent-lifecycle.sh` stamps `terminal:true` from any agent's stop, and
  splits the START/STOP bracket pair across two log files. Found in Phase 4 verification.

## Log
- 2026-08-19 — epic drafted from GH #1; Phase 0 grounding recorded above.
- 2026-08-19 — item 1 dispatched (agent a6ab485e4e0012f06). Known-unknown #1 RESOLVED: the
  `SUBAGENT START` bracket and the `subagent-active-*` marker both appeared, so
  `subagent-lifecycle.sh` reads `agent_id` correctly and the gate arms. Tool logger confirmed
  writing live telemetry. Separately surfaced GH #2 (see Deferred).
- 2026-08-19 — item 1 merged as PR #4 (merge commit 836a603). Verified cold: all six DoD
  conditions re-run with an independent harness, plus a sandbox control proving the
  `Source: GH #<n>` correlation works without the label signal. Branch deleted with `-d`;
  installed hook md5-identical to the merged copy.

## Retro

**Nothing split, nothing re-scoped.** The single item landed as planned: 82 insertions in
one file, no scope creep. The sizing heuristic held.

**What the epic actually bought.** The feature works — session start now names open issues
with no epic. But the run's larger value was as the control plane's first integration test,
and it found three defects that no amount of desk-checking had surfaced:

- **GH #2** — the cancel gate cannot distinguish orchestrator calls from executor calls, so
  a cancel sentinel would deadlock the orchestrator's own cleanup.
- **GH #3** — orchestrator and executor share one working tree, which silently diverted an
  orchestrator commit onto the item branch and let `git push origin main` report success
  while landing nothing.
- **GH #5** — any agent's stop stamps the in-flight item `terminal:true`, which can satisfy
  half the Layer 3 "done" rule mid-run.

**Two root causes, not one.** #2 and #5 are the same fault wearing different clothes — **the
hooks cannot attribute an event to the agent that caused it** — and they are one fix. #3 is a
different fault: **shared mutable state**, one working tree owned by two agents at once.
Per-call attribution would not have prevented it; only isolating the executor's checkout does.
Both are the thing to fix next, as one epic with two distinct remedies.

**What surprised us.** Known-unknown #1 was a false alarm — `agent_id` was read correctly on
the first dispatch. The real risks were the ones nobody had written down.

**The verification rule earned its keep, against the orchestrator.** The `git push origin main`
that landed nothing was the orchestrator's own bad claim, caught only by checking `git log main`
rather than trusting a zero exit code. Failure mode #3 is not something executors do to
orchestrators; it is something anyone does to themselves.

**Deliberately not done.** No release tag: this repo ships skill content, not a versioned
artifact, and `pre-epic` tagging was already judged n/a at Phase 2.
