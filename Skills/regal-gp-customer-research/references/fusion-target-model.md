# Fusion target model for GP customer conversion

What a Dynamics GP 2010 customer from PHTRA, PHEN2, PHBOO or PHGAP becomes in Oracle Fusion Cloud Receivables, how the Customer Import FBDI loads it, and what Regal DEV2 (`ichqjb-dev2`) looks like today. Read it before building a batch, mapping a column or reading a load result.

Evidence tags used throughout:
- **[DEV2]**: observed by a read-only query on DEV2 on 2026-10-16, unless another date is given.
- **[DOC]**: from an Oracle page. The URL is cited.
- **[PROJECT]**: from the AX customer stream's records (issues log ids such as `KF-C54`, `MAP-C19`, `CFG-C17`) or from the AX-to-Fusion FBDI playbook.
- **[unverified]**: not confirmed against any source. Treat it as a hypothesis and check it before you rely on it.

PHGAP holds no customers (it is a US-GAAP consolidation shell). It is listed for completeness, and a reconciliation should show zero for it.

## Contents
1. [The TCA customer model as Fusion stores it](#1-the-tca-customer-model-as-fusion-stores-it)
2. [Customer Import FBDI](#2-customer-import-fbdi)
3. [DEV2 as configured on 2026-10-16](#3-dev2-as-configured-on-2026-10-16)
4. [Mapping targets](#4-mapping-targets)
5. [Known traps](#5-known-traps)
6. [Sources](#6-sources)

---

## 1. The TCA customer model as Fusion stores it

### 1.1 Why the model matters for GP

A GP customer is flat: one `RM00101` row with a few address codes hanging off it. Fusion splits the same customer into a party (who they are), an account (the commercial relationship), sites (where they are), site uses (what each site is for) and a profile (how they are billed and collected). Each layer has its own interface table and its own source-system reference. A missing layer either fails the import or, worse, loads silently incomplete. So every GP customer has to be fanned out into all of the layers below.

### 1.2 Foreign-key chain [DEV2]

Column names were verified in DEV2 through `ALL_TAB_COLUMNS` and joins that returned rows. Most HZ objects are VIEWs over the FUSION schema in this pod. `ALL_TABLES` returns nothing for them, so look in `ALL_OBJECTS` and `ALL_TAB_COLUMNS`.

```
HZ_PARTIES  (PARTY_TYPE = ORGANIZATION for a GP customer)
 ├─ HZ_CUST_ACCOUNTS          PARTY_ID → HZ_PARTIES
 │   └─ HZ_CUST_ACCT_SITES_ALL     CUST_ACCOUNT_ID →, PARTY_SITE_ID → HZ_PARTY_SITES, SET_ID (no ORG_ID)
 │        └─ HZ_CUST_SITE_USES_ALL CUST_ACCT_SITE_ID →, SITE_USE_CODE, PRIMARY_FLAG, BILL_TO_SITE_USE_ID
 ├─ HZ_PARTY_SITES            PARTY_ID →, LOCATION_ID → HZ_LOCATIONS
 │   └─ HZ_PARTY_SITE_USES         party-level purposes (a different list from account site uses)
 └─ HZ_LOCATIONS              the physical address

HZ_CUSTOMER_PROFILES_F        CUST_ACCOUNT_ID →, SITE_USE_ID (null = account level)   date-effective
 └─ HZ_CUST_PROFILE_AMTS_F    per CURRENCY_CODE credit limits                          date-effective

Contacts:
 HZ_PARTIES (PERSON) ── HZ_RELATIONSHIPS (RELATIONSHIP_CODE = CONTACT_OF; person subject, organization object)
                        └─ HZ_ORG_CONTACTS (one per contact relationship)
 HZ_CUST_ACCOUNT_ROLES (the contact's role on the account) → HZ_ROLE_RESPONSIBILITY (BILL_TO, STMTS, ...)
 HZ_CONTACT_POINTS     OWNER_TABLE_NAME = HZ_PARTIES or HZ_PARTY_SITES; CONTACT_POINT_TYPE EMAIL / PHONE

Cross-reference:
 HZ_ORIG_SYS_REFERENCES   ORIG_SYSTEM + ORIG_SYSTEM_REFERENCE → OWNER_TABLE_NAME + OWNER_TABLE_ID
 HZ_ORIG_SYSTEMS_B / _TL  the source systems;  HZ_ORIG_SYS_MAPPING  which entities each one may reference
```

### 1.3 Reference-data set versus business unit

This is the one place where Fusion differs from the EBS model most people remember.

- `HZ_CUST_ACCT_SITES_ALL` has **no ORG_ID**. A query on `s.org_id` returned ORA-00904 [DEV2]. Account sites and site uses are partitioned by **SET_ID** (a reference-data set, from `FND_SETID_SETS`). The import takes the set **code** (`SET_CODE`), upper case.
- A business unit is assigned a reference-data set per reference group. In DEV2, group `HZ_CUSTOMER_ACCOUNT_SITE` maps `RGE_US_BU`, `RGE_UK_PH_GBP_BU` and `RGE_PL_BU` to `ENTERPRISE`, and `RGE_UK_CW_EUR_BU` and `RGE_UK_NC_USD_BU` to `COMMON` [PROJECT, 2026-09-15 target facts]. A site in set `ENTERPRISE` is therefore visible to every BU that shares that set.
- The business unit (ORG_ID) appears on the **customer profile interface** (`RA_CUSTOMER_PROFILES_INT_ALL.ORG_ID`) and later on transactions [DEV2]. `HZ_CUST_SITE_USES_ALL` also carries SET_ID. Whether it carries an ORG_ID column in DEV2 was not checked [unverified].

Why it matters: choosing the BU and choosing the set are two separate decisions. For Picturehouse the set follows from the BU (`RGE_UK_PH_GBP_BU` → `ENTERPRISE`), but the BU itself is still an open decision (`CFG-C22`, workstream UK-02) [PROJECT].

### 1.4 Key columns per table

| Table | Key columns | Notes |
|---|---|---|
| HZ_PARTIES | PARTY_ID, PARTY_NUMBER, PARTY_TYPE, PARTY_NAME | All 746 account parties are ORGANIZATION [DEV2] |
| HZ_CUST_ACCOUNTS | CUST_ACCOUNT_ID, PARTY_ID, ACCOUNT_NUMBER, ACCOUNT_NAME, CUSTOMER_TYPE (R/I), CUSTOMER_CLASS_CODE, STATUS, ORIG_SYSTEM_REFERENCE, CREATED_BY_MODULE | FBDI-created rows carry CREATED_BY_MODULE `ORA_HZ_DATA_IMPORT`; UI rows `TCA_FORM_WRAPPER` [DEV2] |
| HZ_CUST_ACCT_SITES_ALL | CUST_ACCT_SITE_ID, CUST_ACCOUNT_ID, PARTY_SITE_ID, SET_ID, STATUS, BILL_TO_FLAG, SHIP_TO_FLAG, ORIG_SYSTEM_REFERENCE, START_DATE, END_DATE | No ORG_ID |
| HZ_CUST_SITE_USES_ALL | SITE_USE_ID, CUST_ACCT_SITE_ID, SITE_USE_CODE, PRIMARY_FLAG, STATUS, LOCATION, BILL_TO_SITE_USE_ID, PAYMENT_TERM_ID, TAX_CLASSIFICATION, SET_ID | LOCATION is the site-use name and must be unique. BILL_TO_SITE_USE_ID links a SHIP_TO to its BILL_TO |
| HZ_PARTY_SITES | PARTY_SITE_ID, PARTY_ID, LOCATION_ID, PARTY_SITE_NUMBER | |
| HZ_LOCATIONS | LOCATION_ID, ADDRESS1-4, CITY, STATE, PROVINCE, COUNTY, POSTAL_CODE, COUNTRY | |
| HZ_CUSTOMER_PROFILES_F | CUST_ACCOUNT_PROFILE_ID, CUST_ACCOUNT_ID, PARTY_ID, SITE_USE_ID, STATUS, PROFILE_CLASS_ID → HZ_CUST_PROFILE_CLASSES, COLLECTOR_ID → AR_COLLECTORS, STANDARD_TERMS → RA_TERMS_B.TERM_ID, OVERRIDE_TERMS, STATEMENT_CYCLE_ID → AR_STATEMENT_CYCLES, SEND_STATEMENTS, CREDIT_BALANCE_STATEMENTS, CREDIT_HOLD, CREDIT_CHECKING, TOLERANCE, AUTO_REC_INCL_DISPUTED_FLAG, ACCOUNT_STATUS, **CREDIT_LIMIT, CREDIT_CURRENCY_CODE**, EFFECTIVE_START_DATE, EFFECTIVE_END_DATE, CREATED_BY_MODULE | The plain name `HZ_CUSTOMER_PROFILES` returns ORA-00942. A current row is one where today falls between the effective dates. The profile row carries its own credit limit and currency as well as the per-currency rows in the _AMTS_F table |
| HZ_CUST_PROFILE_AMTS_F | CUST_ACCT_PROFILE_AMT_ID, CUST_ACCOUNT_PROFILE_ID → HZ_CUSTOMER_PROFILES_F, CUST_ACCOUNT_ID, SITE_USE_ID, CURRENCY_CODE, OVERALL_CREDIT_LIMIT, TRX_CREDIT_LIMIT, MIN_STATEMENT_AMOUNT, MIN_DUNNING_AMOUNT, EFFECTIVE_START_DATE, EFFECTIVE_END_DATE | `HZ_CUST_PROFILE_AMTS` returns ORA-00942 |
| HZ_CUST_PROFILE_CLASSES | PROFILE_CLASS_ID, NAME, STATUS, COLLECTOR_ID, STANDARD_TERMS, STATEMENT_CYCLE_ID, CREDIT_LIMIT, CREDIT_CURRENCY_CODE | Join on NAME to check CUSTOMER_PROFILE_CLASS_NAME |
| AR_COLLECTORS / AR_STATEMENT_CYCLES / RA_TERMS_TL | COLLECTOR_ID, NAME, STATUS, SET_ID / STATEMENT_CYCLE_ID, NAME, STATUS / TERM_ID, NAME, LANGUAGE, SET_ID | The name lookups for COLLECTOR_NAME, STATEMENT_CYCLE_NAME and STANDARD_TERM_NAME. Filter RA_TERMS_TL by LANGUAGE |
| HZ_RELATIONSHIPS | RELATIONSHIP_CODE (CONTACT_OF) | 4,668 forward CONTACT_OF rows = 4,668 HZ_ORG_CONTACTS [DEV2] |
| HZ_CUST_ACCOUNT_ROLES / HZ_ROLE_RESPONSIBILITY | account contact and its responsibility (BILL_TO, STMTS) | |
| HZ_CONTACT_POINTS | OWNER_TABLE_NAME, CONTACT_POINT_TYPE | |
| HZ_ORIG_SYS_REFERENCES | ORIG_SYSTEM_REF_ID, ORIG_SYSTEM, ORIG_SYSTEM_REFERENCE, OWNER_TABLE_NAME, OWNER_TABLE_ID, STATUS, START_DATE_ACTIVE, END_DATE_ACTIVE, PARTY_ID, CREATED_BY_MODULE, REQUEST_ID | The join from a GP key to a Fusion id |
| HZ_ORIG_SYSTEMS_B | ORIG_SYSTEM_ID, ORIG_SYSTEM, ORIG_SYSTEM_TYPE, STATUS, ENABLE_FOR_TCA_FLAG, START_DATE_ACTIVE, END_DATE_ACTIVE | `GP` is type SPOKE |

Oracle's Sales-edition table reference describes HZ_CUST_ACCT_SITES_ALL as storing "all customer account sites across all operating units", with HZ_CUST_SITE_USES_ALL as its child through CUST_ACCT_SITE_ID [DOC, search snippet of https://docs.oracle.com/en/cloud/saas/sales/oedms/hzcustacctsitesall-5591.html; the page returned 404 when fetched]. The Financials tables index is https://docs.oracle.com/en/cloud/saas/financials/23d/oedmf/financials-tables-and-views.html (found, not fetched). Per-column "required" flags from those pages could not be read [unverified].

---

## 2. Customer Import FBDI

### 2.1 Template and process [DOC]

Source: "How You Import Customer Data", Receivables implementation 25D, https://docs.oracle.com/en/cloud/saas/financials/25d/fairp/how-you-import-customer-data.html.

- Template: **Customer Import** (`CustomerImportTemplate.xlsm`). It has an instructions tab plus **19 interface tabs**, 1,254 columns in total [PROJECT]. Download it from *File-Based Data Import for Financials* → Customer Data Model → Customer Import. A local copy is at `~/Source/AutoConv/FBDI_Templates/Financials/CustomerImportTemplate.xlsm` [PROJECT].
- Upload by running **"Load Interface File for Import"** with Import Process **"Import Trading Community Data in Bulk"**. Data loads per batch and can be previewed before final processing.
- Rules: don't reorder or delete columns (hiding is allowed). Keep each tab at or below 50,000 records. Each customer needs a unique combination of customer number, account number and site number. On an update, `!` clears an existing profile value.
- Every template column resolves to a DEV2 interface column after upper-casing, but the interface views carry far more columns than the sheet (HZ_IMP_PARTIES_T: 843 in the view, 49 on the sheet) [PROJECT]. Build from the template's column list, not the view's.
- The simplified alternative, "Upload Customers from Spreadsheet" (source system `UPLOAD_CUSTOMER_SPREADSHEET`, 12 batches in DEV2), cannot carry profile attributes beyond profile class and business unit [PROJECT, KF-C42/C43]. A conversion needs the full template.

### 2.2 The 19 interface objects

The Oracle page lists these 19 objects, one per interface tab. The individual tab labels were not captured, so the tab-to-table pairing is inferred from the matching count [unverified].

| Interface object | Entity | Used by a GP conversion |
|---|---|---|
| HZ_IMP_PARTIES_T | organization or person party | Yes |
| HZ_IMP_LOCATIONS_T | address | Yes |
| HZ_IMP_PARTYSITES_T | party site (party → location) | Yes |
| HZ_IMP_PARTYSITEUSES_T | party site purpose | Yes (the GP batches had rows) |
| HZ_IMP_ACCOUNTS_T | customer account | Yes |
| HZ_IMP_ACCTSITES_T | account site | Yes |
| HZ_IMP_ACCTSITEUSES_T | account site use (BILL_TO, SHIP_TO) | Yes |
| RA_CUSTOMER_PROFILES_INT_ALL | profile **and** profile amounts on one row | Yes |
| HZ_IMP_CONTACTS_T | contact person / org contact | When contacts convert |
| HZ_IMP_RELSHIPS_T | CONTACT_OF relationship | When contacts convert |
| HZ_IMP_ACCTCONTACTS_T | account contact role | When contacts convert |
| HZ_IMP_CONTACTPTS_T | e-mail, phone | When contacts convert |
| HZ_IMP_CONTACTROLES | contact role | When contacts convert |
| HZ_IMP_ROLERESP | role responsibility (BILL_TO, STMTS) | When contacts convert |
| HZ_IMP_ACCOUNTRELS | account-to-account relationship | Excluded by scope choice 2026-09-15 [PROJECT] |
| HZ_IMP_CLASSIFICS_T | party classification | Excluded by scope choice 2026-09-15 [PROJECT] |
| HZ_IMP_PERSONLANG | person language | Optional |
| RA_CUST_PAY_METHOD_INT_ALL | customer payment method | Staged, not loaded in the AX stream (CFG-C24) |
| RA_CUSTOMER_BANKS_INT_ALL | customer bank account | Staged, not loaded in the AX stream (CFG-C25) |

The AX stream put 17 of the 19 in scope and built 15 headerless CSVs [PROJECT].

**Names that do NOT exist in DEV2.** Each was checked in `ALL_OBJECTS` and returned nothing [DEV2]. Don't use them:

| Wrong name | Use instead |
|---|---|
| HZ_IMP_CUSTOMER_PROFILES_T | RA_CUSTOMER_PROFILES_INT_ALL |
| HZ_IMP_CUST_PROFILE_AMTS_T | RA_CUSTOMER_PROFILES_INT_ALL (CURRENCY_CODE, OVERALL_CREDIT_LIMIT, TRX_CREDIT_LIMIT columns) |
| HZ_IMP_ACCT_SITES_T | HZ_IMP_ACCTSITES_T |
| HZ_IMP_ACCT_SITEUSES_T | HZ_IMP_ACCTSITEUSES_T |
| HZ_IMP_RELATIONSHIPS_T | HZ_IMP_RELSHIPS_T |
| HZ_CUSTOMER_PROFILES, HZ_CUST_PROFILE_AMTS (registry) | HZ_CUSTOMER_PROFILES_F, HZ_CUST_PROFILE_AMTS_F |
| RA_SALESREPS_ALL | not present (ORA-00942); there are no salesreps anyway |
| `HZ_IMP_BATCH_SUMMARY.ORIG_SYSTEM` | ORIGINAL_SYSTEM |
| `HZ_CUST_ACCT_SITES_ALL.ORG_ID` | SET_ID |

### 2.3 Source-system references: every row carries its own and its parent's

Each child row names its parent by the parent's source system (OS) plus source-system reference (OSR), never by a Fusion id. The import resolves the pair through HZ_ORIG_SYS_REFERENCES, so a child can be loaded into a parent that already exists in Fusion [DEV2].

| Interface | Own reference | Parent reference |
|---|---|---|
| HZ_IMP_PARTIES_T | PARTY_ORIG_SYSTEM, PARTY_ORIG_SYSTEM_REFERENCE | none |
| HZ_IMP_LOCATIONS_T | LOCATION_ORIG_SYSTEM, LOCATION_ORIG_SYSTEM_REFERENCE | none |
| HZ_IMP_PARTYSITES_T | SITE_ORIG_SYSTEM, SITE_ORIG_SYSTEM_REFERENCE | PARTY_ORIG_SYSTEM(+_REFERENCE), LOCATION_ORIG_SYSTEM(+_REFERENCE) |
| HZ_IMP_PARTYSITEUSES_T | SITEUSE_ORIG_SYSTEM(+_REF) | SITE_ORIG_SYSTEM(+_REFERENCE) |
| HZ_IMP_ACCOUNTS_T | CUST_ORIG_SYSTEM, CUST_ORIG_SYSTEM_REFERENCE | PARTY_ORIG_SYSTEM(+_REFERENCE) |
| HZ_IMP_ACCTSITES_T | CUST_SITE_ORIG_SYSTEM, CUST_SITE_ORIG_SYS_REF | CUST_ORIG_SYSTEM(+_REFERENCE); SITE_ORIG_SYSTEM(+_REFERENCE) for the party site |
| HZ_IMP_ACCTSITEUSES_T | CUST_SITEUSE_ORIG_SYSTEM, CUST_SITEUSE_ORIG_SYS_REF | CUST_SITE_ORIG_SYSTEM, CUST_SITE_ORIG_SYS_REF; BILL_TO_CUST_SITE_REF for a SHIP_TO |
| RA_CUSTOMER_PROFILES_INT_ALL | none of its own | CUST_ORIG_SYSTEM(+_REFERENCE); CUST_SITE_ORIG_SYS_REF (null = account level) |

Contact interfaces follow the same pattern, but their reference column names were not listed in the research [unverified]. Contact points on a contact need the person party keys populated alongside the relationship keys, or they fail `HZ_IMP_MISSING_PARENT` and `HZ_EDI_EFT_ORG_PARTIES_ONLY` [PROJECT, MAP-C17].

The source system is registered in **Manage Trading Community Source Systems** (code, type SPOKE or PURCHASED, enabled for Trading Community Members), and its referenceable entities are chosen in Manage Source System Entities. The code can't be changed after it is created [DOC, search snippets: https://docs.oracle.com/en/cloud/saas/sales/fagse/create-original-system-references.html and https://docs.oracle.com/en/cloud/saas/supply-chain-and-manufacturing/25b/faivc/manage-trading-community-source-systems-for-data-collections.html; neither page fetched].

### 2.4 Mandatory columns

The database reports every interface column as nullable, so mandatory-ness comes only from the template [PROJECT, MAP-C07]. The template's starred columns recorded on 2026-09-15 are [PROJECT]:

| Interface | Starred columns |
|---|---|
| HZ_IMP_PARTIES_T | BATCH_ID, PARTY_TYPE |
| HZ_IMP_LOCATIONS_T | BATCH_ID |
| HZ_IMP_PARTYSITES_T | BATCH_ID, IDENTIFYING_ADDRESS_FLAG |
| HZ_IMP_PARTYSITEUSES_T | BATCH_ID, SITE_USE_TYPE |
| HZ_IMP_ACCOUNTS_T | BATCH_ID |
| HZ_IMP_ACCTSITES_T | BATCH_ID, SET_CODE |
| HZ_IMP_ACCTSITEUSES_T | BATCH_ID, SITE_USE_CODE, SET_CODE |

That list is not the whole story. The profile import also rejects rows missing `CREDIT_BALANCE_STATEMENTS`, `COLLECTOR_NAME`, `TOLERANCE`, `OVERRIDE_TERMS` and `AUTO_REC_INCL_DISPUTED_FLAG`, none of which GP or AX supplies (errors `AR_CUSTIMP_CREDIT_BALANCE_REQ`, `AR_CUSTIMP_COLLECTOR_NAME_REQ`, `AR_CUSTIMP_TOLERANCE_REQ`, `AR_CUSTIMP_OVERRIDE_TERMS_REQ`, `AR_CUSTIMP_AUTOREC_DISPUTE_REQ`). The AX stream defaulted them to Y / AR Manager / 0 / Y / N from the RGE profile classes [PROJECT, F3, CFG-C33]. These validations run in sequence, so each reload reveals only the next missing column.

Template tooltips for the contact tabs and for RA_CUSTOMER_PROFILES_INT_ALL were not read [unverified]. **The practical minimum is the column set the working GP batch populated** (section 3.2): a batch that sends at least those columns, with the same shapes, is known to complete clean.

### 2.5 ESS chain and preview versus commit

Proven by the AX stream and documented in the playbook [PROJECT]:

1. `uploadFileToUCM` to UCM account `fin$/receivables$/import$`. It returns a DocumentId.
2. `InterfaceLoaderController` with arguments `4,<DocumentId>,N,N,`. Selector **4** means TCA bulk.
3. `CDMAutoBulkImportJob` with arguments batch id, batch name, `CUSTOMER`, source system (`GP` for this stream), then 17 optional arguments. **Argument 14 is "Run Batch in Preview Mode": `Y` validates only, `N` commits.**

All three go through `submitESSJobRequest`; `importBulkData` no longer works. Poll with `GET erpintegrations?finder=ESSJobStatusRF;requestId=...` (POST `getESSJobStatus` returns 400). `COMPLETED` counts as success, as does `SUCCEEDED`. Each run takes about 150 to 200 s.

`CDMAutoBulkImportJob` creates the `HZ_IMP_BATCH_SUMMARY` row from the batch id and name, so the batch need not be created in Manage Data Import first (CFG-C35). The project's batch-id convention is `YYYYMMDDnn`, ten digits, below both Fusion-generated ranges (UI `300000010…`, spreadsheet `100000035…`).

**Reading a batch afterwards** [DEV2, columns verified 2026-10-16]:

- **HZ_IMP_BATCH_SUMMARY**: one row per batch. BATCH_ID, BATCH_NAME, **ORIGINAL_SYSTEM** (not ORIG_SYSTEM), LOAD_TYPE, WHAT_IF_FLAG (preview), BATCH_STATUS (COMPLETED, COMPL_WHATIF, COMPL_ERRORS, PURGED, ACTIVE), CSV_STATUS, PROCESSED_STEP / IN_PROCESS_STEP / TO_PROCESS_STEP, PURGE_DATE, ERROR_MESSAGE, REQUEST_ID, CREATION_DATE.
- **HZ_IMP_ERRORS**: one row per error. BATCH_ID, INTERFACE_TABLE_NAME, MESSAGE_NAME (e.g. HZ_DUPLICATE_COMBINATION), ERROR_MSG_TEXT, ERROR_TYPE_CODE, TOKEN1_NAME/TOKEN1_VALUE through TOKEN5_NAME/TOKEN5_VALUE (the column and value that failed), REQUEST_ID.
- **HZ_IMP_ENTITY_DETAILS**: per-entity insert counts (NUM_INSERTED) used by the playbook. Its other column names were not verified.

Preview versus commit has two recorded positions:
- **Same batch, explicit N.** A preview leaves rows in the interface with batch status `COMPL_WHATIF`. The same batch then commits without a reload, but only if argument 14 is explicitly `N` (KF-C70 to C73, batch 2026091801).
- **New batch id.** The playbook (2026-09-21) says preview consumes the batch id and the commit needs a new id and a rebuilt zip.

The GP batches used the second pattern (`GP_PH_EXPAND20_PREVIEW` 2026100840, then `GP_PH_EXPAND20_COMMIT` 2026100841). Treat a new batch id as the safe default.

### 2.6 REST and SOAP

REST and the SOAP CustomerAccountService create customers record by record; they are meant for integrations. FBDI "Import Trading Community Data in Bulk" is the documented bulk route, and every prior DEV2 conversion used it [DEV2]. The REST pages could not be fetched [unverified].

---

## 3. DEV2 as configured on 2026-10-16

All figures in this section are [DEV2] from 2026-10-16 unless stated. Re-query before quoting them later; DEV2 changes daily.

### 3.1 Accounts and sources

- HZ_CUST_ACCOUNTS: **746** accounts, all STATUS A, created 2026-07-11 to 2026-10-15. CUSTOMER_TYPE R 725, I 2, null 19.
- By source system (HZ_ORIG_SYS_REFERENCES on the account):

| Source | Accounts |
|---|---|
| AX2012 | 664 |
| EXACT | 29 |
| **GP** | **25** |
| RGEPOS | 4 |
| none (created in the UI) | 24 |

- Source system `GP` = "Microsoft Dynamics GP", type SPOKE, active, created 2026-09-23. HZ_ORIG_SYS_MAPPING enables it for 19 entities, all with MULTIPLE_FLAG = N. Those include HZ_PARTIES, HZ_LOCATIONS, HZ_PARTY_SITES, HZ_PARTY_SITE_USES, HZ_CUST_ACCOUNTS, HZ_CUST_ACCT_SITES_ALL, HZ_CUST_SITE_USES_ALL, HZ_CONTACT_POINTS, HZ_RELATIONSHIPS, HZ_ORG_CONTACT_ROLES, HZ_CUST_ACCOUNT_ROLES, HZ_ROLE_RESPONSIBILITY and HZ_CUST_ACCT_RELATE_ALL. MULTIPLE_FLAG = N means one GP reference per Fusion record.
- Sites: 752 account sites (ENTERPRISE 746, US 5, UK 1); 741 accounts have one site. The conversion pattern is one site per account.
- Site uses: BILL_TO primary 746, BILL_TO non-primary 4, SHIP_TO 26, INV 3, ORA_SELF_SERVICE_USER 2, STMTS 1. 744 accounts have exactly one primary active BILL_TO and one has two (probably in different sets; not checked).
- No site use carries PAYMENT_TERM_ID or TAX_CLASSIFICATION, so terms come from the profile.

### 3.2 The three GP batches and their pattern

| Batch id | Batch name | Status | Date |
|---|---|---|---|
| 2026100703 | GP_PH_PROVING_5 | COMPLETED (import status S) | 2026-10-08 |
| 2026100840 | GP_PH_EXPAND20_PREVIEW | COMPL_WHATIF | 2026-10-09 |
| 2026100841 | GP_PH_EXPAND20_COMMIT | COMPLETED | 2026-10-09 |

Result: 25 GP accounts, all UK Picturehouse customers (Curzon, Picturehouse, Everyman, Channel Four and others). No GP batch appears in the error-bearing batch list. GP refs also exist for 5 relationships, 5 account roles, 6 contact points and 7 role responsibilities.

The pattern they used, which is the practical column minimum (section 2.4):

| Element | Value used |
|---|---|
| Source system, every entity | `GP` |
| Party OSR = account OSR = ACCOUNT_NUMBER | `<COMPANY>-<CUSTNMBR>`, e.g. `PHEN2-D00189`, `PHTRA-Dnnnnn` |
| Location OSR, party-site OSR, account-site OSR | `<cust>-MAIN` |
| Account site-use OSR | `<cust>-MAIN-BILL_TO` |
| PARTY_TYPE / PARTY_USAGE_CODE / INSERT_UPDATE_FLAG | ORGANIZATION / CUSTOMER / I |
| CUSTOMER_TYPE / CUSTOMER_CLASS_CODE | R / B2B |
| Location | COUNTRY GB, CITY e.g. London, POSTAL_CODE e.g. WC2B 5LR, STATE and COUNTY null |
| SET_CODE (account site and site use) | ENTERPRISE |
| Site use | BILL_TO, PRIMARY_FLAG Y, LOCATION numeric (11006…) |
| Profile | class DEFAULT, collector AR Manager, term Net 30, cycle Monthly, CREDIT_CHECKING N, CREDIT_HOLD N, STATEMENTS Y, DUNNING_LETTERS N, no currency or credit limit |
| Profile ORG_ID | 300000004842930 = RGE_UK_PH_GBP_BU |

The company prefix exists because the same CUSTNMBR can appear in more than one GP company database. Prefixing makes the reference unique across PHTRA, PHEN2 and PHBOO. It does repeat: on 2026-10-16 PHTRA and PHEN2 shared 1,163 customer numbers, with no matching names behind them (`gp-source-model.md` section 5) [GP, verified].

### 3.3 Reference data

| Object | Values in DEV2 |
|---|---|
| Profile classes (HZ_CUST_PROFILE_CLASSES) | DEFAULT (id 0: no term, Default Collector, credit check Y, statements N, dunning N); RGE Good Credit (Net 30, AR Manager, Y/Y/Y, limit 50,000 no currency); RGE Bad Credit (Net 0, AR Manager, Y/Y/Y, 1,000 USD); ORA_HED_BFB (seeded) |
| Payment terms (RA_TERMS_TL) | IMMEDIATE, Net 0, Net 1, Net 14, Net 15, Net 30, Net 45, Net 60, ORA_HES; "30" is end-dated |
| Collectors (AR_COLLECTORS) | AR Manager, Default Collector |
| Statement cycles | Monthly, ORA_Quarterly, ORA_Weekly |
| Reference-data sets on sites | ENTERPRISE (id 300000000003006), US, UK. All sets: COMMON, ENTERPRISE, GLOBAL, INTERNATIONAL, UK, US, CCI [PROJECT] |
| UK business units | UK GBP ledger `RGE_UK_USGAAP_GBP_PL`: RGE_UK_PH_GBP_BU (used by GP), PH BU, CBC2, CBRC, CECL, CHHL, CPCL, CUKL, CWCL. UK USD ledger: RGE_UK_NC_USD_BU. RGE_UK_CW_EUR_BU has no ledger |
| Ledgers | RGE_US_USGAAP_USD_PL1, RGE_UK_USGAAP_GBP_PL, RGE_UK_USGAAP_USD_PL, RGE_PL_USGAAP_PLN_PL |
| UK receipt methods (active) | RECS_UK_BARC_3416_GBP, XREC_UK_BARC_3416_GBP, UK_AP/AR Netting |
| Customer class codes on accounts | null 498, GRP_SLS 42, B2B 36, CHURCH_REN 32, CBO_PROD 22, STUDIO_CON 21, TRAIL_AUCT 20, WEB_ADVERT 17, CONCES_REB 17, MISC 11, STUDIO_MED 10, SCRN_HIRE 5, FEDERAL 5, MKTG 4, PUBLIC SECTOR COMPANIES 2, CAP_COMP 1, MKTG_FUND 1, PROJLEASE 1, CBO_GC 1 |
| Customer class lookup | No rows under type `CUSTOMER_CLASS` in FND_LOOKUP_VALUES_VL. The type name is probably `CUSTOMER CLASS` with a space [unverified]. On 2026-09-15 it held only FEDERAL and PUBLIC SECTOR COMPANIES [PROJECT] |
| Other lookups | CUSTOMER_TYPE I/R; SITE_USE_CODE 18 values (BILL_TO, SHIP_TO, STMTS, DUN, …); PARTY_SITE_USE_CODE 20 values; CUSTOMER_CATEGORY 43 seeded |
| Numbering | HZ_GENERATE_CUSTOMER_NUMBER, HZ_GENERATE_PARTY_NUMBER, HZ_GENERATE_PARTY_SITE_NUMBER, HZ_AUTO_SITE_NUMBERING, HZ_GENERATE_CONTACT_NUMBER all `AUTO_NUMBERING` at site level |
| Address validation | HZ_IMP_DEFAULT_GEO_VALID_ADDRESS = N at site level (its import effect is unverified). HZ_GEOGRAPHY_VALIDATIONS holds only HZ_RT_ADDR_CLEANSE_OPTIONS = OPTIONAL for GB, PL, US. US validation is Error at State level [PROJECT, CFG-C26]. Where the per-country level is stored was not found [unverified] |
| Geography mapping (HZ_LOCATIONS) | GB: COUNTY > COUNTY, **CITY > TOWNSHIP**, POSTAL_CODE. US: STATE, COUNTY, CITY, POSTAL_CODE. GB geography is loaded (about 1.9M rows: COUNTY, TOWNSHIP, POSTAL_CODE) |

About numbering: the AX stream decided to keep legacy account numbers and set account numbering to `NOAUTONUM_NOUPDATE` (CFG-C17) [PROJECT]. DEV2 still reads AUTO_NUMBERING today, yet the GP batches supplied ACCOUNT_NUMBER (`PHEN2-D00189`) and Fusion kept it. AX, EXACT and RGEPOS left it blank and got numbers 12041 to 13004. So a supplied number is accepted with auto-numbering on. That is observed behaviour with no Oracle document behind it [unverified as a rule]. Party numbers are auto-assigned either way; the GP key survives only in the OSR.

### 3.4 What is NOT in use

- Salespersons: JTF_RS_SALESREPS has 0 rows; RA_SALESREPS_ALL doesn't exist. Nothing to map.
- Carriers and ship methods: WSH_CARRIERS has 0 rows; WSH_CARRIER_SERVICES doesn't exist.
- Descriptive flexfields: ATTRIBUTE_CATEGORY and ATTRIBUTE1-5 are null on every account, account site, site use and account party.
- Credit limits: HZ_CUST_PROFILE_AMTS_F has 7 rows, all USD, none with a limit. No stream has converted credit limits.
- Site-use tax classification and payment terms: used 0 times. Party tax profiles: THIRD_PARTY 54, THIRD_PARTY_SITE 5; most customers have none.
- COUNTY on HZ_LOCATIONS: never populated, even for US.

### 3.5 Import errors seen

HZ_IMP_ERRORS holds 422 rows across all sources; none are from GP batches.

| Interface | Message | Count | What it means |
|---|---|---|---|
| HZ_IMP_PARTIES_T | HZ_DUPLICATE_COMBINATION | 48 | OS/OSR already exists; an insert was sent for a record already loaded |
| HZ_IMP_CONTACTPTS_T | HZ_DUPLICATE_COMBINATION | 36 | same |
| CONTACTS / RELSHIPS / ACCTCONTACTS | HZ_DUPLICATE_COMBINATION | 28 each | same |
| LOCATIONS / PARTYSITES / ACCTSITES | HZ_DUPLICATE_COMBINATION | 24 each | same |
| HZ_IMP_PARTYSITEUSES_T | HZ_DE_INVALID_DATERANGE | 20 | site-use dates outside the site's dates (PL_EXACT_EXPAND20) |
| PARTYSITEUSES / ACCTSITEUSES / ACCOUNTS | HZ_DUPLICATE_COMBINATION | 20 each | same as above |
| RA_CUSTOMER_PROFILES_INT_ALL | AR_CUSTIMP_PF_BAD_CUST_REF | 20 | profile's CUST OSR matched no account (EXACT) |
| HZ_IMP_ROLERESP | HZ_IMP_INVAL_VALUE_COMPARE | 11 | invalid coded value |
| HZ_IMP_CONTACTROLES | HZ_API_UNIQUE_PRIMARY_ORG_CONT | 7 | more than one primary contact per organization |

Smaller ones: HZ_WRONG_PARTY_TYPE (PARTY_TYPE doesn't match the name columns), HZ_IMP_INVAL_PARENT_ENTITY_REF (account pointed at a party OSR that doesn't resolve), HZ_IMP_REQ_ATTRIB on PARTY_SITE_ID, invalid SET_CODE, invalid HOUSE_TYPE and TIMEZONE_CODE on locations. The batch summary also records "The OS/OSR combination RGEPOS/100001 already exists."

---

## 4. Mapping targets

For each Fusion attribute a GP conversion populates: where it goes, what DEV2 accepts, and where to check. Which GP column feeds it belongs in the GP-side mapping reference, not here.

| Fusion attribute | Import column | Valid values in DEV2 | Check against |
|---|---|---|---|
| Party type | HZ_IMP_PARTIES_T.PARTY_TYPE | ORGANIZATION (PERSON for contacts) | must match the name columns used |
| Party name | HZ_IMP_PARTIES_T.ORGANIZATION_NAME | trimmed text | HZ_PARTIES.PARTY_NAME |
| Party usage | HZ_IMP_PARTIES_T.PARTY_USAGE_CODE | CUSTOMER | the GP batches |
| Insert or update | INSERT_UPDATE_FLAG | I first load, U re-run | HZ_ORIG_SYS_REFERENCES (does the OSR exist?) |
| Source system, every row | *_ORIG_SYSTEM | GP | HZ_ORIG_SYSTEMS_B, HZ_ORIG_SYS_MAPPING |
| Party / account reference | PARTY_ORIG_SYSTEM_REFERENCE, CUST_ORIG_SYSTEM_REFERENCE | `<COMPANY>-<CUSTNMBR>`, trimmed | HZ_ORIG_SYS_REFERENCES |
| Account number | HZ_IMP_ACCOUNTS_T.ACCOUNT_NUMBER | same as the account OSR; length 1–12 seen in DEV2 (maximum length not verified) | HZ_CUST_ACCOUNTS.ACCOUNT_NUMBER, numbering profile options |
| Account name | HZ_IMP_ACCOUNTS_T.ACCOUNT_NAME | trimmed text | |
| Account type | HZ_IMP_ACCOUNTS_T.CUSTOMER_TYPE | R external, I internal | lookup CUSTOMER_TYPE |
| Customer class | HZ_IMP_ACCOUNTS_T.CUSTOMER_CLASS_CODE | a code that exists in the class lookup; B2B used for GP | class lookup (type name unverified, see 3.3) |
| Address | HZ_IMP_LOCATIONS_T.ADDRESS1-4, CITY, POSTAL_CODE, COUNTRY | GB: CITY is a TOWNSHIP, STATE blank | HZ_GEOGRAPHIES, HZ_GEO_STRUCT_MAP |
| US state | HZ_IMP_LOCATIONS_T.STATE | required for US | US validation Error at State level |
| Optional location codes | HOUSE_TYPE, TIMEZONE_CODE | leave blank | lookup-validated; invalid values error |
| Identifying address | HZ_IMP_PARTYSITES_T.IDENTIFYING_ADDRESS_FLAG | Y for the main site | template star |
| Party site purpose | HZ_IMP_PARTYSITEUSES_T.SITE_USE_TYPE | PARTY_SITE_USE_CODE values (BILL_TO, …) | lookup PARTY_SITE_USE_CODE |
| Account site set | HZ_IMP_ACCTSITES_T.SET_CODE | ENTERPRISE (upper case code, not the id) | FND_SETID_SETS, BU set assignment |
| Account site use | HZ_IMP_ACCTSITEUSES_T.SITE_USE_CODE, PRIMARY_FLAG, SET_CODE | BILL_TO, Y, ENTERPRISE | lookup SITE_USE_CODE |
| Site-use name | HZ_IMP_ACCTSITEUSES_T.LOCATION | unique per site use | |
| Ship-to → bill-to | HZ_IMP_ACCTSITEUSES_T.BILL_TO_CUST_SITE_REF | the bill-to site OSR | only when a SHIP_TO is loaded |
| Site and site-use dates | START_DATE / END_DATE | site-use range inside the site range | HZ_DE_INVALID_DATERANGE |
| Profile class | RA_CUSTOMER_PROFILES_INT_ALL.CUSTOMER_PROFILE_CLASS_NAME | DEFAULT, RGE Good Credit, RGE Bad Credit | HZ_CUST_PROFILE_CLASSES |
| Collector | COLLECTOR_NAME | AR Manager, Default Collector | AR_COLLECTORS |
| Payment terms | STANDARD_TERM_NAME | Net 0/1/14/15/30/45/60, IMMEDIATE | RA_TERMS_TL |
| Statement cycle | STATEMENT_CYCLE_NAME | Monthly, ORA_Quarterly, ORA_Weekly | AR_STATEMENT_CYCLES |
| Credit, statement and dunning flags | CREDIT_CHECKING, CREDIT_HOLD, STATEMENTS, DUNNING_LETTERS | GP batches used N, N, Y, N | profile class defaults |
| Import-required profile defaults | CREDIT_BALANCE_STATEMENTS, COLLECTOR_NAME, TOLERANCE, OVERRIDE_TERMS, AUTO_REC_INCL_DISPUTED_FLAG | AX stream used Y, AR Manager, 0, Y, N | section 2.4 |
| Business unit | RA_CUSTOMER_PROFILES_INT_ALL.ORG_ID | 300000004842930 (RGE_UK_PH_GBP_BU) used so far; decision open (CFG-C22) | HR_OPERATING_UNITS |
| Credit limits | CURRENCY_CODE, OVERALL_CREDIT_LIMIT, TRX_CREDIT_LIMIT | not used anywhere in DEV2 | HZ_CUST_PROFILE_AMTS_F, and CREDIT_LIMIT / CREDIT_CURRENCY_CODE on HZ_CUSTOMER_PROFILES_F |
| Billing contact e-mail | HZ_IMP_CONTACTS_T, HZ_IMP_RELSHIPS_T (CONTACT_OF), HZ_IMP_ACCTCONTACTS_T, HZ_IMP_CONTACTPTS_T (EMAIL), HZ_IMP_ROLERESP (BILL_TO, STMTS) | one primary contact per org | HZ_RELATIONSHIPS, HZ_CONTACT_POINTS |

Salesperson, carrier, DFF, site-use tax classification and site-use payment terms have no mapping target: none is in use in DEV2 (section 3.4).

---

## 5. Known traps

Each trap gives the rule, why it exists and the evidence.

1. **A profile imports only with its account row in the same batch.** Batches that sent profile rows alone reported "imported" and wrote nothing. A batch that sent the account (U) plus the profile (I) together created all six. Profiles are INSERT even when the account is UPDATE. [PROJECT, MAP-C18/MAP-C20, Addendum 6h]
2. **Verify in the registry tables, never from the job or batch summary.** A profile import reported 6 inserted, 6 imported, 0 errors while HZ_CUSTOMER_PROFILES_F held 0 rows (MAP-C19). Oracle MOS 2339559.1 describes customers created without a profile even when the tab is filled (search snippet only). Run `scripts/fusion_post_load_checks.sql` after every commit. [PROJECT; DOC partially]
3. **The profile appears about 30 s after the job reports done.** Wait, and check the batch counts for `CUSTOMER_PROFILE`, before concluding it failed or re-sending it. [PROJECT, KF-C54; playbook section 8]
4. **Preview does not validate profiles.** CUSTOMER_PROFILE is absent from HZ_IMP_ENTITY_DETAILS in preview (16 of 17 entities) and appears only on commit. A clean preview followed by a profile failure on commit is expected behaviour, so read section 2.4's required profile columns before the first commit. [PROJECT, KF-C71, F11]
5. **A blank argument 14 imports nothing.** The batch finishes `COMPL_WHATIF` and looks like a load. Five customers were reported as loaded when only a preview had run. Pass `Y` or `N` explicitly, every time. [PROJECT, F10, KF-C70 to C73]
6. **Batch-id collisions.** Batch id 2026091701 already held another user's completed batch, so CDMAutoBulkImportJob ended in error and no customer was created. Query HZ_IMP_BATCH_SUMMARY for the day's `YYYYMMDDnn` range before building the zip. A successfully imported batch can't be re-run. A SQL*Loader failure leaves no batch record, so that id is reusable. [PROJECT, F6, KF-C75, KF-C52]
7. **Wrong tenant.** A preview ran on `iartqy-dev1` because the host was typed by hand. DEV2 is `https://ichqjb-dev2.fa.ocs.oraclecloud.com/`. Confirm the host against the registered pod list before any submit. [PROJECT, F9; playbook sections 2 and 9]
8. **A missing class code loads silently.** If CUSTOMER_CLASS_CODE isn't in the class lookup, the account stages with an empty class and the load does not fail: 2,537 of 2,537 AX accounts loaded with no class (KF-C74). Check every GP class value against the lookup before building, and check `CUSTOMER_CLASS_CODE IS NULL` after. [PROJECT, CFG-C19]
9. **GB city is a TOWNSHIP, and GB state is blank.** DEV2 maps GB CITY to geography level TOWNSHIP, with COUNTY and POSTAL_CODE. The GP batches loaded STATE null, and 53 of 57 GB locations have no state. One GP row has city "Essex", a county loaded as the city. Put the town in CITY and the county in COUNTY, and leave STATE empty. (The AX stream's GB "state" carried constituent-country text with a trailing carriage return on 5,834 rows, which is a warning about source text, not a field to copy.) [DEV2; PROJECT, CFG-C26]
10. **US needs a state.** DEV2 US validation is Error at State level: 85 of 2,876 AX US locations without a state were rejected. A GP customer with a US address must carry a valid STATE. US tax zones (Vertex-style) are loaded, so an address that imports may still fail tax determination later [unverified]. [PROJECT, CFG-C26; DEV2]
11. **Re-loading existing references fails; re-runs must be updates.** `HZ_DUPLICATE_COMBINATION` is the top DEV2 error (48 on parties, 20 to 36 on each other entity). An AX batch hit 36 error rows on two accounts that earlier test loads had already created (F7). Before each batch, subtract OSRs already in HZ_ORIG_SYS_REFERENCES for `GP`, or send them with INSERT_UPDATE_FLAG = U. The 25 GP accounts already in DEV2 are in that set. [DEV2; PROJECT, F7]
12. **Trim padded text.** GP `char` columns are space-padded. Fusion does not trim: one AX account name is stored with trailing blanks. Trim every name, address line, city, postcode and reference before it reaches the CSV, because an untrimmed OSR is a different reference from the trimmed one. [DEV2; GP source skill rule]
13. **Site-use dates must sit inside site dates.** `HZ_DE_INVALID_DATERANGE` occurred 20 times on HZ_IMP_PARTYSITEUSES_T in an EXACT batch. Derive site-use START_DATE and END_DATE from the parent site's, never independently. [DEV2]
14. **SET_CODE takes the upper-case code.** A numeric set id, or `Enterprise` in mixed case, failed `HZ_IMP_INVAL_VALUE_COMPARE` on every row. Use `ENTERPRISE`. [PROJECT, F1, CFG-C30]
15. **The parent must resolve.** `HZ_IMP_INVAL_PARENT_ENTITY_REF` (account → party) and `AR_CUSTIMP_PF_BAD_CUST_REF` (profile → account) both mean a child's parent OS/OSR is neither in the batch nor in Fusion. Build every child reference from the same trimmed key as the parent. [DEV2]
16. **Empty values must be empty.** A CSV writer that emits the text `NULL` fails flag, date and number columns at the SQL*Loader stage and rolls the whole file back. [PROJECT, F5, MAP-C26]
17. **Confirm customers before any transaction load.** AutoInvoice rejected lines with "You must enter a valid original system bill-to customer reference" because the customer load had silently failed. [PROJECT, F8, KF-C76]

---

## 6. Sources

- How You Import Customer Data (Receivables 25D): https://docs.oracle.com/en/cloud/saas/financials/25d/fairp/how-you-import-customer-data.html (fetched)
- Guidelines for Uploading Customer Data Using a Simplified Spreadsheet: https://docs.oracle.com/en/cloud/saas/financials/25b/fairp/guidelines-for-uploading-customer-data-using-a-simplified.html (redirected when fetched)
- HZ_CUST_ACCT_SITES_ALL table reference: https://docs.oracle.com/en/cloud/saas/sales/oedms/hzcustacctsitesall-5591.html (404; search snippet)
- Financials Tables and Views: https://docs.oracle.com/en/cloud/saas/financials/23d/oedmf/financials-tables-and-views.html (not fetched)
- Create Original System References: https://docs.oracle.com/en/cloud/saas/sales/fagse/create-original-system-references.html (search snippet)
- Manage Trading Community Source Systems: https://docs.oracle.com/en/cloud/saas/supply-chain-and-manufacturing/25b/faivc/manage-trading-community-source-systems-for-data-collections.html (search snippet)
- MOS 2339559.1, customer created without profile (search snippet only)
- AX to Fusion FBDI conversion playbook: `/Users/jonathanstevenson/Source/AIX-GreenLight/docs/playbooks/ax-to-fusion-fbdi-conversion-playbook.md`
- AX customer stream design pack and issues log: `/Users/jonathanstevenson/Source/AIX-GreenLight/docs/design/conversion-redesign/us_customer_conversion_design_v20260918_1/` (`05_reference/05_issues_log.md`, `06_pipeline/RUNBOOK.md`)
- DEV2 observations: read-only queries on `ichqjb-dev2`, FUSION schema, 2026-10-16
