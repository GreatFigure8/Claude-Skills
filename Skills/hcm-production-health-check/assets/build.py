import base64, json, re, html as H
from data import *

NID_SINGLE = ['552918','571694','250612','208766','977516','589438','217009','581353','445887','481950','299079','253161','253258','485572','613796','625668','647587','615144','571773','589935','10358','254367','183181','644628','214397','592526','333578','446911','534394','255550','646974','592016','977771','594549','977572','378537','675140','393444','459015','351080','667625','580913','592136','655793','662196','568668','564292']

import os
T = os.path.join(os.path.dirname(os.path.abspath(__file__)),'tpl','')
ds_css = open(T+'ds.css').read()
logo = open(T+'logo_clean.svg').read()
def b64(f): return base64.b64encode(open(T+f,'rb').read()).decode()
fonts = [('Barlow',400,'b4cc03e7-57cd-4a84-a939-a0fb63256308.bin'),('Barlow',500,'aed2f054-23b1-485c-9bb0-33aa1db71aac.bin'),('Barlow',600,'446871ce-ea7b-40df-af9b-ab5860868361.bin'),
         ('Barlow Condensed',500,'cb4e4c1f-271b-4273-8a47-607fbad43bae.bin'),('Barlow Condensed',600,'c163f2e2-9d23-40c2-ab48-aba91dd3fbd4.bin'),('Barlow Condensed',700,'aa77b938-966d-4c54-ba19-bdab29e3b1fc.bin')]
font_css = ''.join(f"@font-face{{font-family:'{n}';font-style:normal;font-weight:{w};font-display:swap;src:url(data:font/woff2;base64,{b64(f)}) format('woff2');}}\n" for n,w,f in fonts)

e = H.escape
def rows(tbl, cols, widths=None, right=None):
    right = right or []
    th = ''.join(f'<span{" style=\"text-align:right\"" if i in right else ""}>{e(c)}</span>' for i,c in enumerate(cols))
    grid = widths or ' '.join(['minmax(0,1fr)']*len(cols))
    out = f'<div class="tbl" style="grid-template-columns:{grid}"><div class="th">{th}</div>'
    for r in tbl:
        out += '<div class="tr">' + ''.join(f'<span{" style=\"text-align:right;font-variant-numeric:tabular-nums\"" if i in right else ""}>{e(str(c))}</span>' for i,c in enumerate(r)) + '</div>'
    return out + '</div>'

def h2(t, sub=''): return f'<div class="h2row"><h2>{e(t)}</h2>{f"<span class=sub>{e(sub)}</span>" if sub else ""}</div>'
def corners(white=False):
    s = ' style="color:rgba(255,255,255,.7)"' if white else ''
    return ''.join(f'<i class="corner {c}"{s}></i>' for c in ('tl','tr','bl','br'))

nid_rows = []
for line in NID_PAIRS.split('\n'):
    k,a,b = line.split('|')
    nid_rows.append(('***-**-'+k, a, b))

AOR = [('IP_PAY_FIELD_ADMIN','2,123','719','628 (167 leavers)','location 1,910 · legal entity 198 · dept 212','69 locations · 2,076 employees'),('ORA_RECRUITING','908','380','294 (84)','recruiting hierarchy 740 · org 256','—'),('IP_HR_COORDINATOR','575','203','111 (27)','location 508 · dept 67','56 locations · 2,756 employees'),('IP_HRBP','546','155','268 (53)','location 396 · dept/hierarchy 150','148 locations · 7,967 employees'),('IP_BHRM_AREA_MGR_REP','28','14','10 (4)','country 16 · dept 12','—'),('PAY_REP','7','5','0','location 7','—'),('IP_COMP_ADMIN_BY_COUNTRY','1','1','1 (1)','country','—'),('Total','4,188','1,477','1,312 (336)','','')]
ITSEC_STATS = [('International Paper employees','6','Dec 2025 – Feb 2026'),('Hackett contractor accounts','4','May – Aug 2026'),('Non-person accounts (scheduler service account, SCIM client)','2','Dec 2025 / May 2026'),('Total','12','')]
BIADMIN_STATS = [('International Paper employees','5','Apr 2026'),('Contractor accounts (Hackett and other)','6','Apr – Aug 2026'),('Non-person account','1','Aug 2026'),('Total','12','')]
NOPERSON_STATS = [('Oracle-seeded application identities (*_APPID, FUSION_*)','180','Expected'),('IP service and integration accounts (scheduler, integration, ip_svc_*, IPORC.*)','~12','Owner and expiry to be documented'),('Consultant accounts','12','Time-box to engagement end'),('Vendor accounts','7','Time-box to contract'),('Named IP individuals not linked to a person record','~8','Link to person or disable'),('Test and duplicate admin accounts','5','Disable'),('Personal email address','1','Disable'),('Platform and monitoring identities (FAAdmin, weblogic_idm, oam, monitoring)','~20','Oracle-managed'),('Total','248','249 including 1 inactive')]
SCHED = [('Service accounts (IP_PROC_SCHEDULER, IP_INTEGRATION_USER)','64','8,187','0'),('IP employees','60','2,800','238'),('Hackett consultant accounts (7)','13','514','166'),('External vendor account (1)','13','143','0'),('Total recurring schedules, last 90 days','150','11,644','404')]
# ---------- sections (static HTML) ----------
sections = []

sections.append(f'''
<section class="titlegrid">
  <div>
    <div class="eyebrow">International Paper · Oracle Fusion Cloud HCM</div>
    <h1>Production health check, <span class="acc">September 2026</span></h1>
    <p class="lede">A read-only inspection of the live production tenant against Oracle’s implementation guidance and Hackett’s HCM operating standards, eight months after the 1 January 2026 go-live. Every figure was measured directly in the environment on {RUN_DATE}; nothing is estimated.</p>
  </div>
  <div class="blueprint kpis">{corners()}
    <div><div class="k">Fusion-paid employees</div><div class="v">25,467</div></div>
    <div><div class="k">Active employee headcount</div><div class="v">27,208</div></div>
    <div><div class="k">User accounts · non-employee</div><div class="v">38,842 · 13,375</div></div>
    <div><div class="k">Legal employers · BUs · payrolls</div><div class="v">15 · 119 · 13</div></div>
    <div class="span">Tenant iazbqy · HCM-only pod · Core HR, Payroll, Absence, Recruiting, Help Desk, HDL and 206 HCM extracts in use · 1,072,000 scheduled-process runs since Sept 2024</div>
  </div>
</section>''')

