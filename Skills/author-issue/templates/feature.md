# Feature intake template

Post the fenced block below to Jonathan **as one block**, unedited, and ask him to fill it
in in chat. For several features in one message, repeat the block once per feature.

Fields marked **(required)** gate the draft. `Requirements` and `AC` are the hard gate: with
either empty, do not draft — ask once for exactly what is missing (see `SKILL.md` step 2).

```
FEATURE

Title: (required)
  detailed enough means: the capability and who gets it, in one scannable line —
  "OIC fault handler retries FBDI imports on 503", not "improve error handling".

Problem / why now: (required)
  detailed enough means: the pain this removes and what makes it urgent today —
  a deadline, a recurring manual step, a customer commitment, a blocked workflow.

Summary: (required)
  detailed enough means: 2-4 sentences describing the change from the outside —
  what a user sees or a system does that it does not do now.

Users / actors: (required)
  detailed enough means: who or what invokes this — named roles, services, or jobs.
  "Ops runs it nightly via cron" beats "users".

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

Non-functional requirements:
  detailed enough means: numbers, not adjectives — latency budget, throughput,
  concurrency, retention, availability, auth model, audit needs. "Under 2s p95 for
  10k rows" beats "fast".

Constraints & not in scope:
  detailed enough means: what must NOT change (APIs, schemas, contracts others rely
  on), and the adjacent work this explicitly does not include.

Dependencies / links:
  detailed enough means: the issues, PRs, epics, docs, vendor APIs or environments
  this needs, each with a number or URL. Say "none" if there are none.

Priority: (required)
  detailed enough means: one of P1 / P2 / P3 plus a half-line of why — the impact or
  the deadline that sets it.
```
