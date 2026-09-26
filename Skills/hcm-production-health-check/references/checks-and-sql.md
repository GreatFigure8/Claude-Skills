# Checks and SQL patterns — Fusion HCM health check

All queries run through the HK_SQL_RUNNER BIP report via `execute_sql`. Every statement below ran live against an HCM pod (26A-era) in September 2026. Column names are exact; if a query errors, probe `all_tab_columns` before changing anything.

## Reusable CTEs

```sql
-- current primary employee assignments
cur_asg AS (
  SELECT asg.person_id, asg.assignment_id, asg.assignment_status_type, asg.assignment_type,
         asg.position_id, asg.job_id, asg.grade_id, asg.location_id, asg.organization_id, asg.legal_entity_id
  FROM per_all_assignments_m asg
  WHERE asg.effective_latest_change='Y' AND asg.primary_flag='Y' AND asg.assignment_type='E'
    AND TRUNC(SYSDATE) BETWEEN asg.effective_start_date AND asg.effective_end_date),
-- assignments with an OPEN assigned payroll
paid AS (
  SELECT DISTINCT rg.assignment_id
  FROM pay_rel_groups_dn rg
  JOIN pay_assigned_payrolls_dn ap ON ap.payroll_term_id = rg.parent_rel_group_id
  WHERE rg.group_type='A'
    AND TRUNC(SYSDATE) BETWEEN rg.start_date AND NVL(rg.end_date,TRUNC(SYSDATE))
    AND TRUNC(SYSDATE) BETWEEN ap.start_date AND NVL(ap.end_date,TRUNC(SYSDATE))),
-- the employee population
real_emp AS (SELECT ca.person_id, ca.assignment_id FROM cur_asg ca JOIN paid p ON p.assignment_id=ca.assignment_id
             WHERE ca.assignment_status_type='ACTIVE'),
-- last termination date per person
pos AS (SELECT person_id, MAX(actual_termination_date) term_date FROM per_periods_of_service GROUP BY person_id)
```

Notes: `PAY_ASSIGNED_PAYROLLS_DN.payroll_term_id` points at the **term** rel group (`group_type='T'`); the assignment rel group's `parent_rel_group_id` is that term. Terminated people keep an open assigned payroll until a final close date is set — that is a finding, not a bug in the join.

## Population and person types
- `per_all_people_f` current rows; `per_person_type_usages_m` → `per_person_types.system_person_type` (EMP, EX_EMP, CWK, PWK, EX_PWK, ORA_CANDIDATE, CONTACT, CANCELED_HIRE).
- Active-no-payroll group: characterise by `pay_rel_groups_dn.legislative_data_group_id` → `per_legislative_data_groups_vl`; expect non-Fusion-paid legislations (Mexico).

## User accounts
- `PER_USERS`: `active_flag`, `suspended` (NULL = N), `hr_terminated`, `person_id` (NULL = service/external/test), `user_guid`.
- Classification order: no person → real employee → active E no payroll → suspended E → C → P → INACTIVE with term_date ≥ today−N → INACTIVE older → person with no current assignment.
- Roles: `PER_USER_ROLES ur (user_id, role_id, active_flag)` → `PER_ROLES_DN_VL (role_id, role_name, role_common_name)`.
- Last login: **not available in the DB** (see SKILL.md §3). Do not present a proxy as last login.

## Role hierarchy (inherited BI Administrator / IT Security Manager)
`ASE_ROLE_VL (role_id, code, role_name, role_type_code, is_seeded)` and `ASE_ROLE_ROLE_MBR (child_role_id, parent_role_id)`.
**Naming is inverted:** `CHILD_ROLE_ID` = the container role, `PARENT_ROLE_ID` = the inherited member. To find every role that contains a target:
```sql
SELECT DISTINCT CONNECT_BY_ROOT m.parent_role_id root_role_id, m.child_role_id container_role_id
FROM ase_role_role_mbr m
START WITH m.parent_role_id IN (SELECT role_id FROM ase_role_vl WHERE code IN ('BIAdministrator','ORA_FND_IT_SECURITY_MANAGER_JOB'))
CONNECT BY NOCYCLE PRIOR m.child_role_id = m.parent_role_id
```
Join containers to `per_roles_dn_vl.role_common_name = ase_role_vl.code` → `per_user_roles` → `per_users`, count DISTINCT user_id by holder class. Seeded `ORA_ASM_APPLICATION_IMPLEMENTATION_CONSULTANT_JOB` contains BIAdministrator.

