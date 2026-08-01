# Fusion HCM Object Catalog, Predicates & Quirks

Reference for the validation queries. Read before querying. These objects, columns, and quirks
are confirmed against a live Oracle Fusion environment via the Hackett Fusion SQL runner
(BIP `HK_SQL_RUNNER`, `ApplicationDB_FSCM` data source). The runner resolves objects by name
(synonyms/grants under the apps schema); `all_tables`/`all_objects` work for discovery.

## Discovery first — always

Many HCM and ASM objects are exposed as **synonyms or views, not base tables**. Filtering
`all_tables` on, say, `ASM%` returns zero rows even though the objects exist. Discover with:

```sql
SELECT object_type, COUNT(*) FROM all_objects WHERE object_name LIKE 'ASM%' GROUP BY object_type;
-- find a specific object:
SELECT DISTINCT object_name FROM all_objects
 WHERE object_type IN ('SYNONYM','VIEW','TABLE') AND object_name IN ( ... );
-- confirm columns before SELECTing them:
SELECT column_name FROM all_tab_columns WHERE table_name='PER_LEGAL_EMPLOYERS' ORDER BY column_id;
```

On `ORA-00904` (bad column) or `ORA-00942` (bad table), do NOT retry the same guess — re-check
via `all_tab_columns` / `all_objects` and correct.

## Confirmed objects by area

### Enterprise structures
- `PER_LEGISLATIVE_DATA_GROUPS_VL` — `LEGISLATION_CODE`, `NAME`, `DEFAULT_CURRENCY_CODE` (NOT
  `CURRENCY_CODE`).
- `XLE_ENTITY_PROFILES` — legal entities.
- `PER_LEGAL_EMPLOYERS` — `NAME`, `ORGANIZATION_ID`, effective-dated (`EFFECTIVE_START_DATE` /
  `EFFECTIVE_END_DATE`).
- `FUN_ALL_BUSINESS_UNITS_V` — display column is **`BU_NAME`**, not `NAME`.

### Workforce structures
- `PER_DEPARTMENTS` — effective-dated.
- `HR_ALL_ORGANIZATION_UNITS_F`, `HR_ORG_UNIT_CLASSIFICATIONS_F` — org units & classifications.
- `PER_LOCATIONS` — **does NOT have a standard `EFFECTIVE_END_DATE`**. Do not apply the usual
  `TRUNC(SYSDATE) BETWEEN effective_start_date AND effective_end_date` filter here — it errors.
- `PER_JOBS` (and `PER_JOBS_F`) — `NAME`, `JOB_CODE`, effective-dated.
- `HR_ALL_POSITIONS_F` — positions, effective-dated.
- `PER_GRADES` — `NAME`, `GRADE_CODE`, effective-dated.
- `PER_RATES_F` — grade rate rows (this is the grade-rate object; `PER_GRADE_RATES_F` does NOT
  exist by that name).

### Worker population
- `PER_ALL_PEOPLE_F` — persons. `PER_PERSONS` also present.
- `PER_ALL_ASSIGNMENTS_M` — assignments. Profile by `SYSTEM_PERSON_TYPE` (EMP/CWK),
  `ASSIGNMENT_TYPE` (E/ET/C/CT), `ASSIGNMENT_STATUS_TYPE`. A pattern of EMP rows doubling
  (E + ET) is normal (assignment + terms). Tiny counts = config/test data, not a real population.
- `PER_EMAIL_ADDRESSES` — keyed by `PERSON_ID`. Note: consultant/implementation users provisioned
  with **email-format usernames** will NOT have rows here; query `PER_USERS.USERNAME LIKE
  '%@domain.com'` instead to find them.

### Payroll
- `PAY_ALL_PAYROLLS_F` — customer payroll definitions (zero = payroll not configured).
- `PAY_ELEMENT_TYPES_F` / `_VL` — elements. A large count (e.g. 1,800+) is almost entirely
  **seeded statutory elements** from each localization; it is NOT evidence of payroll build.
