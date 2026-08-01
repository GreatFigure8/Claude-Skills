# Common LOV Sources for Oracle Fusion BIP Reports

This is a working catalog of go-to LOV (List of Values) sources organized by domain. When you need a menu parameter, start here before authoring a new lookup query.

## Financials — General Ledger

### Ledger
```sql
SELECT ledger_id AS value,
       name      AS display
  FROM gl_ledgers_v
 ORDER BY name
```

### Ledger Set
```sql
SELECT ledger_id AS value,
       name      AS display
  FROM gl_ledgers
 WHERE object_type_code = 'S'   -- 'S' = Ledger Set, 'L' = Primary Ledger
 ORDER BY name
```

### Period (cascading from Ledger)
```sql
SELECT gp.period_name AS value,
       gp.period_name AS display
  FROM gl_periods gp,
       gl_ledgers  gl
 WHERE gp.period_set_name = gl.period_set_name
   AND (:p_ledger_id IS NULL OR gl.ledger_id = :p_ledger_id)
   AND gp.adjustment_period_flag = 'N'
 ORDER BY gp.start_date DESC
```

### Open Periods Only
```sql
SELECT period_name AS value,
       period_name AS display
  FROM gl_period_statuses
 WHERE application_id = 101                       -- General Ledger
   AND ledger_id = :p_ledger_id
   AND closing_status IN ('O', 'F')               -- Open, Future-Entry
 ORDER BY start_date DESC
```

### Currency
```sql
SELECT currency_code AS value,
       currency_code || ' - ' || name AS display
  FROM fnd_currencies_vl
 WHERE enabled_flag = 'Y'
   AND currency_flag = 'Y'
 ORDER BY currency_code
```

### Journal Source
```sql
SELECT je_source_name AS value,
       user_je_source_name AS display
  FROM gl_je_sources
 ORDER BY user_je_source_name
```

### Journal Category
```sql
SELECT je_category_name AS value,
       user_je_category_name AS display
  FROM gl_je_categories
 ORDER BY user_je_category_name
```

## Financials — Payables

### Supplier
```sql
SELECT vendor_id   AS value,
       vendor_name AS display
  FROM ap_suppliers
 WHERE enabled_flag = 'Y'
 ORDER BY vendor_name
```

### Supplier Site
```sql
SELECT vendor_site_id AS value,
       vendor_site_code AS display
  FROM ap_supplier_sites_all
 WHERE inactive_date IS NULL
   AND (:p_vendor_id IS NULL OR vendor_id = :p_vendor_id)
 ORDER BY vendor_site_code
```

### Invoice Type
```sql
SELECT lookup_code AS value,
       meaning     AS display
  FROM fnd_lookup_values_vl
 WHERE lookup_type = 'INVOICE TYPE'
   AND enabled_flag = 'Y'
   AND TRUNC(SYSDATE) BETWEEN start_date_active AND NVL(end_date_active, TRUNC(SYSDATE))
 ORDER BY meaning
```

### Payment Method
```sql
SELECT payment_method_code AS value,
       payment_method_name AS display
  FROM iby_payment_methods_vl
 WHERE enabled_flag = 'Y'
 ORDER BY payment_method_name
```

## Financials — Receivables

### Customer
```sql
SELECT hca.cust_account_id  AS value,
       hp.party_name         AS display
  FROM hz_cust_accounts hca,
       hz_parties        hp
 WHERE hca.party_id = hp.party_id
   AND hca.status = 'A'
 ORDER BY hp.party_name
```

### Customer Site
```sql
SELECT hcsu.site_use_id     AS value,
       hcsu.location || ' - ' || hps.party_site_number AS display
  FROM hz_cust_site_uses_all hcsu,
       hz_cust_acct_sites_all hcas,
       hz_party_sites          hps
 WHERE hcsu.cust_acct_site_id = hcas.cust_acct_site_id
   AND hcas.party_site_id = hps.party_site_id
   AND hcsu.status = 'A'
   AND (:p_customer_id IS NULL OR hcas.cust_account_id = :p_customer_id)
 ORDER BY hcsu.location
```

### Transaction Type (AR)
```sql
SELECT cust_trx_type_id   AS value,
       name               AS display
  FROM ra_cust_trx_types_all
 WHERE status = 'A'
 ORDER BY name
```

## Financials — General

### Business Unit
```sql
SELECT bu_id    AS value,
       bu_name  AS display
  FROM fun_all_business_units_v
 ORDER BY bu_name
```

### Legal Entity
```sql
SELECT legal_entity_id AS value,
       name            AS display
  FROM xle_entity_profiles
 WHERE effective_to IS NULL OR effective_to >= TRUNC(SYSDATE)
 ORDER BY name
```

### Operating Unit (legacy term in some places)
```sql
SELECT organization_id AS value,
       name            AS display
  FROM hr_operating_units
 ORDER BY name
```

### Inventory Organization
```sql
SELECT organization_id AS value,
       organization_code || ' - ' || organization_name AS display
  FROM inv_organizations_v
 WHERE legal_entity IS NOT NULL
 ORDER BY organization_code
```

## HCM

### Employee (with as-of-date)
```sql
SELECT papf.person_id     AS value,
       papf.person_number || ' - ' || papf.full_name AS display
  FROM per_all_people_f papf
 WHERE TRUNC(SYSDATE) BETWEEN papf.effective_start_date AND papf.effective_end_date
   AND papf.person_type_id IN (
         SELECT person_type_id
           FROM per_person_types
          WHERE system_person_type = 'EMP'
       )
 ORDER BY papf.full_name
```