## SoD
Role-name heuristics that worked: payroll-run = `role_name IN ('Payroll Manager','Payroll Administrator') OR LIKE 'IP Payroll Manager%' / 'IP Payroll Admin%' / 'IP Payroll Process%'`; HR admin = `LIKE '%HR Specialist%' OR '%Human Resource Specialist%' OR '%HR Administrator%'`. Use INTERSECT of user_id sets.

## Security profiles
`PER_PERSON_SECURITY_PROFILES (name, view_all, secure_by_mgr_hierarchy, secure_by_department, secure_by_location, secure_by_legal_employer, secure_by_payroll, secure_by_aor, secure_by_custom_restriction, include_future_persons, enabled_flag, seed_data_source)`. The role→profile assignment table is not exposed through the runner; report profile design only.

## Audit
- `FND_AUDIT_ATTRIBUTES (table_name, column_name, enabled_flag, …)` — count distinct tables enabled; check the sensitive list explicitly.
- `PER_SENSITIVE_DATA_AUDIT (audit_date, …)` — rows since go-live; 0 = PII-view audit never enabled.
- `FND_AUDIT_WEBAPP_AM` exists but is not the on/off switch.

## National identifiers
```sql
nid AS (SELECT n.person_id, n.legislation_code, n.national_identifier_type,
               REGEXP_REPLACE(n.national_identifier_number,'[^0-9A-Za-z]','') nid_norm
        FROM per_national_identifiers n
        WHERE n.person_id NOT IN (<EX_EMP person_ids from person_type_usages>))
```
Group by legislation, type, nid_norm HAVING COUNT(DISTINCT person_id)>1. Placeholders: `000000000, 999999999, 111111111, 123456789` and `^(.)\1+$`. Names for verification: `per_person_names_f` (name_type GLOBAL, latest row), DOB `per_persons.date_of_birth`, creator `per_persons.created_by` (`anonymous` = external career site; loader account = conversion).

## Areas of responsibility
`PER_ASG_RESPONSIBILITIES`: `status` values are `'Active'`/`'Inactive'` (mixed case), `start_date/end_date`, `responsibility_type`, `usage`, `auto_provision_flag`, scope columns (`location_id, organization_id, department_hierarchy_id, organization_hierarchy_id, business_unit_id, legal_entity_id, top_manager_id, payroll_id, country, recruiting_loc_hierarchy_id, recruiting_org_hierarchy_id, bargaining_unit, …`). Coverage: employees whose `location_id`/`organization_id` matches no active AoR of the type held by a current employee (hierarchy scopes not expanded — say so).

## Manager hierarchy
`PER_ASSIGNMENT_SUPERVISORS_F (assignment_id, manager_assignment_id, manager_id, manager_type='LINE_MANAGER')` current rows joined to current active/suspended primary assignments. Cycles via self-join; depth via CONNECT BY NOCYCLE.

## Scheduled processes (ESS)
- Tables are **`fusion_ora_ess.request_history`** and **`fusion_ora_ess.request_property`** (not visible in all_tab_columns; query them directly).
- Columns used: `requestid, name, definition, username, submission, processstart, processend, state, requesttype, error_warning_message, error_warning_detail, absparentid`.
- States: 1 WAIT, 3 RUNNING, 4 COMPLETED, 9 CANCELLED, 10 ERROR, 11 WARNING, 12 SUCCEEDED, 8 EXPIRED, 15 VALIDATION_FAILED, 16 SCHEDULE_ENDED, 17 FINISHED, 18 ERROR_AUTO_RETRY, 19 ERROR_MANUAL_RECOVERY.
- Request types: 1 single, 3 recurring instance, 8 sub-request; use `requesttype IN (1,3,8)` for executions and `=3` alone for "truly scheduled".
- BIP jobs have `definition LIKE '%EssBipJob'`; `request_property` names: `report_url`, `ujobname`, `jobid`, `is_bursting`, `notify_email_when_failed`, `schurl`.
- Job def = `SUBSTR(definition, INSTR(definition,'/',-1)+1)`.
- Seeded CX noise on an HCM-only pod: `UAClickHistory*`, `IndexActiveMetaModelVersionJobDef`, `UpdateRollupsJobDef`, `MaintenanceJobDef`, `ReflectHierarchyChanges`, `SynchronizeLookupValues`, `FndOSCS*` — run as `FUSION_APPS_CRM_ESS_APPID`.
- Bursting reports failing ~100% in 3–5 s = query returns no rows → `NO_DATA_TO_PROCESS` (MOS Doc 1925999.1). Confirm by `catalog_download_object` of the `.xdm` and reading the SQL. Fix = schedule trigger or heartbeat row + notify-on-failure.

