# Item 1 findings — does L2's headless invocation fire Claude Code CLI hooks?

**Run date:** 2026-08-27/28 (local -0500 / UTC as shown in raw output below)
**HEAD at time of this run's start:** `440425b69b1e1da47d7436873fed74c179b74106` (docs(epic-16) filing commit)
**REPO_ROOT resolution:**

```
$ git rev-parse --path-format=absolute --git-common-dir
/Users/jonathanstevenson/Source/claude-skills/.git
```

REPO_ROOT = `/Users/jonathanstevenson/Source/claude-skills`

## 0. Important caveat about what this run actually is (raw, unresolved)

The dispatch text asserted this invocation used the exact `claude -p --agent
work-item-executor --model sonnet --add-dir <skill> --allowed-tools <list>` command-line
shape that `dispatch.sh` uses for L2. This executor did **not** independently verify that
claim — it was told, not observed launching itself. What this executor *can* observe about
its own process is its environment, which is not obviously consistent with a standalone
headless `claude -p` subprocess:

```
$ env | grep -iE '^CLAUDE|^AGENT|^SESSION'
CLAUDE_AGENT_SDK_VERSION=0.3.246
CLAUDE_CODE_ENTRYPOINT=claude-desktop
CLAUDE_CODE_OAUTH_SCOPES=user:inference user:file_upload user:profile user:sessions:claude_code
CLAUDE_CODE_ENABLE_ASK_USER_QUESTION_TOOL=true
CLAUDE_CODE_EMIT_TOOL_USE_SUMMARIES=false
CLAUDE_CODE_DISABLE_CRON=
CLAUDE_CODE_EAGER_FLUSH=1
CLAUDE_CODE_REPORT_FINDINGS=1
CLAUDE_PREVIEW_CLASSIFIER_FLOOR=1
CLAUDE_CODE_HOST_SESSION_ID=local_ba2e549e-090b-4abc-a244-4f180815f008
CLAUDE_CODE_SDK_HAS_OAUTH_REFRESH=1
CLAUDE_CODE_SDK_HAS_HOST_AUTH_REFRESH=1
CLAUDECODE=1
CLAUDE_CODE_SESSION_ID=058d1969-4cb8-4677-a590-b85afea66b02
CLAUDE_CODE_CHILD_SESSION=1
CLAUDE_PID=55927
CLAUDE_EFFORT=high
CLAUDE_CODE_AGENT=work-item-executor
CLAUDE_CODE_MESSAGING_SOCKET=/tmp/cc-socks/55927.sock
CLAUDE_CODE_MESSAGING_TOKEN=1c7fa60d101864fc31cd733ae0381ea4
```

`CLAUDE_CODE_ENTRYPOINT=claude-desktop`, `CLAUDE_CODE_CHILD_SESSION=1`, and a live
`CLAUDE_CODE_MESSAGING_SOCKET`/`CLAUDE_CODE_MESSAGING_TOKEN` pair (a socket back to a parent
process) are what this executor observed directly. It does not know what these fields look
like under a genuine `claude -p --agent` subprocess launched by `dispatch.sh` outside any
Desktop/parent session, because it has never run in that shape to compare against. Recorded
as a raw fact, not resolved: **this run may be the interactive/orchestrated (Task/Agent-tool)
path wearing the work-item-executor prompt, rather than L2's actual standalone headless
subprocess.** If so, this run cannot settle item 1's question by itself — it would need
comparing against a genuinely detached `claude -p` invocation (no parent Desktop session, no
messaging socket) to know for sure.

## 1. status.json — read back verbatim after this executor's own write

Path:
```
/Users/jonathanstevenson/Source/claude-skills/docs/epics/16-l2-custom-loop-narration-fix/status/chore-verify-l2-hook-firing.json
```

Content, read back exactly as written by this executor (via plain `mv`, not a hook):

```json
{
  "item": "1 - Verify L2 hook firing today",
  "branch": "chore/verify-l2-hook-firing",
  "state": "grounding",
  "detail": "Read plan.md; starting inspection of hook evidence for this headless invocation",
  "commit": null,
  "updated": "2026-08-27T00:00:00Z"
}
```

