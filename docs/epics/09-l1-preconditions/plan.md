# Epic: L1 preconditions — make the machine able to receive what good drafting produces

**Status:** in flight (items 1 and 3 of 5, parallel)
**Source:** GH #39 (continues epic 08, which stopped at its item 1 on a NO-GO verdict)
**Live branch:** per-repo (`main` here, `main` for LODE)   **Integration branch:** per-repo (`main` here, `dev` for LODE)   **Pre-epic tag:** n/a — no autonomy rung is enabled by this epic

## Outcome

The four defects named by epic 08's no-go verdict are fixed at their source, and the
measurement that verdict lacked is actually taken. When this epic is done, the unattended
drafter can emit "there is no work here" and "a human must decide this" as **first-class,
routable outcomes** rather than being forced to produce an approvable plan; its header
metadata is read from repo config instead of recalled; it refuses to draft work that has
already been done or is already in flight; and admission — not drafter goodwill — detects two
proposals that would edit the same lines. Then L1 is re-measured against **at least five
genuinely under-specified briefs**, and a new go/no-go is issued on that evidence.

This epic enables **no autonomy rung**. Everything here still runs at L0: draft, open a PR,
stop. What changes is that the thing L1 would consume becomes well-formed enough to be worth
consuming — and that we find out whether it is.

## Grounding

Verified against the repo and both trackers on 2026-08-20, not recalled:

- **Verified — the verdict and its reasoning.** `docs/epics/08-autonomous-mode/draft-quality-reviews.md`
  scores nine drafts against `draft-quality-rubric.md` and returns **NO-GO on L1** at effective
  n=7. Its "What would change the verdict" section names four remediations; items 1–4 below are
  those four, and item 5 is its measurement demand.
- **Verified — the header defect is real and is 2 of 7.** LODE #741 and #739 both declare
  `**Live branch:** dev` where live is `main` and `dev` is integration. Read from each PR's merge
  commit (`3fae7e32`, `03caa6d5`) because the head branches were deleted on merge.
- **Verified — the two header facts are already within the runner's reach, and it says so itself.**
  `unattended-intake.sh:183-192` carries the comment *"Default branch and INTEGRATION branch are
  not the same thing — this repo integrates on main, LODE integrates on dev"*, and line 190 fetches
  `defaultBranchRef` — the **live** branch — but **only as a fallback** when the `repos` line
  carries no `|base` override. LODE has an override (`|dev`), so on LODE the live branch is never
  resolved at all. Item 2 is therefore one unconditional `gh repo view` call plus passing two
  values the script already reasons about into a prompt that currently guesses them.
- **Verified — the runner has no work-in-progress check of any kind.**
  `Skills/dev-epic-workflow/assets/claude-config/bin/unattended-intake.sh:225-236` selects issues
  with exactly `gh issue list --state open --label claude-intake`. Its only dedup is
  **removing the label** after a successful run. Nothing consults PRs, branches, or issue state
  beyond `open`.
- **Verified — and it corrects the premise of this epic's own open question.** The #757 race,
  timed from `gh`: issue filed `19:50:58Z` → attended PR #758 opened `19:58:37Z` → **#758 merged
  `20:00:12Z`** → runner selected #757 at `20:02:46Z` (runner log) → unattended PR #761 opened
  `20:06:10Z` → issue closed `20:16:24Z`. At the moment of selection there was **no open PR** and
  the issue was **still open**. Therefore *"skip an issue with any open PR referencing it"* would
  **not** have prevented this race, and neither would "skip closed issues". See item 3.
- **Verified — drafters caught the collision themselves.** LODE #732 and #733 both detected that
  they target the same `except` blocks in the same file and both escalated to a human. That is
  the behaviour item 4 must stop depending on.
- **Verified — the label is the only admission control.** There is no path allowlist, no
  sensitive-path denylist, no size ceiling. Those belong to epic 08 item 2 and are **not** in
  scope here.
- **Assumed — the drafter will honour a new outcome vocabulary as reliably as it honours the
  current hard stops.** Unproven; item 1's fixture is what converts it from assumption to fact,
  and item 5 re-measures it at n≥5.
- **Assumed — five genuinely under-specified briefs can be sourced without manufacturing
  artificial ones.** If real briefs are not available, item 5 says so and the verdict stays no-go
  rather than resting on synthetic evidence.

## Invariants

- **No autonomy rung is enabled by this epic.** The runner's five hard stops — never approves,
  never dispatches, never writes code outside the proposal folder, never merges, never closes an
  issue — remain mechanically in force at every commit.
- **Unattended drafting keeps working throughout.** No change may make the runner fail closed on
  a repo configured today; a repo whose config says nothing gets today's behaviour.
