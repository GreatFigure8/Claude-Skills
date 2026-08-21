# Epic: L1 preconditions — make the machine able to receive what good drafting produces

**Status:** in flight (items 4 and 7 of 7; items 1, 2, 3 and 6 done)
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
  current hard stops.** Unproven, and **it stays unproven through item 1** — corrected 2026-08-20
  after item 1 landed. Item 1's fixtures exercise the mechanism end-to-end against a *stub*
  drafter, which proves the plumbing carries a recommendation faithfully; whether a live model
  returns `no-work` rather than inventing a plan is a model property no hermetic fixture can
  establish. **Item 5's D6/V3 axis is the only thing in this epic that measures it**, at n≥5.
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
- **Outcome: DONE.** PR #53, merged `ba25b9b`. Verified cold: block ordering correct
  (`check_work_in_progress` :485 precedes `REC_FILE` :505), item 3's own suite passes 60/60
  against this branch, full gate suite green on merged `main` at **879 cases, 0 failures**.
- **Delivered narrower than this plan's Grounding claimed, and the executor said so unprompted.**
  The fixtures prove the *plumbing* carries a recommendation faithfully, using a stub drafter.
  Whether a live model returns `no-work` instead of inventing a plan is untested and untestable
  hermetically — see the corrected Grounding bullet. Item 5 measures it.
- **A cross-item fixture defect surfaced during the rebase and is worth remembering.** Item 1's
  `gh` stub did not answer the `gh api …/timeline` query item 3 had just introduced, so every case
  in item 1's suite was silently taking item 3's *degraded* `unknown` path rather than the normal
  `clear` path. The suite was green while exercising the wrong branch of someone else's new code.
  Found and fixed by the executor itself. **The general lesson: a stub that does not answer a new
  query does not fail — it silently degrades**, so a suite passing after a neighbouring item lands
  is not evidence that it tested anything.
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
- **Outcome: DONE.** PR #55, merged `6271f30`. Verified cold on 2026-08-21: 3 declared files,
  `Part of #39` once and `Closes` zero times, zero diff lines in item 6's territory, and the live
  `--dry-run` resolves `live=main integration=main` for `claude-skills` and **`live=main
  integration=dev` for LODE** — the exact pair #741 and #739 inverted — both matching
  `git remote show origin`. Full battery on merged `main`: **1005 cases, 0 failures**.
- **One DoD clause is deliberately carried, not met.** *"one live draft per repo compared against
  `git remote show origin`"* was not done: `--dry-run` returns before the prompt is built, so
  **only fixtures have exercised the new prompt text — no live model has yet seen it.** The risk
  row *"header facts are passed in but the drafter overwrites them anyway"* is therefore **not
  retired**, and item 2's own fixture case H deliberately shows a recall-based drafter still
  writing `dev`. Decided 2026-08-21: item 5's live drafts supply that proof rather than burning a
  hard-brief sample on a throwaway PR now.
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
- **Outcome: DONE.** PR #52, merged `96ac7c0`. Verified cold: mechanism correct on the real
  #757 race (live `--dry-run` against LODE, 2/2 true positives), all five mandated cases are
  passing fixtures, `--dry-run` mutated nothing across 8 runs. **One defect found in verification
  and split out as item 6** — see there.
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

### 6. Narrow "references" to closing linkage, not any cross-reference
- **Outcome: DONE.** PR #56, merged `62aa16e`. Verified cold on 2026-08-21 against the repo, not
  the return summary — see the re-measurement below.
- **The load-bearing design claim holds, and a controlled pair proves it.** `claude-skills` #45
  (base `main` = the default branch, body "Closes #41") reports `closingIssuesReferences=[41]`;
  LODE #758 (base `dev` ≠ default `main`, body line 91 "Closes #757") reports `[]`. Same keyword,
  same shape, opposite result. **The keyword fallback is load-bearing, not a nicety** — without it
  the one true positive this epic exists for goes undetected.