sections.append(f'''
<section class="blueprint verdict" id="sec-summary">{corners(True)}
  <div>
    <div class="eyebrow light">Overall score</div>
    <div class="big" id="overallScore"></div>
    <div class="of">of 100 · <strong id="overallLabel"></strong></div>
  </div>
  <div>
    <h2 class="white">The paid-employee record is sound. Access hygiene, silent process failures and unworked queues are where the risk sits.</h2>
    <p class="vlede">Every one of the 25,467 Fusion-paid employees has a position, grade, manager, salary and a unique national identifier, and core payroll processing succeeds 99.9% of the time. Against that, 3,609 leavers still hold live, unsuspended accounts with roles attached; 479 users inherit the seeded BI Administrator role through recruiter data roles; half of all scheduled-process errors come from notification reports that fail by design every hour; and the assignment payroll-process-group load has failed on every run for 90 days behind a green parent flow.</p>
    <div class="sevrow" id="sevCounts"></div>
  </div>
</section>''')

sections.append(f'''
<section class="pad" id="sec-footprint">
  <h2>Environment footprint</h2>
  <div class="foot">{''.join(f'<div class="frow"><span>{e(k)}</span><span>{e(v)}</span></div>' for k,v in FOOTPRINT)}</div>
</section>''')

sections.append(f'''
<section class="pad" id="sec-definitions">
  {h2('How this report counts people','Definitions agreed with International Paper')}
  <div class="defgrid">
    <div class="blueprint defcard">{corners()}
      <div class="eyebrow">Employee</div>
      <p>A person with an <strong>active primary employee assignment</strong> and an <strong>open assigned payroll</strong> in Fusion on the run date. People who are not being paid through Fusion Payroll are not counted, however active their HR record is.</p>
      <div class="eyebrow" style="margin-top:14px">Not an employee</div>
      <p>Ex-employees and terminated people (including the 30-day post-termination account grace period), Recruiting candidates, contingent workers, pending workers, contacts, suspended assignments, and workers whose pay runs outside Fusion (the Mexico population). No activity before the 1 January 2026 go-live is used anywhere in this report.</p>
      <div class="eyebrow" style="margin-top:14px">Shared national identifiers</div>
      <p>Counted only where at least one side of the pair is an employee under this definition. No pair exists where both sides are employees.</p>
    </div>
    <div class="blueprint" style="padding:6px 22px 10px">{corners()}
      {rows(POPULATION, ['Population','Count','Basis'], 'minmax(0,1.3fr) 130px minmax(0,2fr)', [1])}
    </div>
  </div>
</section>''')

sections.append(f'''
<section class="pad" id="sec-strengths">
  <h2>What is working</h2>
  <div class="strengths">{''.join(f'<div class="blueprint scard">{corners()}<div class="m">{e(m)}</div><div class="t">{e(t)}</div><div class="n">{e(n)}</div></div>' for m,t,n in STRENGTHS)}</div>
</section>''')

sections.append(f'''
<section class="pad" id="sec-scorecard">
  {h2('Scorecard by domain','Select a domain to filter the register.')}
  <div class="domgrid" id="domains"></div>
</section>''')

sections.append(f'''
<section class="pad" id="sec-findings">
  <div class="h2row"><h2>Findings register</h2><span class="sub" id="visibleCount"></span></div>
  <div class="no-print filters">
    <div class="seg" id="sevFilters"></div>
    <div class="seg" id="domFilters"></div>
    <button type="button" class="btn btn-secondary" id="toggleAll" style="font-size:15px;padding:8px 14px;margin-left:auto">Expand all</button>
  </div>
  <div class="reg">
    <div class="reghead"><span>Ref</span><span>Severity</span><span>Finding</span><span>Domain</span><span style="text-align:right">Measured</span></div>
    <div id="findings"></div>
  </div>
</section>''')

sections.append(f'''
<section class="pad charts" id="sec-trends">
  <div class="blueprint chart">{corners()}
    <h3>Employee hires and terminations by month</h3>
    <p class="sub">Employee periods of service started and ended since go-live, January to 12 September 2026: 5,667 terminations and 4,265 hires. Hover a month.</p>
    <div class="bars" id="termBars"></div>
    <div class="barlabels" id="termLabels"></div>
    <div class="hover" id="termHover">Hover a month for the exact counts.</div>
  </div>
  <div class="blueprint chart">{corners()}
    <h3>Scheduled process errors, last 30 days</h3>
    <p class="sub">Errored requests by job definition. Dark bars fail more than one run in five. Hover a bar for the success rate.</p>
    <div class="hbars" id="essBars"></div>
    <div class="hover" id="essHover">Hover a job for its success rate.</div>
  </div>
</section>''')

sections.append(f'''
<section class="pad" id="sec-access">
  {h2('User accounts and privileged access','Requested detail — who holds what, measured on the run date')}
  <h3 class="h3">Account classification (PER_USERS, 38,842 accounts)</h3>
  {rows(ACCOUNTS, ['Account holder','Active, not suspended','Active, suspended','Inactive','Assessment'], 'minmax(0,2fr) 150px 140px 90px minmax(0,1.6fr)', [1,2,3])}
  <p class="note">“Non-employee” is every account not held by a Fusion-paid employee: 13,375. Last-login dates are not stored in this tenant (F15), so the 30-day-inactivity cut requested cannot be measured from the database; the account list above is the input for that reconciliation once a sign-in export is available.</p>

  <div class="twocol">
    <div>
      <h3 class="h3">IT Security Manager — 12 direct grants (no custom role inherits it)</h3>
      {rows(ITSEC_STATS, ['Holder class','Accounts','Granted'], 'minmax(0,1.6fr) 90px minmax(0,1.4fr)', [1])}
    </div>
    <div>
      <h3 class="h3">IP BI Administrator — 12 direct grants</h3>
      {rows(BIADMIN_STATS, ['Holder class','Accounts','Granted'], 'minmax(0,1.6fr) 90px minmax(0,1.4fr)', [1])}
    </div>
  </div>

  <div class="twocol">
    <div>
      <h3 class="h3">Roles that contain the seeded BI Administrator role (BIAdministrator)</h3>
      {rows(BIADMIN_INHERIT, ['Role code','Role name','Path','Users'], '1.6fr 1.5fr 1.2fr 70px', [3])}
      <p class="note">Anyone holding a role in this table effectively holds BI Administrator.</p>
    </div>
    <div>
      <h3 class="h3">Who effectively holds BI Administrator</h3>
      {rows(BIADMIN_EFFECTIVE, ['Holder class','Active users'], '1fr 140px', [1])}
      <h3 class="h3" style="margin-top:28px">Roles still held by the 3,609 open leaver accounts</h3>
      {rows(TERM_ROLES, ['Role','Leavers'], '1fr 100px', [1])}
    </div>
  </div>

  <h3 class="h3">Areas of responsibility — active on the run date</h3>
  {rows(AOR, ['Responsibility type','Active AoRs','Holders','Held by leavers','Scope used','Locations with no current-employee holder'], 'minmax(0,1.4fr) 100px 80px 150px minmax(0,1.6fr) minmax(0,1.4fr)', [1,2])}
  <p class="note">Coverage reflects direct location and department scope; the HRBP gap may be smaller where a hierarchy-scoped HRBP covers the site.</p>
  <h3 class="h3">Active accounts with no person record — 248</h3>
  {rows(NOPERSON_STATS, ['Account category','Accounts','Note'], 'minmax(0,1.4fr) 90px minmax(0,2fr)', [1])}
</section>''')