**No `agent_id` field. No `terminal` field.** This executor wrote every key present; nothing
was added by a hook as of this read.

Important limitation on this observation: per `subagent-lifecycle.sh`, `terminal` and
`agent_id` are stamped by the **SubagentStop** hook, which (by definition) fires when this
agent's turn ends — i.e., after this executor has already returned control. This executor
cannot observe its own SubagentStop stamping by reading its own status file mid-run; only the
orchestrator, reading the file *after* this run ends, can see whether that stamp lands. This
findings file should be re-checked externally after this run's SubagentStop fires (or doesn't)
to complete this half of the picture.

## 2. Full listing of the status/ directory

```
$ ls -la /Users/jonathanstevenson/Source/claude-skills/docs/epics/16-l2-custom-loop-narration-fix/status/
total 16
drwxr-xr-x@ 5 jonathanstevenson  staff  160 Aug 27 21:01 .
drwxr-xr-x@ 4 jonathanstevenson  staff  128 Aug 27 21:00 ..
drwxr-xr-x@ 2 jonathanstevenson  staff   64 Aug 27 21:00 .agents
-rw-r--r--@ 1 jonathanstevenson  staff  147 Aug 27 21:00 agent-a7b0d0e00e1204251.log
-rw-------@ 1 jonathanstevenson  staff  265 Aug 27 21:01 chore-verify-l2-hook-firing.json
```

**Yes — an `agent-<id>.log` file exists**: `agent-a7b0d0e00e1204251.log`, timestamped one
minute *before* this executor's own first status write, and before this executor made any
tool call. This executor did not create it.

The `.agents/` subdirectory referenced by `subagent-lifecycle.sh` (as the location of
per-agent "owner" records, `.agents/<agent-id>.json`) exists but is **empty**:

```
$ ls -la /Users/jonathanstevenson/Source/claude-skills/docs/epics/16-l2-custom-loop-narration-fix/status/.agents
total 0
drwxr-xr-x@ 2 jonathanstevenson  staff   64 Aug 27 21:00 .
drwxr-xr-x@ 2 jonathanstevenson  staff   64 Aug 27 21:00 ..
```

## 3. Content of the agent-<id>.log file

```
$ cat /Users/jonathanstevenson/Source/claude-skills/docs/epics/16-l2-custom-loop-narration-fix/status/agent-a7b0d0e00e1204251.log
2026-08-28T02:00:56Z | ── SUBAGENT STOP  (a7b0d0e00e1204251) on branch main — no SubagentStart record for this agent; nothing stamped ──
```

