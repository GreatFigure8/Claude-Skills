# Issue Intake — trackers in, epics out

How work enters the epic workflow from an issue tracker, in both directions:

- **Pickup** — Jonathan reports an issue/work item in GitHub or Azure DevOps (or points at
  an existing one), and the process turns it into a filed epic with work items, linked back.
- **Report** — Jonathan describes a problem in a Claude Code session; Claude creates the
  issue/work item in the proper tracker *first*, then runs the same pickup path.

Either way the invariant is the same: **the tracker is the system of record for "what and
why"; the epic folder is the system of record for "how and status of execution."** Every
epic born from intake carries its tracker ref, and the tracker item always links to its
epic. No orphans in either direction.

## Entry points (all equivalent — description first, command never a prerequisite)

1. **Natural language, no command** — "bug: …", "issue: …", "file this as a work item",
   "pick up issue 123", a pasted URL. This is the normal path; the phrasing itself
   triggers intake.
2. **`/intake <argument>`** — the argument carries the whole input: a ref/URL routes to
   Pickup, free text routes to Report. Same outcome as (1), just a deterministic trigger.
3. **`/intake` (empty)** — the backlog view: list open items, propose a pickup order,
   ask which to take. This is the only command-first case, and it is not a step before
   describing a new problem — a new problem described in the reply simply routes to
   Report as usual.

Never require the command before the description, and never ask Jonathan to re-state a
problem he already described just to fit an entry point — classify what was said and run.

## Detecting the tracker

Decide per repo, from the origin remote — never by asking when it's inferable:

```bash
git remote get-url origin
#   github.com/...                          → GitHub  (gh CLI)
#   dev.azure.com/... | *.visualstudio.com  → Azure DevOps (az boards)
```

A repo with both remotes, or work tracked in a different tracker than the code host,
is a one-time question — record the answer in the repo's `CLAUDE.md` as
`Tracker: github | azdo (<org>/<project>)` and never ask again.

**Prerequisites (verify before first use, per machine):**

- GitHub: `gh auth status` — if unauthenticated, `gh auth login`.
- Azure DevOps: `az extension add --name azure-devops` (once), then either
  `az devops configure --defaults organization=https://dev.azure.com/<org> project=<project>`
  or the `AZURE_DEVOPS_EXT_PAT` env var. Verify with `az boards query --wiql "SELECT [System.Id] FROM WorkItems" --top 1`.

When Claude has shell access, Claude runs these checks itself and reports what's missing
rather than describing the setup.

## The linking contract

| Epic artifact | Tracker artifact | Link mechanism |
|---|---|---|
| Epic (`docs/epics/<NN>-<slug>/`) | One source item: GH Issue, or ADO Epic/Feature/User Story/Bug | Plan header carries `Source: GH #<n>` or `Source: AB#<n>`; tracker item gets a comment with the epic path and plan permalink |
| Work item in `plan.md` | GH: checklist line on the source issue. ADO: child **Task** under the source item | Checklist/Task title = `<item NN>: <name> (<branch>)` |
| Work-item PR | Same source item | GH: `Part of #<n>` in the PR body — `Closes #<n>` **only** on the epic's final work item. ADO: `AB#<n>` in the PR description (auto-links; add the Task's `AB#` too if child Tasks exist) |
| Epic status | Tracker state | See status mapping below |

The `Source:` line lives at the top of `plan.md`, right under the title — it's what lets
any future session (or the `/intake` command) find its way back to the tracker without
being told.

**Status mapping** (applied at the phase boundaries, by whoever crosses them):

| Epic moment | GitHub | Azure DevOps |
|---|---|---|
| Plan filed (Phase 1 approval) | label `epic:planned`, comment with plan link | state → `Active` (or `Committed`), comment with plan link |
| First dispatch (Phase 3) | label `epic:in-progress` (replace `epic:planned`) | child Task → `Active` as each item dispatches |
| Item merged (Phase 3 step 10) | tick the item's checklist line | child Task → `Closed` |
| Epic closed (Phase 5) | comment with retro summary; `Closes #<n>` on final PR closes the issue | source item → `Resolved`/`Closed`, comment with retro summary |
| Item blocked | comment quoting the `blocked` detail from `status.json` | comment on Task; Task → `New` with the question in the comment |