sections.append(f'''
<section class="pad" id="sec-nid">
  {h2('National identifiers','Duplicate detection among employees, as defined for this check')}
  <div class="tiles">
    <div class="blueprint tile">{corners()}<div class="v">0</div><div class="t">Employees sharing an SSN with another employee</div></div>
    <div class="blueprint tile">{corners()}<div class="v">0</div><div class="t">Employees with no, placeholder or malformed SSN</div></div>
    <div class="blueprint tile">{corners()}<div class="v">0</div><div class="t">Employees with more than one SSN of the same type</div></div>
    <div class="blueprint tile">{corners()}<div class="v">1</div><div class="t">Employee SSN also on a cancelled-hire record (birth year differs — verify)</div></div>
  </div>
  <p class="note">Ex-employee records and Recruiting candidate records are not treated as duplicate employees. Name and date of birth were checked on the remaining match.</p>
</section>''')

sections.append(f'''
<section class="pad" id="sec-failures">
  {h2('Why reports and processes are failing','Last 90 days: 11,419 errors')}
  <div class="blueprint rootcause">{corners()}
    <div class="eyebrow">Root cause — 49% of all errors</div>
    <h3>The integration status notifications are exception-only bursting reports; when there is nothing to report they fail instead of skipping.</h3>
    <p>The data model behind <em>Scheduled Integration Status</em> (Schedule_DM.xdm) selects extract flow tasks that ran today, after the last successful notification, with a status other than Completed, and bursts one email per schedule date. On an hour with no exceptions the query returns zero rows, BI Publisher raises <code>NO_DATA_TO_PROCESS</code> and ESS records an Error 3–4 seconds after start. Oracle documents this outcome (Doc 1925999.1). The two sibling reports and the Grade Exception, Grievance Action Plan and WFH notifications behave the same way. Failure notification is off on all of them, so the 5,600 red rows have never reached an inbox. The 118 successful runs of the general status report are the hours that actually had something to send.</p>
    <p><strong>Fix:</strong> add a schedule trigger to each data model so BI Publisher marks the hour Skipped, or burst a single “no exceptions” row as a heartbeat; then switch on notify-on-failure so a real failure is visible.</p>
  </div>
  <h3 class="h3">BI Publisher reports with errors (EssBipJob, 90 days)</h3>
  {rows(FAILING_REPORTS, ['Report (/Custom/Human Capital Management/…)','Errors','Runs','Recorded error / cause','Submitter · schedule'], 'minmax(0,2.2fr) 70px 70px minmax(0,1.5fr) minmax(0,1.3fr)', [1,2])}
  <h3 class="h3">Other scheduled processes with errors (90 days)</h3>
  {rows(ESS_TOP, ['Process','Runs as','Errors','Runs','Error text (REQUEST_HISTORY)','Assessment'], 'minmax(0,1.8fr) minmax(0,1fr) 80px 90px minmax(0,1.6fr) minmax(0,1.2fr)', [2,3])}
  <h3 class="h3">Who owns the recurring BI Publisher schedules (90 days)</h3>
  {rows(SCHED, ['Owner class','Recurring schedules','Runs','Runs from personal folders'], 'minmax(0,2fr) 160px 100px 200px', [1,2,3])}
  <h3 class="h3">Payroll flow and HCM extract task failures (PAY_FLOW_TASK_INSTANCES, 90 days)</h3>
  <p class="note">Every parent flow instance in the period reports Completed. The failures are in the child tasks: 2,396 Functional Error, 253 Rolled Back, 114 Incomplete, 524 Execution Started, 48 Errored.</p>
  {rows(FLOW_ERRORS, ['Flow','Task','Status','Count','Last'], 'minmax(0,2fr) minmax(0,1.2fr) minmax(0,1.2fr) 100px 100px', [3])}
</section>''')

