RUN_DATE = '12 September 2026'

SEV = {'Critical': '#F4900C', 'High': '#184389', 'Medium': '#235CE8', 'Low': '#7A8E9E'}

FINDINGS = [
 dict(id='F01', severity='Critical', domain='Security & access', title='Terminated people still hold active, unsuspended user accounts', metric='3,609', metricLabel='accounts',
  evidence='3,609 accounts belong to people whose employment ended more than 30 days ago (past the agreed 30-day grace period) and are still Active and not Suspended. Every one still carries live roles (up to 36) and none has HR_TERMINATED set. 2,656 of the accounts were already open for leavers at go-live conversion; 953 belong to people terminated since go-live (569 in the last 31–90 days, 343 at 91–180 days, 41 older). 442 of them still hold IP Line Manager and IP Hiring Manager, 66 hold IP Payroll Field Time Administrator and 38 hold IP Payroll Finance. A further 546 people terminated within the last 30 days are already suspended, which shows the leaver process works when it fires.',
  impact='An active account authenticates if the identity provider still permits it, receives approval tasks, appears in worklists and counts against licensed users. Manager and payroll roles on leavers are a direct segregation-of-duties and pay-data exposure. Oracle expects termination to suspend the account automatically when the enterprise option User Account Maintenance is set to Both or Suspend, and the 2,656 converted leaver accounts show that rule was never applied at conversion.',
  actions=['Confirm Manage Enterprise HCM Information > User Account Maintenance is Both or Suspend, and that Send Pending LDAP Requests runs daily (its child job has thrown NullPointerExceptions nine times since July).', 'Bulk-suspend the 2,656 converted leaver accounts via HDL User object (Suspended = Y) after confirming none are rehire candidates.', 'Work the 953 post-go-live leavers as an incident: suspend now, then trace why the termination flow did not fire for them.', 'Add a monthly reconciliation of Active accounts vs Active assignments to the security operations calendar and report the 30-day-grace exceptions.'],
  effort='Low to fix, medium to reconcile', owner='HRIS security lead', reference='Oracle Securing HCM: User and Role Provisioning Setup — User Account Maintenance; Send Pending LDAP Requests'),
 dict(id='F02', severity='Critical', domain='Security & access', title='Seeded BI Administrator inherited by 479 users through recruiter and HR data roles', metric='479', metricLabel='users',
  evidence='The seeded application role BIAdministrator (BI Administrator Role) is a member of two custom job roles, IP_IRC_RECRUITER_JOB_CUSTOM and IP_PER_HUMAN_RESOURCE_ORG_MANAGEMENT_JOB_CUSTOM, as well as the intended IP_BI_ADMINISTRATOR. Through the data roles built on those job roles (IP Recruiter – View by Location 302 users, IP HR Co-ordinator Recruitment – View by Location 177, IP HRBP Recruitment – View by Location 109, View All Req 50, and six others) it reaches 479 distinct active users: 339 Fusion-paid employees, 53 terminated people, 38 contractors, 34 non-Fusion-paid employees and 12 non-person accounts. Only 12 accounts hold IP BI Administrator directly.',
  impact='BI Administrator grants unrestricted access to every BI Publisher and OTBI object in the tenant, including payroll, compensation and national identifier data models, bypassing the location- and organization-based data security those recruiter roles were built to enforce. It also allows catalog changes and scheduler administration. Oracle documents BIAdministrator as an administrative role to be granted to a handful of named people.',
  actions=['Remove BIAdministrator from IP_IRC_RECRUITER_JOB_CUSTOM and IP_PER_HUMAN_RESOURCE_ORG_MANAGEMENT_JOB_CUSTOM in Security Console; replace with BIConsumer (and BIAuthor only where report authoring is a documented duty).', 'Regenerate the ten dependent data roles and run Retrieve Latest LDAP Changes.', 'Keep IP BI Administrator to named report developers; review the 12 direct grants (6 are Hackett or unlinked accounts) and time-box consultant access.', 'Add “role contains BIAdministrator / IT Security Manager” to the quarterly access review as an automated check against ASE_ROLE_ROLE_MBR.'],
  effort='Low', owner='HRIS security lead / CISO', reference='Oracle Securing HCM: BI Administrator, BI Author and BI Consumer roles; Security Console — Copy and edit roles'),
 dict(id='F03', severity='Critical', domain='Scheduled processes & reports', title='Integration status notifications fail every hour by design and nobody is told', metric='5,588', metricLabel='errors / 90d',
  evidence='Three BI Publisher jobs owned by IP_PROC_SCHEDULER run hourly against /Custom/Human Capital Management/Integrations/Status_Notification: “Scheduled Integration BI (Only GL) Report Status” errored 1,902 of 1,905 runs, “Scheduled Integration BI Report Status” 1,898 of 1,905 and “Scheduled Integration Status” 1,788 of 1,906. Together they are 49% of all scheduled-process errors in the last 90 days. The underlying data model is an exception-only query; when there is nothing to report it returns zero rows, the bursting engine raises NO_DATA_TO_PROCESS and the job is recorded as an error. Failure notification is switched off on all three jobs. The same pattern fails IP Grade Exception Alert (80 of 80), Grievance Action Plan Notification (79 of 79), the WFH flag notification (11 of 11) and the SOC salaried direct-report notification.',
  impact='The reports are behaving exactly as built, so their history is useless as a monitor: a genuine failure of the notification itself is indistinguishable from a quiet hour. The 5,600 red rows also bury the real failures listed elsewhere in this register and each hourly run executes correlated sub-queries against the ESS request history tables. Oracle documents this behaviour: a BI-type ESS job whose bursting query returns no data ends in Error.',
  actions=['Add a schedule trigger to each data model (Event Triggers > Schedule) that returns a row only when there is something to send; BI Publisher then records the run as Skipped instead of Error (Oracle Doc 1925999.1 and the BIP data-model guide).', 'Alternatively return a single “no exceptions” row and burst it to the support mailbox so every hour produces a verifiable heartbeat.', 'Turn on notify-on-failure for the five notification jobs so a real failure reaches a monitored inbox.', 'Move the ownership of the Grievance Action Plan schedule off a consultant’s personal account to the process-scheduler service account.'],
  effort='Low', owner='HCM technical lead', reference='My Oracle Support Doc 1925999.1 — ESS Job fails when the BI Publisher bursting SQL returns no data; Oracle BI Publisher Data Modeling Guide — Adding Event Triggers (schedule trigger)'),
 dict(id='F04', severity='High', domain='Integrations & payroll flows', title='Assignment payroll-process-group load fails on every run', metric='2,159', metricLabel='task errors / 90d',
  evidence='The flow GENERATE AND LOAD ASSIGNMENT PPG DATA ends its ORA_PAY_HDL_LOAD task in FUNCTIONAL_ERROR 2,159 times in 90 days, most recently on the run date; the parent flow instance still shows Completed, which is why it has not been noticed. It is 90% of all functional errors across the 47 affected flows. Inbound HDL flows follow the same pattern: IP_SEDGWICKLOA_INBOUND_FILE_FLOW 63 errors, IP_EMPOWER_DEFERRAL 13, IP_ALIGHT_PENSION_INB_V2 13, IP_EMPOWER_LOAN_FEEDBACK 13, IP_BLACK_BAUD_INBOUND_LOAD 10, IP SIRVA PAYROLL ADJUSTMENTS 13, GENERATE AND LOAD ASSIGNED PAYROLL FINC DATA 5. On the outbound side the Empower 401K and RMSP extracts errored 19 times and IP_Financial_Finesse_INT043 4 times.',
  impact='If the PPG load is not landing, workers are not being placed in the right payroll process groups and can be omitted from, or wrongly included in, payroll runs. Failed inbound loads mean leave (Sedgwick), 401(k) deferral and loan (Empower), pension (Alight) and giving (Blackbaud) data is not reaching pay. Because the flow parent reports Completed, none of this appears on the Payroll Flow dashboard as a failure.',
  actions=['Open the latest GENERATE AND LOAD ASSIGNMENT PPG DATA instance, read the HDL data-set error messages (Data Exchange > Import and Load Data) and fix the source rule; confirm one clean run before re-enabling the schedule.', 'Do the same for each inbound flow above; most HDL functional errors are a small number of repeating record-level rejects that can be corrected at source.', 'Change monitoring to read PAY_FLOW_TASK_INSTANCES (child task status), not the parent instance status.', 'Delete or stop IP_SDWK_TEST_DNU, a test flow that ran and failed four times in production.'],
  effort='Medium', owner='Payroll technical lead / Integration lead', reference='Oracle Administering Payroll Flows — Flow task statuses; HCM Data Loader — Data Set error handling'),
 dict(id='F05', severity='High', domain='Security & access', title='Privileged and implementation-grade roles held by contractors and unlinked accounts', metric='32', metricLabel='privileged grants',
  evidence='IT Security Manager is held by 12 accounts: 6 International Paper employees, 4 contractor accounts and 2 non-person accounts (the process-scheduler service account and a SCIM client). IP BI Administrator is held by 12: 5 employees, 6 contractor accounts and 1 non-person account. Application Implementation Consultant is held by 8 accounts. 248 active accounts have no person behind them, including 7 vendor logins, 12 consultant logins, 1 personal email address, 4 test accounts and a duplicate administrator account for a named employee.',
  impact='IT Security Manager can create roles and reset any password; Application Implementation Consultant carries full setup access to every offering and should not persist after go-live. Non-person accounts sit outside the joiner-mover-leaver process, are never suspended by termination, and in the case of consultant and vendor logins outlive the engagement unless someone remembers to remove them.',
  actions=['Reduce IT Security Manager to three or four named IP employees; remove it from the scheduler service account and the SCIM client (they do not need it to run jobs).', 'Remove Application Implementation Consultant from all eight accounts; use a break-glass account under change control.', 'Inventory the 248 non-person accounts with an owner and an expiry date each; disable the test and personal-email accounts now.', 'Time-box all consultant and vendor accounts to the engagement end date.'],
  effort='Low', owner='CISO / HRIS security lead', reference='Oracle Securing HCM — Predefined roles for implementation versus production; Security Console user management'),
 dict(id='F06', severity='High', domain='Approvals & transactions', title='Transactions stalled in approval and thousands of stale drafts', metric='210', metricLabel='pending > 30 days',
  evidence='272 HCM transactions are Pending; 210 of them (77%) were created more than 30 days ago and 165 more than 90 days ago, the oldest dating from go-live. 3,905 transactions sit in Draft, 2,632 of them older than 90 days, and 337 are Aborted. 42 show Complete in the transaction data while the header has not closed.',
  impact='A pending transaction blocks further changes to the affected worker and holds effective-dated records open past payroll cut-off. Drafts older than 90 days are almost never completed and clutter every manager’s task list. Aborted transactions usually mean an approval rule threw an error and the change was silently lost.',
  actions=['Work the 210 in Transaction Console: complete or terminate each, and record the approval rule that caused the stall.', 'Set BPM escalation and expiry on the HR approval tasks (for example escalate at 7 days, expire at 21).', 'Purge drafts older than 90 days quarterly, with a 60-day warning notification to the initiator.', 'Review the 337 aborted transactions for a common rule failure.'],
  effort='Medium', owner='HR operations + BPM administrator', reference='Oracle Implementing Global HR — Transaction Console; BPM Worklist — task escalation and expiration policies'),
 dict(id='F07', severity='High', domain='Absence', title='Absence Management is configured but barely used, and a third of entries are stuck', metric='126', metricLabel='awaiting approval',
  evidence='19 absence types, 19 plans and 1,607 plan enrolments exist, and 25,357 accounts carry the IP Absence Employee SS role, but only 332 absence entries were recorded in the last 12 months across 25,467 paid employees; 126 entries are in Awaiting status. Leave data instead arrives through the Sedgwick inbound HDL flow, which has errored 63 times in 90 days (F04).',
  impact='Either absence is being tracked outside Fusion, in which case the plans and accrual balances are wrong and misleading, or adoption has stalled and employees are waiting weeks for approvals that route to the wrong person. Both leave the 19 plans as dead configuration that still costs maintenance at each quarterly update.',
  actions=['Confirm the intended system of record for absence with HR; if Fusion, fix manager routing first and relaunch.', 'Clear the 126 awaiting entries and enable auto-approval for entry types that do not need manager sign-off.', 'If absence lives in Sedgwick, end-date the unused plans and remove the SS role from the employee provisioning rule.'],
  effort='Medium', owner='HR policy owner', reference='Oracle Implementing Absence Management — Absence approval rules; Evaluate Absences process'),
 dict(id='F08', severity='High', domain='Integrations & payroll flows', title='Hundreds of QuickPay and payroll flows left open or rolled back', metric='605', metricLabel='open QuickPay tasks',
  evidence='QUICK_PAY_ONLY has 493 View SOE tasks in Execution Started and 112 in Incomplete, plus 106 Calculate QuickPay tasks rolled back and 4 errored, in 90 days. Core flows show 34 PAYROLL_RUN, 28 CHECK_PAYMENT, 27 RETROACTIVE_PAY, 26 ELECTRONIC_PAYMENT and 20 PREPAYMENTS rollbacks. Periodic Payroll Activity Report ended in functional error 28 times, Element Result Report errored 17 times and Payslip 7. Formula compilation errored 23 times (21 single, 1 bulk, 1 definition) and JCostingJob 5 times in 30 days.',
  impact='Open QuickPay flows keep locks on the person and appear as in-progress on every payroll checklist; repeated rollbacks of prepayments and payments are usually reruns after a data fix and each one is a manual intervention that should be traceable. A formula that fails to compile keeps running on its previous compiled version, so pay logic can silently lag a change.',
  actions=['Close or roll back the 605 open QuickPay flows through the Payroll Flow checklist and coach payroll users to complete the View SOE step.', 'Review the 21 single-formula compile errors; run Compile Formula in bulk after every quarterly update and treat any error as a release blocker.', 'Log every rollback with a reason on the payroll calendar so the pattern can be attributed (data fix, retro, timing).'],
  effort='Medium', owner='Payroll operations lead', reference='Oracle Administering Global Payroll — QuickPay flows; Administering Fast Formulas — Compile Formula'),
 dict(id='F09', severity='Medium', domain='Scheduled processes & reports', title='Payroll balancing and remittance reports fail for many submitters, and one schedule points at a deleted report', metric='44', metricLabel='reports with errors',
  evidence='Excluding the notification jobs in F03, 44 distinct BI Publisher reports errored in 90 days. Accounting Balancing Report failed 69 of 634 runs across 37 different submitters (20 were delivery errors); Union Dues Remittance Report 30 of 87 (8 submitters); IP Empower Validation Report 21 of 164, all submitted by an external vendor account; Worker Basic Detail Report 13 of 391; HDL Summary Report 10 delivery failures; Labor Distribution Report 6 delivery failures across 95 submitters. A weekly schedule (job 5060) has failed 11 times because its target /Custom/…/Core HR_Ref_Roles/Worker Basic Detail Report.xdo no longer exists. Payroll Configuration Workbook and other reports are being scheduled from consultants’ personal folders in production.',
  impact='Payroll staff are re-running balancing reports several times to get output, which is lost time at every pay cycle and a sign the reports time out or hit parameter combinations that return no data. Personal-folder reports disappear when the consultant’s account is removed, and an external account submitting payroll validation reports is an access-review finding in its own right.',
  actions=['Profile the Accounting Balancing and Union Dues data models for run time and parameter validation; add a “no data” message rather than failing.', 'Delete orphaned schedule 5060 (or repoint it) and search the scheduler for any other job whose report path no longer resolves.', 'Move all production schedules to /Custom and to IP_PROC_SCHEDULER; block scheduling from personal folders by policy.', 'Convert the vendor-submitted validation reports to an IP-owned schedule with the vendor as an email recipient only.'],
  effort='Medium', owner='HCM reporting lead', reference='Oracle BI Publisher — Scheduling reports and delivery; Report job diagnostics'),
 dict(id='F10', severity='Medium', domain='Scheduled processes & reports', title='Seeded CX search and click-history jobs run and fail on an HCM-only tenant', metric='5,340', metricLabel='errors / 90d',
  evidence='crm_click_history_mapping_hourly fails every hour (1,906 of 1,906) with “System error during request pre-processing”; IndexActiveMetaModelVersionJobDef and UpdateRollupsJobDef fail 1,470 of 1,905 each with “Permission denied to execute the request” (last success 13 July); MaintenanceJobDef, ReflectHierarchyChanges, SynchronizeLookupValues and three daily click-history jobs follow the same pattern. All run as FUSION_APPS_CRM_ESS_APPID. FndOSCSBulkIngestJob has also reported “Search Extension Profile Option Not Enabled” 23 times.',
  impact='These are Oracle-owned processes for CX Sales and Oracle Search that have no function in an HCM-only pod. They add roughly 60 red rows a day to the Scheduled Processes console and generate a permission error that looks like a security problem in any log review.',
  actions=['Raise a service request with Oracle asking to disable or reschedule the CRM elastic-search and click-history jobs for this tenant and to confirm the Search Extension profile option state.', 'Until then, filter the console view by product = HCM/Payroll for daily monitoring.'],
  effort='Low', owner='HCM technical lead', reference='Oracle Cloud Applications — Scheduled Processes; Oracle Search Cloud Service enablement (Search Extension profile)'),
 dict(id='F11', severity='Medium', domain='Security & access', title='Terminated accounts keep employee, manager and payroll roles instead of the Ex-Employee role', metric='2,369', metricLabel='leavers with IP Employee',
  evidence='Of the 3,609 open leaver accounts, 2,369 still hold IP Employee, IP Absence Employee SS, IP Next Gen Help Desk User and IP Digital Assistant Access – Employee, while only 737 were moved to the intended IP Ex-Employee role. 442 keep IP Line Manager and IP Hiring Manager Custom, 44 IP Recruiter – View by Location, 28 IP HRBP View by Location and 27 IP HR Grievance Representative. 140 active, unsuspended accounts carry no role at all. 11 custom roles are active but granted to nobody.',
  impact='Role provisioning rules are not deprovisioning on termination, so leavers retain manager approval authority and recruiter data access until someone suspends the account. Roleless accounts are usually failed autoprovisioning and generate help-desk tickets.',
  actions=['Review the role mapping conditions for IP Employee, IP Line Manager and the recruiter data roles; each should require an Active assignment status so autoprovisioning removes them at termination.', 'Run Autoprovision Roles for All Users after the mapping change and reconcile the 140 roleless accounts.', 'Inactivate the 11 unassigned custom roles or document why they exist.'],
  effort='Low', owner='HRIS security lead', reference='Oracle Securing HCM — Role mappings and autoprovisioning; Autoprovision Roles for All Users'),
 dict(id='F12', severity='Medium', domain='Workforce structures', title='Idle departments, jobs, grades and vacant positions accumulating', metric='2,088', metricLabel='idle structures',
  evidence='536 of 7,839 active departments (7%) have no active or suspended worker; 427 of 1,353 active jobs (32%) and 1,109 of 4,501 active grades (25%) are unused; 16 active locations have no worker; 7,635 of 35,236 active positions (22%) are vacant. Position management is fully enforced: no paid employee is without a position, job, grade, location or department.',
  impact='Idle structures surface in every list of values and in Recruiting requisition setup, slow HDL loads and let users pick the wrong value. A third of jobs unused eight months after go-live usually means legacy job codes were converted wholesale rather than rationalised.',
  actions=['Inactivate departments and jobs with no assignment since go-live; keep the record, change the status.', 'Review vacant positions older than 12 months against the headcount plan and close them.', 'Adopt a quarterly structure-hygiene report as a standing HRIS task.'],
  effort='Medium', owner='HRIS / Workforce planning', reference='Oracle Implementing Global HR — Workforce structures status and inactivation'),
 dict(id='F13', severity='Medium', domain='Worker data', title='Terminated employees keep open assigned payrolls', metric='6,685', metricLabel='terminated with open payroll',
  evidence='6,685 people with an inactive (terminated) primary assignment still have an assigned payroll with no end date on the run date. A further 399 suspended assignments (leave) have active payroll, which is expected. The count of terminated people with an open payroll is roughly one in six of all leavers.',
  impact='An assigned payroll that is never end-dated keeps the leaver in the payroll relationship population, so they are picked up by payroll runs, retro processing and year-end until the final close date is set. Oracle defaults the final close date to end-of-time on termination unless the payroll administrator sets it.',
  actions=['Set the final close date on the 6,685 relationships (HDL AssignedPayroll or the Payroll Relationship page) to the last pay date plus the required retro window.', 'Add final-close-date to the termination checklist and to the termination HDL feed from the source system.'],
  effort='Medium', owner='Payroll administration', reference='Oracle Administering Global Payroll — Payroll relationship dates: last standard earnings date, last standard process date and final close date'),
 dict(id='F14', severity='Low', domain='Worker data', title='Diversity and future-dated data gaps', metric='348', metricLabel='no gender',
  evidence='Among the 25,467 paid employees, 348 have no gender recorded and 1,206 US employees have no ethnicity; 264 employee assignment rows are dated in the future. Two employees lack a work email and one lacks a line manager; no paid employee lacks a date of birth, home address, salary record or user account.',
  impact='Missing gender and ethnicity affect EEO-1 and pay-equity reporting. Future-dated rows are legitimate but should be reviewed before each payroll cut-off so a future transfer is not paid early.',
  actions=['Run an employee self-service campaign for gender and ethnicity, with HR completing from I-9 documentation where self-identification is declined.', 'Add future-dated changes to the pre-payroll checklist.'],
  effort='Low', owner='HR operations', reference='Oracle Using Global HR — Person legislative information; EEO-1 reporting'),
 dict(id='F15', severity='Low', domain='Security & access', title='Last-login dates are not captured in the tenant, so 30-day inactivity cannot be measured', metric='0', metricLabel='login records',
  evidence='The tables Oracle uses for sign-in tracking (ASE_USER_LOGIN_INFO, ZCA_BI_USER_LOGIN_ACTIVITY, FFS_USER) contain no rows, and the SCIM user API is not permitted to the service account. The requested list of non-employee accounts with no login in 30 days therefore cannot be produced from the database; the 13,375 non-employee accounts are listed by category instead.',
  impact='Without last-login data, dormant accounts (especially the 248 non-person and 103 contractor accounts) cannot be identified for removal, and licence true-up relies on account counts rather than usage.',
  actions=['Export the sign-in audit from the Oracle Identity domain (or Security Console > User Login History) and join it to the non-employee account list supplied with this report.', 'Enable the ASE user login tracking process if available on this release, so future health checks can read last-login directly.'],
  effort='Low', owner='HRIS security lead / IAM', reference='Oracle Securing HCM — Security Console audit; Oracle Identity Cloud Service audit events'),
 dict(id='F16', severity='Medium', domain='Payroll configuration', title='Element catalog carries 236 unused elements, 55 without eligibility and 24 used earnings that are not costed', metric='236', metricLabel='unused elements',
  evidence='Of 2,275 non-seeded elements, 605 are user-facing (the rest are template-generated Results, Retro, Calculator and Distributor elements). 236 of the 605 have had no element entry since go-live: 81 of 100 Absence elements, 55 of 139 Supplemental Earnings, 28 of 36 Involuntary Deductions, 20 of 100 Voluntary Deductions, 12 Employer Charges, 9 Standard Earnings. 55 have no element eligibility at all (27 involuntary, 20 absence, 4 voluntary, 3 supplemental, 1 balance-initialisation). Costing is correctly defined on the Results element eligibility, but 22 in-use Supplemental Earnings “Premium Adjustment” elements, the RSA HSP employer charge and the DP CDH Plus ImpIn Hrly taxable benefit have no costing; the seven non-US regular-salary elements are uncosted, which is expected as they are paid outside Fusion. Retro event groups are absent on 31 supplemental, 16 standard-earnings and 63 voluntary-deduction elements. 50 user-facing elements have been created since go-live, 36 of them by Hackett consultant accounts, the latest on 11 September 2026.',
  impact='Unused and ineligible elements clutter every element-entry and QuickPay list of values and survive each quarterly update as maintenance debt. In-use earnings without costing post to the suspense or default account and have to be reclassified in GL. Elements without a retro event group are silently excluded from retroactive pay when a rate or hours change is backdated. Elements created in production by consultants outside a release window are a change-control finding.',
  actions=['End-date the 236 unused elements (or document why each is held in reserve) and delete the 55 with no eligibility if they were never linked.', 'Add costing to the 22 Premium Adjustment elements, RSA HSP and DP CDH Plus ImpIn Hrly, mirroring their parent earnings.', 'Review the retro event group on the 110 elements without one against the retro policy; backdated rate changes on those elements will not recalculate.', 'Put element creation under change control: elements are created in a non-production environment and migrated with Functional Setup Manager, not created directly in production.'],
  effort='Medium', owner='Payroll configuration lead', reference='Oracle Implementing Global Payroll — Element eligibility and costing; Retroactive Pay — Recalculation event groups; Migrating setup data with FSM'),
 dict(id='F17', severity='Low', domain='Payroll configuration', title='Time-based earnings are costed per element entry — 7.8 million cost rows since go-live', metric='7.8M', metricLabel='entry-level cost rows',
  evidence='8.4 million Standard Earnings element entries have been created since go-live across 118 elements, loaded by HDL from the time systems. 7.78 million of them carry their own cost allocation at element-entry level (Regular Hours 4.65M, Overtime x 1.5 2.36M, Meal Paid 282k, Overtime 1.5 over 40 191k, Vacation Hours 68k, Holiday 67k, Daily Vacation 29k), plus 83k on the Sick Leave Balance – TSA information element. Element-entry costing overrides the department, position and element costing for that entry.',
  impact='This is a legitimate design for labour distribution from a time system, but it means the costing hierarchy in Fusion is not the source of truth for most earnings — the time system is. Volume of this size affects costing run time, the Payroll Costing Results extract, and any correction that has to be made in Fusion rather than upstream. It also explains the 95-submitter Labor Distribution Report load (F09).',
  actions=['Confirm with Finance that entry-level costing from Workbrain/WFS is the intended design and document the override precedence in the costing design record.', 'Check whether the information element Sick Leave Balance – TSA needs cost segments at all; if not, stop sending them.', 'Include entry-level cost-row volume in the payroll archive and purge planning.'],
  effort='Low', owner='Payroll technical lead + Finance', reference='Oracle Implementing Global Payroll — Costing levels and override precedence (element entry, assignment, department, element eligibility, payroll)'),
 dict(id='F18', severity='High', domain='Recruiting', title='75,698 job applications sit unreviewed and 337 offers are stuck in background check', metric='75,698', metricLabel='unreviewed applications',
  evidence='On requisitions that are still open, 75,698 active job applications are in New / To be Reviewed and 57,659 of them have not been touched in 30 days; a further 2,148 are Reviewed but not dispositioned. Further down the funnel, 1,209 candidates are waiting for a phone screen to be scheduled (839 idle over 30 days), 378 for an interview to be scheduled (190 idle) and 122 are Selected for Offer with no offer created (102 idle). On the offer side (offers created since go-live): 337 are in Background Check / Initiated (77 idle over 30 days), 30 are Accepted but not moved to HR (19 idle), 21 are Approved but not extended (16 idle), 43 are Draft (22 idle). Internal offers handed to HR are not completing: 182 in HR / Processing in Progress (67 idle), 69 in HR / Pending Manual Processing (51 idle) and 16 in HR / Error During Processing.',
  impact='Unreviewed applicants never receive a disposition, which is a candidate-experience and EEO/OFCCP record-keeping problem, and the volume makes the recruiter workbench unusable. Offers stuck in background check point to the Sterling integration or to a step nobody owns. Internal offers stuck in HR processing mean the transfer or promotion has been accepted but the assignment change has not happened; those people are being paid and managed on the old assignment.',
  actions=['Bulk-disposition applications older than 60 days on expired and filled requisitions with a templated candidate notification; agree a review SLA for new applications.', 'Work the 337 background-check offers with Sterling: identify which have results returned but not synced versus never initiated.', 'Clear the 267 internal offers in HR processing and the 16 in error; the error state usually means a validation on the assignment change (position, grade, manager) that HR must correct.', 'Add pipeline-age alerts (application untouched 30 days, offer accepted not moved 7 days) to the recruiting operations dashboard.'],
  effort='Medium', owner='Talent acquisition lead + HR operations', reference='Oracle Implementing Recruiting — Candidate selection process phases and states; Move to HR and offer processing; Background check partner integration'),
 dict(id='F19', severity='Medium', domain='Recruiting', title='Requisition hygiene: expired postings, filled requisitions left open, approved requisitions never posted', metric='1,485', metricLabel='open requisitions',
  evidence='1,485 requisitions are in the Open phase: 625 with an Expired posting (347 open more than 90 days, 91 with no active applicants), 498 Posted, 153 Unposted where the hired count already equals the openings (375 of 375) but the requisition was never filled or closed, 132 approved but Not Posted with an average age of 192 days, 75 Suspended (42 over 180 days) and 2 Scheduled. Every open requisition has a recruiter and a hiring manager. 3,660 requisitions have been created since go-live and 1,543 have been filled; 411 are deleted.',
  impact='Expired and never-posted requisitions distort open-headcount reporting and the vacancy count against the 7,635 vacant positions. Filled requisitions left open keep candidates in the pipeline and block the position from being reused. Automatic fill is available in the requisition template and does not appear to be enabled.',
  actions=['Enable Automatic Fill on the requisition templates so a requisition closes when hired count reaches openings; close the 153 already at target.', 'Review the 625 expired postings with hiring managers: repost, cancel, or fill; start with the 91 that have no active applicants.', 'Set a posting-expiry and unposted-requisition alert and add requisition age to the weekly TA review.'],
  effort='Low', owner='Talent acquisition lead', reference='Oracle Implementing Recruiting — Requisition lifecycle and automatic fill; Job posting expiry'),
 dict(id='F20', severity='Medium', domain='Recruiting', title='Current employees are being created as external candidates', metric='55', metricLabel='duplicate candidates',
  evidence='55 active employees also exist as a separate Recruiting candidate record with the same national identifier, name and date of birth; 50 of the candidate records were created by the external career site between January and August 2026, 5 came in on the candidate conversion, 1 was created by the employee. These are candidate duplicates, not duplicate employees, but if any is hired through Recruiting a second employee record will be created.',
  impact='The candidate duplicate check is not matching external applicants to existing employees, and employees are reaching the external site instead of the internal one. Hiring a duplicate candidate creates a second person with the same SSN.',
  actions=['Confirm candidate duplicate-check settings (national identifier, name and date of birth) for external applications and enable the check at offer creation if it is off.', 'Merge or withdraw the 55 candidate records; verify the two flagged pairs individually.', 'Point internal navigation to the internal career site and add an employee-match warning to the external apply flow.'],
  effort='Low', owner='Talent acquisition lead', reference='Oracle Implementing Recruiting — Candidate duplicate check and merge; Internal candidate experience'),
 dict(id='F21', severity='High', domain='Security & access', title='1,312 active areas of responsibility are held by terminated people, and coverage gaps exist at 56–148 locations', metric='1,312', metricLabel='AoRs on leavers',
  evidence='4,188 areas of responsibility are active on the run date across seven types: IP_PAY_FIELD_ADMIN 2,123 (719 holders), ORA_RECRUITING 908 (380), IP_HR_COORDINATOR 575 (203), IP_HRBP 546 (155), IP_BHRM_AREA_MGR_REP 28, PAY_REP 7, IP_COMP_ADMIN_BY_COUNTRY 1. 1,312 of them (31%) belong to 336 people whose employment has ended: 628 Pay Field Admin (167 leavers), 294 Recruiting (84), 268 HRBP (53), 111 HR Coordinator (27), 10 BHRM area rep, 1 Comp admin; 91 of those leavers still have an active, unsuspended account. AoRs are location-scoped for HR Coordinator (508 of 575), HRBP (396 of 546) and Pay Field Admin (1,910 of 2,123). 148 of the 285 locations with employees have no HRBP held by a current employee (7,967 employees), 56 have no HR Coordinator (2,756 employees) and 69 have no Pay Field Admin (2,076 employees). Only 2,596 of 4,188 AoRs have a usage assigned, and Recruiting is the only type using auto-provisioning.',
  impact='Areas of responsibility drive the HR Help Desk representative, the “HR representative” shown to employees, the recruiting team on requisitions, and IP’s location-based data roles. An AoR on a terminated person routes work to nobody; a location with no live holder means employees at that site see no HR representative and the location-based data role has no one behind it. Because AoRs are separate from role provisioning, terminating the account does not end the AoR.',
  actions=['End-date the 1,312 AoRs on leavers (HDL AreaOfResponsibility with an end date) and enable the termination checklist task or a scheduled job that ends AoRs at termination.', 'Fill the location gaps: assign HRBP, HR Coordinator and Pay Field Admin for the uncovered locations, using organization-hierarchy scope where one person covers a region so the list stops growing per site.', 'Assign a usage to every AoR type (Help Desk representative, checklist assignee, data-role scope) and turn on auto-provisioning for the location-based types so hires at a location are covered automatically.', 'Add “AoR holder not an active employee” to the monthly access reconciliation alongside the leaver-account check (F01).'],
  effort='Medium', owner='HR operations + HRIS security lead', reference='Oracle Implementing Global HR — Areas of Responsibility; Responsibility types and usages; Autoprovisioning AoRs'),
 dict(id='F22', severity='High', domain='Security & access', title='No audit trail on national identifiers, bank accounts, roles or assignments; PII-view audit off', metric='0', metricLabel='audited PII tables',
  evidence='Audit policies are enabled on 77 tables, but of the sensitive HCM objects only the salary family (CMP_SALARY and its component tables) is audited. There is no audit on PER_NATIONAL_IDENTIFIERS, PAY_PERSON_PAY_METHODS_F (bank accounts), PER_USERS / PER_USER_ROLES, PER_ALL_ASSIGNMENTS_M, PER_PERIODS_OF_SERVICE, addresses or element entries. The Sensitive Data Access Audit (who viewed SSN, bank and salary pages) has zero rows in 2026, so it has never been enabled, while the job that purges it is scheduled.',
  impact='Combined with 479 users inheriting BI Administrator and 12 IT Security Managers, a change to a bank account, an SSN or a role grant leaves no record of who made it. This is the first thing an internal or external auditor will ask for after go-live and the one control that cannot be reconstructed after the fact.',
  actions=['Enable audit (Manage Audit Policies) for Person National Identifier, Personal Payment Method, User Account and Role, Assignment, Work Relationship and Address, and confirm audit level Auditing is on.', 'Enable the Sensitive Data Access Audit profile option so PII page views are logged, and schedule the Sensitive Data Access Audit report to security.', 'Retain audit for at least the payroll-year plus statutory period before purge.'],
  effort='Low', owner='HRIS security lead / Internal audit', reference='Oracle Securing HCM — Manage Audit Policies; Sensitive Data Access Audit'),
 dict(id='F23', severity='Medium', domain='Security & access', title='Segregation of duties not enforced between payroll, HR administration and security roles', metric='83', metricLabel='payroll + HR admin',
  evidence='106 active accounts hold a role that can run payroll processes (20 distinct payroll role names are in use). 83 of them also hold an HR specialist or HR administrator role, 9 also hold IT Security Manager and 11 also hold IP BI Administrator directly. 66 accounts hold HCM Integration Specialist and 8 hold Application Implementation Consultant. 234 accounts carry ten or more roles and 65 carry twenty or more. Person security profiles themselves are well designed: 15 custom profiles are AoR- or manager-hierarchy based, only the seeded View All People is unrestricted, although three generations of a “view all workers” custom profile (V1, V2, Custom V3) are all still enabled.',
  impact='One person who can change an assignment or bank account, run the payroll, and administer security can complete a fraudulent payment end to end with no second pair of hands. Role stacking at 20+ roles per account usually means data roles were granted one location at a time instead of by hierarchy.',
  actions=['Define an SoD matrix (payroll run vs HR data change vs security admin vs bank-account maintenance) and remove the 83 / 9 / 11 conflicts or document a compensating control for each.', 'Move to hierarchy-scoped data roles to bring the 65 twenty-plus-role accounts down.', 'End-date the superseded view-all-workers profiles once the roles using them are confirmed.'],
  effort='Medium', owner='CISO / HRIS security lead', reference='Oracle Securing HCM — Role design and segregation of duties; Advanced Access Controls (Risk Management)'),
 dict(id='F24', severity='High', domain='Security & access', title='Production schedules and configuration owned by consultant and external accounts — a transition risk', metric='13', metricLabel='recurring schedules on consultant accounts',
  evidence='150 recurring BI Publisher schedules ran in the last 90 days. 64 belong to the two service accounts (IP_PROC_SCHEDULER 57, IP_INTEGRATION_USER 7) and 60 to IP employees. 13 belong to seven Hackett consultant accounts — the daily Grievance Action Plan notification, a daily Termination Report, a daily custom classification report, three HR Help Desk request schedules (one running 160 times from a consultant’s personal folder) and three Empower Reconciliation schedules — and 13 belong to a single external vendor account (all of the IP Empower Validation Report runs). Two IP employees run 238 schedule instances from personal folders (Hires_Live, Terms_Draft, Transaction Adoption reports). Outside the scheduler, 36 of the 50 payroll elements created since go-live were created by consultant accounts, the integration status notifications route to a consultant mailbox hard-coded in the data model, IT Security Manager sits on 4 contractor accounts and IP BI Administrator on 6, and the scheduler service account itself holds IT Security Manager.',
  impact='None of this fails while the engagement is running. When a consultant or vendor account is removed, its recurring schedules stop, its personal-folder reports disappear, and the mailbox routing breaks; the configuration knowledge behind 36 elements leaves with the person. A service account holding IT Security Manager means a compromise of one credential is a compromise of the tenant.',
  actions=['Re-create the 13 consultant-owned and 13 vendor-owned recurring schedules under IP_PROC_SCHEDULER from /Custom, then delete the originals; make personal-folder scheduling a policy violation and clean up the 238 IP personal-folder runs the same way.', 'Reassign notification recipients and report ownership to IP distribution lists and remove the hard-coded consultant mailbox from the notification data model.', 'Transfer IT Security Manager and BI Administrator from contractor accounts to named IP employees, and strip IT Security Manager from the service account.', 'Run a configuration knowledge-transfer on the elements, formulas and extracts created since go-live, with the design record checked into IP’s repository.'],
  effort='Medium', owner='IP HRIS leadership + Hackett engagement lead', reference='Oracle BI Publisher — Catalog folders, ownership and scheduling; Securing HCM — Service accounts'),
 dict(id='F25', severity='High', domain='Journeys & onboarding', title='Two-thirds of journeys never complete and 39,411 tasks are open past their target date', metric='39,411', metricLabel='overdue tasks',
  evidence='30,835 journeys (checklists) have been assigned since go-live — roughly one per hire, transfer and termination event. 19,116 (62%) are still Initiated and 2,086 are Waiting; 9,633 have completed. Of 139,898 journey tasks created since go-live, 60,821 are Initiated, 58,008 have Expired unactioned, 4,575 were Rejected and 12,712 completed; 39,411 open tasks are past their target end date. 468,662 payslips and 5,742 job-offer letters have been filed as documents of record, so the document side of onboarding is working.',
  impact='Journeys carry the onboarding and offboarding controls — I-9 and policy acknowledgements, equipment and access returns, manager tasks — and each has an owner. An expired or ignored task means the control did not happen, and the 58,008 expiries say tasks are timing out faster than anyone works them. The volume also lands in every manager’s and new hire’s task list and trains users to ignore it.',
  actions=['Review the journey templates in use for tasks nobody actions: remove or make optional the ones that expire at scale, and lengthen target dates on the ones that matter.', 'Close out or cancel the 19,116 Initiated journeys older than 90 days with a bulk journey-administration action, keeping only those with a mandatory compliance task open.', 'Route task ownership to AoR-based roles (F21) instead of named users so that a task does not die with a leaver, and add journey completion to the HR operations dashboard.'],
  effort='Medium', owner='HR operations / Journeys administrator', reference='Oracle Implementing Journeys — Journey templates, task types and expiry; Journey administration and bulk actions'),
]

