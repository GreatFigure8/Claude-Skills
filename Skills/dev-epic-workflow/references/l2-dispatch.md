# L2 — dispatch to a pull request, and stop

How approved work reaches a pull request without a human, and where it stops.
Implemented by `assets/claude-config/bin/dispatch.sh`; called by
`assets/claude-config/bin/unattended-intake.sh`.

This is the third of three surfaces and the only one that acts:

| file | surface | asks |
|---|---|---|
| `references/autonomy-control-surface.md` | **permission** | what may the machine do? |
| `references/worktree-provisioning.md` | **capability** | can this checkout run its gates? |
| **this file** | **action** | it does it, once per cycle, and stops |

**The ceiling is one sentence: L2's ceiling is an OPEN PULL REQUEST.** The runner
never approves a plan, never merges a pull request, never closes an issue, and never
chains to a new one. Any commit that weakens that is a defect, not a feature.

## What one cycle does

Per configured repo, in order. Every step is a refusal point, and every refusal names
what is missing.

1. **Level.** Silently returns unless the repo resolves **L2**. Every repo with no
   autonomy configuration resolves L0, so this emits no line, makes no GitHub call and
   creates nothing. That silence *is* the inertness guarantee.
2. **Budget.** `budget.max-items` (default **1**) and `budget.max-wall-clock` (default
   60m), counted across the **whole cycle**, not per repo. One item at a time is an
   epic 11 invariant, so the counter lives with the library — which is sourced once per
   cycle — rather than being threaded through the runner where somebody would eventually
   reset it in the repo loop.
3. **The override, re-asked.** A human reaches for a kill switch *during* a cycle, not
   before one, so `AUTONOMY-OFF` is checked here as well as at resolution — and again
   immediately before the pull request is opened.
4. **The two signals, asked once.** The branch list and the pull request list of this
   repo. A failed query is a **refusal**, never a guess.
5. **Selection** — see below.
6. **Admission.** The repo's `require-labels` / `forbid-labels`, applied to the epic's
   **`Source:` issue**.
7. **The gate set.** Refused unless the repo declares `gates.<type>` in the provisioning
   file. See "L2 requires a declared gate set".
8. **Worktree and preflight.** Cut from the integration branch, then
   `provision_preflight` — copy, install, **smoke check**, clean tree. A failure here
   refuses the dispatch and leaves **nothing** behind: no worktree, no local branch, and
   nothing on origin, so a transient install failure does not permanently retire a work
   item.
9. **Push the branch.** See "The point of no retry".
10. **The executor.** `claude -p --agent work-item-executor --model sonnet`, with the item's brief and
    the declared gate set, under a timeout, with a heartbeat every five minutes.
11. **Push again, then judge.** Whatever it produced goes to origin before anything is
    decided about it.
12. **The denylist and the size ceiling, against the real diff.** See below.
13. **The pull request**, against the integration branch. **Then stop.**

## How "undispatched" is decided, and it is not by parsing prose

Every work item's plan entry carries a machine-readable line:

```markdown
### 3. L2 — dispatch to a pull request, and stop
- **Branch:** `feat/autonomy-l2-dispatch`
- **Depends on:** 1, 2, 2b
- **Gates:** unit          ← optional; see "The gate set"
```

> An item is dispatchable **iff** no branch of its name exists on `origin` **and** no
> open-or-merged pull request has it as head.

Both halves are needed. The branch alone misses an item whose branch was deleted after
its pull request merged; the pull request alone misses an item whose executor pushed and
then died. Together they are the two signals epic 09 items 7 and 8 already built and
measured, asked of GitHub rather than of a local checkout whose remote refs are only as
fresh as its last fetch.

A **closed-unmerged** pull request is deliberately not a signal: abandoned work is not
delivered work.

**The prose is never read for completion.** A real plan marks a finished item as
`### 1. The UI knows the template's family — DONE (PR #842)`. That title is kept
verbatim and never interpreted — there is a fixture whose whole job is to dispatch an
item titled `DONE (PR #842) — do not dispatch it`, because dispatchability is asked of
origin and of nothing else.

### What is parsed, and what is refused

Only the `## Work items` section is read, and it ends at the next `## ` heading. That is
not tidiness: measured on a real repo, plans carry `### Deferred`,
`### RED proof printed the defect verbatim` and `### What was submitted, and what it did
to DEV-1` as `###` headings in later sections, and a parser that read every `###` in the
file would treat them as work items.

