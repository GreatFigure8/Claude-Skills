# Runbook — the session-scoped issue loop

Operational how-to for `bin/session-loop.sh` and the `/loop` command (epic 21,
`docs/epics/21-session-scoped-issue-loop/`). This is a runbook: it tells you how to
start it, watch it, and stop it. The contract — what each action means and why the
brake sits where it sits — is `Skills/dev-epic-workflow/references/session-loop.md`;
read that first if something here is ambiguous. Everything below is checked against
the merged code from items 1–5 (PRs #106–#110), not against the plan's prose.

**Live-proof status:** this runbook documents the machinery as merged. The epic's
own definition of done for item 6 also requires one real end-to-end run on
`claude-skills` — draft, dispatch, verify, harm-check, merge, chain, close, with a
seeded failure filed and deduplicated — inspected directly on GitHub. That run has
**not** happened yet; it is a separate, explicitly-authorized step (see
`docs/epics/21-session-scoped-issue-loop/plan.md`, item 6) and nothing in this
document should be read as claiming it occurred.

## What the loop is, in one paragraph

Jonathan opens a live Claude Code session, names one repo, and says "start the
loop." From that point the session itself — not a daemon, not a subprocess chain,
not an API-keyed background process — continuously works admitted GitHub issues
end to end: draft a plan from the issue, dispatch each work item through the
existing orchestrated `work-item-executor` path, verify it, run the harm floor,
merge, chain to the next item and then the next issue, close out, and repeat.
**Starting the loop is the grant of full autonomy for that session and that
repo** — there is no approval stop between draft and dispatch. The only in-flight
brake is the harm floor, checked before every merge and every chain, with no
exception.

`bin/session-loop.sh` is deliberately **not headless**: it never invokes `claude`
(no `CLAUDE_BIN`, no `-p`, no subprocess spawn — a fixture greps the file to keep
this true). It only ever runs inside a live, already-authenticated interactive
session, through the session's own `Agent`-tool dispatches.

## Starting the loop

```
/loop <repo>              # or: "start the loop on <repo>"
```

or by hand:

```
git remote get-url origin && gh auth status     # GitHub only — every admission,
                                                 # dispatch and close path uses gh
Skills/dev-epic-workflow/assets/claude-config/bin/session-loop.sh --start --repo <path>
Skills/dev-epic-workflow/assets/claude-config/bin/session-loop.sh --admit --repo <path>
```

`--start` binds the loop to **one** checkout for this session. A second `--start`
naming a **different** repo while another loop is bound is refused — one loop, one
repo, one live session, by name, not by accident. The binding marker lives at
`~/.config/claude-intake/session-loop` (outside any repo, so a second repo's
`--start` can see it) and a session that finished cleanly clears it on `--stop`; a
stale marker left by a session that died is treated the same way (its own record's
`state` will not say `running`, so a new `--start` is not refused by a ghost).

Before committing to the turn cycle, the session states in one line — a
statement, not a question — the repo, how many issues are admitted, and that it
will merge and chain without asking again.

## Previewing it, without starting anything

```
session-loop.sh --next --repo <path> --dry-run
```

Prints the projected happy path for every currently-admitted issue: which are
admitted, which are parked and why, and where the harm floor would gate each merge
and chain. This is **a preview of the shape, not a claim about permission** — the
floor runs for real at every merge and chain and can refuse any step of it. It
writes nothing.

## The turn cycle, once started

Each turn does exactly one of these, in order, and nothing else:

1. `session-loop.sh --next --repo <path>` — prints one `action` plus its `reason`,
   `wake-in` (seconds) and whatever context that action needs (`issue`, `epic`,
   `plan`, `item`, `branch`, `pr`, `command`). For any action that is not `poll` or
   `stop`, the harm floor has **already cleared it** at the moment it was printed.
2. Perform exactly that action (see the action table below).
3. `session-loop.sh --record --repo <path> --issue N --state <s> [--item I]
   [--branch B] --detail "<what happened>"` — this is what advances the per-issue
   state machine; `--next` reads nothing else.
4. Call `ScheduleWakeup` with the `wake-in` delay the driver printed, and end the
   turn. A blocking `sleep` in Bash is never used here — it burns the turn and
   can't be interrupted by a typed stop; a scheduled wakeup can be.

### The actions

| action | what happens |
|---|---|
| `draft` | An admitted issue has no epic yet. Dispatch one `sonnet` drafting subagent per `references/issue-intake.md`'s Unattended intake brief, reusing the same Phase 0 grounding, plan template, and `**Touches:**` rule — but filed straight at `**Status:** approved` (starting the loop *is* the approval, so there's no proposal PR), and item 1 is dispatched in the same turn. A `no-work` or `needs-decision` recommendation is never auto-approved or auto-closed — the issue is recorded `parked`, the recommendation is commented on it, and the loop moves to the next admitted issue. |
| `dispatch` | The existing orchestrated path, unchanged: `work-item-executor` runs in its own worktree (`isolation: "worktree"`) and stops at `pr-opened` — the loop never asks it to merge. An executor that returns `blocked` is recorded `blocked` and chained past, never retried. If the `status.json` detail names a gate failure out of the item's own scope, it is filed via `issue-filer.sh` (see below) instead of only being quoted. |
| `verify` | The driver has already run the four deterministic gates (PR open, declared-paths gate, `gh pr checks` green, diff clears the denylist). What remains is a **cold** `acceptance-verifier` (`model: "opus"`) judging the plan's DoD against the real diff, with no memory of the executor that wrote it. `pass` → `verified`. `fail` → `blocked`, verdict commented on the PR, chained past — never auto-retried. |
| `merge` | Reached only once the item is `verified` **and** the harm floor has cleared the real diff (`git diff --name-only <integration>...<branch>`, fed to the floor as real paths — an unresolvable range or a zero-file diff refuses rather than passing trivially). Merge commit into the integration branch (never a rebase), then land-and-reset: pull, delete the branch remotely and locally, remove the worktree, prune, tick the tracker checklist. |
| `integration-test` | Once every work item of the issue has merged, one command runs before `close` (never per item): a declared `integration-test` command wins; where none is declared, the repo's own declared `gates.*` run instead, in declaration order; where neither is declared, the driver says so and moves straight to `close` in the same turn — a known, recorded gap, never an invented check. A `fail` is filed **first**, then recorded — filing never blocks the record or the chain to `close`. |
| `close` | Every item merged and the integration check settled (or silently not applicable). Plan header → `**Status:** closed`, control-plane scaffolding cleaned, retro written, tracker issue closed. Releases the loop's active issue so the next `--next` chains to the next admitted one. |
| `poll` | Nothing is ready yet (an executor is still running, or no admitted issue is workable). Long wakeup, no action taken — polling is not idling, the loop keeps watching until told to stop. |
| `blocked` | One harm-floor guard refused one action — a denylist hit, a size ceiling, a cross-epic branch collision, an irreversible git op against a shared branch. The PR (if any) is left open for a human, the issue is recorded `blocked`, and the loop chains to the next admitted issue. This is **not** the same event as `halt`. |
| `halt` | `STOP` is present (see Stopping below). The loop stops entirely: report it in one line and schedule no further wakeup. |