DOMAINS = [
 dict(name='Security & access', score=30, blurb='Leaver accounts, inherited BI Administrator and implementation roles in production.'),
 dict(name='Scheduled processes & reports', score=52, blurb='Half of all errors are self-inflicted notification noise; real report failures underneath.'),
 dict(name='Integrations & payroll flows', score=55, blurb='PPG load and inbound HDL flows failing behind Completed parents.'),
 dict(name='Worker data', score=80, blurb='Paid-employee record is clean; no duplicate employees; open payrolls on leavers.'),
 dict(name='Approvals & transactions', score=58, blurb='Stalled approvals and stale drafts.'),
 dict(name='Absence', score=48, blurb='Configured, provisioned, not adopted.'),
 dict(name='Workforce structures', score=76, blurb='Fully enforced position management; idle structures accumulating.'),
 dict(name='Journeys & onboarding', score=40, blurb='Journeys assigned at volume but not worked; tasks expiring unactioned.'),
 dict(name='Recruiting', score=52, blurb='Pipeline not being worked; requisitions not closed; employees re-entering as candidates.'),
 dict(name='Payroll configuration', score=66, blurb='Element catalog carrying unused, ineligible and uncosted elements; entry-level costing volume.'),
]

SEVCOUNT_LABELS = ['Critical', 'High', 'Medium', 'Low']