**The two `epic:` labels are read, not just written.** Until 2026-08-21 this table was a
documented hope: nothing applied the labels and nothing checked them, and the unattended
runner — the one consumer with an obvious use for them — read no label but its own
`claude-intake` trigger. It now reads them as the **highest-authority** signal in its
work-in-progress check, ahead of everything it infers from pull requests and branch
names, and short-circuits on them: a labelled issue is skipped without a single GitHub
query being made about it. So the label is now load-bearing in both directions:

- **Applying it protects the epic.** An issue carrying `epic:planned` or
  `epic:in-progress` cannot be drafted over, including the case no inferred signal can
  see — a plan filed by direct commit to the integration branch, which leaves no PR
  saying `Part of #<n>` and no branch named for the issue.
- **Omitting it does not break anything, and that is the trap.** The inferred signals
  still catch most cases, so a missing label costs API calls and silence rather than a
  visible failure. `claude-skills` GH #39 went through six merged work items of its own
  epic with no label at all while LODE was 8 of 8 correct. The SessionStart injection
  now names any in-flight epic whose source issue is unlabelled, because a gap that only
  shows up as a collision months later is not a gap anybody fixes.

Keep tracker comments terse and factual — one or two lines plus a link. The narrative
lives in the plan and the PRs.

## Direction 1 — Pickup (tracker item exists, or Jonathan names one)

Triggers: "pick up issue 123", "work item 4567", "grab the bug about X", a pasted
issue/work-item URL, or the `/intake <ref>` command.

1. **Fetch the item** — the full body, not the title:
   ```bash
   gh issue view <n> --json number,title,body,labels,comments,url
   az boards work-item show --id <n> --output json
   ```
   Comments count as requirements context — read them.
2. **Phase 0 as normal** — ground against the actual repo. The issue says what hurts;
   the repo says what's true. Discrepancies between the two go into the plan's Open
   questions, and material ones go back to the tracker as a comment.
3. **Phase 1 as normal** — draft the plan with `Source: <ref>` in the header and the
   issue's acceptance criteria (or its closest approximation) reflected in the work
   items' definitions of done. Present for approval; on approval, file it.
4. **Link back** (same turn as filing):
   - GH: `gh issue comment <n> --body "Epic filed: docs/epics/<NN>-<slug>/plan.md — <permalink>"`,
     `gh issue edit <n> --add-label epic:planned`, and edit the issue body (or add a
     comment) with the work-item checklist.
   - ADO: `az boards work-item update --id <n> --state Active --discussion "Epic filed: …"`,
     then one `az boards work-item create --type Task --title "<item NN>: <name> (<branch>)"`
     per work item, each related to the source item
     (`az boards work-item relation add --id <task> --relation-type parent --target-id <n>`).
5. **Hand to Phase 3** — the orchestrator dispatches the first executor. Intake ends here;
   everything downstream is the existing workflow, plus the status-mapping touches above.

**Scale to the issue.** A one-line bug whose fix is one work item still gets the full
shape — plan, branch, PR — but the plan is proportionally small: outcome, one item, one
risk line. The intake path must not make small fixes heavier than Phase 1 already does.

## Direction 2 — Report (the problem arrives in conversation first)

Triggers: "issue:", "bug:", "file this as a work item", "we should track this", a
described defect or feature with no tracker ref, or `/intake <description>`.

1. **Create the tracker item first** — the tracker is the system of record, so it exists
   before any planning:
   ```bash
   gh issue create --title "<imperative summary>" --body "<structured body>"
   az boards work-item create --type "User Story" --title "…" --description "…"   # Bug for defects
   ```
   Write the body the way a good report reads: observed behavior, expected behavior,
   evidence (error text, file/line, repro), and any constraint Jonathan stated. Facts he
   gave, not invented detail — thin is fine; wrong is not.
2. **Confirm the ref back** in one line ("Filed as GH #124 / AB#4571"), then run
   **Direction 1 from step 2** with the new ref.

