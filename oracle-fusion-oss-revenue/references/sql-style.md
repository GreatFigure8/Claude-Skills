# SQL Style Conventions (mandatory for this user)

All SQL written for this user (Jonathan) must follow these conventions exactly. They apply to every query, diagnostic, and snippet — not just the waterfall report.

## The rules

1. **Keywords unindented, on their own lines.** `SELECT`, `FROM`, `WHERE`, `AND`, `GROUP BY`, `ORDER BY` each start at column 0 on their own line.
2. **Columns and `AND` conditions indented** one level beneath their keyword.
3. **Trailing commas** — commas at the *end* of each column line, never leading.
4. **Oracle-style joins in the `WHERE` clause only.** No ANSI `JOIN ... ON`. List tables comma-separated in `FROM`; put join predicates in `WHERE`.
5. **`(+)` syntax for outer joins**, placed on the deficient side. Remember: any predicate on an outer-joined table needs `(+)` too, or the join silently becomes inner (see gotchas #7).
6. **First `WHERE` condition is always `1 = 1`** — so every real predicate can be a clean `AND` line.
7. **Uppercase SQL keywords.**
8. **Meaningful table aliases** (e.g. `vss`, `vsd`, `vpo`, `vpold`, `vps`, `gcc`, `gll`).
9. **Effective-dating / version logic** applied to `_F` and `_M` tables and to versioned VRM tables where relevant.
10. **BIP parameter binding** via `:p_parameter` (e.g. `:p_period`).
11. **Dates** formatted `TO_CHAR(col, 'MM/DD/YYYY')` for display.
12. **Date arithmetic**: `TRUNC(SYSDATE - N)` not `TRUNC(SYSDATE) - N` for look-back; `ADD_MONTHS(p_date, N)` for month offsets.

## Canonical template

```sql
SELECT
    vss.document_number,
    vsd.line_num,
    vpo.net_line_amt,
    TO_CHAR(vpo.revenue_start_date, 'MM/DD/YYYY') revenue_start_date
FROM
    vrm_source_documents vss,
    vrm_source_doc_lines vsd,
    vrm_perf_obligation_lines vpo
WHERE
    1 = 1
    AND vss.document_type_code = 'FUSION_OSS'
    AND vsd.document_id = vss.document_id
    AND vpo.document_line_id = vsd.document_line_id
    AND vpo.removed_flag = 'N'
ORDER BY
    1, 2
```

## CTE template

```sql
WITH pdt AS
(
SELECT
    TRUNC(TO_DATE(:p_period, 'MON-YY', 'NLS_DATE_LANGUAGE=AMERICAN'), 'MONTH') p_date
FROM
    dual
),
src_docs AS
(
SELECT
    vss.document_id,
    vss.document_number
FROM
    vrm_source_documents vss,
    gl_ledgers gll
WHERE
    1 = 1
    AND vss.document_type_code = 'FUSION_OSS'
    AND gll.ledger_id (+) = vss.ledger_id
)
SELECT
    ...
FROM
    ...
```

## Notes

- BIP emits **uppercase** XML tags from column aliases as long as the aliases are *not* double-quoted (Oracle uppercases unquoted identifiers). So alias `net_line_tcv_t` → tag `<NET_LINE_TCV_T>`. Don't double-quote aliases unless you specifically want mixed case.
- When ordering by an aliased column through the MCP's ref-cursor wrapper, use the column *position* (`ORDER BY 1`) — the alias may be hidden (see `environment-and-tooling.md`).

## User profile context

Jonathan is a master of Oracle Integration Cloud (OIC) and Oracle Fusion architecture, and an expert Python and TypeScript developer (FastAPI, OCI hosting, OIC IDCS/ID-domains auth). Explanations can assume deep technical fluency — be concise and precise, skip basics, and lead with the substantive finding. He works as a Hackett consultant delivering these reports to end customers (the waterfall's end user is Jay Surface).
