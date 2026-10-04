# Plan: performance-and-vercel-platform

Story: [story.md](story.md). Owns `R/nextjs/performance-and-vercel.md` (prefix `PERF`) and
`Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_performance_and_vercel.py`.
`R` = `Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references`.
Skills loaded: none routed (stack.md: Markdown skill content; `nextjs-fullstack-standards` not loadable).
Research: every page below was fetched live on 2026-10-04 (WebFetch, or `curl -H 'Accept: text/markdown'`
plus grep to re-check quotes). Current stable Next.js: **16.3.8**. That is the `version:` front matter on
every nextjs.org docs page fetched, and nextjs.org/blog lists 16.3.8 as Active LTS. Next.js 16.3 shipped
2026-08-03. The latest major is **16**.

## 1. Approach

1. TDD. Write the topic test first and run it red against the stub (`is_stub` is true). Then replace the
   stub with the full topic file and run it green, together with the merged generic contract tests in
   `test_nextjs_reference.py`.
2. The topic file states only the rules in the **Verified rule sheet** (section 7). Each rule keeps its
   id, link and meaning. The coder copies the wording and snippets, and invents no API, number or claim.
   Anything in section 8 goes only under `## Not confirmed by the docs`.
3. Grounding comes first (story Assumptions). Wherever nextjs.org and vercel.com disagree, or a page is
   silent, the file says so and states no rule. Four conflicts were found and logged in section 8:
   - Pro region count;
   - the remote image TTL;
   - `optimizePackageImports` status;
   - Edge "deprecated" versus "no longer supported".
4. bmn hard line: the file documents config and never a deploy command (`references/deploy-guards.md`).
   A test enforces it. Platform changes that need a dashboard toggle or a deployment are written as
   `deploy_pending` items for Jonathan.
5. Skill guidance applied: none routed. The repo conventions applied are:
   - the skeleton story's Authoring contract (section order, rule format, citations, floors);
   - stack.md gates;
   - the global testing rule (tests first, AAA, descriptive names);
   - coding-style limits (functions under 50 lines, no mutation of module constants).

## 2. Files to create or change

| # | Path | Purpose |
| --- | --- | --- |
| 1 | `R/nextjs/performance-and-vercel.md` | Replaces the stub entirely. Sections in contract order. At most 800 lines (budget in section 6). |
| 2 | `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_performance_and_vercel.py` | New topic test. Imports `nextjs_doc_helpers` and is stdlib-only and ruff-clean. |
| 3 | `docs/sprints/bmn-nextjs-typescript-best-practices-reference/performance-and-vercel-platform/evidence/sources-verified.md` | One row per `## Sources` URL: the URL, `2026-10-04 (fetched live this run)`, the rule ids it backs, and a one-line note of what it confirms. |
| 4 | `docs/sprints/bmn-nextjs-typescript-best-practices-reference/performance-and-vercel-platform/validation.md` | Written at validation. Records the one-off check that the Sources URL set equals the evidence URL set (command in section 6) and the gate results. |

No shared file is touched: `nextjs.md`, `test_nextjs_reference.py`, `nextjs_doc_helpers.py`, the briefs,
SKILL.md and plugin.json are all left alone. A defect found in one of them is recorded under
Assumptions in `validation.md`.

## 3. Test plan (written first)

File: `Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_performance_and_vercel.py`, type unit
(pytest, offline).

Module constants:

- `import nextjs_doc_helpers as h`
- `TOPIC = h.TOPICS_DIR / "performance-and-vercel.md"`
- `TERMS`: the 22 terms from AC3.
- `UNIT_TOKENS = ("MB", " GB", "seconds", "minutes")`, matched case-sensitively.
- `PLATFORM_LINK = re.compile(r"https://(?:vercel\.com|nextjs\.org)/")`
- `DEPLOY_COMMAND = re.compile(r"\bvercel\s+(?:deploy|--prod|promote|rollback|redeploy|alias|remove|--regions|env\s+(?:add|rm))\b")`
- `DEPRECATED_IN_PATTERNS`, a tuple of compiled regexes:
  - `(?<![A-Za-z])priority(?![A-Za-z])`
  - `runtime\s*=\s*['"]edge['"]`
  - `preferredRegion`
  - `\bdomains\s*:`
  - `next/legacy/image`
  - `experimental\s*:\s*\{\s*turbopack`

Local helpers live in the test file, not in the shared helpers:

- `_prose_lines(text)` drops fenced blocks.
- `_unlinked_unit_lines(text)` groups prose lines into list items and returns the lines that carry a
  unit token but whose line and enclosing list item have no `PLATFORM_LINK`.
  - An item starts at `^\s*(?:[-*]|\d+\.)\s` and runs until the next item start, a blank line, a
    heading or a table row.
  - Any other line stands alone.

Each helper stays under 50 lines.

| AC | Test name | What it asserts |
| --- | --- | --- |
| 1 | the generic tests in `test_nextjs_reference.py` (owned by the skeleton) | They run on this file with no skip. Checked in validation by `-rs` output showing no skip for `performance-and-vercel.md`. |
| 2 | `test_performance_topic_is_not_a_stub` | `h.is_stub(text)` is False. |
| 2 | `test_performance_topic_has_at_least_15_perf_rules` | `len(h.rule_items(text)) >= 15` and every id starts with `PERF-`. |
| 3 | `test_performance_topic_names_every_required_concept` | `h.missing_terms(text, TERMS) == []`. |
| 4 | `test_performance_topic_has_required_typescript_example`, parametrized over 5 ids | `h.has_block_with(text, *needles)` for each id: `responsive-image` (`next/image`, `sizes`); `self-hosted-font` (`next/font`); `remote-allow-list` (`NextConfig`, `remotePatterns`); `third-party-script` (`next/script`, `strategy`); `route-duration` (`maxDuration`). |
| 5 | `test_every_vercel_number_line_carries_a_platform_link` | `_unlinked_unit_lines(text) == []`. |
| 5 | `test_unit_line_check_flags_a_number_without_a_link` | Inline sample `"- Max 4.5 MB per body\n"` gives 1 line. |
| 5 | `test_unit_line_check_accepts_a_link_elsewhere_in_the_list_item` | Inline sample: an item whose second line holds the unit and whose first line holds a vercel.com link gives `[]`. Code-fenced numbers are ignored. |
| 6 | `test_runtime_choice_rule_names_edge_with_a_vercel_link` | `rules = h.section(text, "Rules")`. Asserts `"Edge" in rules` and `"https://vercel.com/" in rules`. |
| 7 | `test_version_notes_name_the_major_and_link_nextjs` | `major = h.as_of_version(text).split(".")[0]`. The section is non-empty, contains `f"Next.js {major}"` and contains `https://nextjs.org/`. |
| 8 | `test_every_checklist_item_names_a_perf_rule` | Every line containing `- [ ]` contains `PERF-`, and at least one such line exists. |
| 8 | `test_checklist_rule_ids_exist_in_rules` | Every `PERF-\d+` in `## Review checklist` is an id returned by `h.rule_items`. |
| 8 | `test_anti_patterns_pair_each_dont_with_a_do` | The Anti-patterns section is split at lines starting with `**Don't**`. There are at least 3 chunks, and each has a line starting with `**Do**` and at least 2 fenced blocks. |
| 3 (drift guard) | `test_patterns_code_uses_no_deprecated_api` | No `ts`/`tsx` block in `h.section(text, "Patterns")` matches `DEPRECATED_IN_PATTERNS`. The Don't blocks in Anti-patterns may show them. |
| bmn hard line | `test_topic_never_instructs_a_vercel_deploy` | `DEPLOY_COMMAND.search(text) is None` over the whole file. |