If Jonathan reports something mid-epic that belongs to the *current* epic, it isn't
intake — it's Phase 3's scope rule (split/defer) plus, when worth tracking, a checklist
line or child Task on the existing source item. Intake creates epics; it doesn't fork
one epic per stray thought.

## Batch intake

"Pick up my open issues" / "what's in the backlog":

```bash
gh issue list --state open --json number,title,labels --limit 50
az boards query --wiql "SELECT [System.Id],[System.Title],[System.State] FROM WorkItems WHERE [System.TeamProject]=@project AND [System.State]<>'Closed'"
```

Present the list with a recommended pickup order (dependencies and blast radius, not
recency), let Jonathan choose, then run pickup per item chosen. One tracker item = one
epic; genuinely-coupled items merge into one epic whose plan header lists every source
ref, and each source item gets the link-back.

## Unattended intake — the `claude-intake` label

Everything above assumes Jonathan is in the session. **Unattended intake** is the same
Pickup path run headlessly when nobody is present, and it stops one step short of
everything above: it produces a **proposal**, never a filed, approved epic.

This contract is deliberately **mechanism-agnostic**. It constrains what an unattended run
may do, not what runs it: a scheduled runner on Jonathan's machine, a CI job, or a manual
headless invocation are bound by the same trigger, the same artifacts, and the same hard
stops. Choosing and building the mechanism is a separate concern; violating any line below
is not open to it.

**Trigger — opt-in, and nothing else.** Applying the `claude-intake` label to a GitHub
issue. No label, no run; there is no "all new issues", and no inference from title or
content. Whatever *wakes* the runner — a timer, a poll, a manual start — the label is the
only thing that *selects* an issue, so an unlabelled issue is never processed. Removing the
label after a run is what stops it recurring. A single named issue may be processed
on demand to exercise the mechanism itself — same contract, same stops.

**What it does.** Exactly two phases of the workflow, in order:

- **Phase 0 — grounding.** Fetch the issue with its comments, then read the *repo*: tree,
  the modules the issue implicates, existing epics, CI config, `git log`/`git branch -a`.
  The issue says what hurts; the repo says what's true. Unverifiable claims become **Open
  questions** in the draft, never silent assumptions — an unattended run has nobody to ask,
  so its honesty about what it could not check is the only thing standing in for judgement.
- **Phase 1 — drafting.** Write the plan per `references/plan-template.md`, with
  `Source: GH #<n>` in the header and the issue's acceptance criteria reflected in the work
  items' definitions of done. Then **stop.**

**What it produces.** One branch and one pull request, plus one tracker comment:

| Artifact | Content |
|---|---|
| Branch | `docs/intake-<NN>-<slug>` — the `docs` type of `references/git-conventions.md`, cut from the integration branch |
| Commit | `docs/epics/<NN>-<slug>/plan.md` at `**Status:** planning` — and nothing else |
| PR | Against the integration branch, body per `references/pr-template.md`, carrying `Part of #<n>` — never `Closes #<n>`, because an unattended run cannot know it is anyone's final item. Its title and body state the proposal's `Recommendation:` (below) |
| Tracker comment | The standard link-back on the source issue: the epic path and the PR URL, one or two lines |

The PR body also states, in its own words, the two things a reviewer needs to know that
aren't visible in the diff: that the plan is **unapproved**, and how the epic number was
chosen (below).

**Outcomes — what a proposal may recommend.** Not every issue deserves an epic, and a
drafter that must produce an approvable plan will produce one whether or not the work exists.
So the plan header of an unattended proposal carries one more field, directly under
`**Status:**`, with a **closed vocabulary of exactly three values**:

| `**Recommendation:**` | Means | What the plan body must carry |
|---|---|---|
| `plan` | There is real work here. Today's behaviour, and the default | A normal epic plan |
| `no-work` | Nothing for an approved epic to dispatch — already fixed, already in flight, a duplicate, or invalid as reported | The evidence that makes it so, **named**: the PR, commit, issue or code |
| `needs-decision` | A real choice a human must make before any plan is worth writing | The choice, the options, and each option's trade-off — left **unresolved**, with no default quietly picked |