PAYROLL_ISSUES = [
 ('1','Assignment payroll-process-group load fails on every run','GENERATE AND LOAD ASSIGNMENT PPG DATA · ORA_PAY_HDL_LOAD in Functional Error 2,159 times in 90 days, last on the run date; parent flow shows Completed.','Workers may sit in the wrong process group, or none, when a run is submitted.','F04'),
 ('2','Inbound pay-affecting feeds erroring at record level','Sedgwick leave 63 · Empower deferral 13 · Empower loan feedback 13 · Alight pension 13 · SIRVA adjustments 13 · Blackbaud 10 · Assigned Payroll FINC data 5 (task errors, 90 days).','Deductions and leave in those files may not be reaching element entries; parents show Completed.','F04'),
 ('3','QuickPay flows left open','493 View SOE tasks in Execution Started, 112 Incomplete, 106 Calculate QuickPay rolled back, 4 errored (90 days).','Locks on the person, noise on every checklist, no record of why.','F08'),
 ('4','Rollbacks on core flows','Payroll Run 34 · Check Payment 28 · Retro Pay 27 · Electronic Payment 26 · Prepayments 20 · Payslip / Archiver 20 · Third-party check 12 · Balance Adjustment 5 · CITI Positive Pay 5 (90 days).','Each is a manual intervention that should carry a reason; none is annotated.','F08'),
 ('5','Payroll reports failing inside flows','Periodic Payroll Activity Report 28 functional errors + 8 rollbacks · Payroll Activity Report 28 · Element Result Report 17 errored · Payslip 7.','Post-run reconciliation reports are not producing on the first attempt.','F08'),
 ('6','Terminated employees with an open assigned payroll','6,685 people with an inactive primary assignment still have an assigned payroll with no end date.','They remain in the run, retro and year-end population until the final close date is set.','F13'),
 ('7','Fast formula compile state','21 single-formula compile errors and 1 failed bulk compile in 30 days; 2,619 of 3,932 non-seeded formula rows carry no compile flag.','A formula that fails to compile keeps executing its previous compiled version.','F08'),
 ('8','Balancing and remittance reports unreliable','Accounting Balancing Report 69 errors / 634 runs across 37 submitters (20 delivery) · Union Dues Remittance 30 / 87 · Third Party Balancing 4 / 4 · Regular Rate Average 4 / 4 · Empower validation scheduled by an external vendor login.','Payroll staff rerun to get output; balancing evidence is incomplete for the cycle.','F09'),
 ('9','Payroll roles on leavers and broad BI access','66 open leaver accounts hold IP Payroll Field Time Administrator, 38 hold IP Payroll Finance; 479 users inherit BI Administrator, which reads every payroll data model.','Pay data exposure and segregation-of-duties gap.','F01, F02, F11'),
 ('10','Costing errors','JCostingJob errored 5 of 52 runs (90 days).','GL costing incomplete for those runs.','F08'),
 ('11','US employees active without an assigned payroll','7 (the other 1,734 unpaid active workers are Mexico and other legislations paid outside Fusion, which is expected).','Likely setup misses; confirm each is intentionally unpaid.','—'),
]
ELEMENTS = [
 ('Supplemental Earnings','139','3','55','84','22 Premium Adjustment elements uncosted','5'),
 ('Absences','100','20','81','19','14 PSL accrual elements uncosted (information, expected)','0'),
 ('Voluntary Deductions','100','4','20','80','all costed','23'),
 ('Standard Earnings','82','0','9','73','7 non-US salary elements uncosted (paid outside Fusion)','0'),
 ('Employer Charges','45','0','12','33','RSA HSP uncosted','0'),
 ('Involuntary Deductions','36','27','28','8','all costed','4'),
 ('Pre-Statutory Deductions','35','0','6','29','all costed','12'),
 ('Information','34','0','3','31','28 uncosted (expected)','2'),
 ('Taxable Benefits','23','0','5','18','DP CDH Plus ImpIn Hrly uncosted','0'),
 ('Tax Deductions','5','0','5','0','—','0'),
 ('Direct Payments','3','0','2','1','all costed','1'),
 ('Balance Initialization','2','1','1','1','—','2'),
 ('Total user-facing','605','55','236','377','24 in-use elements needing costing','50'),
]
PAYROLL_UNCHECKED = [
 'Run results and balances reconciled against a prior period (gross-to-net, employer taxes, YTD balances).',
 'Tax configuration: TRU and jurisdiction coverage, tax card completeness, SUI/SIT registrations.',
 'Element entry validity for the paid population (missing mandatory entries, ended entries with future runs); element input-value defaults and validation formulas.',
 'Retro-notification backlog and unprocessed retro events.',
 'Purge and archive strategy for run results (752M value rows in eight months), element entries and ESS history — purge jobs are scheduled for stage and audit data but not for payroll history.',
 'Costing completeness per run and unallocated costing (suspense) balances.',
 'Third-party payment and involuntary deduction (garnishment) configuration.',
]
sections.append(f'''
<section class="pad" id="sec-payroll">
  {h2('Payroll','Everything in this report that can reach pay, in one place')}
  {rows(PAYROLL_ISSUES, ['#','Issue','Measured','Why it matters to pay','Finding'], '40px minmax(0,1.2fr) minmax(0,2fr) minmax(0,1.4fr) 90px')}
  <h3 class="h3">Payroll elements — user-facing non-seeded elements by classification</h3>
  <p class="note" style="margin-top:0">605 of the 2,275 non-seeded elements are user-facing; the other 1,670 are template-generated. “Used” means at least one element entry since go-live.</p>
  {rows(ELEMENTS, ['Classification','Elements','No eligibility','Unused since go-live','Used','Costing','Created since go-live'], 'minmax(0,1.3fr) 90px 110px 130px 70px minmax(0,1.6fr) 120px', [1,2,3,4,6])}
  <h3 class="h3">Not yet verified</h3>
  <p class="note" style="margin-top:0">These were not measured in this pass and should be run with the payroll team before payroll is called healthy or not. They are a second, run-level pass rather than a flow-table check.</p>
  <ul class="ul">{''.join(f'<li>{e(x)}</li>' for x in PAYROLL_UNCHECKED)}</ul>
</section>''')

RECRUIT_REQS = [('Expired posting','625','347','166','119','91'),('Posted','498','170','90','83','16'),('Unposted (hired count = openings, 375 / 375)','153','92','41','130','23'),('Not Posted (approved, never posted)','132','97','90','192','39'),('Suspended','75','70','42','188','27'),('Scheduled','2','1','0','61','1'),('Open requisitions','1,485','777','429','—','197')]
RECRUIT_PIPE = [('New / To be Reviewed','75,698','57,659','941'),('New / Reviewed','2,148','1,073','29'),('Screening / To be Reviewed · Reviewed','2,598','1,443','58'),('Screening / Phone Screen to be Scheduled','1,209','839','15'),('New / Under Consideration','828','434','86'),('Interview / Interview Scheduled','506','266','50'),('Interview / Interview to be Scheduled','378','190','48'),('Background Check / Initiated','336','95','0'),('Screening / Phone Screen Completed','185','145','2'),('Offer / To be Created','122','102','36'),('Interview / Selected for Offer','45','36','11'),('Offer / Draft · Approved · Extended · Accepted','106','56','33')]
RECRUIT_OFFERS = [('HR / Processed','601','0','—'),('Background Check / Initiated','337','77','external'),('HR / Processing in Progress','182','67','all internal'),('HR / Pending Manual Processing','69','51','all internal'),('Offer / Draft','43','22','external'),('Offer / Accepted (not moved to HR)','30','19','external'),('Background Check / Rejected by Employer','28','1','—'),('Offer / Extended','27','13','external'),('Withdrawn by candidate (offer / BGC / HR)','68','0','—'),('Offer / Rejected by Employer','24','4','—'),('Offer / Approved (not extended)','21','16','external'),('HR / Error During Processing','16','6','all internal')]
sections.append(f'''
<section class="pad" id="sec-recruiting">
  {h2('Recruiting','Requisitions, pipeline and offers on the run date; offers since go-live')}
  <h3 class="h3">Open requisitions by state</h3>
  {rows(RECRUIT_REQS, ['State','Requisitions','Open > 90 days','Open > 180 days','Avg days open','No active applicants'], 'minmax(0,2fr) 120px 130px 130px 120px 150px', [1,2,3,4,5])}
  <div class="twocol">
    <div>
      <h3 class="h3">Active applications on open requisitions (85,000)</h3>
      {rows(RECRUIT_PIPE, ['Phase / state','Applications','Idle > 30 days','Internal'], 'minmax(0,2fr) 110px 120px 90px', [1,2,3])}
    </div>
    <div>
      <h3 class="h3">Offers created since go-live (1,264)</h3>
      {rows(RECRUIT_OFFERS, ['Phase / state','Offers','Idle > 30 days','Type'], 'minmax(0,2fr) 90px 120px 100px', [1,2])}
    </div>
  </div>
</section>''')