Interpretation, stated as inference (not observation): this is a `SubagentStop` event that
the `subagent-lifecycle.sh` hook processed (proving the hook script itself executed and wrote
a log line) for an agent id (`a7b0d0e00e1204251`) that has **no matching `.agents/<id>.json`
owner record** — hence "nothing stamped." The timestamp (2026-08-28T02:00:56Z / Aug 27
21:00:56 local) lands almost exactly at the epic-16 filing commit's timestamp
(`440425b`, `2026-08-27 21:00:08 -0500`) and on `branch main`, not
`chore/verify-l2-hook-firing`. This executor did not run on `main` and did not generate this
event. It most plausibly belongs to a different, unrelated subagent invocation from the
plan-filing/grounding session (e.g. the "research agent" the plan's Grounding section cites),
not to this item-1 dispatch. This executor cannot confirm that origin — it is recording the
raw log line and the raw timing coincidence, not asserting the cause.

## 4. Plain answer to "did hooks fire" — as far as this run can tell

- **The `subagent-lifecycle.sh` hook script has demonstrably executed at some point in this
  repo's session history** — the existence of `agent-a7b0d0e00e1204251.log` and the empty
  `.agents/` directory are hook-created artifacts (this executor created neither).
- **That hook execution is not attributable to this item's dispatch** — wrong branch (`main`
  vs `chore/verify-l2-hook-firing`), wrong timing (before this executor's first tool call),
  and it explicitly logged that it found no start record and stamped nothing.
- **This executor's own status.json shows no `agent_id`/`terminal` stamping as of the last
  read in this run.** Whether that changes at this run's actual SubagentStop is something
  only a post-hoc read (by the orchestrator, after this executor returns) can answer — this
  executor cannot observe its own termination event.
- **Whether this run even represents the headless `claude -p --agent` shape `dispatch.sh`
  uses is itself unverified** (see §0) — environment variables suggest a Task/Agent-tool
  child session inside Claude Desktop, not a detached subprocess.

**Overall: partial.** Hook *infrastructure* is confirmed to fire in this repo (§3), but there
is no confirmed instance in this run of it firing *for this executor's own dispatch*, and
whether this run is even the invocation shape item 1 was meant to test is itself in question
(§0). A conclusive yes/no on L2's specific headless shape requires either (a) an external
post-hoc check of this run's own status.json/agent log after this session's true
SubagentStop, done by a process that can independently confirm this was a detached `claude -p`
subprocess, or (b) a fresh run item that launches `claude -p --agent work-item-executor`
from an actual shell with no parent Desktop session, and inspects the resulting environment
for the same variables checked in §0 to confirm the shape before checking hook evidence.

## Run 2 (detached)

**Run date:** 2026-08-27/28 (local -0500 / UTC as shown below)
**HEAD at time of this run's start:** `0603306` (Run 1's findings commit)
**Orchestrator's stated intent for this run:** launch `claude -p` with `CLAUDE_CODE_CHILD_SESSION`,
`CLAUDE_CODE_HOST_SESSION_ID`, `CLAUDE_CODE_MESSAGING_SOCKET`, `CLAUDE_CODE_MESSAGING_TOKEN`,
`CLAUDE_CODE_SESSION_ID`, `CLAUDE_CODE_ENTRYPOINT`, `CLAUDE_PID`, `CLAUDECODE`, `CLAUDE_CODE_AGENT`
explicitly unset, to produce a genuinely detached process for comparison against Run 1.

### 1. This run's own environment, verbatim

```
$ env | grep -iE '^CLAUDE|^AGENT'
CLAUDE_AGENT_SDK_VERSION=0.3.246
CLAUDE_CODE_OAUTH_SCOPES=user:inference user:file_upload user:profile user:sessions:claude_code
CLAUDE_CODE_ENABLE_ASK_USER_QUESTION_TOOL=true
CLAUDE_CODE_EMIT_TOOL_USE_SUMMARIES=false
CLAUDE_CODE_DISABLE_CRON=
CLAUDE_CODE_EAGER_FLUSH=1
CLAUDE_CODE_REPORT_FINDINGS=1
CLAUDE_PREVIEW_CLASSIFIER_FLOOR=1
CLAUDE_CODE_SDK_HAS_OAUTH_REFRESH=1
CLAUDE_CODE_SDK_HAS_HOST_AUTH_REFRESH=1
CLAUDE_EFFORT=high
CLAUDE_CODE_ENTRYPOINT=sdk-cli
CLAUDE_CODE_AGENT=work-item-executor
CLAUDE_CODE_MESSAGING_SOCKET=/tmp/cc-socks/62138.sock
CLAUDE_CODE_MESSAGING_TOKEN=e7ed6d0baecbfbf560da87d099884d2f
CLAUDE_CODE_EXECPATH=/Users/jonathanstevenson/.local/share/claude/versions/2.1.241
CLAUDECODE=1
CLAUDE_CODE_SESSION_ID=2a8bdb2e-21ab-4415-97f5-2207c5daed30
CLAUDE_CODE_CHILD_SESSION=1
CLAUDE_PID=62138
```

### 2. Direct comparison against the nine variables the orchestrator says it unset

