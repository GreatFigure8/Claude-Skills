---
title: Show story counts in sprint-state list
slug: list-story-counts
sprint: 2026-09-11-001
kind: service
issue: 112
created: 2026-09-11T03:33:32Z
---

# Show story counts in sprint-state list

## Statement
> As a user, I want the sprint-state list to show story counts.

`sprint-state.sh list` currently prints one tab-separated line per sprint: name, status,
claim-by, claim-at. Add a fifth column giving the story count as `done/total`, so a reader
sees at a glance how much of each sprint is finished without opening the manifest.

## Requirements
1. R1 — `list` shows a story count for every sprint it prints.
2. R2 — `list <status>` filtering shows the same count column.

## Specification
- File: `Skills/dev-story-flow/assets/bin/sprint-state.sh`, function `cmd_list`.
- Append a fifth tab-separated field: `<done>/<total>`, where `total = len(m["stories"])`
  and `done` is the number of stories whose `status == "done"`. A sprint with no stories
  prints `0/0`.
- Output stays header-less and tab-separated; fields 1–4 are unchanged, so existing consumers
  (`cut -f1`, `wc -l` in the phase docs) keep working.
- `get`, `set`, `story`, `stale`, `new` output does not change.
- Docs: update the helper section of `Skills/dev-story-flow/references/sprint-state.md` to
  list the five columns.
- Tests: extend `assets/tests/sprint-state-fixtures.sh` with checks that the fifth field is
  `0/0` for a new sprint, `0/2` after two stories are added, and `1/2` after one is forced
  to `done`. Add `assets/tests/sprint-state-list-integration.sh`, which runs the script from
  a throwaway git repo through new → story add ×2 → story set done → `list` and asserts the
  exact line, and which is invoked by the existing fixture runner pattern (exit 0 = pass).

## Dependencies, risks, and breaking changes
- Appending a column is additive; nothing parses field 5 today. No breaking change.
- Story `emphasize-story-counts` in this sprint depends on this one (it styles field 5).
- No new dependencies; python3 only, as today.

## Acceptance criteria
- AC-U: unit tests pass — `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` exits 0 with the three new count checks present.
- AC-I: integration — `bash Skills/dev-story-flow/assets/tests/sprint-state-list-integration.sh` exits 0, having run the real script in a throwaway repo and matched `list` output field-for-field.
- AC-1: `list` on a sprint with no stories ends the line with `0/0`.
- AC-2: `list` on a sprint with two stories, one `done`, ends the line with `1/2`.
- AC-3: `list planned` (filtered) prints the same five fields as unfiltered.
- AC-4: fields 1–4 are byte-identical to today's output for the same manifest.

## Out of scope
- Header rows, colour, or emphasis (see `emphasize-story-counts`).
- Per-status breakdowns (executing/blocked counts).
- Any change to `get` or other subcommands.

## Open questions
Jonathan closed the sprint without answering the intake round; defaults taken:
- Count format: `done/total` (alternatives: total only; per-status breakdown).
- Column position: appended as field 5 (alternative: after status).
- Header: none (alternative: header row).
- Zero stories: `0/0` (alternative: `-`).
