# Epic: Work items declare the paths they touch

**Status:** in flight (item 1 of 4 done — items 2 (PR #74) and 3 (PR #72) open awaiting review, item 4 pending)
**Source:** GH #57 (split out of GH #39 / epic 09 item 4)
**Live branch:** `main`   **Integration branch:** `main`   **Pre-epic tag:** n/a — additive, every change reverts by merge-revert

## Outcome

A work item states the paths it will touch in a field a program can read, instead of in a
sentence a program has to guess at. When this epic is done, epic 09 item 4's collision check
reads that field rather than parsing prose; the PR gate compares the declared paths against the
actual diff and reports both directions of mismatch; and the drafter emits the field on every
proposal it writes. The prose `**Scope:**` line stays exactly where it is and keeps doing what it
is good at — explaining *what changes and why* to a human.

This epic enables no autonomy rung and changes no admission policy. It replaces a heuristic with
a declaration.

## Grounding

Verified against the repo on 2026-08-21, not recalled. Every line names how it was checked.

- **Verified — `**Scope:**` is free text and nothing machine-reads it.** `references/plan-template.md:37`
  is `- **Scope:** what changes, in files/modules`. A grep for `Scope` across `assets/` and
  `references/` returns only prose mentions — the executor agent's "scope that grows mid-item"
  rule and the PR template's manual line. **Epic 09 item 4 is the first machine consumer that has
  ever existed.**
- **Verified — two surfaces already disagree about whether this is one field or two.**
  `SKILL.md:59` reads *"**Work items** — numbered, each with: branch name, scope, **files/modules
  touched**, definition of done, and what it explicitly does not do"* — naming the touched-files
  list as its own element. `plan-template.md:37` collapses it into Scope. This drift predates the
  epic and is itself evidence for the field.
- **Verified — one check is already manual because the field does not exist.**
  `references/pr-template.md:62` asks a human for `git diff --stat <base>...HEAD` → *"touched
  paths match scope: yes/no + note"*. That is Phase 4's central question answered by eye.
- **Verified — the prose extractor's limits, measured on the five live proposals** by epic 09
  item 4's first dispatch and re-derived independently by the orchestrator from
  `origin/intake/proposed-*`:
  - Precision and recall trade off with no clean setting. Restricting to the token that leads a
    Scope bullet removes both known false positives **and loses a true collision**, because PR #25
    writes its declaration as a comma list wrapped across two lines.
  - Mentions are indistinguishable from declarations. PR #26's Scope names `subagent-lifecycle.sh`
    and `subagent-tool-logger.sh` only as files it compares *against*, while its own *Not in scope*
    says "any change to ... themselves (this item only reads what they already write)".
  - Path forms differ between drafts of the same file: PR #26 writes the full
    `Skills/dev-epic-workflow/assets/claude-config/hooks/tests/active-epic-fixtures.sh`; PR #50
    writes `hooks/tests/active-epic-fixtures.sh`.
- **Verified — the header window is not a constraint here.** `session-start-context.sh:149` sets
  `EPIC_QUEUE_HEADER_LINES=10` and `unattended-intake.sh:107` pins the runner to the same window.
  The new field is **per work item, in the body**, so it never competes for those ten lines.
- **Verified — the drafter is pointed at the template for structure but told header facts
  explicitly.** `unattended-intake.sh:537` says *"using the structure in
  ${SKILL_DIR}/references/plan-template.md"*, then enumerates `Status`, `Source`,
  `Recommendation`, `Live branch`, `Integration branch` by name. A body field added to the
  template *may* propagate on its own — **that is an assumption, and item 2 tests it rather than
  trusting it.**
- **Verified — the blast radius of retrofitting.** 9 filed epics carrying 27 work items with a
  `**Scope:**` line, plus 3 live proposals. Item 1 decides this is **not** retrofitted; see there.
- **Assumed — that a drafter will produce accurate paths.** Unproven, and it is the same class of
  defect epic 09 item 2 fixed for branch names, where a drafter filling a field from recall got it
  wrong on 2 of 7 proposals. Item 3's gate is the only thing in this epic that would catch it, and
  it only catches it for an item being *executed*, never for a proposal. Stated in Risks, not
  waved away.

## Invariants

- **A plan without the field stays valid.** Every consumer treats absence as "not declared" and
  degrades loudly, never fails closed. The 9 filed epics and 27 existing work items are not
  rewritten by this epic and must keep working untouched.
- **The prose `**Scope:**` line is not replaced or deprecated.** It explains intent to a human;
  the new field states paths to a program. Both stay.
- **No autonomy rung is enabled and no admission policy changes.** The runner's five hard stops —
  never approves, never dispatches, never writes code outside the proposal folder, never merges,
  never closes an issue — remain in force at every commit.
- **Existing proposals stay approvable by hand.** PRs #25, #26 and #50 predate the field and must
  remain readable and mergeable after it exists.
- **The automation may not modify its own config, its admission policy, or this plan.**

## Work items

### 1. Define the field, and land it on every surface that defines it — done, merged `18d0380`
- **Branch:** `docs/declared-paths-field`
- **Depends on:** none
- **Scope:** Add the field to `references/plan-template.md` with a worked example, and update the
  two surfaces that already describe this element so all three agree: `SKILL.md:59` (which already
  names "files/modules touched" — point it at the field by name) and
  `references/issue-intake.md` (the proposal contract). **Recommended shape, one path per line:**

  ```
  - **Touches:**
    - `Skills/dev-epic-workflow/references/plan-template.md`
    - `Skills/dev-epic-workflow/SKILL.md`
  ```

  Three rules, each earning its place from the measurement above: **one path per line** so a
  wrapped comma list can never lose an entry the way PR #25's did; **repo-root-relative always**,
  which deletes the suffix-normalisation problem at its source rather than solving it in every
  consumer; and **declarations only** — a file the item merely reads or compares against is
  named in prose, never here, which is the mention-versus-declaration line drawn explicitly.
- **Not in scope:** any consumer. This item makes the field exist and be defined; nothing reads it
  yet. Also **no retrofit** — the 27 existing work items across 9 filed plans are left alone, and
  the decision is recorded in the template so it is not re-litigated.
- **Definition of done:** the field is defined in `plan-template.md` with a worked example and the
  three rules stated; `SKILL.md:59` names it; `issue-intake.md` carries it in the proposal
  contract; a grep for the old wording finds no surface still describing this element differently.
- **Verification:** `grep -rn 'files/modules touched\|Touches' Skills/dev-epic-workflow/` shows the
  three surfaces agreeing and nothing else claiming otherwise.
- **Rollback:** revert; the field is additive and nothing reads it yet.

### 2. The drafter emits it
- **Branch:** `feat/intake-declare-touched-paths`
- **Depends on:** 1
- **Scope:** Make the unattended drafter produce a well-formed `**Touches:**` block per work item.
  **First establish whether the template alone is enough** — the prompt points at
  `plan-template.md` for structure but enumerates header facts explicitly, so propagation is an
  assumption. If a fixture shows the drafter omitting or malforming the field when only the
  template changed, add it to the `PROMPT` explicitly, in the same shape as the supplied header
  facts. Where the drafter genuinely cannot tell which paths an item touches, it declares nothing
  and says so in prose — never a plausible guess, for exactly the reason `Live branch` is supplied
  rather than recalled.
- **Not in scope:** validating that the declared paths are correct. Item 3 does that, and only for
  items being executed.
- **Definition of done:** a fixture drafting a proposal produces every work item carrying a
  `**Touches:**` block whose entries are repo-root-relative, one per line; a fixture where the
  paths are genuinely unknowable produces no block and a prose statement, not a guess; the
  existing guard battery passes.
- **Verification:** run the fixtures and extract the block with the same sed the consumers use;
  a `--dry-run` across both live repos mutating nothing (cksum `~/.config/claude-intake/intake.log`
  before and after).
- **Rollback:** revert; proposals go back to prose-only.

### 3. The PR gate compares declaration against diff
- **Branch:** `feat/declared-paths-gate`
- **Depends on:** 1
- **Scope:** A script that reads an item's declared paths and compares them against
  `git diff --name-only <base>...HEAD`, reporting **both** directions: declared-but-untouched
  (the item did less than it said) and touched-but-undeclared (the item did more). Wire it into
  `references/pr-template.md` — replacing the manual line at :62 — and into the
  `work-item-executor` agent definition as a pre-PR step. **v1 WARNs, it does not block**, and an
  absent field yields "not declared", never a failure.
- **Not in scope:** blocking a PR on mismatch; that is a policy change worth making only once
  there is evidence about the false-positive rate.
- **Definition of done:** the script reports both mismatch directions on a fixture repo; an item
  with no declared block reports "not declared" and exits 0; `pr-template.md:62`'s manual line is
  gone, replaced by the command; the executor agent runs it before opening a PR.
- **Verification:** fixtures for the three cases (exact match, over-reach, under-reach) plus one
  for the absent field; a negative control showing the gate fails when the comparison is inverted.
- **Rollback:** revert; the PR template's manual line comes back.

### 4. Collision detection reads the field
- **Branch:** `refactor/collision-detection-reads-declarations`
- **Depends on:** 1, **and on epic 09 item 4 having landed**
- **Scope:** Replace item 4's prose extractor with a read of the declared block. A proposal that
  carries the field is compared on declared paths only; a proposal that does not — every one that
  predates this epic — falls back to epic 09's own stated rule, `colliding-unknown` →
  `needs-decision`, rather than to prose parsing. That is a **deliberate reduction in cleverness**:
  the fallback fails toward a human, which is what the outcome vocabulary exists for.
- **Not in scope:** changing what a collision *does* once detected; that was settled 2026-08-21 —
  admission downgrades the header to `needs-decision`.
- **Definition of done:** the two known false positives from PR #26's Scope (`subagent-lifecycle.sh`,
  `subagent-tool-logger.sh`) no longer appear, because a mention is not in the declared block; the
  true collisions between #25, #26 and #50 are still found once those proposals carry the field;
  a proposal without the field returns `colliding-unknown`; the prose extractor is deleted, not
  left dormant.
- **Verification:** re-run epic 09 item 4's own fixture suite against the new reader, plus a live
  comparison over the open proposals showing the same true positives and neither false positive.
- **Rollback:** revert; item 4's prose extractor returns.

## Sequence

**1 → (2 ∥ 3) → 4**

Item 1 is a pure definition change and blocks everything. Items 2 and 3 are independent — 2 is the
producer, 3 is a checker of already-produced declarations — and touch disjoint files, so they run
in parallel in separate worktrees. **Item 4 additionally waits on epic 09 item 4**, which is in
flight now; there is nothing to refactor until its prose extractor exists.

If epic 09 item 4 lands late, items 1–3 still deliver on their own: the field exists, the drafter
emits it, and the PR gate makes Phase 4's central question mechanical. Item 4 here is the only one
coupled to the other epic.

## Risks

| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| The drafter declares plausible-but-wrong paths, exactly as it did for `Live branch` on 2 of 7 proposals | **Medium** | A proposal's collision check silently compares fiction | Item 3's gate catches it — but **only for an item being executed, never for a proposal**. Stated as a known gap, not mitigated away. A proposal's declared paths could be existence-checked (`git cat-file -e`); that is deliberately deferred, not assumed |
| Over-declaration to dodge a collision, or under-declaration to avoid one | Low | Collision detection degrades to noise or silence | Epic 09's existing rule already covers the empty case (`colliding-unknown` → `needs-decision`); item 3's gate reports over-reach in the other direction |
| The declaration goes stale as an item's scope legitimately shifts mid-execution | **Medium** | Gate warns on honest work | v1 WARNs rather than blocks, and the workflow already requires a scope change to be announced and the plan updated |
| Adding a field changes what every future proposal emits | Medium | Every drafted proposal | Additive and absence-tolerant by invariant; the 3 live proposals are unaffected and stay approvable |
| The template change does not propagate to the drafter on its own | **Medium** | Item 2 silently ships nothing | Item 2 tests propagation before assuming it, and adds the field to the `PROMPT` explicitly if the fixture shows it is needed |
| This epic's own items forget to declare their paths | Low | Embarrassing, and evidence against the field | Items 2, 3 and 4 each carry a `**Touches:**` block once item 1 lands — the epic dogfoods its own field |

## Open questions

- **Is the field required or optional for hand-authored plans?** Optional is the safe default and
  is what the invariant assumes. Required is only enforceable once item 3 exists, and would need a
  retrofit decision for anything in flight.
- **May a declaration name a directory** (`hooks/tests/`) rather than only files? Shorter
  declarations, coarser collisions. Leaning yes with a trailing slash as the marker, because
  epic 09's measurement showed real proposals declaring `status/` and `hooks/lib/` exactly that way.
- **Should deletions be declared distinctly from edits?** A path an item *removes* is a stronger
  collision signal than one it edits. Leaning no for v1 — YAGNI until a collision is missed.
- **Does item 3's gate ever become a blocker?** Deliberately out of scope here; revisit once there
  is a measured false-positive rate rather than a guess about one.

## Deferred / out of scope

- **Retrofitting the 27 existing work items across 9 filed plans.** Closed epics are history and
  nothing reads their declarations. Explicitly decided in item 1, not left implicit.
- **Existence-checking a proposal's declared paths.** Cheap (`git cat-file -e`) and would catch the
  drafter-fiction risk at draft time rather than execution time. Left out to keep this epic to one
  idea; noted in Risks so it is not lost.
- **Making the field structured beyond a path list** — globs, modules, symbols. Speculative until
  a path list is shown to be insufficient.
- **GH #54** — `session-start-fixtures.sh` fails 2/125 by environment. Unrelated and still open.

## Log
- 2026-08-21 — drafted from GH #57, which was split out of epic 09 item 4 rather than folded into
  it. Grounded by reading `plan-template.md`, `SKILL.md`, `pr-template.md`, `issue-intake.md` and
  the drafter `PROMPT`, and by re-deriving item 4's collision measurement independently from the
  `origin/intake/proposed-*` branches. **Two grounding findings shaped the plan:** `SKILL.md`
  already names "files/modules touched" as its own element, so item 1 is closing a drift that
  already exists rather than inventing a field; and the drafter is pointed at the template for
  structure but told header facts explicitly, so item 2 must *test* propagation rather than assume
  it.
- 2026-08-21 — **approved and numbered 10.** Filed while epic 09 is still in flight with items 4
  and 7 dispatched; that is safe by design, because telemetry resolution is decided by the
  `.claude/signals/active-epic` pointer (which names `09-l1-preconditions`) and then by "newest
  plan marked **in flight**", never by mtime. A just-filed plan is always the newest plan, which
  is exactly the capture GH #11 was about — state outranks recency, so epic 09 keeps its executors.
