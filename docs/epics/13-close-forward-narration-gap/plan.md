# Epic: close the forward-narration gap in subagent output discipline

**Status:** approved
**Live branch:** main
**Integration branch:** main
**Pre-epic tag:** n/a
**Source:** GH #75

## Outcome
`work-item-executor.md`'s Communication discipline section explicitly forbids forward-looking narration ("Now let's X", "Let's check Y", "Now run Z") with the same weight as recap narration, using anti-examples drawn from a second live dispatch that violated the rule after epic 12's mitigation landed — and states plainly that the Forbidden phrasing list is illustrative of a pattern, not an exhaustive blocklist. The drift fixture is extended to guard the new markers.

## Grounding
- Verified: read `work-item-executor.md` lines 95–123 (Communication discipline + Forbidden phrasing block, added by epic 12 / GH #68). Read `SKILL.md` line 101 (canonical Output discipline paragraph). Read `output-discipline-drift-fixtures.sh` in full — literal `grep -F` substring checks against both files, each with a mutation self-test proving it can fail.
- Verified: GH #75 already tracks this exact failure mode, documents the epic-12 mitigation, and frames it as an open, unsolved limitation of prompt-only enforcement.
- Verified: the transcript Jonathan supplied (2026-08-27) shows the rule violated again, but in a different shape than the existing examples — every current anti-example is recap-then-preview ("Good — X. Let's Y."), while the new transcript's violations are almost all pure forward announcement with no recap ("Now let's implement.", "Let's check if...", "Now run gates: lint, typecheck, test, build."). Posted as evidence: [issue #75 comment](https://github.com/GreatFigure8/Claude-Skills/issues/75#issuecomment-5437492579).
- Assumed: this wording change reduces, not eliminates, narration drift — #75 is explicit that prompt-only enforcement can't be proven to work. Mechanical detection (#75's own open question) stays out of scope.

## Invariants
- Drift fixture keeps passing, and keeps proving it has teeth (fails on a mutated copy) for every marker, old and new.
- No change to the three permitted exceptions (blocking question / major issue / completion summary) — only tightening what falls outside them.
- SKILL.md states the rule once; work-item-executor.md keeps applying it rather than restating it (epic-12 invariant, not reversed here).

## Work items

### 1. Add forward-narration anti-examples and an exhaustiveness disclaimer
- **Branch:** `chore/close-forward-narration-gap`
- **Depends on:** none
- **Scope:** in `work-item-executor.md`'s Forbidden phrasing block, add 2–4 new anti-examples drawn from the 2026-08-27 transcript that are pure forward announcements (no recap), and add one sentence stating the list illustrates a *pattern* — any narration of an upcoming or just-finished tool call — not an exhaustive blocklist. Extend `output-discipline-drift-fixtures.sh` with markers for the new anti-examples and the disclaimer sentence, each proven to flip on a mutated copy per the file's existing pattern.
- **Touches:**
  - `Skills/dev-epic-workflow/assets/claude-config/agents/work-item-executor.md`
  - `Skills/dev-epic-workflow/assets/claude-config/hooks/tests/output-discipline-drift-fixtures.sh`
- **Not in scope:** no mechanical narration linter (GH #75's own open question — its own epic if pursued); no change to SKILL.md's canonical paragraph (the gap is in the concrete examples, which live only in `work-item-executor.md`); no change to the three-exception structure itself.
- **Definition of done:** the Forbidden phrasing block covers both recap-style and pure-forward-announcement narration with concrete examples of each, plus the disclaimer; drift fixture passes and its mutation self-test still flips for every marker.
- **Verification:** `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/output-discipline-drift-fixtures.sh` exits 0, all cases PASS.
- **Rollback:** revert the merge commit.

## Sequence
Single item.

## Risks
| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| Wording still doesn't generalize to a third narration shape | Medium | Low (cost only, no correctness impact) | GH #75 stays open regardless — this is framed as a mitigation, not a claimed fix, matching #75's own framing |

## Deferred / out of scope
- Mechanical transcript linter to detect narration drift after the fact (GH #75's open question) — needs its own design.

## Log
- 2026-08-27 — epic filed from GH #75, second live-dispatch evidence attached as a comment.
