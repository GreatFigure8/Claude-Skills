# Pre-PR gates by stack

Run the gates that apply, paste the results into the PR body. A gate that wasn't
run is a gate that failed — say which ones were skipped and why.

Commands below are the common shape; check the repo's own `Makefile`, `justfile`,
`pyproject.toml`, `package.json`, or CI workflow first and use what's actually
configured there rather than assuming.

## Python — FastAPI / FastMCP services

**Load these skills before planning, not after coding** (Phase 0):

- **`building-python-web-apps`** — the reference architecture for a production FastAPI
  service: FastAPI + async SQLAlchemy + Postgres, Stripe, Dockerised deployment. Load it
  before designing a new service or changing its persistence layer, not while reviewing
  the diff.
- **`building-python-mcp-servers`** — the authority for FastMCP servers: tool design and
  error contracts, event-loop-safe blocking work, subprocess wrapping, single-file vs
  packaged distribution, and global-state-free testing. Prefer it over any general
  "MCP server" guidance, which is usually written for the Node/TypeScript SDK and does
  not transfer to FastMCP.
- **`rendering-untrusted-content`** — whenever stored, authored, or imported content is
  rendered into HTML. It audits autoescape bypasses (`|safe` and friends) rather than
  trusting that the template is fine. Applies to any templating layer, not only Python.

```
uv sync
uv run ruff check . && uv run ruff format --check .
uv run mypy <package>
uv run pytest -q
```

- New dependency → it's in the right member's `pyproject.toml` **and** the root
  lockfile is regenerated and committed in the same commit.
- New async work stays async end to end. Don't leave a sync call inside an async
  path — that's the whole reason sync→async conversions get their own PR.
- HTTP clients are injected, not constructed inline, so tests can supply a
  transport. Per-call client lifecycles unless there's a measured reason otherwise.
- Secrets resolve through the credential/secrets provider. No credential material,
  connection strings, pod hostnames with embedded auth, or tokens in the repo,
  in tests, or in fixtures.

## LLM-backed application features

**Load first:** **`building-llm-backed-features`** — building features on top of an LLM API
in Python: prompt surfaces that drift apart, structured outputs, context budgets, model
config wiring, live-model tests kept out of CI, and truthful presentation of model output.

- Prompt text that appears in more than one place has already drifted. Treat prompt surfaces
  the way you treat any duplicated fact — see `shipping-across-surfaces`.
- Live-model tests stay out of CI. A test that calls a real model is not a gate; it is an
  experiment, and it will fail for reasons unrelated to the change under review.
- An evaluator set that has been filtered until it passes is not a passing evaluator set.
  Record what was filtered and why, in the PR body.

## uv workspace / monorepo

- A move between workspace members is a `refactor(move):` commit with no logic change.
- Cross-member imports go through the shared core package's public surface, not
  into another server's internals.
- Root lockfile regenerated whenever any member's dependencies change.
- Temporary scaffolding (a `legacy/` member, a compat shim) carries a comment
  naming the epic and work item that deletes it. Scaffolding without a scheduled
  deletion is permanent maintenance.

## Database migrations

- Migration and the code that requires it land in the **same commit**.
- Forward-compatible: the previous revision of the app can still run against the
  new schema for the length of a deploy. Expand → backfill → contract, as separate
  work items when the contract step is destructive.
- Upgrade and downgrade both exercised against a scratch database.

## MCP tool contracts

External contract stability is an epic-level invariant — existing installs must
keep working:

- Tool names, parameter names, and result shapes stay stable unless the plan says
  otherwise and names the migration path.
- Session/environment binding semantics unchanged (e.g. environment selection
  before tool invocation still behaves the same way).
- New tool → registered, described well enough to trigger correctly, and smoke-run
  against a real environment before the PR, not just unit-tested.
- Renaming or removing a tool is its own work item with its own approval.

## Next.js / Shadcn / Tailwind

```
npm run lint
npx tsc --noEmit
npm run build
```

- Server/client component boundaries deliberate; no secrets in anything reaching
  the client bundle.
- API calls go through the typed client layer, not ad-hoc fetches scattered in
  components.
- New UI primitives come from the existing Shadcn set before anything new is added.

## OCI hosting

- Infrastructure changes are code (Resource Manager stack / Terraform) in the same
  PR as the code that needs them.
- Config through environment/Vault, never baked into an image.
- Per-tenancy deployment shape stays consistent — one stack per customer tenancy;
  a change to the stack shape gets its own work item.
- The rollback story is written down before merge, not improvised after.

## Auth — OIC ID Domains (and other IdPs)

- Scopes and audiences checked against the app's actual registration, not recalled.
- Token validation (issuer, audience, expiry, signature) exercised by a test.
- Local-dev auth bypasses are impossible to enable in a deployed environment.

## Supabase / pgvector

- Row-level security policies reviewed whenever a table is added or its access
  pattern changes.
- Embedding dimension and index type match the model in use; a model change means
  a re-embed work item, not a silent swap.
- Anonymous/shared corpora carry no client-identifying content — check before load,
  not after.