`no-work` and `needs-decision` are **correct, preferred outputs** when they fit. They are not
failures, and not a fallback for a hard brief: a plan the drafter would not defend is worse
than an honest `no-work`, and inventing work in order to have something to draft is the worst
outcome available to it. They are equally not an escape hatch — an under-specified brief that
still has obvious real work is a `plan` with **Open questions**, not a `needs-decision`.

**Every outcome has the same shape.** All three produce a branch, a `plan.md` at
`**Status:** planning`, a PR, and a tracker comment. A `no-work` proposal opens a PR too: the
artifact *is* the evidence, and a PR is trivial to close, whereas a bare issue comment would
be lighter but would break the one-shape-for-every-outcome property and leave nothing
version-controlled to read six months later. The PR title carries the recommendation as a
leading tag — `intake: [no-work] proposed epic for #<n> — <slug>` — and so does the issue
comment. A `plan` proposal's title, body and comment are unchanged.

**Reading the field.** Absent means `plan`: proposals drafted before the field existed stay
valid, and the field is purely additive. Present but outside the vocabulary is **not** read as
`plan` — a malformed terminal outcome is precisely the case a human should look at, so it is
logged verbatim and treated as `needs-decision`. Matching is case-insensitive and ignores
anything after the value, so `no-work (duplicate of #758)` is `no-work`.

**Admission can downgrade a recommendation, and it is the only thing that may.**
After the plan is drafted and **before** its PR is opened, the runner compares the
files and modules the fresh proposal declares it will touch against those declared by
every other **open** proposal in the same repository. On overlap it rewrites that
proposal's own `**Recommendation:**` from `plan` to `needs-decision`, names the
counterpart proposal and the shared paths in the plan body and in the PR, and comments
on both issues. The drafter is not consulted and does not need to have noticed.

This is **not a fourth outcome** — the vocabulary above stays closed at three. A genuine
file collision *is* a real choice a human must make before either plan is worth
approving, which is what `needs-decision` already means. The downgrade is written into
the **plan file**, not only into the PR, because `session-start-context.sh` buckets a
proposal by reading `**Recommendation:**` out of the plan header: a proposal left at
`plan` keeps rendering under *awaiting approval*, where it can be approved without the
collision ever being registered.

**What it never does.** It does not resolve the collision, order the two epics, or close
either as superseded — that is precisely the decision being routed. The counterpart
proposal is annotated **by a comment on its issue** and is never rewritten: its pull
request is open and someone may be reading it.

**How a declaration is read**, because this is a trade-off and not a detail:

- **`**Scope:**` blocks only.** `**Not in scope:**` is the opposite of a declaration —
  "the tempting adjacent thing this deliberately skips" — and reading it manufactures a
  false positive on the first real pair available.
- **Paths match on suffixes at path-component boundaries.** One plan writing
  `Skills/…/hooks/tests/x.sh` and another writing `hooks/tests/x.sh` are naming one
  file; exact-string matching misses the pair, and basename-only matching collides
  everything.
- **Recall is preferred to precision, deliberately.** Every path-like token in a Scope
  block counts, including one a plan mentions only as a file it reads. The alternative —
  reading only the token that leads a bullet — was measured against the live proposals
  and loses a real collision, because declarations wrap across lines. So a reported path
  may be one side only reads; read both Scope blocks before concluding there is no
  conflict.
- **Three structural tokens never collide anything:** `plan.md`, `status/` and
  `docs/epics/`. They are the shape of a plan rather than the subject of one, they
  appear in live Scope blocks, and under suffix matching they would otherwise collide
  every proposal with every other, forever.
- **Only a `plan` is checked.** A `no-work` proposal proposes no edits and usually
  carries no Scope block at all; running the rule over it would turn every honest
  `no-work` into a `needs-decision`. A draft that already says `needs-decision` is
  already where a collision would put it.
- **An empty declaration is colliding-unknown**, not "no overlap". A `plan` whose Scope
  names no file at all returns `needs-decision` with that stated as the reason, rather
  than passing silently.
- **A failed query publishes anyway, loudly.** If the open-proposal enumeration itself
  fails, the proposal is published unchecked and the runner logs that it was — the same
  rule the work-in-progress check uses. A GitHub blip must not stop a runner that worked
  yesterday.
