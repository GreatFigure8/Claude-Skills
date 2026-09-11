# Sprint state — the contract the three phases share

The creator, planner and coder never talk to each other. They hand work forward through
**one committed file per sprint**: `docs/sprints/<sprint>/sprint.json`. Whoever runs next
scans those manifests, picks the ones in its input state, claims them, and advances them.
Git is the audit trail; the repo is the queue.

## Why a manifest and not the alternatives

| Option | Verdict |
|---|---|
| **Per-sprint `sprint.json` with a `status` field** (chosen) | One source of truth per sprint, committed, greppable, carries metadata (claims, story states, issue numbers), no cross-sprint merge conflicts, survives `/clear` and machine changes. |
| Marker files (`.ready-to-plan`, `.planned`, `.complete`) | Trivial to test with `ls`, but no metadata, flags can coexist inconsistently, nowhere to record a claim or a story's state. |
| Central `docs/sprints/index.md` | One glance shows everything, but every session and executor writes the same file — a merge-conflict magnet with parallel work. |
| GitHub labels / project board | Network-dependent, invisible to `grep`; this flow deliberately files no GitHub issues, and sprint state belongs beside the stories. |

## The state machine

```
drafting ──► ready-to-plan ──► planning ──► planned ──► executing ──► complete
 (creator)     (creator)       (planner)   (planner)    (coder)       (coder)
                                                           │
                                                           └──► blocked  (coder; needs Jonathan)
```

| Status | Set by | Meaning |
|---|---|---|
| `drafting` | creator, on first story | Stories are being written. Only the creator touches the sprint. |
| `ready-to-plan` | creator, when Jonathan says the sprint is documentation-complete | Planner input state. |
| `planning` | planner, on claim | A planner owns it; other planners skip it. |
| `planned` | planner, when every story has a plan and `impl-plan.md` exists | Coder input state. Jonathan may review `impl-plan.md` here. |
| `executing` | coder, on claim | A coder owns it; other coders skip it unless the claim is stale. |
| `complete` | coder, after every story is done, sprint gates pass, and integration is merged to live | Terminal. |
| `blocked` | coder | At least one story exhausted its fix attempts or needs a decision. Jonathan resolves, then `set <sprint> planned --force` to re-admit. |

Transitions are enforced by `assets/bin/sprint-state.sh` — an out-of-order `set` fails unless
`--force` is passed, and `--force` is a deliberate human-authorised repair, never a habit.

## Claims — "being executed at the moment"

`planning` and `executing` carry a claim: `{"by": "<hostname>-<UTC stamp>", "at": "<ISO-8601>"}`.
A phase generates its id once at start and reuses it for every claim in that session. A claim
is **stale** when it is older than `DSF_STALE_HOURS` (default 6) — `sprint-state.sh stale
<sprint>` exits 0 when so. A stale `executing` sprint may be reclaimed by a new coder, which
says so in one line; a fresh one is skipped. `planned`, `complete` and `blocked` clear the claim.

## Manifest schema

```json
{
  "sprint": "2026-09-10-001",
  "status": "planned",
  "created": "2026-09-10T14:02:11Z",
  "updated": "2026-09-10T16:40:03Z",
  "branch": { "live": "main", "integration": "sprint/2026-09-10-001" },
  "claim": null,
  "stories": [
    {
      "slug": "create-home-page",
      "title": "Create the home page",
      "kind": "interactive",
      "status": "planned",
      "plan": "create-home-page/create-home-page-plan.md",
      "attempts": 0,
      "detail": ""
    }
  ],
  "history": [
    { "at": "2026-09-10T14:02:11Z", "status": "drafting", "by": "creator" },
    { "at": "2026-09-10T15:10:47Z", "status": "ready-to-plan", "by": "creator" }
  ]
}
```

- `kind` is `interactive` (UI, browser-tested) or `service` (backend, DB, API, MCP, CLI — curl/bash-tested). It decides the acceptance-criteria shape.
- `branch.integration` is `sprint/<sprint>` by default, or `"none"` in repos whose `CLAUDE.md` says to work directly against live. `branch.live` is the branch the completed sprint merges into — `dev` in repos with a dev/main model (pass `--live dev`).
- Story `status`: `drafted → planned → executing → validating → done`, with `blocked` as the exceptional terminal. `attempts` counts validate→fix cycles; the coder stops at 3.
- `history` is append-only. Never rewrite it; `--force` transitions are recorded with `"forced": true`.

## Folder layout

```
docs/sprints/
└── 2026-09-10-001/
    ├── sprint.json                          ← the manifest above
    ├── impl-plan.md                         ← planner: story order, dependencies, gotchas
    ├── create-home-page/
    │   ├── story.md                         ← creator
    │   ├── create-home-page-plan.md         ← planner: item table + validation procedure
    │   └── validation.md                    ← coder: per-criterion results of the final pass
    └── add-chat-endpoint/
        ├── story.md
        └── add-chat-endpoint-plan.md
```

Sprint name is `YYYY-MM-DD-NNN`, index zero-padded to three digits and restarting each day
(`sprint-state.sh new` computes it). Story slugs are lower-case, dash-separated, chosen by the
creator from the story's title.

## The helper

`assets/bin/sprint-state.sh` (python3 under the hood, no other dependencies):

```
sprint-state.sh new [--live <branch>] [--integration <branch>|none]   → prints the new sprint name
sprint-state.sh list [<status>]                                         → name  status  claim-by  claim-at
sprint-state.sh get <sprint>                                            → the manifest JSON
sprint-state.sh set <sprint> <status> [--by <id>] [--force]             → transition (+claim/unclaim)
sprint-state.sh story add <sprint> <slug> --title <t> --kind <k>
sprint-state.sh story set <sprint> <slug> <status> [--detail <text>] [--plan <relpath>] [--bump-attempts]
sprint-state.sh stale <sprint> [<hours>]                                → exit 0 if the claim is stale
```

`SPRINTS_DIR` overrides `docs/sprints` (relative to the git top level). Every write is atomic
(temp file + `mv`) and is followed by a commit by the calling phase — a manifest change that
is not committed does not exist to the next session.
