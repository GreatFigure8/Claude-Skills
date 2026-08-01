# Oracle-Style SQL Conventions for BIP

This is the authoritative reference for SQL written for Oracle Fusion BIP data models. Every SQL artifact this skill produces — main dataset, LOV queries, ad-hoc validation queries — follows these rules without exception.

## Non-negotiable rules

### 1. Join syntax
- **Use Oracle-style joins only.** Joins go in the `WHERE` clause.
- **Use `(+)` for outer joins.** Place the `(+)` on the optional side of the join.
- **No ANSI join syntax.** Do not use `JOIN`, `INNER JOIN`, `LEFT JOIN`, `RIGHT JOIN`, `FULL OUTER JOIN`, `CROSS JOIN`, or `USING` clauses.

#### Why
This convention is non-negotiable for several reasons:
1. Consistency with Oracle's own delivered seeded SQL across the FUSION schema.
2. Easier visual parsing of large join chains when all join conditions live in one `WHERE` block.
3. Reliable predicate pushdown behavior in Oracle's CBO with `(+)` notation.
4. The user's house style — every BIP report at Hackett follows this convention.

#### Correct
```sql
SELECT gjh.name             AS journal_name,
       gjl.je_line_num      AS line_number,
       gcc.segment1         AS company,
       gcc.segment3         AS account
  FROM gl_je_headers       gjh,
       gl_je_lines         gjl,
       gl_code_combinations gcc
 WHERE gjh.je_header_id = gjl.je_header_id
   AND gjl.code_combination_id = gcc.code_combination_id
   AND gjh.ledger_id = :p_ledger_id
   AND gjh.period_name = :p_period_name
 ORDER BY gjh.name, gjl.je_line_num
```

#### Outer join (Oracle style)
```sql
SELECT aia.invoice_num,
       aps.vendor_name,
       acra.check_number
  FROM ap_invoices_all      aia,
       ap_suppliers          aps,
       ap_checks_all         acra
 WHERE aia.vendor_id = aps.vendor_id
   AND aia.invoice_id = acra.invoice_id(+)        -- outer: invoices without checks still appear
   AND aia.org_id = :p_org_id
```

#### Wrong (do not use)
```sql
-- DO NOT WRITE SQL LIKE THIS
SELECT gjh.name, gjl.je_line_num, gcc.segment1
  FROM gl_je_headers gjh
  INNER JOIN gl_je_lines gjl ON gjh.je_header_id = gjl.je_header_id
  LEFT JOIN gl_code_combinations gcc ON gjl.code_combination_id = gcc.code_combination_id
 WHERE gjh.ledger_id = :p_ledger_id
```

### 2. Case and formatting
- Uppercase SQL keywords: `SELECT`, `FROM`, `WHERE`, `AND`, `OR`, `ORDER BY`, `GROUP BY`, `HAVING`, `UNION`, `WITH`, `CASE`, `WHEN`, `THEN`, `ELSE`, `END`, `IS NULL`, `IS NOT NULL`, `LIKE`, `IN`, `EXISTS`, `BETWEEN`.
- Lowercase identifiers, table names, column names, aliases.
- One column per line in `SELECT` lists when there are more than 3 columns.
- Align column aliases vertically with `AS` for readability.
- Right-align keywords against the column edge in indent: `  FROM`, ` WHERE`, `   AND`, ` ORDER BY`.

### 3. Aliases
Short, mnemonic, lowercase. Common conventions:

| Table | Alias |
|-------|-------|
| `gl_je_headers` | `gjh` |
| `gl_je_lines` | `gjl` |
| `gl_code_combinations` | `gcc` |
| `gl_ledgers_v` | `gl` |
| `ap_invoices_all` | `aia` |
| `ap_invoice_distributions_all` | `aida` |
| `ap_invoice_lines_all` | `aila` |
| `ap_suppliers` | `aps` |
| `ap_checks_all` | `aca` |
| `ar_cash_receipts_all` | `acra` |
| `ra_customer_trx_all` | `rcta` |
| `ra_customer_trx_lines_all` | `rctla` |
| `hz_parties` | `hzp` |
| `hz_cust_accounts` | `hca` |
| `xla_ae_headers` | `xah` |
| `xla_ae_lines` | `xal` |
| `xla_distribution_links` | `xdl` |
| `per_all_people_f` | `papf` |
| `per_all_assignments_m` | `paam` |
| `per_jobs_f` | `pjf` |
| `per_grades_f` | `pgf` |
| `hr_all_organization_units` | `haou` |
| `hr_operating_units` | `hou` |
| `po_headers_all` | `pha` |
| `po_lines_all` | `pla` |
| `po_distributions_all` | `pda` |
| `okc_k_headers_all_b` | `okh` |
| `pjf_projects_all_b` | `ppa` |
| `vrm_source_documents` | `vsd` |
| `vrm_perf_obligation_lines` | `pol` |
| `vrm_perf_obligation_lin_dists` | `pold` |
| `vrm_pol_satisfaction_events` | `pse` |

When in doubt, take the first letter of each word in the table name.

### 4. Bind parameters
- Form: `:p_param_name` — lowercase, snake_case, prefixed with `p_`.
- Names must match exactly between the SQL and the data model `<parameters>` block.
- Common names: `:p_ledger_id`, `:p_period_name`, `:p_date_from`, `:p_date_to`, `:p_bu_id`, `:p_org_id`, `:p_supplier_id`, `:p_customer_id`, `:p_employee_id`, `:p_business_group_id`.

### 5. Multi-select parameter pattern
For menu parameters that accept multiple values, use the Fusion-friendly null-guard + IN pattern:

```sql
AND (:p_ledger_id IS NULL OR gjh.ledger_id IN (:p_ledger_id))
```

This works because BIP passes a comma-separated value list when `multiValue="true"`, and Oracle parses `IN (:p_ledger_id)` as a list expansion at runtime. The `IS NULL` guard makes the parameter optional.

### 6. Date ranges
Default to inclusive `BETWEEN`:
```sql
AND gjh.default_effective_date BETWEEN :p_date_from AND :p_date_to
```

For timestamp columns where you want the full day:
```sql
AND xah.accounting_date >= TRUNC(:p_date_from)
AND xah.accounting_date <  TRUNC(:p_date_to) + 1
```

### 7. Date-effective HCM tables
Tables ending in `_F` or `_M` are date-effective. Always include the effective-date predicate:

```sql
AND TRUNC(SYSDATE) BETWEEN papf.effective_start_date AND papf.effective_end_date
AND TRUNC(SYSDATE) BETWEEN paam.effective_start_date AND paam.effective_end_date
```

If the report needs as-of-date logic, parameterize:
```sql
AND :p_as_of_date BETWEEN papf.effective_start_date AND papf.effective_end_date
```

### 8. Forbidden patterns
- `SELECT *` — always enumerate columns explicitly.
- Implicit data type conversions (e.g., `WHERE numeric_col = '123'`) — use explicit casts.
- Subqueries in `SELECT` lists when a join would do.
- Cartesian joins (any pair of tables in `FROM` without a join predicate connecting them).
- Hard-coded literal IDs in `WHERE` clauses — parameterize.

### 9. Header comment
Every query starts with a one-line comment naming the intent and grain:

```sql
/* AR Invoice Aging — one row per AR transaction line, aged by due date */
SELECT ...
```

For longer comments, use the standard block:
```sql
/*
 * Report: AR Invoice Aging
 * Grain : One row per ra_customer_trx_lines_all line
 * Author: oracle-fusion-bip-generator skill
 * Notes : Aging buckets computed via (TRUNC(SYSDATE) - due_date) ranges.
 *         Multi-org enabled via :p_org_id null-guard.
 */
```

## Common patterns

