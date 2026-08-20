# Epic: stop attributing subagent telemetry to unapproved planning proposals

**Status:** planning
**Source:** GH #48
**Live branch:** main   **Integration branch:** main   **Pre-epic tag:** n/a

## Outcome

The active-epic resolution shared by `subagent-lifecycle.sh` and `subagent-tool-logger.sh` no
longer treats a `planning` proposal as a valid telemetry address. Only `approved` and `in flight`
plans — the two states that can actually own an executor — are addresses. Telemetry that has
nowhere legitimate to go (only `planning`/malformed plans are open, nothing is `approved` or `in
flight`) lands in a shared, repo-level orphan bucket instead of being silently dropped or misfiled
into a proposal that never asked for an executor.

## Grounding

- **Verified (issue mechanics):** `references/executor-control-plane.md` documents the resolution
  order at lines 65–73: (1) the `active-epic` pointer, (2) newest `plan.md` reading `in flight`,
  (3) newest `plan.md` that is "open but not started" — explicitly listing `planning`, `approved`,
  or no parseable `**Status:**` line at all — (4) nothing. Rule 3's three-way grouping is exactly
  what the issue reports: a `planning` proposal is `open`, so it wins rule 3 whenever every real
  epic is `closed`.
- **Verified (contradiction the issue points at):** line 81 states the governing principle —
  "Being open and being in flight are different states, and only the second one is an address" —
  but rule 3 as written makes three *open* states (including `planning`) into addresses. `planning`
  is documented elsewhere in the same skill (`references/issue-intake.md`, unattended-intake
  contract) as never approved and never dispatchable, so it can never legitimately own executor
  telemetry.
- **Verified (identical logic, two files):** the resolution block is byte-for-byte duplicated
  between `BEGIN active-epic resolution` / `END active-epic resolution` markers in both
  `subagent-lifecycle.sh` (lines 108–217, with `plan_state()` at 152 and `resolve_epic_dir()` at
  170) and `subagent-tool-logger.sh` (the same block, lines 86–195). `hooks/tests/active-epic-fixtures.sh`
  section H asserts this byte-identity directly (`cmp -s` on the extracted blocks) — any fix must
  preserve it or that assertion fails by construction.
- **Verified (fixture cases that currently encode the bug as correct behaviour):**
  `active-epic-fixtures.sh` section N, pass `p2` (`RUNNING_EPIC` = `approved`, no epic `in
  flight`), rows `planning|running|third`, `in progress|running|third`, `in flightless mode|running|third`,
  and `Closed-ish|running|third` — each currently *expects* the newer, merely-`open` `THIRD_EPIC` to
  win over the older but genuinely `approved` `RUNNING_EPIC`, purely on recency. Under the fix these
  four expectations flip to `running`, because `approved` becomes a higher-priority tier than
  `planning`/unrecognized-open, not a recency tie-break within the same tier. Section F's
  no-`Status:`-line case and the `07-also-queued`/`08-also-queued` sub-case in section K also
  assert on epics whose state would move from "wins rule 3" to "orphan bucket" — both need their
  expected values (and, for K, a new orphan-bucket assertion) rewritten, not just extended.
- **Verified (repo-level fallback is safe to introduce):** `.claude/signals/` is created
  unconditionally near the top of both hooks (`mkdir -p "$SIGNALS_DIR"`, lifecycle line 94, logger's
  equivalent) before any epic resolution runs, and is already gitignored
  (`.gitignore` lines 31–33: `.claude/signals/`, `docs/epics/*/status/`, `docs/epics/*/CANCEL`). A
  new subdirectory under it needs no new `.gitignore` entry.
- **Verified (issue's own proposed remedies):** the issue names three options — keep today's
  misfiling behaviour, drop `planning` from rule 3 and accept telemetry loss when only a proposal is
  open, or redirect that telemetry to a repo-level location such as
  `.claude/signals/orphan-telemetry/` "so it is neither lost nor attributed to an epic that did not
  earn it." This plan adopts the third option (see Open questions — this is the drafted
  recommendation, not a foregone conclusion).
