# Epic: replace the legalistic Communication discipline section with plain phrasing

**Status:** closed (superseded — see Log; GH #75 remains open, to be addressed by a new
structural-fix epic)
**Live branch:** main
**Integration branch:** main
**Pre-epic tag:** n/a
**Source:** GH #75 — the fourth attempt on this issue. Epic 12 first added the Communication discipline
section; epic 13 extended it with a second "Forbidden phrasing" example set after a live violation;
both looked correct on paper and both failed on the next real dispatch. This epic changes the
*form* of the instruction instead of adding more examples to the same form.

## Outcome
`work-item-executor.md`'s Communication discipline section is replaced with a short, plain,
directly-phrased instruction — the same three exceptions SKILL.md's canonical Output discipline
rule already defines (blocking question, major issue, return summary), stated in one paragraph
of direct imperative language, with no bulleted forbidden-phrasing list and no narrative about
prior violations. Validated against a **real** work-item dispatch's actual transcript, not a grep
for the phrase in the file — the failure mode this epic exists to fix is specifically that prior
fixes verified as "the text is present" without verifying "the live model complies," and both
passed the former while failing the latter.

## Grounding
This epic was diagnosed in the orchestrator session of 2026-08-27, evidence gathered live rather
than assumed:

- **Verified — the epic-14 dispatch (this same session) narrated 9 times**, in the exact
  recap/preview shapes epic 13's Forbidden phrasing list already named as banned ("Now write
  status...", "Now verify with grep...", "Now commit and push.", "Exit 0, clean match. Now open
  the PR."). Read directly from the executor's own transcript JSONL
  (`agent-ae00446b2785c9642.jsonl`), not inferred. This means epic 13's fix — concrete banned
  examples added to the file — did not hold on the very next real dispatch after it merged.
- **Verified — it is not a harness-level competing instruction.** A plain `general-purpose`
  subagent with zero discipline instruction stayed silent on a trivial 3-tool-call task; the same
  agent type given an explicit discipline instruction stayed silent on both a 3-call task and an
  8-call/5-phase fully scripted task. If a harness-level "give updates" default were overriding
  agent-level instructions, the zero-instruction control should have narrated. It didn't.
- **Verified — it is not the agent file's length or persona diluting the rule.** The real
  `work-item-executor` agent type, given its own full built-in instruction (all 100+ lines,
  unchanged), stayed completely silent on the identical 8-call/5-phase scripted task. Same file,
  same rule, zero narration — so file length/density alone doesn't explain the real-dispatch
  failures either.
- **Verified — the trigger is real judgment under a long interleaved trajectory, not judgment
  alone.** A single-shot judgment task (read one plan, answer three analysis questions requiring
  real evaluation, one tool call) came back completely clean regardless of instruction wording —
  there was no interleaved action/decision structure for narration to occupy. The real failure
  case (epic 14) had ~38 interleaved tool calls with a decision at many of them.
- **Verified — extended thinking is already active and does not by itself prevent the
  duplication.** The narrating epic-14 transcript recorded 13 separate `thinking` blocks
  alongside its 9 narration `text` blocks — thinking activates at roughly the same density as
  real decision points, and the model still separately writes a visible sentence about a subset
  of those decisions anyway. "Enable extended thinking" is not an available lever; it was already
  on.
- **Verified — the same agent, given a genuinely interleaved multi-step judgment task (audit
  three closed epics' retros against their stated outcomes, one grep-checked claim per epic, a
  verdict recorded before moving to the next) with the current legalistic instruction swapped for
  short plain phrasing, executed 6 real tool calls across 3 real judgment cycles with its entire
  visible output being exactly the three requested verdict lines.** This is the first genuinely
  judgment-heavy, multi-step test result in the whole investigation that came back clean. (A
  paired control using the same task did not produce comparable data — see Assumed below.)
- **Assumed — not proven by a fair paired test.** The control run in that last comparison used an
  overly broad "ignore your entire lifecycle and status contract" framing and the executor
  correctly refused the whole task as an unauthorized override attempt (zero tool calls, no
  narration data either way). So the plain-phrasing result is a real positive data point, not a
  proven A/B win over the legalistic version under identical conditions. This epic's validation
  step (below) is what closes that gap — on a **real** dispatch, not another diagnostic.

## Invariants
- The three exceptions stay exactly as SKILL.md's canonical Output discipline rule defines them
  (blocking question, major issue, return summary) — this changes phrasing/form, not the rule's
  substance, so `work-item-executor.md`'s "applied to you, not restated" relationship to
  `SKILL.md` stays true.