## What the harm floor checks, and when

The harm floor is `autonomy_harm_check()` in `bin/autonomy.sh` (epic 21 item 2),
called from `session-loop.sh` before it will ever name a `merge`, a `dispatch`
(chain), or a `close` — never as a courtesy the live session is trusted to
remember, but as the reason the driver refuses to print those actions at all when
a guard fires. It combines five deterministic guards, checked cheapest/most
decisive first, with no LLM judgement anywhere in it:

1. **STOP** — `~/.config/claude-intake/STOP` exists. Checked first, before
   anything else is read from GitHub or the repo. This is the one that maps to
   `halt` rather than `blocked`.
2. **Irreversible git op** — refuses a `push --force`/`--force-with-lease` or a
   `reset --hard` whose target branch already exists on `origin` (shared
   history). A branch nobody has pushed yet isn't shared and this guard has
   nothing to say about it — rewriting history nobody else can see isn't the
   harm this floor exists to stop.
3. **Cross-epic collision** — refuses acting on a branch that another *still
   in-flight* epic's own `status/` directory already claims (a closed epic's old
   status files are history, not a live claim). A worktree is identified by its
   branch, so a branch collision is a worktree collision here.
4. **Denylist** — refuses when the diff touches a path matching the built-in
   floor (`.github/*`, `.circleci/*`, other CI configs, `install.sh` anywhere in
   the tree, `*/claude-config/bin/*`, `*/claude-config/hooks/*`,
   `.claude/settings*.json`, `*.plist`, and the credential classes: `.env`,
   `*.pem`, `*.key`, `*.p12`, `id_rsa*`, `*/secrets/*`, `.npmrc`, `.netrc`) —
   or a repo-declared addition to it. **There is no config key that shrinks this
   floor**, only ones that add to it. An empty/unreadable diff is treated as a
   **missing** check, not a passed one — the merge action refuses outright
   rather than harm-checking against nothing.
5. **Size ceiling** — refuses when a repo-declared file or line-count ceiling is
   exceeded.

**Known consequence, stated once because it recurs constantly on this repo
specifically:** the denylist floor covers `*/claude-config/bin/*` and
`*/claude-config/hooks/*` — this control plane's own code. Any work item whose
diff touches those paths is refused at `merge` and left for a human. On
`claude-skills`, whose entire content *is* this control plane, that is the common
case, not the exception — correct behaviour (autonomous machinery that can rewrite
its own brakes has none), but it means a live-proof run on this repo needs an
issue whose diff stays outside those paths.

## What gets auto-filed, and why

`bin/issue-filer.sh` (epic 21 item 4) is the deterministic half of "a gate failure
out of the current item's own scope becomes a filed GitHub issue instead of the
loop stopping to ask." It is called from exactly two places in
`session-loop.md`'s action contract — `dispatch`'s `blocked` handling (an
executor's gate failure that is out of that item's scope) and
`integration-test`'s `fail` handling (a post-merge, pre-close check) — never from
inside `session-loop.sh` itself; the judgement of *which* failures are out of
scope stays with whichever live session discovered them.

