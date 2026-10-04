# Sources verified — `route-handlers-and-apis.md`

Every URL below was fetched live on **2026-10-04** by the planner of story
`route-handlers-and-api-design` (WebFetch, or `curl` of the page's `.md` export for the two
long vercel.com pages). The nextjs.org pages all reported `version: 16.3.8` in their
front matter; the blog lists 16.3.8 (Active LTS, 2026-09-30) as the latest stable release.

This list must equal the `## Sources` list of
`Skills/dev-bother-me-nope/skills/dev-bother-me-nope/references/nextjs/route-handlers-and-apis.md`
(AC10). If the coder adds or drops a source, this file changes in the same commit.

| URL | Fetched | Backs |
| --- | --- | --- |
| https://nextjs.org/docs/app/getting-started/route-handlers | 2026-10-04 | API-1, API-2, API-23, API-24; Version notes (Cache Components) |
| https://nextjs.org/docs/app/api-reference/file-conventions/route | 2026-10-04 | API-2, API-4, API-7, API-28, API-31, API-32; Version notes (15.0.0-RC history) |
| https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config | 2026-10-04 | API-25, API-35; Version notes (v16.0.0 removals) |
| https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/runtime | 2026-10-04 | API-35; Version notes (Edge) |
| https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config/maxDuration | 2026-10-04 | API-36 |
| https://nextjs.org/docs/messages/edge-runtime-deprecated | 2026-10-04 | API-35 |
| https://nextjs.org/docs/app/guides/backend-for-frontend | 2026-10-04 | API-3, API-5, API-6, API-8, API-9, API-12, API-13, API-16, API-19, API-22, API-26, API-29, API-30, API-32, API-37, API-38, API-39 |
| https://nextjs.org/docs/app/api-reference/functions/after | 2026-10-04 | API-33, API-34; Version notes (stable since 15.1) |
| https://nextjs.org/docs/app/api-reference/functions/next-request | 2026-10-04 | API-3, API-20 |
| https://nextjs.org/docs/app/api-reference/functions/next-response | 2026-10-04 | API-3, API-29, API-30 |
| https://nextjs.org/docs/app/api-reference/functions/cookies | 2026-10-04 | API-28 |
| https://nextjs.org/docs/app/api-reference/functions/redirect | 2026-10-04 | API-14, API-30 |
| https://nextjs.org/docs/app/api-reference/functions/forbidden | 2026-10-04 | API-18 |
| https://nextjs.org/docs/app/api-reference/functions/revalidateTag | 2026-10-04 | API-27 |
| https://nextjs.org/docs/app/api-reference/functions/updateTag | 2026-10-04 | API-27; Version notes (caching APIs) |
| https://nextjs.org/docs/app/api-reference/config/next-config-js/headers | 2026-10-04 | API-31 |
| https://nextjs.org/docs/app/api-reference/file-conventions/proxy | 2026-10-04 | API-16, API-31; Version notes (proxy rename) |
| https://nextjs.org/docs/app/guides/authentication | 2026-10-04 | API-13, API-14, API-16, API-28 |
| https://nextjs.org/docs/app/guides/data-security | 2026-10-04 | API-8, API-15, API-17 |
| https://nextjs.org/docs/app/guides/server-actions | 2026-10-04 | API-5, API-17 |
| https://nextjs.org/docs/app/getting-started/mutating-data | 2026-10-04 | API-5 |
| https://nextjs.org/docs/app/guides/caching-without-cache-components | 2026-10-04 | API-23 |
| https://nextjs.org/docs/app/guides/upgrading/version-16 | 2026-10-04 | API-4; Version notes (async request APIs, proxy, caching APIs) |
| https://nextjs.org/blog/next-16 | 2026-10-04 | Version notes (breaking changes, `revalidateTag`, `updateTag`, proxy) |
| https://nextjs.org/blog/next-16-3 | 2026-10-04 | Version notes (root params not yet in Route Handlers) |
| https://vercel.com/docs/functions/functions-api-reference | 2026-10-04 | API-35, API-39; Version notes (Edge unsupported from 16.3) |
| https://vercel.com/docs/functions/functions-api-reference/vercel-functions-package | 2026-10-04 | API-34 |
| https://vercel.com/docs/functions/configuring-functions/duration | 2026-10-04 | API-36 |
| https://vercel.com/docs/functions/limitations | 2026-10-04 | API-36, API-37 |
| https://vercel.com/docs/functions/runtimes/edge | 2026-10-04 | API-35 |
| https://vercel.com/docs/vercel-firewall/vercel-waf/rate-limiting | 2026-10-04 | API-19 |
| https://vercel.com/docs/vercel-firewall/vercel-waf/rate-limiting-sdk | 2026-10-04 | API-19; Patterns (rate-limited POST) |
| https://vercel.com/docs/headers/request-headers | 2026-10-04 | API-32; Patterns (webhook) |
| https://vercel.com/docs/webhooks/webhooks-api | 2026-10-04 | API-33 |
| https://vercel.com/docs/webhooks | 2026-10-04 | API-33 |
| https://vercel.com/docs/caching/cdn-cache | 2026-10-04 | API-26 |
| https://vercel.com/kb/guide/how-do-i-get-the-raw-body-of-a-serverless-function | 2026-10-04 | API-32 |
| https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status | 2026-10-04 | API-9, API-11, API-15 |
| https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status/201 | 2026-10-04 | API-11 |
| https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS | 2026-10-04 | API-31 |
| https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Methods/OPTIONS | 2026-10-04 | API-31; Patterns (preflight status 200) |
| https://developer.mozilla.org/en-US/docs/Glossary/Idempotent | 2026-10-04 | API-21 |
| https://developer.mozilla.org/en-US/docs/Web/API/Response/json_static | 2026-10-04 | API-3, API-10 |
| https://developer.mozilla.org/en-US/docs/Web/API/Request/json | 2026-10-04 | API-9 |
| https://zod.dev/basics | 2026-10-04 | API-8 |
| https://zod.dev/api | 2026-10-04 | API-20; Patterns (`z.uuid`, `z.coerce`, `z.int`, `z.strictObject`, `.pipe`) |
| https://zod.dev/error-formatting | 2026-10-04 | Patterns (`z.flattenError`) |
| https://www.typescriptlang.org/docs/handbook/release-notes/typescript-4-9.html | 2026-10-04 | Patterns (`satisfies`) |
