# Lessons and decisions: GP customer conversion

What has actually happened in Regal customer-conversion work up to 2026-10-16, so this skill never repeats a mistake or re-asks a settled question. It covers the US AX stream (the proven pattern), the UK AX (Cineworld) stream, and the UK GP (Picturehouse) stream that this skill serves.

Source files are cited by short name. They all sit in the session research folder `scratchpad/research/`:
- `lessons` = `conversion-lessons.md` (mined from project docs and Claude Code transcripts; its own ids such as `KF-C54`, `MAP-C19`, `CFG-C17`, `F6` are kept).
- `gp-schema` = `gp-customer-schema.md` (live GP profile, 2026-10-16, including its "Verification pass").
- `fusion-model` = `fusion-customer-model.md` (live DEV2 read, 2026-10-16).
- `atp/<file>` = exports of Greenlight conversations and records (the chat tool the Regal team uses). Greenlight's user is not always Jonathan, so turns there are attributed to "the Greenlight user".

When two sources disagree, this file says so and prefers the observed system state.

**Correction to `lessons`.** Its framing says no GP customer was ever loaded into Fusion. That is wrong. DEV2 was queried on 2026-10-16 and holds **25 GP accounts**, created by batches `GP_PH_PROVING_5`, `GP_PH_EXPAND20_PREVIEW` and `GP_PH_EXPAND20_COMMIT` (`fusion-model` sections 3.1 and 5). The 2026-10-10 Greenlight read also saw "GP 25" (`atp/conv-uk-load-dev2.md`, 2026-10-10 16:27). No transcript or Greenlight thread in the inputs records who ran those batches or how.