TERMS = [['Jan',731],['Feb',609],['Mar',707],['Apr',644],['May',788],['Jun',628],['Jul',657],['Aug',737],['Sep',166]]
HIRES = [['Jan',427],['Feb',454],['Mar',507],['Apr',386],['May',528],['Jun',637],['Jul',450],['Aug',613],['Sep',263]]

ESS30 = [['EssBipJob (BI Publisher reports)',2235,2749],['UAClickHistoryMappingScheduler (CX)',719,0],['IndexActiveMetaModelVersion (CX)',719,0],['UpdateRollupsJobDef (CX)',719,0],['JWorkerJob (payroll worker)',45,64186],['MaintenanceJobDef (CX)',29,0],['BIPDelivery',28,5237],['SingleFormulaCompile',21,156],['ComputeUsersACLProcessor',15,14405],['HRC_DL_MAIN (HDL)',13,2379],['HRC_DL_IMPORT_OBJECT',8,2360],['LoadBatchFromFile',8,906],['JCostingJob',5,8]]

POPULATION = [
 ('Person records (current)', '97,721', 'Includes candidates, contacts and leavers.'),
 ('Candidates / emergency contacts', '209,019 / 33,303', 'Person-type usages. Not workers.'),
 ('Active primary employee assignments', '27,208', 'Active primary employee assignment on the run date.'),
 ('… of which no active assigned payroll', '1,741', 'Payroll relationship exists but no assigned payroll is open: Mexico LDG 1,712, China 13, US 7, Japan 4, Canada 2, Singapore 2, Hong Kong 1. Paid outside Fusion Payroll (Mexico payroll extracts). Not employees under the agreed definition; the 7 US cases warrant a look.'),
 ('Suspended employee assignments with active payroll', '399', 'Leave of absence. Not counted.'),
 ('Contingent workers (active)', '99', 'Not counted.'),
 ('Fusion-paid employees — the population this report measures', '25,467', 'Active primary employee assignment and an open assigned payroll on the run date.'),
 ('Terminated employees (current inactive assignment)', '38,919', 'Of these, 6,685 still have an open assigned payroll (F13).'),
]