- **Existing proposals stay valid artifacts.** `claude-skills` PRs #25, #26, #50 and LODE #761
  must remain readable and approvable by hand after any header- or outcome-format change. Format
  changes are additive.
- **The automation may not modify its own config**, its admission policy, or this plan.
- **A skip is never silent.** Every refusal to draft — already addressed, in flight, collided —
  is written to the issue and to the runner log with the evidence that caused it.

## Work items

### 1. Non-approval outcomes as a first-class drafter product
- **Branch:** `feat/intake-nonapproval-outcomes`
- **Depends on:** none
- **Scope:** Give the drafter a closed vocabulary of terminal outcomes and a place to put it.
  A new `**Recommendation:**` header field on the proposal's `plan.md`, with exactly three
  values: `plan` (draft an epic, today's behaviour), `no-work` (duplicate, already done, or
  invalid — nothing for an approved epic to dispatch), `needs-decision` (a real choice a human
  must make before any plan is worth writing; the plan body states the choice and the options,
  and does not resolve it). The drafter prompt in `unattended-intake.sh` gains the vocabulary and
  the rule that `no-work` and `needs-decision` are **correct, preferred outputs** when they fit —
  not failures. The PR title and the issue comment carry the recommendation. `session-start-context.sh`
  lists `no-work` / `needs-decision` proposals under a distinct heading from ordinary
  `planning` ones, because the action they need from Jonathan is different.
- **Not in scope:** any consumer that *acts* on the recommendation automatically. L1's obligation
  to route these to a human is written down here as a contract; enforcing it is epic 08 item 5's
  job, and epic 08 is closed. This item makes the output exist and be visible; nothing more.
- **Definition of done:** the three values are documented in `references/issue-intake.md`; a
  fixture replaying #757's brief (observations only, four open questions, a negative constraint)
  produces `Recommendation: no-work` with the duplicate named, **not** a plan at
  `Status: planning`; a fixture on an ordinary QA brief still produces `Recommendation: plan`;
  the SessionStart injection renders all three; the existing guard battery passes.
- **Verification:** run the two fixtures and diff their `plan.md` headers; grep
  `session-start-context.sh` for the new heading and exercise it against a fixture epics tree.
- **Rollback:** revert; the field is additive and a proposal without it reads as `plan`.

### 2. Header metadata read from repo config, never from recall
- **Branch:** `fix/intake-header-from-config`
- **Depends on:** none
- **Scope:** Resolve both branch facts in the runner and pass them to the drafter as *stated
  facts*. The integration branch is already `BASE_BRANCH` (`unattended-intake.sh:187-191`,
  validated against origin at :193). The live branch is `defaultBranchRef`, which line 190 already
  fetches — but only when no `|base` override exists, so on LODE it is never resolved. Make that
  fetch **unconditional**, then inject live branch, integration branch and the epics dir into the
  `PROMPT` string (:303) alongside an explicit prohibition: these header fields are supplied, never
  inferred. Where a fact is genuinely unavailable the drafter writes `unknown`, never a guess.
- **Not in scope:** the rest of the header. `Pre-epic tag` stays a judgement call and stays the
  drafter's to propose.
- **Definition of done:** a drafted proposal for LODE reads `**Live branch:** main` and
  `**Integration branch:** dev`; one for `claude-skills` reads `main` for both; a repo whose base
  is unresolvable yields `unknown` and a logged reason rather than a plausible wrong value; the
  two known-bad headers (LODE #741, #739) are reproduced-and-fixed by the fixture.
- **Verification:** `--dry-run` across both configured repos showing the resolved values in the
  log, plus one live draft per repo compared against `git remote show origin`.
- **Rollback:** revert; the drafter returns to filling the fields itself.

### 3. Never draft work that is already done or already in flight
- **Branch:** `fix/intake-skip-addressed-issues`
- **Depends on:** none
- **Scope:** Add the work-in-progress check the runner has never had. **The rule the evidence
  supports, which is not the rule the question assumed:** skip an issue when a PR referencing it
  exists in state **open or merged** and was **not authored by the runner** (runner-authored is
  decided by the `intake/proposed-` branch prefix the script already constructs, not by GitHub
  actor). Closed-unmerged PRs do **not** block — abandoned work is not work in flight. Evaluate
  the check **twice**: at selection, and again immediately before opening the proposal PR, because
  the #757 window between those two points was under four minutes. On a skip: comment the
  evidence on the issue, remove the label so it cannot spin, and log it.
  - Merged-not-open is the case that actually bit us: at 20:02:46 the only trace of #758 was that
    it had merged 2m34s earlier. An open-PR-only rule sees nothing.
  - The "not authored by the runner" qualifier costs nothing today — the runner removes the label
    after drafting, so it never re-selects its own issue — and it stops the runner tripping over
    its own proposal PR if the label is ever re-applied by hand.
- **Not in scope:** admission policy generally (labels, path allowlists, size ceilings) — epic 08
  item 2. This item adds exactly one check, for exactly one failure that has already happened.
- **Definition of done:** a fixture replaying the #757 timeline (issue open, label present, one
  merged non-runner PR referencing it) is skipped with the merged PR named in the comment; an
  issue with an open non-runner PR is skipped; an issue with only a closed-unmerged PR is
  **drafted**; an issue with only the runner's own proposal PR is **drafted**; the late re-check
  catches a PR that merges after selection.