- **Only `intake/proposed-*` branches are enumerated.** An attended proposal on
  `docs/intake-<NN>-<slug>` is invisible to this check. That gap is real and small, and
  it is recorded rather than papered over.

**The long-run answer is a structured field, not a better parser.** `references/plan-template.md`
now defines exactly that: a per-work-item `**Touches:**` block, one repo-root-relative path
per line, declarations only. The unattended drafter now emits it (epic 10 item 2), but
nothing reads it here yet — this collision check still parses `**Scope:**` prose, by design
until the field has a consumer too (epic 10 item 4). Once it does, a machine-readable
declaration replaces this heuristic outright rather than refining it.

**Routing is a human's job — and this is the contract that says so.** Nothing acts on a
recommendation today: the runner does not approve a `plan`, does not close a `no-work`, and
does not escalate a `needs-decision`. It states the outcome in the PR, in the issue comment,
and in its log, and stops. Any consumer built later — an autonomous rung above L0 especially —
inherits these obligations verbatim:

- A `no-work` or `needs-decision` proposal is **never** dispatched, and never approved
  automatically. It is routed to a human, and that human's decision is the next event.
- A `needs-decision` proposal's stated choice is **never** resolved by the machine, not even
  by taking the option the plan happens to list first.
- A `no-work` proposal is **never** auto-closed. "Nothing to do here" is a claim a human
  checks; the run's evidence is an argument, not a verdict.

Nothing enforces those three lines today. They are written down here so that whatever
consumes the outcome is built against them, and so that a consumer which violates one is
violating a stated contract rather than improvising a missing one.

**The hard stops.** These are stops, not defaults — there is no flag, label, or issue body
that turns any of them off. They are the stops of the **drafting** cycle, which is what
this file describes and what runs on every repo including unconfigured ones. Since epic 11
item 3 the same process also carries a **dispatch** pass, which is a separate path with its
own stops, its own admission policy, and its own ceiling: `references/l2-dispatch.md`. It
is unreachable below L2, so on an unconfigured repo the list below is the whole of what the
process can do.

- It **never approves.** `**Status:** planning` is the only status it may write.
- It **never dispatches an executor.** Not for item 1, not for a "trivial" item. (Dispatch
  is L2's job, from an epic a human has *already* approved — never from a proposal this
  path drafted, because a `planning` plan is not dispatchable at any rung.)
- It **never writes code.** Its diff touches `docs/epics/<NN>-<slug>/` and nothing else.
- It **never merges** — not the PR it opened, not anything else. It never pushes to the
  integration branch.
- It **never closes an issue**, and never applies `epic:planned` / `epic:in-progress`. Those
  are Phase 1-approval and Phase 3-dispatch touches; the label the run *does* manage is
  removing its own `claude-intake` trigger. It **reads** the two `epic:` labels — that is
  the work-in-progress check's first signal — and reading is the whole of its involvement:
  the runner can never label an issue into being skipped, so it can never block itself.

Approval remains exactly where it was: Jonathan reads the PR the way he reads any PR. The
epic becomes real when he merges it **and** sets `**Status:** approved`; until that edit
lands, the plan is a draft that happens to be version-controlled. A `planning` plan is
**never dispatchable** — the SessionStart injection lists it under *awaiting approval*,
deliberately not *awaiting dispatch*, so the distinction survives a fresh context. A proposal
recommending `no-work` or `needs-decision` gets its own line there instead — *recommending no
work* / *awaiting a decision* — because what it needs from a reader is not approval.

**Numbering — there isn't any.** An unattended run claims **no epic number at all**. Phase 1
assigns the number *at approval*, and a runner reserving one early both contradicted that rule
and collided whenever two issues were labelled before either proposal merged. Proposals are
named for their issue, which is already unique:

```
docs/epics/proposed-<issue>-<slug>/plan.md      on branch  intake/proposed-<issue>-<slug>
```