| Variable | Run 1 value | This run (Run 2) | Actually absent? |
|---|---|---|---|
| `CLAUDE_CODE_CHILD_SESSION` | `1` | `1` | **No — still present** |
| `CLAUDE_CODE_HOST_SESSION_ID` | `local_ba2e549e-...` | (not in output) | **Yes — absent** |
| `CLAUDE_CODE_MESSAGING_SOCKET` | `/tmp/cc-socks/55927.sock` | `/tmp/cc-socks/62138.sock` | **No — still present** (new value) |
| `CLAUDE_CODE_MESSAGING_TOKEN` | `1c7fa60d...` | `e7ed6d0b...` | **No — still present** (new value) |
| `CLAUDE_CODE_SESSION_ID` | `058d1969-...` | `2a8bdb2e-...` | **No — still present** (new value) |
| `CLAUDE_CODE_ENTRYPOINT` | `claude-desktop` | `sdk-cli` | **No — still set**, value changed from `claude-desktop` to `sdk-cli` |
| `CLAUDE_PID` | `55927` | `62138` | **No — still present** (new value) |
| `CLAUDECODE` | `1` | `1` | **No — still present** |
| `CLAUDE_CODE_AGENT` | `work-item-executor` | `work-item-executor` | **No — still present** |

**Plain statement:** the strip did not take for eight of the nine named variables. Only
`CLAUDE_CODE_HOST_SESSION_ID` is genuinely absent this run. `CLAUDE_CODE_CHILD_SESSION=1` and a live
`CLAUDE_CODE_MESSAGING_SOCKET`/`CLAUDE_CODE_MESSAGING_TOKEN` pair — the two signals Run 1 flagged as
the strongest evidence of a nested child session with a live channel back to a parent — are both
still present, with fresh values (new PID, new socket path, new token), meaning this run still has an
active messaging socket to *some* parent process. `CLAUDE_CODE_ENTRYPOINT` did change value
(`claude-desktop` → `sdk-cli`), which is the one variable showing any difference in kind rather than
just a fresh session identifier, but it was not unset — it was set to a different non-empty value.

**Conclusion on detachment: this run is NOT confirmed detached.** Based only on what this run directly
observed, it looks like the same shape as Run 1 — `CLAUDE_CODE_CHILD_SESSION=1` plus a live messaging
socket/token pair — with one env var (`CLAUDE_CODE_HOST_SESSION_ID`) removed and `CLAUDE_CODE_ENTRYPOINT`
changed from `claude-desktop` to `sdk-cli`. Whatever launched this run, it is not evidently a bare
`claude -p` subprocess with no parent session and no messaging channel; a live socket to a parent
process is still present.

### 3. status.json — before and after this run's own writes

Read back **before** this run wrote anything (i.e. as Run 1 left it at its own `gates-passed`):

```json
{
  "item": "1 - Verify L2 hook firing today",
  "branch": "chore/verify-l2-hook-firing",
  "state": "gates-passed",
  "detail": "Findings file committed and pushed (0603306); evidence is partial/unverified per findings doc — see item-1-hook-firing-findings.md. Not opening PR per dispatch instructions.",
  "commit": "0603306",
  "updated": "2026-08-28T02:04:02Z"
}
```

No `agent_id` field, no `terminal` field present at that point.

Read back immediately **after** this run's own `grounding` write (`mv`-based, not a hook):

```json
{
  "item": "1 - Verify L2 hook firing today",
  "branch": "chore/verify-l2-hook-firing",
  "state": "grounding",
  "detail": "Run 2 (detached): read plan.md and Run 1 findings; checked own env vars for the specific strip list the orchestrator applied before invoking this run.",
  "commit": "0603306",
  "updated": "2026-08-28T02:10:00Z"
}
```

Still no `agent_id`, still no `terminal` — this executor wrote every key present; nothing was added by
a hook as of this read. As with Run 1, `terminal`/`agent_id` are SubagentStop-stamped, which fires
after this agent's turn ends, so this run cannot observe its own SubagentStop from inside itself — only
a post-hoc read by the orchestrator after this run returns can settle that half.

### 4. Full listing of status/ — new agent-<id>.log?

