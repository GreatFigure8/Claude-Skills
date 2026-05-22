# Verification Toolkit

Commands and scripts for verifying OIC integration artifacts before activation. Cheap to run; saves time-consuming debug cycles later.

## JavaScript syntax check

Catches typos, missing braces, ES6 syntax that slipped in:

```bash
node --check cashApplicationLib_v25.js
```

Exit code 0 = clean. Any output = problem. Run before every upload to OIC.

## Nashorn ES5 verification

OIC's runtime is Nashorn, which speaks ES5.1 — older than Node.js. Some syntax that Node accepts (like template literals, arrow functions, `let`/`const`) breaks Nashorn at runtime. Catch these locally:

```bash
/usr/lib/jvm/java-11-openjdk-amd64/bin/jjs --language=es5 --no-deprecation-warning <script.js>
```

To exercise a specific function:

```bash
cat > /tmp/test.js <<'EOF'
load('/path/to/cashApplicationLib.js');
print(dkcas_someFunction('arg1', 'arg2'));
EOF
/usr/lib/jvm/java-11-openjdk-amd64/bin/jjs --language=es5 --no-deprecation-warning /tmp/test.js
```

The `--language=es5` flag tells Nashorn to reject ES6+ features. `--no-deprecation-warning` suppresses the warning about Nashorn being deprecated in Java 11+ (it still works fine for OIC's purposes).

## `var _ret` pattern lint

Walk every declared function and confirm it has `var _ret;` at the top and a single `_ret = ...; return _ret;` at the end:

```python
import re

with open('cashApplicationLib.js') as f:
    src = f.read()

funcs = re.findall(
    r'function\s+(\w+)\s*\([^)]*\)\s*\{(.*?)^\}',
    src, re.DOTALL | re.MULTILINE
)
for name, body in funcs:
    has_var = 'var _ret;' in body
    returns = re.findall(r'^\s+return\s+([^;]+);', body, re.MULTILINE)
    only_ret = all(r.strip() == '_ret' for r in returns)
    status = '✓' if (has_var and only_ret and len(returns) > 0) else '✗'
    print(f'{status} {name}: var _ret={has_var}, returns={returns}')
```

False positives possible for functions containing inline lambdas (the regex sees `return` statements inside the lambda body). Read the output critically — if the only "extra" returns are inside `.replace(/.../g, function(...) { return ...; })` callbacks, it's a false positive.

## HTML well-formedness check (for documentation deliverables)

```python
from lxml import html
doc = html.parse('cash_application_oic_implementation_guide_v49.html')
print(f'parses: {len(doc.xpath("//*"))} nodes')
```

If the parse fails or returns far fewer nodes than expected, the HTML has structural issues that should be fixed before delivery.

## Screenshot rendering (for visual verification)

```python
import asyncio
from playwright.async_api import async_playwright

async def shoot():
    async with async_playwright() as p:
        b = await p.chromium.launch()
        page = await b.new_page(viewport={'width': 1200, 'height': 1800})
        await page.goto('file:///path/to/file.html', wait_until='networkidle')
        await page.screenshot(path='render.png', full_page=False)
        await b.close()

asyncio.run(shoot())
```

For viewing a specific section, scroll first:

```python
await page.evaluate('''() => {
  const target = document.querySelector('#step-23');
  if (target) window.scrollTo({top: target.offsetTop - 20, behavior: 'instant'});
}''')
await page.wait_for_timeout(300)
```

## JSON sample validation

Before pasting a JSON sample into a Stage File or REST trigger, confirm it parses:

```bash
python3 -c "import json, sys; json.loads(sys.stdin.read())" < sample.json
```

If it parses, OIC's schema inference will accept it. If it fails, fix the syntax first.

## hackett-fusion MCP — live tenant probing

Four tools available; use them in order when starting a new session:

**1. `auth_check`** — confirm the MCP can reach the tenant.
Returns: status (`ok` / `auth_failed` / `error`), DB user, session time.

**2. `identify_environment`** — fingerprint the tenant.
Returns: DB identifiers, enterprise name, counts of ledgers, BUs, LEs, active users. Useful to confirm you're pointed at TEST not PROD.

**3. `execute_sql`** — run a SELECT.
Takes a single SELECT statement (no trailing semicolon, no DDL/DML).
Returns: JSON with columns, row count, truncation flag, rows.
Constraints documented in `fusion-service-quirks.md`.

**4. `run_bip_report`** — run a BIP report by absolute path.
Takes the absolute path (no `/Shared Folders/` prefix, ends in `.xdo`), optional format.
Returns: report output in the requested or default format.

**Standard opening sequence:**
```
1. auth_check  → confirm connectivity
2. identify_environment  → confirm correct tenant
3. execute_sql with a small probe  → confirm SQL pipeline works
   Example: SELECT 1 AS probe FROM DUAL
```

If any of these fail, the underlying issue is environmental — credentials, network, MCP server state. Restart the MCP server (`/restart` command) if SQL queries timeout consecutively.

## OIC activity log inspection

After activating an integration and running it, the OIC console exposes an activity stream per execution. Useful inspection points:

- **JS activity entries** — show which library version was actually used (helps diagnose the cache trap from `platform-constraints.md`).
- **REST/SOAP activity entries** — show the full request payload and response, including faults.
- **Stitch activity entries** — show each operation's target and resolved value. Most useful for debugging scope variable state.
- **Switch activity entries** — show which branch fired (or that no branch fired). The "no branch fired" case is often a silent bug.

Run with **tracing enabled** for the first few activations of a new flow — the trace level provides per-activity payload snapshots.

## Manual smoke test flow

After uploading a new library version and reactivating an integration:

1. **Check the library's Configure tab** — does the function list match expectations? Did the upload take?
2. **Run the integration with a known-good payload** — does it complete?
3. **Run the integration with a known-bad payload** — does the right error path fire?
4. **Compare activity logs to expectations** — which JS activities ran, with what inputs, what outputs?

Don't trust silence. If the integration completes successfully but the activity log shows that a JS activity returned an unexpected value, dig in immediately — silent acceptance of bad outputs is the worst failure mode.

## Pre-flight checklist before activating

Before every reactivation:

- [ ] `node --check` clean.
- [ ] `jjs --language=es5` runs the smoke test without error.
- [ ] Lint script confirms every declared function has `var _ret;` and a single named return.
- [ ] If parameter signatures changed, re-Save every Call JavaScript Function activity.
- [ ] If response schema changed, re-paste the Sample JSON Document in the REST trigger and Stage File activities.
- [ ] Hard-refresh the Designer UI (Ctrl+Shift+R).
- [ ] Deactivate → Activate (not just Save).

Most "but it worked yesterday" failures trace to skipping one of these.