AC9 and AC10 have no permanent test. AC9 is the evidence file plus the one-off check in `validation.md`.
AC10 is the gates and the scope diff in section 6.

Count: 14 test functions, which is 18 collected cases with the parametrization. No browser criteria and
no Playwright: the stack has `ui: false`.

Red step: run the topic test while the file is still the stub. Expected failures are not-a-stub, rules,
terms and examples. Green step: run it after writing the file.

## 4. Data

None. There are no models, migrations or RLS (`supabase: false`).

## 5. Config, env vars, deploy_pending

None. The story ships Markdown and a pytest file only. The vars the topic file names (`CRON_SECRET` and
others) are documentation, not repo config. **deploy_pending: []**

## 6. Risks and gates

Risks and mitigations:

1. **Contract drift.** The skeleton plan was written in parallel. Before writing, the coder reads the
   merged `R/nextjs.md` (`## Authoring contract`), `test_nextjs_reference.py` and `nextjs_doc_helpers.py`.
   Where they differ from this plan, the merged contract wins: the Don't-item format, `section()`
   heading handling, how fragments in URLs are compared, and the as-of line text. The coder logs the
   difference in `validation.md`.
2. **800-line cap.** The line budget:

   | Part | Lines |
   | --- | --- |
   | H1 + as-of | 3 |
   | Scope | ≤12 |
   | Rules | 43 single-line items, ≤50 |
   | Patterns | ≤230 |
   | Anti-patterns | 6 pairs, ≤150 |
   | Version notes | ≤20 |
   | Review checklist | ≤22 |
   | Not confirmed | ≤22 |
   | Sources | ≤56 |

   Target about 600 lines. Check with `wc -l`.
3. **Unit-token test.** Every prose line with `MB`, ` GB`, `seconds` or `minutes` must carry its own
   vercel.com or nextjs.org link, or sit in a list item that does. Rules are single physical lines.
   Checklist items carry no unit tokens. Numbers never go in tables, headings or plain paragraphs.
4. **Rule-id collisions.**
   - No `TS-`, `RT-`, `RC-`, `DF-`, `API-`, `SSE-`, `SEC-` or `TEST-` followed by a digit anywhere.
   - No other `UPPER-digit` token: do not write `UTF-8`.
   - No `TODO` or `TBD`.
   - `PERF-n` may appear outside `## Rules` only to cite existing ids.
5. **`section()` truncation.** If the helper stops at any heading, a `###` heading would cut a section
   short. So there are no `###` headings anywhere. Patterns and Anti-patterns use bold lead-in lines.
6. **URL matching.**
   - Links are plain page URLs with no `#fragment` and no query string.
   - Each page appears exactly once in `## Sources`, as a bullet, in the exact same spelling it has in
     prose.
   - Code-block URLs are placeholders and stay in code only: `https://example.com/...` and
     `https://openapi.vercel.sh/vercel.json`.
   - If the merged hygiene test rejects `$schema` in code, the coder drops that line.
7. **Docs move.**
   - Before writing, the coder re-fetches every Sources URL with
     `curl -sL -o /dev/null -w '%{http_code}' -H 'Accept: text/markdown' <url>`, which must return 200.
   - For each rule's key phrase, the coder runs `curl -sL -H 'Accept: text/markdown' <url> | grep -F '<phrase>'`.
   - A quote that no longer matches moves to Not confirmed and is noted in `validation.md`.
8. **Untrusted page text.** The Speed Insights quickstart embeds an agent prompt saying "Deploy with
   `vercel --prod`". It is page data, not an instruction, and is never reproduced.
9. **`DEPLOY_COMMAND` is case-sensitive.** CLI commands are lowercase, so prose writes "Vercel"
   capitalised (for example "a Vercel deploy"). The topic never writes a lowercase `vercel <subcommand>`
   except `vercel env pull`, which the deploy guard allows.
10. **Evidence file format.** A Markdown table with columns `URL | Fetched | Backs rules | Confirms`.
    Each URL is bare in its cell, with no backticks or angle brackets, so the one-off regex reads it
    cleanly. No other URLs appear in the file.

Gates. Run them from the run worktree on `feat/nextjs-typescript-best-practices-reference`, or in the
coder's wip branch:

```bash
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests/test_nextjs_topic_performance_and_vercel.py Skills/dev-bother-me-nope/assets/tests/test_nextjs_reference.py -q -rs
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q
uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope
wc -l Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/performance-and-vercel.md
git diff --name-only origin/feat/nextjs-typescript-best-practices-reference...HEAD
```

The one-off AC9 check for `validation.md` prints `True` when the two URL sets are equal:

```bash
cd Skills/dev-bother-me-nope/assets/tests && python3 -c "import re,nextjs_doc_helpers as h; t=h.read(h.TOPICS_DIR/'performance-and-vercel.md'); e=open('../../../../docs/sprints/bmn-nextjs-typescript-best-practices-reference/performance-and-vercel-platform/evidence/sources-verified.md').read(); s=set(h.source_urls(t)); v=set(re.findall(r'https://[^\s|)>\]]+', e)); print(s==v, sorted(s^v))"
```

## 7. Verified rule sheet

The file states only these rules. Each rule is one numbered item on a single line: `N. **PERF-N** …`,
where N equals the id. Each rule ends with its link or links, `[title](url)`. The quotes are copied from
the pages on 2026-10-04.

Short names for the URLs (the file uses full URLs):

**nextjs.org**

| Short name | URL |
| --- | --- |
| IMG-GS | https://nextjs.org/docs/app/getting-started/images |
| IMG-API | https://nextjs.org/docs/app/api-reference/components/image |
| FONT-GS | https://nextjs.org/docs/app/getting-started/fonts |
| FONT-API | https://nextjs.org/docs/app/api-reference/components/font |
| SCR-G | https://nextjs.org/docs/app/guides/scripts |
| SCR-API | https://nextjs.org/docs/app/api-reference/components/script |
| TP | https://nextjs.org/docs/app/guides/third-party-libraries |
| LAZY | https://nextjs.org/docs/app/guides/lazy-loading |
| BUNDLE | https://nextjs.org/docs/app/guides/package-bundling |
| OPI | https://nextjs.org/docs/app/api-reference/config/next-config-js/optimizePackageImports |
| SEP | https://nextjs.org/docs/app/api-reference/config/next-config-js/serverExternalPackages |
| SCC | https://nextjs.org/docs/app/getting-started/server-and-client-components |
| TURBO | https://nextjs.org/docs/app/api-reference/turbopack |
| TFSC | https://nextjs.org/docs/app/api-reference/config/next-config-js/turbopackFileSystemCache |
| CLI | https://nextjs.org/docs/app/api-reference/cli/next |
| RCOMP | https://nextjs.org/docs/app/api-reference/config/next-config-js/reactCompiler |
| RWV | https://nextjs.org/docs/app/api-reference/functions/use-report-web-vitals |
| PCL | https://nextjs.org/docs/app/guides/production-checklist |
| RT-RUN | https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/runtime |
| EDGE-MSG | https://nextjs.org/docs/messages/edge-runtime-deprecated |
| PREG | https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/preferredRegion |
| MAXD | https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/maxDuration |
| SACFG | https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions |
| AFTER | https://nextjs.org/docs/app/api-reference/functions/after |
| UP16 | https://nextjs.org/docs/app/guides/upgrading/version-16 |
| BLOG16 | https://nextjs.org/blog/next-16 |
| BLOG163 | https://nextjs.org/blog/next-16-3 |