```
$ ls -la /Users/jonathanstevenson/Source/claude-skills/docs/epics/16-l2-custom-loop-narration-fix/status/
total 24
drwxr-xr-x@ 6 jonathanstevenson  staff  192 Aug 27 21:06 .
drwxr-xr-x@ 4 jonathanstevenson  staff  128 Aug 27 21:00 ..
drwxr-xr-x@ 2 jonathanstevenson  staff   64 Aug 27 21:00 .agents
-rw-r--r--@ 1 jonathanstevenson  staff  147 Aug 27 21:05 agent-a7a486cf814fe9c0a.log
-rw-r--r--@ 1 jonathanstevenson  staff  147 Aug 27 21:00 agent-a7b0d0e00e1204251.log
-rw-------@ 1 jonathanstevenson  staff  341 Aug 27 21:06 chore-verify-l2-hook-firing.json
```

**Yes — a new `agent-<id>.log` file appeared**: `agent-a7a486cf814fe9c0a.log`, timestamped
`Aug 27 21:05` (`2026-08-28T02:05:53Z`), five minutes after Run 1's leftover
`agent-a7b0d0e00e1204251.log` (`Aug 27 21:00`) and landing close to this run's own start. Content:

```
$ cat /Users/jonathanstevenson/Source/claude-skills/docs/epics/16-l2-custom-loop-narration-fix/status/agent-a7a486cf814fe9c0a.log
2026-08-28T02:05:53Z | ── SUBAGENT STOP  (a7a486cf814fe9c0a) on branch main — no SubagentStart record for this agent; nothing stamped ──
```

