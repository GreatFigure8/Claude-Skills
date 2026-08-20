# Session Handoff — 06-runner-conformance / work item 1

**Written:** 2026-08-20T12:40:04Z
**Branch:** main (pushed: yes)
**Last commit:** ec695df Merge pull request #33 from GreatFigure8/feat/intake-config-visibility
**Worktree:** /Users/jonathanstevenson/Source/claude-skills

## Verified this session
- Epic 06 item 1 merged as PR #24. Guards re-run after the change: missing credential `rc=3`, 0644 `rc=3`, empty token `rc=3`, missing binary `rc=1`, lock held `rc=2`, dry-run `rc=0`.
- GH #22 fixed and proven live: two issues labelled at once produced two proposals with distinct folders (`proposed-15-…`, `proposed-12-…`, PRs #25/#26). No epic number is claimed at draft time.
- GH #23 fixed and verified: repo list honoured, missing list falls back, bogus entry skipped without aborting (first or last), per-repo base resolution `claude-skills base=main` / `Oracle-Simple-Convert base=dev`.
- GH #27 fixed (PR #28): runner no longer runs `git switch`/`git pull` in the target checkout. Confirmed LODE stayed on `dev` after a dry-run.
- GH #31 fixed (PR #32): `~/Source` is the only directory the runner creates in; nonexistent root produces a logged skip.
- GH #29 built, merged (PR #33) and **installed**; all four states run from `~/.claude/hooks/`: listed+explicit base, listed+default base, not listed, never-configured (silent, output byte-identical to main's copy).
- GH #30 closed as not-a-defect by direct test: `claude -p` in a directory with no `~/.claude.json` entry returned `rc=0`, correct stdout, empty stderr — headless runs do not raise the trust dialog.
- The `2.1.220` entry in macOS privacy settings is the Claude Code CLI binary (`Identifier=com.anthropic.claude-code`, bare Mach-O). The desktop app is a different identifier (`com.anthropic.claudefordesktop`).

## Claimed but NOT yet verified
- Epic 06's plan still reads `Status: in flight (item 1 of 1)` though its only item merged. The epic was never formally closed and has no retro.
- GH #27, #31 and #29 were built and merged **without epic plans** — filed as issues, fixed directly under time pressure. That deviates from Phase 1 and is unreconciled.
- The `**armed**` wording of the new session-start line has not been seen from the *installed* hook (only from the branch copy). The agent is loaded now, so a fresh session should show it.
- Runner executes on CLI **2.1.220**; the desktop app is on **2.1.234**. Skew unexamined.
- Quality of unattended-drafted plans (PRs #25, #26) has not been reviewed by anyone.

## In-flight (debugging / hypothesis state)
- **An unattended intake run is ACTIVE right now** (pid seen at checkpoint), draining 7 LODE issues: `731 730 729 728 727 726 725`, all still labelled, 0 proposal PRs created so far. It began at 12:35:56Z on #731. Expect ~20–45 min, one PR per issue against `dev`, each label removed as it completes.
- If interrupted, unprocessed issues keep their labels and the next poll resumes them. A killed run can leave an orphaned worktree under `~/Source/Oracle-Simple-Convert-proposed-*` and a stale `~/.config/claude-intake/.lock`.

## Exact next action
- Let the LODE run finish, then review the 7 proposal PRs against `dev` and close epic 06 with a retro.

## Environment state
- launchd agent `com.jonathanstevenson.unattended-intake` is **LOADED** and polling every 30 minutes. Unload with `launchctl unload ~/Library/LaunchAgents/com.jonathanstevenson.unattended-intake.plist`.
- `~/.config/claude-intake/repos` lists `~/Source/claude-skills` and `~/Source/Oracle-Simple-Convert|dev`.
- `~/.config/claude-intake/env` holds a subscription-backed `CLAUDE_CODE_OAUTH_TOKEN` (mode 600). Not the Keychain, not an API key.
- `claude-intake` label exists in both repos. All 7 LODE issues currently carry it.
- The Mac is **not** kept awake by the agent — no `caffeinate` wrapper. Sleep pauses the drain until wake.
- Jonathan has macOS privacy grants to review under Privacy & Security; nothing in this workflow needs them, since all writes are confined to `~/Source`.

## Open questions for Jonathan
- Close epic 06 with a retro, or fold the unplanned fixes (#27, #31, #29) into it first so the record matches what was built?
- Keep the agent loaded, or unload it after the LODE drain?