ACCOUNTS = [
 ('Fusion-paid employee', '25,357', '110', '—', 'Expected'),
 ('Employee, active but not paid in Fusion (Mexico and other LDGs)', '1,737', '4', '—', 'Non-employee under definition; legitimate accounts'),
 ('Employee on leave (suspended assignment)', '398', '1', '—', 'Legitimate'),
 ('Contingent worker', '90', '13', '—', 'Legitimate; time-box'),
 ('Terminated within 30 days (grace period)', '228', '546', '—', 'Within policy'),
 ('Terminated more than 30 days ago', '3,609', '3,180', '26', 'F01 — 3,609 must be suspended'),
 ('Person with no current assignment', '135', '159', '—', 'Review: pending workers, cancelled hires'),
 ('No person linked (service, vendor, consultant, test)', '209', '39', '1', 'F05 — inventory and expire'),
 ('Total accounts', '31,763', '4,052', '27', '38,842 accounts; 13,375 are non-employee'),
]

ITSEC = [
 ('104146','Breck, Karen','Employee','2026-01-06','ankit.mishra@thehackettgroup.com'),
 ('107455','Carroll, Charles','Employee','2025-12-15','jonathan.stevenson@thehackettgroup.com'),
 ('159107','Snowden, Theresa','Employee','2026-01-08','404611'),
 ('267823','Mahasuar, Snehashree','Employee','2026-02-23','159107'),
 ('404611','Peddada, Krishna Teja','Employee','2026-01-06','ankit.mishra@thehackettgroup.com'),
 ('440509','Ynfante, Jesus','Employee','2026-02-23','159107'),
 ('IP_PROC_SCHEDULER','— (service account)','No person','2026-05-28','404611'),
 ('FACP-235f5621…_scim_client_APPID','— (SCIM client)','No person','2025-12-15','jonathan.stevenson@thehackettgroup.com'),
 ('arnav.motwani@thehackettgroup.com','Motwani, Arnav','Contractor','2026-07-22','prasad.deshpande@thehackettgroup.com'),
 ('cara.betz@thehackettgroup.com','Betz, Cara','Contractor','2026-05-01','arnav.motwani@thehackettgroup.com'),
 ('prasad.deshpande@thehackettgroup.com','Deshpande, Prasad','Contractor','2026-07-13','404611'),
 ('vidyasagar.challa@thehackettgroup.com','Challa, Vidyasagar','Contractor','2026-08-14','404611'),
]