Same pattern as Run 1's leftover log: a `SubagentStop` event, on **`branch main`** — not
`chore/verify-l2-hook-firing`, the branch this run is actually on — with no matching `SubagentStart`
record, so nothing was stamped. Since this run has never operated on `main`, this event is not
attributable to this run's own dispatch. It most plausibly belongs to whatever session or agent the
orchestrator ran on `main` to launch this run (e.g. the orchestrator's own dispatch turn), not to the
detached `work-item-executor` process itself.

`.agents/` remains **empty** — no new owner record file appeared:

```
$ ls -la /Users/jonathanstevenson/Source/claude-skills/docs/epics/16-l2-custom-loop-narration-fix/status/.agents
total 0
drwxr-xr-x@ 2 jonathanstevenson  staff   64 Aug 27 21:00 .
drwxr-xr-x@ 2 jonathanstevenson  staff   64 Aug 27 21:00 .
```

### 5. Plain answer — is this run detached, and did hooks fire for it?

- **Detached: no, not confirmed.** Eight of the nine variables the orchestrator says it unset are
  still present in this run's own environment, including `CLAUDE_CODE_CHILD_SESSION=1` and a live
  messaging socket/token pair to a parent process — the exact signals Run 1 flagged as inconsistent
  with a standalone `claude -p` subprocess. Only `CLAUDE_CODE_HOST_SESSION_ID` is genuinely absent,
  and `CLAUDE_CODE_ENTRYPOINT` changed value (`claude-desktop` → `sdk-cli`) without being unset.
- **Hooks fired for this run's own dispatch: no evidence either way, partial at best — same as Run 1.**
  A new `agent-<id>.log` did appear during this run's window, proving the `subagent-lifecycle.sh` hook
  script executed again during this session — but that event is stamped `branch main`, not
  `chore/verify-l2-hook-firing`, has no matching `SubagentStart` record, and stamped nothing. It is not
  attributable to this run's own dispatch by the same reasoning Run 1 applied to its own leftover log.
  This run's own `status.json` shows no `agent_id`/`terminal` as of its last self-read, and `.agents/`
  is still empty.
- **Overall: partial/unresolved, and the intended detachment fix did not take.** This run cannot
  settle item 1's original question because it cannot confirm it is the invocation shape item 1 was
  meant to test. The orchestrator's attempt to strip the specific env vars distinguishing a nested
  child session from a genuine detached `claude -p` subprocess only removed one of nine named
  variables (`CLAUDE_CODE_HOST_SESSION_ID`); the two strongest signals of a live parent channel
  (`CLAUDE_CODE_CHILD_SESSION=1`, an active messaging socket/token) persisted unchanged in kind. A
  conclusive answer still requires a run launched such that `CLAUDECODE`, `CLAUDE_CODE_CHILD_SESSION`,
  and any `CLAUDE_CODE_MESSAGING_*` pair are actually absent from the process environment — not merely
  reassigned to fresh values — before hook-firing evidence can be meaningfully checked.

## Run 3 (epic 19 item 3's live probe — SessionStart injection, not subagent stamping)

**Run date:** 2026-09-10. **HEAD at time of this run:** `34f1d1c` (this item's phase-session
harness commit, `feat/epic-loop-phase-session`).

**What this run tests, and how it differs from Runs 1-2 above.** Runs 1-2 asked whether the
*subagent-lifecycle* hook (SubagentStart/SubagentStop, `.agents/<id>.json` stamping) fires for
this executor's own dispatch, from *inside* a running agent that cannot observe its own
termination. Epic 19 item 3 needs a different, narrower question answered: does the
**SessionStart** hook — the one that injects `docs/epics/handoff.md` into context
(`session-start-context.sh`, confirmed by reading its source: it greps for
`docs/epics/handoff.md` under the repo root and `cat`s it into the injected block) — actually
fire for a `claude -p` process, so that a later phase session can read a prior phase's handoff
by injection alone (A1)? phase-session.sh (this item) does not depend on the answer being yes —
it names the handoff path explicitly in every prompt regardless — but the plan's Grounding
calls for the probe to be run rather than assumed either way.

**Also methodologically different from Run 2:** Run 2 above was launched *as a Task/Agent-tool
subagent* by an orchestrator that *intended* to strip nine `CLAUDE_CODE_*`/`CLAUDECODE`
variables, and found the strip did not take — `CLAUDE_CODE_CHILD_SESSION=1` and a live messaging
socket/token persisted, because a Task-tool agent is still a nested child of the launching
session by construction, whatever its own `env` shows. This run instead spawned `claude -p` as a
**literal child process of a shell command** (`env ... claude -p ...` via the Bash tool), which
is the actual shape `dispatch.sh`, `phase-session.sh` and a launchd job all use — not a nested
agent wearing a stripped environment.

**Setup:**

```
$ mkdir /Users/jonathanstevenson/Source/probe-scratch-epic19-item3 && cd $_
$ git init -q && git config user.email a@b.c && git config user.name probe
$ git commit -q -m init --allow-empty  # (README.md committed)
$ mkdir -p docs/epics
$ cat > docs/epics/handoff.md   # seeded with a unique marker, shown below
$ git add -A && git commit -q -m "seed handoff with probe marker"
$ bash <skill>/assets/claude-config/install.sh   # repo-mode install, NOT --commit
  ✓ settings merged → .claude/settings.json (added: statusLine, SessionStart, PreCompact,
    SessionEnd, PreToolUse, PreToolUse, PostToolUse, SubagentStart, SubagentStop)
```

`docs/epics/handoff.md`, seeded content (the line under "Claimed but NOT yet verified" is the
probe):

```markdown
**Claimed but NOT yet verified**
- MARKER-LIVEPROBE-4471c2 this line only appears in the injected handoff, not in the prompt given to the session
```

**The env-stripped invocation, and a control proving the strip actually took** (this is the gap
Run 2 found in itself — proving the strip BEFORE trusting what it implies):

```
$ env $(env | grep -iE '^CLAUDE|^ANTHROPIC' | cut -d= -f1 | sed 's/^/-u /' | tr '\n' ' ') \
    ANTHROPIC_BASE_URL="$ANTHROPIC_BASE_URL" \
    env | grep -iE '^CLAUDE|^ANTHROPIC'
ANTHROPIC_BASE_URL=https://api.anthropic.com
```

Unlike Run 2, this control shows the strip genuinely took: **zero** `CLAUDE_CODE_*` /
`CLAUDECODE` / `CLAUDE_PID` / messaging-socket variables survive — only `ANTHROPIC_BASE_URL`
(needed for the CLI to reach the API at all) was deliberately kept. `HOME`, `PATH`, `USER`,
`SHELL`, `TERM` and the rest of the invoking shell's environment were NOT stripped (`env -i`
with only `HOME`/`PATH`/`LANG` set was tried first and failed with an auth error — see the raw
transcript below — so this run is "no Claude Code session vars" rather than "launchd's actual
minimal environment"; that gap is the one honest limitation of this run, noted rather than
papered over).

