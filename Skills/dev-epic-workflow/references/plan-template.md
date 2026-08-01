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