- **The suite cannot silently pass against the old script.** Run against pre-item-6
  `unattended-intake.sh` it does not merely fail, it **hard-errors** building mutant R
  (*"the linkage gate moved, so case R proves nothing"*). The reverse control matches the
  executor's claim exactly: main's suite against the new script gives **60 cases / 21 failures**.
- **Branch:** `fix/intake-reference-narrowing`
- **Depends on:** 3 (done) — this narrows the check item 3 added
- **Scope:** Item 3 asks GitHub's issue timeline for any `cross-referenced` event whose source is
  a PR. That is far broader than "this issue is being worked": **a passing mention of the issue
  number in an unrelated PR body blocks it.** Narrow the signal to GitHub's *closing* linkage
  (`closingIssuesReferences` / a connected-event, i.e. the PR actually declares it resolves the
  issue) with a documented fallback for the merged case. Keep item 3's other two axes exactly as
  they are: state must be open-or-merged, and runner-authored PRs are excluded by the
  `intake/proposed-` branch prefix.
- **Not in scope:** admission policy generally; any change to what a skip *does* once decided.
- **Definition of done:** the four false positives measured below no longer skip; the #757 true
  positive (PR #758, which declared it fixed the issue) still skips; a PR that merely names an
  issue number in prose does not skip it; a fixture encodes the self-reference case specifically.
- **Verification:** re-run the live `--dry-run` classification over every open issue in both
  repos and compare against the table below — the four `SKIP`s must become `DRAFT` and LODE's two
  true positives must stay `SKIP`.
- **Rollback:** revert; the check returns to the broader rule, which fails safe.
- **Why this is a separate item and not a fix to item 3:** it is a rule change, not a defect in the
  implementation of the agreed rule. Item 3's executor found the breadth, measured it, and
  explicitly declined to change the rule unilaterally — which is the behaviour this workflow wants.

**The measurement, taken cold on 2026-08-20 after PR #52 merged.** On `claude-skills`, four of
four open issues classify `SKIP`, all falsely:

| Issue | Classified | Blocking PR | True positive? |
|---|---|---|---|
| #12 | SKIP | #38 `docs/close-epic-06` (merged) | No — passing mention in a close-out |
| #15 | SKIP | #38 `docs/close-epic-06` (merged) | No — passing mention in a close-out |
| #39 | SKIP | #47 `docs/approve-epic-08` (merged) | No — passing mention in an approval |
| #48 | SKIP | **#52 itself** (open) | No — **self-refuting**, see below |
| LODE #786 | SKIP | open PR | **Yes** |
| LODE #757 | SKIP | #758 (merged) | **Yes** — the race this epic exists for |

The #48 row is the sharpest evidence available: PR #52's own body contains the sentence
*"#48 classified DRAFT — no open or merged non-runner PR references it"*, and that sentence is
itself a cross-reference. **The PR documenting that #48 is draftable is what makes it
undraftable.** No narrower demonstration of the defect is needed.

**Severity, stated plainly:** a false positive is not a soft deferral. `skip_issue` removes the
`claude-intake` label, so a spurious skip *retires the issue from unattended intake* until a human
re-labels it. It fails safe against duplicated work and it is never silent — the skip comment
warns about passing mentions in as many words — but on a repo whose close-out PRs routinely name
every issue they touched, that is most issues. **Nothing is at risk today: no open issue currently
carries the label.** This item must land before the label is used on this repo again — and in
particular **before item 5**, which labels issues in order to draft them and would otherwise
measure a drafter that never ran.

**Re-measured cold on 2026-08-21, after PR #56 merged, by the orchestrator and not by the
executor.** Every open issue in both repos was classified twice — once against `main` before the
merge (item 3's rule) and once against item 6's script — and every blocking PR was read to confirm
whether it declares closure. n=5 issues on `claude-skills`, n=7 on LODE.

| Issue | item 3 rule | item 6 rule | Blocking PR read back | Correct? |
|---|---|---|---|---|
| #12 | SKIP | **DRAFT** | #38 — no closing link, no closing keyword | ✅ flip |
| #15 | SKIP | **DRAFT** | #38 — no closing link, no closing keyword | ✅ flip |
| #39 | SKIP | **DRAFT** | #47 — no closing link, no closing keyword | ✅ flip |
| #48 | SKIP | **DRAFT** | #52 — no closing link, no closing keyword | ✅ flip |
| **#54** | SKIP | **DRAFT** | **#55 — item 2's own PR, mentions #54, closes nothing** | ✅ flip |
| LODE #757 | SKIP | SKIP | #758 merged, body "Closes #757" via the **`declared` fallback** | ✅ held |
| LODE #786 | SKIP | SKIP | #792 merged, declares closure via the **`declared` fallback** | ✅ held |
| LODE #766 | SKIP | SKIP | #808 merged, declares closure | ✅ held |
| LODE #795 | SKIP | **DRAFT** | #799 says only "Part of #795" | ⚠️ see item 7 |
| LODE #811/#803/#801 | — | DRAFT | nothing references them | — |

**The measurement was worse than the plan's table said, in item 6's favour.** It listed four false
positives; there were **five of five** — `#54` had appeared since, blocked by PR #55, *the pull
request implementing this very epic's item 2*. Under item 3's rule every open issue on this repo
was un-draftable. Both true positives survive, and both survive **through the keyword fallback**,
which is the measurement that proves the fallback earns its place.

**Two of item 6's executor's claims did not survive, and are corrected here.** It reported that
LODE #766 and #795 both now classify `DRAFT`. **#766 does not** — it skips correctly via merged
PR #808, a different PR than the one that blocked it before. **#795 does**, and it is worse than
reported: #795 is **open** with **four merged PRs** on branches named `*/795-*`, every one saying
"Part of #795". That is item 7.

### 7. Treat a named branch or a declared "Part of" as work in flight
- **Branch:** `fix/intake-wip-inflight-epics`
- **Depends on:** 6 (done) — this widens the check item 6 narrowed
- **Why this exists, measured not supposed.** Item 6 correctly narrowed *blocking* to closing
  linkage, which is the right signal for **already done**. It left **already in flight**
  undetected whenever the work is a multi-item epic, because those PRs say "Part of #N" and
  deliberately do not declare closure until the final item. Measured 2026-08-21 across both repos
  (n=11 issues): **LODE #811 is open right now with an OPEN PR (#814), a merged PR (#813) and a
  branch `feat/811-reconcile-claim-against-ledger`, and today's runner would draft over it.**
- **Scope:** add two further block signals to `check_work_in_progress`, both cheap, both measured
  present on the real cases: (a) a non-runner branch on `origin` named `*/<issue>-*`; (b) an
  open-or-merged non-runner PR whose body declares `Part of #<issue>`. Item 6's closing-linkage
  path stays exactly as it is and remains the **already done** signal; these two are the
  **already in flight** signal. The skip comment must name *which of the three* fired, because
  the remedy differs: already-done means close the issue, in-flight means wait.
- **Not in scope:** admission policy generally; any change to what a skip *does* once decided;
  cross-repo (`owner/repo#N`) and full-URL references, which item 6 left unhandled and this item
  does not pick up.
- **Definition of done:** measured against the same live classification item 6 was, the rule flips
  **exactly three** verdicts and no others — LODE #795 and #811 and `claude-skills` #39 go
  `DRAFT`→`SKIP`, each naming the in-flight epic; **#12, #15, #48 and #54 stay `DRAFT`** so item
  6's five flips are not undone; **LODE #757 and #786 stay `SKIP`** through the closing-linkage
  path, unchanged; LODE #803 and #801 stay `DRAFT`. A fixture encodes the "Part of" case and a
  mutant proves the branch signal is independently load-bearing.
- **Verification:** re-run the live `--dry-run` classification over every open issue in both repos
  and diff it against the table above — three cells change, nine do not.
- **Rollback:** revert; the check returns to item 6's closing-linkage-only rule, which fails
  *open* (drafts too much) rather than closed.
- **Why this is item 7 and not a fix to item 6:** identical reasoning to why item 6 was not a fix
  to item 3. Item 6 implemented the approved rule correctly; widening what counts as "in flight"
  is a rule change, and the executor that found it was right not to make it unilaterally.

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

**(1 ∥ 3) → (2 ∥ 6) → (4 ∥ 7) → 5**, where **6 and 7 must both precede 5**.

Items 2 and 6 did run in parallel and landed cleanly against each other — measured, not assumed:
zero diff lines of overlap in either direction, and PR #55 stayed `MERGEABLE/CLEAN` after #56
merged. **Item 7 replaces item 6 as the last gate before item 5**, for the same reason item 6
was: item 5 labels issues in order to draft them, and while #795- and #811-shaped issues
classify `DRAFT`, item 5 would draft duplicate proposals over epics already in flight and score
the result as evidence. **4 and 7 are independent** — 4 touches admission before `gh pr create`,
7 touches the work-in-progress helper — so they may run in parallel, each in its own worktree.

Items 1, 2 and 3 are logically independent, but **1 and 2 are not safely concurrent**: both edit
the same `PROMPT` string at `unattended-intake.sh:303`ff — item 1 adds the outcome vocabulary,
item 2 injects the supplied header facts — and two executors editing one heredoc in parallel is
a merge conflict by construction. Item 3 touched the selection loop and a new pre-push re-check,
disjoint from both, so **1 and 3 ran in parallel and did land cleanly against each other's
declared regions** — the only conflict was two adjacent insertions git could not order, which is
the cheap kind.

**4 depends on 1** for the `needs-decision` vocabulary. **6 depends on 3** and touches only the
work-in-progress helper item 3 added, so it is free to run alongside 2 or 4.

**5 depends on everything, and on 6 especially.** Item 5 works by labelling issues so the runner
drafts them; while item 6's defect stands, an issue that has ever been named in a merged PR is
skipped and *delabelled* instead of drafted. Running item 5 first would measure a drafter that
never ran and call the empty result evidence — the precise failure that emptied epic 08's Group C
and cost it its verdict.

The ordering principle is the same one epic 08 used and then obeyed: **the measurement gates the
conclusion, and a no-go is allowed to end the epic.** Items 1–4 and 6 are worth landing on their
own merits even if item 5 returns no-go again — a drafter that can say "no work here", reads its
header from config, refuses duplicated work, and detects collisions is better at L0 too.

## Risks

| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| The new outcome vocabulary becomes an escape hatch — the drafter returns `needs-decision` whenever a brief is hard, and drafting quality silently drops | **Medium** | L1 looks safe because nothing is ever drafted | Item 5 scores the *rate* of each outcome on the hard sample and states it; an implausibly high `needs-decision` rate is itself a finding, not a pass |
| Item 3's check is too broad and starves the runner | Medium | Labelled issues never drafted | The rule is narrow by construction — merged-or-open, non-runner-authored only; the `--dry-run` classification of every live labelled issue is a required verification step |
| Item 3's check is too narrow and the race recurs | Low | A second wasted proposal | The check runs twice, and the second run is immediately before PR creation; the window shrinks from ~4 min to seconds |
| Five genuinely hard briefs cannot be sourced without manufacturing them | **Medium** | Item 5 cannot deliver, or delivers synthetic evidence | Stating "not measured" is an explicit permitted outcome; manufactured briefs are not — the rubric already refuses to let a solved brief inflate a verdict |
| Header facts are passed in but the drafter overwrites them anyway | Low | The 2-of-7 defect survives item 2 | **NOT RETIRED at item 2's merge.** `--dry-run` returns before the prompt is built, so only fixtures have seen the new text. Item 5's live drafts are the first real test |
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
- **`session-start-fixtures.sh` fails 2 of 125 on any machine that has unattended intake
  configured.** Confirmed pre-existing and environment-dependent, not caused by items 1 or 3:
  with `INTAKE_REPO_LIST=/nonexistent` the suite is **125/125 on `main`**. Two independent
  diagnoses agree — the harness scrubs `PATH`, and `session-start-context.sh:383` calls bare
  `grep` for its `launchctl` check, which is unresolvable under that scrubbed path, leaving a
  stray blank line the byte-identical comparison then fails on. The fix is one line pinning
  `INTAKE_REPO_LIST` in the harness (or resolving `grep` in the hook). **Worth filing as its own
  issue** — a gate that fails for environmental reasons trains people to ignore it.
- **No human override exists to say "draft it anyway".** Item 3 added a check with no bypass;
  a `--force-issue`-style flag or a `claude-intake-force` label would give one. Admission-policy
  shaped, so it belongs near epic 08 item 2 rather than here.
- **`--repo` is an override, not a filter.** It forces the repo slug for *every* entry in the
  repos list rather than restricting the run to one repo, which makes `--repo X --issue N` produce
  confusing cross-repo output. Pre-existing; harmless in `--dry-run`; worth a docstring fix.
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
- 2026-08-20 — **items 1 and 3 dispatched in parallel**; item 3 landed first (PR #52, `96ac7c0`).
  Verified cold rather than from the return summary: PR scope, region boundaries, and the claim
  that `session-start-fixtures.sh`'s 2 failures were pre-existing — all three held. **Item 6 was
  created out of that verification**: item 3's reference rule is far broader than intended, and
  PR #52's own body demonstrates it by flipping #48 from DRAFT to SKIP. Item 6 must precede item 5.
- 2026-08-20 — **Grounding corrected, not the item.** The plan claimed item 1's fixture would
  convert "the drafter honours the vocabulary" from assumption to fact. It cannot: hermetic
  fixtures stub the drafter, and whether a live model returns `no-work` instead of inventing a
  plan is a model property. Item 1's executor flagged the overclaim in its own return summary
  rather than letting it stand. Measuring it is item 5's job and item 5's alone.
- 2026-08-21 — **items 2 and 6 verified cold by the orchestrator and merged** (PR #55 → `6271f30`,
  PR #56 → `62aa16e`). Nothing was taken from either executor's return summary: the negative
  controls were re-run (60/21 for the stale suite; the new suite *hard-errors* against the old
  script rather than silently passing), the load-bearing `closingIssuesReferences` claim was
  reduced to a controlled pair (#45 base=default → link populated; LODE #758 base≠default →
  link empty despite "Closes #757"), and every open issue in both repos was re-classified against
  both scripts. Full battery on merged `main`: **1005 cases, 0 failures**; working tree clean;
  `~/.config/claude-intake/intake.log` byte-identical across 14 live `--dry-run` invocations.
- 2026-08-21 — **the re-measurement was worse than this plan recorded, in item 6's favour.** The
  table said four false positives; there were **five of five**, the new one being `#54`, blocked
  by PR #55 — the pull request implementing this epic's own item 2. Item 3's rule had made every
  open issue on this repo un-draftable.
- 2026-08-21 — **two of item 6's executor's claims were corrected on verification.** LODE #766
  does **not** flip to `DRAFT` (it skips correctly via merged PR #808); #795 does, and it is worse
  than reported — open, with four merged `*/795-*` PRs all saying "Part of #795".
- 2026-08-21 — **item 7 filed**, and the sequence changed to `(1 ∥ 3) → (2 ∥ 6) → (4 ∥ 7) → 5`.
  The open question *"an issue whose epic is mid-flight now classifies DRAFT — widen the rule or
  not?"* is **resolved: widen**, as its own item. The deciding evidence was found by measuring
  rather than reasoning: **LODE #811 is open right now with an OPEN PR, a merged PR and a branch
  named for it, and today's runner would draft over it.** Both proposed signals were measured
  across n=11 live issues before being written down — they flip exactly three verdicts, all three
  correct, and disturb neither item 6's five flips nor its two true positives.
- 2026-08-21 — **decision: PR #55 merged with one DoD clause deliberately unmet.** No live model
  has yet seen item 2's new prompt text, because `--dry-run` returns before the prompt is built.
  Item 5's live drafts supply that proof; drafting a throwaway proposal now would burn a
  hard-brief sample to test a string. The associated risk row is marked **NOT RETIRED** rather
  than quietly dropped.