**First attempt, `env -i` (fully minimal env), for the record — failed on auth, not on the
question this run asks:**

```
$ env -i HOME="$HOME" PATH="/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin" \
    LANG="en_US.UTF-8" "$HOME/.local/bin/claude" -p '...' --model sonnet
Anthropic profile login expired · Run /login to use your claude.ai account instead, or
re-authenticate the profile
```

This is a credential-resolution failure (some other env var or keychain-session dependency
`env -i` also stripped), not evidence about hooks one way or the other — recorded so a future
run doesn't re-waste a cycle rediscovering it. Immediate diagnostic: it means at least one of
the variables `env -i` blanks (beyond the `CLAUDE_CODE_*`/`ANTHROPIC_*` set explicitly tested
below) gates credential lookup — worth a future item's own investigation if a truly minimal
launchd environment is ever required, but out of this item's scope.

**The actual probe, second attempt (Claude-session vars stripped, rest of env intact):**

```
$ cd /Users/jonathanstevenson/Source/probe-scratch-epic19-item3
$ env $(env | grep -iE '^CLAUDE|^ANTHROPIC' | cut -d= -f1 | sed 's/^/-u /' | tr '\n' ' ') \
    ANTHROPIC_BASE_URL="$ANTHROPIC_BASE_URL" \
    "$HOME/.local/bin/claude" -p 'Reply with EXACTLY one line: if any text beginning with
    "MARKER-LIVEPROBE-" appears anywhere in the context you were given at the start of this
    session (not in this message itself), quote that exact line. Otherwise reply with the
    single word NONE. Do not explain, do not add anything else.' --model sonnet
EXIT=0
MARKER-LIVEPROBE-4471c2 this line only appears in the injected handoff, not in the prompt given to the session
```

**Plain answer.** The model reported the exact marker line from `docs/epics/handoff.md` —
content it was never given in the prompt (the prompt only asked it to look for anything
matching `MARKER-LIVEPROBE-*`, it did not supply the marker itself or the file's content) — so
the only route that text could have reached the session's context is `session-start-context.sh`
firing on `SessionStart` and injecting the handoff, exactly as it does for an interactive
session. **SessionStart injection DOES fire for a `claude -p` process spawned as a plain child
of a shell command, with every `CLAUDE_CODE_*`/`CLAUDECODE`/`ANTHROPIC_*`-except-base-url
variable genuinely absent from its environment** — the shape `dispatch.sh` and this item's
`phase-session.sh` both use, and a reasonable proxy for (if not identical to) a launchd job's
own environment.

**What this settles and what it still doesn't, stated plainly:**

- Settled, for THIS shape (plain subprocess, Claude-session vars absent, ordinary shell env
  otherwise intact): SessionStart hooks fire and inject `docs/epics/handoff.md`'s real content
  into a `-p` session's context. This is a materially stronger result than Runs 1-2, which
  tested subagent-lifecycle stamping (a different hook, a different question) from inside a
  Task-tool agent that never achieved a genuinely stripped environment in the first place.
- Not settled: whether a launchd job's own environment — no inherited shell variables at all,
  a minimal `PATH`, no `TERM`, invoked by `launchd` rather than a Bash tool call — behaves
  identically. The `env -i` attempt above hit an unrelated auth failure before it could answer
  that, and diagnosing it is out of this item's scope.
- **Item 3's own mitigation (A1) does not depend on this answer either way.**
  `phase-session.sh` names `docs/epics/handoff.md`'s absolute path explicitly in every prompt it
  builds, for both reading and writing, regardless of whether SessionStart injection also fires.
  This run is evidence the belt is probably unnecessary in the common case — not a reason to
  remove the suspenders.

Cleanup: `/Users/jonathanstevenson/Source/probe-scratch-epic19-item3` was a sibling scratch
directory outside this repo, removed after this run; nothing from it is referenced by path
elsewhere in this repo.
