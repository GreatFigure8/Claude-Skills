# Epic: Mandate nextjs-fullstack-standards for all TypeScript work

**Status:** closed
**Source:** GH #85
**Live branch:** main   **Integration branch:** main   **Pre-epic tag:** n/a — prose/doc change only, no runtime behavior to reconstruct

## Outcome

Every TypeScript work item planned under `dev-epic-workflow` loads the
`nextjs-fullstack-standards` skill at Phase 0, with no deviation — the same way Python work
items are already gated by `building-python-web-apps` / `building-python-mcp-servers`. The
mandate is stated in two places a session actually reads at Phase 0: the stack-skill summary
in `SKILL.md`, and the Next.js/Shadcn/Tailwind section of `references/stack-gates.md`.

## Grounding

- Verified: `Skills/dev-epic-workflow/SKILL.md`'s Phase 0 stack-skill paragraph named
  `building-python-web-apps`, `building-python-mcp-servers`, `building-llm-backed-features`,
  `rendering-untrusted-content`, and `shipping-across-surfaces` — no TypeScript-specific skill.
- Verified: `Skills/dev-epic-workflow/references/stack-gates.md`'s `## Next.js / Shadcn /
  Tailwind` section had no "load this skill first" instruction at all, unlike every Python
  section above it.
- Verified (post-hoc): `nextjs-fullstack-standards` exists as an installed plugin skill
  (`anthropic-skills:nextjs-fullstack-standards`), so the mandate names a real, loadable skill.
- Assumed: none — this is a prose/behavior-contract change with no runtime mechanism, so
  there is nothing further to verify against a live system.

**Process note:** this epic was filed retroactively, and the deviation is two-layered. Jonathan
asked for the change directly in conversation; it was implemented and **committed straight to
`main`** (commit `ebb6df3`) — no Phase 0/1 planning, no work-item branch, no PR (Phase 3 steps
2–3 and 8–9 all skipped). That is failure mode #1 from `SKILL.md`'s own list (coding before the
plan is agreed) compounded with failure mode #2 (no branch boundary at all). Jonathan then asked
for the GH issue and epic to be filed after the fact, which is this document and GH #85.

## Invariants

- No new persistent state, hook, or slash command — the mandate is a documentation change read
  at Phase 0, not a stored flag or gate script.
- Existing Python stack-gate mandates are unaffected; this only adds the TypeScript equivalent.

## Work items

### 1. Add the TypeScript stack-skill mandate to SKILL.md and stack-gates.md
- **Branch:** none — implemented via direct commit to `main` (process deviation, see Process
  note above; not repeated going forward).
- **Depends on:** none
- **Scope:** State, in `SKILL.md`'s Phase 0 stack-skill paragraph, that any TypeScript work
  loads `nextjs-fullstack-standards` with no deviation; add a matching "Load first, no
  deviation" line to the `## Next.js / Shadcn / Tailwind` section of `references/stack-gates.md`,
  retitled to cover TypeScript work generally.
- **Touches:**
  - `Skills/dev-epic-workflow/SKILL.md`
  - `Skills/dev-epic-workflow/references/stack-gates.md`
- **Not in scope:** no enforcement mechanism (hook/gate script) — the mandate is prose, the
  same way every other Phase-0 stack-skill instruction in this file is prose.
- **Definition of done:** `SKILL.md`'s Phase 0 paragraph names `nextjs-fullstack-standards`;
  `stack-gates.md`'s Next.js section carries a "Load first, no deviation" line naming it.
- **Verification:** `grep -n "nextjs-fullstack-standards" Skills/dev-epic-workflow/SKILL.md
  Skills/dev-epic-workflow/references/stack-gates.md` returns a match in both files.
- **Rollback:** revert commit `ebb6df3`.

## Sequence
Single item, no dependencies.

## Risks
| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| Mandate is prose only, no enforcement — a future session could still skip loading the skill | Low-medium | A TypeScript work item ships without the skill's guidance applied | Same mechanism every other stack-skill rule in this file relies on; add a mechanical check only if drift is actually observed |

## Deferred / out of scope
- A mechanical Phase-0 check (e.g. a hook that verifies the skill was loaded before a
  TypeScript-touching work item is dispatched) — not needed unless prose proves insufficient.

## Log
- 2026-08-31 — Work item 1 implemented directly in conversation and pushed straight to `main`
  (commit `ebb6df3`), ahead of this plan being filed — process gap, no branch or PR (see
  Process note). Verified: `git show --stat ebb6df3` touches exactly the two files listed
  under Touches; `grep -n "nextjs-fullstack-standards"` matches both files.
- 2026-08-31 — Issue filed retroactively as GH #85; this plan filed and closed in the same
  session per Jonathan's instruction. Retro: the same lesson as epic 17 — the workflow being
  extended was, again, not the workflow used to extend it. Two deviations compounded this
  time (no plan *and* no branch/PR), because the change looked small enough to seem
  self-evidently safe. Worth naming as a pattern: "it's just a docs one-liner" is exactly the
  rationalization Phase 1's sizing heuristic and failure mode #1 exist to catch, and it beat
  the process twice in two consecutive sessions.