## Payroll flows and extracts
- `PAY_FLOW_INSTANCES` (parent, always Completed) → `PAY_FLOW_TASK_INSTANCES.status` is the truth: FUNCTIONAL_ERROR, ERRORED, ROLLEDBACK, INCOMPLETE, EXECUTION_STARTED, NOT_STARTED, SKIPPED, SCHEDULED.
- Names: `PAY_FLOWS_VL.base_flow_name`, `PAY_FLOW_TASKS_VL.base_flow_task_name`.

## Payroll elements
- `PAY_ELEMENT_TYPES_F` has `seed_data_source` (filter `NOT IN ('BULK_SEED_DATA_SCRIPT','ORA_SEED_DATA_SCRIPT')`), `legislation_code IS NULL` for customer elements, `indirect_only_flag`, `creator_type`, `closed_for_entry_flag`, `recalc_event_group_id`, `created_by`, `creation_date`. `parent_base_element_name` is not populated — identify generated elements by name suffix.
- Eligibility `PAY_ELEMENT_LINKS_F (element_type_id, element_link_id, costing_link_flag)`; entries `PAY_ELEMENT_ENTRIES_F (element_type_id, effective_start_date, creator_type)`; balance feeds `PAY_BALANCE_FEEDS_F`.
- Costing `PAY_COST_ALLOCATIONS_F (source_type, source_id)`: `EL` = element link (this is where template costing lives, on the **Results** element's link — evaluate costing on the family), `EE` = element entry override, `ORG`, `ASG`, `PAY`, `PSU`. `costing_link_flag` is **not** the indicator.
- Classification `PAY_ELE_CLASSIFICATIONS_VL.base_classification_name`.
- `FF_FORMULAS_F`: `compile_flag` (Y or NULL), `created_by NOT LIKE 'SEED%'`; it has **no** `seed_data_source`.

## Structures and data quality
`hr_org_unit_classifications_f` (classification_code HCM_LEMP / HCM_PSU / HCM_TRU / FUN_BUSINESS_UNIT / DEPARTMENT / ORA_PER_UNION, status 'A'), `hr_locations_all_f_vl.active_status`, `per_jobs_f_vl`, `per_job_family_f`, `hr_all_positions_f`, `per_grades_f`, `per_grade_ladders_f`, `pay_all_payrolls_f`, `cmp_salary_bases`, `cmp_salary (assignment_id, date_from, date_to)`, `per_email_addresses (email_type='W1')`, `per_person_addr_usages_f (address_type='HOME')`, `per_people_legislative_f.sex`, `per_ethnicities`.

## Approvals
`HRC_TXN_HEADER` has no status; join `HRC_TXN_DATA.status` (DRAFT, PENDING, ABORTED, COMPLETE, …) on `transaction_id`.

## Modules
- Absence: `anc_absence_types_f`, `anc_absence_plans_f`, `anc_per_abs_entries (approval_status_cd)`, `anc_per_plan_enrollment`.
- Recruiting: `irc_requisitions_b (current_phase_id, current_state_id, object_status='ORA_ACTIVE', open_date, filled_date, number_to_hire, hired_count, recruiter_id, hiring_manager_id)` with `irc_phases_tl` / `irc_states_tl` (language='US'); `irc_submissions (current_phase_id, current_state_id, active_flag, discarded_flag, internal_flag, subm_last_modified_date)`; `irc_offers (current_phase_id, current_state_id, move_to_hr_status, hr_processed_date)`. Cast timestamps with `CAST(x AS DATE)` before date arithmetic.
- Help Desk: `svc_service_requests (status_cd, creation_date)` — HRHD custom status codes; open = not CLOSED/RESOLVED.
- Journeys: `per_allocated_checklists (checklist_status, checklist_name)`, `per_allocated_tasks (status, target_end_date)`.
- Documents: `hr_documents_of_record` + `hr_document_types_vl`. Talent: `hrt_profiles_b (profile_usage_code='P')`, `hrg_goals`. Comp: `cmp_plans_b`. Benefits `ben_pl_f`. Learning `wlf_learning_items_f`. T&L `hwm_tm_rec`. Seniority `per_seniority_dates_f`. Cards `pay_dir_cards_f`.

## Table growth
`pay_run_results`, `pay_run_result_values`, `pay_element_entries_f`, `pay_cost_allocations_f`, `hrc_dl_data_sets`, `hrc_txn_header`, `fusion_ora_ess.request_history`. Purge jobs: `request_history` where `UPPER(name) LIKE '%PURGE%'` since go-live.
