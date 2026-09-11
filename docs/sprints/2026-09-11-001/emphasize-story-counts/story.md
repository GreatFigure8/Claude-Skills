---
title: Emphasize story counts on a terminal
slug: emphasize-story-counts
sprint: 2026-09-11-001
kind: service
issue: 113
created: 2026-09-11T03:33:32Z
---

# Emphasize story counts on a terminal

## Statement
> As a user I want to make sure story counts are shown in large text.

A terminal has no font size, so "large" is read as visual emphasis: when `list` writes to a
TTY, the story-count field is rendered in ANSI bold; when piped or redirected, the output is
plain so scripts see exactly the text `list-story-counts` specifies.

## Requirements
1. R1 — The story count stands out from the other fields when a human reads `list` in a terminal.
2. R2 — Scripted consumers see no escape codes.

## Specification
- File: `Skills/dev-story-flow/assets/bin/sprint-state.sh`, function `cmd_list`.
- Determine styling once per invocation: styled when `sys.stdout.isatty()` is true, unless
  env `NO_COLOR` is set (any value) — the no-color.org convention. Env `DSF_FORCE_STYLE=1`
  forces styling on regardless of TTY (for tests and pagers).
- When styled, wrap field 5 only as `\033[1m<done>/<total>\033[0m`. Tabs between fields are
  outside the escape sequences. No other field is styled.
- Docs: one sentence in `references/sprint-state.md` under the helper, naming `NO_COLOR`
  and `DSF_FORCE_STYLE`.
- Tests: extend `assets/tests/sprint-state-fixtures.sh` — piped `list` contains no
  `\033`; `DSF_FORCE_STYLE=1 list` wraps field 5 in `\033[1m…\033[0m`; `NO_COLOR=1
  DSF_FORCE_STYLE=1 list` is plain. Add the TTY case to
  `assets/tests/sprint-state-list-integration.sh`: run `list` under a pseudo-terminal
  (python3 `pty.spawn` or `script -q`) and assert the escapes appear.

## Dependencies, risks, and breaking changes
- Depends on `list-story-counts` (field 5 must exist).
- Risk: styling leaking into piped output would break `cut`/`wc` consumers — mitigated by
  the isatty check and the piped-output test.
- macOS `script` flags differ from GNU; prefer python3 `pty` for the TTY test.

## Acceptance criteria
- AC-U: unit tests pass — `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` exits 0 with the three styling checks present.
- AC-I: integration — `bash Skills/dev-story-flow/assets/tests/sprint-state-list-integration.sh` exits 0, including the pseudo-terminal case.
- AC-1: `list | cat` contains no ESC (0x1b) bytes.
- AC-2: `DSF_FORCE_STYLE=1 list` renders field 5 as `ESC[1m<done>/<total>ESC[0m` and nothing else styled.
- AC-3: `NO_COLOR=1 DSF_FORCE_STYLE=1 list` is identical to `list | cat`.
- AC-4: under a pseudo-terminal, `list` output contains `ESC[1m`.

## Out of scope
- Colour choices beyond bold; themes; a header row.
- A separate banner/figlet-style `summary` subcommand.
- Any non-terminal surface.

## Open questions
Jonathan closed the sprint without choosing among the four readings offered; default taken:
- "Large text" = ANSI bold on a TTY (alternatives: block-letter banner subcommand; a UI
  surface, which would be an `interactive` story; something else).