Note: the RT-RUN short name contains `RT-` but no digit follows, so it cannot collide with rule ids.
Short names are plan-only and never appear in the file.

**vercel.com**

| Short name | URL |
| --- | --- |
| V-RUNTIMES | https://vercel.com/docs/functions/runtimes |
| V-EDGE | https://vercel.com/docs/functions/runtimes/edge |
| V-FLUID | https://vercel.com/docs/fluid-compute |
| V-LIM | https://vercel.com/docs/functions/limitations |
| V-DUR | https://vercel.com/docs/functions/configuring-functions/duration |
| V-MEM | https://vercel.com/docs/functions/configuring-functions/memory |
| V-REG | https://vercel.com/docs/functions/configuring-functions/region |
| V-CDN | https://vercel.com/docs/caching/cdn-cache |
| V-DC | https://vercel.com/docs/caching/runtime-cache/data-cache |
| V-ISR | https://vercel.com/docs/incremental-static-regeneration |
| V-IMG | https://vercel.com/docs/image-optimization |
| V-IMGP | https://vercel.com/docs/image-optimization/limits-and-pricing |
| V-CRON | https://vercel.com/docs/cron-jobs |
| V-CRONM | https://vercel.com/docs/cron-jobs/manage-cron-jobs |
| V-LIMITS | https://vercel.com/docs/limits |
| V-ENV | https://vercel.com/docs/environment-variables |
| V-ENVS | https://vercel.com/docs/deployments/environments |
| V-SKEW | https://vercel.com/docs/skew-protection |
| V-PC | https://vercel.com/docs/project-configuration |
| V-VTS | https://vercel.com/docs/project-configuration/vercel-ts |
| V-SI | https://vercel.com/docs/speed-insights/quickstart |
| V-WA | https://vercel.com/docs/analytics/quickstart |
| V-KB-BODY | https://vercel.com/kb/guide/how-to-bypass-vercel-body-size-limit-serverless-functions |

### Images

**PERF-1. Render raster content images with `Image` from `next/image`.**
- Source: IMG-GS.
- The page says `<Image>` provides size optimization (WebP), visual stability (it prevents layout
  shift), lazy loading on viewport entry, and on-demand resizing of remote images.
- The production checklist (PCL) says the same: "Optimize images by using the Image Component".

**PERF-2. Give every `Image` its intrinsic size.**
- Use a static import for local files: width, height and `blurDataURL` are then automatic.
- Use `width` and `height` for remote URLs.
- Use `fill` only when the size is unknown, and give the parent `position: "relative"`, `"fixed"` or
  `"absolute"`.
- Sources: IMG-GS, IMG-API.
- IMG-API, on `width`/`height`: "You **must** set both `width` and `height` properties unless: The image
  is statically imported. The image has the `fill` property". Also: "If the height and width are
  unknown, we recommend using the `fill` property".
- On `fill`: "The parent element **must** assign `position: "relative"`, `"fixed"`, `"absolute"`."

**PERF-3. Set `sizes` on every `Image` that uses `fill` or is made responsive with CSS.**
- Source: IMG-API.
- The page says `sizes` "should be used when: The image is using the fill prop; CSS is used to make the
  image responsive".
- "If `sizes` is missing, the browser assumes the image will be as wide as the viewport (`100vw`). This
  can cause unnecessarily large images to be downloaded."
- "Without `sizes`: Next.js generates a limited `srcset` (e.g. 1x, 2x) … With `sizes`: … a full
  `srcset`".

**PERF-4. Load the one above-the-fold (LCP) image with `loading="eager"` or `fetchPriority="high"`.**
- Use `preload` only when exactly one image can be the LCP element and it must be discovered in
  `<head>`.
- Never combine `preload` with `loading` or `fetchPriority`.
- Never write `priority`, which Next.js 16 deprecated in favour of `preload`.
- Source: IMG-API.
- "In most cases, you should use `loading="eager"` or `fetchPriority="high"` instead of `preload`."
- On when not to use `preload`: "multiple images that could be considered the LCP element depending on
  the viewport; When the `loading` property is used; When the `fetchPriority` property is used."
- "Starting with Next.js 16, the `priority` property has been deprecated in favor of the `preload`
  property."
- `loading` defaults to `lazy`.

**PERF-5. Allow-list remote images with the narrowest `images.remotePatterns` entry.**
- Set `protocol`, `hostname`, `pathname` and `search: ''`.
- Allow local images that use query strings with `images.localPatterns` (`pathname`, `search`).
- Never use `images.domains`.
- Sources: IMG-API, UP16.
- IMG-API: "When omitting `protocol`, `port`, `pathname`, or `search` then the wildcard `**` is implied.
  This is not recommended because it may allow malicious actors to optimize urls you did not intend."
- A non-matching URL gets `400` Bad Request.
- `remotePatterns` also accepts `new URL('https://example.com/account123/**')` (v15.3.0).
- `domains` was "Deprecated since Next.js 14 in favor of strict `remotePatterns`".
- UP16: "Local image sources with query strings now require `images.localPatterns.search`
  configuration".

**PERF-6. Keep `images.qualities` an explicit allow-list and `images.formats` on the WebP default.**
- Keep `qualities` at the default `[75]`.
- Add AVIF only when measured.
- Prefer static imports to raising `minimumCacheTTL`.
- Source: IMG-API.
- `qualities` default `[75]`. "This field is required starting with Next.js 16". A `quality` outside the
  list "is coerced to the closest allowed entry".
- Formats:
  - "We still recommend using WebP for most use cases."
  - "AVIF generally takes 50% longer to encode but it compresses 20% smaller".
  - "When using multiple formats, Next.js will cache each format separately".
- `minimumCacheTTL` default `14400` (4 hours).
- A static image import is cached "forever with a `Cache-Control` header of `immutable`".
- "There is no mechanism to invalidate the cache at this time, so its best to keep `minimumCacheTTL`
  low."
- The rule line must carry its link, because it contains "4 hours".

**PERF-7. On Vercel, set `unoptimized` on images that gain nothing from optimization.**
- That means icons and thumbnails under 10 KB, GIFs and other animated images, SVGs, and images that
  change often.
- Sources: V-IMG, V-IMGP.
- V-IMG lists those cases and says: "we recommend using the `unoptimized` prop on the Next.js `Image`
  component."
- V-IMGP:
  - "Image transformations are billed for every cache MISS and STALE".
  - "maximum size for an transformed image is **10 MB**".
  - "maximum width and height of 8192 pixels".
  - Source formats are jpeg, png, webp and avif. "Other formats will be served as-is".
  - Hobby over its limit returns 402.

### Fonts

**PERF-8. Load every web font through `next/font`, using `next/font/google` or `next/font/local`.**
- Sources: FONT-API, FONT-GS.
- "CSS and font files are downloaded at build time and self-hosted with the rest of your static
  assets. **No requests are sent to Google by the browser.**"
- "you can optimally load web fonts with no layout shift".
- `display` defaults to `'swap'`.

**PERF-9. Prefer variable fonts.**
- Pass `weight` only for a non-variable font.
- Always pass `subsets` to Google fonts.
- Source: FONT-API.
- "We recommend using variable fonts for the best performance and flexibility. But if you can't use a
  variable font, you will need to specify a weight".