BIADMIN_DIRECT = [
 ('107455','Carroll, Charles','Employee','2026-04-13'),('267823','Mahasuar, Snehashree','Employee','2026-04-13'),('404611','Peddada, Krishna Teja','Employee','2026-04-13'),
 ('440509','Ynfante, Jesus','Employee','2026-04-13'),('455461','Johnston, David','Employee','2026-04-13'),('971357','Kappal, Karan','Contractor','2026-04-13'),
 ('consultant account','Madumadukala, Raju','Contractor','2026-08-14'),('anvesh.duvvuru@thehackettgroup.com','—','No person','2026-08-14'),
 ('matias.fernandez@thehackettgroup.com','Fernandez, Matias','Contractor','2026-07-29'),('muralidhar.gunde@thehackettgroup.com','Gunde, Muralidhar','Contractor','2026-08-28'),
 ('prasad.deshpande@thehackettgroup.com','Deshpande, Prasad','Contractor','2026-07-13'),('rajeev.rachamalla@thehackettgroup.com','Rachamalla, Rajeev','Contractor','2026-05-11'),
]

BIADMIN_INHERIT = [
 ('IP_BI_ADMINISTRATOR','IP BI Administrator','Job role (intended)','12'),
 ('IP_IRC_RECRUITER_JOB_CUSTOM','IP Recruiter','Job role — contains BIAdministrator','14'),
 ('IP_RECRUITER_-_VIEW_BY_LOCATION_DATA','IP Recruiter – View by Location','Data role on IP Recruiter','302'),
 ('IP_HR_CO-ORDINATOR_RECRUITMENT-_VIEW_BY_LOCATION_DATA','IP HR Co-ordinator Recruitment – View by Location','Data role on IP Recruiter','177'),
 ('IP_HRBP_RECRUITMENT-_VIEW_BY_LOCATION_DATA','IP HRBP Recruitment – View by Location','Data role on IP Recruiter','109'),
 ('IP_RECRUITER-_VIEW_ALL_REQ_DATA','IP Recruiter – View All Req','Data role on IP Recruiter','50'),
 ('IP_RECRUITER_-_VIEW_BY_ORGANIZATION_DATA','IP Recruiter – View by Organization','Data role on IP Recruiter','41'),
 ('IP_HR_ORG_MANAGEMENT_VIEW_ALL_DATA','IP HR Org Management View All','Data role on IP HR Org Management','39'),
 ('IP_HRBP__RECRUITMENT-_VIEW_BY_ORG_HIERARCHY_DATA','IP HRBP Recruitment – View by Org Hierarchy','Data role on IP Recruiter','27'),
 ('IP_HR_CO-ORDINATOR_RECRUITMENT-_VIEW_BY_ORG_HIERARCHY_DATA','IP HR Co-ordinator Recruitment – View by Org Hierarchy','Data role on IP Recruiter','23'),
 ('ORA_ASM_APPLICATION_IMPLEMENTATION_CONSULTANT_JOB','Application Implementation Consultant','Seeded — contains BIAdministrator','8'),
 ('IP_PER_HUMAN_RESOURCE_ORG_MANAGEMENT_JOB_CUSTOM','IP HR Org Management','Job role — contains BIAdministrator','5'),
]