sections.append(f'''
<section class="pad" id="sec-modules">
  {h2('Configuration by module','Observed state against Oracle implementation guidance')}
  {rows(MODULES, ['Module','What is configured and in use','Assessment'], 'minmax(0,0.8fr) minmax(0,1.6fr) minmax(0,1.8fr)')}
</section>''')







body = '\n'.join(sections)

page_css = '''
:root{--color-accent:#235CE8;--color-accent-2:#4B99F7;--color-accent-100:#EEF4FE;--color-accent-200:#D9E6FC;--color-accent-300:#BBDEF9;--color-accent-400:#80BCF9;--color-accent-500:#4B99F7;--color-accent-600:#235CE8;--color-accent-700:#184389;--color-accent-800:#12336B;--color-accent-900:#0C2450;--color-bg:#F4F7F9;--color-text:#1d1f20;}
html,body{margin:0;background:var(--color-bg);color:var(--color-text);font-family:var(--font-body);font-size:15px;line-height:1.5;-webkit-font-smoothing:antialiased}
a{color:var(--color-accent-700)} a:hover{color:var(--color-accent-600)}
.wrap{max-width:1240px;margin:0 auto;padding:0 32px 64px;text-wrap:pretty}
header.mast{display:flex;align-items:center;justify-content:space-between;gap:24px;padding:26px 0 18px;border-bottom:1px solid var(--color-divider);flex-wrap:wrap}
header.mast img{height:26px;width:auto;display:block}
header.mast .meta{display:flex;gap:28px;font-size:15px;color:var(--color-neutral-700);flex-wrap:wrap}
header.mast strong{color:var(--color-text);font-weight:600}
nav.toc{position:sticky;top:0;z-index:20;background:var(--color-bg);display:flex;gap:4px 22px;flex-wrap:wrap;padding:12px 0;font-size:15px;border-bottom:1px solid var(--color-divider)}
nav.toc a{text-decoration:none;font-weight:500;color:var(--color-neutral-800);padding:2px 0;border-bottom:2px solid transparent}
nav.toc a:hover{color:var(--color-accent-600)}
nav.toc a.on{color:var(--color-accent-700);border-bottom-color:var(--color-accent-600)}
section[id]{scroll-margin-top:70px}
.titlegrid{display:grid;grid-template-columns:minmax(0,1.5fr) minmax(0,1fr);gap:40px;padding:48px 0 40px;align-items:end}
.eyebrow{font-size:15px;letter-spacing:.12em;text-transform:uppercase;color:var(--color-accent-700);font-weight:600;margin-bottom:14px}
.eyebrow.light{color:var(--color-accent-300);margin-bottom:0}
h1{font-size:60px;line-height:.98;margin:0 0 18px;font-weight:600;letter-spacing:-.01em;font-family:var(--font-heading)}
h1 .acc{color:var(--color-accent-600)}
h2{font-size:36px;margin:0;font-weight:600;font-family:var(--font-heading)}
h2.white{font-size:34px;line-height:1.1;margin:0 0 16px;color:#fff}
h3{font-family:var(--font-heading);font-weight:600}
.h3{font-size:22px;margin:28px 0 10px}
.lede{font-size:18px;max-width:640px;margin:0;color:var(--color-neutral-800)}
.kpis{padding:22px 24px;display:grid;grid-template-columns:1fr 1fr;gap:18px 24px;font-size:15px}
.kpis .k{color:var(--color-neutral-600);font-size:15px}.kpis .v{font-family:var(--font-heading);font-size:30px;font-weight:600;line-height:1.1}
.kpis .span{grid-column:1/-1;border-top:1px solid var(--color-divider);padding-top:14px;color:var(--color-neutral-700)}
.verdict{background:var(--color-accent-700);color:#fff;padding:40px 44px;display:grid;grid-template-columns:200px minmax(0,1fr);gap:40px;align-items:start}
.verdict .big{font-family:var(--font-heading);font-size:112px;line-height:.9;font-weight:600;margin:8px 0 4px}
.verdict .of{font-size:16px;color:var(--color-accent-300)}.verdict .of strong{color:#fff;font-weight:600}
.vlede{font-size:17px;margin:0 0 22px;color:#E3ECFB;max-width:760px}
.sevrow{display:flex;gap:12px;flex-wrap:wrap}
.sevrow .pill{display:flex;align-items:center;gap:10px;border:1px solid rgba(255,255,255,.35);padding:8px 14px;font-size:15px}
.sevrow .pill .n{font-family:var(--font-heading);font-size:22px;font-weight:600;line-height:1}.sevrow .pill .l{color:#E3ECFB}
.sq{width:10px;height:10px;display:inline-block}
.pad{padding:56px 0 8px}
.h2row{display:flex;align-items:baseline;justify-content:space-between;gap:24px;margin-bottom:24px;flex-wrap:wrap}
.sub{font-size:15px;color:var(--color-neutral-700)}
.defgrid{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1.6fr);gap:24px;align-items:start}
.defcard{padding:22px 24px}.defcard p{margin:0;font-size:16px;color:var(--color-neutral-900)}
.domgrid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:20px}
.dom{text-align:left;padding:20px 22px 18px;cursor:pointer;font:inherit;color:inherit;display:flex;flex-direction:column;gap:10px;background:transparent}
.dom:hover{background:var(--color-accent-100)}
.dom .top{display:flex;justify-content:space-between;align-items:baseline;gap:12px}
.dom .name{font-family:var(--font-heading);font-size:22px;font-weight:600;line-height:1.1}
.dom .score{font-family:var(--font-heading);font-size:34px;font-weight:600;line-height:1}
.dom .bar{height:6px;background:var(--color-neutral-200);position:relative}.dom .bar div{position:absolute;inset:0 auto 0 0}
.dom .bot{display:flex;justify-content:space-between;font-size:15px;color:var(--color-neutral-700)}
.dom .blurb{font-size:15px;color:var(--color-neutral-800)}
.filters{display:flex;gap:12px;flex-wrap:wrap;align-items:center;margin-bottom:18px}
.seg{display:inline-flex;border:1px solid var(--color-divider);flex-wrap:wrap}
.seg button{font:inherit;font-size:15px;padding:8px 16px;border:0;border-left:1px solid var(--color-divider);cursor:pointer;background:transparent;color:var(--color-text);font-weight:500}
.seg button:first-child{border-left:0}.seg button:hover{background:var(--color-accent-100)}.seg button.on{background:var(--color-accent-700);color:#fff}
.reg{border-top:2px solid var(--color-text)}
.reghead,.frow-btn{display:grid;grid-template-columns:64px 120px minmax(0,1fr) 190px 150px;gap:16px}
.reghead{padding:10px 12px;font-size:15px;letter-spacing:.06em;text-transform:uppercase;color:var(--color-neutral-700);font-weight:600;border-bottom:1px solid var(--color-divider)}
.find{border-bottom:1px solid var(--color-divider)}
.frow-btn{padding:16px 12px;width:100%;text-align:left;font:inherit;color:inherit;background:transparent;border:0;cursor:pointer;align-items:center}
.frow-btn:hover,.frow-btn.open{background:var(--color-accent-100)}
.frow-btn .id{font-family:var(--font-heading);font-size:18px;font-weight:600;color:var(--color-neutral-700)}
.frow-btn .sev{display:inline-flex;align-items:center;gap:8px;font-size:15px;font-weight:600}
.frow-btn .title{font-size:17px;font-weight:500;line-height:1.3}
.frow-btn .dom{font-size:15px;color:var(--color-neutral-700);padding:0;display:block}
.frow-btn .met{font-family:var(--font-heading);font-size:24px;font-weight:600;text-align:right;line-height:1}
.frow-btn .met span{display:block;font-family:var(--font-body);font-size:15px;font-weight:400;color:var(--color-neutral-700);margin-top:2px}
.fbody{display:none;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:28px 40px;padding:8px 12px 28px 92px;font-size:15px}
.fbody.open{display:grid}
.fbody .lab{font-size:15px;letter-spacing:.08em;text-transform:uppercase;color:var(--color-accent-700);font-weight:600;margin-bottom:8px}
.fbody p{margin:0 0 18px;color:var(--color-neutral-900);font-size:16px}
.fbody ol{margin:0 0 18px;padding-left:20px;color:var(--color-neutral-900);font-size:16px;display:grid;gap:6px}
.fbody .meta{display:grid;grid-template-columns:auto 1fr;gap:6px 14px;font-size:15px;color:var(--color-neutral-700);border-top:1px solid var(--color-divider);padding-top:12px}
.charts{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:28px}
.chart{padding:24px 26px}.chart h3{font-size:24px;margin:0 0 4px}.chart p.sub{margin:0 0 18px}
.bars{display:flex;align-items:flex-end;gap:6px;height:180px;border-bottom:1px solid var(--color-divider)}
.bars .col{flex:1;height:100%;display:flex;align-items:flex-end;gap:2px;cursor:default}
.bars .col div{flex:1;transition:background .15s}
.barlabels{display:flex;gap:6px;margin-top:6px}.barlabels span{flex:1;text-align:center;font-size:15px;color:var(--color-neutral-700)}
.hover{margin-top:14px;min-height:24px;font-size:16px;font-weight:500}
.hbars{display:grid;gap:10px}
.hbar{display:grid;grid-template-columns:220px minmax(0,1fr) 60px;gap:12px;align-items:center;font-size:15px;cursor:default}
.hbar .lab{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.hbar .trk{height:14px;background:var(--color-neutral-200)}.hbar .trk div{height:100%}
.hbar .val{text-align:right;font-weight:600}
.tbl{display:grid;border-top:2px solid var(--color-text);font-size:15px}
.tbl .th,.tbl .tr{display:contents}
.tbl .th span{padding:10px 8px;font-size:15px;letter-spacing:.06em;text-transform:uppercase;color:var(--color-neutral-700);font-weight:600;border-bottom:1px solid var(--color-divider)}
.tbl .tr span{padding:10px 8px;border-bottom:1px solid var(--color-divider);color:var(--color-neutral-900);word-break:break-word}
.tbl .tr span:first-child{font-weight:500;color:var(--color-text)}
.ul{margin:8px 0 0;padding-left:22px;font-size:16px;color:var(--color-neutral-900);display:grid;gap:6px;max-width:900px}
.note{font-size:15px;color:var(--color-neutral-700);margin:12px 0 0;max-width:900px}
.twocol{display:grid;grid-template-columns:repeat(auto-fit,minmax(460px,1fr));gap:0 40px}
.chips{margin:0}.chip{display:inline-block;border:1px solid var(--color-divider);padding:3px 9px;margin:0 6px 6px 0;font-size:15px;font-family:ui-monospace,Menlo,monospace}
.tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:20px}
.tile{padding:20px 22px}.tile .v{font-family:var(--font-heading);font-size:40px;font-weight:600;line-height:1;color:var(--color-accent-600)}.tile .t{font-size:15px;color:var(--color-neutral-700);margin-top:8px}
.det{margin-top:18px}.det summary{cursor:pointer;font-weight:500;font-size:16px;color:var(--color-accent-700);margin-bottom:10px}
.rootcause{padding:26px 28px;margin-bottom:12px;background:#fff}.rootcause h3{font-size:26px;margin:0 0 12px;line-height:1.15}.rootcause p{margin:0 0 12px;font-size:16px;color:var(--color-neutral-900);max-width:1000px}
code{font-family:ui-monospace,Menlo,monospace;font-size:14px;background:var(--color-neutral-100);padding:1px 5px}
.strengths{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:20px;margin-top:20px}
.scard{padding:20px 22px}.scard .m{font-family:var(--font-heading);font-size:34px;font-weight:600;line-height:1;color:var(--color-accent-600);margin-bottom:8px}.scard .t{font-size:17px;font-weight:500;margin-bottom:4px}.scard .n{font-size:15px;color:var(--color-neutral-700)}
.foot{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:0 48px;border-top:2px solid var(--color-text);margin-top:20px}
.frow{display:flex;justify-content:space-between;gap:16px;padding:12px 0;border-bottom:1px solid var(--color-divider);font-size:15px}
.frow span:first-child{color:var(--color-neutral-800)}.frow span:last-child{font-weight:600;font-variant-numeric:tabular-nums;text-align:right}
.method{padding:56px 0 24px;display:grid;grid-template-columns:minmax(0,1fr) minmax(0,2fr);gap:40px}
.mtext{font-size:16px;color:var(--color-neutral-900);display:grid;gap:12px}.mtext p{margin:0}
footer{border-top:1px solid var(--color-divider);padding:20px 0 0;display:flex;justify-content:space-between;gap:24px;font-size:15px;color:var(--color-neutral-700);flex-wrap:wrap}
@media (max-width:900px){.titlegrid,.verdict,.defgrid,.method{grid-template-columns:1fr}.reghead,.frow-btn{grid-template-columns:56px 100px minmax(0,1fr) 120px}.reghead span:nth-child(4),.frow-btn .dom{display:none}.fbody{grid-template-columns:1fr;padding-left:12px}h1{font-size:44px}}

/* reveal-on-scroll: whole section at once, when its top reaches the viewport */
.rv-anim{opacity:0;transform:scale(.5);transform-origin:50% 50%;transition:opacity 1.1s cubic-bezier(.22,1,.36,1),transform 1.3s cubic-bezier(.22,1,.36,1);will-change:opacity,transform}
section.rv.in>.rv-anim,section.rv.in.rv-anim{opacity:1;transform:none}
.dom .bar div,.hbar .trk div{transition:width 1.4s cubic-bezier(.16,.6,.2,1),background .15s}
.bars .col div{transition:height 1.4s cubic-bezier(.16,.6,.2,1),background .15s}
.fbody{overflow:hidden}
.fbody.open{animation:fbIn .5s ease}
@keyframes fbIn{from{opacity:0;transform:translateY(-6px)}to{opacity:1;transform:none}}
.blueprint{transition:box-shadow .2s ease,transform .2s ease}
.tile:hover,.scard:hover,.dom:hover{box-shadow:var(--shadow-md);transform:translateY(-2px)}
@media (prefers-reduced-motion: reduce){.rv-anim{opacity:1;transform:none!important;transition:none}.dom .bar div,.hbar .trk div,.bars .col div{transition:none}}
@media print{.rv-anim{opacity:1!important;transform:none!important}}
@media print{.no-print{display:none!important}body{background:#fff}.fbody{display:grid!important}.det[open],.det{display:block}details>*{display:block}}
'''

