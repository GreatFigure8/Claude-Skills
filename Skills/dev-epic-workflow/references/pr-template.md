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
- **The declared-paths gate is run, its output pasted, whatever it says.**
  `bin/declared-paths-gate.sh` (epic 10 item 3) WARNs on a mismatch — it never
  blocks — so a nonzero exit here is not a reason to withhold the PR, only a
  reason to paste the finding and, if it's real, say so in the summary.

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
- `git diff --stat <base>...HEAD` → <pasted output>
- `git grep -n "<removed-symbol>"` → <no matches / n/a — nothing removed>
- `Skills/dev-epic-workflow/assets/claude-config/bin/declared-paths-gate.sh --plan docs/epics/<NN>-<epic-slug>/plan.md --item <N> --base <base>` → <pasted output — "not declared" if the item carries no `**Touches:**` block; a mismatch WARNs and does not block. Replaces the old manual "touched paths match scope: yes/no + note" eyeball check.>

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
