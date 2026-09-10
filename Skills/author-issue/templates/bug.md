# Bug intake template

Post the fenced block below to Jonathan **as one block**, unedited, and ask him to fill it
in in chat. For several bugs in one message, repeat the block once per bug.

Fields marked **(required)** gate the draft. `Requirements` and `AC` are the hard gate: with
either empty, do not draft — ask once for exactly what is missing (see `SKILL.md` step 2).

```
BUG

Title: (required)
  detailed enough means: names the broken behaviour and where, in one line someone
  scanning the backlog can act on — "FBDI import silently drops rows with a null
  segment3", not "import bug".

Summary: (required)
  detailed enough means: 2-4 sentences — what happens, who hits it, how often, and
  what it costs. Enough for someone with no context to know why it matters.

Repo / branch / environment: (required)
  detailed enough means: repo name, the branch or commit it reproduces on, and the
  environment (local / dev / test / prod pod). "main @ 3f2a1c9, dev pod" beats "dev".

Steps to reproduce: (required)
  detailed enough means: numbered, literal steps someone else can follow blind —
  exact inputs, exact commands, exact clicks. If it needs a specific data set or
  file, name it. Intermittent? say how often and what varies.

Expected: (required)
  detailed enough means: the correct behaviour stated as an observable, not a
  feeling — "the row is rejected with a validation error naming segment3".

Actual: (required)
  detailed enough means: what actually happens, verbatim where possible — the error
  text, the wrong value, the missing row. "Doesn't work" is not an Actual.

Evidence (logs, screenshots, links):
  detailed enough means: the smallest excerpt that shows the failure — stack trace,
  log lines with timestamps, a failing request/response pair, a screenshot, or links
  to a run. Say "none" if there is genuinely none.

Requirements: (required — numbered, your words, not Claude's)
  detailed enough means: what must be true when this is done, one numbered line each.
  Behaviour and constraints, not implementation.
  R1.
  R2.

Acceptance criteria: (required — numbered, your words, not Claude's)
  detailed enough means: each one is a check someone can run and get a yes/no from.
  If you cannot imagine testing it, it is a requirement, not a criterion.
  AC1.
  AC2.

Constraints & not in scope:
  detailed enough means: what must NOT change (APIs, schemas, behaviour others rely
  on) and what is explicitly out of this bug's scope, so it does not grow.

Priority: (required)
  detailed enough means: one of P1 / P2 / P3 plus a half-line of why — the impact or
  the deadline that sets it.
```