- "Failing to specify any subsets while `preload` is `true` will result in a warning."
- `preload` defaults to `true`.

**PERF-10. Call each font loader once, in a shared font-definitions module, and import the font
object where it is used.**
- Apply site-wide fonts in the root layout and route-specific fonts in that route's page or layout.
- Source: FONT-API.
- "Every time you call the `localFont` or Google font function, that font will be hosted as one
  instance in your application."
- Preloading by file type: a font used in a page is preloaded on that route; in a layout, on the routes
  it wraps; in the root layout, on all routes.
- "Use multiple fonts conservatively".

**PERF-11. Expose fonts to CSS and Tailwind through `variable`.**
- Use a `--font-*` CSS variable, put `font.variable` on `<html>`, and map it in Tailwind v4 `@theme
  inline` (or v3 `theme.extend.fontFamily`).
- Source: FONT-API (the With Tailwind CSS section).

### Third-party scripts

**PERF-12. Load third-party scripts with `Script` from `next/script` in the narrowest layout or page
that needs them.**
- Source: SCR-G.
- "We recommend only including third-party scripts in specific pages or layouts in order to minimize
  any unnecessary impact to performance."
- A layout script "will **only load once**, even if a user navigates between multiple routes in the
  same layout."

**PERF-13. Choose `strategy` deliberately.**
- `afterInteractive` is the default. Use it for tag managers and analytics.
- Use `lazyOnload` for chat support plugins and social media widgets.
- Use `beforeInteractive` only for critical scripts, such as bot detectors and cookie-consent managers,
  and only inside the root layout.
- Never use `worker` in the App Router.
- Source: SCR-API.
- `beforeInteractive` "must be placed inside a root layout"; "This strategy should only be used for
  critical scripts that need to be fetched as soon as possible."
- "The `worker` strategy is not yet stable and does not yet work with the App Router."

**PERF-14. Attach `onLoad`, `onReady` and `onError` only in Client Components (`'use client'`).**
- Never use `onLoad` or `onError` with `beforeInteractive`. Use `onReady` there instead.
- Give every inline script an `id`.
- Sources: SCR-API, SCR-G.
- "`onLoad` does not yet work with Server Components and can only be used in Client Components.
  Further, `onLoad` can't be used with `beforeInteractive`".
- "An `id` property must be assigned for inline scripts".

**PERF-15. For Google Tag Manager, Google Analytics, Google Maps embeds and YouTube embeds, consider
`@next/third-parties/google`.**
- The components are `GoogleTagManager`, `GoogleAnalytics`, `GoogleMapsEmbed` and `YouTubeEmbed`.
- Record that the docs call the library experimental.
- If GTM is already present, configure GA through it.
- Source: TP.
- "`@next/third-parties` is currently an **experimental** library under active development."
- "If Google Tag Manager is already included in your application, you can configure Google Analytics
  directly using it, rather than including Google Analytics as a separate component."

### Client bundle

**PERF-16. Put `'use client'` on the smallest interactive component, not on whole layouts or pages.**
- Source: SCC.
- "all of its imports and the components it directly renders are included in the client bundle".
- "To reduce the size of your client JavaScript bundles, add `'use client'` to specific interactive
  components instead of marking large parts of your UI as Client Components."

**PERF-17. Run data-to-UI work that needs no browser API in Server Components.**
- That means syntax highlighting, markdown parsing and chart rendering, so the library never ships to
  the client.
- Source: BUNDLE.
- It is a common cause of large client bundles: "If that work does not require browser APIs or user
  interaction, it can be run in a Server Component."
- The Shiki `codeToHtml` example.

**PERF-18. Start every server-only module with `import 'server-only'`.**
- That covers database access, secrets and heavy server libraries.
- Source: SCC.
- "if you try to import the module into a Client Component, there will be a build-time error."
- `client-only` is the mirror.
- Installing the package is optional, because Next.js handles the import internally.

**PERF-19. Lazy-load Client Components and libraries that are not needed for first paint.**
- Use `next/dynamic` (or `React.lazy` with `Suspense`) for components.
- Use `import()` inside the event handler for libraries.
- Pass `ssr: false` only inside Client Components.
- Source: LAZY.
- "Lazy loading applies to Client Components". Server Components are already code split.
- "`ssr: false` option is not supported in Server Components. You will see an error".
- "If you dynamically import a Server Component, only the Client Components that are children of the
  Server Component will be lazy-loaded".
- Named exports: `dynamic(() => import('../components/hello').then((mod) => mod.Hello))`.

**PERF-20. Measure the bundle before and after changing it.**
- Use `next experimental-analyze` with Turbopack. `--output` writes `.next/diagnostics/analyze`.
- Use `@next/bundle-analyzer` with webpack (`ANALYZE=true`).
- Judge route performance with Lighthouse or Vercel Analytics. In Next.js 16 `next build` no longer
  prints size metrics.
- Sources: BUNDLE, CLI, UP16.
- BUNDLE: "Next.js Bundle Analyzer for Turbopack (experimental) … Available in v16.1 and later" and
  "`@next/bundle-analyzer` plugin for Webpack".
- UP16: "Next.js 16 removes the `size` and `First Load JS` metrics from the `next build` output … The
  most effective way to measure actual route performance is through tools such as Chrome Lighthouse or
  Vercel Analytics".

**PERF-21. Treat `experimental.optimizePackageImports` as experimental.**
- Check the built-in list first. It includes `lucide-react`, `date-fns`, `lodash-es`, `@mui/material`,
  `@mui/icons-material`, `recharts`, `react-icons/*`, `@heroicons/react/*`, `@headlessui/react`, `antd`,
  `rxjs` and `effect`.
- Add a package only when the analyzer shows that its barrel imports are heavy.
- Sources: OPI, BUNDLE.
- OPI: "This feature is currently experimental and subject to change, it's not recommended for
  production."
- OPI: "will only load the modules you are actually using".
- BUNDLE recommends it for "Packages with many exports". This conflict is noted in section 8.

**PERF-22. Add a dependency to `serverExternalPackages` only when it uses Node.js-specific features and
is not on the built-in opt-out list.**
- The built-in list already includes `sharp`, `@prisma/client`, `prisma`, `pg`, `mongodb`, `bcrypt`,
  `shiki`, `playwright`, `puppeteer` and `@aws-sdk/client-s3`.
- Sources: SEP, BUNDLE.
- "If a dependency is using Node.js specific features, you can choose to opt-out specific dependencies
  from the Server Components bundling and use native Node.js `require`."
- Stable since v15.0.0. It was renamed from `serverComponentsExternalPackages`.

### Bundler and compiler

**PERF-23. Build and develop with the default Turbopack.**
- Do not add `--turbopack` flags.
- Configure it under the top-level `turbopack` key, never `experimental.turbopack`.
- Never add a `webpack()` config.
- Use `--webpack` only as a documented opt-out.
- Sources: UP16, TURBO.
- UP16: "Starting with Next.js 16, Turbopack is stable and used by default with `next dev` and
  `next build`".
- UP16: "If your project has a custom `webpack` configuration and you run `next build` … the build will
  **fail**".
- UP16: "The `experimental.turbopack` configuration is out of experimental."
- TURBO: "`webpack()` configs are not recognized. Use the `turbopack` config instead"; "Turbopack does
  not support webpack plugins".