BIADMIN_EFFECTIVE = [('Fusion-paid employees','339'),('Terminated people','53'),('Contractors','38 (+2 suspended)'),('Employees not paid in Fusion','34'),('Employee on leave','1'),('No person linked','12'),('Distinct active users','479')]

TERM_ROLES = [('IP Employee · IP Absence Employee SS · IP Next Gen Help Desk User · IP Digital Assistant Access – Employee','2,369'),('IP Ex-Employee (the intended leaver role)','737'),('IP Line Manager · IP Hiring Manager Custom · Digital Assistant – Manager','442'),('IP Payroll Field Time Administrator','66'),('IP Recruiter – View by Location','44'),('IP Payroll Finance','38'),('IP HRBP View by Location','28'),('IP HR Grievance Representative','27'),('IP HRBP Recruitment – View by Location','26'),('IP Payroll Finance Data Role View by Location','23')]

NOPERSON = ['ip_svc_fa','ip_svc_tcp','ip_svc_term_user','IP_INTEGRATION_USER','IP_ADP_INTEGRATION_USER','IP_PROC_SCHEDULER','Sail.Integration','Sail.Integration1','IPORC.EY','IPORC.Sterling','IPORC.Assessment','HRServiceDelivery@Ipaper.com','charles.carroll@ipaper.com','Anusuya.Sampath@ipaper.com','Melanie.Posey','Admin_404611','Self_Service_Test_User','kp_test','test_kp','KP.testing','tquintero306@gmail.com','vandana.sharma@alight.com','kelly.solomon@alight.com','neha.vats.2@alight.com','suchalika.bag@alight.com','nishandini.c@alight.com','evelyn.powell@alight.com','Anshita.Sharma.2@alight.com','ajay.tomar.4@alight.com','saikrishna.chelikani@thehackettgroup.com','bala.amudala@thehackettgroup.com','bhupal.reddy@thehackettgroup.com','rajesh.daram@thehackettgroup.com','amarnath.podaralla@thehackettgroup.com','diptalal.dutta@thehackettgroup.com','Yashaswini.Kalle@thehackettgroup.com','Ankit.Mishra1@thehackettgroup.com','anvesh.duvvuru@thehackettgroup.com','phanindra.talur@thehackettgroup.com','gopi.boddu@thehackettgroup.com','sthitapragnya.panda@thehackettgroup.com','vamshi.krishna@thehackettgroup.com','sravanthi.bandi@thehackettgroup.com','CZFORT8','AGILLI4','DALVA19','102789','233363','245372','436541','972432','973791','FAAdmin','faoperator','weblogic_idm','oamAdminUser','IDRWUser','IDROUser','OPAUSER','PSCR_PROXY_USER','FIISUSER','AIAPPS_BIP','em_monitoring','octo_monitor','rats_monitor','anonymous','PUBLIC']

NID_PAIRS = """0139|581353 Adkins, Tracy Kyle|Candidate, career site 2026-01-10
0255|393444 Mcdermott, Dalton Derby|Candidate, conversion 2025-12-24
0323|255550 Jones, Douglas|Candidate, career site 2026-08-09
0508|977111 Flores, Rodolfo|Candidate 976974, career site 2026-05-30
0585|644628 Allen, Denzel J|Candidate, career site 2026-02-04
0684|568668 Gallaspy, Dillon Chase|Candidate, career site 2026-07-23
1329|481950 Mayer, Lucas|Candidate, career site 2026-03-30
1464|580913 Day, Stefen Michael|Candidate, career site 2026-01-06
1521|655793 Mullen, Richard Cornelius|Candidate, conversion 2025-12-24
1703|589935 Drew, Benjamin Richard|Candidate, career site 2026-03-12
1855|646974 Vlasaty, Isaac David|Candidate, career site 2026-07-30
2151|639268 Slagle, Addison|Candidate 971281, conversion 2025-12-24
2188|445887 Green, Terrance|Candidate, career site 2026-06-28
2584|250612 Garcia, William|Candidate, career site 2026-02-16
3275|667625 Oehlert, Joseph Albert|Candidate, career site 2026-06-02
3619|571773 White, Tyler|Candidate, career site 2026-02-12
3630|214397 Robinette, Jason Kevin|Candidate, career site 2026-06-27
3936|977771 Mohamed, Raage|Candidate, career site 2026-06-27
4074|647587 Sarnecke, Jacob|Candidate, career site 2026-02-05
4386|625935 Mendoza, Kaira (DOB 1996)|Cancelled hire 123456, DOB 1995 — verify
4389|662196 Neal, Jaleo Neal|Candidate, career site 2026-01-16
5085|592526 Jackson, Deangelo|Candidate, conversion 2025-12-24
5099|977572 Torres, Adriana|Candidate, career site 2026-03-17
5118|615144 Aguirre, Evelyn|Candidate, career site 2026-05-13
5152|217009 Skelton, Dwight Lee|Candidate, career site 2026-04-07
5473|254367 Bates, John|Candidate "John, Bates", career site 2026-08-05
5787|459015 Emigh, Hunter Alan|Candidate, career site 2026-08-07
6017|299079 Smith II, Aaron Ray|Candidate, career site 2026-01-27
6067|613796 Ortega, Jordy|Candidate, career site 2026-01-28
6538|564292 Reyes, Dennis Alexander|Candidate, career site 2026-03-27
6569|333578 Mauthe, Braz Micah|Candidate, career site 2026-05-13
7058|592136 Fields, William|Candidate, conversion 2025-12-24
7155|552918 Dicentes, Michelle Tiffany|Candidate, career site 2026-05-28
7332|446911 Varnado Jr, Errol La’Rue|Candidate, career site 2026-02-23
7390|589438 Siple, Alexander James|Candidate, career site 2026-04-09
7452|378537 Leroy, Christopher Joseph|Candidate, career site 2026-01-13
7469|675140 Preciado, Ruben|Candidate, career site 2026-02-26
7732|571694 Bumbolo, Dashawn Michael|Candidate, career site 2026-04-23
7797|253258 Cullen, David Dean|Candidate, career site 2026-03-03
7817|264981 Delatorre, Juan Aurelio|Candidate 979123 "De La Torre, Juan", created by the employee 2026-01-27
7965|635361 Morrison, Jackson Willis|Candidate 975893, career site 2026-04-30
8171|636932 Mejia, Kelsey|Candidate 974921 (no DOB), career site 2026-01-13
8172|485572 Larosiliere, Williams|Candidate, career site 2026-07-08
8175|305204 Supalo, Willie James|Candidate 978971, career site 2026-06-19
8224|654357 Garcia Murillo, Javier|Candidate 978452, career site 2026-07-28
8377|183181 Kendall, James|Candidate "KENDALL, GREG", same DOB, career site 2026-04-24 — verify
8389|253161 Mills, Chelsea|Candidate, career site 2026-01-21
8621|977516 Cina, Anthony Kalman|Candidate, career site 2026-05-06
8721|592016 Simmons, Kenneth Vincent|Candidate, career site 2026-01-20
8796|534394 Gallien, Daniel Augustus|Candidate "Daniel, Gallien augustus", career site 2026-05-14
8894|351080 Cottrell, Joshua John|Candidate, career site 2026-02-25
9211|594549 Quintero, Edgar|Candidate, career site 2026-07-15
9512|10358 Bowman, Gregory|Candidate, career site 2026-03-03
9641|625668 Butler, Chris|Candidate, created by user 416322 2026-06-24
9758|208766 Elton III, Frank W|Candidate, career site 2026-07-01
9969|464982 Powers, Constance|Candidate 976692, career site 2026-05-01"""

