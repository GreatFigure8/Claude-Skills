# Validation — app-router-routing-and-metadata

Branch `wip/nextjs-typescript-best-practices-reference/app-router-routing-and-metadata`, cut from
`origin/feat/nextjs-typescript-best-practices-reference` (efff2ea). Date: 2026-10-04.

## TDD record

| Step | Command | Result |
| --- | --- | --- |
| RED | `pytest .../test_nextjs_topic_routing_and_metadata.py -q` (file still a stub) | 16 collected: 15 failed, 1 passed. Failures were `LookupError: no heading 'Not confirmed by the docs'` and the assertions `not is_stub`, rule count, terms, examples, checklist, anti-patterns. They fail for the right reason: the file is a stub. The one pass is `test_routing_topic_examples_never_type_as_any`, which holds trivially with no code blocks. |
| GREEN | same command after writing the topic file | 16 passed |
| GREEN, generic contract | `pytest test_nextjs_topic_routing_and_metadata.py test_nextjs_reference.py -q -rs` | 145 passed, 56 skipped. The 56 skips are 7 generic tests x 8 other stubs. No skip names `routing-and-metadata` (was 63 before this story). |

## Gates (AC10)

- Full suite: `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`
  gives **690 passed, 56 skipped** (76 s). Baseline on the run branch was 667 passed, 63 skipped:
  +16 story tests, +7 generic tests that no longer skip for this topic.
- Lint: `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` gives `All checks passed!`.
- Types: none (stack.md). The topic's snippets were nevertheless compiled, see below.
- Line cap: the topic file is 712 lines (cap 790 in the plan, 800 in the contract).

## AC9 grounding evidence

One-off check (script saved as a file in the scratchpad because the harness refuses heredocs; it is
the plan's command, run from this worktree):

```text
src = set(source_urls(read(routing-and-metadata.md)))
ev  = set(https URLs in evidence/sources-verified.md) minus the llms.txt version source
print('equal:', src == ev, sorted(src ^ ev))
```

Output:

```text
equal: True []
sources count: 58 prose count: 58
sources never cited in prose: []
prose not in sources: []
lines: 712
rules: 40 ts/tsx fences: 24
antis: 6 checklist: 17
```

## Extra check: the snippets compile

Beyond the plan, every `ts`/`tsx` block in `## Patterns` (14 files) and the Do half of each
anti-pattern (5 files) was extracted into a scratch app in the session scratchpad with
`next@16.3.8`, `react@19.2.0`, `typescript@5.9.3` and `strict: true`. Local modules the snippets
import (`post-schema`, `products`, `projects`, `photo-view`) were stubbed. `next typegen` generated
the global `PageProps`/`LayoutProps` route types, and `tsc -p` then reported **no errors** across all
23 source files. Nothing from that scratch tree is committed.

## Live re-check of the verified rule sheet

The brief says to re-fetch anything that looks wrong. Every rule's cited page was re-read on
2026-10-04 (Markdown variants, nextjs.org, vercel.com, react.dev status 200). The rule sheet held, with
these deliberate edits to match the pages exactly:

- **RT-31.** The pages state "not in event handlers" only for `redirect()`. The rule now scopes
  that sentence to `redirect()` and the checklist item follows. Both functions are typed `never`
  and are called outside `try`/`catch`.
- **RT-9.** The `global-error` html/body requirement (error.js page) is folded into the rule.
- **RT-26.** Worded as the layout.js page words it: layouts don't re-render on navigation, so
  they can't read the pathname or the latest search params.
- **RT-11.** The `generateMetadata` awaited `params` is a separate sentence with its own link.
- **Patterns.** The plan's "Verified" and "Design choice" planner notes were turned into one short
  prose paragraph under each pattern, per the plan's rule that planner notes never go in the file.

Facts confirmed live, among others: the v16 guide's async-API list, image-function and sitemap `id`
Promises, `default.js` build failure and the `data-scroll-behavior` opt-in; `generateStaticParams`
(array, `[]`, Cache Components needs one param, top-down and bottom-up); `dynamicParams` removed
under Cache Components (route-segment-config row `v16.0.0`); `partialPrefetching` (`16.3.0`, needs
`cacheComponents`); the `prefetch` export values; `robots` `other` (`v16.3.0`); root params; redirect
status codes and `redirects` running before Proxy; Vercel's 1,024 vs 2,048 limits.

## Assumptions

1. The merged skeleton contract was read first (`nextjs.md` Authoring contract,
   `nextjs_doc_helpers.py`, `test_nextjs_reference.py`, the skeleton `validation.md`). It matches the
   plan's defaults: `section(text, "Rules")` takes the bare title, `read` takes a `Path`, and `TOPICS`
   values are `(prefix, slug)`. Only the Anti-patterns markers needed no widening.
2. The plan's test module is kept assertion for assertion. Two mechanical edits only:
   `test_every_checklist_item_names_an_rt_rule` uses `h.checklist_items` (so a wrapped item is one
   item) instead of a line scan, and `zip(..., strict=True)` in `_anti_pattern_chunks`.
3. `## Rules` is one flat numbered list with no `###` group headings, and each rule is one physical
   line, as the plan's format note requires. A `###` between items would be folded into the previous
   item by `numbered_items`.
4. The H1 is "App Router routing, navigation and metadata" (the plan's outline). The skeleton's
   "Routing and metadata" title applies only to a stub.
5. The as-of line is copied from `nextjs.md`: `> As of Next.js 16.3.8, verified 2026-10-04.`
6. `evidence/sources-verified.md` is unchanged. Its set still equals `## Sources`.
7. The adopting-partial-prefetching page now also links
   `https://nextjs.org/docs/app/guides/optimizing-prefetching`. It was not fetched as a source for any
   rule, so it is not cited.
8. No generateSitemaps block trim was needed: the file is 712 lines.
9. `nextjs-fullstack-standards` was not loaded and no build skill was routed (stack.md). No `.sh`
   file changed, so shellcheck had nothing to check. No migrations, env vars or deploy_pending.