- **Verification:** the five fixtures above, plus a `--dry-run` against the live repos showing
  each open `claude-intake` issue's classification and reason.
- **Rollback:** revert; the runner returns to drafting everything labelled.

### 4. Collision detection in admission, not in drafter goodwill
- **Branch:** `feat/intake-collision-detection`
- **Depends on:** 1 (consumes the `needs-decision` outcome)
- **Scope:** After a proposal is drafted and before its PR is opened, compare the files and
  modules it declares it will touch against those declared by every other **open** proposal in
  the same repo. On overlap, set both the new proposal's `Recommendation:` to `needs-decision`,
  name the counterpart proposal and the overlapping paths in the plan body and the PR, and
  comment on both issues. The existing proposal is annotated by comment, not rewritten — an open
  PR is not edited from under a reviewer.
- **Not in scope:** resolving the collision, ordering the two epics, or closing either as
  superseded. That is precisely the human decision the outcome exists to route.
- **Definition of done:** a fixture drafting two proposals that both declare the same file
  produces the second at `needs-decision` naming the first; two proposals declaring disjoint
  files are unaffected; the #730/#731 pair is reproduced as a fixture and detected **by admission
  with the drafter's own collision reasoning stripped out**, proving the check does not depend on
  the drafter noticing.
- **Verification:** the three fixtures; plus a grep confirming the check runs before `gh pr create`
  in the script's control flow.
- **Rollback:** revert; detection reverts to drafter goodwill, which is where it is today.

### 5. Re-measure on hard briefs, and re-verdict
- **Branch:** `chore/l1-remeasure`
- **Depends on:** 1, 2, 3, 4 — measuring the old drafter says nothing about the fixed one
- **Scope:** Source **at least five genuinely under-specified briefs** — observations without a
  diagnosis, unstated constraints, real open questions — and ensure they are **not overtaken by
  attended work** while the runner drafts them (item 3's check now makes overtaking visible
  rather than silent). Draft them unattended. Score every draft against the **existing**
  `draft-quality-rubric.md`, unchanged and unfitted to the findings. Score D6 (uncertainty handled
  honestly) and V3 (silently resolving a stated open question) on this group specifically, since
  that is the axis the original sample could not measure. Then issue a new go/no-go on L1.
- **Not in scope:** amending the rubric to fit what is found; enabling L1 whatever the verdict —
  L1 lives in epic 08 item 5 and requires its own epic to build. This item produces evidence and
  a verdict, not a switch.
- **Definition of done:** ≥5 hard-brief drafts scored, grouped separately from any easy briefs
  drafted in the same window; the sample size stated beside the verdict per Phase 4; an explicit
  go / no-go with reasons; **a second no-go is a legitimate and possibly correct outcome** and
  ends this epic honestly, exactly as the first one ended epic 08.
- **Verification:** a second reader can re-derive every score from the unchanged rubric plus the
  drafts at the commits they were cut from; the provenance of each brief is recorded, including
  whether attended work touched its issue during the window.
- **Rollback:** n/a — no change is made.

## Sequence

**(1 ∥ 3) → 2 → 4 → 5**

Items 1, 2 and 3 are logically independent, but **1 and 2 are not safely concurrent**: both edit
the same `PROMPT` string at `unattended-intake.sh:303`ff — item 1 adds the outcome vocabulary,
item 2 injects the supplied header facts — and two executors editing one heredoc in parallel is
a merge conflict by construction. Item 3 touches the selection loop (:225-236) and a new
pre-`gh pr create` re-check, which are disjoint from both. So **1 and 3 run in parallel, 2 follows
1** on the same region of the file. Fixtures land in separate files under
`hooks/tests/`, so they do not collide.

**4 depends on 1** for the `needs-decision` vocabulary. **5 depends on all four**, because it
measures the fixed drafter, not the current one.

The ordering principle is the same one epic 08 used and then obeyed: **the measurement gates the
conclusion, and a no-go is allowed to end the epic.** Items 1–4 are worth landing on their own
merits even if item 5 returns no-go again — a drafter that can say "no work here", reads its
header from config, refuses duplicated work, and detects collisions is better at L0 too.

## Risks

| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| The new outcome vocabulary becomes an escape hatch — the drafter returns `needs-decision` whenever a brief is hard, and drafting quality silently drops | **Medium** | L1 looks safe because nothing is ever drafted | Item 5 scores the *rate* of each outcome on the hard sample and states it; an implausibly high `needs-decision` rate is itself a finding, not a pass |
| Item 3's check is too broad and starves the runner | Medium | Labelled issues never drafted | The rule is narrow by construction — merged-or-open, non-runner-authored only; the `--dry-run` classification of every live labelled issue is a required verification step |
| Item 3's check is too narrow and the race recurs | Low | A second wasted proposal | The check runs twice, and the second run is immediately before PR creation; the window shrinks from ~4 min to seconds |
| Five genuinely hard briefs cannot be sourced without manufacturing them | **Medium** | Item 5 cannot deliver, or delivers synthetic evidence | Stating "not measured" is an explicit permitted outcome; manufactured briefs are not — the rubric already refuses to let a solved brief inflate a verdict |
| Header facts are passed in but the drafter overwrites them anyway | Low | The 2-of-7 defect survives item 2 | The DoD requires a live draft per repo compared against `git remote show origin`, not a prompt review |
| Collision detection depends on proposals declaring their touched files honestly | **Medium** | Overlap missed | The declaration is already a plan-template field; where it is absent or empty the check treats the proposal as colliding-unknown and returns `needs-decision` rather than passing silently |
| Scope creep back into epic 08's ladder | Medium | This epic becomes epic 08 again | Invariant: no rung is enabled here; items 2 and 5 explicitly disclaim admission policy and the L1 switch |
| Fixtures escape their sandbox (GH #15, still open) | Known-real | Working tree committed by a test | Item fixtures reuse the existing harness; GH #15 remains open and is **not** fixed here — flagged in Deferred |

## Open questions

- **Where do five hard briefs come from?** Real QA intake is symptom-first but usually
  well-specified. Candidates: LODE's older un-triaged backlog, `needs-triage` issues with low
  confidence scores, and issues deliberately filed thin. This needs an answer before item 5 is
  dispatched, not before the epic is approved.
- **Should `needs-decision` also be reachable *after* a plan is drafted** — i.e. can a proposal
  start as `plan` and be downgraded by item 4's collision check? Item 4 assumes yes. If Jonathan
  prefers a proposal's recommendation to be immutable once written, item 4 instead opens the PR
  and comments the collision without changing the header.
- **Does a `no-work` proposal still open a PR?** It carries a plan file that says "do not approve
  me". A PR is the current, uniform delivery mechanism and is easy to close; a bare issue comment
  is lighter but breaks the one-shape-for-every-outcome property. Leaning: keep the PR, because
  the artifact is the evidence.
- **Should item 5's re-verdict be allowed to go straight to a go on L1**, or should a go here only
  authorise *re-filing* the ladder epic for separate approval? Leaning strongly toward the latter
  — a verdict is evidence, not an approval.

## Deferred / out of scope

- **The autonomy ladder itself (epic 08 items 2–8).** If item 5 returns a go, the ladder is
  re-filed as a **new epic** for separate approval, incorporating the opt-in hardening from
  PR #49 (global L0 override; enablement gated on ledger evidence). It is not resurrected in place.
- **Admission policy** — labels, area allowlist, sensitive-path denylist, size ceiling. Epic 08
  item 2's scope, unchanged.
- **GH #15** — fixture harnesses can escape their sandbox. Real, open, and touched by this epic's
  fixtures, but a separate defect with its own proposal already drafted (PR #25).
- **GH #12** — branch-name cancel selectors inert under worktree dispatch (PR #26).
- **GH #48** — telemetry resolution treats a `planning` proposal as an address (PR #50). Adjacent
  to this epic's subject matter but independently scoped; keep it separate.
- Any change to the rubric. It was written before the drafts were read and that ordering is what
  makes it evidence; re-fitting it would destroy the property.

## Log
- 2026-08-20 — drafted following epic 08's NO-GO verdict on L1. Grounded by re-reading the verdict,
  the runner script, and both trackers. **One finding changed a work item's design during
  grounding:** the #757 race was assumed to be preventable by skipping issues with an open PR;
  the actual timings show the blocking PR had already *merged* 2m34s before selection, so item 3's
  rule is merged-or-open and non-runner-authored, and runs twice.
- 2026-08-20 — **approved and numbered 09**, immediately after epic 08 was closed on its no-go.
  A second grounding finding changed the Sequence before dispatch: items 1 and 2 both edit the
  drafter `PROMPT` at `unattended-intake.sh:303`, so the drafted plan's "1 ∥ 2 ∥ 3" was wrong and
  became "(1 ∥ 3) → 2". Item 2's scope also tightened once line 190 was read — the live branch is
  already fetched, just not on repos that override their base, which is exactly the repo where
  both header defects appeared.