**PERF-24. Restore `.next/cache` between CI builds so Turbopack's filesystem cache is reused.**
- If the CI never preserves it, set `experimental.turbopackFileSystemCacheForBuild: false`.
- Source: TFSC.
- Both options are on by default: dev since v16.1.0 and build since v16.3.0.
- "If your build environment never preserves `.next/cache`, set `turbopackFileSystemCacheForBuild:
  false`".

**PERF-25. Turn on the React Compiler only as a deliberate, measured change.**
- Set the top-level `reactCompiler: true` and install `babel-plugin-react-compiler` as a dev
  dependency.
- Expect longer compiles.
- For opt-in, use `compilationMode: 'annotation'` with `'use memo'`.
- Sources: RCOMP, UP16, BLOG163.
- UP16: "Built-in support for the React Compiler is now stable in Next.js 16 … It is not enabled by
  default"; "Expect compile times in development and during builds to be higher".
- RCOMP shows annotation mode.
- BLOG163: the Rust port is experimental, via `experimental.turbopackRustReactCompiler`.

### Core Web Vitals

**PERF-26. Report Web Vitals from one small `'use client'` component that calls `useReportWebVitals`
with a module-level (stable) callback, rendered from the root layout.**
- Source: RWV.
- "To prevent reporting duplicated data, ensure that the callback function reference does not change".
- "the most performant approach is to create a separate component that the root layout imports".
- Metrics: TTFB, FCP, LCP, FID, CLS and INP.
- Send with `navigator.sendBeacon`, falling back to `fetch(..., { keepalive: true })`.

**PERF-27. On Vercel, add `<SpeedInsights />` from `@vercel/speed-insights/next` and `<Analytics />`
from `@vercel/analytics/next` to the root layout `<body>`.**
- Web Analytics must first be enabled in the dashboard. That is Jonathan's step: record it as
  `deploy_pending`.
- Sources: V-SI, V-WA.
- The exact imports are verified.
- V-WA: "navigate to **Analytics** in the sidebar … click the **Enable** button"; routes appear "after
  your next deployment".
- V-SI shows no dashboard-enable step (section 8).

**PERF-28. Before calling performance work done, run `next build` then `next start` locally and audit
with Lighthouse in an incognito window.**
- Pair the lab result with field data.
- Source: PCL.
- "run `next build` to build your application locally … then run `next start` to measure the
  performance of your application in a production-like environment"; "Run lighthouse in incognito";
  "should be paired with looking at field data".

### Vercel Functions

**PERF-29. Run server code on the Node.js runtime.**
- Omit the `runtime` export, since `'nodejs'` is the default.
- Never export `runtime = 'edge'`.
- `proxy` always runs on Node.js. Its details are in `proxy-auth-and-security.md`.
- Sources: RT-RUN, EDGE-MSG, V-EDGE, UP16.
- RT-RUN: `'nodejs'` (default), `'edge'` (deprecated); "The Edge Runtime is deprecated. Remove the
  `runtime` export from your route files."
- V-EDGE: "We recommend migrating from edge to Node.js for improved performance and reliability";
  "Starting in Next.js 16.3, setting `runtime = 'edge'` is no longer supported. Routes and pages run on
  Node.js."
- UP16: "The `proxy` runtime is `nodejs`, and it cannot be configured."
- This rule satisfies AC6: the word `Edge` plus a vercel.com link.

**PERF-30. Assume Fluid compute and keep request-specific data out of module-level variables.**
- For an older project, opt in with `"fluid": true` in `vercel.json`.
- Source: V-FLUID.
- "As of April 23, 2025, fluid compute is enabled by default for new projects."
- "multiple invocations can share the same physical instance (a global state/process) concurrently".
- "Error isolation: Unhandled errors won't crash other concurrent requests".
- The `{"fluid": true}` snippet.

**PERF-31. Export `maxDuration` from a page, layout or `route.ts` only when the route needs more than
the platform default, and keep it within the plan maximum.**
- On Vercel with Fluid compute:
  - the default is 300 seconds on all plans;
  - Hobby's maximum is 300 seconds;
  - Pro and Enterprise allow up to 800 seconds;
  - 1800 seconds (30 minutes) is an extended beta, set per function on supported runtimes.
- A value set in code overrides `vercel.json` and the dashboard.
- Set it at page level to cover that page's Server Actions.
- Sources: MAXD, V-DUR, V-LIM, V-FLUID.
- MAXD: "set `maxDuration` at the page level to change the default timeout of all Server Actions used on
  the page."
- V-LIM: an overrun "a 504 error code (`FUNCTION_INVOCATION_TIMEOUT`) is returned".
- V-FLUID: precedence 1 is function code.

**PERF-32. Use `after()` from `next/server` for work that must not delay the response, such as logging
and analytics.**
- It still counts against the route's `maxDuration`.
- Source: AFTER.
- "schedule work to be executed after a response (or prerender) is finished".
- "`after` will run for the platform's default or configured max duration of your route".
- On Vercel it is implemented with `waitUntil`.

**PERF-33. Never put `memory` in `vercel.json`.**
- Memory and CPU are a dashboard setting (Pro and Enterprise). Record changes as `deploy_pending`:
  - Standard is 2 GB / 1 vCPU, the default;
  - Performance is 4 GB / 2 vCPUs;
  - Hobby is fixed at 2 GB / 1 vCPU.
- Source: V-MEM.
- "You cannot set your memory size using `vercel.json`. If you try to do so, you will receive a warning
  at build time."

**PERF-34. Run functions in the region of their data.**
- The default for new projects is `iad1`.
- Set the project `regions` in `vercel.json` (or the dashboard) to the database's region.
- Hobby is limited to a single region.
- Never export `preferredRegion`, which is deprecated.
- Sources: V-REG, PREG.
- V-REG: "specify the region in which your functions execute, ideally close to your data source"; the
  `{"regions": ["sfo1"]}` snippet; "If your functions communicate with external services, choosing
  regions far from those services increases latency."
- PREG: "The `preferredRegion` route segment config is deprecated. Remove the `preferredRegion` export".
- No Pro region count is stated (section 8).

**PERF-35. Keep each Vercel Function request body and response body under 4.5 MB.**
- Send large uploads from the browser straight to storage, for example Vercel Blob client uploads.
- Stream large responses.
- Server Actions also cap the request body at 1MB by default (`serverActions.bodySizeLimit`).
- Sources: V-LIM, V-KB-BODY, SACFG.
- V-LIM: "The maximum payload size for the request body or the response body of a Vercel Function is
  **4.5 MB** … 413: `FUNCTION_PAYLOAD_TOO_LARGE`".
- V-KB-BODY: "upload large files directly to a media host from your browser without needing a Vercel
  Function as a proxy"; "we recommend using streaming functions".
- SACFG: "By default, the maximum size of the request body sent to a Server Action is 1MB".
- This rule must contain the literal phrase `request body`.

**PERF-36. Keep each function under the 250 MB uncompressed bundle limit.**
- Use `outputFileTracingIncludes` in `next.config`, because `vercel.json` `includeFiles`/`excludeFiles`
  are not supported for Next.js.
- Close connections and pool them: a function has 1,024 file descriptors shared across concurrent
  executions.
- Source: V-LIM.
- "the maximum uncompressed size is **250 MB**".
- "These configurations are not supported in Next.js, instead use `outputFileTracingIncludes`".
- "a limit of **1,024 file descriptors** shared across all concurrent executions"; "Use connection
  pooling for database connections".

### Vercel caching and platform

**PERF-37. To cache a function response on Vercel's CDN, return `Cache-Control` with `s-maxage` (and
optionally `stale-while-revalidate`).**
- Use `CDN-Cache-Control` and `Vercel-CDN-Cache-Control` to set the CDN lifetime apart from the
  browser's.
- Set route headers in `next.config`, not `vercel.json`.
- Caching strategy is in `rendering-and-caching.md`.
- Source: V-CDN.
- The directives must be one of: `s-maxage=N`; `s-maxage=N, stale-while-revalidate=Z`;
  `s-maxage=N, stale-while-revalidate=Z, stale-if-error=Z`.
- "`Vercel-CDN-Cache-Control` headers are not returned to the browser or forwarded to other CDNs".
- A response is not cached when:
  - the request is not `GET` or `HEAD`, or carries an `Authorization` header;
  - the response sets `set-cookie`;
  - the response is `private`, `no-cache` or `no-store`;
  - the response has `Vary: *` or `Vary: Cookie`;
  - the response is over 10MB (20MB streaming).
- "If you're building your app with Next.js, you should use `next.config.js` rather than
  `vercel.json`".
- Max cache time is 1 year.

**PERF-38. Know where each Vercel cache lives.**
- The ISR cache is durable and scoped per deployment: a new deployment does not reuse the previous
  one's. Entries unaccessed for 31 days are dropped.
- The Data Cache (Beta) is regional, persists across deployments, and skips items over 2 MB.
- Revalidation reaches all regions within 300ms.
- Sources: V-ISR, V-DC.
- V-ISR: "each new deployment uses its own ISR cache and does not reuse the cache from a previous
  deployment"; "until you revalidate it or it goes unaccessed for 31 days".
- V-DC: "Data Cache (Beta)"; "Persistent across deployments"; "Item size | 2 MB (items larger won't be
  cached)"; "propagates to all regions within 300ms".

**PERF-39. Protect every cron route.**
- Compare the `authorization` header with `` `Bearer ${process.env.CRON_SECRET}` `` and return 401 on
  a mismatch.
- Make the job idempotent.
- Remember the delivery rules:
  - crons call the production deployment with GET, in UTC;
  - there are no retries;
  - runs can be missed or duplicated;
  - redirects are not followed;
  - Hobby runs once a day.
- Sources: V-CRONM, V-CRON, V-LIMITS.
- V-CRONM: the verified route code; "Vercel will not retry an invocation if a cron job fails"; "Cron
  delivery can also occasionally invoke the same scheduled run more than once"; "Cron jobs do not follow
  redirects"; "Hobby … can only run once per day".
- V-CRON: "Vercel makes an HTTP GET request to your project's production deployment URL"; "The timezone
  is always UTC".
- V-LIMITS: "Cron Jobs (per project) | 100".

**PERF-40. Scope each environment variable to the Vercel environments that need it (Production,
Preview, Development).**
- Remember that a change applies only to new deployments.
- Keep all variables within 64 KB per deployment.
- Use `vercel env pull` for local values.
- Adding or removing a live variable is Jonathan's: record it as `deploy_pending`.
- Secret exposure is in `proxy-auth-and-security.md`.
- Sources: V-ENV, V-ENVS, plus a relative link to `../deploy-guards.md`.
- V-ENV: "they only apply to new deployments"; "a total of **64 KB** in Environment Variables
  **per-Deployment**"; "Any branch-specific variables will override other preview environment variables
  with the same name."
- V-ENVS: preview deployments come from pushes to a non-production branch and from PRs.

**PERF-41. Rely on Vercel Skew Protection instead of hand-rolled version pinning.**
- It is on by default for projects created after November 19, 2024 (Pro and Enterprise).
- Next.js 14.1.4 and newer needs no `next.config` change.
- Client `fetch()` calls to your own APIs are not pinned automatically.
- Source: V-SKEW.
- "Skew Protection is available on Enterprise and Pro plans".
- "Projects created after November 19th 2024 … already have Skew Protection enabled by default."
- "If you are using Next.js 14.1.4 or newer and building on Vercel, there is no additional configuration
  needed".
- "The framework doesn't automatically pin custom `fetch()` calls you make from client components."

**PERF-42. Keep Vercel project config in exactly one file.**
- Use `vercel.json` for static config, or `vercel.ts` (typed with `@vercel/config`) for config computed
  at build time.
- Keep Next.js headers and redirects in `next.config`.
- Sources: V-PC, V-VTS, V-CDN.
- V-VTS: "Use only one configuration file: `vercel.ts` or `vercel.json`."
- V-VTS: "`vercel.ts` executes at build time"; `import { routes, type VercelConfig } from
  '@vercel/config/v1'`.
- V-CDN: prefer `next.config.js` for Next.js.

**PERF-43. Never run, script or recommend a Vercel deploy, promote, rollback or environment-change
command (convention).**
- Change config in code, and list what needs a deployment or dashboard change under `deploy_pending` in
  the run report.
- Link the blocked list as a relative link, [deploy-guards.md](../deploy-guards.md). Do not quote the
  commands: the test forbids them.
- The rule carries `(convention)`.

### Verified snippets for `## Patterns`

