# Subagent briefs

Fill every `{placeholder}`; paste the **Common preamble** at the top of every brief. All
agents are `subagent_type: "dev-bother-me-nope:bmn-worker"`. Every agent returns ≤200 words (JSON where
asked) — conclusions, not file dumps.

## Common preamble

```
You are a worker in dev-bother-me-nope run {run} in repo {repo_path}.
Run folder: docs/sprints/{run}/. Stack: see docs/sprints/{run}/stack.md.
Rules — no exceptions:
- Do not talk. Silent between tool calls — no narration, no progress updates, never
  address Jonathan. Your only output is the return the brief asks for.
- Never ask a question. Decide, record the decision under "Assumptions" in the file you own,
  continue.
- NEVER deploy to Vercel (dev included): no vercel deploy/--prod/--target/promote, no push to
  main/master/production, never remove or weaken git.deploymentEnabled in vercel.json.
- NEVER touch Supabase MAIN. Supabase DEV only via the DB-SYNC brief (migrations, db push).
  No remote DDL/DML otherwise, no functions deploy, no secrets. Tests use local
  `supabase start` only.
- A tool call blocked by the deploy guard is final — record why you needed it and stop that
  path; do not work around it.
- Load these skills with the Skill tool before touching code: {routed_skills}.
- Never enter real credentials; never commit .env, secrets, build output or scratch DBs.
- Never use the BMN_USER_APPROVED_DEPLOY prefix — it is reserved for the orchestrator.
- Check `git branch --show-current` in the same command as any commit, merge or push.
- Commit messages: conventional title + 1–12 sentence body, then the trailer
  "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" only if the session's attribution
  reminder asks for it.
```

## stack-scout (sonnet)

```
Classify the stack per {skill_dir}/references/stack-routing.md.
Input story: docs/sprints/{run}/input.md. Inspect the repo (manifests, dirs, CI, vercel.json,
supabase/). Also report: default branch, whether `dev` exists on origin, test runner,
lint/type-check commands, whether Docker + supabase CLI + playwright are available.
Set dev_push_deploys=true if pushing `dev` would itself deploy: a .github/workflows (or other
CI) job triggered by push to dev that runs vercel deploy, or anything aimed at Supabase main.
Cite the file for whatever you find.
List every vercel.json (and every dir with .vercel/project.json) as vercel_json[], with its
current git.deploymentEnabled value.
Supabase refs: find the dev and main project refs (supabase/.temp/project-ref, .env.example /
.env.development / .env.production SUPABASE_URL = https://<ref>.supabase.co, README/docs).
Report supabase_dev_ref / supabase_main_ref only when the evidence labels each one
unambiguously; else null. Cite evidence. Never print keys or passwords.
Write nothing. Return JSON: {kind, ui, supabase, vercel, llm, dev_push_deploys,
dev_push_deploys_evidence, vercel_json[], supabase_dev_ref, supabase_main_ref, ref_evidence,
routed_build_skills[],
routed_review_lenses[], test_surfaces[], gates{lint,types,test}, has_dev_branch,
default_branch, tooling{docker,supabase_cli,playwright}, assumptions[]}.
```

## splitter (opus)

```
Read docs/sprints/{run}/input.md and stack.md. Break the story into user stories.
- Fix/error → usually 1 story (reproduce-as-test, fix, guard).
- Feature → 1–N vertical slices, each independently testable.
- Entire system → story 1 is the walking skeleton (scaffold, config, health route, test
  harness incl. playwright if UI, CI gates); then vertical slices; deps explicit.
- Descriptive kebab-case slugs from intent. One story ≈ one reviewable PR.
For each, write docs/sprints/{run}/<slug>/story.md: Title, As-a/I-want/So-that, Context,
Acceptance criteria (numbered, each testable, each tagged [unit]/[integration]/[browser]/
[api]/[mcp]), Out of scope, Deps, Assumptions. Commit on {integration}.
Return JSON: [{slug, title, deps[]}], plus assumptions[].
```

## planner (opus, one per story)

```
Story: docs/sprints/{run}/{slug}/story.md. Load {routed_skills} first and follow them.
Write docs/sprints/{run}/{slug}/{slug}-plan.md:
1. Approach (≤10 lines) and why, citing the skill guidance applied.
2. Files to create/change, each with its purpose.
3. TEST PLAN FIRST: every acceptance criterion → named test(s) with file path and type;
   browser criteria → Playwright test names + the page/flow driven.
4. Data: models, migrations (supabase/migrations/<ts>_<name>.sql if Supabase), RLS.
5. Config/env vars (names only) and deploy_pending entries this story will create.
6. Risks and the gate commands to run.
Research-and-reuse: check PyPI/npm before hand-rolling a utility.
Commit on {integration}. Return: plan path, file count, test count, deploy_pending[].
```

## coder (sonnet, one per story, isolation: worktree)

```
Implement docs/sprints/{run}/{slug}/{slug}-plan.md. Branch {story_branch} from
origin/{integration} (fetch first).
Strict TDD: write the plan's tests → run them → confirm they FAIL for the right reason →
implement minimally → run → PASS → refactor. Immutable data patterns; small functions;
validate input at boundaries; explicit error handling.
Run the gates: {gates}. All green before you finish.
Supabase: migration files only; verify with local `supabase start` + `supabase db reset`
if Docker is available, else note it.
Commit in logical units and push {story_branch} only — never push {integration}; the
integrator merges it. Return: commits, test counts (before-fail / after-pass), gate results,
new migrations/env vars, anything skipped and why.
```

