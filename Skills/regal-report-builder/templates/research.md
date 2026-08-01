# Research Trail — {report_short_name}

**Report:** {one-line business question}
**Pillar / module:** {e.g. Financials / Assets}
**Environment researched:** {host} ({environment name}) — fingerprint {release}
**Date:** {YYYY-MM-DD}

---

## Grain

One row per **{grain}**.

Verification:
```sql
SELECT COUNT(*)                    AS total_rows,
       COUNT(DISTINCT {grain_key}) AS distinct_grain
  FROM {object}
 WHERE {predicates}
```
Result: total_rows = {N}, distinct_grain = {N}. {Match / explain the difference.}

---

## Objects used

| Object | Suffix meaning | Book | Confirmed via | Rows in env | Notes |
|---|---|---|---|---|---|
| {object} | {base / translated / date-effective / multi-org} | {OEDMF / OEDMH / OEDSC / OEDPP / OEDMP} | Docs + live | {N} | {note} |

Documentation pages consulted:
- {OBJECT_NAME} — {URL}

---

## Join keys

| From | To | Key | Type | Evidence |
|---|---|---|---|---|
| {a} | {b} | {col} | inner / outer `(+)` | {doc index detail / observed cardinality} |

---

## Mandatory predicates applied

- [ ] Date-effective (`_F` tables): `TRUNC(SYSDATE) BETWEEN effective_start_date AND effective_end_date`
- [ ] Language (`_TL` tables): `language = USERENV('LANG')` — or `_VL` view used instead
- [ ] Org / BU scope (`_ALL` tables)
- [ ] Ledger / book / legislative data group scope

---

## Columns

| Report label | Object.column | Datatype | Source of truth |
|---|---|---|---|
| {label} | {obj}.{col} | {type} | Docs / live result |

---

## Environment observations

- {e.g. "FA_BOOKS populated, 1,204 rows." / "Tax module returns zero rows — not configured in DEV-2."}

---

## Inferred, not confirmed

Anything below is reasoning, not evidence. Confirm before relying on it.

- {inference} — needs {what would confirm it}

---

## Open questions for the client

- {question}