NID_SINGLE = ['552918','571694','250612','208766','977516','589438','217009','581353','445887','481950','299079','253161','253258','485572','613796','625668','647587','615144','571773','589935','10358','254367','183181','430698377'.replace('430698377','183181'),'644628','214397','592526','333578','446911','534394','255550','646974','592016','977771','594549','977572','378537','675140','393444','459015','351080','667625','580913','592136','655793','662196','568668','564292']

FAILING_REPORTS = [
 ('Integrations/Status_Notification/Scheduled Integration BI (Only GL) Report Status','1,902','1,905','Bursting, no data (F03)','IP_PROC_SCHEDULER, hourly'),
 ('Integrations/Status_Notification/Scheduled Integration BI Report Status','1,898','1,905','Bursting, no data (F03)','IP_PROC_SCHEDULER, hourly'),
 ('Integrations/Status_Notification/Scheduled Integration Status','1,788','1,906','Bursting, no data (F03)','IP_PROC_SCHEDULER, hourly'),
 ('Reports/Notification Report/IP Grade Exception Alert Report','80','80','Bursting, no data','IP_INTEGRATION_USER, daily 10:00'),
 ('Reports/Help Desk/Grievance_Action_Plan_Notification','79','79','Bursting, no data','consultant personal account, daily'),
 ('Reports/Payroll/Accounting Balancing Report','69','634','BIP job failed (49) · delivery error (20)','37 submitters, ad hoc'),
 ('Reports/Payroll/Union_Dues_Remittance_Report','30','87','BIP job failed','8 submitters'),
 ('Reports/Empower Reports/IP Empower Validation Report','21','164','BIP job failed','external vendor account'),
 ('Reports/Core HR/Worker Basic Detail Report','13','391','delivery error (5) · system error (3) · failed (5)','39 submitters'),
 ('Reports/Core HR_Ref_Roles/Worker Basic Detail Report','11','11','Report definition not found — orphaned schedule 5060','named user, weekly'),
 ('Reports/Notification Report/WFH_FLG_DM/WFHFLGNOTIFICATION_RPT','11','11','Bursting, no data','IP_INTEGRATION_USER, weekly'),
 ('Integrations/HDL Error Report/HDL_Summary_Report','10','1,906','delivery error','named user, hourly'),
 ('Integrations/Alight/… Alight Payroll Actuals with all elements and Balances Report','8','50','BIP job failed','consultant account'),
 ('Reports/Payroll/Labor_Distribution_Report','6','669','delivery error','95 submitters'),
 ('/~IP_PROC_SCHEDULER/PSL Reports/PSL Summary Report','6','8','BIP job failed — personal folder','IP_PROC_SCHEDULER'),
 ('Integrations/SumTotal/Emp, Org, Job, EmpJob, Org file reports (5)','15','395','delivery error, all on 2026-07-06','IP_PROC_SCHEDULER'),
 ('Reports/Payroll/EE Union and Payee Code Audit Listing','4','19','BIP job failed','named user'),
 ('PSL Reports/PSL Summary Report · Third Party Balancing Report · Regular_Rate_Average_Report','12','12','BIP job failed, 100%','various'),
 ('Consultant personal folders … Payroll – Configuration Workbook','8','9','BIP job failed — personal folders','consultant accounts'),
 ('Integrations/IP_Bank_Reconciliation/GL_Bank_Reconciliation_Report','3','377','BIP job failed','IP_PROC_SCHEDULER'),
]

FLOW_ERRORS = [
 ('GENERATE AND LOAD ASSIGNMENT PPG DATA','ORA_PAY_HDL_LOAD','Functional error','2,159','2026-09-12'),
 ('QUICK_PAY_ONLY','View SOE','Execution started / Incomplete','493 / 112','2026-09-11'),
 ('QUICK_PAY_ONLY','Calculate QuickPay','Rolled back / Errored','106 / 4','2026-09-11'),
 ('IP_SEDGWICKLOA_INBOUND_FILE_FLOW','ORA_PAY_HDL_LOAD','Functional error','63','2026-09-11'),
 ('PAYROLL_RUN','Payroll run','Rolled back','34','2026-09-09'),
 ('Periodic Payroll Activity Report','—','Functional error / Rolled back','28 / 8','2026-09-08'),
 ('PAYROLL_ACTIVITY_REPORT','—','Functional error','28','2026-09-02'),
 ('CHECK_PAYMENT','—','Rolled back','28','2026-09-04'),
 ('RETROACTIVE_PAY','—','Rolled back','27','2026-09-07'),
 ('ELECTRONIC_PAYMENT','—','Rolled back','26','2026-09-10'),
 ('PREPAYMENTS','—','Rolled back','20','2026-09-03'),
 ('ELEMENT_RESULT_REPORT','—','Errored','17','2026-09-11'),
 ('IP_EMPOWER_DEFERRAL_INBOUND_FLOW · IP_ALIGHT_PENSION_INB_V2 · IP_EMPOWER_LOAN_FEEDBACK_INBOUND_FLOW','ORA_PAY_HDL_LOAD','Functional error','13 each','2026-09-12'),
 ('GENERATE_EE_TP_CHECK','Check payment','Rolled back','12','2026-08-03'),
 ('IP_BLACK_BAUD_INBOUND_LOAD','ORA_PAY_HDL_LOAD','Functional error','10','2026-09-09'),
 ('PAYSLIP · PAYSLIP_ARCHIVER','—','Rolled back / Functional error','10 / 10 / 7','2026-09-09'),
 ('IP SIRVA PAYROLL ADJUSTMENTS INBOUND_V1','Initiate Data Loader / Costing of Balance Adjustment','Functional error / Errored','8 / 5','2026-08-27'),
 ('GENERATE DATA LOADER FILE','LOAD_BATCH','Errored','8','2026-08-17'),
 ('Empower RMSP / RMSP SFTP / 401K SFTP extracts','—','Functional error','7 / 6 / 6','2026-08-25'),
 ('GENERATE AND LOAD ASSIGNED PAYROLL FINC DATA','ORA_PAY_HDL_LOAD','Functional error','5','2026-08-10'),
 ('IP_Custom_CITI_PositivePay_Extract','—','Rolled back','5','2026-09-10'),
 ('IP_Financial_Finesse_INT043_Employee_Demographic · IP_SEDGWICK_ATP_INBOUND_FF · IP_SDWK_TEST_DNU','—','Functional error','4 each','2026-07-30'),
 ('ORA_PAY_UPGRADE_OBJECT','ORA_PAY_UPGRADE_FINAL_OBJ','Functional error','3','2026-08-22'),
]