js = '''
const SEV=%s; const FINDINGS=%s; const DOMAINS=%s; const TERMS=%s; const HIRES=%s; const ESS=%s;
const fmt=n=>n.toLocaleString('en-US');
const sevOrder=['Critical','High','Medium','Low'];
const state={sev:'All',dom:'All',open:{},allOpen:false};
const scoreColor=s=>s<50?'#F4900C':s<70?'#184389':'#235CE8';
const overall=Math.round(DOMAINS.reduce((a,d)=>a+d.score,0)/DOMAINS.length);
document.getElementById('overallScore').textContent=overall;
document.getElementById('overallLabel').textContent=overall<50?'At risk':overall<70?'Needs attention':'Healthy';
document.getElementById('sevCounts').innerHTML=sevOrder.map(s=>`<div class="pill"><span class="sq" style="background:${SEV[s]}"></span><span class="n">${FINDINGS.filter(f=>f.severity===s).length}</span><span class="l">${s}</span></div>`).join('');
function render(){
  const F=FINDINGS;
  document.getElementById('domains').innerHTML=DOMAINS.map(d=>{const fs=F.filter(f=>f.domain===d.name);const top=sevOrder.find(s=>fs.some(f=>f.severity===s));const sel=state.dom===d.name;
    return `<button type="button" class="blueprint dom" data-dom="${d.name}" style="${sel?'background:var(--color-accent-100);border-color:var(--color-accent-600)':''}"><i class="corner tl"></i><i class="corner tr"></i><i class="corner bl"></i><i class="corner br"></i>
      <div class="top"><span class="name">${d.name}</span><span class="score" style="color:${scoreColor(d.score)}">${d.score}</span></div>
      <div class="bar"><div data-w="${d.score}%%" style="width:0;background:${scoreColor(d.score)}"></div></div>
      <div class="blurb">${d.blurb}</div>
      <div class="bot"><span>${fs.length} finding${fs.length===1?'':'s'}</span><span>${top?'Highest: '+top:'No findings'}</span></div></button>`}).join('');
  if(document.getElementById('domains').classList.contains('shown')){document.querySelectorAll('.dom [data-w]').forEach(x=>x.style.width=x.dataset.w);}
  document.querySelectorAll('.dom[data-dom]').forEach(b=>b.onclick=()=>{state.dom=state.dom===b.dataset.dom?'All':b.dataset.dom;render();});
  const domNames=['All',...new Set(F.map(f=>f.domain))];
  document.getElementById('sevFilters').innerHTML=['All',...sevOrder].map(s=>`<button type="button" class="${state.sev===s?'on':''}" data-sev="${s}">${s}</button>`).join('');
  document.getElementById('domFilters').innerHTML=domNames.map(s=>`<button type="button" class="${state.dom===s?'on':''}" data-domf="${s}">${s}</button>`).join('');
  document.querySelectorAll('[data-sev]').forEach(b=>b.onclick=()=>{state.sev=b.dataset.sev;render();});
  document.querySelectorAll('[data-domf]').forEach(b=>b.onclick=()=>{state.dom=b.dataset.domf;render();});
  const vis=F.filter(f=>(state.sev==='All'||f.severity===state.sev)&&(state.dom==='All'||f.domain===state.dom));
  document.getElementById('visibleCount').textContent=(vis.length===F.length?F.length+' findings':vis.length+' of '+F.length+' findings')+' · select a row for evidence and remediation';
  document.getElementById('toggleAll').textContent=state.allOpen?'Collapse all':'Expand all';
  document.getElementById('findings').innerHTML=vis.map(f=>{const o=state.open[f.id]!==undefined?state.open[f.id]:state.allOpen;
    return `<div class="find"><button type="button" class="frow-btn ${o?'open':''}" data-id="${f.id}" aria-expanded="${o}">
      <span class="id">${f.id}</span><span class="sev" style="color:${SEV[f.severity]}"><span class="sq" style="background:${SEV[f.severity]}"></span>${f.severity}</span>
      <span class="title">${f.title}</span><span class="dom">${f.domain}</span><span class="met">${f.metric}<span>${f.metricLabel}</span></span></button>
      <div class="fbody ${o?'open':''}"><div><div class="lab">What we found</div><p>${f.evidence}</p><div class="lab">Why it matters</div><p>${f.impact}</p></div>
      <div><div class="lab">Recommended action</div><ol>${f.actions.map(a=>`<li>${a}</li>`).join('')}</ol>
      <div class="meta"><span style="font-weight:600">Effort</span><span>${f.effort}</span><span style="font-weight:600">Owner</span><span>${f.owner}</span><span style="font-weight:600">Reference</span><span>${f.reference}</span></div></div></div></div>`}).join('');
  document.querySelectorAll('.frow-btn').forEach(b=>b.onclick=()=>{const id=b.dataset.id;const cur=state.open[id]!==undefined?state.open[id]:state.allOpen;state.open[id]=!cur;render();});
}
const tocLinks=[...document.querySelectorAll('#toc a')];const tocTargets=tocLinks.map(a=>document.querySelector(a.getAttribute('href')));
function updToc(){const y=window.scrollY+90;let cur=0;tocTargets.forEach((t,i)=>{if(t&&t.offsetTop<=y)cur=i;});if(window.innerHeight+window.scrollY>=document.body.scrollHeight-4)cur=tocLinks.length-1;tocLinks.forEach((a,i)=>a.classList.toggle('on',i===cur));}
window.addEventListener('scroll',updToc,{passive:true});updToc();
document.getElementById('toggleAll').onclick=()=>{state.allOpen=!state.allOpen;state.open={};render();};
render();
// charts
const tmax=Math.max(...TERMS.map(t=>t[1]));
const tb=document.getElementById('termBars'), tl=document.getElementById('termLabels'), th=document.getElementById('termHover');
tb.innerHTML=TERMS.map((t,i)=>`<div class="col" data-i="${i}"><div data-h="${Math.max(2,Math.round(HIRES[i][1]/tmax*100))}%%" style="height:0;background:#BBDEF9"></div><div data-h="${Math.max(2,Math.round(t[1]/tmax*100))}%%" style="height:0;background:#4B99F7"></div></div>`).join('');
tl.innerHTML=TERMS.map(t=>`<span>${t[0]}</span>`).join('');
document.querySelectorAll('.bars .col').forEach(c=>{c.onmouseenter=()=>{const i=+c.dataset.i;th.textContent=`${TERMS[i][0]}: ${fmt(TERMS[i][1])} terminations, ${fmt(HIRES[i][1])} hires`;c.children[1].style.background='#F4900C';};c.onmouseleave=()=>{th.textContent='Hover a month for the exact counts. Light bars are hires, dark bars terminations.';c.children[1].style.background='#4B99F7';};});
th.textContent='Hover a month for the exact counts. Light bars are hires, dark bars terminations.';
const emax=Math.max(...ESS.map(e=>e[1]));const eb=document.getElementById('essBars'),eh=document.getElementById('essHover');
eb.innerHTML=ESS.map((e,i)=>`<div class="hbar" data-i="${i}"><span class="lab" title="${e[0]}">${e[0]}</span><div class="trk"><div data-w="${Math.max(1,Math.round(e[1]/emax*100))}%%" style="width:0;background:${e[1]/(e[1]+e[2])>0.2?'#184389':'#4B99F7'}"></div></div><span class="val">${fmt(e[1])}</span></div>`).join('');
document.querySelectorAll('.hbar').forEach(r=>{const e=ESS[+r.dataset.i];const bar=r.querySelector('.trk div');const base=bar.style.background;r.onmouseenter=()=>{eh.textContent=`${e[0]}: ${fmt(e[1])} errors, ${fmt(e[2])} successes — ${(100*e[2]/(e[1]+e[2])).toFixed(1)}%% success rate`;bar.style.background='#F4900C';};r.onmouseleave=()=>{eh.textContent='Hover a job for its success rate.';bar.style.background=base;};});
''' % (json.dumps(SEV), json.dumps(FINDINGS), json.dumps(DOMAINS), json.dumps(TERMS), json.dumps(HIRES), json.dumps(ESS30))

