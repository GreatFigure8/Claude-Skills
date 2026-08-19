# PR template

The canonical PR body for every work-item PR. Two uses:

1. **Drop it into the repo** as `.github/PULL_REQUEST_TEMPLATE.md` (copy everything
   inside the fenced block below) so GitHub pre-fills it on every PR.
2. **Fill it when opening a PR from chat** — the agent fills every section from the
   plan and the actual verification output, never from recall. A section that
   doesn't apply gets `None` with a one-line reason, not deletion.

Rules that make the template mean something:

- **Every claim in Verification is pasted output**, not a description of output.
  If a gate wasn't run, the checkbox stays unchecked and the PR says why.
- **In scope must map 1:1 to the plan item's scope.** Anything extra is scope
  growth — split it (PR B) instead of listing it here.
- **The deletion grep is mandatory when the item promised a removal.** This is
  the check that catches "reported complete but silently did not land."

---

```markdown
## Work item

Epic: <epic name> — `docs/epics/<NN>-<epic-slug>/plan.md`
Item: <N> — <item title>
Branch: `<type>/<slug>` → `<integration branch>`

## Summary

<2–4 sentences: what this PR does and why, in plain language. A reviewer who
reads nothing else should understand the change from this paragraph.>

## In scope

<!-- Bullet per change, matching the plan item's stated scope. -->
- 

## Deliberately not in scope

<!-- The adjacent thing that was tempting. Name where it went: Deferred list,
     a follow-on item, or "out of this epic entirely." Write "None" if truly
     nothing was excluded — but that's rare on a real change. -->
- 

## Change character

<!-- Check all that apply. Pure moves and behavior changes must be separate
     commits (refactor(move): prefix carries zero behavior change). -->
- [ ] Behavior change
- [ ] Pure move / rename (`refactor(move):` commits only)
- [ ] Schema migration (Alembic revision paired with the model change in this PR)
- [ ] MCP tool contract touched (names/params/return shapes — call out below)
- [ ] Config / infra (OCI, OIC ID Domains, env vars — call out below)

<contract or config notes, if either box above is checked>

## Verification

<!-- Pasted output, not prose. One line per check: command → result. -->
- `<command>` → <result>
- `git diff --stat <base>...HEAD` → touched paths match scope: <yes/no + note>
- `git grep -n "<removed-symbol>"` → <no matches / n/a — nothing removed>

### Gates (per `stack-gates.md`)
- [ ] Python: `ruff check` / `mypy` / `pytest` clean
- [ ] Migrations: Alembic up/down exercised (or n/a)
- [ ] MCP: tool contracts stable or version-bumped (or n/a)
- [ ] Frontend: `tsc --noEmit` / lint / `next build` clean (or n/a)
- [ ] Rebased on `<integration>` immediately before opening this PR

## Rollback

<!-- One of: -->
Revert this merge commit. | Restore from tag `pre-<epic-slug>`. | <other, stated>

## Plan impact

<!-- What changes in docs/epics/<NN>-<epic-slug>/plan.md when this merges:
     item marked done, discoveries added to Deferred, scope split recorded. -->
- 
```