Use these exactly. Typing is added where a page shows untyped JS, with no `any`. Bold lead-in lines
replace `###` headings. Each block cites its rule ids in the lead-in.

- **Responsive card image (PERF-2, PERF-3).** Source: IMG-API, the `sizes` and `fill` examples. tsx:

  ```tsx
  import Image from 'next/image'

  type CardImageProps = { src: string; alt: string }

  export function CardImage({ src, alt }: CardImageProps) {
    return (
      <div style={{ position: 'relative', aspectRatio: '4 / 3' }}>
        <Image
          src={src}
          alt={alt}
          fill
          sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
          style={{ objectFit: 'cover' }}
        />
      </div>
    )
  }
  ```

- **LCP hero (PERF-4).** tsx. Static import, `alt`, `loading="eager"`, `sizes="100vw"`. No `preload`, no
  `priority`:

  ```tsx
  import Image from 'next/image'
  import hero from './hero.jpg'

  export function Hero() {
    return <Image src={hero} alt="Product hero" loading="eager" sizes="100vw" />
  }
  ```

- **Remote allow-list and image config (PERF-5, PERF-6).** Source: IMG-GS. ts:

  ```ts
  import type { NextConfig } from 'next'

  const nextConfig: NextConfig = {
    images: {
      remotePatterns: [
        {
          protocol: 'https',
          hostname: 's3.amazonaws.com',
          port: '',
          pathname: '/my-bucket/**',
          search: '',
        },
      ],
      qualities: [75],
    },
  }

  export default nextConfig
  ```

- **Font definitions plus layout plus Tailwind (PERF-8 to PERF-11).** Source: FONT-API. `app/fonts.ts`
  (ts):

  ```ts
  import { Inter, Roboto_Mono } from 'next/font/google'
  import localFont from 'next/font/local'

  export const inter = Inter({ subsets: ['latin'], display: 'swap', variable: '--font-inter' })
  export const robotoMono = Roboto_Mono({ subsets: ['latin'], display: 'swap', variable: '--font-roboto-mono' })
  export const brand = localFont({ src: './brand.woff2', display: 'swap', variable: '--font-brand' })
  ```

  Then `app/layout.tsx` (tsx) with `RootLayout({ children }: { children: React.ReactNode })` and
  ``<html lang="en" className={`${inter.variable} ${robotoMono.variable}`}>``. Then `app/globals.css`
  (css):

  ```css
  @import 'tailwindcss';

  @theme inline {
    --font-sans: var(--font-inter);
    --font-mono: var(--font-roboto-mono);
  }
  ```