js2 = r'''
// appear effect: each section scales up from 50% and fades in as it enters the viewport (replays on every entry); nav links use an animated scroll
(function(){
  const secs=[...document.querySelectorAll('.wrap > section')];
  secs.forEach(s=>{ s.classList.add('rv'); const isGrid=getComputedStyle(s).display==='grid'; if(isGrid){ s.classList.add('rv-anim'); } else { const w=document.createElement('div'); w.className='rv-inner rv-anim'; while(s.firstChild) w.appendChild(s.firstChild); s.appendChild(w); } });
  function show(s){ s.classList.add('in'); s.querySelectorAll('[data-w]').forEach(x=>x.style.width=x.dataset.w); s.querySelectorAll('[data-h]').forEach(x=>x.style.height=x.dataset.h); s.querySelectorAll('.domgrid,.chart').forEach(g=>g.classList.add('shown')); }
  function hide(s){ s.classList.remove('in'); s.querySelectorAll('[data-w]').forEach(x=>x.style.width='0'); s.querySelectorAll('[data-h]').forEach(x=>x.style.height='0'); s.querySelectorAll('.domgrid,.chart').forEach(g=>g.classList.remove('shown')); }
  const enter=new IntersectionObserver(es=>es.forEach(e=>{ if(e.isIntersecting) show(e.target); }),{threshold:0,rootMargin:'0px 0px -12% 0px'});
  const leave=new IntersectionObserver(es=>es.forEach(e=>{ if(!e.isIntersecting) hide(e.target); }),{threshold:0,rootMargin:'0px'});
  secs.forEach(s=>{enter.observe(s);leave.observe(s);});
  document.querySelectorAll('#toc a').forEach(a=>a.addEventListener('click',ev=>{ ev.preventDefault(); const tgt=document.querySelector(a.getAttribute('href')); if(!tgt) return; let y=0; for(let el=tgt; el; el=el.offsetParent) y+=el.offsetTop; y-=64; window.scrollTo({top:y,behavior:'smooth'}); history.replaceState(null,'',a.getAttribute('href')); }));
  function countUp(el,to,dur){const start=performance.now();(function step(t){const p=Math.min(1,(t-start)/dur);const eased=1-Math.pow(1-p,3);el.textContent=Math.round(to*eased);if(p<1)requestAnimationFrame(step);})(start);}
  const sc=document.getElementById('overallScore');const target=parseInt(sc.textContent,10);sc.textContent='0';setTimeout(()=>countUp(sc,target,1800),300);
})();
'''