- `status.json` remains the actual progress channel — nothing about this narrows or changes what
  gets reported there.
- No change to `SKILL.md`'s own canonical Output discipline paragraph (line 101) — only
  `work-item-executor.md`'s copy is in scope.

## Work items

### 1. Replace the Communication discipline section with plain phrasing, validate on a real dispatch
- **Branch:** `docs/plain-phrasing-communication-discipline`
- **Depends on:** none
- **Scope:** in `Skills/dev-epic-workflow/assets/claude-config/agents/work-item-executor.md`,
  replace the entire `## Communication discipline` section (currently spanning the paragraph
  introducing the rule, the three-exception list, "Outside those three, stay silent...", the
  "Forbidden phrasing" bullet list, the "second dispatch" narrative paragraph, and the closing
  "pattern, not an exhaustive blocklist" paragraph) with:

  ```markdown
  ## Communication discipline

  Same rule as `SKILL.md`'s Output discipline (Phase 3) — applied to you, not restated.

  Be quiet while you work. Make your tool calls, write to `status.json`, and don't narrate
  them — no "now reading X," no "let me check Y," no recap of what a call just returned, no
  preview of what you're about to do next. Just do it.

  Speak up in exactly three moments: you hit a blocker and need to ask a real question,
  something changes the shape of the work and needs flagging now rather than at the end, or
  you're giving your final return summary. Otherwise, silence — between tool calls, between
  phases, the whole way through. If you're not in one of those three moments, don't write a
  sentence.
  ```

  Update `output-discipline-drift-fixtures.sh` so its markers match the new section's actual
  wording (the fixture asserts specific substrings are present — those substrings must be
  updated to strings that exist in the new text, and the mutation self-test must still prove the
  fixture can fail).
- **Touches:**
  - `Skills/dev-epic-workflow/assets/claude-config/agents/work-item-executor.md`
  - `Skills/dev-epic-workflow/assets/claude-config/hooks/tests/output-discipline-drift-fixtures.sh`
- **Not in scope:** no change to `SKILL.md`'s own Output discipline paragraph; no change to the
  three exceptions' substance; no change to any other section of `work-item-executor.md`.
- **Definition of done:**
  - The new section text is in the file, the old Forbidden-phrasing/narrative paragraphs are
    gone, and the drift fixture passes with updated markers plus a working mutation self-test.
  - **The orchestrator dispatches the next real, non-diagnostic work item using this updated
    executor**, and before merging this item's own PR, reads that real dispatch's transcript
    JSONL directly (the same way epic 14's failure was found) and confirms zero narration
    text blocks between tool calls. If that real dispatch still narrates, this item is not
    done — report the finding, do not merge on "the text is present."
  - If no other real work item is available to dispatch at validation time, the validation dispatch
    may be this epic's own PR-opening step for item 1 itself (the executor opening its own PR is a
    real dispatch, not a diagnostic one) — but the orchestrator must still read the transcript
    before merging, per the same rule.
- **Verification:** `grep -c "Communication discipline" work-item-executor.md` → 1 (section still
  exists, once); `output-discipline-drift-fixtures.sh` passes; the live-transcript read described
  above, with the actual thinking/text block counts reported, not assumed clean.
- **Rollback:** revert the merge commit — restores the epic-13 version, which is a known (if
  imperfect) prior state, not a regression to nothing.

## Sequence
Single item.

## Risks
| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| Plain phrasing also fails to hold on a real dispatch — this would be the third failure of a "fix" that looked right on paper | Medium (two priors failed; this is the first design with any live positive signal, but unproven under a fair paired test) | Low (cosmetic — no dispatch has ever produced an incorrect *outcome* from narration, only extra token cost) | Definition of done requires reading a real dispatch's transcript before merge, not just a text grep — if it fails, the item is reported not-done and the epic stays open rather than closing on false confidence, same discipline epic 14 used to catch the earlier gap |
| The drift fixture's updated markers pass even if the live behavior regresses, recreating the same false-confidence gap as before | Low | Low | The definition of done explicitly separates "fixture passes" from "verified done" — the live-transcript read is a second, independent check, not inferred from the fixture |