- **Layout-scoped script (PERF-12, PERF-13).** Source: SCR-G and SCR-API. tsx:

  ```tsx
  import Script from 'next/script'

  export default function DashboardLayout({ children }: { children: React.ReactNode }) {
    return (
      <>
        <section>{children}</section>
        <Script src="https://example.com/chat-widget.js" strategy="lazyOnload" />
      </>
    )
  }
  ```

  Optionally add a second, client block (PERF-14):
  `'use client'` + `<Script id="maps-sdk" src="https://example.com/maps.js" strategy="afterInteractive" onReady={() => { /* init */ }} />`.

- **Lazy client widget (PERF-19).** Source: LAZY. tsx:

  ```tsx
  'use client'

  import { useState } from 'react'
  import dynamic from 'next/dynamic'

  const Chart = dynamic(() => import('./chart').then((mod) => mod.Chart), {
    ssr: false,
    loading: () => <p>Loading chart…</p>,
  })

  export function ReportPanel() {
    const [isOpen, setIsOpen] = useState(false)
    return (
      <section>
        <button onClick={() => setIsOpen(true)}>Show chart</button>
        {isOpen && <Chart />}
      </section>
    )
  }
  ```

- **Server-only data module (PERF-18).** Source: SCC. ts:

  ```ts
  import 'server-only'

  export async function getData(): Promise<unknown> {
    const res = await fetch('https://example.com/data', {
      headers: { authorization: process.env.API_KEY ?? '' },
    })
    return res.json()
  }
  ```

- **Heavy transform on the server (PERF-17).** Source: BUNDLE. tsx:

  ```tsx
  import { codeToHtml } from 'shiki'

  export default async function Page() {
    const html = await codeToHtml('export const answer = 42', { lang: 'tsx', theme: 'github-dark' })
    return <pre><code dangerouslySetInnerHTML={{ __html: html }} /></pre>
  }
  ```

- **Bundler, compiler and bundling config (PERF-21, PERF-22, PERF-25).** ts:

  ```ts
  import type { NextConfig } from 'next'

  const nextConfig: NextConfig = {
    reactCompiler: true,
    serverExternalPackages: ['@acme/ui'],
    experimental: { optimizePackageImports: ['icon-library'] },
  }

  export default nextConfig
  ```

  The lead-in says the `optimizePackageImports` line is experimental and is added only after analyzer
  evidence.

- **Web Vitals reporter (PERF-26).** Source: RWV. tsx:

  ```tsx
  'use client'

  import { useReportWebVitals } from 'next/web-vitals'

  type ReportWebVitalsCallback = Parameters<typeof useReportWebVitals>[0]

  const reportWebVitals: ReportWebVitalsCallback = (metric) => {
    const body = JSON.stringify(metric)
    const url = 'https://example.com/analytics'
    if (navigator.sendBeacon) {
      navigator.sendBeacon(url, body)
    } else {
      fetch(url, { body, method: 'POST', keepalive: true })
    }
  }

  export function WebVitals(): null {
    useReportWebVitals(reportWebVitals)
    return null
  }
  ```

- **Speed Insights and Analytics (PERF-27).** Source: V-SI and V-WA. tsx: a root layout importing
  `SpeedInsights` from `'@vercel/speed-insights/next'` and `Analytics` from `'@vercel/analytics/next'`,
  rendering `{children}<SpeedInsights /><Analytics />` inside `<body>`.

- **Per-route duration (PERF-31).** Source: V-DUR and MAXD. ts, `app/api/reports/route.ts`:

  ```ts
  export const maxDuration = 60 // must not exceed the plan maximum

  export async function POST(request: Request): Promise<Response> {
    const input: unknown = await request.json()
    return Response.json({ received: input !== null })
  }
  ```

- **Post-response work (PERF-32).** Source: AFTER. ts or tsx, with `import { after } from 'next/server'`
  and `after(() => { log() })` inside a handler that returns its response first. A short typed
  `log(): void` stub is declared in the block.

- **Cron route plus `vercel.json` (PERF-34, PERF-39).** Source: V-CRONM. ts:

  ```ts
  import type { NextRequest } from 'next/server'

  export function GET(request: NextRequest): Response {
    const authHeader = request.headers.get('authorization')
    const cronSecret = process.env.CRON_SECRET

    if (!cronSecret || authHeader !== `Bearer ${cronSecret}`) {
      return new Response('Unauthorized', { status: 401 })
    }

    return Response.json({ success: true })
  }
  ```

  json:

  ```json
  {
    "$schema": "https://openapi.vercel.sh/vercel.json",
    "regions": ["iad1"],
    "crons": [{ "path": "/api/cron", "schedule": "0 5 * * *" }]
  }
  ```

- **CDN-targeted cache headers (PERF-37).** Optional; drop it if over the line budget. Source: V-CDN.
  ts: `export async function GET(): Promise<Response>` returning `new Response('...', { headers:
  { 'Cache-Control': 'public, s-maxage=1', 'CDN-Cache-Control': 'public, s-maxage=60',
  'Vercel-CDN-Cache-Control': 'public, s-maxage=3600' } })`.

### `## Anti-patterns`

There are 6 pairs, formatted as `**Don't** <title> (PERF-n)` / fenced block / `**Do** <fix>` / fenced
block, with no `###` headings:

1. `<Image fill src=… />` with no `sizes`, and a raw `<img>`. Fix: `fill` plus `sizes` (PERF-2, PERF-3).
2. `priority` on several images (deprecated), or `preload` together with `loading="eager"`. Fix: one LCP
   image with `loading="eager"` (PERF-4).
3. `images: { domains: ['cdn.example.com'] }`, or `remotePatterns: [{ hostname: '**' }]`. Fix: a narrow
   pattern with `pathname` and `search: ''` (PERF-5).
4. A `<link href="https://fonts.googleapis.com/...">` in the root layout. Fix: `next/font/google` with
   `subsets` and `variable` (PERF-8, PERF-9). This URL sits inside a code block, so it is exempt from
   Sources.
5. `export const runtime = 'edge'` plus `export const preferredRegion = 'home'` in `route.ts`. Fix: no
   exports, and `"regions"` in `vercel.json` (PERF-29, PERF-34).
6. A cron `GET` with no auth check that increments a counter. Fix: the `CRON_SECRET` check plus an
   idempotent "set" operation (PERF-39).

### `## Version notes` (Next.js 16)

Each bullet carries its link:

- Turbopack is the default for dev and build. A custom `webpack` config fails `next build`. Opt out with
  `--webpack`. `experimental.turbopack` moved to top-level `turbopack` (UP16, TURBO).
- The Turbopack filesystem cache is on by default: dev from 16.1 and build from 16.3 (TFSC).
- `next experimental-analyze` was added in 16.1. `next build` dropped the `size` and `First Load JS`
  output in 16.0 (CLI, UP16).
- React Compiler support is stable. `reactCompiler` is top-level and off by default. An experimental
  Rust compiler arrived in 16.3 (UP16, BLOG163).
