# Environment & Tooling

How to connect to the live Oracle Fusion environment, validate work against it, and the tenant-specific values that must be flagged (and ideally parameterized) when porting to another customer.

## Table of contents
1. The hackett-fusion MCP server
2. Always identify the environment first
3. Live validation workflow
4. Tenant-specific values (Imagine)
5. Revenue Stream codes
6. Row limit and result handling

---

## 1. The hackett-fusion MCP server

The `hackett-fusion` MCP exposes Oracle Fusion via the `HK_SQL_RUNNER` BIP report. Tools:
- `identify_environment` — DB name/instance/service, connected user, **enterprise_name**, ledger/BU/LE/user counts. Call first in any session.
- `auth_check` — connectivity/credential health.
- `execute_sql` — runs a single SELECT (base64'd through the BIP data model, decoded and run via a ref cursor). Trailing semicolons stripped. DDL/DML not supported.
- `run_bip_report` — runs a deployed BIP report by absolute catalog path (`.xdo`, no `/Shared Folders` prefix).

`execute_sql` quirks:
- **Row limit**: results capped by `FUSION_ROW_LIMIT` (default 1000). For population-level audits, aggregate inside the query (`COUNT`, `SUM(CASE ...)`) rather than returning rows — see the invariant check in `gotchas-and-fixes.md` §13.
- **ORDER BY on aliases**: the ref-cursor wrapping can hide column aliases from `ORDER BY`. Use `ORDER BY <position>` (e.g. `ORDER BY 1`) instead of `ORDER BY <alias>`.
- **Large SQL**: the full waterfall is ~1490 lines / ~56KB. It can be submitted but is unwieldy in one call; for validation, submit a trimmed wrapper (the CTE chain through `base_data` plus the audit columns) rather than the entire final SELECT when you only need to check invariants.

## 2. Always identify the environment first

**The MCP connection has been observed silently switching tenants mid-session** — pointing variously at `eqba-dev4`/`eqba-dev5` ("Imagine"), and at `fa-ewpl-test` ("Setup Enterprise", which has *no OSS data*). A query against the wrong/empty tenant returns **zero rows that look exactly like a logic bug**. Before trusting any result:
```
identify_environment  → confirm enterprise_name = "Imagine"
```
If you get zero rows where you expected data, re-check the environment before debugging the SQL.

## 3. Live validation workflow

1. `identify_environment` → confirm Imagine.
2. Run the change.
3. Run the audit-invariant population check (`gotchas-and-fixes.md` §13): expect `total_rows ≈ 7,362` and 0/0/0 failures for Row-Total / IS-002 / IS-003.
4. For fan-out suspicions, run the duplicate-source diagnostic (`gotchas-and-fixes.md` §1).
5. Spot-check known POLs (e.g. 30001 for currency, `LineSplitsTest04` for version-skew recovery).

Never declare a fix "done by construction" without running it. A stray duplicated `FROM buckets_n ;` block once made the file fail to parse despite "correct" logic; only running it caught it.

## 4. Tenant-specific values (Imagine)

Flag every one of these when porting. They are correct for Imagine (`enterprise_name="Imagine"`, non-prod hosts `eqba-dev4`/`eqba-dev5`) but tenant-specific:

| Value | Meaning | Portable alternative |
|---|---|---|
| `application_id = 10455` | period-statuses (Subscription Mgmt) application id | look up via `FND_APPLICATION` rather than hardcode |
| `gcc.segment3 LIKE '4%'` | revenue accounts | tenant COA convention; confirm per tenant |
| `gcc.segment1` = Company | COA segment | confirm segment assignment per COA |
| `gcc.segment3` = GL Account / Department | COA segment | " |
| `gcc.segment8` = Revenue Stream | COA segment | " |
| `catalog_code = 'Product_Reporting'` | item catalog for Product Family | other tenants: `PRODUCT_FAMILY`, `PRODUCT_CATALOG`, etc. |
| `'GLO'` org | master org for PLM `attribute5` | confirm master org code |
| conversion type `'300000002367347'` | = 'Period End' in this tenant | **never hardcode**; join `GL_DAILY_CONVERSION_TYPES.user_conversion_type` |
| functional/reporting currency | not uniformly USD (USD/INR/AUD/EUR/GBP ledgers) | source from `gl_ledgers.currency_code`, never assume USD |

To resolve COA segments portably (rather than by position), join `FND_ID_FLEX_SEGMENTS` by segment name and `FND_FLEX_VALUES(_TL)` for value descriptions.

## 5. Revenue Stream codes

`gcc.segment8` raw codes seen in Imagine (the report displays the *raw code* per the user's choice, not the value-set description):
- `R010` = License
- `R012` = Perpetual License
- `R020` = Care
- `R040` = Managed Services
- `R050` = Hardware
- `R060` = SaaS
- `R070` = Subscription

(Older transcripts also reference `R005`/`R006` in other contexts.) The value-set description lookup (e.g. via the segment8 value set) is available if a future requirement wants the readable name instead of the code.

## 6. Row limit and result handling

- Default cap 1000 rows. Population is ~7,362 OSS POLs, so unfiltered SELECTs truncate. Always either aggregate in-query or filter to a sample for inspection.
- `truncated: true` in the result flags a capped set.
- For reconciling totals, prefer `SUM`/`COUNT` projections that return a single summary row.
