# auto-clear-prompt-at-stop — execution plan

Sprint: 2026-09-11-002   Story: auto-clear-prompt-at-stop   Kind: service

**Grounded** (read with `sed -n` / `grep -n`, this repo, branch `dev` @ `a27ebd0`):
`Skills/dev-epic-workflow/assets/claude-config/hooks/context-budget-gate.sh` (256 lines),
`hooks/session-end-guard.sh` (51), `hooks/session-start-context.sh` (720),
`settings-hooks.json` (90), `install.sh` (172),
`hooks/tests/context-budget-gate-fixtures.sh`, `hooks/tests/session-start-fixtures.sh`,
`hooks/tests/clear-prompt-filing-fixtures.sh`, `Skills/clear-prompt/SKILL.md` (141),
`Skills/dev-story-flow/SKILL.md` rule 10 (lines 94-97),
`Skills/dev-story-flow/references/dev-story-coder.md` (lines 49, 163, 186-195),
`Skills/dev-story-sprint/SKILL.md` (lines 20, 149-172, 210), `Skills/dev-story-flow/assets/`
(`bin/sprint-state.sh`, `tests/sprint-state-fixtures.sh`,
`tests/sprint-state-list-integration.sh`, `install.sh`), `.gitignore`, and the sibling story
`docs/sprints/2026-09-11-002/flow-stopping-point-160k/story.md`.
Stop-hook contract confirmed against the official hooks documentation
(https://code.claude.com/docs/en/hooks) via a `claude-code-guide` sub-agent (Sonnet 5).

**Assumed / corrections to the story's citations** — the repo wins where they disagree:

1. **`.gitignore` — verified, no work needed.** `.claude/signals/` is already ignored
   (under `# dev-epic-workflow runtime state (never committed)`). The story's "verify rather
   than assume" is discharged here; no item adds a rule. `install.sh` repo-mode already
   appends the same line (lines 141-150); user mode never touches `.gitignore` (lines 164-169)
   and does not need to.
2. **`session-end-guard.sh` has no "other per-session cleanup".** The story's §3 says the
   `handoff-stop-gate-<slug>` marker is "removed by `session-end-guard.sh` alongside its other
   per-session cleanup" — there is none. Worse, the guard `exit 0`s at **line 17** when the
   tree is clean, which is the common case at session end. Plan: the marker sweep goes in
   `session-end-guard.sh` **above** the `git rev-parse` / `DIRTY` checks (before line 14), so
   it runs on every session end, clean or dirty.
3. **The Stop-hook comment is at lines 4-6**, not line 5
   ("Deliberately NOT implemented as a Stop hook: Stop fires on every turn end and would fight
   normal iterative flow / risk hook loops"). Updated, not deleted, per the story.
4. **`UNIT` is not "the last path segment".** Real writers put exactly `.claude/stories/<slug>`
   (`dev-story-sprint/SKILL.md:77`) or `.claude/stories/<sprint>`
   (`dev-story-coder.md:49`) in `active-epic`, but the gate's own fixture writes
   `.claude/stories/context-budget-gate/status`. Plan: `UNIT` is the **segment immediately
   following `.claude/stories/`**, which is correct for both. In epic mode `active-epic` holds
   a bare `<NN>-<slug>` (`dev-epic-workflow/SKILL.md:165`), no `.claude/stories/` — that is
   exactly how the gate already picks `MODE=epic` (lines 159-170).
5. **`clear-prompt/SKILL.md` "never touches disk" appears once, on line 3** (frontmatter
   `description`). Line 25's table cell reads `Touches git/disk | Never` — different string,
   also rewritten. `clear-prompt-filing-fixtures.sh` pins one marker in that file, taken from
   **line 24** (`` `dev-story-sprint` mid-sprint, `dev-epic-workflow` right after filing,
   before anything is dispatched ``); line 24 must survive verbatim.
6. **Stop-hook contract (confirmed, not assumed).** stdin carries `session_id`,
   `transcript_path`, `cwd`, `hook_event_name`, `permission_mode`, `stop_hook_active`,
   `last_assistant_message`. To block: **top-level** `{"decision":"block","reason":"…"}` on
   stdout with **exit 0** (not nested under `hookSpecificOutput`). Exit 2 + stderr also blocks.
   `matcher` has **no meaning for `Stop`** and is omitted — the existing `SessionEnd` group in
   `settings-hooks.json` (lines 30-39) is the shape to copy. Claude Code hard-caps consecutive
   Stop blocks at 8 regardless; `stop_hook_active` is true while already continuing from a
   prior block. Non-JSON stdout on exit 0 is a non-blocking hook error, so every non-block path
   must print **nothing**.
7. **Lib location.** `install.sh` copies hooks into `$HOME/.claude/hooks` or
   `<repo>/.claude/hooks`, so the gate cannot find the lib by repo path. It resolves it from
   its own location — `LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` captured
   **before** the `cd "$CLAUDE_PROJECT_DIR"` at gate line 42.
8. **Depends on `flow-stopping-point-160k`** (same sprint, plan first, execute first). Every
   line number for the gate's stop band, `STOP` threshold and per-tool decision table refers to
   the gate **as that story leaves it**. Item 1 rebases onto that story's merge before starting.
9. `install.sh` line 73 prints `(8 scripts, executable)` — becomes 10.

## Items

| # | Branch | Scope / Done when / Not | Files owned | Wave | Model | Gates |
|---|---|---|---|---|---|---|
| 1 | `refactor/auto-clear-prompt-at-stop-budget-lib` | Extract `context-budget-lib.sh` from the gate — `session_slug_for()` (gate lines 99-106), `resolve_mode()` (158-170, sets `MODE`/`RULE`/`HANDOFF`/`DEF_*`), `resolve_thresholds()` (182-223, incl. story 1's `STOP`), `is_int()`, `read_sentinel()` — and source it from the gate. Pure extraction: **zero** behaviour change. Gate sources by absolute path resolved from `BASH_SOURCE` before its `cd`; a missing/unreadable lib → `exit 0` (house fail-open). `install.sh` gains the lib in the `cp` list (line 60-68) and the count in line 73 becomes 9. Done when: `context-budget-gate-fixtures.sh` passes unchanged, story 1's AC-3 golden-output case included. Not: any new text, the Stop hook, `settings-hooks.json`. | `hooks/context-budget-lib.sh` (new), `hooks/context-budget-gate.sh`, `hooks/tests/context-budget-gate-fixtures.sh`, `assets/claude-config/install.sh` | 1 | **Opus 5** | `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/context-budget-gate-fixtures.sh` |
| 2 | `feat/auto-clear-prompt-at-stop-gate-sentence` | Story §1. Add `handoff_sentence()` to `context-budget-lib.sh`: resolve `UNIT` (segment after `.claude/stories/` in `.claude/signals/active-epic`) and `CALLER` (`dev-story-flow <phase>` when `docs/sprints/<UNIT>/sprint.json` exists at the git top level, phase from its `status` mapped `planning→plan`, `executing→execute`, anything else → `dev-story-sprint`; else `dev-story-sprint`), returning the sprint sentence `Then call Skill({skill: "clear-prompt", args: "<CALLER> <UNIT>"}) — it posts the hand-off and clears this session.`, the epic sentence `Then write docs/epics/handoff.md per dev-epic-workflow's /handoff and commit it.`, or the existing `${HANDOFF}` wording when neither resolves. Gate appends it to the **stop-band `additionalContext`** and to the **hard-band stderr**. Soft-band text untouched. Done when: AC-4 and AC-7 fixture cases pass. Not: the Stop hook, `install.sh`, `settings-hooks.json`. | `hooks/context-budget-lib.sh`, `hooks/context-budget-gate.sh`, `hooks/tests/context-budget-gate-fixtures.sh` | 2 | Sonnet 5 | `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/context-budget-gate-fixtures.sh` |
| 3 | `feat/auto-clear-prompt-at-stop-session-start` | Story §4. In `session-start-context.sh`, beside the autosnapshot block (lines 64-78): when `.claude/signals/prep-for-clear-*.md` exist, print the **newest** under `### Prep-for-clear from the previous session`, fenced, then `rm -f` **every** one. In the same pass `rm -f .claude/signals/handoff-stop-gate-*` (§3's marker cleanup on `clear`; all of them — a cleared session gets a new `session_id`, so per-slug matching is impossible). Glob-safe (`nullglob`-free: test `[ -e "$f" ]`), never fails the session. Done when: the two new `session-start-fixtures.sh` cases pass and the suite's failure count is still 2 (the pre-existing ones). Not: the epic-queue section, the handoff injection, any other hook. | `hooks/session-start-context.sh`, `hooks/tests/session-start-fixtures.sh` | 2 | Sonnet 5 | `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/session-start-fixtures.sh` (failures must be exactly the 2 pre-existing) |
| 4 | `feat/auto-clear-prompt-at-stop-hook` | Story §3. New `handoff-stop-gate.sh` implementing the decision table verbatim, sourcing `context-budget-lib.sh` (items 1+2) and reusing `handoff_sentence()` for the reason, prefixed `This turn may not end yet:`. Epic-mode freshness compares `docs/epics/handoff.md` mtime to the sentinel's `epoch` via `date -r` → `stat -f %m` → `stat -c %Y`. Block writes the `handoff-stop-gate-<slug>` marker **first**, then top-level `{"decision":"block","reason":…}` on stdout, `exit 0`. Every other path: empty stdout, `exit 0`. jq → python3 → fail open. New fixture suite covering every table row, both modes, `full`/`nojq`/`bare` PATHs, and the once-per-session marker, modelled on `context-budget-gate-fixtures.sh` (`newproj`, `env -i`, sandbox `mktemp -d`). Done when: AC-1, AC-2, AC-3 cases pass. Not: registration, install, `clear-prompt`. | `hooks/handoff-stop-gate.sh` (new), `hooks/tests/handoff-stop-gate-fixtures.sh` (new) | 3 | **Opus 5** | `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/handoff-stop-gate-fixtures.sh` |
| 5 | `docs/auto-clear-prompt-at-stop-clear-prompt` | Story §2. `clear-prompt/SKILL.md` gains a final step, gated on the trigger being a token/context budget: write the posted block verbatim to `.claude/signals/prep-for-clear-<session-slug>.md` at the git top level (same slug derivation as the gate), then call `mcp__ccd_session_mgmt__clear_session` with `session_id: "self"` when available, else say `/clear` on one line. Rewrite line 3's "clear-prompt never touches disk or git", line 25's `Touches git/disk \| Never` cell, and line 135's "stateless markdown — no scripts" to describe the one gitignored file it now writes and why. Non-budget triggers keep today's behaviour. **Line 24 must survive verbatim** (pinned by `clear-prompt-filing-fixtures.sh`). Done when: AC-6 grep holds and the filing fixture still passes. Not: the template's fields, the resume section, any script. | `Skills/clear-prompt/SKILL.md` | 3 | Sonnet 5 | `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/clear-prompt-filing-fixtures.sh` |
| 6 | `feat/auto-clear-prompt-at-stop-register` | Story §5 + §3's marker cleanup. `settings-hooks.json`: new `Stop` block, **no `matcher` key**, one command `$CLAUDE_PROJECT_DIR/.claude/hooks/handoff-stop-gate.sh` (copy the `SessionEnd` group's shape, lines 30-39). `install.sh`: add `handoff-stop-gate.sh` to the `cp` list, line 73 count → 10; the existing python merge is already idempotent on command paths (lines 117-129), so verify rather than rewrite. `session-end-guard.sh`: `rm -f .claude/signals/handoff-stop-gate-*` inserted **before** line 14's `git rev-parse` guard, and the lines 4-6 comment rewritten to point at `handoff-stop-gate.sh` instead of saying a Stop hook was avoided. Done when: AC-5 holds. Not: hook logic, docs. | `assets/claude-config/settings-hooks.json`, `assets/claude-config/install.sh`, `hooks/session-end-guard.sh` | 4 | Sonnet 5 | AC-5 command below |
| 7 | `docs/auto-clear-prompt-at-stop-budget-sentences` | Story §5 last bullet. One sentence each into `Skills/dev-story-flow/SKILL.md` rule 10 (lines 94-97), `references/dev-story-coder.md` "Budget" (lines 186-195) and `Skills/dev-story-sprint/SKILL.md` budget section (lines 149-172): past the stop threshold the Stop hook will not let the turn end until `clear-prompt` has posted, and `clear-prompt` clears the session itself. Done when: `grep -n "Stop hook" ` finds it in all three. Not: thresholds, phase procedures (story 1 owns those), `clear-prompt/SKILL.md`. | `Skills/dev-story-flow/SKILL.md`, `Skills/dev-story-flow/references/dev-story-coder.md`, `Skills/dev-story-sprint/SKILL.md` | 4 | Sonnet 5 | AC-doc grep below |
| 8 | `test/auto-clear-prompt-at-stop-integration` | AC-I. New `Skills/dev-story-flow/assets/tests/handoff-stop-integration.sh` (conventions from `sprint-state-list-integration.sh`: `mktemp -d`, `git init -q`, `trap rm -rf`, no network). Temp `HOME` + temp repo, `install.sh --user`, sprint-mode `active-epic` + `context-usage-<slug>` sentinel at 160000, `docs/sprints/<UNIT>/sprint.json` in `executing`; run the **installed** `handoff-stop-gate.sh` with real Stop JSON → assert `block` whose reason contains `Skill({skill: "clear-prompt"`; write `prep-for-clear-<slug>.md` → assert allow; remove it → assert allow (marker); run `session-start-context.sh` with `{"source":"clear"}` → assert the block content is printed and the file gone. Done when: exits 0. Not: unit coverage (item 4 owns it). | `Skills/dev-story-flow/assets/tests/handoff-stop-integration.sh` (new) | 5 | Sonnet 5 | `bash Skills/dev-story-flow/assets/tests/handoff-stop-integration.sh` |

## Validation — how the coder proves each acceptance criterion

| AC | Check | Command | Pass when |
|---|---|---|---|
| AC-U | unit | `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/context-budget-gate-fixtures.sh && bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/handoff-stop-gate-fixtures.sh && bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh` | exit 0 |
| AC-U (b) | unit, pre-existing failures excluded | `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/session-start-fixtures.sh \| tail -1` | reads `failures: 2` and no failing case name contains `prep-for-clear` |
| AC-I | integration | `bash Skills/dev-story-flow/assets/tests/handoff-stop-integration.sh` | exit 0 |
| AC-1 | unit (item 4 fixture case `A`) | `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/handoff-stop-gate-fixtures.sh 2>&1 \| grep -c 'FAIL.*AC-1'` | `0`, and the suite's own `A:` cases assert stdout parses to `.decision == "block"` with `.reason` containing `dev-story-flow execute` |
| AC-2 | unit (item 4 fixture cases `B1`-`B5`) | `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/handoff-stop-gate-fixtures.sh` | exit 0; each of 159999 / stale sentinel / missing sentinel / `stop_hook_active:true` / marker present asserts `exit 0` **and** empty stdout |
| AC-3 | unit (item 4 fixture cases `C1`,`C2`) | `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/handoff-stop-gate-fixtures.sh` | exit 0; epic mode at 150000 with no `docs/epics/handoff.md` blocks with the `docs/epics/handoff.md per dev-epic-workflow's /handoff` sentence; with `handoff.md` mtime > sentinel `epoch` it allows silently |
| AC-4 | unit (item 2 fixture cases) | `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/context-budget-gate-fixtures.sh` | exit 0; the stop-band `additionalContext` at 160000 ends with `Skill({skill: "clear-prompt", args: "dev-story-sprint <UNIT>"})` with no matching manifest and `…"dev-story-flow execute <UNIT>"})` with one |
| AC-5 | install idempotence | `H="$(mktemp -d)"; HOME="$H" bash Skills/dev-epic-workflow/assets/claude-config/install.sh --user >/dev/null && cp "$H/.claude/settings.json" "$H/first.json" && HOME="$H" bash Skills/dev-epic-workflow/assets/claude-config/install.sh --user >/dev/null && diff -q "$H/first.json" "$H/.claude/settings.json" && python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));g=d["hooks"]["Stop"];assert sum(1 for x in g for h in x.get("hooks",[]) if h["command"].endswith("handoff-stop-gate.sh"))==1, g;assert all("matcher" not in x for x in g), g' "$H/.claude/settings.json" && test -x "$H/.claude/hooks/handoff-stop-gate.sh" && test -f "$H/.claude/hooks/context-budget-lib.sh"; rc=$?; rm -rf "$H"; exit $rc` | exit 0 |
| AC-6 | doc grep | `grep -n "touches disk" Skills/clear-prompt/SKILL.md` | exactly one line, and it describes the sentinel write rather than claiming the skill never touches disk; `grep -c "never touches disk or git" Skills/clear-prompt/SKILL.md` is `0`; `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/clear-prompt-filing-fixtures.sh` exits 0 |
| AC-7 | golden output after extraction | `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/context-budget-gate-fixtures.sh 2>&1 \| grep -i 'golden'` | every golden-output case from `flow-stopping-point-160k` reports `PASS`, and the suite exits 0 |
| AC-doc | doc grep (item 7) | `grep -ln "Stop hook" Skills/dev-story-flow/SKILL.md Skills/dev-story-flow/references/dev-story-coder.md Skills/dev-story-sprint/SKILL.md \| wc -l` | `3` |

## Order and dependencies

- **Whole story lands after `flow-stopping-point-160k`** (same sprint). Item 1 starts only
  once that story is merged to the integration branch; every gate line number above is
  post-merge.
- Wave 1: **1**. Wave 2: **2** (needs 1's lib), **3** (independent files).
  Wave 3: **4** (needs 1+2 for the lib and `handoff_sentence()`), **5** (independent file).
  Wave 4: **6** (needs 4's script to exist), **7** (independent files).
  Wave 5: **8** (needs 4 and 6 — it runs the installed hooks).
- **§4 before §2 step 2**, as the story requires: item 3 (session-start surfacing) is wave 2,
  item 5 (clear-prompt's self-clear) is wave 3. The block can never be lost to a self-clear.
- No two items in the same wave own a file. `context-budget-gate.sh` and
  `context-budget-gate-fixtures.sh` are touched by items 1 and 2, in different waves;
  `install.sh` by items 1 and 6, in different waves.

## Risks and gotchas

- **First Stop hook in the repo, installed user-level, fires in every repo on the machine.**
  Every non-block path must exit 0 with *empty* stdout — non-JSON stdout on a Stop hook is
  reported as a hook error in the transcript. The `bare` PATH variant (no jq, no python3) must
  be proven silent.
- **Loop safety is triple**: `stop_hook_active`, the once-per-session marker, and Claude
  Code's own 8-block cap. The marker is written *before* stdout so a crash mid-print cannot
  produce a second block.
- **Marker cleanup is the failure mode that wedges nothing but disables the hook.** A marker
  left behind silently exempts a session forever. `session-end-guard.sh` must sweep it above
  its clean-tree `exit 0` (line 17) — that early return is why the story's "alongside its other
  per-session cleanup" does not work as written.
- **Lib extraction is the highest-risk item.** The gate serves three orchestrators; epic-mode
  output must stay byte-identical. Sourcing must not leak `set -e`, must not re-`cd`, and must
  preserve the exact `exit 0` points (every `is_int … || exit 0` currently exits the *gate*, so
  the lib's helpers must return status and let the gate decide, or use a shared `fail_open`).
- **mtime portability**: BSD (`stat -f %m`, `date -r`) vs GNU (`stat -c %Y`). Try in order, and
  fail open if none work.
- **`clear_session` is desktop-only.** CLI sessions get the one-line `/clear`; item 5 must not
  imply the MCP tool always exists.
- **`clear-prompt-filing-fixtures.sh` pins line 24** of `clear-prompt/SKILL.md`. Item 5 edits
  lines 3, 25 and 135 and must leave 24 byte-identical.
- **`session-start-fixtures.sh` already has 2 failures** on `dev` today. The gate is "still
  exactly 2, none of them mine", not "exit 0".
- **Install is a copy, not a symlink.** Nothing here is live on this machine until
  `install.sh --user` is re-run; item 8 runs the repo copy through a temp `HOME`, so it does
  not depend on the machine's install.

## Open questions

none — the story's Q1-Q6 are answered "yes to all" and its carried assumptions are adopted as
written, except the four citation corrections recorded under *Assumed* above, which follow the
repo.
