# list-story-counts — validation

Sprint: 2026-09-11-001   Integration: sprint/2026-09-11-001 @ f732a71
Run: 2026-09-11T17:35:00Z

| AC | Check | Command | Result | Status |
|---|---|---|---|---|
| AC-U | unit | `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` | 43 passed, 0 failed | PASS |
| AC-I | integration | `bash Skills/dev-story-flow/assets/tests/sprint-state-list-integration.sh` | 2 passed, 0 failed | PASS |
| AC-1 | manual | throwaway repo: `sprint-state.sh new` then `list` | `2026-09-11-001 drafting - - 0/0` | PASS |
| AC-2 | manual | throwaway repo: 2 stories added, 1 forced done, then `list` | `... 1/2` | PASS |
| AC-3 | manual | `sprint-state.sh list drafting` (filtered) | same 5 tab-separated fields as unfiltered | PASS |
| AC-4 | manual + fixtures | fields 1-4 (`sprint`, `status`, `claim-by`, `claim-at`) observed unchanged in all runs above; existing fixture assertions on those fields still pass | byte-identical | PASS |

All rows pass. No deviations.