toc = ['Scorecard','Findings','Access','National IDs','Failing processes','Configuration','Method']

html = f'''<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>IP PROD — Oracle Fusion Cloud HCM Health Check · September 2026</title>
<style>{font_css}</style>
<style>{ds_css}</style>
<style>{page_css}</style>
</head><body><div class="wrap">
<header class="mast">
  <img src="data:image/svg+xml;base64,{base64.b64encode(logo.encode()).decode()}" alt="The Hackett Group">
  <div class="meta"><span>HCM Implementation Health Check</span><span>Environment: <strong>IP PROD</strong></span><span>{RUN_DATE}</span></div>
</header>
<nav class="toc no-print" id="toc">
  <a href="#sec-summary">Summary</a><a href="#sec-footprint">Footprint</a><a href="#sec-definitions">Definitions</a><a href="#sec-strengths">Working well</a><a href="#sec-scorecard">Scorecard</a><a href="#sec-findings">Findings</a><a href="#sec-trends">Trends</a><a href="#sec-access">Access</a><a href="#sec-nid">National IDs</a><a href="#sec-failures">Failing processes</a><a href="#sec-payroll">Payroll</a><a href="#sec-recruiting">Recruiting</a><a href="#sec-modules">Modules</a>
</nav>
{body}
<footer><span>© 2026 The Hackett Group, Inc. All Rights Reserved. Prepared by Jonathan Stevenson.</span><span>Enabling Digital World Class® Performance</span></footer>
</div>
<script>{js}{js2}</script>
</body></html>'''

open(os.environ.get('HC_OUT','/mnt/user-data/outputs/HCM_Health_Check.html'),'w').write(html)
print(len(html))
