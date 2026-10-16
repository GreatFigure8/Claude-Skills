# Field mapping: GP 2010 Picturehouse customers to the Fusion Customer Import

What this file is for: column by column, where each Customer Import (FBDI) interface column
gets its value for a Picturehouse customer (PHTRA, PHEN2, PHBOO), the rule that converts it,
and how sure we are. `gp-source-model.md` says what GP holds; `fusion-target-model.md` says
what DEV2 accepts. This file joins the two.

Every mapping carries one status:
- **verified**: used by a GP batch that completed on DEV2 (2026100703 `GP_PH_PROVING_5`,
  2026100841 `GP_PH_EXPAND20_COMMIT`), as observed in the DEV2 registry on 2026-10-16, or
  used by the AX stream's DEV2 loads that completed.
- **documented**: stated by Oracle, by the template, by Greenlight's *Oracle Customer
  Conversion Rules* skill, or by a project decision log, but not exercised by a GP batch.
- **proposed**: this file's reasoning. Each one is flagged for Jonathan and must be agreed
  before a load.

## Contents

1. [Evidence keys](#1-evidence-keys)
2. [Rules that apply to every table](#2-rules-that-apply-to-every-table)
3. [Reference scheme](#3-reference-scheme)
4. [HZ_IMP_PARTIES_T](#4-hz_imp_parties_t)
5. [HZ_IMP_LOCATIONS_T](#5-hz_imp_locations_t)
6. [HZ_IMP_PARTYSITES_T](#6-hz_imp_partysites_t)
7. [HZ_IMP_PARTYSITEUSES_T](#7-hz_imp_partysiteuses_t)
8. [HZ_IMP_ACCOUNTS_T](#8-hz_imp_accounts_t)
9. [HZ_IMP_ACCTSITES_T](#9-hz_imp_acctsites_t)
10. [HZ_IMP_ACCTSITEUSES_T](#10-hz_imp_acctsiteuses_t)
11. [RA_CUSTOMER_PROFILES_INT_ALL](#11-ra_customer_profiles_int_all)
12. [Contacts and contact points](#12-contacts-and-contact-points)
13. [Value crosswalks](#13-value-crosswalks)
14. [No source in GP](#14-no-source-in-gp)
15. [No target in Fusion](#15-no-target-in-fusion)
16. [Decisions waiting on Jonathan](#16-decisions-waiting-on-jonathan)
17. [Sources](#17-sources)

---

## 1. Evidence keys

| Key | Meaning |
|---|---|
| GPB | The DEV2 GP batches. The column pattern is in `fusion-target-model.md` section 3.2 and the research file `fusion-customer-model.md` section 2.2 (populated columns read from batch 2026100703). |
| TPL | The template column list `template_columns_CustomerImportTemplate.csv` (positions, starred columns, lengths in the column comment). The data-type column in that file is shifted in places; trust the comment text. |
| GLR | Greenlight skill *Oracle Customer Conversion Rules*, required-field table and invariants. |
| AXS | The AX stream's staging SQL `sql/14_stage_ax_customer_fbdi.sql`, whose batches completed on DEV2. |
| GOLD | The golden US customer run's fill SQL (AX, target DEV1, source system `CSV`, not loaded). Used only for column names. |
| LOG | AX customer issues log ids (`KF-C*`, `CFG-C*`, `MAP-C*`) and the playbook. |
| SRC | `gp-source-model.md`, with its section number. |
| TGT | `fusion-target-model.md`, with its section number. |
| PHF | Greenlight's 2026-10-16 PH workbook fill (all 9,669 customers). It was **not loaded**, and it used source system `PH_GP` and ORG_ID `210`, neither of which matches DEV2. Cite it only for what it measured. |

---

## 2. Rules that apply to every table

| # | Rule | Why | Status |
|---|---|---|---|
| G1 | `RTRIM` every GP `char` column on extract, and trim again before the CSV is written. | GP pads `char(n)` with spaces and never stores NULL. Fusion does not trim: an AX account name is stored with trailing blanks, and an untrimmed reference is a different reference. (SRC 4; TGT trap 12) | verified (extract script; GPB references are trimmed) |
| G2 | A trimmed empty string becomes an empty CSV field, never the text `NULL`. | A CSV writer that emitted `NULL` failed the SQL*Loader stage and rolled back the whole file (F5, MAP-C26). | verified (LOG) |
| G3 | `1900-01-01` becomes NULL. | GP stores "no date" as 1900-01-01. FRSTINDT is 1900-01-01 on 100% of customers. (SRC 5, fact 8) | documented |
| G4 | Dates are written `YYYY/MM/DD`. | The template comments ask for that format, and the AX staging SQL writes it. (TPL; AXS) | verified (AXS) |
| G5 | `BATCH_ID` is the same 10-digit `YYYYMMDDnn` on every row of every file, and the zip name carries it. | One logical batch is one BATCH_ID everywhere (GLR). The loader script refuses a zip whose name lacks the id. | verified (GPB, LOG) |
| G6 | Every `*_ORIG_SYSTEM` column is `GP`. | `GP` ("Microsoft Dynamics GP", SPOKE) is the source system registered on DEV2 on 2026-09-23 and used by all three GP batches. PHF's `PH_GP` is not registered. (TGT 3.1) | verified |
| G7 | `INSERT_UPDATE_FLAG` is `I` for a reference not yet in `HZ_ORIG_SYS_REFERENCES` for `GP`, and `U` for one that is. Profiles are always `I`. | Re-inserting an existing reference fails `HZ_DUPLICATE_COMBINATION`, the top DEV2 error. 25 GP accounts already exist. A profile is INSERT even when its account is UPDATE (MAP-C18). (TGT traps 1, 11) | verified (GPB used I; the U/I rule is LOG) |
| G8 | No value contains a line break. | The format builder raises on a CR or LF inside a value. Strip CR/LF from GP text first (the golden SQL replaced them with spaces). | documented (format builder; GOLD) |
| G9 | Keep values out of coded columns you cannot validate (HOUSE_TYPE, TIMEZONE_CODE and similar). | Lookup-validated columns with a bad value error on DEV2. (TGT 3.5) | verified (DEV2 errors) |
| G10 | Personal data (contact names, emails, phones) is pulled only in the controlled build run, never into a Claude session or a report. | Many PHTRA customers are individuals. (SRC 5, fact 9) | documented |

---

## 3. Reference scheme

This is the scheme the DEV2 GP batches used. Keep it exactly, so a re-run resolves to the
records already loaded.

| Entity | Reference column(s) | Value | Example | Status |
|---|---|---|---|---|
| Party | `PARTY_ORIG_SYSTEM_REFERENCE` | `<COMPANY>-<CUSTNMBR>` | `PHEN2-D00189` | verified |
| Account | `CUST_ORIG_SYSTEM_REFERENCE` | same as the party reference | `PHEN2-D00189` | verified |
| Account number | `ACCOUNT_NUMBER` (accounts, account sites, site uses, profiles) | same as the account reference | `PHEN2-D00189` | verified |
| Location | `LOCATION_ORIG_SYSTEM_REFERENCE` | `<cust ref>-MAIN` | `PHEN2-D00189-MAIN` | verified |
| Party site | `SITE_ORIG_SYSTEM_REFERENCE` | `<cust ref>-MAIN` | `PHEN2-D00189-MAIN` | verified |
| Account site | `CUST_SITE_ORIG_SYS_REF` | `<cust ref>-MAIN` | `PHEN2-D00189-MAIN` | verified |
| Account site use | `CUST_SITEUSE_ORIG_SYS_REF` | `<cust ref>-MAIN-BILL_TO` | `PHEN2-D00189-MAIN-BILL_TO` | verified |
| Party site use | `SITEUSE_ORIG_SYSTEM_REF` | `<cust ref>-MAIN-BILL_TO` | | proposed (the GPB rows exist; their value was not captured) |

Rules:
- `<COMPANY>` is the GP database name (`SY01500.INTERID`), which the extract stamps as
  `company_code` from `DB_NAME()`. `<CUSTNMBR>` is `RTRIM(RM00101.CUSTNMBR)` with no other
  change. The outlier `DO5594` (letter O) is kept as is: it is the customer's key in GP.
  **verified** for the prefix pattern.
- The prefix is not optional. PHTRA and PHEN2 share 1,163 customer numbers, and 0 of those
  pairs have the same name (SRC 5, fact 1). `fusion-target-model.md` section 3.2 records the clash as
  verified (GP research, 2026-10-16).
- `MAIN` is a **literal**, not `RTRIM(ADRSCODE)`. Every customer collapses to one site (SRC 5,
  fact 7), and 12 address IDs are typos (`M`, `MAI`, `MIAN`, `MIN`, `MAON`, a street name).
  Using the literal keeps typos out of references and matches the GP batches. The literal
  itself is **verified**; using it for a typo address ID is **proposed**.
- `ACCOUNT_NUMBER` length: 12 characters for a 6-character CUSTNMBR, 13 for the 7-character
  outliers. The template comment declares `VARCHAR2(30)` (TPL), and DEV2 kept the supplied
  number even with auto-numbering on (TGT 3.3). **verified** in practice, **documented** for
  the length.

---

## 4. HZ_IMP_PARTIES_T

One row per selected customer. Load order 1.

| Fusion column | Req | GP source | Rule | DEV2 values | Status | Notes and evidence |
|---|---|---|---|---|---|---|
| BATCH_ID | Y (TPL, GLR) | literal | G5 | `YYYYMMDDnn` | verified | GPB |
| PARTY_ORIG_SYSTEM | | literal | `GP` | `GP` | verified | G6 |
| PARTY_ORIG_SYSTEM_REFERENCE | | `company_code`, `CUSTNMBR` | `<COMPANY>-<CUSTNMBR>` | | verified | section 3 |
| INSERT_UPDATE_FLAG | | derived | G7 | I / U | verified | GPB used I |
| PARTY_TYPE | Y (TPL, GLR) | literal | `ORGANIZATION` | ORGANIZATION, PERSON | verified | All 746 DEV2 account parties are ORGANIZATION. PERSON for individuals is open (section 16, D3). |
| PARTY_USAGE_CODE | | literal | `CUSTOMER` | CUSTOMER | verified | GPB; AXS |
| ORGANIZATION_NAME | | `RM00101.CUSTNAME` | RTRIM; strip CR/LF; max 360 | free text | verified | GP max length is 62 (SRC 3.1), well under 360. |
| PERSON_FIRST_NAME / PERSON_LAST_NAME | when PERSON | `CUSTNAME` split | only if D3 chooses PERSON | | proposed | `HZ_WRONG_PARTY_TYPE` fires when PARTY_TYPE doesn't match the name columns (TGT 3.5). |
| PARTY_NUMBER | | none | leave blank | auto-numbered | verified | DEV2 assigns party numbers (`HZ_GENERATE_PARTY_NUMBER` = AUTO_NUMBERING). The GP key survives only in the reference. |
| JGZZ_FISCAL_CODE | | `RM00101.TXRGNNUM` | leave blank | | proposed | 1 PHTRA and 5 PHEN2 customers carry a VAT number. Whether a VAT number belongs here or in a party tax profile is not established (section 14). |

---

## 5. HZ_IMP_LOCATIONS_T

One row per selected customer: the primary address from RM00102, or RM00101's copy for the
19 PHTRA customers with no address row (extract column `address_source`). Load order 2.

| Fusion column | Req | GP source | Rule | DEV2 values | Status | Notes and evidence |
|---|---|---|---|---|---|---|
| BATCH_ID | Y | literal | G5 | | verified | |
| LOCATION_ORIG_SYSTEM | | literal | `GP` | | verified | |
| LOCATION_ORIG_SYSTEM_REFERENCE | | derived | `<cust ref>-MAIN` | | verified | section 3 |
| INSERT_UPDATE_FLAG | | derived | G7 | | verified | |
| COUNTRY | blocking (GLR address appendix layer 1) | `CCode`, then `COUNTRY` | rule L1 below | ISO-2, `VARCHAR2(2)` | verified for GB | GPB loaded GB. |
| ADDRESS1 | per country (GB requires street) | `RM00102.ADDRESS1` | RTRIM; strip CR/LF | text, max 240 | verified | GPB. Blank on 1,209 PHTRA, 113 PHEN2, 2 PHBOO customers (RM00101 counts, SRC 5 fact 4). |
| ADDRESS2, ADDRESS3 | | `RM00102.ADDRESS2`, `ADDRESS3` | RTRIM; strip CR/LF | max 240 | documented | Template columns; GPB values not captured. |
| CITY | GB requires city (GLR layer 2) | `RM00102.CITY` | rule L2 below | GB geography level TOWNSHIP | verified | GPB loaded e.g. `London`. Blank on 2,342 PHTRA, 311 PHEN2, 9 PHBOO customers. |
| STATE | US only | `RM00102.STATE` | rule L3 below | US: valid state | verified (null for GB) | GPB loaded STATE null. |
| COUNTY | | `RM00102.STATE` | rule L3 below | GB geography level COUNTY | proposed | GPB loaded COUNTY null; DEV2 has never populated COUNTY. |
| POSTAL_CODE | GB requires postcode (GLR layer 2) | `RM00102.ZIP` | rule L4 below | GB geography includes POSTAL_CODE | verified | GPB loaded e.g. `WC2B 5LR`. Blank on 1,661 PHTRA, 211 PHEN2, 2 PHBOO. |
| ADDRESS_EFFECTIVE_DATE | | `RM00102.CREATDDT` | G3, G4; or blank | | proposed | AXS wrote the address valid-from date here. |
| HOUSE_TYPE, TIMEZONE_CODE, DO_NOT_VALIDATE_FLAG, VALIDATED_FLAG | | none | blank | | verified | G9; AXS left DO_NOT_VALIDATE_FLAG blank. |

**L1 country.** Use `CCode` when it is a two-letter code; it is ISO-2 in practice and populated
wherever `COUNTRY` is (SRC 5, fact 6). When `CCode` is blank and `COUNTRY` is not, map the
upper-cased `COUNTRY` text through the 43-name list PHF built (for example `UNITED KINGDOM` to
GB, `ISLE OF MAN` to IM, `UNITED ARAB EMIRATES` to AE); treat any name off that list as
unresolved. When the two disagree (PHTRA has 7 `FR` codes without `FRANCE` text), hold the row
for review rather than pick one. Status: **proposed** (the CCode-first order); the list is
**documented** by PHF, not loaded.

**L1 blank country is a decision, not a rule.** 508 PHTRA and 115 PHEN2 customers have no
country text (RM00101); PHF counted 608 RM00102 rows with none. Defaulting them to GB is
plausible for a UK business but would load foreign customers as British. Options: default GB,
default GB only when the postcode matches a GB pattern, or hold with reason
`HOLD_NO_COUNTRY`. See D5.

**L2 city.** Put the town in CITY, because DEV2 maps GB CITY to geography level TOWNSHIP. One
GP row already in DEV2 has the county "Essex" as its city (TGT trap 9), so check that a CITY
value is not a county name. A blank city is a decision (D6): hold, or load and accept the
geography warning. Whether DEV2 rejects a GB location with no city is **not verified** (the GB
validation level was not found; TGT 3.3). Status: **verified** for the placement,
**proposed** for the blank handling.

**L3 STATE and COUNTY.** GP `STATE` is free-text county (360 distinct values in PHTRA) and
sometimes holds rubbish such as VAT numbers or a US zip (PHF finding). For GB, leave STATE
empty (**verified**, GPB). For COUNTY there are two choices: leave it null as the GP batches
did (**verified**), or move GP STATE into COUNTY as PHF did (**proposed**). Free-text county
names may not match the DEV2 GB COUNTY geography, so the null choice is the safer default.
For a US address, GP STATE goes to STATE and must be a valid state, because DEV2 US validation
is Error at State level (**documented**, CFG-C26). For other countries, leave STATE, PROVINCE
and COUNTY empty unless a country-specific rule is agreed (**proposed**).

**L4 postal code.** RTRIM and upper-case. Do not reformat a GB postcode beyond that.
Validate it against a GB pattern only to flag (GLR layer 3); a failed pattern goes to the
review list, not into a rewrite. Status: **proposed** (upper-case and flag);
**verified** that GPB loaded a GB postcode as written.

---

## 6. HZ_IMP_PARTYSITES_T

One row per customer. Load order 3.

| Fusion column | Req | GP source | Rule | DEV2 values | Status | Notes and evidence |
|---|---|---|---|---|---|---|
| BATCH_ID | Y | literal | G5 | | verified | |
| PARTY_ORIG_SYSTEM / _REFERENCE | | derived | `GP` / `<cust ref>` | | verified | parent party |
| SITE_ORIG_SYSTEM / _REFERENCE | | derived | `GP` / `<cust ref>-MAIN` | | verified | section 3 |
| LOCATION_ORIG_SYSTEM / _REFERENCE | | derived | `GP` / `<cust ref>-MAIN` | | verified | parent location |
| INSERT_UPDATE_FLAG | | derived | G7 | | verified | |
| IDENTIFYING_ADDRESS_FLAG | Y (TPL, GLR) | literal | `Y` | Y/N | proposed | Starred in the template. With one site per customer it must be `Y`; the GPB value was not captured. AXS used Y for the primary address. |
| PARTY_SITE_NAME | | none | blank | | proposed | AXS used the address description; GP has none beyond ADRSCODE. |
| PARTY_SITE_NUMBER | | none | blank | auto-numbered | verified | `HZ_GENERATE_PARTY_SITE_NUMBER` = AUTO_NUMBERING (TGT 3.3). |
| START_DATE_ACTIVE / END_DATE_ACTIVE | | `RM00102.CREATDDT` or none | see D9 | | proposed | Child dates must sit inside this range (TGT trap 13). |

---

## 7. HZ_IMP_PARTYSITEUSES_T

One row per customer. Load order 4. The GP batches had rows in this table (TGT 2.2), but their
column values were not captured.

| Fusion column | Req | GP source | Rule | DEV2 values | Status | Notes and evidence |
|---|---|---|---|---|---|---|
| BATCH_ID | Y | literal | G5 | | verified | |
| PARTY_ORIG_SYSTEM / _REFERENCE | | derived | `GP` / `<cust ref>` | | verified | |
| SITE_ORIG_SYSTEM / _REFERENCE | | derived | `GP` / `<cust ref>-MAIN` | | verified | parent party site |
| SITE_USE_TYPE | Y (TPL, GLR) | literal | `BILL_TO` | lookup PARTY_SITE_USE_CODE (20 values) | proposed | AXS used BILL_TO and SHIP_TO here; GPB rows exist, value not captured. |
| PRIMARY_FLAG | | literal | `Y` | Y/N | proposed | Exactly one primary per purpose (GLR invariant). |
| SITEUSE_ORIG_SYSTEM / _REF | | derived | `GP` / `<cust ref>-MAIN-BILL_TO` | | proposed | section 3 |
| INSERT_UPDATE_FLAG | | derived | G7 | | verified | |
| START_DATE / END_DATE | | same as party site | see D9 | | proposed | `HZ_DE_INVALID_DATERANGE` hit this table 20 times in an EXACT batch. |

---

## 8. HZ_IMP_ACCOUNTS_T

One row per customer. Load order 5.

| Fusion column | Req | GP source | Rule | DEV2 values | Status | Notes and evidence |
|---|---|---|---|---|---|---|
| BATCH_ID | Y | literal | G5 | | verified | |
| CUST_ORIG_SYSTEM / _REFERENCE | | derived | `GP` / `<COMPANY>-<CUSTNMBR>` | | verified | |
| PARTY_ORIG_SYSTEM / _REFERENCE | | derived | `GP` / same value | | verified | `HZ_IMP_INVAL_PARENT_ENTITY_REF` if it doesn't resolve (TGT trap 15). |
| ACCOUNT_NUMBER | | derived | `<COMPANY>-<CUSTNMBR>` | `VARCHAR2(30)` | verified | section 3 |
| INSERT_UPDATE_FLAG | | derived | G7 | | verified | |
| CUSTOMER_TYPE | | literal or derived | `R`; `I` for group companies if D7 says so | R external, I internal | verified for R | AXS mapped intercompany to I. Candidates in GP: D05190 (PHTRA), D00519, D00116 (PHEN2), D06015 (PHTRA) (SRC 5, fact 10). |
| CUSTOMER_CLASS_CODE | | literal | `B2B` | class lookup | verified | GPB. GP CUSTCLAS holds currency (GBP/EUR/USD), not a business class, so it does not feed this column. A code missing from the lookup loads silently empty (TGT trap 8). |
| ACCOUNT_NAME | | `RM00101.CUSTNAME` | RTRIM; max 240 | | verified | AXS and GOLD carried the party name; GPB accounts carry names. |
| ACCOUNT_ESTABLISHED_DATE | | `RM00101.CREATDDT` | G3, G4 | date | proposed | Present in the GPB column set; value not captured. AXS used the AX created date. Do not use FRSTINDT (always 1900-01-01). |
| ACCOUNT_TERMINATION_DATE | | none | blank | date | proposed | A possible home for GP INACTIVE (section 13.6); the import effect was not tested. |
| STATUS | | n/a | not on the template sheet | | documented | The account sheet has no status column (TPL). |

---

## 9. HZ_IMP_ACCTSITES_T

One row per customer. Load order 6.

| Fusion column | Req | GP source | Rule | DEV2 values | Status | Notes and evidence |
|---|---|---|---|---|---|---|
| BATCH_ID | Y | literal | G5 | | verified | |
| CUST_ORIG_SYSTEM / _REFERENCE | | derived | `GP` / `<cust ref>` | | verified | parent account |
| ACCOUNT_NUMBER | | derived | `<cust ref>` | | verified | The macro moves this column (TPL; format builder). |
| CUST_SITE_ORIG_SYSTEM / CUST_SITE_ORIG_SYS_REF | | derived | `GP` / `<cust ref>-MAIN` | | verified | section 3 |
| SITE_ORIG_SYSTEM / _REFERENCE | | derived | `GP` / `<cust ref>-MAIN` | | verified | parent party site |
| INSERT_UPDATE_FLAG | | derived | G7 | | verified | |
| Account Address Set (SET_CODE) | Y (TPL, GLR) | literal | `ENTERPRISE` | upper-case set code | verified | GPB. The template column is labelled *Account Address Set*; the column list resolves it as SET_ID, but it loads the set **code**. A numeric id or `Enterprise` failed `HZ_IMP_INVAL_VALUE_COMPARE` (F1, CFG-C30). `RGE_UK_PH_GBP_BU` maps to ENTERPRISE for group `HZ_CUSTOMER_ACCOUNT_SITE`. |
| START_DATE / END_DATE | | see D9 | | | proposed | AXS used the address valid-from date. |
| CUSTOMER_CATEGORY_CODE, KEY_ACCOUNT_FLAG, TRANSLATED_CUSTOMER_NAME | | none | blank | | documented | No GP source. |

---

## 10. HZ_IMP_ACCTSITEUSES_T

One BILL_TO row per customer. Load order 7.

| Fusion column | Req | GP source | Rule | DEV2 values | Status | Notes and evidence |
|---|---|---|---|---|---|---|
| BATCH_ID | Y | literal | G5 | | verified | |
| ACCOUNT_NUMBER | | derived | `<cust ref>` | | verified | moved by the macro |
| CUST_SITE_ORIG_SYSTEM / CUST_SITE_ORIG_SYS_REF | | derived | `GP` / `<cust ref>-MAIN` | | verified | parent account site |
| CUST_SITEUSE_ORIG_SYSTEM / _REF | | derived | `GP` / `<cust ref>-MAIN-BILL_TO` | | verified | section 3 |
| SITE_USE_CODE | Y (TPL, GLR) | literal | `BILL_TO` | lookup SITE_USE_CODE (18 values) | verified | GPB. All four GP address pointers are equal for 8,483 of 8,484 PHTRA customers and all PHEN2/PHBOO (SRC 3.1), so one BILL_TO covers bill-to, ship-to and statement-to. |
| PRIMARY_FLAG | | literal | `Y` | | verified | GPB. Check 4 of `fusion_post_load_checks.sql` expects exactly one primary active BILL_TO. |
| Account Address Purpose Set (SET_CODE) | Y (TPL, GLR) | literal | `ENTERPRISE` | | verified | same rule as section 9 |
| LOCATION | | none | blank | unique per site use | proposed | GPB site uses carry numeric names (11006…); whether the batch supplied them or Fusion assigned them is not recorded. AXS supplied no LOCATION and its batches completed. |
| BILL_TO_CUST_SITE_REF | | none | blank | | documented | Needed only for a SHIP_TO row (TGT 2.3). |
| PAYMENT_TERM_ID, TAX_CLASSIFICATION | | none | blank | | verified | Never used in DEV2; terms come from the profile (TGT 3.1). |
| START_DATE / END_DATE | | same as account site | see D9 | | proposed | must sit inside the site range |
| INSERT_UPDATE_FLAG | | derived | G7 | | verified | |

No SHIP_TO or STMTS rows: the GP batches loaded BILL_TO only and GP never separates them (D10).

---

## 11. RA_CUSTOMER_PROFILES_INT_ALL

One account-level row per customer (no site reference), always `I`, always in the same batch
as its account row. Load order 8. Preview does not validate this table (TGT trap 4).

| Fusion column | Req | GP source | Rule | DEV2 values | Status | Notes and evidence |
|---|---|---|---|---|---|---|
| BATCH_ID | Y | literal | G5 | | verified | |
| INSERT_UPDATE_FLAG | Y (TPL, GLR) | literal | `I` | | verified | MAP-C18 |
| PARTY_ORIG_SYSTEM / _REFERENCE | | derived | `GP` / `<cust ref>` | | documented | GOLD and PHF fill them; GPB value not captured. |
| CUST_ORIG_SYSTEM / _REFERENCE | Y (TPL, GLR) | derived | `GP` / `<cust ref>` | | verified | `AR_CUSTIMP_PF_BAD_CUST_REF` if unmatched |
| CUST_SITE_ORIG_SYSTEM / CUST_SITE_ORIG_SYS_REF | | none | blank (account level) | | verified | |
| ACCOUNT_NUMBER | | derived | `<cust ref>` | | verified | GPB column set |
| CUSTOMER_PROFILE_CLASS_NAME | | literal | `DEFAULT` | DEFAULT, RGE Good Credit, RGE Bad Credit | verified | GPB. GP CUSTCLAS does not map to a profile class (section 13.2). |
| COLLECTOR_NAME | import-required | literal | `AR Manager` | AR Manager, Default Collector | verified | GPB; F3 |
| CREDIT_BALANCE_STATEMENTS | import-required | literal | `Y` | Y/N | documented | AXS default (F3, CFG-C33). The GPB value was not captured. |
| TOLERANCE | import-required | literal | `0` | number | documented | same |
| OVERRIDE_TERMS | import-required | literal | `Y` | Y/N | documented | same |
| AUTO_REC_INCL_DISPUTED_FLAG | import-required | literal | `N` | Y/N | documented | same |
| CREDIT_CHECKING | | literal | `N` | Y/N | verified | GPB. Revisit if credit limits convert (D8). |
| CREDIT_HOLD | Y (TPL, GLR) | `RM00101.HOLD` | 1 to `Y`, else `N` | Y/N | verified (N) | GPB loaded N. HOLD = 1 on 2 PHTRA and 1 PHEN2 customers, all inactive (SRC 3.1). The HOLD-to-Y mapping is **documented** by AXS (blocked to Y). |
| STATEMENTS | | `RM00101.STMTCYCL` | 5 to `Y` | Y/N | verified | GPB. STMTCYCL = 5 for every customer. |
| STATEMENT_CYCLE_NAME | | `RM00101.STMTCYCL` | 5 to `Monthly` | Monthly, ORA_Quarterly, ORA_Weekly | verified | GPB. Any other code is a stop: none exists today. |
| DUNNING_LETTERS | | literal | `N` | Y/N | verified | GPB |
| DISCOUNT_TERMS, INTEREST_CHARGES | | literal | `N` | Y/N | documented | AXS and GOLD set N; GPB value not captured. |
| STANDARD_TERM_NAME | | `RM00101.PYMTRMID` | crosswalk 13.1 | RA_TERMS_TL names, max 15 | verified for Net 30 | GPB loaded `Net 30`. |
| CURRENCY_CODE | | `RM00101.CURNCYID` | blank to `GBP`; only when a credit limit is sent | ISO currency | proposed | GPB sent no currency. See 13.4. |
| OVERALL_CREDIT_LIMIT | | `CRLMTTYP`, `CRLMTAMT` | crosswalk 13.4 | number | proposed | No stream has converted credit limits; HZ_CUST_PROFILE_AMTS_F holds no limits today. |
| TRX_CREDIT_LIMIT | | none | blank | | proposed | GP has no per-transaction limit. |
| ACCOUNT_STATUS | | none | blank | lookup ACCOUNT_STATUS (user-defined) | proposed | The template defines it as a user-defined collections status, not active/inactive. PHF wrote ACTIVE/INACTIVE here; those values are not verified in the lookup. |
| ORG_ID | Y (TPL, GLR) | literal | `300000004842930` | RGE_UK_PH_GBP_BU | verified | GPB, for both PHTRA and PHEN2 references. The BU decision itself is still open (CFG-C22). PHBOO has not been loaded. PHF's `210` is a Legal Entity Map value, not a DEV2 BU id. |
| TXN_DELIVERY_METHOD / STMT_DELIVERY_METHOD | | `Send_Email_Statements` and contacts | `EMAIL` only with a billing contact, else blank | AR_INV_DELIVERY_METHOD | proposed | AXS used EMAIL/PRINT and required an external billing contact. Only 76 PHTRA and 1 PHBOO customers set the GP flag. |
| All other profile columns (credit analyst, review cycle, grace days, late charges, AutoCash, balance forward) | | none | blank | | documented | No GP source. Blank lets the profile class default apply. |

---

## 12. Contacts and contact points

The GP batches did load some contact objects: DEV2 holds GP references for 5 relationships,
5 account roles, 6 contact points and 7 role responsibilities (TGT 3.2). Their column values
were not captured, so there is no verified GP contact pattern.

What GP offers:

| GP source | Holds | Counts (PHTRA / PHEN2 / PHBOO) | Fusion target | Status |
|---|---|---|---|---|
| `RM00101.CNTCPRSN`, `RM00102.CNTCPRSN` | One free-text contact name per customer or address | 3,032 / 374 / 1 filled | Person party (HZ_IMP_PARTIES_T, PERSON), HZ_IMP_CONTACTS_T, HZ_IMP_RELSHIPS_T (CONTACT_OF), HZ_IMP_ACCTCONTACTS_T | proposed |
| `SY01200` (`Master_Type = 'CUS'`, per ADRSCODE) | INET1 or EmailTo/Cc/Bcc text | customers with email 99 / **0** / 1 | HZ_IMP_CONTACTPTS_T, type EMAIL | proposed |
| `RM00106` | Statement email recipients, Email_Type 1/2/3 (meaning unverified) | 99 / 10 / 1 customers | contact point plus HZ_IMP_ROLERESP `STMTS` | proposed |
| `PHONE1-3`, `FAX` | Phone numbers, sometimes text | PHONE1 blank 96% / 86% / 100% | HZ_IMP_CONTACTPTS_T, type PHONE | proposed |

If contacts convert, follow the AX stream's decided pattern (CFG-C20): one billing contact per
external email, a person party, a CONTACT_OF relationship, an account contact and
responsibilities BILL_TO and STMTS. Split multi-address email text and quarantine anything
malformed (MAP-C15/C23). Populate the person party keys on contact points alongside the
relationship keys, or they fail `HZ_IMP_MISSING_PARENT` (MAP-C17). Keep one primary contact
per organization (`HZ_API_UNIQUE_PRIMARY_ORG_CONT`). Splitting CNTCPRSN into first and last
name is a guess on free text, so it is a decision (D11). PHF's phone values were masked
synthetic numbers; never load a masked fill.

---

## 13. Value crosswalks

### 13.1 Payment terms (PYMTRMID to STANDARD_TERM_NAME)

GP `Dnnn` means net nnn days (DUETYPE 1). The first research pass listed 25 codes and the
verification pass counted 22 distinct terms; the difference is unexplained (SRC 1.3). Only four
values occur on customers.

| GP term | Customers (PHTRA / PHEN2 / PHBOO) | DEV2 term | Status |
|---|---|---|---|
| D030 | 8,255 / 1,161 / 2 | `Net 30` | verified (GPB loaded Net 30) |
| D010 | 15 / 0 / 16 | none: DEV2 has no Net 10 | no target (decision D4) |
| D005 | 0 / 1 / 0 | none: no Net 5 | no target (D4) |
| blank | 214 / 5 / 0 | `Net 30` | proposed: the GBP class default is D030 (SRC 3.6) |
| D000 | not on customers | `Net 0` or `IMMEDIATE` | proposed, unused |
| D001, D014, D015, D045, D060 | not on customers | `Net 1`, `Net 14`, `Net 15`, `Net 45`, `Net 60` | proposed, unused |
| D007, D019, D020, D021, D025, D028, D070, D090, D110, D115, D117, D120, D121, D122, D128, EOM | not on customers | none | no target, unused |

DEV2 terms: IMMEDIATE, Net 0, Net 1, Net 14, Net 15, Net 30, Net 45, Net 60, ORA_HES; `30` is
end-dated (TGT 3.3). For D010/D005 the choices are a new DEV2 term, mapping to the nearest
existing term, or holding the customer. That is setup or a decision, not a mapping rule.

### 13.2 Customer class (CUSTCLAS)

| GP CUSTCLAS | Customers (PHTRA / PHEN2) | Fusion | Status |
|---|---|---|---|
| GBP, EUR, USD, blank | 8,244 / 1,081 GBP; 10 / 63 EUR; 7 / 18 USD; 223 / 5 blank | CUSTOMER_CLASS_CODE `B2B` for all; PROFILE_CLASS `DEFAULT` for all | verified (GPB) |

CUSTCLAS is a currency grouping, so it carries no class meaning. The currency it implies is
already on CURNCYID.

### 13.3 Currency (CURNCYID)

Blank means "functional currency", and the functional currency is GBP in PHTRA and PHEN2
(`MC40000.FUNLCURR`, SRC 4). Blank (224 PHTRA, 5 PHEN2) becomes `GBP` through an explicit,
recorded defaulting rule. Status: **verified** for the GBP fact, **proposed** for writing it.
The Fusion profile only needs a currency on the amount row, so send it only with a credit limit.

### 13.4 Credit limit (CRLMTTYP, CRLMTAMT)

The numeric meaning of CRLMTTYP is inferred from class data, not printed by Microsoft (SRC 4).

| CRLMTTYP | Meaning | PHTRA | PHEN2 | PHBOO | Proposed Fusion value |
|---|---|---|---|---|---|
| 0 | No credit | 224 | 5 | 0 | no limit sent; the "no credit" intent needs a decision (D8) |
| 1 | Unlimited | 17 | 81 | 0 | no limit sent |
| 2 | Amount in CRLMTAMT | 8,243 | 1,081 | 18 | OVERALL_CREDIT_LIMIT = CRLMTAMT, CURRENCY_CODE = CURNCYID (blank to GBP) |

Status: **proposed** for every row. The GP batches sent no limit (**verified**), and US-08
decided "no credit limits" for the US (CFG-C23). Whether PH credit limits convert at all is D8.
Type 2 amounts: PHTRA 8,242 at or under 10,000 and 1 above; PHEN2 all at or under 10,000.

### 13.5 Hold (HOLD)

1 to CREDIT_HOLD `Y`, 0 to `N`. Status: **documented** (AXS mapped blocked to Y; CREDIT_HOLD
is required on the profile per GLR). Every HOLD customer is also INACTIVE, so under most
selection rules no held customer converts.

### 13.6 Inactive (INACTIVE)

GP INACTIVE is permanent and allowed only with no open invoices (SRC 4). PHTRA 10, PHEN2 3,
PHBOO 0. The template has no account or site status column. **Proposed:** exclude inactive
customers with reason `EXCL_INACTIVE`, which option C does by definition. The alternative,
loading them with ACCOUNT_TERMINATION_DATE or a site END_DATE, is untested on DEV2.

### 13.7 Statement cycle, balance type, comments, tax

| GP | Values | Fusion | Status |
|---|---|---|---|
| STMTCYCL | 5 (Monthly) on every customer | STATEMENT_CYCLE_NAME `Monthly`, STATEMENTS `Y` | verified |
| BALNCTYP | 0 (open item) on every customer | no column; Fusion's default open-item handling applies, leave balance-forward columns blank | proposed |
| COMMENT1 / COMMENT2 | filled 4,121 / 506 / 16 | dropped, or a descriptive flexfield if Regal configures one | proposed (decision D12); DFFs are unused in DEV2 |
| USERDEF1 / USERDEF2 | empty everywhere | dropped | verified empty (SRC 3.1) |
| TAXSCHID | VOS, VOI, ROWO, VOZ and others | HZ_IMP_ACCTSITEUSES_T.TAX_CLASSIFICATION, left blank | proposed; the VOS-to-Fusion tax classification mapping is **unverified**. No DEV2 site use carries a tax classification, and the UK tax setup was not researched. |

---

## 14. No source in GP

Columns the load needs or wants that GP cannot supply. Each needs a conversion default or a
decision.

| Fusion column | Default used | Status |
|---|---|---|
| CUSTOMER_CLASS_CODE | `B2B` | verified |
| CUSTOMER_PROFILE_CLASS_NAME | `DEFAULT` | verified |
| COLLECTOR_NAME | `AR Manager` | verified |
| CREDIT_BALANCE_STATEMENTS | `Y` | documented |
| TOLERANCE | `0` | documented |
| OVERRIDE_TERMS | `Y` | documented |
| AUTO_REC_INCL_DISPUTED_FLAG | `N` | documented |
| CREDIT_CHECKING, DUNNING_LETTERS; DISCOUNT_TERMS, INTEREST_CHARGES | all `N` | verified; documented |
| ORG_ID | `300000004842930` | verified; decision open (CFG-C22) |
| Account Address Set / Purpose Set | `ENTERPRISE` | verified |
| IDENTIFYING_ADDRESS_FLAG, PRIMARY_FLAG | `Y` | proposed / verified |
| Person first and last name (if PERSON parties or contacts) | none; free-text split | decision D3, D11 |
| Party tax profile / VAT registration | no sheet in the Customer Import handles it | gap; not researched |
| Country for 500+ customers | GB or hold | decision D5 |

---

## 15. No target in Fusion

GP data with nowhere to go in this load. Each is dropped unless a decision says otherwise.

| GP column | Why there is no target | Status |
|---|---|---|
| SHRTNAME, STMTNAME | No short-name or statement-name column on the sheets used (STMTNAME differs from CUSTNAME on 21 PHTRA, 22 PHEN2). | proposed |
| SHIPMTHD (`SALES`), SLPRSNID, SALSTERR | A placeholder and two blank fields; DEV2 has no carriers and no salespeople. | verified (TGT 3.4) |
| PRCLEVEL (`STD`) | No price-list column in the Customer Import. | proposed |
| RMARACC | GL index only; the import sheets carry no receivables account. | proposed |
| CPRCSTNM, RM00105 | Never set; no hierarchy. HZ_IMP_ACCOUNTRELS is out of scope. | verified empty |
| FRSTINDT | Always 1900-01-01. | verified |
| BALNCTYP, KP*HST flags | No equivalent column; not researched. | proposed |
| COMMENT1/2 | No DFF configured (D12). | proposed |
| CRCRDNUM, SY06000 bank rows | Never extracted (card data; 3 inactive EFT rows). | documented |
| SY03900 notes | Real note on 3 PHTRA customers only. | proposed |
| D010, D005 and 16 other GP terms | No matching DEV2 term (13.1). | no target |
| Address IDs other than the primary | Collapsed to one site (SRC 5, fact 7). | proposed |

---

## 16. Decisions waiting on Jonathan

**These D-numbers are mapping-local.** The authoritative decisions register is `lessons-and-decisions.md` section 4, which uses its own numbering (its D1 to D21 do not match these).

| Id | Question | Options | Default in this file |
|---|---|---|---|
| D1 | Selection rule | A open balance (322), B open or active since 2024 (2,375), C all active (9,656) | none (SRC 6) |
| D2 | BU per company | RGE_UK_PH_GBP_BU for all three, or split | RGE_UK_PH_GBP_BU (as loaded) |
| D3 | Individuals as PERSON parties | keep ORGANIZATION, or PERSON with a name split | ORGANIZATION |
| D4 | D010 / D005 terms | add DEV2 terms, nearest term, or hold | hold |
| D5 | Blank country | GB, GB if postcode looks GB, or hold | hold `HOLD_NO_COUNTRY` |
| D6 | Blank city or address line 1 | hold, or load with warning | hold |
| D7 | Group companies as internal (`I`) | I or R | R |
| D8 | Credit limits and the "no credit" type | convert as 13.4, or none | none (as loaded) |
| D9 | Site and site-use dates | blank everywhere, or RM00102.CREATDDT on both | blank everywhere |
| D10 | SHIP_TO / STMTS site uses | BILL_TO only, or add | BILL_TO only |
| D11 | Contacts | none, emails only, or full billing contacts | none |
| D12 | COMMENT1/2 | drop, or DFF | drop |
| D13 | The 19 PHTRA customers with no address row | hold `HOLD_NO_ADDRESS`, or load RM00101's copy | hold |
| D14 | Name duplicates across companies (239 pairs) | one party per GP customer, or merge | one party per customer (as AX CFG-C18) |

---

## 17. Sources

- `gp-source-model.md` and `fusion-target-model.md` (this skill).
- `scripts/gp_customer_extract.sql`, `scripts/fusion_post_load_checks.sql` (this skill).
- In `/Users/jonathanstevenson/Source/AIX-GreenLight/docs/design/conversion-redesign/us_customer_conversion_design_v20260918_1/06_pipeline/`:
  `mapping/_evidence/template_columns_CustomerImportTemplate.csv`, `sql/14_stage_ax_customer_fbdi.sql`, `ingest/fbdi_customer_load_format.py`.
- Playbook: `/Users/jonathanstevenson/Source/AIX-GreenLight/docs/playbooks/ax-to-fusion-fbdi-conversion-playbook.md`.
- Greenlight ATP extracts (research scratch, 2026-10-16): *Oracle Customer Conversion Rules*,
  *Oracle Load Error Prediction* (address appendix), golden US customer SQL and summary, the
  PH conversation of 2026-10-16 12:29 to 13:08 (PHF), the UK AX DEV2 load conversation of
  2026-10-10 to 2026-10-15.
- Not available: Greenlight's saved customer mapping configs (file empty after one retry), the
  job arguments of real CDM runs (file empty), and the build files of the three GP batches.
