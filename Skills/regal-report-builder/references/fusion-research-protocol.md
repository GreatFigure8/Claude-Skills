# Fusion Research Protocol

How to establish, with evidence, what you are querying — before you query it.

There are exactly two acceptable sources of truth for an Oracle Fusion object or column:

1. **A live result from the target pod** (via `execute_sql` or `fusion_rest_get`).
2. **Oracle's published Tables and Views documentation** (via `web_fetch`).

Recall is not a third source. Neither is pattern-matching from a similar table, another client, or EBS.

---

## 1. Oracle Tables and Views documentation

### Verified TOC entry points

| Pillar | Book code | TOC URL |
|---|---|---|
| Financials | OEDMF | `https://docs.oracle.com/en/cloud/saas/financials/26c/oedmf/toc.htm` |
| HCM | OEDMH | `https://docs.oracle.com/en/cloud/saas/human-resources/oedmh/toc.htm` |
| SCM & Manufacturing | OEDSC | `https://docs.oracle.com/en/cloud/saas/supply-chain-and-manufacturing/26c/oedsc/toc.htm` |
| Project Management | OEDPP | `https://docs.oracle.com/en/cloud/saas/project-management/26c/oedpp/toc.htm` |
| Procurement | OEDMP | `https://docs.oracle.com/en/cloud/saas/procurement/26c/oedmp/toc.htm` |

All five confirmed reachable. Financials, SCM, PPM, and Procurement are release-pinned in the path (`26c`); HCM's canonical URL carries no release segment, though a release-pinned form also resolves.

### How the books are organized

Each TOC groups by **module**, then splits **Tables** and **Views**. Financials modules include Advanced Collections, Assets, Bill Management, Budgetary Control, Cash Management, Expenses, Financials Common Module, General Ledger, Payables, Receivables, Subledger Accounting, Tax, and more. Each entry links to a per-object page with columns, datatypes, primary key, and index/foreign-key detail.

### Working method

1. Fetch the TOC for the right pillar.
2. Find the module section for your subject area.
3. Fetch the specific object page — do not stop at the TOC. The TOC proves the object exists; only the page tells you its columns.
4. Read: column list, datatypes, nullability, primary key, and the index section (this is where join keys are evidenced).
5. Record the citation. In the research file, write the object name, the pillar book, and what you confirmed.

### Do not construct URLs from memory

Object page URLs carry a numeric suffix (`fabooks-14396.html`) that is not derivable. Reach the page by following a link from the TOC or by searching. A hand-built URL that 404s wastes a turn; one that resolves to the *wrong* object is worse.

### Release skew

If a release-pinned URL 404s, the release has rolled forward. Find the current release by search rather than by incrementing the path speculatively. Prefer the book matching the client pod's release — `identify_environment` fingerprints it.

---

## 2. Live pod confirmation

### Object discovery — use `all_objects`, not `all_tables`

Fusion exposes most application objects to the reporting schema as **synonyms and views**, not base tables. This is the single most common false negative in Fusion SQL research:

```sql
-- WRONG: returns zero rows and looks like the objects don't exist
SELECT table_name
  FROM all_tables
 WHERE table_name LIKE 'GL_%'
```

```sql
-- RIGHT
SELECT object_name,
       object_type
  FROM all_objects
 WHERE object_type IN ('SYNONYM','VIEW','TABLE')
   AND object_name LIKE 'GL_%'
 ORDER BY object_name
```

A zero-row result from `all_tables` proves nothing. Never report "that table doesn't exist" on that basis.

### Column confirmation

```sql
SELECT column_name,
       data_type,
       data_length,
       nullable
  FROM all_tab_columns
 WHERE table_name = 'FA_BOOKS'
 ORDER BY column_id
```

Or inspect the shape directly:

```sql
SELECT *
  FROM fa_books
 WHERE ROWNUM <= 5
```

### Population check

An object can exist and be empty — routine in a DEV pod mid-implementation. State it as a finding:

```sql
SELECT COUNT(*) AS row_count
  FROM fa_books
```

"Object exists, zero rows in DEV-2" is useful information for the client. Silently building a report over an empty table and presenting it as validated is not.

### Seeded vs. customer-configured

For configuration-state work, existence is not the same as configuration. Distinguish Oracle seed data from client-created rows using creation attributes (`created_by`, `creation_date`, seed-source columns) before calling something "configured."

### Cardinality and fan-out

Before committing to a join, prove the grain:

```sql
SELECT COUNT(*)                  AS total_rows,
       COUNT(DISTINCT asset_id)  AS distinct_assets
  FROM fa_books
 WHERE book_type_code = :P_BOOK_TYPE_CODE
```

If the two differ and you expected one row per asset, your grain is wrong. Find out why before proceeding.

---

## 3. Object naming conventions

Fusion suffixes carry meaning. Choosing the wrong variant is a real defect, not a stylistic slip.

| Suffix | Meaning | Consequence for your SQL |
|---|---|---|
| `_B` | Base table | Non-translated attributes live here |
| `_TL` | Translated | Needs a language predicate |
| `_VL` | Translated view | Applies the language filter for you — usually preferred |
| `_ALL` | Multi-org | Needs an org/BU predicate; the runner applies no org context |
| `_F` | Date-effective | **Mandatory** effective-date predicate or rows multiply |
| `_V` | View | Check what it already filters before adding predicates |
| `_INT` / `_INTERFACE` | Load staging | Not a reporting source unless the report is about the load |
| `_GT` | Global temporary | Session-scoped; empty outside its process. Never a report source |

### Date-effective predicate (HCM `_F` tables)

```sql
AND TRUNC(SYSDATE) BETWEEN papf.effective_start_date
                       AND papf.effective_end_date
```

Omitting this is the most common Fusion HCM reporting defect: the query runs, returns rows, looks plausible, and silently returns every historical version of every record.

### Translated table predicate

```sql
AND fat.language = USERENV('LANG')
```

Prefer the `_VL` view where one exists.

---

## 4. What to record

Every report gets a research file. Minimum contents:

```markdown
## Objects used
| Object | Pillar / book | Confirmed via | Notes |
|---|---|---|---|
| fa_books | Financials / OEDMF | Docs + live (1,204 rows, DEV-2) | Asset/book grain |
| fa_additions_b | Financials / OEDMF | Docs + live | Base; description on _TL |

## Join keys
| From | To | Key | Evidence |
|---|---|---|---|
| fa_books | fa_additions_b | asset_id | OEDMF index detail; confirmed 1:1 on data |

## Grain
One row per asset per book. COUNT(*) 1,204 = COUNT(DISTINCT asset_id||book_type_code) 1,204.

## Open questions
- Tax book in scope? Not confirmed with client.
```

---

## 5. Failure modes to name out loud

When one of these occurs, say so plainly rather than working around it silently:

- **Object not found in the pod** — after checking `all_objects`, not `all_tables`.
- **Object exists but is empty** — a statement about the environment, not the query.
- **Join fans out unexpectedly** — the grain assumption was wrong; stop and re-derive it.
- **Docs and pod disagree** — usually release skew or a customization. Report both observations; don't quietly pick one.
- **No documentation page found** — some objects are undocumented. Fall back to live inspection and label the column meanings as inferred from data, not confirmed from docs.
- **Five failed correction attempts** — stop. Describe the specific obstacle.

None of these is embarrassing. Presenting an unverified query as validated is.
