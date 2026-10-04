# Validation — rendering-caching-and-streaming-ssr

Branch `wip/nextjs-typescript-best-practices-reference/rendering-caching-and-streaming-ssr`, cut from
`origin/feat/nextjs-typescript-best-practices-reference` (skeleton merged). Date: 2026-10-04.
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.

## TDD record

| Step | Command | Result |
| --- | --- | --- |
| RED | `pytest .../test_nextjs_topic_rendering_and_caching.py` against the stub | 24 collected, **24 failed**. Failures are the stub's: `is_stub` true, no `RC-` rules (`0 >= 8` anti-patterns, empty rule list), missing terms and examples, `LookupError: no heading 'Review checklist'`. Committed as `test:` before any content. |
| GREEN | same file, with `R/nextjs/rendering-and-caching.md` written | **24 passed** |
| Generic contract | `pytest test_nextjs_reference.py -rs` | passes for `rendering-and-caching.md` with **no skip**: its 7 generic cases moved from skipped to passed (skips 63 to 56; no `SKIPPED` line names this file) |
| Refactor | wording tightened, imports added to the anti-pattern snippets, AP10 dropped for the line budget | topic and contract tests re-run: green |

## Gates (AC10)

- Full suite `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q -rs`:
  **698 passed, 56 skipped** (73 s). The skeleton's 667 passed + 24 new topic cases + 7 generic cases no
  longer skipped = 698. The 56 skips are 7 generic cases × the 8 other stubs, each with the reason
  `<file> is a stub pending <owning slug>`.
- Lint `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope`: `All checks passed!`.
- Types: none (stack.md). shellcheck: no `.sh` file changed.
- `wc -l R/nextjs/rendering-and-caching.md`: 785 lines (cap 800).
- `git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD` lists only
  `R/nextjs/rendering-and-caching.md`, `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_rendering_and_caching.py`
  and files under `docs/sprints/bmn-nextjs-typescript-best-practices-reference/rendering-caching-and-streaming-ssr/`.

## AC9 grounding evidence

`evidence/sources-verified.md` lists the 46 URLs of the file's `## Sources`, each with the 2026-10-04 fetch date
and the rule ids it backs. The plan's one-off set-equality command (script saved as a file because the harness
refuses heredocs inside compound commands):

```text
file: 46 evidence: 46
equal: True | only in file: [] | only in evidence: []
```

All 44 nextjs.org and vercel.com pages, the security release post and the two react.dev pages were fetched live
again by the coder on 2026-10-04. Claims most likely to drift were grepped against the fetched text (see
`evidence/sources-verified.md`, Method). Every `ts` and `tsx` fence (32) was type-checked in strict mode
against the published `next@16.3.8` and `react@19` types with stand-in declarations for `PageProps`,
`LayoutProps` and the application helpers. The only diagnostic is the deliberate one-argument
`revalidateTag('posts')` in the anti-pattern Don't block (TS2554 "Expected 2 arguments"), which confirms the
documented TypeScript error.

## Assumptions

1. **Anti-pattern format follows the merged contract, not the plan's default.** The contract defines
   `### Don't …` H3 headings, each with at least one fenced block. Each heading here names its `RC-` ids, holds
   the Don't block, then a `**Do:**` marker line, then the Do block. The topic test parses exactly that shape.
2. **Nine anti-patterns, not ten.** AP10 (random value in a prerendered component) was dropped for the line
   budget (785 of 800 lines); the plan allowed this. The content stays covered by RC-17 and the
   "Non-deterministic values" pattern.
3. **Sources.** The version-source post (the security release) is the first Sources bullet, as in the stub and in
   `nextjs.md`, because the as-of line rests on it. The sheet's rendering-philosophy page (S4) is cited by no
   rule, so it is not listed. The file has 46 Sources.
4. **Not confirmed items need a prose URL (contract).** The first item names the nonexistent
   `getting-started/cache-components` path as inline code and links the Caching page it checked instead.
5. **Wording on "throws".** Only `updateTag` is documented to throw outside a Server Action (the page's own error
   example). RC-33 and the decision table say `refresh` "cannot be used" elsewhere, which is what its page says.
6. **Examples.** The webhook Route Handler uses `POST` with a signature check (the docs' example uses `GET`), still
   `revalidateTag(tag, 'max')`; the Server Action example carries the auth-check shape from the Server Actions
   guide. Application helpers (`db`, `auth`, `getProfile`, `verifyWebhook`, `postExists`, `Nav`, `List` and
   the like) are placeholders, not Next.js APIs.
7. **Tests are stricter than the plan's 15 cases (24 here):** at least 8 anti-patterns, a model label on every
   rule, RC-1 starting with "Detect", the decision table's `Call from` and `What the user sees` columns, three
   tables in Patterns, at least 10 linked version notes, and at least 12 `ts`/`tsx` fences.
8. **Defects in shared files:** none found. `nextjs.md`, the helpers and `test_nextjs_reference.py` were read-only
   and the contract matched the plan apart from item 1.
9. **No migrations, env vars, Vercel or Supabase work** (stack.md: no UI, no Supabase, no Vercel). `deploy_pending: []`.