- `PAY_REL_GROUPS_DN` — payroll relationship groups (seeded statutory rows exist by default).

### Security (expanded audit)
- `PER_ROLES_DN_VL` — role catalog. **Custom vs. seeded**: seeded roles have
  `ROLE_COMMON_NAME LIKE 'ORA\_%' ESCAPE '\'`. Custom client roles do not (often a client prefix
  like `RCW_`/`RGE_`). `CREATED_BY` is unreliable for this split (a single migration/client
  account often owns the whole catalog), so use the name predicate.
- `PER_ROLE_MAPPINGS` — automated role-provisioning rules. A count of ~2 means provisioning is
  barely started.
- Security profiles (person/position/org/payroll/LDG/country) are frequently **not reliably
  queryable** from the reporting account — mark NOT ASSESSED rather than guessing.

### Extended audit (expanded)
- `PER_ACTIONS_B` / `PER_ACTIONS_VL` — actions. **Custom vs. seeded** via `SEED_DATA_SOURCE`
  (seeded rows non-null; custom typically null). All-seeded (e.g. 90/0 custom) means no
  customer actions yet even though workflows may require them.
- `PER_ACTION_REASONS_B` / `_VL` — action reasons; same `SEED_DATA_SOURCE` predicate.
- `CMP_SALARY_BASES` (`_VL`) — salary bases. Validate the two mappings the design calls for:
  - to **LDG** via `LEGISLATIVE_DATA_GROUP_ID IS NOT NULL`
  - to **Grade Rate** via `GRADE_RATE_ID IS NOT NULL OR DEFAULT_GRADE_RATE_ID IS NOT NULL`
  Report bases missing either link by name. `SALARY_BASIS_TYPE`, `NAME`, `SALARY_BASIS_CODE`,
  `GRADE_ANNUALIZATION_FACTOR` are also present. (A common design: 2 types × N LDGs.)
- Flexfields:
  - `FND_DESCRIPTIVE_FLEXS_VL` — DFF registrations (mostly seeded; a large total is not custom
    config).
  - `FND_DESCR_FLEX_COLUMN_USAGES` — **customer-deployed segments**: count
    `ENABLED_FLAG='Y'` AND `CREATED_BY` not in the seed accounts
    (`'SEED_DATA_FROM_APPLICATION','ORACLE','SEEDADMIN'` and not `LIKE 'FUSION%'`). This is the
    real "custom DFF" signal. Columns: `DESCRIPTIVE_FLEXFIELD_NAME`, `DESCRIPTIVE_FLEX_CONTEXT_CODE`,
    `END_USER_COLUMN_NAME`, `ENABLED_FLAG`, `CREATED_BY`, `CREATION_DATE`.

### ASM offerings / FSM feature opt-ins — NOT ASSESSED by default
Offerings/features are modeled as solution bundles + feature choices, exposed as ASM synonyms/
views (`ASM_SOLUTION_BUNDLES_B/_TL`, `ASM_SOLUTION_BUNDLE_SELECTIONS`,
`ASM_CP_FEATURE_CHOICE_FEATURES`, `ASM_CHOICE_ENTERPRISE_APPS`). The *licensed/provisioned*
footprint is readable from `ASM_SOLUTION_BUNDLE_SELECTIONS` joined to bundle names, but the
granular *Configure Offerings* opt-in toggles need careful lookup decode and are error-prone.
Default to NOT ASSESSED unless the user explicitly asks for the opt-in decode.

## Custom-vs-seeded cheat sheet
- Roles → name `ORA_` prefix = seeded.
- Actions / action reasons → `SEED_DATA_SOURCE` non-null = seeded.
- DFF segments → `CREATED_BY` in seed accounts = seeded; human/enabled = custom.
- Elements, payment methods, material statuses, payroll rel groups → assume seeded unless proven.

## Session reliability
The environment binding drops between calls. If a tool returns `environment-not-selected`,
call `select_environment(<id>)` again and re-run. This is expected, not an error in the data.