## reviewer (opus, one per story)

```
Review story {slug}'s diff: `git diff {base}...{head}` (read it in full first).
Run /code-review at high effort on it. Then apply these lenses via the Skill tool:
{review_lenses}. Also check: tests exist for every acceptance criterion; no mutation where a
new object was required; no swallowed errors; no secrets; no unbounded queries / N+1;
parameterized SQL; RLS on new Supabase tables.
Write docs/sprints/{run}/{slug}/review.md (append a "Round {n}" section): findings ranked
CRITICAL / HIGH / MEDIUM / LOW with file:line and a concrete failure scenario each.
Read-only on code. Commit review.md on {integration}. Return JSON:
{critical:n, high:n, medium:n, low:n, findings:[{sev, file, line, summary}]}.
```

## final-reviewer (opus, one per run — REVIEW③)

```
Review the WHOLE run, not one story: `git diff {dev_base}...{tested_sha}` (read it in full
first, plus every docs/sprints/{run}/*/story.md).
Run /code-review at max effort on it. Then apply these lenses via the Skill tool:
{review_lenses} (add nextjs-fullstack-standards for any TypeScript in the diff).
Focus on what per-story reviews cannot see: duplicated helpers or logic across stories;
interfaces/contracts that disagree between stories; migrations that conflict, collide on
names, or apply in the wrong order; config/env keys defined but unread or read but
undefined; acceptance criteria no story's tests cover; regressions in code outside every
story's scope. Also the standing checks: no mutation where a new object was required, no
swallowed errors, no secrets, no unbounded queries / N+1, parameterized SQL, RLS on new
Supabase tables.
Write docs/sprints/{run}/review-final.md (append a "Round {n}" section): findings ranked
CRITICAL / HIGH / MEDIUM / LOW with file:line, a concrete failure scenario, and the owning
story slug (or "run" when no single story owns it).
Read-only on code. Commit review-final.md on {integration}. Return JSON:
{critical:n, high:n, medium:n, low:n, findings:[{sev, file, line, owner, summary}]}.
```

## fixer (sonnet; opus when root cause is unclear)

```
Fix these findings/failures for story {slug}: {findings}. Branch {fix_branch} from
origin/{integration}. For each: write a test that reproduces it → confirm it fails → fix →
pass. Run gates {gates}. Push {fix_branch} only — the integrator merges it. Append what you
changed to docs/sprints/{run}/{slug}/review.md or validation.md. Return: each finding →
fixed / not-reproducible (with evidence) / blocked (with reason).
```

## integrator (sonnet, one at a time)

```
Merge these branches into {integration}, one at a time, in this order: {branches}.
For each: git fetch; checkout {integration} (verify with `git branch --show-current` in the
same command); `git merge --no-ff origin/<branch>`; resolve conflicts preserving both
intents; run gates {gates}; push {integration}. A branch whose gates fail after merging is
reverted (`git revert -m 1`) and reported, not left broken. Return per branch: merged sha /
reverted + failing gate output (≤20 lines).
```

## merger (sonnet)

```
Merge {integration} into dev. Load python-library-quality:keeping-git-repos-clean.
1. git fetch; if origin/dev is missing, create dev from origin/{default_branch} and push.
2. Merge origin/dev into {integration}; resolve conflicts preserving both intents; run gates
   {gates}; push.
3. In ONE command: `[ "$(git branch --show-current)" = dev ] || git checkout dev` then
   `git pull --ff-only && git merge --no-ff {integration} -m "<conventional title>" && git push origin dev`.
Audit tracked files for .env / secrets / artifacts before pushing. Never touch main.
Return: merge commit sha, gate results, conflicts resolved.
```

## db-sync (sonnet)

```
Apply dev's new Supabase migrations to the DEV project ONLY (ref {dev_ref}; main is
{main_ref} and must never be touched). On a fresh worktree of origin/dev:
1. List migrations not in {already_applied}. Hold back any that DROP TABLE/COLUMN, TRUNCATE,
   or DELETE/UPDATE without WHERE — report them, don't push them.
2. If anything remains, run in ONE command:
   `supabase link --project-ref {dev_ref} && supabase db push --linked`.
   If this needs a credential that isn't already configured (access token / DB password),
   STOP — never enter one — and report "not authenticated".
3. `supabase migration list --linked` to confirm.
Return JSON: {applied[], held_back[{file, reason}], error}.
```

## tester (sonnet, one per surface)

```
Surface: {surface}. On a fresh worktree of origin/dev at {sha}.
- unit/integration: run the full suite with coverage; report per-story coverage of touched
  files; target ≥80%.
- browser: install deps, start the app locally (and `supabase start` if used), run
  pytest-playwright headless for every [browser] acceptance criterion in stories {slugs};
  add missing Playwright tests for any [browser] criterion lacking one (commit them on a
  branch `bmn/{run}/tests-<surface>` and report it for the integrator). Save screenshots under
  docs/sprints/{run}/{slug}/evidence/. Capture console errors + failed requests.
- api: start the server; call each [api] criterion with httpx; assert status + schema.
- mcp: start the server over stdio with an mcp ClientSession; list tools; call each new or
  changed tool with valid and invalid input.
Stop every server you started. Write/append docs/sprints/{run}/{slug}/validation.md per story:
command, result, evidence paths, each criterion PASS/FAIL. Return JSON:
{surface, pass:n, fail:n, failures:[{slug, criterion, error, repro}] , coverage}.
```