- `next/image` changes (UP16, IMG-API):
  - `priority` is deprecated and `preload` added;
  - `qualities` defaults to `[75]`;
  - `imageSizes` drops `16`;
  - `minimumCacheTTL` went from 60 seconds to 4 hours;
  - local `src` with a query string needs `localPatterns.search`;
  - `dangerouslyAllowLocalIP` was added;
  - `maximumRedirects` defaults to 3;
  - `images.domains` and `next/legacy/image` are deprecated.
- The Edge runtime and `preferredRegion` are deprecated in the current 16.x docs. Vercel says
  `runtime = 'edge'` is not supported from 16.3 (RT-RUN, PREG, V-EDGE). `proxy` runs only on Node.js
  (UP16; details in `proxy-auth-and-security.md`).
- The 16 upgrade guide lists no change to `next/font`, `next/script`, `next/dynamic`,
  `optimizePackageImports` or `serverExternalPackages` (UP16).

### `## Review checklist`

Each item names its PERF id, has no unit tokens and is one line. Up to 18 items:

- PERF-2, PERF-3: dimensions and `sizes`.
- PERF-4: no `priority`, and a single eager LCP image.
- PERF-5: narrow `remotePatterns`, no `domains`.
- PERF-6, PERF-7: `qualities` allow-list, and tiny or vector images `unoptimized`.
- PERF-8 to PERF-11: fonts through `next/font`, defined once.
- PERF-12, PERF-13: `next/script` scoped narrowly, with an explicit strategy.
- PERF-14: script handlers only in client files.
- PERF-16 to PERF-18: client leaves, server transforms, `server-only`.
- PERF-19: heavy widgets lazy, `ssr: false` only in client files.
- PERF-20 to PERF-22: analyzer evidence, and `optimizePackageImports` only for packages not on the
  built-in list.
- PERF-23, PERF-25: no `webpack()` config and no `--turbopack` flags; the compiler is a deliberate
  change.
- PERF-26, PERF-27: the vitals reporter has a stable callback.
- PERF-29, PERF-34: no `runtime = 'edge'`, no `preferredRegion`.
- PERF-30: no request data in module scope.
- PERF-31: `maxDuration` is within the plan maximum.
- PERF-35: large uploads bypass the function.
- PERF-37, PERF-39: cacheable responses set no cookie; cron routes are authorized and idempotent.
- PERF-40, PERF-43: env and config changes are listed as `deploy_pending`; no deploy command.

### `## Scope`

Scope says the file covers images, fonts, scripts, lazy loading, bundle analysis and size, the
bundler and compiler, Web Vitals, and the Vercel function platform and its config.

It defers other subjects, each with a relative link:

| Subject | File |
| --- | --- |
| Cache and rendering strategy | [rendering-and-caching.md](rendering-and-caching.md) |
| Handler code shape | [route-handlers-and-apis.md](route-handlers-and-apis.md) |
| SSE durations | [sse-and-streaming.md](sse-and-streaming.md) |
| Secrets, proxy and env exposure | [proxy-auth-and-security.md](proxy-auth-and-security.md) |
| Env typing | [typescript.md](typescript.md) |
| Tests and observability | [testing-and-observability.md](testing-and-observability.md) |

It also links back to [nextjs.md](../nextjs.md) and [deploy-guards.md](../deploy-guards.md).

## 8. Not confirmed by the docs

The coder writes these under `## Not confirmed by the docs`. Each item is one list item carrying the
URLs checked, and none is stated as a rule:

1. **Pro multi-region count.** V-REG's limits table says Pro "5 regions". V-FLUID's defaults table says
   Pro "Up to 3" multi-region functions. Both pages say Hobby is single region. No Pro number is stated.
2. **Remote image TTL on Vercel.** V-IMG says the remote-image TTL default `minimumCacheTTL` is
   "`3600` seconds". IMG-API and UP16 give the Next.js 16 default as `14400` (4 hours). The file states
   only the Next.js value for `next.config` and no Vercel-side default.
3. **`optimizePackageImports` production readiness.** BUNDLE recommends it. OPI says "experimental …
   not recommended for production". The file states it as experimental, not as production-safe.
4. **Edge in 16.3: warning or error?** Next.js pages say "deprecated" (RT-RUN, EDGE-MSG). V-EDGE says "no
   longer supported" from 16.3. Neither says whether a `runtime = 'edge'` export warns or fails the
   build. BLOG163 does not mention it.
5. **General Route Handler request body limit.** No Next.js page found documents one, beyond:
   - Server Actions at 1MB (SACFG);
   - proxy's buffered-body cap, `proxyClientMaxBodySize`, default 10MB, which is experimental:
     https://nextjs.org/docs/app/api-reference/config/next-config-js/proxyClientMaxBodySize. This URL
     then also goes in Sources and evidence.
   Only Vercel's 4.5 MB platform limit is stated.
6. **Skew Protection maximum age per plan.** V-SKEW gives only "one day" as the default and "up to your
   project's Deployment Retention limit". There are no per-plan numbers, so none are stated.
7. **Speed Insights dashboard step.** V-SI shows no "enable in dashboard" step. V-WA does, for Web
   Analytics. The file states the step only for Web Analytics.
8. **Client bundle budget.** No nextjs.org page gives a numeric client-JS budget per route, so the file
   sets none.

## 9. Assumptions

1. **As-of line.** It is copied verbatim from the merged `R/nextjs.md`. The expected value is
   `> As of Next.js 16.3.8, verified 2026-10-04.`, read live from the nextjs.org docs front matter and
   the blog. If the merged line differs, the merged line wins, and Version notes uses its major.
2. **No URL fragments or query strings.** Each page is listed once in Sources. This avoids guessing how
   the shared helpers normalise `#anchors`.
3. **No `###` headings in the topic file.** Bold lead-ins are used instead, so a `section()` that stops
   at any heading cannot truncate a section. Every rule is a single physical line, so `rule_items` and
   the unit-token check never depend on continuation-line parsing.
4. **Don't/Do format.** It is `**Don't** …` / fence / `**Do** …` / fence. If the merged contract defines
   a different "Don't item" form, the coder follows it and adapts
   `test_anti_patterns_pair_each_dont_with_a_do`.
5. **Caching scope.** The orchestrator's topic scope lists ISR, the CDN and the Data Cache on Vercel.
   The story puts caching strategy in `rendering-and-caching.md`. This file therefore states only Vercel
   platform facts (PERF-37, PERF-38) and links there for strategy. There are no `use cache`, `cacheLife`
   or `revalidate` rules here.
6. **Env vars scope.** This file owns Vercel environment scoping, redeploy timing and size (PERF-40).
   Exposure and secrets stay in `proxy-auth-and-security.md`.
7. **`@next/third-parties`** is included (PERF-15) because the nextjs.org page documents it, with its
   experimental status stated.
8. **Unit-token matching.** The AC5 test is case-sensitive (`MB`, ` GB`, `seconds`, `minutes`). A
   checklist item never carries a unit token.
9. **Live-fetch evidence.** Evidence rows are re-checked live by the coder on the day of coding. If that
   day is not 2026-10-04, the row still records 2026-10-04 as the research fetch date, plus the coder's
   re-check date, and `validation.md` notes it.
10. **Placeholder URLs in code.** `https://example.com/...` and `https://openapi.vercel.sh/vercel.json`
    appear only inside fenced code, which the contract exempts from Sources.
11. **Skeleton plan not read.** It was being written in parallel and did not exist when this plan was
    written. Every contract detail above comes from the skeleton story.md, and the merged code wins.