Approving is what assigns the number: rename `proposed-<issue>-<slug>` to `<NN>-<slug>` and set
`Status: approved`. Nothing points at the number beforehand — no branch, no status file, no
tracker item — so the rename is a `git mv` and a header edit. The `proposed-` prefix also makes
an unapproved draft obvious in a folder listing, which reinforces the same gate the
`Status: planning` header enforces.

**Repos — opt in by listing.** The runner reads `~/.config/claude-intake/repos`, one entry per
line (`#` comments and blank lines ignored):

```
/Users/you/Source/some-repo              # proposals target the GitHub default branch
/Users/you/Source/other-repo|dev         # proposals target dev instead
```

An entry is an absolute path, optionally followed by `|<base-branch>`. The separator is a pipe
rather than whitespace because checkout paths contain spaces. **The base is the repo's
*integration* branch, which is not necessarily its GitHub default** — a repo can default to
`main` while work actually integrates on `dev`. Without an override the GitHub default is used;
a base that does not exist on `origin` causes that repo to be skipped with a logged reason
rather than a failed run.

**Header facts are supplied, never recalled.** Both branch fields of the plan header are
resolved by the runner — from the repos list and from `gh repo view --json defaultBranchRef` —
and injected into the drafter's prompt as stated facts it must copy verbatim:
`**Live branch:**` is the GitHub default branch, `**Integration branch:**` is the base above,
and the epics directory is the one the repo actually uses. The default-branch query runs
**unconditionally**, including for repos that override their base: it used to be the fallback
*inside* the no-override branch, so the repos most likely to have live ≠ integration were the
only ones whose live branch was never resolved at all. That is not a hypothetical — two of
seven unattended proposals declared the integration branch as the live one, on the field the
"never write to the live branch" rule is stated in terms of. Where a value cannot be resolved
the drafter is handed `unknown` and told to write `unknown`: a gap a reader closes in seconds
beats a plausible wrong branch that reads as correct and gets approved. `**Pre-epic tag:**` is
deliberately *not* supplied — it is a judgement, and it stays the drafter's to propose.

**The runner never touches your checkout.** It does not `switch`, does not `pull`, and does not
care which branch you are standing on: it fetches, then cuts its worktree from
`origin/<base>`. It runs unattended on a timer, so it could otherwise have moved you off your
working branch mid-edit (GH #27). A repo joins the poller by being listed,
never by existing on disk — the same opt-in principle the `claude-intake` label applies at the
issue level. A missing or empty list falls back to a single configured repo. Each listed repo is
processed in full isolation, with its own label check, issue list, epic folder, and worktrees;
one repo failing is logged and skipped and never stops the others. A single lock covers the
whole run, so two repos are never processed concurrently.

**Watching it, without knowing it is there.** The runner reports every cycle and every
issue into the repo's own control plane — a reserved `<epics-dir>/.intake/status/` tree,
resolved at the canonical repo root exactly as the executor hooks resolve theirs — and
`session-start-context.sh` surfaces a cycle **in flight** to any session that opens: which
issue is drafting, how many are done and queued, and where to `tail` it. Nothing has to be
armed by hand. The flat `intake.log` remains as the audit trail underneath and now names
the resolved control plane once per repo, so tailing it still tells you where to look
instead. The reserved tree begins with a dot and holds no `plan.md`, so no resolver can
mistake it for an epic. Full design, and what each way of killing a cycle records, in
`references/executor-control-plane.md` — "The unattended intake control plane".

**Failure behaviour.** A run that fails part-way leaves no half-filed epic on the
integration branch — the branch and PR are the unit, so an incomplete run is a branch
nobody merges. The failure is reported as a comment on the issue, and the trigger label
stays off so a failing run cannot loop.

## Failure modes this section exists to prevent

- **Two systems of record.** The plan drifting from the issue, or the issue silently
  amended without the plan noticing. The `Source:` ref plus the status-mapping touches
  are the contract; when the issue changes materially mid-epic, that's a plan revision
  (Phase 1 re-approval), not a quiet accommodation.
- **Untracked work.** Anything reported in conversation that lands as commits must have
  a tracker ref by the time its PR opens — the PR-body link is the enforcement point.
- **Tracker spam.** One comment per phase boundary, not per commit; the commit stream
  and `status/` already carry the fine grain.