- **Assumed:** no other reader parses `**Status:**` for a purpose that would be broken by narrowing
  rule 3 to `approved` only. `session-start-context.sh` (the SessionStart backlog injection quoted
  live in this session's grounding) already lists `planning` proposals under "awaiting approval"
  separately from dispatch state — a different code path, not part of this resolution block — but
  this plan does not re-read that script's source; a work item touching it would be out of scope
  here if the assumption is wrong.

## Invariants

- The two hooks' active-epic resolution logic stays byte-identical between the shared
  `BEGIN`/`END` markers — asserted by the existing fixture, not just eyeballed.
- Hooks keep failing open and staying silent on genuine errors: no non-closed plan anywhere, an
  unwritable `.claude/signals/`, malformed hook input → exit 0, no telemetry, no stderr.
- No new dependency: still correct with `jq` absent, `python3` absent, under `bash` 3.2 (the
  existing three-tier parser shape is preserved).
- The explicit `active-epic` pointer's semantics are unchanged: it still overrides inference and is
  still ignored only when it names a directory whose plan reads `closed`.
- Runtime state stays gitignored; nothing this epic adds is committed.

## Work items

### 1. Narrow rule 3 to `approved`; add the orphan-telemetry fallback
- **Branch:** `fix/telemetry-resolution-planning-not-an-address`
- **Depends on:** none
- **Scope:**
  - `subagent-lifecycle.sh` and `subagent-tool-logger.sh` — inside the shared resolution block:
    rule 3 (currently "newest `plan.md` that is open but not started: `planning`, `approved`, or no
    parseable Status line") narrows to *only* `approved`. A new terminal step is added after it:
    when no pointer, no `in flight` plan, and no `approved` plan resolved, but at least one non-closed
    `plan.md` exists (`planning`, unparseable, or any other non-standard open status), telemetry is
    written under `$REPO_ROOT/.claude/signals/orphan-telemetry/` instead of any epic's own `status/`
    tree — same file shapes as today (`agent-<id>.log` brackets and tool lines, `.agents/<id>.json`
    owner records for the lifecycle hook), just rooted outside `docs/epics/`. When *no* non-closed
    `plan.md` exists at all (every epic closed, or no epics filed yet), behaviour is unchanged:
    nothing is written, exit 0, as today.
  - `references/executor-control-plane.md` — rewrite the "Which epic, decided explicitly" list
    (around lines 62–73) to name four possible outcomes instead of three, make explicit that
    `planning` and `approved` are no longer treated as the same tier, and add one or two sentences
    to the surrounding prose (near line 93's "no parseable Status: line counts as open") stating
    where that telemetry now lands and why it is not attributed to any specific epic. Update the
    Layer 1 telemetry section's framing if it references the old three-tier language.
  - `hooks/tests/active-epic-fixtures.sh` — flip the four affected expectations in section N pass
    `p2` (`planning`, `in progress`, `in flightless mode`, `Closed-ish` rows) from `third` to
    `running`; update section F's no-`Status:`-line case and section K's `07-also-queued`
    (`planning`) / `08-also-queued` (status-less) sub-case to assert the new orphan-bucket location
    instead of "wins rule 3"; add a small helper (mirroring `life_epic`/`log_epic`) that checks
    `.claude/signals/orphan-telemetry/agent-<id>.log` so cases can assert "landed in orphan, not in
    any epic" as a distinct, positive outcome rather than inferring it from `<none>`. Add a fresh
    case reproducing the issue's exact scenario: every real epic `closed`, one `planning` proposal
    open, no pointer — before the fix this asserts the proposal's `status/` tree gets telemetry
    (today's bug, reproducible on unmodified code); after the fix it asserts the proposal's
    `status/` tree stays empty and the orphan bucket receives the bracket pair instead.
- **Not in scope:** `cancel-gate.sh`, ownership/`terminal`-stamping semantics, per-agent log naming,
  the `status.json` milestone vocabulary, `session-start-context.sh`'s backlog listing, the pointer's
  own resolution rules (still honors an explicit non-closed target unchanged), and any change to how
  `docs/epics/proposed-<n>-<slug>/` proposals are numbered or renamed at approval.
- **Definition of done:**
  - Only real epics, `closed` excepted, plus the pointer, plus the orphan bucket, can receive
    telemetry — a `planning`-only repo state never writes into that proposal's `status/` tree.
  - An `approved` plan still wins over any merely-`planning`/malformed open plan regardless of which
    `plan.md` is newer (the fixed version of section N pass `p2`).
  - An `in flight` plan still beats an `approved` one regardless of recency (section L, unaffected
    by this change, still passes).
  - The pointer, and the closed-epic exclusion, are both unchanged (sections B, C, D, M all still
    pass unmodified).
  - The two hooks' resolution blocks remain byte-identical (section H still passes).
  - `jq`, `python3`-only, and neither-present variants all agree (all three `full`/`nojq`/`bare`
    passes of the fixture still run and pass).
  - Zero non-closed `plan.md` anywhere still degrades to true silence — exit 0, nothing written, no
    stderr (section G, unmodified, still passes).
- **Verification:** `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/active-epic-fixtures.sh`
  run to completion with `failures: 0`, output pasted in the item's own report — including the
  reproduction case run once against the pre-fix hook (documenting the live bug) and once against
  the fixed hook. Also re-run `cancel-gate-fixtures.sh` and `lifecycle-fixtures.sh` unchanged as
  regression, per the control-plane doc's own rule for touching any control-plane hook. `bash -n`
  over both edited hook scripts.
- **Rollback:** revert the merge commit, re-run `install.sh` (`--user` or repo mode, matching how
  this repo's hooks are installed). Worst case reverts to today's behaviour — a known, low-impact
  misfiling bug, not a destructive one.

## Sequence

Single item.

## Risks

| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| Orphan bucket becomes a silent dumping ground nobody ever looks at, same complaint in a new place | Low | Cosmetic — telemetry is still gitignored, local-only, and easy to `rm -rf` | It replaces a worse outcome (misattributed to a real proposal, or lost); no retention/rotation policy is being invented here, matching existing status-log handling |
| Narrowing rule 3 breaks a real workflow that relied on `planning` proposals catching stray telemetry | Low | Telemetry redirected but not lost — recoverable by reading `orphan-telemetry/` instead of the old (wrong) location | Fixture regression suite plus the reproduction case prove the redirect, not a drop |
| Divergence reintroduced between the two hook files during the edit | Medium if done by hand, low with the fixture | Lifecycle and logger disagree about the epic again | Section H's byte-identity assertion is unchanged and must still pass |
| Line-number citations in `executor-control-plane.md` drift as prose is added | Low | Documentation-only, cosmetic | Not a gate; the doc is prose, not a fixture target |

## Deferred / out of scope

- Whether `session-start-context.sh`'s "awaiting approval" backlog listing needs any change — not
  verified as in-scope or broken; would need its own grounding pass if raised later.
- Any retention, rotation, or size cap on `.claude/signals/orphan-telemetry/` — out of scope until
  it is observed to grow unbounded in practice, matching how `status/agent-*.log` has no cap today
  either.
- Making the orphan bucket queryable from `/tasks` or any other UI surface — it is a filesystem
  escape hatch, not a new observability feature.

## Open questions

- **The core design decision is drafted, not settled.** The issue names three ways to resolve the
  tension (keep misfiling into `planning`; drop `planning` and accept telemetry loss when only a
  proposal is open; redirect to a repo-level orphan bucket) and asks explicitly for "a decision, and
  the docs and hooks agreeing with it." This plan recommends and scopes the third option, because it
  is the only one that satisfies both stated principles at once — `planning` stops being an address,
  and line 93's "write it somewhere, never silently lose it" still holds. Approval is where that
  recommendation is confirmed or overridden; if Jonathan prefers the "accept the loss" option
  instead, item 1's orphan-bucket sub-scope (the fallback step and its fixture cases) simply drops,
  leaving a smaller diff.
- **Whether "no non-closed plan.md exists at all" should also redirect to the orphan bucket**, rather
  than staying silent as today. This plan keeps that case unchanged (true silence) to stay minimal
  and matched to the reported defect — the defect is specifically about `planning` proposals
  competing for an address, not about capturing every stray subagent's activity when there are no
  epics at all. Worth reconsidering only if unattributed telemetry loss in a fully-empty-epics repo
  turns out to matter in practice.

## Log

- 2026-08-20 — proposed from GH #48 via unattended intake. Phase 0 confirmed the reported
  three-way grouping in rule 3 (`references/executor-control-plane.md` lines 65–73), the
  contradiction with the "open vs. in flight" principle at line 81, the byte-identical resolution
  block in both hooks, and — concretely — the four existing fixture cases in
  `active-epic-fixtures.sh` section N that currently encode the reported bug as a passing test and
  would need their expectations rewritten by any fix. Not approved, not numbered, not dispatchable.
