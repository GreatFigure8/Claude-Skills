# Load runbook: GP Picturehouse customers into Regal DEV2

How to take a selected set of Picturehouse customers from GP (PHTRA, PHEN2, PHBOO) through
the Customer Import FBDI into Regal DEV2 (`ichqjb-dev2`), and prove they landed. Each step
says what it does, why, how to run it, and what output to expect.

Read `field-mapping.md` first: this runbook applies its rules but does not repeat them. Trap
numbers (T1 to T17) refer to `fusion-target-model.md` section 5.

## Contents

1. [Who does what](#1-who-does-what)
2. [Step 0: Preconditions](#2-step-0-preconditions)
3. [Step 1: Select the population](#3-step-1-select-the-population)
4. [Step 2: Cleanse and derive](#4-step-2-cleanse-and-derive)
5. [Step 3: Build the FBDI package](#5-step-3-build-the-fbdi-package)
6. [Step 4: Upload and run, preview then commit](#6-step-4-upload-and-run-preview-then-commit)
7. [Step 5: Verify in the registry](#7-step-5-verify-in-the-registry)
8. [Step 6: Reconcile](#8-step-6-reconcile)
9. [Step 7: Rollback and re-run](#9-step-7-rollback-and-re-run)
10. [Traps checklist](#10-traps-checklist)
11. [Sources and gaps](#11-sources-and-gaps)

---

## 1. Who does what

| Actor | Does | Never does |
|---|---|---|
| Claude | Runs the read-only GP extract, applies the mapping, builds the zip, runs the dry run, runs every read-only DEV2 check, writes the reconciliation. | Handles the Fusion password, submits a load without Jonathan's go, connects to a database Jonathan has not confirmed. |
| Jonathan | Confirms the target host, says "load" for each preview and each commit, types his password into the loader in his own terminal. | |

The split is the playbook's (section 7). The loader prompts for the password without echo and
never prints it.

---

## 2. Step 0: Preconditions

**What it does.** Confirms the go-ahead, the target, the reference data and a free batch id
before anything is built.

**Why.** A preview has run on the wrong tenant before (T7), a reused batch id has failed a
whole import (T6), and a missing setup value can load silently empty (T8).

**How.**

1. **Get Jonathan's word.** No preview and no commit runs without his explicit instruction for
   that run. A preview writes interface rows and a batch record on DEV2, so it counts as a
   write. Also confirm the open decisions in `field-mapping.md` section 16 that affect this
   batch (at least D1 selection, D2 business unit, D4 terms, D5 blank country).
2. **Confirm the host is `https://ichqjb-dev2.fa.ocs.oraclecloud.com/`.** Check it against the
   registered pod list (`fusion-sql.ts --list` in Greenlight, or the Fusion SQL MCP connection
   list here). Reject `iartqy-dev1` or any host typed by hand.
3. **Confirm the source system.** Run on DEV2:

   ```sql
   SELECT orig_system, orig_system_type, status, enable_for_tca_flag
   FROM   hz_orig_systems_b
   WHERE  orig_system = 'GP';
   ```

   Expect one row: `GP`, `SPOKE`, active. No row means nothing can load; stop.
4. **Confirm the reference values the mapping uses still exist.** Run on DEV2:

   ```sql
   SELECT 'PROFILE_CLASS' kind, name, status FROM hz_cust_profile_classes WHERE name = 'DEFAULT'
   UNION ALL SELECT 'COLLECTOR', name, status FROM ar_collectors WHERE name = 'AR Manager'
   UNION ALL SELECT 'CYCLE', name, status FROM ar_statement_cycles WHERE name = 'Monthly'
   UNION ALL SELECT 'TERM', name, NULL FROM ra_terms_tl WHERE name = 'Net 30' AND language = 'US'
   UNION ALL SELECT 'CLASS_IN_USE', customer_class_code, TO_CHAR(COUNT(*))
             FROM hz_cust_accounts WHERE customer_class_code = 'B2B' GROUP BY customer_class_code;
   ```

   Expect five rows. The `B2B` row proves the class code is in use (36 accounts on
   2026-10-16); the class lookup type name itself is unverified (`fusion-target-model.md` 3.3).
   A missing row is a stop: fix setup or the mapping first.
5. **Pick a free batch id.** Run check 0 of `scripts/fusion_post_load_checks.sql`. Any id it
   returns is taken. Choose the next free `YYYYMMDDnn` for the preview and another for the
   commit. Name the batches the way the GP batches were named:
   `GP_PH_<PURPOSE>_PREVIEW` and `GP_PH_<PURPOSE>_COMMIT`.
6. **List what is already loaded.** Run on DEV2:

   ```sql
   SELECT owner_table_name, orig_system_reference
   FROM   hz_orig_sys_references
   WHERE  orig_system = 'GP' AND status = 'A'
   ORDER  BY owner_table_name, orig_system_reference;
   ```

   Keep the account references. Any selected customer already listed must go as an update
   (`U`) or be dropped, never as an insert (T11). On 2026-10-16 there were 25 GP accounts.

**Expect.** Jonathan's go, the confirmed host, five setup rows, two free batch ids, the GP reference list.

---

## 3. Step 1: Select the population

**What it does.** Pulls the agreed customers from each GP company, one row per address.

**Why.** Which customers convert is Jonathan's decision (D1). The extract carries the three
candidate rules as commented-out `WHERE` options, so the rule in the file is the rule agreed.

**How.**

1. Open `scripts/gp_customer_extract.sql` and uncomment exactly one `WHERE` option (A, B or C).
2. Run it unchanged on each site: `PHTRA-Great-Plains`, `PHEN2-Great-Plains`,
   `PHBOO-Great-Plains`. Skip PHGAP (no customers). The site decides the company; every row
   carries `company_code` and `company_qualified_id`.
3. Write the rows to a file in the build folder. Do not paste rows into the session: names,
   contacts and addresses are personal data for many PHTRA customers. Report counts only.
4. Record, per company: rows, distinct `company_qualified_id`, rows with
   `address_source = 'RM00101 (no address row)'`, and customers with more than one row.

**Expect** (2026-10-16 figures; re-run, the companies still trade):

| Option | PHTRA | PHEN2 | PHBOO | Total |
|---|---|---|---|---|
| A open balance | 156 | 166 | 0 | 322 |
| B open or dated on/after 2024-01-01 | 1,965 | 410 | 0 | 2,375 |
| C all active | 8,474 | 1,164 | 18 | 9,656 |

Rows exceed customers only for the 4 PHTRA customers with two addresses. PHBOO was not re-run
in the verification pass, so treat its figures as first-pass.

---

## 4. Step 2: Cleanse and derive

**What it does.** Turns each extract row into one row per interface table, applying every rule
in `field-mapping.md`, and sets aside the customers that cannot load yet.

**Why.** Fusion validates in sequence and fails late; a defect found here costs a rebuild,
one found in the import costs a batch id.

**How.**

1. **Collapse to one site.** Keep the primary address (`is_primary_address = 1`) for each
   customer. Use the literal `MAIN` in every site reference (mapping section 3).
2. **Apply the rules** in mapping sections 2 to 13: RTRIM, 1900-01-01 to NULL, `YYYY/MM/DD`
   dates, CCode-first country, GB CITY as the town with STATE blank, terms crosswalk, blank
   currency to GBP, the profile defaults, `ORG_ID 300000004842930`, set code `ENTERPRISE`.
3. **Flag existing references.** A customer whose account reference is in the Step 0 list
   goes as `U` on party, location, sites, account and site use, with its profile as `I`.
4. **Hold what cannot load.** Give each held or excluded customer one upper-case reason code.
   These codes are **proposed** (they follow the AX stream's style, such as `HOLD_NO_ADDRESS`):

   | Code | When | Mapping rule |
   |---|---|---|
   | `HOLD_NO_ADDRESS` | no RM00102 row (19 PHTRA) | D13 |
   | `HOLD_NO_COUNTRY` | no CCode and no resolvable COUNTRY text | L1, D5 |
   | `HOLD_COUNTRY_CONFLICT` | CCode and COUNTRY text disagree | L1 |
   | `HOLD_NO_CITY` | blank city, or address line 1 blank | L2, D6 |
   | `HOLD_US_NO_STATE` | US address without a valid state | L3 (T10) |
   | `HOLD_TERM_NO_TARGET` | D010 or D005 with no agreed term | 13.1, D4 |
   | `EXCL_INACTIVE` | `INACTIVE = 1` | 13.6 |

5. **Run integrity checks on the derived set** before building. These are **proposed** checks
   modelled on the AX builder's ten checks (which were not listed in the inputs):
   - one row per customer in each of the eight tables;
   - every reference unique within its table, and trimmed;
   - every child's parent reference present in the batch or in the Step 0 list (T15);
   - `BATCH_ID` identical on every row;
   - starred columns non-empty: PARTY_TYPE, IDENTIFYING_ADDRESS_FLAG, SITE_USE_TYPE, the set
     codes, SITE_USE_CODE, CREDIT_HOLD, ORG_ID, INSERT_UPDATE_FLAG on profiles;
   - the five import-required profile columns non-empty (T4);
   - no value contains a line break or the text `NULL` (T16);
   - no value longer than its template length (ORGANIZATION_NAME 360, ACCOUNT_NAME 240,
     ADDRESS1 240, CITY 60, POSTAL_CODE 60, ACCOUNT_NUMBER 30).
6. **Write the boundary identity.** `LOAD + HELD + REJECT = selected` per company, delta 0.

**Expect.** Eight derived tables with one row per LOAD customer each, a held list with reason
codes, every integrity check passing, and the identity at delta 0.

---

## 5. Step 3: Build the FBDI package

**What it does.** Writes the load files in exactly the format the template's Generate CSV
macro produces, and zips them.

**Why.** The loader's control files expect the macro's column order. Writing in template order
is the likeliest cause of a load that completes with values in the wrong columns (UK AX job
specification, 2026-10-13).

**How.**

1. Do not fill `CustomerImportTemplate.xlsm`. Use `ingest/fbdi_customer_load_format.py`
   (`write_set`) in the AX pipeline folder; it reimplements the macro from the extracted macro
   source (E8 evidence file). A GP driver for it is not in the inputs: the AX drivers
   (`build_single_customer_zip.py`) read AX JSON. How the three GP batches were built is not
   recorded, so write or locate a GP driver that feeds `write_set` the Step 2 rows.
2. The package the builder writes:

   | Interface table | File in the zip |
   |---|---|
   | HZ_IMP_PARTIES_T | `HzImpPartiesT.csv` |
   | HZ_IMP_LOCATIONS_T | `HzImpLocationsT.csv` |
   | HZ_IMP_PARTYSITES_T | `HzImpPartySitesT.csv` |
   | HZ_IMP_PARTYSITEUSES_T | `HzImpPartySiteUsesT.csv` |
   | HZ_IMP_ACCOUNTS_T | `HzImpAccountsT.csv` |
   | HZ_IMP_ACCTSITES_T | `HzImpAcctSitesT.csv` |
   | HZ_IMP_ACCTSITEUSES_T | `HzImpAcctSiteUsesT.csv` |
   | RA_CUSTOMER_PROFILES_INT_ALL | `RaCustomerProfilesIntAll.csv` |

   Contact files (`HzImpContactsT.csv`, `HzImpRelshipsT.csv`, `HzImpAcctContactsT.csv`,
   `HzImpContactPtsT.csv`, `HzImpContactRoles.csv`, `HzImpRoleResp.csv`) are added only if
   D11 converts contacts. A table with no rows gets no file.
3. The format, as the builder enforces it:
   - no header row; an extra last column holding `END` on every row;
   - comma separated, CRLF line ends, minimal quoting, UTF-8 without BOM;
   - template column order, except: on account sites, columns D then H move before AW; on
     account site uses, column B moves before AT twice; profiles are re-sequenced into the
     132-column control-file order;
   - no properties file: the macro writes only the CSVs and the zip;
   - a review copy of each file with a header row goes to `review/`, never into the zip.
4. Name the zip so it carries the batch id. The AX convention is
   `CustomerImport_<source>_<set>_batch<id>.zip`, for example
   `CustomerImport_GP_ENTERPRISE_batch2026101701.zip`. The loader refuses a zip whose name
   lacks the batch id.
5. Check the template version. The column list in the evidence folder came from the
   2026-09-15 template. The Greenlight UK sessions used a 26C template. If the template
   changes, regenerate the column list and the macro evidence before building.
6. Build the preview zip first. The commit zip is built later with its own batch id.

**Expect.** One zip, eight headerless CSVs with matching row counts, review copies, and the
batch id in the zip name and on every row.

---

## 6. Step 4: Upload and run, preview then commit

**What it does.** Uploads the zip, loads it into the interface tables, and runs the import,
first in preview (validate only) and then for real.

**Why.** Preview catches party, location, site, account and site-use errors without creating
anything. It does not check profiles (T4), so a clean preview is necessary, not sufficient.

**The chain** (playbook section 4; `ingest/load_customer_import.py`):

| Call | Job and arguments | Returns |
|---|---|---|
| 1 `uploadFileToUCM` | account `fin$/receivables$/import$` | DocumentId |
| 2 `submitESSJobRequest` | `InterfaceLoaderController` ("Load Interface File for Import"), arguments `4,<DocumentId>,N,N,`; selector 4 is "Import Trading Community Data in Bulk" | loader request id |
| 3 `submitESSJobRequest` | `CDMAutoBulkImportJob` in `oracle/apps/ess/cdm/foundation/bulkImport`, 21 arguments: batch id, batch name, `CUSTOMER`, `GP`, then 17 optional, of which **argument 14 is Run Batch in Preview Mode: `Y` validates, `N` commits** | import request id |

The job creates the `HZ_IMP_BATCH_SUMMARY` row itself; no batch is pre-created in Manage Data
Import. Status is polled with `GET erpintegrations?finder=ESSJobStatusRF;requestId=...`;
`COMPLETED` and `SUCCEEDED` both mean success. `importBulkData` no longer works.

**How.** Jonathan runs these from the AX pipeline folder, in his own terminal:

1. Dry run, which makes no calls:
   `python3 ingest/load_customer_import.py --zip <zip> --batch-id <preview id> --batch-name GP_PH_<PURPOSE>_PREVIEW --source-system GP --dry-run`.
   Expect the three calls printed, with `GP` as argument 4. The script defaults to `AX2012`,
   so `--source-system GP` is mandatory.
2. Preview, after Jonathan's go: the same command with `--preview` in place of `--dry-run`.
   Expect a DocumentId, a loader request and an import request, each about 150 to 200 s,
   ending `COMPLETED` or `SUCCEEDED`, and the note that nothing was created.
3. Read the preview (Claude, read-only): check 1 should show `COMPL_WHATIF`; check 2 should
   return 0 rows; check 2c should list one entity row per populated table except
   `CUSTOMER_PROFILE` (verify the HZ_IMP_ENTITY_DETAILS column names first, as the script
   says). Any error stops the run: fix the data in Step 2, rebuild, and preview again under a
   new id.
4. Commit, after Jonathan's go: pick a new free batch id, rebuild the zip with it (Step 3),
   then run the command with `--batch-name GP_PH_<PURPOSE>_COMMIT --no-preview`. Never leave
   argument 14 blank: a blank finishes `COMPL_WHATIF` and imports nothing (T5).
5. If a run stops after the load was submitted, resume with
   `--resume-load-request <loader request id>` instead of re-running. A second load puts the
   same interface rows in the batch twice.
6. On HTTP 401, stop. Repeated failed logins can lock the account.

Committing the preview batch in place with an explicit `N` has also worked on DEV2 (KF-C72,
four batch ids), but the GP batches used a new id (2026100840 then 2026100841). Keep the new
id as the default.

The Greenlight app's upload-and-submit route is not proven for customers: in the UK AX
session it picked its own batch id at upload and it was not confirmed that it runs the loader
step. Use the script.

**Expect.** Preview batch `COMPL_WHATIF` with 0 errors; commit batch `COMPLETED` with
`WHAT_IF_FLAG` N.

---

## 7. Step 5: Verify in the registry

**What it does.** Proves every layer of every customer exists in the Fusion registry tables.

**Why.** Job and batch status are not proof. A profile import once reported 6 inserted,
6 imported, 0 errors while `HZ_CUSTOMER_PROFILES_F` held 0 rows (T2).

**How.** Wait at least 30 s after the import completes; the profile lands late (T3). Then run
`scripts/fusion_post_load_checks.sql`, one statement at a time, with the commit batch id and
name in each `params` block:

| Check | Expect |
|---|---|
| 1 batch summary | `COMPLETED`, `WHAT_IF_FLAG` N, no `ERROR_MESSAGE` |
| 2, 2b errors | 0 rows. Otherwise the tokens name the column and value. |
| 2c entity counts | one row per populated table, now including `CUSTOMER_PROFILE` |
| 3 accounts in the batch | one row per LOAD customer; `has_active_site`, `has_bill_to`, `has_account_profile` all `Y`; class `B2B` |
| 4 primary BILL_TO | 0 rows |
| 5 missing profile | 0 rows. If not, re-send the account (`U`) and its profile (`I`) together (T1). |
| 5b profile settings | DEFAULT, AR Manager, Net 30, Monthly; credit checking N, hold N, statements Y; credit balance Y, tolerance 0, override Y, auto-rec disputed N; no amount rows unless D8 converts credit limits. 5b covers all GP accounts, and the earlier 25 may show their own values for the last four columns (not captured). |
| 6 references per entity | each layer grows by the LOAD count |
| 7 locations | no GB row with null city or postcode; no US row without a state |
| 8 untrimmed text | 0 rows |

**Expect.** Every check at its expected value. Do not report a customer as loaded until
checks 3, 4 and 5 agree.

---

## 8. Step 6: Reconcile

**What it does.** Ties what Fusion holds back to what GP selected, per company. **Why.** The
boundary identity shows nothing went missing between selection and registry.

**How.**

1. Run check 9 and compare each company's `fusion_accounts` against the Step 2 LOAD count
   plus the GP accounts already there before this batch (Step 0 list).
2. Confirm, per company: `LOAD + HELD + REJECT = selected`, delta 0, where REJECT is any
   customer that check 3 did not return.
3. Site uses: one primary active BILL_TO per account (check 4 at 0 rows).
4. Profiles: one current account-level profile per account (check 5 at 0 rows; check 5b
   counts sum to the GP account total).
5. Credit limits: if D8 converted them, the count of profile amount rows with a limit equals
   the LOAD customers with CRLMTTYP 2, and the amounts match. If not, check 5b shows no
   amount rows.
6. Publish the result per company, with counts only.

**Regal report convention.** The Regal technical standard names conversion reports
`Data Conv AR Customer Pre Load Report`, `Data Conv AR Customer Post Validation Report` and
`Data Conv AR Customer Error Report`, with data models `XXCONV_AR_CUSTOMER_PRE_DM`, `_POST_DM`
and `_ERR_DM`, in `Custom/Regal/DC Reports/AR Customer/PreLoadReports`, `PostValidationReps`
and `ErrorReports` (standard section 7, via the research notes). None exists for GP yet, and
no RICE id for customer conversion was found; ask Jonathan for the id rather than invent one.

**Expect.** Delta 0 per company, and a counts-only reconciliation table.

---

## 9. Step 7: Rollback and re-run

**What it does.** Says what can be undone or repeated after a batch. **Why.** Imports are not
reversible by re-import, and the wrong re-run creates duplicates or errors.

| Situation | What to do | Evidence |
|---|---|---|
| A customer loaded wrong | Correct it with `U` rows under a new batch id. `!` clears an existing profile value. No delete route is documented in the inputs. | Oracle import page; T11 |
| Re-running a batch that completed | Not possible: a successfully imported batch cannot be re-run. Build a new batch. | LOG (KF limits) |
| The same customer sent again as `I` | Fails `HZ_DUPLICATE_COMBINATION`. Send `U`, or drop it. | T11 |
| A profile is missing | Re-send the account (`U`) with the profile (`I`) in one batch. A profile alone reports success and writes nothing. | T1 |
| SQL*Loader stage failed | Nothing was loaded and no batch record exists, so the batch id is reusable. Fix the file (often a `NULL` text value) and rebuild. | T16, KF-C52 |
| Import failed on a taken batch id | Pick a free id and rebuild. | T6 |
| Loader submitted, script stopped | `--resume-load-request <id>`; do not reload. | loader script |
| Interface rows purged | Registry records stay; checks 3 to 9 still work through `HZ_ORIG_SYS_REFERENCES`. | check script header |

Before any transaction load (open AR), confirm the customers in the registry first: AutoInvoice
rejects lines whose bill-to customer reference does not resolve (T17).

---

## 10. Traps checklist

Tick each before the commit.

- [ ] Host is `ichqjb-dev2` (T7).
- [ ] Batch ids free; commit id differs from preview id (T6).
- [ ] Argument 14 explicit: `Y` for preview, `N` for commit (T5).
- [ ] Source system `GP` on every row and as argument 4 (mapping G6).
- [ ] Every reference company-prefixed and trimmed (T12; mapping section 3).
- [ ] Already-loaded GP references sent as `U` or dropped (T11).
- [ ] Set code `ENTERPRISE`, upper case, on account sites and site uses (T14).
- [ ] GB city in CITY, STATE blank; US state present (T9, T10).
- [ ] Optional coded location columns left blank (TGT 3.5).
- [ ] Site-use dates inside site dates, or all blank (T13).
- [ ] Profile row present for every account, in the same batch, with the five import-required
      columns (T1, T4).
- [ ] Class code `B2B` confirmed in use (T8).
- [ ] No `NULL` text, no line breaks (T16).
- [ ] Every parent reference resolves (T15).
- [ ] Verification waits 30 s and reads the registry, not the job (T2, T3).

---

## 11. Sources and gaps

Sources: the AX-to-Fusion FBDI playbook; `ingest/load_customer_import.py` and
`ingest/fbdi_customer_load_format.py` (AX pipeline folder); `fusion-target-model.md` sections
2, 3, 5; `scripts/fusion_post_load_checks.sql`; the UK AX DEV2 load conversation (2026-10-13).

Gaps: the GP batches' build files and column values; real CDM job arguments (research extract
empty); Greenlight's saved mapping configs (empty); the screen name of `CDMAutoBulkImportJob`;
HZ_IMP_ENTITY_DETAILS columns other than NUM_INSERTED.
