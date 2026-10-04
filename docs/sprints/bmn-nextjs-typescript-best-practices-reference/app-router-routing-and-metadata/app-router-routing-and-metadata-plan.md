# Plan: App Router routing, navigation and metadata

**Story:** [story.md](story.md) · **Run:** `bmn-nextjs-typescript-best-practices-reference`
**Owns:** `R/nextjs/routing-and-metadata.md` (prefix `RT`) and
`Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_routing_and_metadata.py`.
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.
**Research date:** 2026-10-04. Every page below was fetched live today (Markdown variant
`<url>.md` for nextjs.org and vercel.com). **Current stable Next.js: 16.3.8.** It was read
from `https://nextjs.org/docs/llms.txt` (`@doc-version: 16.3.8`), and npm `next@latest` is
`16.3.8`. **Latest major: 16.**

## 1. Approach

- **Skills.** No build skill is routed (stack.md: Markdown content). This plan applies the
  story's grounding rule and the skeleton's authoring contract. `nextjs-fullstack-standards`
  isn't loadable, so nothing is approximated from memory.
- **Research first.** The planner fetched every page live and wrote the
  [Verified rule sheet](#7-verified-rule-sheet), with 40 rules (`RT-1`–`RT-40`). Each rule has
  its URL, a paraphrase of what the page says, and every snippet checked against that page.
  The Sonnet coder transcribes the sheet. It does not research, and it adds no claim that
  isn't on the sheet.
- **TDD.** Write the story test first, then run it. It fails, because the file is still a stub.
  Then write the topic file and run the test again until it passes.
- **Layout.** The topic file maps Jonathan's canonical layout (`../nextjs.md`) onto the
  conventions and never redefines it. Examples live in `src/app`, `src/features/<f>/…` and
  `src/shared/…`, which is the docs' "store project files outside of `app`" strategy.
- **Conflicts.** Where the docs contradict each other, the rule follows the newer, explicit
  source (the v16 upgrade guide), and the conflict is recorded under
  `## Not confirmed by the docs`.

## 2. Files

| File | Action | Purpose |
| --- | --- | --- |
| `R/nextjs/routing-and-metadata.md` | replace stub entirely | The topic file. Content is in §7–§12 below. Hard cap is 790 lines (contract cap 800). |
| `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_routing_and_metadata.py` | create | Story tests for AC2–AC8 (full code in §3). |
| `docs/sprints/bmn-nextjs-typescript-best-practices-reference/app-router-routing-and-metadata/evidence/sources-verified.md` | **already written by the planner** | 58 URLs, fetch date and the rule ids each backs (AC9). Keep it equal to the topic's `## Sources`. |
| `docs/sprints/bmn-nextjs-typescript-best-practices-reference/app-router-routing-and-metadata/validation.md` | create at validation | One-off checks for AC9 and AC10, plus the test and lint output. |

Nothing else changes. These are off-limits: `R/nextjs.md`, `test_nextjs_reference.py`,
`nextjs_doc_helpers.py`, the wiring files and the other topic files. Record any defect found
in them under Assumptions in `validation.md`.

## 3. Test plan (written first)

All tests are `[unit]`, with no browser and no network. Generic contract checks live in the
skeleton's `test_nextjs_reference.py` (parametrized over topic files). This story adds one
module.

| AC | Test(s) | File | Type |
| --- | --- | --- | --- |
| 1 Contract | the generic contract tests in `test_nextjs_reference.py`: section order, rule format and citations, floors, Sources hosts, prose URLs in Sources, as-of version equals `nextjs.md`, ≤800 lines, tagged fences, relative links, no `TODO`/`TBD`. Validation runs `pytest test_nextjs_reference.py -rs` and confirms **no skip** names `routing-and-metadata`. Plus `test_routing_topic_cites_no_other_topics_rule_ids`. | `test_nextjs_reference.py` (skeleton), `test_nextjs_topic_routing_and_metadata.py` | unit |
| 2 Not a stub, ≥15 rules | `test_routing_topic_replaces_the_stub`, `test_routing_topic_has_at_least_fifteen_rt_rules` | story test | unit |
| 3 Required concepts | `test_routing_topic_covers_required_concepts` | story test | unit |
| 4 Examples | `test_routing_topic_has_worked_example[static-params-page, typed-generate-metadata, sitemap, not-found-page, client-search-params]`, `test_routing_topic_examples_never_type_as_any` | story test | unit |
| 5 Slot `default` rule | `test_rules_state_the_parallel_route_default_requirement` | story test | unit |
| 6 Canonical layout link | `test_canonical_layout_is_linked_from_the_topic` | story test | unit |
| 7 Version notes | `test_version_notes_name_the_major_and_link_nextjs_org` | story test | unit |
| 8 Reviewer-ready | `test_every_checklist_item_names_an_rt_rule`, `test_every_anti_pattern_pairs_a_dont_with_a_do` | story test | unit |
| 3/Grounding | `test_not_confirmed_section_lists_the_urls_checked` | story test | unit |
| 9 Evidence | one-off command in `validation.md` (§6), not a permanent test | — | validation |
| 10 Scope and gates | one-off `git diff --name-only` check, the full suite and ruff (§6) | — | validation |

**16 collected test items** come from 12 functions; one is parametrized ×5.

### Test module (write verbatim, then adapt only the helper-call details noted below)

```python
"""Story tests for references/nextjs/routing-and-metadata.md (rule prefix RT).

test_nextjs_reference.py already runs the generic authoring-contract checks on every
non-stub topic file: section order, rule format and citations, floors, Sources, the as-of
line, the 800-line cap, fence tags and relative links. This module adds what only the
routing-and-metadata topic needs: depth, the required concepts, five worked examples, the
Next.js 16 parallel-route `default` rule, the link to the canonical layout in nextjs.md,
version notes for the as-of major, and a reviewer-ready checklist and anti-pattern list.
Standard library and pytest only; nothing here touches the network.
"""

import re

import nextjs_doc_helpers as h
import pytest

TOPIC = h.TOPICS_DIR / "routing-and-metadata.md"
PREFIX = "RT"
MIN_RULES = 15
MIN_ANTI_PATTERNS = 3
MIN_CHECKLIST_ITEMS = 8
TERMS = (
    "layout.tsx", "page.tsx", "loading.tsx", "not-found.tsx", "template.tsx",
    "default.tsx", "[slug]", "[...slug]", "[[...slug]]", "route group",
    "private folder", "parallel route", "intercepting route", "(.)",
    "generateStaticParams", "dynamicParams", "<Link", "prefetch", "useRouter",
    "usePathname", "useSearchParams", "redirect(", "permanentRedirect", "notFound(",
    "generateMetadata", "metadataBase", "generateViewport", "sitemap.ts", "robots.ts",
    "opengraph-image", "ImageResponse", "MetadataRoute",
)
EXAMPLES = {
    "static-params-page": ("generateStaticParams", "params"),
    "typed-generate-metadata": ("generateMetadata", "Metadata"),
    "sitemap": ("MetadataRoute.Sitemap",),
    "not-found-page": ("notFound()",),
    "client-search-params": ("'use client'", "useSearchParams"),
}
ANY_TYPE = re.compile(r"(?::|\bas|<|\|)\s*any\b")
MARKER_LEAD = r"^[ \t]*(?:[-*][ \t]+|#{3,4}[ \t]+)?(?:\*\*)?"
DONT_MARKER = re.compile(MARKER_LEAD + r"Don['’]t\b", re.MULTILINE)
DO_MARKER = re.compile(MARKER_LEAD + r"Do(?=[:*\s])(?![ \t]+not\b)", re.MULTILINE)
FENCE_LINE = re.compile(r"^[ \t]*```", re.MULTILINE)
PARENT_LINK = re.compile(r"\]\(\.\./nextjs\.md(?:#[^)]*)?\)")


def _text() -> str:
    return h.read(TOPIC)


def _rule_ids() -> list[str]:
    return [rule_id for rule_id, _ in h.rule_items(_text())]


def test_routing_topic_replaces_the_stub():
    assert not h.is_stub(_text())


def test_routing_topic_has_at_least_fifteen_rt_rules():
    assert len(_rule_ids()) >= MIN_RULES


def test_routing_topic_cites_no_other_topics_rule_ids():
    ids = _rule_ids()
    assert ids and all(rule_id.startswith(f"{PREFIX}-") for rule_id in ids)
    others = "|".join(prefix for prefix, _ in h.TOPICS.values() if prefix != PREFIX)
    assert re.findall(rf"\b(?:{others})-\d+\b", _text()) == []


def test_routing_topic_covers_required_concepts():
    assert h.missing_terms(_text(), TERMS) == []


@pytest.mark.parametrize("needles", list(EXAMPLES.values()), ids=list(EXAMPLES))
def test_routing_topic_has_worked_example(needles):
    assert h.has_block_with(_text(), *needles), needles


def test_routing_topic_examples_never_type_as_any():
    blocks = h.code_blocks(_text(), ("ts", "tsx"))
    assert [body for _, body in blocks if ANY_TYPE.search(body)] == []


def test_rules_state_the_parallel_route_default_requirement():
    text = _text()
    assert "default" in h.section(text, "Rules")
    assert any(
        "default.tsx" in item and "@" in item and "build" in item
        for _, item in h.rule_items(text)
    )


def test_canonical_layout_is_linked_from_the_topic():
    assert PARENT_LINK.search(_text())


def test_version_notes_name_the_major_and_link_nextjs_org():
    text = _text()
    notes = h.section(text, "Version notes")
    major = h.as_of_version(text).split(".")[0]
    assert notes.strip()
    assert f"Next.js {major}" in notes
    assert "https://nextjs.org/" in notes


def test_every_checklist_item_names_an_rt_rule():
    lines = h.section(_text(), "Review checklist").splitlines()
    items = [line for line in lines if line.lstrip().startswith("- [ ]")]
    assert len(items) >= MIN_CHECKLIST_ITEMS
    assert [line for line in items if f"{PREFIX}-" not in line] == []


def _anti_pattern_chunks(section: str) -> list[str]:
    starts = [match.start() for match in DONT_MARKER.finditer(section)]
    ends = starts[1:] + [len(section)]
    return [section[begin:end] for begin, end in zip(starts, ends)]


def test_every_anti_pattern_pairs_a_dont_with_a_do():
    chunks = _anti_pattern_chunks(h.section(_text(), "Anti-patterns"))
    assert len(chunks) >= MIN_ANTI_PATTERNS
    for chunk in chunks:
        assert DO_MARKER.search(chunk), chunk[:120]
        assert len(FENCE_LINE.findall(chunk)) >= 4, chunk[:120]
        assert f"{PREFIX}-" in chunk, chunk[:120]


def test_not_confirmed_section_lists_the_urls_checked():
    section = h.section(_text(), "Not confirmed by the docs")
    assert "https://nextjs.org/" in section
```

**Adapt only these details, after reading the merged `nextjs_doc_helpers.py`:**

- Check whether `section(text, heading)` expects `"Rules"` or `"## Rules"`, and whether
  `read(path)` takes a `Path` or a file name.
- Check whether `TOPICS` values are `(prefix, slug)`.

Keep every assertion. If the contract's Anti-patterns syntax differs from the default in §9,
widen `DONT_MARKER`/`DO_MARKER` to match it and note that in `validation.md`. Never weaken a
count.

## 4. Data

None. There are no models, migrations or RLS. This is a Markdown and pytest story.

## 5. Config / env / deploy_pending

There are no env vars or config. **deploy_pending: `[]`.** Nothing touches Vercel or Supabase.

## 6. Risks and gates

**Risks**

1. **The skeleton contract is being finalised in parallel.** The rule regex, the
   Anti-patterns item syntax, `section()` semantics and the exact as-of string are all
   defined by the merged skeleton. Before writing, the coder reads `R/nextjs.md`
   `## Authoring contract`, `test_nextjs_reference.py` and `nextjs_doc_helpers.py`. Where they
   differ from this plan, the merged contract wins.
2. **The 800-line cap.** The section budgets in §8 total about 760 lines. If the file goes
   over 790, trim in this order:
   1. the `generateSitemaps` block, keeping RT-39's text;
   2. the `default.tsx` block in the modal pattern;
   3. anti-pattern 6.
3. **URL fragments.** The prose-URL ⊆ Sources check is a string match, so prose links must
   **never use `#fragments`**. The Sources list in §12 is fragment-free. Cite the page and
   name the section in words.
4. **Snippets aren't compiled.** Every snippet in §9–§10 was checked by eye against the
   cited page's own snippet and API shape. The coder copies them verbatim, adapting only
   formatting. REVIEW① spot-checks.
5. **Overlap with sibling topics.** `loading.tsx`/Suspense semantics belong to
   `rendering-and-caching.md`. Typegen and `typedRoutes` setup belong to `typescript.md`. Proxy
   redirects belong to `proxy-auth-and-security.md`. Here they are stated only as far as
   routing needs, with a relative link out.
6. **`any`-scan false positives.** Never write the word `any` after `:`, `as`, `<` or `|` in a
   ts/tsx block, comments included.

**Gates (in the coder's worktree, then again on the run branch after merge)**

```bash
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests/test_nextjs_reference.py -q -rs   # no skip mentioning routing-and-metadata
uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope
wc -l Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/routing-and-metadata.md   # <= 790
git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD   # AC10: only the 2 owned files + this story folder
```

AC9 one-off: put this command and its output in `validation.md`. It must print `equal: True`.

```bash
cd Skills/dev-bother-me-nope/assets/tests && python3 -c "
import re, nextjs_doc_helpers as h
t = h.TOPICS_DIR / 'routing-and-metadata.md'
src = set(h.source_urls(h.read(t)))
ev = set(re.findall(r'https://[^\s|)\x60]+', open('../../../../docs/sprints/bmn-nextjs-typescript-best-practices-reference/app-router-routing-and-metadata/evidence/sources-verified.md').read()))
ev = {u for u in ev if not u.endswith('llms.txt')}
print('equal:', src == ev, sorted(src ^ ev))"
```

(The evidence header mentions `https://nextjs.org/docs/llms.txt` as the version source. It is
excluded above because it isn't cited in the topic file.)

## 7. Verified rule sheet

**Format for the topic file:** each rule is one numbered list item,
`N. **RT-N** <imperative sentence…> [label](url) …`.

- **Write each rule as one physical line** in the topic file, with no hard wraps and no
  sub-bullets. A parser that reads only the item's first line must still see the id, the
  imperative and the citation.
- Where a rule below is split into sub-bullets for readability, join them into sentences on
  that one line.
- Lines labelled **Source**, **Says**, **Snippet**, **Snippets verified** or **Verified** are
  planner notes. They never go into the topic file.
- Everything else (rule text, links and the `(convention)` tag) is copied verbatim.

### File conventions and structure

1. **RT-1** Keep `src/app/` a routing layer in new projects (route folders, special files and
   metadata files only). Put feature code in `src/features/<feature>/` and cross-feature code
   in `src/shared/`, as the canonical layout in [../nextjs.md](../nextjs.md) does
   (convention). This is the docs' "store project files outside of `app`" strategy, and the
   [`src` folder](https://nextjs.org/docs/app/api-reference/file-conventions/src-folder) is
   supported ([project structure](https://nextjs.org/docs/app/getting-started/project-structure)).
   - **Source:** project-structure, src-folder.
   - **Says:** Next.js is unopinionated about layout. "Store project files outside of `app`"
     is one documented strategy. `src/app` is supported.
2. **RT-2** Keep `public/`, `package.json`, `next.config.ts`, `tsconfig.json` and `.env*`
   files at the project root. Put `proxy.ts` inside `src/`, and add `src/` to the `@/*`
   path alias ([src folder](https://nextjs.org/docs/app/api-reference/file-conventions/src-folder)).
   - **Source:** src-folder.
   - **Says:** this is the src-folder page's "Good to know" list, verbatim in substance.
3. **RT-3** Make a segment public only by adding `page.tsx` (UI) or `route.ts` (API), and
   never put both in the same segment. Other files colocated in `app/` are never routable
   ([project structure](https://nextjs.org/docs/app/getting-started/project-structure),
   [Route Handlers](https://nextjs.org/docs/app/getting-started/route-handlers)).
   - **Source:** project-structure "Colocation"; route-handlers.
   - **Says:** "there cannot be a `route.js` file at the same route segment level as
     `page.js`". Only content returned by page/route is sent to the client.
4. **RT-4** Define the required root layout `app/layout.tsx` with `<html>` and `<body>`. Never
   hand-write `<head>`, `<title>` or `<meta>` tags; use the Metadata API, which handles
   streaming and de-duplication of head elements
   ([layout.js](https://nextjs.org/docs/app/api-reference/file-conventions/layout)).
   - **Source:** layout "Root Layout".
   - **Says:** the root layout must define html/body, and you should not manually add head
     tags.
5. **RT-5** Use a route group `(name)` to share a layout across a subset of routes without
   changing URLs; `(auth)/login/page.tsx` serves `/login`. Never let two groups resolve to the
   same path. Define `/` inside a group when there is no top-level `layout.tsx`. Navigating
   between multiple root layouts is a full page load
   ([route groups](https://nextjs.org/docs/app/api-reference/file-conventions/route-groups)).
   - **Source:** route-groups "Caveats"; project-structure.
   - **Says:** groups are omitted from the URL. Conflicting paths cause an error. Moving
     across root layouts triggers a full reload.
6. **RT-6** Prefix a folder with `_` (a private folder) when route-local helpers must live
   inside `app/` in an existing repo; this opts the folder and its subfolders out of routing.
   Use `%5F` to start a URL segment with an underscore
   ([project structure](https://nextjs.org/docs/app/getting-started/project-structure)).
   - **Source:** project-structure "Private folders".
7. **RT-7** Use `template.tsx` only when a segment's children must remount on navigation, to
   reset client state or re-run effects. Otherwise use `layout.tsx`, which keeps state. A
   template remounts when its own segment or its params change, not on search-param changes
   ([template.js](https://nextjs.org/docs/app/api-reference/file-conventions/template)).
   - **Source:** template "Behavior".
8. **RT-8** Add `loading.tsx` to dynamic routes so navigation is immediate and the route can
   be partially prefetched. It doesn't cover uncached data the same segment's layout awaits
   (`cookies()`, `headers()`, uncached fetches). Wrap that data in its own `<Suspense>` or move
   it into the page; [rendering-and-caching.md](rendering-and-caching.md) has the details
   ([linking and navigating](https://nextjs.org/docs/app/getting-started/linking-and-navigating),
   [loading.js](https://nextjs.org/docs/app/api-reference/file-conventions/loading)).
   - **Source:** linking-and-navigating "Dynamic routes without loading.tsx"; loading
     "Instant Loading States".
9. **RT-9** Add `not-found.tsx` for `notFound()` UI; the root `app/not-found.tsx` also serves
   every unmatched URL. Place `error.tsx` and `global-error.tsx` following the strategy in
   [testing-and-observability.md](testing-and-observability.md). Treat
   `forbidden.tsx`/`unauthorized.tsx` (behind `experimental.authInterrupts`) and
   `global-not-found.tsx` (behind `experimental.globalNotFound`) as experimental. The
   forbidden and unauthorized pages say they are not recommended for production
   ([not-found.js](https://nextjs.org/docs/app/api-reference/file-conventions/not-found),
   [error.js](https://nextjs.org/docs/app/api-reference/file-conventions/error),
   [forbidden.js](https://nextjs.org/docs/app/api-reference/file-conventions/forbidden),
   [unauthorized.js](https://nextjs.org/docs/app/api-reference/file-conventions/unauthorized)).
   - **Source:** those 4 pages.
   - **Says:**
     - The root not-found handles unmatched URLs.
     - `global-not-found` is experimental, behind `experimental.globalNotFound`.
     - `forbidden`/`unauthorized` are "currently experimental… not recommended for
       production" and need `authInterrupts`.
     - `global-error` must render its own html/body.

### Dynamic segments and params

10. **RT-10** Name dynamic segments `[slug]` (one `string`), `[...slug]` (catch-all,
    `string[]`) and `[[...slug]]` (optional catch-all, `slug?: string[]`, which also matches the
    bare path), and type `params` to match
    ([dynamic routes](https://nextjs.org/docs/app/api-reference/file-conventions/dynamic-routes)).
    - **Source:** dynamic-routes, with the TypeScript table.
11. **RT-11** Await `params` in pages, layouts, `route.ts`, `default.tsx`, `generateMetadata`
    and the `opengraph-image`/`twitter-image`/`icon`/`apple-icon` files. Await `searchParams`
    in pages. Both are Promises, and Next.js 16 removed synchronous access
    ([version 16 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-16),
    [page.js](https://nextjs.org/docs/app/api-reference/file-conventions/page),
    [generateMetadata](https://nextjs.org/docs/app/api-reference/functions/generate-metadata)).
    In a Client Component page, unwrap them with React's
    [`use()`](https://react.dev/reference/react/use). Two documented exceptions take
    synchronous `params`: [`generateStaticParams`](https://nextjs.org/docs/app/api-reference/functions/generate-static-params)
    (the parent params) and
    [`generateImageMetadata`](https://nextjs.org/docs/app/api-reference/functions/generate-image-metadata).
    - **Source:** v16 guide "Async Request APIs"; page; generate-metadata (awaits
      `params`); v15 guide (generateMetadata params became Promises); react use.
    - **Says:** "Starting with Next.js 16, synchronous access is fully removed." The list
      names layout, page, route, default and the four image files.
    - **Snippet:** `const { slug } = await props.params`, exactly as in the guide.
12. **RT-12** Type route props with the generated global helpers
    `PageProps<'/route'>` and `LayoutProps<'/route'>`. They need no import, and they are
    generated by `next dev`, `next build` or `next typegen`; `LayoutProps` also types named
    slots ([layouts and pages](https://nextjs.org/docs/app/getting-started/layouts-and-pages)).
    Setup lives in [typescript.md](typescript.md).
    - **Says:** "PageProps, LayoutProps are global helpers — no imports required." Static
      routes resolve `params` to `{}`.
13. **RT-13** Validate every `params` value at runtime before using it, because values arrive
    as `string`/`string[]`/`undefined` from any URL. Call `notFound()` on invalid values,
    narrowing with an assertion function
    ([dynamic routes](https://nextjs.org/docs/app/api-reference/file-conventions/dynamic-routes)).
    - **Says:** the TypeScript section has the `assertValidLocale(value): asserts value is
      Locale` example, which calls `notFound()`.
14. **RT-14** Read root params, the dynamic segments above the root layout such as
    `app/[lang]/layout.tsx`, with the `next/root-params` getters (`await lang()`) in Server
    Components instead of prop drilling. They aren't available in Client Components, Server
    Actions or Route Handlers. Segment names must be valid JS identifiers, so
    `[post-slug]` fails
    ([next/root-params](https://nextjs.org/docs/app/api-reference/functions/next-root-params),
    [Next.js 16.3](https://nextjs.org/blog/next-16-3)).
    - **Says:** this was introduced in v16.3.0. With Cache Components, each root param
      needs ≥1 `generateStaticParams` value.

### Static params

15. **RT-15** Export `generateStaticParams` from every dynamic segment whose values are known
    at build time (in a page, layout or `route.ts`), and always return an array. Omit it and
    the route renders dynamically at request time. Return `[]` to render every path on its
    first visit instead
    ([generateStaticParams](https://nextjs.org/docs/app/api-reference/functions/generate-static-params),
    [linking and navigating](https://nextjs.org/docs/app/getting-started/linking-and-navigating)).
    - **Says:** "You must always return an array… Otherwise, the route will be dynamically
      rendered." Missing it means falling back to dynamic rendering.
16. **RT-16** Return at least one param from `generateStaticParams` when Cache Components
    (`cacheComponents: true`) is on, because an empty array is a build error. The documented
    escape hatch is a placeholder param handled with `notFound()`, and it weakens build-time
    validation
    ([generateStaticParams](https://nextjs.org/docs/app/api-reference/functions/generate-static-params)).
17. **RT-17** Export `dynamicParams = false` to 404 params that `generateStaticParams` did not
    return, but only while Cache Components is off. Next.js 16 removed `dynamicParams` (with
    `dynamic`, `revalidate` and `fetchCache`) when `cacheComponents` is enabled
    ([dynamicParams](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/dynamicParams),
    [route segment config](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config)).
    - **Says:** the default is `true`, which generates at request time. `false` returns a 404.
      It is "not available when Cache Components is enabled". The v16.0.0 history row records
      the removal.
18. **RT-18** Generate params for nested dynamic segments in one of two ways:
    - **bottom-up:** the leaf page returns every segment;
    - **top-down:** the parent layout returns its own params, and the child reads them from
      its synchronous `params` argument.

    A segment can generate params only for itself and the segments above it
    ([generateStaticParams](https://nextjs.org/docs/app/api-reference/functions/generate-static-params)).

### Parallel and intercepting routes

19. **RT-19** Give every named `@slot` an explicit `default.tsx`, because Next.js 16 builds
    fail without one. Return `null` to render nothing, or call `notFound()` to keep the
    pre-16 404. Also add a `default.tsx` beside the slots for the implicit `children` slot.
    Without it, a hard navigation that can't recover the parent's active state renders a 404
    ([version 16 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-16),
    [default.js](https://nextjs.org/docs/app/api-reference/file-conventions/default),
    [parallel routes](https://nextjs.org/docs/app/api-reference/file-conventions/parallel-routes)).
    - **Source:** v16 guide "Parallel Routes `default.js` requirement".
    - **Says:**
      - "All parallel route slots now require explicit default.js files. Builds will fail
        without them… create a default.js… that calls notFound() or returns null."
      - default page: a missing default errors for named slots, and a missing `children`
        default returns a 404.
    - **Snippets verified:** `export default function Default() { return null }` and the
      `notFound()` variant.
    - This rule must contain `default.tsx`, `@` and `build`, because the AC5 test checks for
      them.
20. **RT-20** Treat each `@slot` as a prop of the parent layout that never changes the URL.
    - Authorize inside each slot's page or Data Access Layer. Every slot renders on the
      server, even when the layout returns only one.
    - Expect one dynamic slot to make every slot at its level dynamic.

    ([parallel routes](https://nextjs.org/docs/app/api-reference/file-conventions/parallel-routes)).
    - **Says:**
      - "Slots are not route segments and do not affect the URL structure."
      - "Both slots render on the server, regardless of which one the layout returns…
        Authorize inside each slot's page."
      - "If one slot is dynamic, all slots at that level must be dynamic."
21. **RT-21** Build URL-addressable modals by intercepting the real route inside a slot:
    `@modal/(.)photos/[id]/page.tsx` sits beside `photos/[id]/page.tsx`.
    - The matchers are `(.)` same level, `(..)` one up, `(..)(..)` two up and `(...)` from
      the root `app`. They count route segments, so `@slot` folders don't count.
    - Close the modal with `router.back()`, or with `<Link>` plus a slot `page.tsx` or
      `[...catchAll]/page.tsx` that returns `null`.
    - A refresh or a shared URL renders the full page, not the modal.

    ([intercepting routes](https://nextjs.org/docs/app/api-reference/file-conventions/intercepting-routes),
    [parallel routes](https://nextjs.org/docs/app/api-reference/file-conventions/parallel-routes)).
    - **Says:** "The (..) convention is based on route segments, not the file-system… it
      does not consider @slot folders." Modal closing is covered in parallel-routes
      "Closing the modal".

### Navigation and prefetching

22. **RT-22** Navigate with `<Link href>` from `next/link`.
    - Use `useRouter` only for programmatic navigation in Client Component event handlers.
    - Never pass `router.push`/`router.replace` an untrusted or unsanitized URL, because a
      `javascript:` URL executes in the page.
    - With `typedRoutes` on, cast non-literal hrefs with `as Route`; setup is in
      [typescript.md](typescript.md).

    ([Link](https://nextjs.org/docs/app/api-reference/components/link),
    [useRouter](https://nextjs.org/docs/app/api-reference/functions/use-router),
    [TypeScript](https://nextjs.org/docs/app/api-reference/config/typescript)).
    - **Says:** "Recommendation: Use the `<Link>` component for navigation unless you have a
      specific requirement for using `useRouter`." The XSS warning is in useRouter's "Good to
      know". Typed links: "For non-literal strings, you need to manually cast with `as Route`."
23. **RT-23** Keep `<Link>`'s default prefetch (`"auto"`/`null`). It prefetches static
    routes in full and dynamic routes down to the nearest `loading.tsx`.
    - Set `prefetch={false}` on large link lists such as infinite tables, or defer
      prefetching to hover.
    - Judge prefetching only in production, because it is disabled in development.
    - `<Link>` must hydrate before it can prefetch.

    ([Link](https://nextjs.org/docs/app/api-reference/components/link),
    [linking and navigating](https://nextjs.org/docs/app/getting-started/linking-and-navigating),
    [prefetching](https://nextjs.org/docs/app/guides/prefetching)).
    - **Says:** "Prefetching is only enabled in production." Hover pattern:
      `prefetch={active ? null : false}` with `onMouseEnter`.
24. **RT-24** Keep layouts and pages free of side effects such as analytics calls, which can
    run when the route is prefetched rather than visited. Move them into a Client Component
    `useEffect` or a Server Action
    ([prefetching](https://nextjs.org/docs/app/guides/prefetching)).
    - **Says:** this is the prefetching guide's "Triggering unwanted side-effects during
      prefetching" section.
25. **RT-25** Enable `partialPrefetching: true` only together with `cacheComponents: true`;
    without it, `next dev` and `next build` throw at config validation.
    - Audit existing `<Link prefetch={true}>` links first, because their behaviour changes.
    - To opt in per segment, use `export const prefetch = 'partial'` or
      `'force-disabled'`. This needs Cache Components, and you never write `'auto'`
      explicitly.

    ([partialPrefetching](https://nextjs.org/docs/app/api-reference/config/next-config-js/partialPrefetching),
    [adopting Partial Prefetching](https://nextjs.org/docs/app/guides/adopting-partial-prefetching),
    [prefetch segment config](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/prefetch),
    [Next.js 16.3](https://nextjs.org/blog/next-16-3)).
    - **Says:** introduced in 16.3.0. "requires cacheComponents. Without it, next dev and
      next build throw."
26. **RT-26** Import `useRouter`, `usePathname`, `useSearchParams` and `useParams` from
    `next/navigation`, never `next/router`, and read URL state in Client Components. Layouts
    receive neither `searchParams` nor the pathname, because they don't re-render on
    navigation ([useRouter](https://nextjs.org/docs/app/api-reference/functions/use-router),
    [layout.js](https://nextjs.org/docs/app/api-reference/file-conventions/layout)).
27. **RT-27** Wrap every Client Component that calls `useSearchParams` in
    [`<Suspense>`](https://react.dev/reference/react/Suspense) on prerendered routes.
    Production builds fail without it, though development looks fine. With Cache Components,
    also wrap `usePathname` and `useParams` callers on routes whose params
    `generateStaticParams` doesn't cover
    ([useSearchParams](https://nextjs.org/docs/app/api-reference/functions/use-search-params),
    [usePathname](https://nextjs.org/docs/app/api-reference/functions/use-pathname),
    [useParams](https://nextjs.org/docs/app/api-reference/functions/use-params)).
    - **Says:** the build fails with "Missing Suspense boundary with useSearchParams". Under
      cacheComponents, usePathname/useParams "suspends… otherwise, the build fails".
28. **RT-28** Read `searchParams` from the page prop when the server needs them to load data.
    That prop is a plain object, not `URLSearchParams`, and it makes the page dynamic. Use
    `useSearchParams` only for state that exists only on the client
    ([layouts and pages](https://nextjs.org/docs/app/getting-started/layouts-and-pages),
    [page.js](https://nextjs.org/docs/app/api-reference/file-conventions/page)).
    - **Says:** this is "What to use and when". "searchParams is a plain JavaScript object,
      not a URLSearchParams instance."
29. **RT-29** Call `useLinkStatus` only in a descendant of `<Link>`, to show a fixed-size
    pending hint while prefetching is off or incomplete. Treat it as a quick patch, and fix
    the cause with prefetching or `loading.tsx`
    ([useLinkStatus](https://nextjs.org/docs/app/api-reference/functions/use-link-status)).
30. **RT-30** Add `data-scroll-behavior="smooth"` to `<html>` only when the app sets a global
    `scroll-behavior: smooth` and wants Next.js to suspend it during navigation, because
    Next.js 16 no longer overrides it. Keep the scroll position with `scroll={false}` on
    `<Link>` or `{ scroll: false }` on `router.push`/`replace`
    ([version 16 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-16),
    [Link](https://nextjs.org/docs/app/api-reference/components/link)).

### Redirects and not found

31. **RT-31** Use the right redirect function:
    - `redirect()` for temporary redirects: 307, or 303 for a progressive-enhancement Server
      Action form post. With JS available, a Server Action does a client-side navigation.
    - `permanentRedirect()` when an entity's canonical URL changes: 308.

    Call both outside `try`/`catch` and without `return`, because they throw and are typed
    `never`. Never call them from a Client Component event handler; use `router.push` there
    ([redirect](https://nextjs.org/docs/app/api-reference/functions/redirect),
    [permanentRedirect](https://nextjs.org/docs/app/api-reference/functions/permanentRedirect),
    [redirecting](https://nextjs.org/docs/app/guides/redirecting)).
    - **Says:**
      - "redirect throws an error so it should be called outside the try block."
      - "can be called in Client Components during the rendering process but not in event
        handlers."
      - The type parameter is `replace` by default and `push` in Server Actions.
32. **RT-32** Pick the redirect mechanism by when it runs:
    - `redirects()` in `next.config.ts` for path maps known ahead of time. It runs before
      Proxy, and `permanent` selects 308 over 307.
    - Proxy `NextResponse.redirect` for conditional redirects; see
      [proxy-auth-and-security.md](proxy-auth-and-security.md).
    - For 1,000+ redirects, use the guide's Proxy-backed redirect map, or Vercel
      [Bulk Redirects](https://vercel.com/docs/routing/redirects).

    ([redirecting](https://nextjs.org/docs/app/guides/redirecting)).
    - **Says:** "redirects runs before Proxy". The "Managing redirects at scale (advanced)"
      section covers large maps. Vercel's table offers Bulk redirects "for large-scale
      migrations".
33. **RT-33** Call `notFound()` in the render path when a record is missing: in a component,
    a function it awaits, `generateMetadata` or a Route Handler.
    - Never let a `try`/`catch` swallow it; let it through with `unstable_rethrow`.
    - When the response must carry a real 404 status, run the existence check before any
      `<Suspense>`/`loading.tsx` streaming starts. A streamed not-found is a `200` with
      `noindex`.

    ([notFound](https://nextjs.org/docs/app/api-reference/functions/not-found),
    [loading.js](https://nextjs.org/docs/app/api-reference/file-conventions/loading)).
    - **Says:**
      - "You do not need to write `return notFound()`… `never` return type."
      - "A try/catch around the call suppresses it."
      - The streaming status-code caveat.

### Metadata

34. **RT-34** Export a static `metadata: Metadata` object unless metadata depends on request
    data or params. In that case, export `generateMetadata` instead. Never export both from
    one segment, and export them only from Server Components; move client logic into a child
    component ([generateMetadata](https://nextjs.org/docs/app/api-reference/functions/generate-metadata),
    [metadata and OG images](https://nextjs.org/docs/app/getting-started/metadata-and-og-images)).
    - **Says:** "You cannot export both the metadata object and generateMetadata function
      from the same route segment." Both are "only supported in Server Components".
35. **RT-35** Set `metadataBase` once in the root layout so relative URL fields (canonical,
    alternates, Open Graph images) resolve; relative URLs without it fail the build.
    - Return it as a string from a `'use cache'` `generateMetadata`.
    - Define `title.template` in layouts together with the required `title.default`.
    - Use `title.absolute` to escape a parent template.

    ([generateMetadata](https://nextjs.org/docs/app/api-reference/functions/generate-metadata)).
    - **Says:**
      - "Using a relative path in a URL-based metadata field without configuring a
        metadataBase will cause a build error."
      - "title.default is required when you add a title.template."
      - A template applies only to child segments.
36. **RT-36** Fetch data that `generateMetadata` and the page share through one React
    [`cache()`](https://react.dev/reference/react/cache)-wrapped function. `fetch` is already
    memoized. Re-spread nested objects such as `openGraph` (or read `await parent`) when a
    child must keep the parent's fields: metadata merges shallowly, so a child's `openGraph`
    replaces the parent's
    ([metadata and OG images](https://nextjs.org/docs/app/getting-started/metadata-and-og-images),
    [generateMetadata](https://nextjs.org/docs/app/api-reference/functions/generate-metadata)).
37. **RT-37** Put `themeColor`, `colorScheme`, `width`, `initialScale` and the other viewport
    fields in `export const viewport: Viewport` or in `generateViewport`, never in `metadata`,
    where they have been deprecated since Next.js 14. Like metadata, these exports are
    Server-Component-only and you never export both from one segment
    ([generateViewport](https://nextjs.org/docs/app/api-reference/functions/generate-viewport),
    [generateMetadata](https://nextjs.org/docs/app/api-reference/functions/generate-metadata)).
38. **RT-38** Prefer file-based metadata to config.
    - `favicon.ico` goes only at the root of `app/` and can't be generated.
    - `icon`/`apple-icon` and `opengraph-image`/`twitter-image` (with `.alt.txt`) go in any
      segment.
    - File-based metadata overrides `metadata`/`generateMetadata`, and a deeper
      `opengraph-image` takes precedence over one higher in the tree.
    - Static OG images over 8 MB and Twitter images over 5 MB fail the build.

    ([metadata and OG images](https://nextjs.org/docs/app/getting-started/metadata-and-og-images),
    [app icons](https://nextjs.org/docs/app/api-reference/file-conventions/metadata/app-icons),
    [opengraph-image](https://nextjs.org/docs/app/api-reference/file-conventions/metadata/opengraph-image),
    [Next.js 16.2](https://nextjs.org/blog/next-16-2)).
    - **Says:**
      - "Favicons can only be set in the root /app segment."
      - "You cannot generate a favicon icon."
      - The size limits and build failure.
      - 16.2: `icon.png` and `icon.svg` are both emitted.
39. **RT-39** Generate `app/sitemap.ts` returning `MetadataRoute.Sitemap` and `app/robots.ts`
    returning `MetadataRoute.Robots`. These are special Route Handlers, cached unless they
    use a Request-time API. Split large sitemaps with nested `sitemap.ts` files or with
    `generateSitemaps`, and await its `id` prop, which is a `Promise<string>` in Next.js 16
    ([sitemap](https://nextjs.org/docs/app/api-reference/file-conventions/metadata/sitemap),
    [robots](https://nextjs.org/docs/app/api-reference/file-conventions/metadata/robots),
    [generateSitemaps](https://nextjs.org/docs/app/api-reference/functions/generate-sitemaps),
    [version 16 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-16)).
40. **RT-40** Generate dynamic Open Graph images in `opengraph-image.tsx` with `ImageResponse`
    from `next/og`.
    - Export `alt`, `size` and `contentType`. Vercel recommends 1200×630.
    - Await `params`, and `id` when you use `generateImageMetadata`.
    - Stay within flexbox-only CSS, `ttf`/`otf`/`woff` fonts and the 500 KB bundle limit.
    - Generated images are statically optimized unless they use Request-time APIs or
      uncached data.

    ([opengraph-image](https://nextjs.org/docs/app/api-reference/file-conventions/metadata/opengraph-image),
    [ImageResponse](https://nextjs.org/docs/app/api-reference/functions/image-response),
    [generateImageMetadata](https://nextjs.org/docs/app/api-reference/functions/generate-image-metadata),
    [Vercel OG image generation](https://vercel.com/docs/og-image-generation)).

**APIs that changed in the latest major (Next.js 16) are flagged in rules RT-11, RT-17,
RT-19, RT-23, RT-30, RT-39 and RT-40. They are listed with links in §11.**

## 8. Topic file outline and line budget (≤ 790)

```text
# App Router routing, navigation and metadata          (H1)
> As of Next.js 16.3.8, verified 2026-10-04.             (copy the exact line from R/nextjs.md)
## Scope                    ~15   (§8.1)
## Rules                    ~150  (§7, RT-1..RT-40, sub-grouped with ### headings only if the contract allows; otherwise one flat list)
## Patterns                 ~290  (§9)
## Anti-patterns            ~140  (§10)
## Version notes            ~24   (§11)
## Review checklist         ~18   (§11.1)
## Not confirmed by the docs ~22  (§11.2)
## Sources                  ~60   (§12)
```

If the contract's rule parser needs one contiguous numbered list, drop the `###` group
headings in `## Rules`.

### 8.1 Scope text (verbatim)

> This file covers:
>
> - the App Router file conventions;
> - dynamic, catch-all and optional catch-all segments;
> - route groups and private folders;
> - parallel routes and intercepting routes;
> - `generateStaticParams` and `dynamicParams`;
> - navigation with `<Link>`, the `next/navigation` hooks, `redirect()`, `permanentRedirect()`
>   and `notFound()`, and prefetching;
> - the Metadata API: static `metadata`, `generateMetadata`, `generateViewport`, and the
>   file-based icons, Open Graph images, `sitemap.ts` and `robots.ts`.
>
> It maps the canonical layout in [../nextjs.md](../nextjs.md) onto these conventions and
> never redefines that layout. Other topics own the following:
>
> | Topic | File |
> | --- | --- |
> | Rendering, caching and Suspense semantics | [rendering-and-caching.md](rendering-and-caching.md) |
> | Error-handling strategy (`error.tsx`, `global-error.tsx`) | [testing-and-observability.md](testing-and-observability.md) |
> | `route.ts` internals | [route-handlers-and-apis.md](route-handlers-and-apis.md) |
> | Proxy redirects and auth | [proxy-auth-and-security.md](proxy-auth-and-security.md) |
> | Type generation and `typedRoutes` setup | [typescript.md](typescript.md) |
> | Server Action mutations | [data-fetching-and-mutations.md](data-fetching-and-mutations.md) |

## 9. Patterns (verbatim content; every snippet checked against the cited page)

Each pattern is an `###` heading naming the rules it shows. Fences use plain `tsx`/`ts`/`text`
tags, with the file path in a first-line comment and no `filename=` attributes.

### 9.1 Canonical layout → routing conventions (RT-1, RT-2, RT-3, RT-5, RT-38, RT-39)

The prose starts: "The layout below is canonical for new projects ([../nextjs.md](../nextjs.md));
an existing repo keeps its own." Then comes this table:

| Canonical path | URL | Convention |
| --- | --- | --- |
| `src/app/layout.tsx` | wraps every route | root layout (RT-4) |
| `src/app/page.tsx` | `/` | page (RT-3) |
| `src/app/(auth)/layout.tsx` | — | route group layout: auth-only UI, URL unchanged (RT-5) |
| `src/app/(auth)/login/page.tsx` | `/login` | group omitted from the URL (RT-5) |
| `src/app/(dashboard)/dashboard/page.tsx` | `/dashboard` | group omitted from the URL (RT-5) |
| `src/app/api/webhooks/route.ts` | `/api/webhooks` | Route Handler; no `page.tsx` in the same segment (RT-3), see [route-handlers-and-apis.md](route-handlers-and-apis.md) |
| `src/proxy.ts` | — | Proxy lives inside `src/` (RT-2) |
| `public/`, `next.config.ts`, `tsconfig.json` | — | stay at the project root (RT-2) |

Then: "This topic adds these docs-confirmed files, which the tree doesn't show:"

- `src/app/favicon.ico` (root only)
- `src/app/sitemap.ts`
- `src/app/robots.ts`
- `src/app/not-found.tsx`
- `loading.tsx` in dynamic segments
- `opengraph-image.tsx` per segment

The table and list are prose plus a table, with no fence needed. Optionally add a short
` ```text ` tree. Skip it if the line budget is tight.

### 9.2 Dynamic segment with static params and a 404 for missing records (RT-11, RT-12, RT-15, RT-33)

```tsx
// src/app/blog/[slug]/page.tsx
import { notFound } from 'next/navigation'
import { getPost, getPublishedSlugs } from '@/features/blog/services/posts'

export async function generateStaticParams(): Promise<Array<{ slug: string }>> {
  const slugs = await getPublishedSlugs()
  return slugs.map((slug) => ({ slug }))
}

export default async function Page(props: PageProps<'/blog/[slug]'>) {
  const { slug } = await props.params
  const post = await getPost(slug)
  if (!post) {
    notFound()
  }
  return (
    <article>
      <h1>{post.title}</h1>
      <p>{post.body}</p>
    </article>
  )
}
```

- **Verified:** `generateStaticParams` returns `{ slug }[]` (generate-static-params,
  "Single Dynamic Segment").
- **Verified:** `PageProps<'/blog/[slug]'>` with `await props.params` (layouts-and-pages
  "Route Props Helpers").
- **Verified:** `notFound()` without `return` narrows `post` (not-found "Good to know").

### 9.3 Shared, cached data and typed dynamic metadata (RT-34, RT-35, RT-36)

```ts
// src/features/blog/services/posts.ts (getPublishedSlugs and getPublishedPosts live here too)
import { cache } from 'react'
import { parsePost, type Post } from './post-schema'

export const getPost = cache(async (slug: string): Promise<Post | undefined> => {
  const res = await fetch(`https://api.example.com/posts/${encodeURIComponent(slug)}`)
  if (res.status === 404) return undefined
  if (!res.ok) throw new Error(`Failed to load post: ${res.status}`)
  const data: unknown = await res.json()
  return parsePost(data) // runtime validation: see typescript.md
})
```

```tsx
// src/app/blog/[slug]/page.tsx (add to the page above)
import type { Metadata } from 'next'

export async function generateMetadata(props: PageProps<'/blog/[slug]'>): Promise<Metadata> {
  const { slug } = await props.params
  const post = await getPost(slug) // same cache()d call as the page: fetched once
  if (!post) {
    notFound()
  }
  return {
    title: post.title, // rendered as "<title> | Acme" by the root title.template
    description: post.summary,
    alternates: { canonical: `/blog/${slug}` }, // resolved against metadataBase
  }
}
```

- **Verified:** this follows the metadata guide's "Memoizing data requests" (a
  `cache(async (slug: string) => …)` getter used by both).
- **Verified:** generate-metadata, which types the first argument with `PageProps` and
  allows `notFound()` inside `generateMetadata`.
- **Verified:** `alternates.canonical` with `metadataBase` (generate-metadata "metadataBase").
- **Note:** `parsePost`/`Post` are local modules (convention). Say this in one prose line and
  link [typescript.md](typescript.md).

### 9.4 Root layout: metadataBase, title template and viewport (RT-4, RT-35, RT-37)

```tsx
// src/app/layout.tsx
import type { Metadata, Viewport } from 'next'
import './globals.css'

export const metadata: Metadata = {
  metadataBase: new URL('https://acme.com'),
  title: { template: '%s | Acme', default: 'Acme' },
  description: 'Acme app',
}

export const viewport: Viewport = {
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: 'white' },
    { media: '(prefers-color-scheme: dark)', color: 'black' },
  ],
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
```

- **Verified:** generate-metadata (`title.template`/`default`, `metadataBase: new URL(…)`).
- **Verified:** generate-viewport, "With media attribute" (the `themeColor` array).
- **Verified:** layout "Root Layout".

### 9.5 `sitemap.ts`, `robots.ts` and split sitemaps (RT-39)

```ts
// src/app/sitemap.ts
import type { MetadataRoute } from 'next'
import { getPublishedPosts } from '@/features/blog/services/posts'

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const posts = await getPublishedPosts()
  return [
    { url: 'https://acme.com', lastModified: new Date(), changeFrequency: 'yearly', priority: 1 },
    ...posts.map((post) => ({ url: `https://acme.com/blog/${post.slug}`, lastModified: post.updatedAt })),
  ]
}
```

```ts
// src/app/robots.ts
import type { MetadataRoute } from 'next'

export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: '*', allow: '/', disallow: '/dashboard/' },
    sitemap: 'https://acme.com/sitemap.xml',
  }
}
```

```ts
// src/app/products/sitemap.ts (served at /products/sitemap/<id>.xml)
import type { MetadataRoute } from 'next'
import { getProductsPage } from '@/features/catalog/services/products'

const URLS_PER_SITEMAP = 50_000 // Google's per-sitemap limit, per the Next.js docs

export async function generateSitemaps(): Promise<Array<{ id: number }>> {
  return [{ id: 0 }, { id: 1 }]
}

export default async function sitemap(props: { id: Promise<string> }): Promise<MetadataRoute.Sitemap> {
  const page = Number(await props.id) // Next.js 16: id arrives as Promise<string>
  const products = await getProductsPage(page * URLS_PER_SITEMAP, URLS_PER_SITEMAP)
  return products.map((product) => ({
    url: `https://acme.com/products/${product.id}`,
    lastModified: product.updatedAt,
  }))
}
```

- **Verified:** sitemap "Generating a sitemap using code", including the `changeFrequency`
  and `priority` literals.
- **Verified:** robots "Generate a Robots file".
- **Verified:** sitemap/generate-sitemaps, which give the URL as `/…/sitemap/[id].xml`.
- **Verified:** the v16 guide's `Number(resolvedId)`.

### 9.6 Generated Open Graph image (RT-11, RT-40)

```tsx
// src/app/blog/[slug]/opengraph-image.tsx
import { ImageResponse } from 'next/og'
import { getPost } from '@/features/blog/services/posts'

export const alt = 'Acme blog post'
export const size = { width: 1200, height: 630 }
export const contentType = 'image/png'

export default async function Image({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const post = await getPost(slug)
  return new ImageResponse(
    (
      <div
        style={{
          fontSize: 64,
          background: 'white',
          width: '100%',
          height: '100%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {post?.title ?? 'Acme'}
      </div>
    ),
    { ...size }
  )
}
```

- **Verified:** opengraph-image "Using external data". The snippet matches it with
  `fontSize` changed.

### 9.7 Client Component reading and updating search params (RT-22, RT-26, RT-27, RT-28)

```tsx
// src/features/catalog/components/sort-select.tsx
'use client'

import { usePathname, useRouter, useSearchParams } from 'next/navigation'

const SORT_OPTIONS = ['newest', 'price-asc', 'price-desc'] as const
type SortOption = (typeof SORT_OPTIONS)[number]

function isSortOption(value: string): value is SortOption {
  return (SORT_OPTIONS as readonly string[]).includes(value)
}

export function SortSelect() {
  const router = useRouter()
  const pathname = usePathname()
  const searchParams = useSearchParams()
  const raw = searchParams.get('sort') ?? ''
  const current: SortOption = isSortOption(raw) ? raw : 'newest'

  function select(value: string) {
    if (!isSortOption(value)) return
    const next = new URLSearchParams(searchParams.toString())
    next.set('sort', value)
    router.replace(`${pathname}?${next.toString()}`, { scroll: false })
  }

  return (
    <select value={current} onChange={(event) => select(event.target.value)}>
      {SORT_OPTIONS.map((option) => (
        <option key={option} value={option}>
          {option}
        </option>
      ))}
    </select>
  )
}
```

```tsx
// src/app/products/page.tsx
import { Suspense } from 'react'
import { SortSelect } from '@/features/catalog/components/sort-select'

export default function Page() {
  return (
    <main>
      <Suspense fallback={<p>Loading filters…</p>}>
        <SortSelect />
      </Suspense>
      {/* Server-side filtering reads this page's searchParams prop instead (RT-28). */}
    </main>
  )
}
```

- **Verified:** use-search-params, "Updating searchParams" (the
  `new URLSearchParams(searchParams.toString())` + `router.push(pathname + '?' + …)` pattern)
  and "Prerendering" (the Suspense wrapper).
- **Verified:** use-router (`replace(href, { scroll })`).
- **Note:** under `typedRoutes`, the template-literal href would need `as Route` (RT-22).
  Say so in one line.

### 9.8 URL-addressable modal: parallel and intercepting routes (RT-19, RT-20, RT-21)

```text
src/app/(dashboard)/dashboard/
├── layout.tsx                  # renders {children} and {modal}
├── page.tsx                    # /dashboard
├── photos/[id]/page.tsx        # full page on refresh or a shared link
└── @modal/
    ├── default.tsx             # return null; required for every slot in Next.js 16
    ├── page.tsx                # return null; closes the modal on <Link> back to /dashboard
    ├── [...catchAll]/page.tsx  # return null; closes it on <Link> to any other sub-path
    └── (.)photos/[id]/page.tsx # soft navigation to /dashboard/photos/1 opens the modal
```

```tsx
// src/app/(dashboard)/dashboard/layout.tsx
export default function DashboardLayout({
  children,
  modal,
}: {
  children: React.ReactNode
  modal: React.ReactNode
}) {
  return (
    <section>
      {children}
      {modal}
    </section>
  )
}
```

```tsx
// src/app/(dashboard)/dashboard/@modal/(.)photos/[id]/page.tsx
import { Modal } from '@/shared/components/modal'
import { PhotoView } from '@/features/photos/components/photo-view'

export default async function PhotoModal({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  return (
    <Modal>
      <PhotoView id={id} />
    </Modal>
  )
}
```

```tsx
// src/shared/components/modal.tsx
'use client'

import { useRouter } from 'next/navigation'

export function Modal({ children }: { children: React.ReactNode }) {
  const router = useRouter()
  return (
    <div role="dialog" aria-modal="true">
      <button type="button" onClick={() => router.back()}>
        Close
      </button>
      {children}
    </div>
  )
}
```

```tsx
// src/app/(dashboard)/dashboard/@modal/default.tsx (page.tsx and [...catchAll]/page.tsx are the same)
export default function Default() {
  return null
}
```

- **Verified:** parallel-routes "Modals", "Opening the modal" and "Closing the modal". That
  covers the slot props, the `default` returning null, `@slot/page.tsx` and
  `[...catchAll]/page.tsx` returning null, and the Modal with `router.back()`.
- **Verified:** intercepting-routes. `(.)` is the same level, because `@modal` is a slot,
  not a segment.
- **Design choice:** the interceptor and its target sit in the same `(dashboard)` group,
  because whether matchers count group folders is unconfirmed (§11.2 #4).
- **Design choice:** the layout types slots explicitly rather than with
  `LayoutProps<'/dashboard'>`, because how a group path appears in route literals is
  unconfirmed (§11.2 #3).

## 10. Anti-patterns (verbatim; default item syntax)

**Default syntax**, used unless the merged contract prescribes another:

1. An H3 line `### Don't <what> (RT-n)`.
2. A fenced Don't block.
3. A line `**Do:** <what>`.
4. A fenced Do block.

Keep the `RT-n` on the Don't line.

1. `### Don't read params synchronously (RT-11)`

   ```tsx
   export default function Page({ params }: { params: { slug: string } }) {
     return <h1>{params.slug}</h1> // Next.js 16: params is a Promise; sync access was removed
   }
   ```

   `**Do:** await the Promise.`

   ```tsx
   export default async function Page(props: PageProps<'/blog/[slug]'>) {
     const { slug } = await props.params
     return <h1>{slug}</h1>
   }
   ```

2. `### Don't ship a parallel-route slot without default.tsx (RT-19)`

   ```text
   src/app/(dashboard)/dashboard/
   ├── layout.tsx
   ├── page.tsx
   └── @analytics/
       └── page.tsx        # no default.tsx: next build fails in Next.js 16
   ```

   `**Do:** give the slot its fallback.`

   ```text
   src/app/(dashboard)/dashboard/
   ├── layout.tsx
   ├── page.tsx
   └── @analytics/
       ├── page.tsx
       └── default.tsx     # return null, or call notFound() to keep the pre-16 404
   ```

3. `### Don't call redirect() inside try (RT-31)`

   ```ts
   // src/lib/actions/projects.ts
   'use server'
   import { redirect } from 'next/navigation'
   import { saveProject } from '@/features/projects/services/projects'

   export async function createProject(formData: FormData) {
     try {
       const id = await saveProject(formData)
       redirect(`/dashboard/projects/${id}`) // throws NEXT_REDIRECT, which the catch swallows
     } catch {
       return { error: 'Could not create the project.' }
     }
   }
   ```

   `**Do:** redirect after the try/catch.`

   ```ts
   // src/lib/actions/projects.ts
   'use server'
   import { redirect } from 'next/navigation'
   import { saveProject } from '@/features/projects/services/projects'

   export async function createProject(formData: FormData) {
     let id: string
     try {
       id = await saveProject(formData)
     } catch {
       return { error: 'Could not create the project.' }
     }
     redirect(`/dashboard/projects/${id}`)
   }
   ```

   Input validation of `formData` belongs to
   [data-fetching-and-mutations.md](data-fetching-and-mutations.md). One prose line says so.

4. `### Don't call useSearchParams outside a Suspense boundary (RT-27)`

   ```tsx
   // src/app/products/page.tsx (prerendered)
   import { SortSelect } from '@/features/catalog/components/sort-select'

   export default function Page() {
     return <SortSelect /> // next build: "Missing Suspense boundary with useSearchParams"
   }
   ```

   `**Do:** wrap the caller in <Suspense>.`

   ```tsx
   import { Suspense } from 'react'
   import { SortSelect } from '@/features/catalog/components/sort-select'

   export default function Page() {
     return (
       <Suspense fallback={<p>Loading filters…</p>}>
         <SortSelect />
       </Suspense>
     )
   }
   ```

5. `### Don't hand-write head tags in the root layout (RT-4, RT-37)`

   ```tsx
   export default function RootLayout({ children }: { children: React.ReactNode }) {
     return (
       <html lang="en">
         <head>
           <title>Acme</title>
           <meta name="theme-color" content="black" />
         </head>
         <body>{children}</body>
       </html>
     )
   }
   ```

   `**Do:** export metadata and viewport.`

   ```tsx
   import type { Metadata, Viewport } from 'next'

   export const metadata: Metadata = { title: { template: '%s | Acme', default: 'Acme' } }
   export const viewport: Viewport = { themeColor: 'black' }

   export default function RootLayout({ children }: { children: React.ReactNode }) {
     return (
       <html lang="en">
         <body>{children}</body>
       </html>
     )
   }
   ```

6. `### Don't push an unvalidated URL (RT-22)`

   ```tsx
   'use client'
   import { useRouter, useSearchParams } from 'next/navigation'

   export function ContinueButton() {
     const router = useRouter()
     const target = useSearchParams().get('next') ?? '/'
     return <button type="button" onClick={() => router.push(target)}>Continue</button> // ?next=javascript:… runs script
   }
   ```

   `**Do:** allow only same-origin paths (convention: the docs require sanitizing, and this check is ours).`

   ```tsx
   'use client'
   import { useRouter, useSearchParams } from 'next/navigation'

   function toSafePath(value: string | null): string {
     if (value === null || !value.startsWith('/') || value.startsWith('//') || value.startsWith('/\\')) {
       return '/'
     }
     return value
   }

   export function ContinueButton() {
     const router = useRouter()
     const target = toSafePath(useSearchParams().get('next'))
     return <button type="button" onClick={() => router.push(target)}>Continue</button>
   }
   ```

   The guard rejects protocol-relative `//host` and `/\host` paths as well as `javascript:`.

In the topic file these blocks are **unindented** top-level fences. They are shown indented
here only because they sit inside a list.

## 11. Version notes (verbatim content for `## Version notes`)

Intro line: "Changes to routing, navigation and metadata in **Next.js 16**, as confirmed by
the upgrade guide and release posts."

- **Async `params`/`searchParams` only.** Next.js 15's temporary synchronous access is gone.
  `params` in `layout`, `page`, `route`, `default`, `opengraph-image`, `twitter-image`, `icon`
  and `apple-icon`, and `searchParams` in `page`, must be awaited (RT-11)
  ([version 16 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-16)).
  `generateMetadata` `params`/`searchParams` became Promises in 15
  ([version 15 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-15)).
- **Metadata image functions.** The image function receives `params` and `id` as Promises,
  and `generateImageMetadata` keeps synchronous `params` (RT-40)
  ([version 16 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-16)).
- **Sitemap `id`.** `sitemap` receives the `generateSitemaps` `id` as `Promise<string>` (RT-39)
  ([version 16 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-16)).
- **Parallel routes need `default`.** Every slot needs an explicit `default` file, and the
  build fails without one (RT-19)
  ([version 16 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-16)).
- **Prefetch cache rewrite.** Prefetching now uses layout deduplication and incremental
  prefetching, with no code changes: more requests, each much smaller (RT-23)
  ([Next.js 16](https://nextjs.org/blog/next-16)).
- **Scroll behavior.** Next.js no longer overrides `scroll-behavior: smooth`. Opt back in
  with `data-scroll-behavior="smooth"` (RT-30)
  ([version 16 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-16)).
- **`middleware` renamed `proxy`.** The old filename is deprecated; see
  [proxy-auth-and-security.md](proxy-auth-and-security.md)
  ([version 16 upgrade](https://nextjs.org/docs/app/guides/upgrading/version-16)).
- **Root params.** `unstable_rootParams` was removed in 16.0, and `next/root-params` shipped
  in 16.3 (RT-14) ([next/root-params](https://nextjs.org/docs/app/api-reference/functions/next-root-params)).
- **Segment config under Cache Components.** `dynamicParams` (with `dynamic`, `revalidate`
  and `fetchCache`) is unavailable when `cacheComponents` is on (RT-17)
  ([route segment config](https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config)).
- **16.2.**
  - `<Link transitionTypes>`.
  - Multiple icon formats (`icon.png` + `icon.svg`) emitted as separate `<link>` tags.
  - Faster `ImageResponse`, with Geist Sans as the default font.
  - Experimental `prefetchInlining`.

  ([Next.js 16.2](https://nextjs.org/blog/next-16-2), [Link](https://nextjs.org/docs/app/api-reference/components/link)).
- **16.3.**
  - Small prefetches are bundled automatically.
  - Opt-in Partial Prefetching (`partialPrefetching`, which needs `cacheComponents`) and the
    per-segment `prefetch` export (RT-25).
  - `robots` rules accept `other` for non-standard directives.

  ([Next.js 16.3](https://nextjs.org/blog/next-16-3),
  [partialPrefetching](https://nextjs.org/docs/app/api-reference/config/next-config-js/partialPrefetching),
  [robots](https://nextjs.org/docs/app/api-reference/file-conventions/metadata/robots)).

Closing note (one line): "Some reference pages, such as page.js, layout.js, default.js and
dynamic routes, still say synchronous `params` works 'in Next.js 15'. For 16, the upgrade
guide governs."

### 11.1 Review checklist (verbatim; every item names its rule)

- [ ] RT-1, RT-2: a new project keeps `src/app/` routing-only, with features in
  `src/features/`, shared code in `src/shared/` and `proxy.ts` in `src/`.
- [ ] RT-3: no segment has both `page.tsx` and `route.ts`.
- [ ] RT-4: the root layout has `<html>`/`<body>` and no hand-written `<head>` tags.
- [ ] RT-5: no two route groups resolve to the same URL.
- [ ] RT-11: every `params`/`searchParams` access is awaited, or unwrapped with `use()` in a
  Client Component.
- [ ] RT-13: `params` are validated, and invalid values call `notFound()`.
- [ ] RT-15, RT-16, RT-17: each prerenderable dynamic segment exports `generateStaticParams`
  returning an array (≥1 entry under Cache Components), with no `dynamicParams` under Cache
  Components.
- [ ] RT-19: every `@slot` has a `default.tsx`.
- [ ] RT-20: each slot authorizes its own data.
- [ ] RT-22: navigation uses `<Link>`, and `router.push`/`replace` never receive unsanitized
  input.
- [ ] RT-24: no side effects run in layout or page render.
- [ ] RT-27: `useSearchParams` callers are wrapped in `<Suspense>` on prerendered routes.
- [ ] RT-31: `redirect()`/`permanentRedirect()` run outside `try`/`catch` and never in event
  handlers, and 308 is used only for canonical-URL changes.
- [ ] RT-33: `notFound()` is never swallowed by `try`/`catch`, and the real-404 check runs
  before streaming when the status matters.
- [ ] RT-34, RT-35: no segment exports both `metadata` and `generateMetadata`, `metadataBase`
  is set in the root layout, and every `title.template` has a `title.default`.
- [ ] RT-37: viewport fields live in `viewport`/`generateViewport`, not `metadata`.
- [ ] RT-39, RT-40: `sitemap.ts`/`robots.ts` are typed with `MetadataRoute`, and OG images
  export `alt`/`size`/`contentType` and await `params`.

### 11.2 Not confirmed by the docs (verbatim; nothing here is a rule)

1. **Missing slot `default`: 404 or build failure?** The parallel-routes page still says a
   missing `default.js` renders a 404. The default.js page says named slots error, and the
   v16 guide says builds fail. RT-19 follows the v16 guide. Checked:
   - https://nextjs.org/docs/app/api-reference/file-conventions/parallel-routes
   - https://nextjs.org/docs/app/api-reference/file-conventions/default
   - https://nextjs.org/docs/app/guides/upgrading/version-16
2. **Synchronous `params` in `generateViewport`.** The v16 removal list doesn't name
   `generateMetadata`/`generateViewport`. The generateMetadata page awaits `params`, so RT-11
   covers it. The generateViewport page shows `generateViewport({ params })` with no await,
   and says only to type `params` with `PageProps`/`LayoutProps`. Checked:
   - https://nextjs.org/docs/app/api-reference/functions/generate-viewport
   - https://nextjs.org/docs/app/api-reference/functions/generate-metadata
   - https://nextjs.org/docs/app/guides/upgrading/version-16
3. **Route groups in route literals.** No page shows a route-group folder inside a
   `PageProps<'…'>`/`LayoutProps<'…'>` literal, so the examples avoid the helpers on grouped
   routes. Checked:
   - https://nextjs.org/docs/app/api-reference/file-conventions/page
   - https://nextjs.org/docs/app/api-reference/file-conventions/layout
   - https://nextjs.org/docs/app/getting-started/layouts-and-pages
   - https://nextjs.org/docs/app/api-reference/config/typescript
4. **Route groups and interception.** The interception matchers are documented to ignore
   `@slot` folders. Whether `(group)` folders count isn't stated, so keep an interceptor and
   its target inside the same group. Checked:
   - https://nextjs.org/docs/app/api-reference/file-conventions/intercepting-routes
5. **The `next.config` redirect limit on Vercel.** nextjs.org says 1,024 and vercel.com says
   2,048. No number is stated as a rule. Checked:
   - https://nextjs.org/docs/app/guides/redirecting
   - https://vercel.com/docs/routing/redirects/configuration-redirects
6. **The sitemap reference example.** It multiplies the awaited `id`, which is a string, by
   a number. The v16 guide converts with `Number(...)`, and the pattern here follows the
   guide. Checked:
   - https://nextjs.org/docs/app/api-reference/file-conventions/metadata/sitemap
   - https://nextjs.org/docs/app/api-reference/functions/generate-sitemaps
7. **The `generateImageMetadata` `id` type.** The v16 guide says `Promise<string>`, and the
   reference page says it resolves to `string` or `number`. Checked:
   - https://nextjs.org/docs/app/guides/upgrading/version-16
   - https://nextjs.org/docs/app/api-reference/functions/generate-image-metadata
8. **The `prefetch` segment export's release.** Its history row reads `v16.x.x`, with no
   exact release stated. The 16.3 post describes Partial Prefetching. Checked:
   - https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/prefetch
   - https://nextjs.org/blog/next-16-3

Format each checked URL as a bare `https://` URL or a Markdown link. Every one is already in
§12.

## 12. Sources (verbatim, fragment-free, 58 bullets; must equal the evidence file)

```text
https://nextjs.org/docs/app/getting-started/project-structure
https://nextjs.org/docs/app/getting-started/layouts-and-pages
https://nextjs.org/docs/app/getting-started/linking-and-navigating
https://nextjs.org/docs/app/getting-started/metadata-and-og-images
https://nextjs.org/docs/app/getting-started/route-handlers
https://nextjs.org/docs/app/api-reference/file-conventions/src-folder
https://nextjs.org/docs/app/api-reference/file-conventions/route-groups
https://nextjs.org/docs/app/api-reference/file-conventions/layout
https://nextjs.org/docs/app/api-reference/file-conventions/page
https://nextjs.org/docs/app/api-reference/file-conventions/template
https://nextjs.org/docs/app/api-reference/file-conventions/loading
https://nextjs.org/docs/app/api-reference/file-conventions/not-found
https://nextjs.org/docs/app/api-reference/file-conventions/error
https://nextjs.org/docs/app/api-reference/file-conventions/forbidden
https://nextjs.org/docs/app/api-reference/file-conventions/unauthorized
https://nextjs.org/docs/app/api-reference/file-conventions/default
https://nextjs.org/docs/app/api-reference/file-conventions/dynamic-routes
https://nextjs.org/docs/app/api-reference/file-conventions/parallel-routes
https://nextjs.org/docs/app/api-reference/file-conventions/intercepting-routes
https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config
https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/dynamicParams
https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/prefetch
https://nextjs.org/docs/app/api-reference/functions/generate-static-params
https://nextjs.org/docs/app/api-reference/functions/next-root-params
https://nextjs.org/docs/app/api-reference/components/link
https://nextjs.org/docs/app/api-reference/functions/use-router
https://nextjs.org/docs/app/api-reference/functions/use-pathname
https://nextjs.org/docs/app/api-reference/functions/use-search-params
https://nextjs.org/docs/app/api-reference/functions/use-params
https://nextjs.org/docs/app/api-reference/functions/use-link-status
https://nextjs.org/docs/app/api-reference/functions/redirect
https://nextjs.org/docs/app/api-reference/functions/permanentRedirect
https://nextjs.org/docs/app/api-reference/functions/not-found
https://nextjs.org/docs/app/guides/redirecting
https://nextjs.org/docs/app/guides/prefetching
https://nextjs.org/docs/app/guides/adopting-partial-prefetching
https://nextjs.org/docs/app/api-reference/config/next-config-js/partialPrefetching
https://nextjs.org/docs/app/api-reference/functions/generate-metadata
https://nextjs.org/docs/app/api-reference/functions/generate-viewport
https://nextjs.org/docs/app/api-reference/file-conventions/metadata/sitemap
https://nextjs.org/docs/app/api-reference/functions/generate-sitemaps
https://nextjs.org/docs/app/api-reference/file-conventions/metadata/robots
https://nextjs.org/docs/app/api-reference/file-conventions/metadata/opengraph-image
https://nextjs.org/docs/app/api-reference/file-conventions/metadata/app-icons
https://nextjs.org/docs/app/api-reference/functions/image-response
https://nextjs.org/docs/app/api-reference/functions/generate-image-metadata
https://nextjs.org/docs/app/api-reference/config/typescript
https://nextjs.org/docs/app/guides/upgrading/version-16
https://nextjs.org/docs/app/guides/upgrading/version-15
https://nextjs.org/blog/next-16
https://nextjs.org/blog/next-16-2
https://nextjs.org/blog/next-16-3
https://vercel.com/docs/og-image-generation
https://vercel.com/docs/routing/redirects
https://vercel.com/docs/routing/redirects/configuration-redirects
https://react.dev/reference/react/use
https://react.dev/reference/react/Suspense
https://react.dev/reference/react/cache
```

In the topic file, each line becomes a `- <url>` bullet. Every URL used in the topic file's
prose must be in this list. Every URL in this list must appear somewhere in the file's prose:
in a rule, a pattern note, the version notes or not-confirmed.

## 13. Not confirmed by the docs (planner's research log)

These facts were looked for and **not** found, so they are kept out of the rules. Items 1–8
are carried into the topic file as §11.2.

- **The error-boundary APIs from 16.2/16.3.** These are `unstable_catchError`, `catchError`,
  `unstable_retry` and the `retry` prop in `global-error`. They exist, but error handling is
  owned by `testing-and-observability.md`, so they aren't stated here.
- **Instant Navigations, `instant` export, Navigation Inspector, `@next/playwright`
  `instant()`, `experimental.useOffline`.** These are confirmed in the 16.3 post, but they
  belong to the rendering, caching and testing topics. Only Partial Prefetching (a `<Link>`
  concern) is stated here.
- **`router.bfcacheId`.** It is documented on the useRouter page with no version row. It was
  left out as niche, which is a scope decision, not a grounding gap.

## 14. Assumptions (planner)

1. The as-of line in the topic file is copied byte-for-byte from `R/nextjs.md`. The planner
   expects `> As of Next.js 16.3.8, verified 2026-10-04.`, read live from llms.txt and npm.
   If the skeleton recorded a different version, the skeleton wins, and REVIEW① checks that
   the version notes still hold.
2. Prose URLs never carry `#fragments`. That keeps the prose ⊆ Sources check a plain string
   match.
3. The Anti-patterns item syntax, rule-list grouping and `section()` heading argument follow
   the merged skeleton contract. §3 and §10 give the defaults. Only the test's marker regexes
   may be widened to match the contract.
4. The examples use `@/…` imports rooted at `src/` (RT-2), and Jonathan's
   `features/<f>/services`, `features/<f>/components`, `shared/components` and `lib/actions`
   folders. Data access uses `fetch` plus a local `parsePost`, not an ORM call, so no snippet
   uses an API the cited pages don't show.
5. `typedRoutes`, `next typegen` and `PageProps` setup are stated only as far as routing
   needs them, and linked to `typescript.md`, which owns them.
6. `evidence/sources-verified.md` was written by the planner, because the planner did the
   live fetch. The coder keeps it equal to Sources, and adds a URL only after fetching it live
   and recording that in validation.md.
7. The coder works on `wip/nextjs-typescript-best-practices-reference/app-router-routing-and-metadata`
   in its own worktree, and the merge into the run branch is `--no-ff`. The orchestrator owns
   that step.
