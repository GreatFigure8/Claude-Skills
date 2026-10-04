# Validation — nextjs-standard-entry-point-and-skill-wiring

Branch `wip/nextjs-typescript-best-practices-reference/nextjs-standard-entry-point-and-skill-wiring`,
cut from `origin/feat/nextjs-typescript-best-practices-reference`. Date: 2026-10-04.

## TDD record

| Step | Command | Result |
| --- | --- | --- |
| RED, helpers | `pytest .../test_nextjs_doc_helpers.py` | collection error, `ModuleNotFoundError: No module named 'nextjs_doc_helpers'` (0 collected) |
| GREEN, helpers | same | 41 passed |
| RED, reference + wiring + renamed version test | `pytest test_nextjs_reference.py test_nextjs_wiring.py test_skill_text_rules.py` | 263 collected: 194 failed, 69 passed. Failures were `FileNotFoundError` (nine topic files absent), `LookupError` (sections missing in the 48-line draft), and `AssertionError` (missing wiring text, version still `1.6.0`) |
| GREEN, new files | `pytest test_nextjs_doc_helpers.py test_nextjs_reference.py test_nextjs_wiring.py -rs` | 191 passed, 63 skipped |
| Generic contract on a complete topic | the 185-case reference file run in a scratch copy with a synthetic contract-complete `typescript.md` | all 17 `typescript` cases passed, 0 skipped |

## AC16 gates

- Full suite: `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`
  gives **667 passed, 63 skipped** (74 s). The 476 pre-existing tests are unchanged, apart from
  the renamed version test.
- Skips: exactly 63 = 7 generic topic tests × 9 stubs, each with the reason
  `<file> is a stub pending <owning slug>` (checked with `-rs`: nine lines, `[7]` each, every slug
  equal to the `TOPICS` slug). Nothing else is skipped.
- Lint: `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` gives
  `All checks passed!`.
- shellcheck: no `.sh` file changed.
- Types: none (stack.md).

## AC15 grounding evidence

`evidence/sources-verified.md` lists 13 URLs, each fetched with WebFetch on 2026-10-04. The one-off
set-equality command (the plan's command, run from this harness worktree root instead of the run
worktree path, with the script saved as a file because the harness refuses heredocs):

```text
files = [NEXTJS_MD, *(topic stubs)]
cited = {u for p in files for u in source_urls(read(p))}
listed = {normalize_url(u) for u in URL_RE.findall(read(sources-verified.md))}
exit status: cited != listed
```

Output:

```text
cited: 13 listed: 13
only cited: []
only listed: []
exit=0
```

The version string `16.3.8` was read from the docs sidebar ("Latest Version 16.3.8") and from the
security-release post ("v16.3.8 (Active LTS)").

## Orchestrator addendum (in scope: this story owns `stack-routing.md`)

The "Test surfaces (drives TEST)" table in `references/stack-routing.md` named only Python tooling.
A `TypeScript / Next.js repo` row now carries the TypeScript tooling:

- unit + integration: the repo's runner (Vitest or Jest) with coverage;
- browser (`ui`): Playwright (`@playwright/test`) against `next build && next start` run locally;
- HTTP black-box: `fetch` against the running server;
- gates: `tsc --noEmit`, `eslint .` (`next lint` was removed in Next.js 16) and `next build`;
- details point to `nextjs/testing-and-observability.md`.

The `next lint` removal is confirmed by the upgrade guide (cited in `nextjs.md`). Wiring tests
`test_stack_routing_test_surfaces_names_typescript_tooling` (asserts the row, its Surface cell and
every tooling phrase) and `test_stack_routing_test_surfaces_keeps_the_python_rows` (the Python rows
are unchanged) cover it.

## Assumptions

1. The plan's helper API (§7.4) is implemented as written. Two points the plan left open:
   - `numbered_items` and `bullet_items` keep the list marker (`1. `, `- `), while `rule_items`
     returns `item_text` without its `N. ` marker so `RULE_RE.match(item_text)` works directly;
   - the list-returning section readers (`source_urls`, `malformed_source_lines`, `rule_items`,
     `checklist_items`, `anti_patterns`) return `()` when their section is absent, so the contract
     test for the missing section reports it. Only `section()` raises `LookupError`.
2. The generic tests also check that the list number equals the rule number (`1. **TS-1**`), that a
   topic has a single H1, that only list items or H3s sit at column 0 under `## Rules`, and that a
   still-stubbed topic keeps its plan §7.3 H1.
3. Jonathan's draft has 37 entries below the root, not the 39 the plan's test sketch mentioned.
   `DRAFT_PATHS` lists all 37 in draft order.
4. After the live read, four non-negotiables and one placement rule were reworded to what the pages
   state (list in `evidence/sources-verified.md`). The notable one: `middleware.ts` is not banned
   outright, because Proxy does not support the Edge runtime.
5. `## Version notes` in `nextjs.md` is a bullet list (13 items). The 16.3 headline changes are
   four separate bullets so each has its own source and owner.
6. The test-surfaces row uses the relative link `nextjs/testing-and-observability.md`, which
   resolves from `references/` to a stub that the testing story fills.
7. `nextjs-fullstack-standards` was not loaded and no build skill was routed (stack.md). No `.sh`
   file changed, so shellcheck had nothing to check.
8. The `evidence` folder and this file sit in the run folder on this branch; tests never read run
   folders (the AC15 check is a one-off).
9. Jonathan's untracked draft in his main checkout was not touched.
