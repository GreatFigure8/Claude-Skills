# list-story-counts — execution plan

Sprint: 2026-09-11-001   Story: list-story-counts   Kind: service
Grounded: Skills/dev-story-flow/assets/bin/sprint-state.sh (cmd_list, load/save, main dispatch), Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh (list section), Skills/dev-story-flow/references/sprint-state.md (line 106 list signature)   Assumed: none

## Items
| # | Branch | Scope / Done when / Not | Files owned | Wave | Model | Gates |
|---|---|---|---|---|---|---|
| 1 | feat/list-story-counts-column | In `cmd_list` (sprint-state.sh), append a 5th tab field `<done>/<total>` computed from `m.get("stories", [])` (`total=len(stories)`, `done=count where s["status"]=="done"`); update the `list` usage line in references/sprint-state.md to show 5 columns. Done when: `sprint-state.sh list` on a sprint with 0 stories prints trailing `0/0`, and fields 1-4 are unchanged. Not: no change to get/set/story/stale/new output. | Skills/dev-story-flow/assets/bin/sprint-state.sh, Skills/dev-story-flow/references/sprint-state.md | 1 | Sonnet 5 | `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` |
| 2 | test/list-story-counts-coverage | Extend sprint-state-fixtures.sh's list section with 3 checks: fresh sprint → trailing `0/0`; after 2 story adds → `0/2`; after one forced to `done` → `1/2`. Add new file assets/tests/sprint-state-list-integration.sh: throwaway git repo, run `new` → `story add` ×2 → `story set <slug1> done --force` → `list`, assert the exact tab-separated line (5 fields) matches expected, exit 0/1 in the same PASS/FAIL pattern as the fixtures runner. Done when: both test files run standalone and exit 0 against item 1's implementation. Not: no changes to sprint-state.sh itself. | Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh, Skills/dev-story-flow/assets/tests/sprint-state-list-integration.sh | 2 | Sonnet 5 | `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh && bash Skills/dev-story-flow/assets/tests/sprint-state-list-integration.sh` |

## Validation — how the coder proves each acceptance criterion
| AC | Check | Command / browser steps | Pass when |
|---|---|---|---|
| AC-U | unit | `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` | exit 0, output includes the 3 new count checks passing |
| AC-I | integration | `bash Skills/dev-story-flow/assets/tests/sprint-state-list-integration.sh` | exit 0 |
| AC-1 | unit | `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` (0-story case) | line for a fresh sprint ends `0/0` |
| AC-2 | unit | `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` (2-story, 1-done case) | line ends `1/2` |
| AC-3 | unit/manual | `SPRINTS_DIR=<tmp> Skills/dev-story-flow/assets/bin/sprint-state.sh list planned` against a fixture repo with a planned sprint | 5 fields printed, same shape as unfiltered `list` |
| AC-4 | manual diff | `diff <(git show HEAD~1:Skills/dev-story-flow/assets/bin/sprint-state.sh 2>/dev/null | ... )` — practically: inspect `cmd_list` output fields 1-4 against pre-change behavior in the fixtures/integration test assertions | fields 1-4 byte-identical to pre-change `list` output |

## Order and dependencies
Item 2 depends on item 1 (tests exercise the new column). Both in this story's own wave;
no dependency on other stories in the sprint. Story `emphasize-story-counts` in this sprint
depends on this story being done first (per story.md Dependencies) — the coder should land
this story before starting that one.

## Risks and gotchas
- `cmd_list` must keep the output header-less and tab-separated; appending a field must not
  add a trailing tab or extra whitespace that breaks `cut -f1` / `wc -l` consumers named in
  the story.
- `total = len(m["stories"])`; a sprint predating this change may lack the `stories` key —
  use `m.get("stories", [])` (as `cmd_story`/`find_story` already do) to avoid a KeyError.
- Only python3 is available inside the heredoc (no external deps); keep the count logic to
  plain list comprehension/`sum()`.
- Test files must remain self-contained throwaway-git-repo runners per the existing
  `sprint-state-fixtures.sh` pattern (mktemp dir, trap cleanup, PASS/FAIL counters).

## Open questions
None — story.md's own Open Questions section already records the defaults Jonathan left
unanswered (format, column position, header, zero-story rendering); this plan follows them
as specified.