```
issue-filer.sh --file --repo <path> --issue <N> --item <I> \
  --check "<failing check name>" --evidence "<the check's own failure output>"
```

What it does, and only this:

1. **Fingerprints** the trimmed `<check>\x1e<evidence>` pair with `cksum` (not a
   security boundary — a dedup key against accidental repeats, using a tool
   guaranteed present rather than one that may not be installed).
2. **Searches** open issues labelled `epic-loop-filed` for a body containing
   `<!-- epic-loop-fingerprint: <hex> -->` matching that fingerprint. A match
   means `skip #<n> ...` and nothing is created. A `gh` failure during the search
   is a **refusal** (exit 2), never read as "nothing to dedupe against" — that
   distinction exists so a flaky `gh` call on the exact wrong turn can't file a
   duplicate.
3. **Files**, only on no match: `gh issue create` with a body naming the
   discovering issue and item, the failing check, the evidence verbatim in a code
   block, and the fingerprint marker — labelled `epic-loop-filed`.

Filing is the **terminal** action. This tool never fixes what it just filed; the
fix is a future loop cycle picking up the new issue as its own admitted work —
which requires a human to add the admission label and requirements/acceptance
criteria to it first (see Deferred, below): `epic-loop-filed` alone does not make
an issue loop-pickable.

## Admission — what the loop is allowed to touch

An issue is **admitted** only when both hold, checked by the driver against the
issue itself, never assumed from a label alone:

1. it carries the **`epic-loop-ready`** label — the same constant the
   `author-issue` skill applies to everything it files
   (`Skills/author-issue/references/trackers.md`); and
2. its **body** carries a `Requirements` heading and an `Acceptance criteria`
   heading (matched on text, any heading style — `###`, `##`, or `**Bold:**` —
   because a hand-written issue won't match a specific level), each followed by
   at least two non-blank lines of real content before the next heading.

Both, because the label is a **claim** and the body is the **evidence**. Claude's
own `Derived acceptance criteria` heading is explicitly excluded from matching
`Acceptance criteria` — admitting on it would let the machine satisfy its own
admission test. The `## Loop admission` checkboxes some issue bodies carry are
self-reported documentation, never the gate itself.

An issue failing either half is **parked, not executed**: the loop steps over it
and keeps going. Nothing is silently ignored — `--admit` prints the reason for
every open labelled issue, and `--next --dry-run` shows the same.

```
session-loop.sh --admit --repo <path>            # every open labelled issue, admitted/parked + why
session-loop.sh --admit --repo <path> --issue N  # one issue's verdict
```

## Stopping

Any of these halts the loop **before its next action** — everything already
pushed stays safe, because the executor pushes on its first commit:

- Jonathan says stop (spoken or typed, any phrasing). The session runs
  `session-loop.sh --stop --repo <path>` and stops scheduling wakeups.
- `session-loop.sh --stop --repo <path>` run from any other terminal.
- `~/.config/claude-intake/STOP` exists — the harm floor refuses everything and
  `--next` answers `halt` rather than `blocked`.
- The session ends or the client closes. The loop is session-scoped; it dies with
  the session, by design — there is no daemon to keep it alive past that.

```
session-loop.sh --status --repo <path>     # loop state + active issue's state
session-loop.sh --stop   --repo <path>     # request a clean stop
```

A clean stop states in one line exactly where things stand: last action, the
active issue, and any PR left open for a human.

## What this loop never does

- Runs headless or unattended — retired in item 1, not reintroduced. It only ever
  runs inside a live, already-authenticated interactive session that itself calls
  it, turn by turn.
- Loops two repos from one session, or two sessions against one repo (the
  machine-wide binding marker enforces the second half of that even though it
  can't see which session called it).
- Resolves a `needs-decision`, or closes a `no-work` recommendation.
- Retries a failed verifier verdict or a blocked executor.
- Merges without the harm floor. There is no flag, label, or issue body field
  that turns it off.
- Introduces an API key, a daemon, a launchd job, or a promotion-ladder record —
  all three were retired by this same epic (item 1), not carried forward.

## Where the code actually lives

- `Skills/dev-epic-workflow/assets/claude-config/bin/session-loop.sh` — the
  deterministic driver (`--start`/`--status`/`--admit`/`--next`/`--record`/`--stop`).
- `Skills/dev-epic-workflow/assets/claude-config/bin/issue-filer.sh` — fingerprint-
  deduplicated failure filing.
- `Skills/dev-epic-workflow/assets/claude-config/bin/autonomy.sh` —
  `autonomy_harm_check`, the harm floor, plus the denylist floor and size ceiling
  it draws on.
- `Skills/dev-epic-workflow/assets/claude-config/commands/loop.md` — the `/loop`
  entry point a session runs.
- `Skills/dev-epic-workflow/assets/claude-config/hooks/tests/session-loop-fixtures.sh`
  and `issue-filer-fixtures.sh` — the fixture suites.
- `Skills/dev-epic-workflow/references/session-loop.md` — the full contract this
  runbook summarizes operationally; read it for the *why* behind any line above.