## Contents
1. [Timeline](#1-timeline)
2. [What worked](#2-what-worked)
3. [What broke](#3-what-broke)
4. [Decisions register](#4-decisions-register)
5. [Jonathan's working rules](#5-jonathans-working-rules)
6. [Open questions](#6-open-questions)
7. [DQ findings already recorded in Greenlight](#7-dq-findings-already-recorded-in-greenlight)

---

## 1. Timeline

| Date | Event | Source |
|---|---|---|
| 2026-05-21 | GP Picturehouse customer extract delivered as Excel: 9,523 rows, 8,364 customers, already in Fusion-import shape | `lessons` 2.2 |
| 2026-09-01 | Live GP counts: PHTRA 8,484, PHEN2 1,167, PHBOO 18, PHGAP 0 (total 9,669) | `lessons` 2.1 |
| 2026-09-12 | Greenlight profiles the AX customer master. First Customers DQ findings recorded | `atp/conv-profile-extract.md`, `atp/dq-findings-customers.md` |
| 2026-09-15 | DEV2 target facts read: template is 19 sheets, no GP or AX source system yet | `lessons` 2.4 |
| 2026-09-16 | First DEV2 customer batch `2026091601`. Source system `AX2012` registered in DEV2 | `lessons` 2.5 (CFG-C35); `atp/conv-us-golden.md` |
| 2026-09-17 | Load fails because batch id `2026091701` already held another user's batch | `lessons` F6 |
| 2026-09-18 | Preview then commit on the same batch `2026091801` (requests 430970 / 430998) | `lessons` KF-C72 |
| 2026-09-19/20 | Greenlight 26C thread builds a US AX FBDI for "A24" (13 accounts) and 20 Poland customers | `atp/conv-template-26c.md` |
| 2026-09-21 | Single-customer proof: 0016026 previewed (`2026092101`), committed (`2026092102`). One preview ran on the wrong tenant | `lessons` 3.1 #1, F9 |
| 2026-09-22 | "5 customers loaded" turns out to be preview only. Re-run as `2026092201` / `2026092202` | `lessons` F10 |
| 2026-09-23 | 857 US AX accounts loaded in nine zips (22 rejected). Source system `GP` registered in DEV2 | `lessons` 3.1 #2; `fusion-model` 2.3 |
| 2026-09-24 | Greenlight builds 100 PHTRA customers plus 100 invoices as FBDI files, reference `GP-PH`. No load recorded | `atp/conv-template-26c.md` 2026-09-24 01:54 to 02:08 |
| 2026-09-26 | Greenlight finds the required `*Part Site Use Type` column cannot be filled by `fill_template` | `atp/conv-add-template.md` |
| 2026-09-29 | Six UK-GP DQ findings recorded | `atp/dq-findings-customers.md` |
| 2026-09-30 | Runbook shows the Customer object still in Phase 1 (Profile) | `atp/conv-runbook-status.md` |
| 2026-10-07/08 | US AX 5 (`2026100701`) previewed and committed on the same id, 98 records. UK CW `UK_CW20_EXPAND_20` (`2026100803`) committed, 537 records | `atp/conv-uk-load-dev2.md` 2026-10-13 11:53 (job spec) |
| 2026-10-08 | `2026100703` `GP_PH_PROVING_5` COMPLETED | `fusion-model` 5 |
| 2026-10-09 | `2026100840` `GP_PH_EXPAND20_PREVIEW` COMPL_WHATIF, then `2026100841` `GP_PH_EXPAND20_COMMIT` COMPLETED (25 GP accounts in total) | `fusion-model` 5 |
| 2026-10-09 | Greenlight GP profiling: 322 customers with open AR (PHTRA 156, PHEN2 166, PHBOO 0). 10 GP findings recorded | `atp/conv-profiling-help.md` |
| 2026-10-10 | Greenlight reads DEV2: 743 accounts (AX2012 664, EXACT 27, GP 25). Builds a UK AX 5-customer file; masking corrupts names and e-mails | `atp/conv-uk-load-dev2.md` |
| 2026-10-13 | DEV2 review workbook and the DEV2 job specification added. US AX 5-customer request in a separate thread | `atp/conv-uk-load-dev2.md`; `atp/conv-ax-import.md` |
| 2026-10-14 | New UK AX five (batch `2026101401`). Upload preview shows stray template rows on 11 unfilled tabs | `atp/conv-uk-load-dev2.md` |
| 2026-10-15 | Blank 26C template fixes the stray rows. Zip uploaded to UCM (doc 414839); app restamps batch to `2026101501`. Submission left to the user, outcome not recorded | `atp/conv-uk-load-dev2.md` 10:44 |
| 2026-10-15 | US AX "golden" fill: 2,964 customers into the Dev1 workbook, not loaded. UK CW full fill: 9,398 customers for DEV1, not loaded | `atp/golden-customer-summary.md`; `atp/conv-uk-cw.md` |
| 2026-10-16 | Greenlight UK-PH fill: 9,669 GP customers into the Dev1 workbook, 3 DQ findings, DQ deck. Not loaded | `atp/conv-uk-ph.md` |
| 2026-10-16 | This research: live GP profile and verification pass, DEV2 read (746 accounts, 25 GP) | `gp-schema`; `fusion-model` |

---

## 2. What worked

1. **Single customer first, then five, then a batch of tens to hundreds.** Evidence: 0016026 on 2026-09-21, five on 2026-09-22, 857 on 2026-09-23 (`lessons` 3.1 #1-2). The GP stream followed the same ladder: `GP_PH_PROVING_5`, then `GP_PH_EXPAND20` (`fusion-model` 5). Why: each step exposes the next validation layer while a failure is still cheap to diagnose.
2. **The GP batch pattern that loaded.** Source system `GP` on every entity. Party OSR = account OSR = `ACCOUNT_NUMBER` = `<COMPANY>-<CUSTNMBR>` (for example `PHEN2-D00189`). Site OSRs `<cust>-MAIN`, site-use OSR `<cust>-MAIN-BILL_TO`. `SET_CODE` `ENTERPRISE`. Profile DEFAULT / AR Manager / Net 30 / Monthly. Profile ORG_ID 300000004842930 (`RGE_UK_PH_GBP_BU`). Evidence: batch `2026100703`, COMPLETED with import status S (`fusion-model` 2.2, 3.1). Why: the company prefix makes the key unique across GP companies, and every child carries its own OS+OSR and its parent's.
3. **Preview, then commit.** GP used a new id for the commit (`2026100840` preview, then `2026100841` commit). The AX stream also committed in place with argument 14 explicitly `N` (`2026091801`, `2026100701`; four batch ids per the job spec). Evidence: `fusion-model` 5; `lessons` 3.1 #7; `atp/conv-uk-load-dev2.md` 2026-10-13 11:53. Why: preview catches party, location, site and account errors before anything is created.
4. **Verify in the registry tables, never in the job summary.** A profile import reported "6 inserted, 0 errors" while `HZ_CUSTOMER_PROFILES_F` held 0 rows (`lessons` 3.1 #3, MAP-C19). Why: the batch summary counts interface rows, not created records.
5. **Subtract what already exists before building.** OPENAR batch 1 collided on two accounts loaded earlier; the population was rebuilt as 885 minus 6 (`lessons` F7). On 2026-10-14 Greenlight dropped candidates whose party name already existed in DEV2, for example True Brit Entertainment, Motion Picture Solutions and STUDIOCANAL (`atp/conv-uk-load-dev2.md` 13:09). Why: an insert on an existing OS/OSR raises `HZ_DUPLICATE_COMBINATION`.
6. **Query the source live instead of trusting a delivered file.** The AX extract was missing 695 of 1,311 open-balance customers (`lessons` F18, DEL-14). For GP, live queries found the cross-company number collision that the May extract hides (`gp-schema` 5.4). Why: delivered extracts carry undocumented filters.
7. **Reconcile with a boundary identity.** LOAD + HELD + REJECT = source rows, with an independent recompute (`lessons` 3.1 #6, REC-06). Why: it proves nothing was silently dropped.
8. **Start from a truly blank template.** On 2026-10-15 the user supplied `CustomerImportTemplate_26c_BLANK.xlsm` (4 header rows per sheet). The upload preview then listed only the 8 filled tabs (`atp/conv-uk-load-dev2.md` 07:14). Why: Oracle's template and the "Dev1" workbook ship example rows on unfilled tabs.
9. **Name the service account.** The customer import job (`CDMAutoBulkImportJob`, loader interface 4, UCM `fin$/receivables$/import$`) appeared only once "ERP Conversion Service Account" was passed (`atp/conv-uk-load-dev2.md` 2026-10-14 13:09).
10. **Quarantine bad values, never guess.** Multi-address e-mail fields were split, classified and quarantined (`lessons` MAP-C15/C23). The first version routed two customers' invoices to Regal internal addresses, and only the independent verifier caught it.
11. **Profile each GP company before filling.** On 2026-10-09 Greenlight counted RM00101 per company database and found no duplicate CUSTNMBR within any one company. The 2026-10-16 profile then measured the collision across companies (`atp/conv-profiling-help.md`; `gp-schema` 5.4). Why: within-company uniqueness and cross-company collision are different facts, and the key design needs both.
12. **Read the DEV2 state before choosing customers.** On 2026-10-14 Greenlight listed the 25 UK AX2012 accounts already in DEV2 and checked each candidate by account number and party name before building (`atp/conv-uk-load-dev2.md` 13:09). Why: it is cheaper to drop a candidate than to unpick a duplicate party.
13. **Show the upload preview before uploading.** The 2026-10-14 dry-run upload preview exposed the stray template rows before anything reached UCM (`atp/conv-uk-load-dev2.md` 13:15). Why: the preview lists row counts for every sheet in the package, including sheets nobody filled.

---

## 3. What broke

Each item: symptom, root cause, fix, evidence.

### 3.1 Load mechanics (all streams)
1. **Profile rows reported but not created.** *Symptom:* batch says profiles imported, `HZ_CUSTOMER_PROFILES_F` has none. *Cause:* profile rows were sent without their account row in the same batch. *Fix:* send the account row (U) and the profile (I) together; profiles are always INSERT. Wait about 30 s after the job ends before checking. *Evidence:* `lessons` 3.1 #8-9, F4 (batches ...5412, ...5459 failed; ...5509 worked; KF-C54).
2. **Preview mistaken for a load.** *Symptom:* "we loaded the 5 customers", but the batch was `COMPL_WHATIF`. *Cause:* the script sent a blank argument 14. Blank imports nothing. *Fix:* always pass Y or N explicitly, and read the batch status before reporting. *Evidence:* `lessons` F10 (2026-09-22). Jonathan: "We need to ACTUALLY LOAD THE CUSTOMERS".
3. **Preview does not validate the profile.** *Symptom:* clean preview, failed commit on profiles. *Cause:* the profile is absent from `hz_imp_entity_details` in preview. *Fix:* expect profile errors only at commit. *Evidence:* `lessons` F11 (KF-C71); repeated by Greenlight on 2026-10-14.
4. **Preview versus commit on the same id: sources disagree.** The job spec says a preview batch can be committed in place (four batch ids). The Greenlight app says "preview burns its id, so the commit is a new upload under a new id" (`atp/conv-uk-load-dev2.md` 2026-10-14 13:09). The GP batches used a new id. *Default:* new id for the commit, the same as GP did.
5. **Batch-id collision.** *Symptom:* `CDMAutoBulkImportJob` ends in error and creates no customer. *Cause:* id `2026091701` already held another user's batch. *Fix:* query `HZ_IMP_BATCH_SUMMARY` for the day's range before building. *Evidence:* `lessons` F6 (KF-C75).
6. **Batch-id format.** `20261010001` (11 digits) does not fit; the job needs 10 digits, `YYYYMMDDnn`. The Greenlight upload also restamps the batch to a free id (`2026101401` became `2026101501`). *Evidence:* `atp/conv-uk-load-dev2.md` 2026-10-14 13:15 and 2026-10-15 10:44. The 2026-10-16 UK-PH fill used `20261016` (8 digits), so it must be restamped.
7. **"Create the batch in Manage Data Import Batches first" is wrong.** Two Greenlight summaries say this (`atp/conv-uk-cw.md`; `atp/golden-customer-summary.md`). The proven path shows `CDMAutoBulkImportJob` creates the batch itself (`lessons` 2.5 #3, CFG-C35).
8. **Wrong tenant.** *Symptom:* a preview ran on `iartqy-dev1`. *Cause:* the host was typed by hand. *Fix:* confirm the host against the registered pod list. The target is `ichqjb-dev2`. *Evidence:* `lessons` F9 (2026-09-21). Related: the Greenlight workbooks are "Dev1" templates carrying DEV1 values (CW-PH UK BU 300000006310472), while DEV2's BU is 300000004842930 (`atp/conv-uk-load-dev2.md` 2026-10-10; `atp/conv-uk-cw.md`).
9. **Duplicate combination on re-load.** *Symptom:* `HZ_DUPLICATE_COMBINATION` is the top DEV2 error: 48 on parties, 36 on contact points, 24 each on locations, party sites and account sites, 20 on accounts. *Cause:* the same OS/OSR was inserted twice. *Fix:* use INSERT_UPDATE_FLAG `U` or new references, and subtract loaded accounts first. *Evidence:* `fusion-model` 2.4 #1; `lessons` F7 (36 error rows on two accounts, 2026-09-23).
10. **Orphan child rows.** `HZ_IMP_INVAL_PARENT_ENTITY_REF` occurs on accounts pointing at a party OSR that is neither in the batch nor in Fusion. `AR_CUSTIMP_PF_BAD_CUST_REF` occurred 20 times on EXACT profiles. Contact points failed `HZ_IMP_MISSING_PARENT` (24) until the person-party keys were populated beside the relationship keys. *Fix:* every row carries its parent's OS+OSR, built from one key function. *Evidence:* `fusion-model` 2.4 #2; `lessons` F2 (MAP-C17).
11. **Missing class code loads silently.** *Symptom:* 2,537 of 2,537 AX accounts loaded with no class. *Cause:* a `CUSTOMER_CLASS_CODE` absent from the lookup stages empty, and the load does not fail. *Fix:* the code must exist before the load; check `CUSTOMER_CLASS_CODE` after it. *Evidence:* `lessons` CFG-C19 (KF-C74). The GP batches used `B2B`, which exists in DEV2 (`fusion-model` 3.1).
12. **Address validation at State level.** *Symptom:* 85 of 2,876 US locations rejected. *Cause:* DEV2 US validation is Error at State level. *Evidence:* `lessons` CFG-C26 (KF-C28). For GB, DEV2 maps COUNTY>COUNTY and CITY>TOWNSHIP; the GB validation level is unverified (`fusion-model` 3.5). The GP batches loaded GB with STATE and COUNTY null.
13. **Required profile columns with no legacy source.** `CREDIT_BALANCE_STATEMENTS`, `COLLECTOR_NAME`, `TOLERANCE`, `OVERRIDE_TERMS` and `AUTO_REC_INCL_DISPUTED_FLAG` are rejected one pass at a time. Defaults used: Y / AR Manager / 0 / Y / N. *Evidence:* `lessons` F3 (CFG-C33, KF-C32).
14. **SET id loaded where the code is required.** A numeric set id failed `HZ_IMP_INVAL_VALUE_COMPARE`, and so did `Enterprise`. *Fix:* upper-case code `ENTERPRISE`. *Evidence:* `lessons` F1 (CFG-C30).
15. **Blank terms do not inherit anything.** On 2026-10-13 the Greenlight user asked to leave terms blank "so Fusion uses the default from the customer profile class". DEV2's DEFAULT class has no term. Greenlight logged a high finding: "DEFAULT profile class has no terms on DEV-2" (`atp/conv-ax-import.md`; `atp/dq-findings-customers.md` 2026-10-13; `fusion-model` 3.4). The GP batches set `Net 30` explicitly.
16. **Status polling.** POST `getESSJobStatus` returns 400. Use GET `ESSJobStatusRF`, and count `COMPLETED` as success (`lessons` F12). A 401 means stop and do not retry, because retries can lock the account (`lessons` F13).

### 3.2 File and template quirks (Excel, CSV, Greenlight fill tool)
17. **The `.xlsm` is not the load format.** The load needs headerless CSVs with Pascal-case names (`HzImpPartiesT.csv`), UTF-8 without BOM, an `END` column, and a re-sequenced profile file (for example, Organization ID moves from position 82 to 78). Writing in template order is the likeliest cause of values landing in the wrong columns (`atp/conv-uk-load-dev2.md` 2026-10-13 11:53; `lessons` 2.5 #1).
18. **The text `NULL` in CSVs.** `duckdb -csv` wrote `NULL` for empty values; flag, date and number columns rejected it, and the whole file rolled back. A loader failure leaves no batch, so the id can be reused (`lessons` F5, MAP-C26, KF-C52).
19. **Template example rows.** Unfilled tabs held 10 to 30 rows on 2026-10-14; the A24 file (2026-09-20) carried other customers' rows; five UK CW sheets still hold example rows (`atp/conv-uk-load-dev2.md`; `atp/conv-template-26c.md`; `atp/conv-uk-cw.md`). The tool cannot clear a tab ("expected 5 row(s) from a population of 0"). **Risk for the 2026-10-16 UK-PH file:** it was built on `RGE_Customer_Master_FBDI_Dev1.xlsm`, whose unfilled sheets list 10 to 22 rows (for example HZ_IMP_CONTACTS_T 22, HZ_IMP_RELSHIPS_T 22). Whether those rows are examples is unverified.
20. **Required column the fill tool cannot fill.** `*Part Site Use Type` on HZ_IMP_PARTYSITEUSES_T has a blank interface-column entry. The fill reports success anyway. Check `matchedColumns` against `unmatchedColumns` (`atp/conv-add-template.md`, 2026-09-26).
21. **Masking although policy says off.** `fill_template` replaced addresses (2026-09-26), person names, account name, collector and e-mails (2026-10-10, 2026-10-15) and GP phone numbers (2026-10-16) with synthetic values. A file with masked columns must never be loaded. Only an approved unmask request gives real values (`atp/conv-add-template.md`; `atp/conv-uk-load-dev2.md`; `atp/conv-uk-cw.md`; `atp/conv-uk-ph.md`; finding a47cdfa9).
22. **Fill mechanics.** Each fill returns a new document id, so chain each sheet from the previous output; parallel fills on one base create separate branches (`atp/conv-template-26c.md` 2026-09-20). `fill_template` rejects ORDER BY without TOP. `STRING_SPLIT` is unavailable at the AX database's compatibility level (`atp/conv-uk-load-dev2.md` 2026-10-10). `fill_template` reads only registered SQL Server sites, not ATP (`atp/golden-customer-summary.md`).
23. **Uploaded but never submitted.** Three 2026-10-10 uploads (UCM 401976 to 401978) came from the masked document and were never submitted. Leave them unsubmitted and never reuse them (`atp/conv-uk-load-dev2.md` 2026-10-13 11:38).
24. **Upload is not submit.** On 2026-10-15 "upload the completed template and submit" produced an upload only. The Greenlight tool cannot set job parameters; the user confirms them on the submission form. The tool also does not confirm that the `InterfaceLoaderController` step (selector 4) runs before `CDMAutoBulkImportJob`. If a batch shows no rows, that step is the likely cause (`atp/conv-uk-load-dev2.md` 10:44).
25. **Transactions before customers.** AutoInvoice rejected lines with "You must enter a valid original system bill-to customer reference" because the customer load had failed. Confirm customers in the registry before any transaction load (`lessons` F8, KF-C76). This applies to the 100 Picturehouse invoices built on 2026-09-24 with `GP-PH` references, which match no loaded GP customer.
26. **Untrimmed names.** One AX account is stored with trailing blanks. GP `char` fields are space-padded, so RTRIM every one before it reaches a key or a name (`fusion-model` 2.4 #12; `lessons` 1). A char-padded key once broke a master-set comparison in the Poland fill (`atp/conv-template-26c.md` 2026-09-24 20:03).
27. **Fusion SQL runner failures.** Some `fusion_run_sql` queries returned BIP HTTP 500 (BU joins on 2026-10-10, ESS history on 2026-10-13). `hz_orig_systems_b.ORIG_SYSTEM_NAME` gives ORA-00904; use `hz_orig_systems_vl` (`atp/conv-uk-load-dev2.md`; `atp/golden-customer-summary.md`).

### 3.3 GP-specific
28. **Cross-company number collision.** PHTRA and PHEN2 share 1,163 CUSTNMBRs with zero name matches; PHTRA/PHBOO share 18 and PHEN2/PHBOO 13. 9,669 rows hold only 8,488 distinct numbers. CUSTNMBR can never be the global key (`gp-schema` 5.4; `atp/conv-uk-ph.md`). Note: `references/fusion-target-model.md` 3.2 records this as verified.
29. **The 2026-10-16 UK-PH fill departed from the proven GP batch pattern.** It used source system `PH_GP` (not registered in DEV2; `GP` is), ORG_ID `210` (a "BU value" code from the Legal Entity Map, not a Fusion BU id), left SET_ID blank, built BILL_TO and SHIP_TO party-site uses on every address (19,308), and did not consult the `uk_ph_customer_source_to_target_v20261009_1.xlsx` mapping workbook (`atp/conv-uk-ph.md` 12:54). *Fix:* rebuild to the pattern in section 2 item 2.
30. **Query too complex.** One UNION across three company databases in a single fill failed with "The query processor ran out of internal resources". A third, simpler formulation succeeded (`atp/conv-uk-ph.md` 12:54).
31. **Address typos become extra sites.** PHTRA has 11 non-`MAIN` ADRSCODEs (`M`, `MAI`, `MIAN`, `MIN`, a street-address string …); 4 customers have two addresses, all typo duplicates. Collapse each customer to one site (`gp-schema` 5, 7 #7). The 2026-10-16 fill wrote one site per address row (9,654).
32. **"15 customers without an address" is wrong; it is 19.** Greenlight derived 15 from 8,484 − 8,469. The verified profile shows 19 PHTRA customers with no RM00102 row, while 4 have two (`atp/conv-uk-ph.md`; `gp-schema` 5). Prefer 19.
33. **Open AR totals differ by method.** Greenlight (2026-10-09): PHTRA 1,350,523.81, PHEN2 602,578.26. Verified profile: 1,298,917.25 and 598,322.80, signing RMDTYPAL 7-9 negative with VOIDSTTS=0. The customer counts (156 / 166) agree (`atp/conv-profiling-help.md`; `gp-schema` 5). Always state the sign rule.
34. **Bad dates.** FRSTINDT is 1900-01-01 on 100% of customers. Open documents dated 3026-05-27 and 8202-02-28 exist. On 2026-09-24 the Greenlight user confirmed 3026 should read 2026 (`gp-schema` 7 #8; `atp/conv-template-26c.md` 02:06).
35. **GP class is not a business class.** CUSTCLAS holds GBP / EUR / USD, and the GP default class is USD although about 97% of customers are GBP. 224 PHTRA customers have blank class, currency, terms and tax (`gp-schema` 4, 7 #4).
36. **A BU-id "collision" that was not one.** On 2026-09-24 Greenlight flagged 300000004842930 as shared by `RGE_UK_CW_EUR_BU` and `RGE_UK_PH_GBP_BU`. The id came from the user's own input. DEV2 gives `RGE_UK_CW_EUR_BU` id 300000004842917 (`atp/conv-template-26c.md`; `lessons` 2.4).
37. **No BU on stored customers.** `HZ_CUST_ACCT_SITES_ALL` has no ORG_ID, so "customers loaded by BU" cannot be counted. The BU goes in only on the profile (`atp/conv-uk-load-dev2.md` 2026-10-10 16:38; `fusion-model` 1.1).
38. **Name-prefix duplicate checks miss suffixes.** "The Walt Disney Company Ltd" versus "... Limited (Studios)" passed a prefix check. Normalise Ltd/Limited before comparing (`atp/conv-uk-load-dev2.md` 2026-10-13 11:53). GP has 344 same-name groups covering 722 customers across PHTRA and PHEN2 (`gp-schema` verification pass).

---

## 4. Decisions register

**This register is the authoritative one for the skill.** The D-numbers in `field-mapping.md` section 16 are local to the mapping file and do not match these, and `SKILL.md` section 12 only summarises what is open.

Status: **decided** (an explicit decision is on record), **default-in-use** (what the loaded GP batches used, with no recorded sign-off), **open**.

| # | Decision | Status | Who / when | Source |
|---|---|---|---|---|
| D1 | Account numbering: keep the GP number with company prefix, `<COMPANY>-<CUSTNMBR>` (e.g. `PHTRA-D00659`), as ACCOUNT_NUMBER = party OSR = account OSR | default-in-use | GP batches, 2026-10-08/09; also chosen by the 2026-10-16 Greenlight fill | `fusion-model` 2.2, 3.1; `atp/conv-uk-ph.md` |
| D2 | Account number generation `NOAUTONUM_NOUPDATE` | decided for AX (CFG-C17), but DEV2 shows `HZ_GENERATE_CUSTOMER_NUMBER` = AUTO_NUMBERING; supplied GP numbers were kept anyway. Observed state wins | Hackett/Jonathan, 2026-09-18; observed 2026-10-16 | `lessons` 2.3; `fusion-model` 2.4 #11 |
| D3 | Source system code `GP` ("Microsoft Dynamics GP", SPOKE, active), on every entity | default-in-use. `GP-PH` (2026-09-24) and `PH_GP` (2026-10-16) were proposed in Greenlight and are not registered | registered 2026-09-23 | `fusion-model` 2.3; `atp/conv-template-26c.md`; `atp/conv-uk-ph.md` |
| D4 | Reference scheme: sites `<cust>-MAIN`, account site use `<cust>-MAIN-BILL_TO`; children carry the parent's OS+OSR | default-in-use | GP batches | `fusion-model` 2.2 |
| D5 | SET_CODE `ENTERPRISE` (id 300000000003006) on account sites and site uses | default-in-use (UK reference set formally open, CFG-C22) | GP batches; set confirmed in DEV2 2026-09-15 | `fusion-model` 2.2; `lessons` 2.4 |
| D6 | Business unit per GP company: all three companies to `RGE_UK_PH_GBP_BU` (300000004842930) | default-in-use; open (CFG-C22, CFG-PH-02: 12 Picturehouse LEs against 3 GP databases) | GP batches; open UK-02 | `fusion-model` 5; `lessons` 2.1 |
| D7 | Profile: class DEFAULT, collector AR Manager, terms Net 30, cycle Monthly, statements Y, credit check N, credit hold N, dunning N | default-in-use; UK defaults not signed off (`lessons` 4.1 #13) | GP batches | `fusion-model` 3.2 table |
| D8 | GP terms crosswalk (D030 → Net 30; D010, D005 and EOM have no exact DEV2 equivalent) | open | proposed by Greenlight 2026-10-16 | `atp/conv-uk-ph.md`; `gp-schema` 4 |
| D9 | Customer class `B2B`; GP CUSTCLAS (a currency grouping) is not carried | default-in-use | GP batches; Greenlight left class blank 2026-10-16 | `fusion-model` 2.2; `atp/dq-findings-customers.md` 2026-09-29 |
| D10 | Selection rule. Verified counts per company (open balance / traded since 2024 / all active): PHTRA 156 / 1,965 / 8,474; PHEN2 166 / 410 / 1,164; PHBOO 0 / 0 / 18 | **open** | Jonathan's AX rulings ("transactions in the last 6 months", 2026-09-21; "any customer with open AR regardless of the date", 2026-09-23) are not recorded as applying to GP | `lessons` CFG-C13; counts as supplied with this task. PHTRA 1,965 (1,966 rows) is the verification-pass figure for "open OR history since 2024-01-01"; the first pass's 1,964 is superseded (`gp-source-model.md`) |
| D11 | Party grouping / dedupe: one party per GP customer per company, or merge same-name customers (239 PHTRA×PHEN2 name pairs; 344 names / 722 customers combined) | open. AX equivalent CFG-C18 was decided, then reopened ("most expensive to defer", CFG-C07) | 2026-09-18 onward | `lessons` 2.3; `gp-schema` 5.4 and verification pass |
| D12 | Address set versus company: the May extract shows 1,147 customers under `PICTUREHOUSE BOOKINGS`, but PHBOO holds 18 | open | 2026-05 extract vs live 2026-09-01 | `lessons` 2.2 |
| D13 | Intercompany customers (e.g. D05190 Picturehouse Entertainment in PHTRA, with 35,230.30 open and blank currency; D00519 in PHEN2; Regal and Cineworld entities): CUSTOMER_TYPE `I` or `R`, convert or not | open (AX rule: intercomp class → `I`) | none for GP | `gp-schema` 7 #10; `lessons` CFG-C19 |
| D14 | EUR and USD customers (PHEN2 EUR 63 / USD 18; PHTRA EUR 10 / USD 7; PHEN2 41 EUR open docs): profile currency and BU | open. GP batches sent no currency | none | `gp-schema` verification pass, 7 #10 |
| D15 | Person versus organisation party type. Many PHTRA names are individuals; the GP batches loaded all as ORGANIZATION | open (UK-CW-212 also open). For the 2026-10-13 US sample the Greenlight user ruled "no individuals" | Greenlight user, 2026-10-13 | `gp-schema` 7 #9; `atp/conv-ax-import.md` |
| D16 | GP companies in scope: PHTRA and PHEN2 carry the population; PHBOO has 18 customers, no open AR and no activity since 2022; PHGAP has 0 | open (Q-04). The 2026-10-16 Greenlight user said "read the UK Picture House databases (all of them)" | Greenlight user, 2026-10-16 | `gp-schema` 5; `atp/conv-uk-ph.md` |
| D17 | Batch ids `YYYYMMDDnn` (10 digits), checked unused in `HZ_IMP_BATCH_SUMMARY`; commit under a new id after preview | decided (format, collision check); default-in-use (new id) | 2026-09-16 onward | `lessons` 2.5 #3, F6; `fusion-model` 5 |
| D18 | One site per GP customer with a BILL_TO account site use; no SHIP_TO | default-in-use (GP batches); the 2026-10-16 fill added SHIP_TO | GP batches | `fusion-model` 3.2; `gp-schema` 7 #7 |
| D19 | Contacts: GP has one free-text CNTCPRSN, 99 PHTRA e-mail customers and 0 in PHEN2's SY01200. The GP batches loaded 5 relationships and 6 contact points | open | Greenlight asked 2026-10-16 | `atp/conv-uk-ph.md`; `fusion-model` 3.6 |
| D20 | Credit limits: GP carries type and amount; the GP batches loaded none; AX treated credit as "a design exercise, not a conversion" | open | none for GP | `gp-schema` 5; `lessons` 4.1 #12 |
| D21 | Never load masked or synthetic values; skip the object instead | decided | Greenlight user, 2026-10-13: "do not mask the contacts or if you are not able to turn the masking off, skip contacts for this load" | `atp/conv-uk-load-dev2.md` 11:38 |

---

## 5. Jonathan's working rules

Found in the research inputs:
- **Reuse the proven path.** "NO for the last time. DO. IT LIKE WE DID IT FOR THE 5 CUSTOMERS." Do not propose new builders or installs when tooling exists (`lessons` 3.3, 2026-09-23).
- **Load, report, fix, reload.** "We must load it, report on any issues, fix the issues, and then reload, period." (`lessons` 3.3, 2026-09-21).
- **No conjecture.** "do not conjecture, assume or guess ... research is key" (2026-10-16); "do not add anything, assume or conjecture. do not lie or make anything up." (2026-09-22) (`lessons` 3.3).
- **Every DEV2 write needs an explicit go.** This is an AIX-GreenLight standing rule (`lessons` 3.3).
- **Jonathan enters the password in his own terminal.** Claude never handles it; Claude does the pull, build, dry-run and verification (`lessons` 3.3).
- **Stay quiet; confirm the scope of a stop.** "stay quiet" (too much narration). "just stop" was once over-applied to four unrelated workers (`lessons` 3.3).
- **Confirm the host before submitting** (F9) and **stop on a 401** (F13) (`lessons` 3.2).

Instructions from the Greenlight user (who is not identified in the exports, so they are not attributed to Jonathan):
- "fill only the template I name with the fill_template tool", and acknowledge uploads without inspecting them (`atp/conv-uk-ph.md` 2026-10-16 12:29).
- "do not mask the contacts or if you are not able to turn the masking off, skip contacts for this load" (`atp/conv-uk-load-dev2.md` 2026-10-13 11:38).
- "clear all data from every tab in the FBDI template first, then populate", followed by "if i need to clear the records manually, i will do so" (`atp/conv-uk-load-dev2.md` 2026-10-14 and 2026-10-15).
- Swap the individual in the sample "for another active US organization customer (no individuals)" (`atp/conv-ax-import.md` 2026-10-13 15:41).
- Leave payment terms blank "so Fusion uses the default from the customer profile class". That default does not exist in DEV2; see section 3 #15 (`atp/conv-ax-import.md` 2026-10-13 15:41).
- "load 5 customers for UK from AX that have open invoices > $0 and are not already in DEV-2" (`atp/conv-uk-load-dev2.md` 2026-10-14 13:08).
- "This customer conversion should read the UK Picture House databases (all of them)" (`atp/conv-uk-ph.md` 2026-10-16 12:48).

Also in force from the repo's `CLAUDE.md` (not in the research inputs): verify state before asserting it; confirm the database target before connecting; no change to a live environment without his explicit word; wizards do the fix rather than print it; the caller tracks state, and the server stays a tools server.

---

## 6. Open questions

1. **Which selection rule applies to GP?** It sets the population size: from 322 open-balance customers to about 9,656 all-active. *Who:* Jonathan, then the Regal AR owner.
2. **Which BU and reference set does each GP company map to?** It drives profile ORG_ID and SET_CODE (CFG-C22, CFG-PH-02). *Who:* Regal finance / configuration lead (UK-02).
3. **Is PHBOO in scope?** It has 18 customers and nothing since 2022. *Who:* Jonathan / Regal AR owner.
4. **Merge same-name customers across companies?** Merging after AR loads means re-pointing transactions (CFG-C07). *Who:* Jonathan with the Regal AR owner.
5. **What is the May extract's `PICTUREHOUSE BOOKINGS` address set?** It decides whether address sets mean companies. *Who:* whoever built the extract (GP data owner, unassigned per `AP-P2-24`).
6. **How are intercompany and Regal/Cineworld group customers treated?** It sets CUSTOMER_TYPE and whether their open AR converts. *Who:* Regal finance.
7. **Which BU and currency do EUR/USD customers take?** The profile carries currency and the BU has a ledger currency. *Who:* Regal finance.
8. **Person versus organisation for individual-named customers?** It affects party type, `HZ_WRONG_PARTY_TYPE` errors and PII handling. *Who:* Jonathan / Regal AR owner.
9. **GP terms crosswalk**, including D010, D005, EOM and blanks (214 PHTRA). Blank terms give no terms in DEV2. *Who:* Regal AR owner.
10. **Do contacts convert, and from which field** (CNTCPRSN, SY01200, RM00106)? *Who:* Regal AR owner.
11. **Do credit limits and hold flags convert?** *Who:* Regal credit / AR owner.
12. **Was the 2026-10-15 upload (UCM 414839, batch 2026101501) ever submitted?** It matters before reusing batch ids or re-loading those five accounts. *Who:* the Greenlight user; checkable in `HZ_IMP_BATCH_SUMMARY`.
13. **Who ran the three GP_PH batches, from which file?** No record of it exists in the inputs. *Who:* Jonathan.
14. **What is the GB geography validation level in DEV2?** It decides whether blank city (2,342 PHTRA) or county rows reject. *Who:* checkable in DEV2 setup; Fusion configuration lead.
15. **Does UK VAT registration need loading?** TXRGNNUM is filled on 6 GP customers in total, and no in-scope sheet carries it. *Who:* Regal tax.
16. **Can the same legal customer exist in both UK AX (`vcw`) and GP?** This has never been tested. *Who:* checkable by a name match.
17. **What agreed rules does `uk_ph_customer_source_to_target_v20261009_1.xlsx` hold?** The 2026-10-16 user called it "the active working template", yet the fill never read it. Its "Open items" and "Target configuration" sheets may already settle D6 to D9. *Who:* the Greenlight user; readable through Greenlight's knowledge base.
18. **Is the May 2026 extract still a basis?** It holds 9,523 rows against 9,669 live, a gap of 146 that nobody has explained. *Who:* GP data owner (unassigned, `AP-P2-24`).
19. **Who owns GP customer data, and what is the extract freeze point?** The client register leaves the GP data-owner cell blank, and no GP extract timestamp is agreed (`lessons` 4.1 #17). *Who:* Regal programme lead.
20. **What are the RICE id and FDD number for UK customer conversion?** Naming of reports and objects depends on them (`lessons` 4.1 #20). *Who:* Regal technical standards owner.

---

## 7. DQ findings already recorded in Greenlight

From `atp/dq-findings-customers.md` (79 findings: 19 GP, 48 AX or tooling, 12 excluded). The 12 excluded "Contact" findings, dated 2026-09-09 and 2026-09-17, are HCM (UltiPro) emergency and dependent contacts, not AR customers.

### 7.1 GP (Picturehouse) findings, all status open

| Date | Title | Severity | Affected / population |
|---|---|---|---|
| 2026-09-29 | UK-GP: VAT/tax registration number essentially absent | high | 11,663 / 9,669 (as recorded) |
| 2026-09-29 | UK-GP: CCode gives a clean ISO2 country where COUNTRY is free text | info | 7,971 / 8,484 |
| 2026-09-29 | UK-GP: CUSTCLAS is a currency/tax grouping, not a business class | medium | 8,484 / 8,484 |
| 2026-09-29 | UK-GP: flat, single-address model, no party/account split | high | 8,469 / 8,469 |
| 2026-09-29 | UK-GP: incomplete addresses and near-absent e-mail | medium | 1,209 / 8,484 |
| 2026-09-29 | UK-GP: BALNCTYP uniformly one value (verified 2026-10-16: 0 = open item) | medium | 8,484 / 8,484 |
| 2026-10-09 | PHGAP company database has an empty customer master | info | 0 / 0 |
| 2026-10-09 | Customer IDs collide across PHTRA and PHEN2 with different customers | critical | 1,163 / 1,167 |
| 2026-10-09 | Customers missing payment terms, class, currency or tax schedule | medium | 224 / 9,651 |
| 2026-10-09 | Missing country and address data | high | 623 / 9,651 |
| 2026-10-09 | Customer names duplicated within a company | medium | 292 / 9,651 |
| 2026-10-09 | VAT registration blank on almost every customer | medium | 9,645 / 9,651 |
| 2026-10-09 | Possible test or placeholder customers | low | 14 / 9,651 |
| 2026-10-09 | Special characters and whitespace in PHTRA names and IDs | medium | 251 / 8,484 |
| 2026-10-09 | Contact details sparsely populated | low | 9,142 / 9,651 |
| 2026-10-09 | Open AR scope: 322 customers, 16 PHTRA with credits only | info | 322 / 9,669 |
| 2026-10-16 | No payment terms or currency; 15 customers without an address row (verified count is 19, section 3 #32) | medium | 245 / 9,669 |
| 2026-10-16 | Address fields misused: STATE holds VAT numbers or US zips, PHONE1 holds text | medium | 608 / 9,654 |
| 2026-10-16 | Customer numbers collide across Picture House company databases | high | 1,181 / 9,669 |

### 7.2 AX and tooling findings (summary by theme, all open)

| Theme | Findings | Severities | Dates |
|---|---|---|---|
| Duplicate names within an entity (US 6,914/25,616 and 4,813/16,124; UK 2,076/9,399) | 4 | high, medium | 09-12 to 09-28 |
| Tax/VAT registration absent (US and UK AX) | 5 | high, medium | 09-12 to 09-28 |
| Payment terms missing or uncrosswalked (398, 395, 2,964; DEFAULT class has no terms on DEV2) | 5 | high, medium, low | 09-12 to 10-15 |
| Invoice account differs or blank (AX invoice pooling) | 4 | medium, low, info | 09-12 to 09-28 |
| No credit limits configured (US 16,124; UK 9,399) | 2 | medium | 09-20, 09-28 |
| UK AX address hygiene (county truncated 3,238; CR in State 5,811; defects 52/9,586) | 4 | high, medium | 09-28 to 10-15 |
| US address hygiene (line break 1/5; no street 16; State not 2-char 98; non-US 11; expired 768) | 5 | high, medium | 10-13 to 10-15 |
| Customer class not populated, no AX group resolves | 2 | high | 10-15 |
| Masking and synthetic values from `fill_template` (incl. a47cdfa9; account name 9,398) | 2 | high, medium | 10-10, 10-15 |
| Load inputs placeholders (batch, ORIG_SYSTEM CSV, ORG_ID, SET_ID); template example rows | 2 | high, medium | 10-15 |
| Scope and source gaps (2,999 vs spec 2,869; operating unit excluded; no postal address) | 3 | medium | 10-15 |
| Other (non-ASCII names 151; whitespace 13; individuals as organisations; parties with two accounts; contact type decode; profile gaps; internal e-mail domain 10,955; remit-to as SHIP_TO; UK master transacts in another company; UK open AR 420/9,399) | 10 | high to low | 09-19 to 10-15 |

Greenlight holds no import errors or saved mappings for customers. On 2026-10-16 the queries behind `atp/cdm-import-errors.md` (ORACLE_IMPORT_ERRORS for CDMAutoBulkImportJob imports), `atp/load-import-errors.md` (LOAD_IMPORT_ERRORS joined to LOAD_BATCHES) and `atp/mapping-configs-customer.md` (MAPPING_CONFIGS for CustomerImportTemplate.xlsm) returned zero rows. So no Oracle import errors were harvested for any CDM bulk-import run: all 5 CDM runs in `atp/cdm-imports.md` are status "uploaded" with no job result. No load-import errors exist for any batch, and no column mapping is saved for the customer template. `LOAD_BATCHES` itself held no rows on 2026-10-16 (its table statistics still said 50), so Greenlight currently records no load batches at all; the batch evidence in this file comes from DEV2's `HZ_IMP_BATCH_SUMMARY`. `atp/streams.md` holds only an export error (ORA-00904).