### Department
```sql
SELECT haou.organization_id AS value,
       haou.name            AS display
  FROM hr_all_organization_units haou
 WHERE haou.classification_code = 'DEPARTMENT'
   AND TRUNC(SYSDATE) BETWEEN haou.date_from AND NVL(haou.date_to, TRUNC(SYSDATE))
 ORDER BY haou.name
```

### Job
```sql
SELECT job_id   AS value,
       name     AS display
  FROM per_jobs_f
 WHERE TRUNC(SYSDATE) BETWEEN effective_start_date AND effective_end_date
 ORDER BY name
```

### Grade
```sql
SELECT grade_id AS value,
       name     AS display
  FROM per_grades_f
 WHERE TRUNC(SYSDATE) BETWEEN effective_start_date AND effective_end_date
 ORDER BY name
```

### Position
```sql
SELECT position_id AS value,
       name        AS display
  FROM hr_all_positions_f
 WHERE TRUNC(SYSDATE) BETWEEN effective_start_date AND effective_end_date
   AND status = 'ACTIVE'
 ORDER BY name
```

### Legal Employer
```sql
SELECT organization_id AS value,
       name            AS display
  FROM hr_legal_employers_f
 WHERE TRUNC(SYSDATE) BETWEEN effective_start_date AND effective_end_date
 ORDER BY name
```

### Person Type
```sql
SELECT person_type_id AS value,
       user_person_type AS display
  FROM per_person_types
 WHERE active_flag = 'Y'
 ORDER BY user_person_type
```

## Procurement

### PO Type
```sql
SELECT lookup_code AS value,
       meaning     AS display
  FROM fnd_lookup_values_vl
 WHERE lookup_type = 'PO_TYPE'
   AND enabled_flag = 'Y'
   AND TRUNC(SYSDATE) BETWEEN start_date_active AND NVL(end_date_active, TRUNC(SYSDATE))
 ORDER BY meaning
```

### Buyer
```sql
SELECT papf.person_id AS value,
       papf.full_name AS display
  FROM per_all_people_f papf,
       po_agents_v       pav
 WHERE papf.person_id = pav.agent_id
   AND TRUNC(SYSDATE) BETWEEN papf.effective_start_date AND papf.effective_end_date
 ORDER BY papf.full_name
```

## Projects

### Project
```sql
SELECT project_id   AS value,
       segment1 || ' - ' || name AS display
  FROM pjf_projects_all_b ppa,
       pjf_projects_all_tl ppt
 WHERE ppa.project_id = ppt.project_id
   AND ppt.language = USERENV('LANG')
   AND ppa.project_status_code IN ('ACTIVE', 'OPEN')
 ORDER BY ppa.segment1
```

### Task
```sql
SELECT task_id    AS value,
       task_number || ' - ' || task_name AS display
  FROM pjf_tasks_v
 WHERE (:p_project_id IS NULL OR project_id = :p_project_id)
 ORDER BY task_number
```

## Subledger Accounting

### Subledger Application
```sql
SELECT application_id AS value,
       application_name AS display
  FROM xla_subledgers x,
       fnd_application_vl f
 WHERE x.application_id = f.application_id
   AND x.subledger_enabled_flag = 'Y'
 ORDER BY application_name
```

### Event Class (per Application)
```sql
SELECT event_class_code AS value,
       name             AS display
  FROM xla_event_classes_vl
 WHERE application_id = :p_application_id
 ORDER BY name
```

## Common — Cross-Domain

### Generic Lookup (FND_LOOKUP_VALUES_VL)
For any custom or seeded lookup type:
```sql
SELECT lookup_code AS value,
       meaning     AS display
  FROM fnd_lookup_values_vl
 WHERE lookup_type = :p_lookup_type
   AND enabled_flag = 'Y'
   AND TRUNC(SYSDATE) BETWEEN start_date_active AND NVL(end_date_active, TRUNC(SYSDATE))
 ORDER BY meaning
```

### Value Set Values
For descriptive flexfield values from a value set:
```sql
SELECT fvv.value_id           AS value,
       fvv.value || ' - ' || fvv.description AS display
  FROM fnd_vs_values_b fvv,
       fnd_vs_value_sets fvvs
 WHERE fvv.value_set_id = fvvs.value_set_id
   AND fvvs.value_set_code = :p_value_set_code
   AND fvv.enabled_flag = 'Y'
   AND TRUNC(SYSDATE) BETWEEN NVL(fvv.start_date_active, TRUNC(SYSDATE))
                          AND NVL(fvv.end_date_active, TRUNC(SYSDATE))
 ORDER BY fvv.value
```

### Yes/No
For boolean-style parameters:
```sql
SELECT lookup_code AS value,
       meaning     AS display
  FROM fnd_lookups
 WHERE lookup_type = 'YES_NO'
 ORDER BY lookup_code DESC
```

## Notes

- LOV queries must return exactly two columns named `value` and `display`. BIP relies on these positional names.
- Use `_VL` views (translation layer views) instead of `_B`/`_TL` direct table joins when available — they handle language fallback automatically.
- Always add `ORDER BY` on the display column for predictable UI behavior.
- For LOVs with thousands of rows, consider adding a search-pattern parameter to the LOV itself rather than returning the full list.
- For cascading LOVs, validate that the child query returns sensible results when the parent is NULL — users may not always pre-select the parent.