### Subledger accounting drill-back
To trace journal lines to their subledger source:
```sql
SELECT gjl.je_line_num,
       xah.entity_id,
       xah.application_id,
       xah.event_id,
       xal.accounted_dr,
       xal.accounted_cr
  FROM gl_je_lines       gjl,
       gl_import_references gir,
       xla_ae_headers    xah,
       xla_ae_lines      xal
 WHERE gjl.je_header_id = gir.je_header_id
   AND gjl.je_line_num  = gir.je_line_num
   AND gir.gl_sl_link_id = xal.gl_sl_link_id
   AND gir.gl_sl_link_table = xal.gl_sl_link_table
   AND xal.ae_header_id = xah.ae_header_id
```

### Period range from period name
When the user filters by a period name but you need a date range:
```sql
SELECT gp.start_date, gp.end_date
  FROM gl_periods gp,
       gl_ledgers gl
 WHERE gp.period_set_name = gl.period_set_name
   AND gp.period_name = :p_period_name
   AND gl.ledger_id = :p_ledger_id
```

### Multi-org access
Use the org context table for security-aware queries:
```sql
SELECT aia.invoice_num, aia.invoice_amount
  FROM ap_invoices_all aia
 WHERE aia.org_id IN (
         SELECT organization_id
           FROM mo_glob_org_access_tmp
       )
   AND aia.invoice_date BETWEEN :p_date_from AND :p_date_to
```

### As-of-date HCM snapshot
```sql
SELECT papf.person_number,
       papf.full_name,
       paam.assignment_number,
       paam.position_id
  FROM per_all_people_f      papf,
       per_all_assignments_m paam
 WHERE papf.person_id = paam.person_id
   AND :p_as_of_date BETWEEN papf.effective_start_date AND papf.effective_end_date
   AND :p_as_of_date BETWEEN paam.effective_start_date AND paam.effective_end_date
   AND paam.assignment_status_type IN ('ACTIVE', 'SUSPENDED')
```

### Hierarchical org rollup
Use `CONNECT BY` for org or value-set hierarchies:
```sql
SELECT LEVEL          AS hier_level,
       haou.organization_id,
       haou.name      AS org_name
  FROM hr_all_organization_units haou,
       per_org_hierarchy_elements pohe
 WHERE haou.organization_id = pohe.organization_id_child
   AND pohe.org_hierarchy_id = :p_hierarchy_id
 START WITH pohe.organization_id_parent = :p_top_org_id
 CONNECT BY PRIOR pohe.organization_id_child = pohe.organization_id_parent
```

## LOV query conventions

LOV queries return exactly two columns named `value` and `display`:

```sql
/* LOV: Ledger selector */
SELECT ledger_id  AS value,
       name       AS display
  FROM gl_ledgers_v
 ORDER BY name
```

For LOVs that need a "compound display" (e.g., code + description):
```sql
SELECT lookup_code AS value,
       lookup_code || ' - ' || meaning AS display
  FROM fnd_lookup_values_vl
 WHERE lookup_type = 'INVOICE_TYPE'
   AND enabled_flag = 'Y'
   AND TRUNC(SYSDATE) BETWEEN start_date_active AND NVL(end_date_active, TRUNC(SYSDATE))
 ORDER BY meaning
```

For cascading LOVs (child depends on parent):
```sql
/* LOV: Ledger selector — filtered by selected BU */
SELECT gl.ledger_id  AS value,
       gl.name       AS display
  FROM gl_ledgers_v gl,
       fun_all_business_units_v fabuv
 WHERE gl.ledger_id = fabuv.primary_ledger_id
   AND (:p_bu_id IS NULL OR fabuv.bu_id = :p_bu_id)
 ORDER BY gl.name
```

## Validation expectations

Every query authored by this skill must pass through `hackett-fusion:execute_sql` and return:
1. **No error.** Syntax and binding both valid.
2. **Sensible row count.** Non-zero, or zero with a defensible explanation.
3. **Correct grain.** If the report intent says "one row per invoice" and `COUNT(*)` ≠ `COUNT(DISTINCT invoice_id)`, the grain is broken — fix the joins.
4. **No silent fan-out.** Spot-check distinct counts on the grain key against the total row count when fan-out is plausible (OSS revenue tables, project costing, GL line splits via XLA).

If a query fails validation 5 times in a row, stop and report the specific obstacle to the user rather than guessing further.