| the plan says | the runner does |
|---|---|
| `**Status:** approved` or `in flight` | dispatchable |
| `**Status:** planning` | **never** — that is L1, and this epic does not build it |
| `**Status:** closed`, or unparseable | never |
| an item with **no** `- **Branch:**` line | **refuses**, names the item, and considers **no later item of that epic** |
| a `Branch:` value that is not a usable git branch name | **refuses** rather than sanitising it into something the plan did not say |

The state test reads the first **two** words of the `**Status:**` line, case-insensitively
— the same rule the control-plane hooks use, for the same reason: keying on the first word
alone truncates `in flight` to `in`, which is how `approved` and `in flight` were once
indistinguishable (GH #11).

**Refusing an item stops that epic rather than skipping to its next item.** Items are
sequenced; stepping over one whose branch cannot be read is how you dispatch item 3 while
item 2 is unaccounted for.

Two shapes in the wild currently take that path, both legitimately: an item marked
`### 3. CANCELLED — …` with no branch, and one whose branch field reads
`deferred to **epic 180 item 5**`. Both are refusals a human clears by editing the plan,
and neither is guessed at.

### Which epic

**In flight before approved, then numeric order within each.** Finishing an epic that is
already started before starting another is the most conservative reading of "serialized,
one item at a time", and it keeps a half-delivered epic from sitting behind a queue of
freshly approved ones.

The order is **numeric**, not lexical, and that matters on a real repo rather than in
principle: one configured repo has epics numbered past 190, where a lexical sort puts
`100` before `99` for the rest of the project's life.

The reserved intake tree cannot be reached from here — it is `.intake`, and the
`*/plan.md` glob does not match a leading dot. That is the same guarantee, by the same
mechanism, that keeps it from ever being selected as the active epic.

### A dependency must be MERGED, not merely dispatched

This is the difference between working on the first live cycle and producing a broken pull
request on the second. The runner opens a pull request and stops; a human merges it, at
whatever hour suits them. Ten minutes later the next cycle sees item 1's branch on origin,
calls it dispatched, and cuts item 2 from an integration branch that does **not** contain
item 1.

So a declared dependency must have a **merged** pull request. It is asked of the listing
already in hand, so it costs no extra query. `Depends on: none` is unconstrained, which is
what lets two genuinely parallel items proceed once their shared predecessor lands. A
dependency the plan does not contain, or one written **after** the item that needs it, is
a refusal — this file does not reason about out-of-order sequencing and says so rather
than picking whichever reading is convenient.

Two real `Depends on:` lines shaped the tokeniser, and both are quoted from live plans:

- `- **Depends on:** none (independent of 1 and 2)` — a first word of `none` means none,
  whatever follows. A tokeniser that scraped every number out of that line would make an
  explicitly independent item wait for two others forever.
- `- **Depends on:** 1 — the sample must show the *corrected* output` — the id list ends
  at the first token that is neither an item id nor a connector.

A mis-parse here can only cause a **refusal** — an item waiting for something it does not
need — never a dispatch that should not have happened.

## The denylist is checked against the diff, after the executor, before the PR

A work item's plan says what it intends to touch in **prose**. Prose is not
machine-readable — that is what epic 10 exists for — so a declaration-based check would be
checking the wrong thing with great confidence.

```bash
git -C "$WT" diff --name-only "origin/<integration>...HEAD" | autonomy_deny_diff_paths
```

That, plus `git diff --numstat` against `max-files` / `max-diff-lines`. A denied path
**refuses the pull request and does not delete the branch**: the work is on origin, the
refusal names the path *and* the pattern that caught it, and a human decides what it was.

## The point of no retry

The branch is pushed **before** the executor is started, at the integration branch's
commit. That is what makes the dispatchability rule answer honestly next cycle: an
executor that dies at its first tool call leaves a branch and a control-plane record
saying so, and the item is not silently re-dispatched every ten minutes forever — which is
the worst behaviour available to an unattended loop.

It is pushed **after** the provisioning preflight, deliberately, so that a failed smoke
check leaves nothing on origin and the item can be tried again once the environment is
fixed.

**An executor that returns `blocked` is recorded and the epic is left alone.** Never
retried: a block is by definition something the automation cannot resolve, and an
unattended retry loop on an ambiguous plan is the worst available behaviour. The branch
on origin is what makes "never retried" structural rather than remembered.

## What the executor is told, and what it cannot do

The contract is invoked **by name** — `claude -p --agent work-item-executor --model sonnet` — and is
never re-inlined or forked here. The brief is the per-item dispatch an orchestrator would
give in a session, plus the two places an unattended dispatch genuinely differs:

1. **It does not open the pull request.** The denylist has to sit between the work
   existing and the work being proposed, and this is the only place that fits. The
   executor stops at `gates-passed` and pushes; the runner opens the pull request if — and
   only if — admission passes.
2. **Its gates are declared, not inferred.**

**The ceiling is enforced by the allowlist, not by the prose.** The executor is invoked
with a wider allowlist than the drafter's — it writes code and runs tests, which is
exactly why this rung has its own admission policy rather than inheriting the drafter's —
and with **no `gh pr create`, no `gh pr merge`, no `gh pr edit`, no `gh issue close` and
no `gh issue edit`**. What is absent is the point: the ceiling holds even if every
sentence in the brief is ignored.

The gate commands' own leading words are added to the allowlist, derived from the repo's
provisioning declaration. That grants nothing new — `install`, `smoke` and every `gates.*`
value are already shell commands this machinery runs, and `worktree-provision.sh` guards
that file's ownership and mode for exactly that reason — and it keeps the two from
drifting apart, which is how an executor ends up unable to run the gate it was just told
is mandatory.

### The runner reads the executor's milestone, and refuses without one

`origin` outranks `status.json`, so the record is used for exactly two things: to notice
`blocked`, and to refuse a pull request for an item whose gates were never reported.

| the executor's last milestone | what happens |
|---|---|
| `gates-passed` or `pr-opened` | the diff is checked, and the pull request opens |
| `blocked` | recorded as blocked, epic left alone, never retried |
| anything else | refused, naming the milestone it actually reached |
| **no record at all** | **refused** |

That last row is deliberate. Item 2b names the worst available outcome of an unattended
dispatch: a run that decides the gates are unrunnable, reports them skipped, and opens the
pull request anyway. An executor that never wrote a milestone is indistinguishable from
that, so it does not get a pull request. The branch stands and a human looks.

## L2 requires a declared gate set

Measured on the first real dispatch: the repo-wide gate script covered **zero** TypeScript
and ran none of the tests that could catch a regression in the `.tsx` item under way. The
attended executor ran the right gates from repo precedent, which is judgement, and
judgement is what is absent here.

So a repo that declares no `gates.<type>` is **refused at L2**, naming the file and the key
to add. That is not an inconvenience: a gate that has never been shown to run is a hope.
L0 drafting is untouched by this — a repo with no provisioning section still drafts,
exactly as it does today.

An item may name its type with an optional `- **Gates:** <type>` line. Naming a type that
is not declared is refused, listing what *is* declared. Naming **no** type gets **every**
declared gate, in declaration order: over-running gates is safe, under-running them is the
thing that was measured.

## The pull request it opens

Against the **integration** branch, always. `Part of #<n>` exactly once, from the plan's
`Source:` header, and **never a closing keyword** — a closing keyword makes somebody
else's merge close an issue, and closing an issue is a thing this runner does not do, not
directly and not by leaving a fuse.

The body opens by saying a machine wrote it and no human has read the diff. Every claim in
it is evidence the runner actually has: the diffstat, the commit list, the denylist
result, the size against the ceiling, the smoke check, and the executor's own final
milestone verbatim. What it does not have, it says it does not have — the runner did not
re-run the gates and does not pretend to have their output.

## Watching it, and stopping it

Per dispatch, into the reserved intake tree `bin/intake-status.sh` owns:

```
<epics-dir>/.intake/status/dispatch-<branch-slug>.json
```

Named `dispatch-…` and not `<branch-slug>.json` deliberately: the **executor** writes its
own `<branch-slug>.json` into the **epic's** status tree. Those are two records about two
different things — what the executor believes and what the runner observed — and giving
them the same basename in two trees is an invitation to read one and think it is the
other.

States: `admitted` → `dispatching` → `pr-opened`, with `refused`, `blocked` and `failed`
as terminals. A heartbeat every five minutes moves `updated` while an executor runs,
because a quiet run and a dead one are not the same thing and 105 minutes were once spent
finding that out.

| to stop it | do this |
|---|---|
| revoke dispatch, keep drafting | `touch ~/.config/claude-intake/AUTONOMY-OFF` |
| stop the whole cycle, drafting included | `touch ~/.config/claude-intake/STOP` |
| revoke one repo | set its `level` to `L0` |
| permanently | revert the merge |

`AUTONOMY-OFF` is honoured **mid-flight**: if it appears while an executor is running, no
pull request is opened. The branch is pushed and complete either way, so nothing is lost —
open it by hand, or remove the file and re-dispatch.

## Reading it without a session

```bash
bin/dispatch.sh --check --repo <path> --slug <owner/name>
bin/dispatch.sh --plan <plan.md>
bin/dispatch.sh --select --repo <path> --slug <owner/name> --epics-dir <dir>
bin/dispatch.sh --deny --repo <path> --slug <o/n> --worktree <wt> --base <ref>
```

**Read-only in every mode.** There is deliberately no `--dispatch`: the one entry point
that runs an executor, pushes a branch or opens a pull request is `dispatch_repo`, and it
is reachable only from the runner, on a cycle that has already passed the stop file, the
lock, the credential check and the level resolution.

## Fixtures

`assets/claude-config/hooks/tests/l2-dispatch-fixtures.sh` — 231 cases.

**The repository is real, the world is not.** The sandbox holds an actual bare `origin`
and an actual clone, so `git worktree add`, `git push` and `git diff --name-only` are the
real commands answering about real commits — the denylist and the size ceiling are checked
against a diff git produced, not against a string the suite wrote. Only `gh` and `claude`
are stubs, and the `gh` stub answers the branch list **from** the bare repo so the fixture
cannot disagree with itself.

**Section K is the inertness proof, run twice.** The shipped runner against a
reconstruction of the pre-item-3 runner, built by deleting exactly the 56 lines this item
added and refusing to run if the count is wrong, compared byte for byte on an unconfigured
repo — log, stdout, stderr and the whole call stream, with the word "dispatch" absent from
the log entirely. That pair alone would pass on a runner that does nothing, so the same
pair runs again against a repo configured at L2, where the shipped runner must reach an
open pull request and the reconstruction must be blind to the idea.

**Section H is the invariant, as a fixture rather than a promise.** A completed cycle
leaves the pull request open, the issue open and nothing merged: the call stream of a
*successful* run is asserted to contain no `gh pr merge`, no `gh issue close`, no
`gh issue edit`, no `gh issue comment`, no `gh pr edit/review/close` and no push to the
integration branch, with `origin/<integration>` byte-identical to where it started and the
plan file untouched.

**Six mutants**, each a change somebody could make believing it harmless: an advisory
denylist, an assumed `gates-passed`, a disabled level gate, an accepted any-milestone, a
removed `blocked` branch, and a prose-driven selection.

The suite found two real defects in the library while it was being written, and both are
worth remembering:

- **A `$( )` around a function is a subshell, and every global it sets dies with it.**
  `DISPATCH_GATE_COMMANDS="$(provision_gates …)"` lost `PROVISION_REFUSAL`, so a refused
  gate lookup degraded to "none declared" — a silent refusal wearing a message.
  `bin/intake-status.sh` documents the identical hazard from the other direction.
- **The executor's run log was inside the working tree.** Written to
  `$WT/.dispatch-run.log` it is an untracked file in a checkout where an unattended
  executor is about to run `git add -A`, so the runner's own log lands in the executor's
  commit, in the diff the denylist checks, and in the pull request a human reviews. The
  fixture saw it as "2 file(s)" where the item touched one.

## What this rung deliberately does not do

- **L1 — approve and file a plan.** Still measured NO-GO (epic 08/09, never re-measured).
  A `planning` plan is never dispatchable, which is the mechanical form of that. The
  *mechanism* to grant L1 now exists (`autonomy_may_approve`, epic 19 item 2, see
  `references/autonomy-control-surface.md`), but nothing wires it to a granted repo here —
  `dispatch.sh` itself still refuses unless a repo resolves **exactly** `L2`, unchanged by
  that item, and no repo is granted L1 by epic 19 either (its own invariant).
- **L3 — merge on green.** L3 without L2's track record is an accelerator before brakes.
  `autonomy_may_merge` exists for the same reason as above; this file does not call it.
- **L4 — chain to the next item.** One item per cycle, and the cycle ends at the pull
  request. `autonomy_may_chain` exists for the same reason; this file does not call it.
- **Touch the tracker at all.** No label, no comment, no close. The `Part of #<n>` in the
  pull request body is what puts a cross-reference on the issue timeline, and GitHub does
  that without this runner writing anything.

**Why this file is unchanged by epic 19 item 2.** That item raises `autonomy.sh`'s ceiling
from L2 to L4 and adds `autonomy_may_approve` / `_merge` / `_chain` — the *permission*
surface. Whether *this* file, `dispatch.sh`, ever consults them is a separate decision the
epic 19 invariant reserves for later items (4–6): "`dispatch.sh`... contracts stay
stable — this epic wraps them, it does not edit their internals." So `DISPATCH_LEVEL=L2`
above is still an **exact** match, not a floor — a repo resolving L3 or L4 is, as far as
this file is concerned, indistinguishable from one resolving L1 or L0: dispatch still
silently returns.