## Deferred / out of scope
- A fully fair paired A/B test (plain vs. legalistic phrasing, identical real-work-item task,
  same executor) was not run — the diagnostic control attempt was refused by the executor as an
  unauthorized override, not a clean comparison. If plain phrasing also fails live, a properly
  isolated paired test (using a legitimate dispatch framing on both sides, not a "DIAGNOSTIC
  OVERRIDE" framing that trips the executor's own guardrails) would be the next diagnostic step
  before trying a third phrasing.
- Whether SKILL.md's own canonical Output discipline paragraph (line 101) should also be
  simplified in the same style — left alone here since it wasn't shown to be the failing surface,
  and it's already reasonably plain (one paragraph, no bulleted forbidden-phrasing list).

## Log
- 2026-08-27 — epic filed and approved in the same session as the diagnosis, per Jonathan's
  request to file it to disk before clearing context so the diagnostic reasoning isn't lost.
  Diagnosis: 6 diagnostic subagent dispatches across the session (2 scripted-task controls, 1
  real-item retrospective read, 1 real work-item-executor scripted replication, 1 single-shot
  judgment task pair, 1 interleaved-judgment task pair) narrowed the cause from "harness
  override" (ruled out) through "agent file dilution" (ruled out) to "real judgment across a long
  interleaved trajectory duplicates itself from private thinking into visible text, and the
  current legalistic instruction form doesn't suppress it" (best current explanation, still not
  proven by a fair paired test).
- 2026-08-27 — item 1 dispatched (`work-item-executor`, agent `a744f7244a64c793d`), landed
  PR #81 (`31c46d6`), fixture and gates green, executor self-reported "no narration between
  tool calls." Per the item's own definition of done, that self-report was independently checked
  against the raw transcript JSONL
  (`~/.claude/projects/-Users-jonathanstevenson-Source-claude-skills/.../subagents/agent-a744f7244a64c793d.jsonl`)
  by a separate verification subagent, not trusted. **Result: FAILS.** 8 text blocks total, 1
  legitimate (final return summary), 7 narration violations — the same "Now X" recap/preview
  pattern epic 13's Forbidden-phrasing list already named, e.g. "Now let's set up the branch and
  read the target files.", "Now run the drift fixture to check it passes.", "Now open the PR."
  This is the third consecutive attempt (epics 12, 13, 15) that reads as fixed by grep/fixture and
  fails on the live transcript. **PR #81 is NOT merged.** Item 1 is reported not-done per its own
  definition of done — do not merge on "the text is present." Epic left `in flight`, open
  question for Jonathan: whether to attempt the Deferred section's fair paired A/B test next, or
  try a different lever entirely (e.g. a structural constraint rather than instruction wording —
  since three wording-only attempts have now failed the same way).
- 2026-08-27 — Jonathan's decision: go structural, not a fourth wording attempt. Before
  drafting a plan, researched what's actually available to intercept or strip a subagent's
  freestanding text content blocks programmatically. Checked live against the real docs (not
  memory) — Claude Code's Hooks Reference (https://code.claude.com/docs/en/hooks) and the Claude
  Agent SDK Hooks docs (https://code.claude.com/docs/en/agent-sdk/hooks): neither exposes
  block-level interception. The only hook that touches assistant text at all
  (`MessageDisplay`) is explicitly display-only/read-only; every other hook (`PreToolUse`,
  `PostToolUse`, `Stop`, `SubagentStart`/`SubagentStop`, `PreCompact`, etc.) fires around tool
  calls or session boundaries, never on message content. **Confirmed: the only way to actually
  strip text blocks before they re-enter a subagent's own context is to bypass the Task/Agent
  tool's built-in dispatch loop entirely and drive the raw Anthropic Messages API in a custom
  loop** — owning the conversation array directly, filtering text blocks out of each assistant
  turn before appending it to history. This is materially bigger than the three prior attempts:
  a bespoke executor harness (replicating tool execution, permissions, context management that
  the Task tool currently provides for free), not a prompt edit. Presented this trade-off to
  Jonathan; he chose to build it, starting next session ("we're going to do 1 after a clear").
  **This epic (15) is closed as superseded** — its scoped outcome (fix via wording) is
  abandoned, not achieved; GH #75 (the underlying narration problem) stays open and will be
  re-scoped under a new epic for the custom Messages-API executor loop. **PR #81 is left open,
  unmerged** — its diff (the plain-phrasing text replacement plus fixture update) is
  functionally moot once text-block stripping is programmatic, but closing or merging it is
  Jonathan's call, not decided here. GH #75's label (`epic:in-progress`) is left as-is rather
  than guessed at; the next session's Phase 1 filing of the new epic should resolve it properly,
  per the skill's own filing-updates-tracker rule.