ESS_TOP = [
 ('crm_click_history_mapping_hourly (UAClickHistoryMappingScheduler)','FUSION_APPS_CRM_ESS_APPID','1,906','1,906','System error during request pre-processing','Seeded CX job — F11'),
 ('IndexActiveMetaModelVersionJobDef · UpdateRollupsJobDef','FUSION_APPS_CRM_ESS_APPID','1,470 each','1,905','Permission denied to execute the request','Seeded CX — last success 2026-07-13'),
 ('crm_click_history_aggregation / user_active_time / caching (daily)','FUSION_APPS_CRM_ESS_APPID','79 each','79','Permission denied / pre-processing','Seeded CX'),
 ('MaintenanceJobDef · ReflectHierarchyChanges · SynchronizeLookupValues','FUSION_APPS_CRM_ESS_APPID','61 / 8 / 8','79 / 11 / 11','Permission denied','Seeded CX'),
 ('JWorkerJob (payroll worker)','FUSION_APPS_HCM_ESS_APPID','55','174,052','Error (child of payroll flows)','Ties to F08 rollbacks'),
 ('BIPDelivery','FUSION_APPS_HCM_ESS_APPID','61','13,884','BIP job failed with delivery error','Email/FTP delivery of scheduled reports'),
 ('FndOSCSBulkIngestJob','FAAdmin / loader','23','4,827','Search Extension Profile Option Not Enabled','Oracle Search not enabled — F11'),
 ('Formula Compile Utility Submission (SingleFormulaCompile)','IP_PROC_SCHEDULER and users','25','159','BIZ_ERROR exit code','F08'),
 ('ComputeUsersACLProcessor / ComputeUsersACL','IP_PROC_SCHEDULER','15 / 3','38,075 / 1,906','ESS-07036 unrecoverable system error','Manager-hierarchy ACL refresh, 0.04% failure'),
 ('LoadBatchFromFile (Load Batch)','IP_PROC_SCHEDULER / IP_INTEGRATION_USER','10 / 5','123 / 210','No HDL files generated in path · Process has logical errors','Inbound extracts producing empty HDL'),
 ('ProcessLdapRequestsChild (Send Pending LDAP Requests)','FUSION_APPS_HCM_ESS_APPID','9','110','NullPointerException SummaryMap.getSummary()','Account maintenance — ties to F01'),
 ('HRC_DL_MAIN (Import and Load HCM Data File)','scheduler, named users, consultants','15','~500','DLOAD_PROCESS_BIZ_ERROR · child job exception','HDL loads submitted by named people'),
 ('HRC_DL_IMPORT_OBJECT / IMPORT_AND_LOAD_OBJECT','FUSION_APPS_HCM_ESS_LOADER_APPID','8 / 8','5,784 / 5,788','ORA-20922 business error','0.14% of HDL object loads'),
 ('DaemonJob','FUSION_APPS_HCM_ESS_APPID','6','6','JBO-27123 fnd_trace.stop_trace','Trace daemon, all runs failed'),
 ('JCostingJob','FUSION_APPS_HCM_ESS_APPID','5','52','Error','Payroll costing — F08'),
 ('FndOSCSIndexIngestJob','named user','1','4','Index metadata not found — fa-hcm-position (404)','Oracle Search'),
]

MODULES = [
 ('Global HR / Core HR','In use — 25,467 paid employees, 15 legal employers, 119 business units, 7,839 departments, 35,236 positions, 1,353 jobs, 4,501 grades, 269 grade ladders, 326 locations, 136 unions, 9 legislations.','Position management enforced 100%; every paid employee has job, grade, location, department, manager, work email, DOB, home address. Oracle guidance met on structure completeness. Gaps: idle structures (F13), duplicate persons (F04), 264 future-dated rows, diversity attributes (F15).'),
 ('Security','413 custom roles (39 data roles), 19 person security profiles (15 custom, AoR- and hierarchy-based — good design), 38,842 accounts; audit on 77 tables but only salary among sensitive HCM objects. Custom IP roles replace the seeded HR Specialist model (good practice).','Leaver deprovisioning not effective (F01, F11); 1,312 areas of responsibility on leavers and location coverage gaps (F21); seeded BI Administrator leaked into recruiter data roles (F02); implementation roles and consultant/vendor accounts in production (F05); no last-login capture (F15); no audit on NID, bank, roles or assignments (F22); SoD conflicts (F23); consultant and personal-account dependency (F24).'),
 ('Mexico and other non-US workers','1,712 Mexico plus 29 other-legislation employees on HCM, paid outside Fusion Payroll via extracts.','Records are complete where it matters (legislative row, manager, work email, HR coverage at every location); 925 have no grade, 33 no home address, 2 no national identifier; no absence entries and no Help Desk requests in 2026 — those services are not reaching this population.'),
 ('Payroll (US)','13 payrolls, 14 payroll statutory units, 5 tax reporting units, 4,070 elements (2,275 non-seeded, 605 user-facing), 3,932 non-seeded fast formulas, 29,306 current salary records, 10 salary bases; 8.4M element entries loaded since go-live.','Flows complete but child tasks fail (F04, F09); 6,685 leavers with open assigned payroll (F13); 2,619 non-seeded formula rows carry no compile flag and should be confirmed with a bulk Compile Formula run; 1,712 Mexico workers are on HCM but paid outside Fusion Payroll via extracts.'),
 ('Absence Management','19 absence types, 19 plans, 1,607 plan enrolments; SS role provisioned to 25,357 accounts.','332 entries in 12 months, 126 awaiting — configured but not adopted (F07). Leave arrives via Sedgwick HDL flow instead.'),
 ('Recruiting','4,315 requisitions, 275,607 job applications in 12 months, 209,019 candidate person records.','High volume; candidates not matched on hire produce duplicate persons (F04); recruiter data roles carry BI Administrator (F02).'),
 ('HR Help Desk (Next Gen)','31,804 service requests in 12 months; IP Next Gen Help Desk User provisioned broadly.','Active. Leavers keep the Help Desk User role (F10). Grievance Action Plan notification failing daily (F03).'),
 ('Journeys / Checklists','30,835 journeys assigned since go-live, 139,898 tasks; 468,662 payslips and 5,742 offer letters filed as documents of record across 222 document types.','Assigned at volume but not worked: 62% of journeys still Initiated, 58,008 tasks expired, 39,411 open past target (F25). Document records are healthy.'),
 ('Workforce Compensation','4 workforce compensation plans configured.','Present; cycle results not evaluated in this pass.'),
 ('Time and Labor','438 time records since go-live; time comes from Workbrain, WFS and Kronos as element entries via HDL (8.4M entries).','Not used as the time system of record; the HDL path is the control point (F04, F17).'),
 ('Seniority · Calculation cards','622,021 seniority-date rows; 123,311 calculation cards, 9,300 created since go-live.','Present. Tax card completeness is on the payroll not-yet-verified list.'),
 ('Talent / Performance / Goals','64,570 person talent profiles; 8 goals; no performance documents.','Profiles exist from conversion; performance and goals not implemented beyond a pilot; not scored.'),
 ('Compensation','10 salary bases; salary present for 100% of paid employees.','Base pay sound. Workforce compensation cycles not evaluated in this pass.'),
 ('Benefits · Learning · Time and Labor','0 benefit plans, 0 learning items; time comes from Workbrain/WFS/Kronos via extracts.','Not implemented; out of scope. Third-party time and benefit feeds are the integration risk (F04).'),
 ('Integrations (HDL, Extracts, BIP)','206 non-seeded HCM extract definitions, 2,353 HDL data sets in 30 days (~78 a day), 130+ scheduled BIP jobs, three service accounts (IP_PROC_SCHEDULER, IP_INTEGRATION_USER, ip_svc_*).','Heavy and mostly healthy (HDL 99.9%), but failures hide behind Completed parents (F04) and behind notification noise (F03); production schedules owned by consultants’ personal folders (F09).'),
]

STRENGTHS = [
 ('100%','Position management enforced','No paid employee is missing a position, job, grade, location or department.'),
 ('0','Duplicate employees','25,467 employees, 25,467 valid, unique SSNs — no employee shares an identifier with another employee; no placeholders or malformed values.'),
 ('99.93%','Core payroll worker success','JWorkerJob ran 174,052 times in 90 days with 55 errors; HDL object loads 99.86%.'),
 ('1','Employee without a line manager','And none report to an inactive manager; no self-reporting managers.'),
 ('100%','Salary, work email, DOB and address coverage','Only two paid employees lack a work email.'),
 ('546','Leavers suspended inside 30 days','The termination flow works when it fires; the gap is the population it never touched (F01).'),
]

FOOTPRINT = [
 ('Enterprise / tenant','International Paper · iazbqy (HCM-only pod)'),('Go-live','1 January 2026'),('Legal employers / payroll statutory units / TRUs','15 / 14 / 5'),('Business units','119'),
 ('Legislative data groups','9 (US, CA, MX, CN, JP, SG, HK …)'),('Active departments / inactive','7,839 / 1,160'),('Active positions / vacant','35,236 / 7,635'),('Active jobs / grades / locations','1,353 / 4,501 / 326'),
 ('Unions','136'),('User accounts (active / suspended / inactive)','31,763 / 4,052 / 27'),('Custom roles / data roles / unassigned','413 / 39 / 11'),('Areas of responsibility (active / on leavers)','4,188 / 1,312'),('Payrolls / elements (non-seeded / user-facing)','13 / 2,275 / 605'),
 ('Non-seeded fast formulas','3,932'),('Absence plans / types / enrolments','19 / 19 / 1,607'),('Salary bases / current salary records','10 / 29,306'),('Requisitions open / created since go-live / applications (12 m)','1,485 / 3,660 / 275,607'),
 ('Help Desk requests (12 m)','31,804'),('HCM extract definitions (non-seeded)','206'),('HDL data sets (30 d)','2,353'),('Scheduled-process runs (90 d) / errors','1,072,000+ / 11,419'),('Run results / run result values / element entries (rows)','144M / 752M / 10.7M'),('Line managers / max direct reports / hierarchy depth','3,154 / 56 / 11'),
 ('Journeys assigned / tasks (since go-live)','30,835 / 139,898'),('Documents of record (2026) / document types','475,821 / 222'),('Benefits plans / Learning items','0 / 0 (not implemented)'),
]
