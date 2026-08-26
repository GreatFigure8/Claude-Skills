# Plan template

The plan is the artifact that gets approved. On approval it is filed in the repo under `docs/epics/`, in a numbered folder ordered by implementation sequence starting at `01` — `docs/epics/01-<epic-slug>/plan.md`, `docs/epics/02-<epic-slug>/plan.md`, and so on — so it survives the chat session. The number is assigned at approval (next available), and the folder is the epic's home: status updates, the Deferred list, the retro, and any supporting artifacts live there.

Present the **whole** plan every time it changes. Never hand over a diff fragment to be merged by hand.

---

## Structure

```markdown
# Epic: <name>

**Status:** planning | approved | in flight (item N of M) | closed
**Live branch:** <branch that must keep working>
**Integration branch:** <branch work items merge into>
**Pre-epic tag:** <tag or "n/a">

## Outcome
One paragraph. What is true when this is done that isn't true now.

## Grounding
- Verified: <what was actually read/run/queried, and where>
- Assumed: <what wasn't verified — each of these is a risk>

## Invariants
Things that must remain true for the whole epic:
- <e.g. existing installs keep working against unchanged tool names/contracts>
- <e.g. no credential material committed; secrets resolve through the provider>
- <e.g. migrations are forward-only and paired with the code that needs them>

## Work items

### 1. <short title>
- **Branch:** `<type>/<epic-slug>-<item-slug>`
- **Depends on:** none | item N
- **Scope:** what changes, in files/modules
- **Touches:** the paths this item declares it will change (optional — see below)
- **Not in scope:** the tempting adjacent thing this deliberately skips
- **Definition of done:** observable conditions, not intentions
- **Verification:** the exact command/grep/query that proves it
- **Rollback:** revert the merge commit | drop the branch | restore from tag

### 2. <short title>
...

## Sequence
1 → 2 → (3 ∥ 4) → 5, with a note on why anything must be serial.

## Risks
| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|

## Deferred / out of scope
Running list. Everything discovered mid-epic that isn't strictly required lands
here instead of in the current branch.

## Log
- YYYY-MM-DD — item 1 merged, verified by <check>. Item 3 split into 3a/3b because <reason>.
```

---

## The `**Touches:**` field

Optional, per work item, directly under **Scope**. It states the paths this item will
*change* — for a program to read, not a human to infer from prose. `**Scope:**` stays
exactly where it is and keeps explaining *what changes and why*; `**Touches:**` is the
same fact in a form a check can compare against a diff.

```markdown
- **Touches:**
  - `Skills/dev-epic-workflow/references/plan-template.md`
  - `Skills/dev-epic-workflow/SKILL.md`
```

Three rules, each earning its place from a measured failure:

1. **One path per line.** A comma list wrapped across two lines has already lost a real
   entry in a live proposal — a line per path can't drop one that way.
2. **Repo-root-relative, always.** Two drafts of the same file have already been seen
   naming it two different ways (a full repo path and a truncated one). Fixing the form
   at the source removes the normalisation problem from every consumer, rather than
   asking each one to solve it again.
3. **Declarations only.** A path this item merely reads, or compares itself against, is
   named in prose — `**Scope:**` or `**Not in scope:**` — never here. A live proposal has
   already named a file only as something it reads while explicitly stating in its own
   `**Not in scope:**` that the file itself is untouched; conflating the two would have
   made that a false positive.

**Absence means "not declared," never a failure.** Every consumer degrades to that
reading rather than failing closed — a plan without the field stays exactly as valid as
one with it. Consequently the field is **not retrofitted**: existing plans that predate
it are left alone rather than rewritten, and this is the decision, recorded here so it
does not need to be re-litigated per epic.

## Worked example (shape only)

```markdown
# Epic: extract the OIC transport out of the legacy server

**Status:** in flight (item 1 of 3)
**Live branch:** main-v2   **Integration branch:** dev-v2   **Pre-epic tag:** pre-transport-extraction

## Outcome
OIC HTTP access lives in one client module in the shared core package, injectable
for tests, with per-call client lifecycles — so domain servers stop owning transport.

## Work items

### 1. OIC client into core
- **Branch:** `refactor/transport-oic-client`
- **Scope:** move the OIC HTTP calls into the core clients package; add the http dep;
  inject the transport; move scope-precedence handling with it.
- **Not in scope:** no protocol seam, no async conversion of the Fusion SOAP/REST tools,
  no credential-schema change.
- **Definition of done:** no direct HTTP construction remains outside the client module;
  existing OIC tools pass their tests unchanged.
- **Verification:** grep for direct client construction under the server packages returns
  nothing; `git diff --stat` touches only the intended paths.
- **Rollback:** revert the merge commit; the tag predates the epic.

### 2. Transport bug-fix pass
Small, lands between 1 and 3 so item 3 doesn't inherit known defects.

### 3. Fusion SOAP/REST async-native conversion
The sync tools convert to async. Separate PR because the diff is large and mechanical,
and mixing it with item 1 would make both unreviewable.

## Deferred
- Credential-resolution alignment — needs a schema change, gets its own epic.
```

The two habits this example is really teaching: **split when scope grows** (one extraction became three PRs), and **park what needs its own schema change** rather than smuggling it in.
