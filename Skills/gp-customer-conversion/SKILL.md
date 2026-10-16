---
name: gp-customer-conversion
description: 'Convert Microsoft Dynamics GP (Great Plains) customers into Oracle Fusion Receivables customers (party, account, site, site use, profile) through the Customer Import FBDI, for the Regal / Cineworld Picturehouse UK companies (GP databases PHTRA, PHEN2, PHBOO, PHGAP on the Regal SQL Server MCP) landing in Regal Fusion, ichqjb-dev2 first. Use it whenever anyone mentions GP, Great Plains or Picturehouse customers, RM00101 / RM00102 / RM00201 / SY01200, the UK-PH customer stream, Customer Import or CustomerImportTemplate, HZ_IMP_PARTIES_T / HZ_IMP_ACCOUNTS_T / RA_CUSTOMER_PROFILES_INT_ALL, CDMAutoBulkImportJob, GP customer profiling or data quality, the customer FBDI zip, or asks how a GP customer becomes a Fusion customer, even phrased as pull the customers from Great Plains, which customers do we convert, map the customer fields, why did the customer load fail, or load the UK customers into DEV2. GP side only: AX customers belong to ax-erp-source; the general GP schema belongs to great-plains-erp-source.'
---

# GP customer conversion (Picturehouse → Oracle Fusion)

You are the Dynamics GP customer-data architect for the Regal Fusion programme. The person
asking knows what a customer, a bill-to address or a credit limit *is*; they need you to know
which of GP's tables holds it, what the Picturehouse data actually looks like, what Fusion's
Customer Import expects, and what has already gone right and wrong on this project. Every
statement in this skill was either observed on the live systems on 2026-10-16, taken from
Oracle or Microsoft documentation, or lifted from this project's own conversion history —
and each reference file says which. Where nothing was verified, the skill says **unverified**;
carry that word forward rather than dropping it.

## Contents

1. Ground rules
2. Correct the premise
3. Sessions and sites
4. What is where: the concept router
5. The model translation
6. Population and selection
7. Verified recipes
8. Mapping
9. Cleansing rules and reason codes
10. Loading into Fusion
11. Verification and reconciliation
12. Decisions, open questions, history
13. Answering style
14. Files in this skill and sources

---

## 1. Ground rules

1. **Never guess; run it.** The PH databases are reachable read-only, so a count is one query
   away. Say "unverified" when you cannot run the check, never "probably".
2. **Name the company and the as-of date in every number.** PHTRA and PHEN2 share customer
   numbers and nothing else; an unlabelled count is wrong half the time.
3. **Read-only on GP, no load on Fusion without Jonathan's word.** Profiling and preview
   batches are reads of a kind; a commit batch (`CDMAutoBulkImportJob` argument 14 = N) changes
   a live environment and happens only when Jonathan says so, on the pod he names.
4. **Confirm the target before connecting.** A site in the MCP roster is an inventory, not
   permission. Check the Fusion host is `ichqjb-dev2` (a UK load once went to the wrong tenant).
5. **No PII, no secrets in outputs.** Business names and customer numbers are fine; e-mail
   addresses, phone numbers, bank details and any credential never appear in a reply, a report
   or a file. The extract script returns presence flags for e-mail and phone for this reason.
6. **GP char columns are space-padded.** `RTRIM()` everything that leaves GP; DEV2 already holds
   one untrimmed name from an earlier batch.
7. **Verify state in the registry tables, not in the job log.** A batch once reported six
   profiles imported while `HZ_CUSTOMER_PROFILES_F` held none.

## 2. Correct the premise

- **PH is Picturehouse (UK), not Poland.** Cinema City Poland is a different SQL Server
  database set with its own MCP sites. The four PH databases are the Picturehouse companies:

  | DB | Company (SY01500.CMPNYNAM) | Customers | Role |
  |---|---|---|---|
  | PHTRA | Picturehouse Cinemas Limited | 8,484 | the trading company; nearly all customers |
  | PHEN2 | Picturehouse Entertainment Ltd (New) | 1,167 | distribution arm; EUR activity |
  | PHBOO | Picture House Bookings | 18 | no open AR, no activity |
  | PHGAP | PICTUREHOUSE US GAAP | 0 | reporting company; nothing to convert |

- **The source is GP 2010** (version 11.0.1752) on SQL Server 2022 at compatibility level 100:
  `STRING_AGG`, `TRIM()` and other modern T-SQL fail; use `FOR XML PATH` and `LTRIM(RTRIM())`.
- **The customer class column is `CUSTCLAS`, not `CLASSID`.** Three classes exist (GBP, EUR,
  USD) and they drive currency, not segmentation.
- **The "address set" in the May 2026 Excel extract is not the company database.** 1,147
  customers sat under a "Bookings" set although PHBOO has 18 customers. Treat the extract as a
  delivered file, not as the source; the source is the four databases.
- **GP customers have been loaded to DEV2 before.** Three batches (`GP_PH_PROVING_5`,
  `GP_PH_EXPAND20_PREVIEW`, `GP_PH_EXPAND20_COMMIT`) created 25 accounts with no errors. The
  pattern they used is the one to follow (section 8). A note in older transcripts claiming no GP
  customer ever reached Fusion is superseded by the observed DEV2 state.

## 3. Sessions and sites

| Need | Tool | Site / target | Notes |
|---|---|---|---|
| GP system tables (company master SY01500) | Regal SQL Server MCP `execute_sql` | `Great-Plains` (DB DYNAMICS) | login HKT-PH, read-only confirmed by the server |
| PHTRA customers | same | `PHTRA-Great-Plains` | 8,484 customers, 1,298,917.25 GBP net open AR across 156 customers |
| PHEN2 customers | same | `PHEN2-Great-Plains` | 1,167 customers, 598,322.80 GBP net open AR across 166 customers, 41 open EUR documents |
| PHBOO / PHGAP | same | `PHBOO-Great-Plains`, `PHGAP-Great-Plains` | 18 and 0 customers |
| Fusion target state and post-load checks | Fusion SQL MCP (`connect` then `execute_sql`) | `https://ichqjb-dev2.fa.ocs.oraclecloud.com` | runner `/Custom/Hackett/HK_SQL_RUNNER.xdo`; the connection expires after 30 minutes — reconnect, don't retry |
| Project history, DQ findings, saved mappings | Greenlight (REGALCHATTAPP ATP) | tables CONVERSATIONS / MESSAGES / DQ_FINDINGS / GOLDEN_CONVERSIONS / MAPPING_CONFIGS / LOAD_BATCHES | read-only; the lessons file already distils it |

Three related companies (PHENT, PHCON, PHNMM) exist in SY01500 but have no MCP site; they were
not profiled and are out of scope until someone adds a site.

## 4. What is where: the concept router

| Concept | GP table(s) | Key | Picturehouse reality (2026-10-16) |
|---|---|---|---|
| Customer master | `RM00101` | CUSTNMBR | 103 columns; CUSTCLAS, PYMTRMID, CURNCYID, CRLMTTYP/CRLMTAMT, HOLD, INACTIVE, STMTCYCL, BALNCTYP, PRBTADCD / PRSTADCD / STADDRCD address pointers |
| Addresses | `RM00102` | CUSTNMBR + ADRSCODE | effectively one address per customer: bill-to, ship-to and statement pointers all equal the primary for 8,483 of 8,484 PHTRA customers; 11 address-code typos (MIAN, MAI, M…) |
| Balance summary | `RM00103` | CUSTNMBR | useful for sanity, not for the open-AR figure |
| Open AR documents | `RM20101` | CUSTNMBR, RMDTYPAL, DOCNUMBR | `CURTRXAM` is the functional-currency remaining amount; `ORTRXAMT` the original; use it for the open-balance selection |
| History | `RM30101` | same | last-activity date = max DOCDATE across RM20101 ∪ RM30101 |
| Foreign-currency amounts | `MC020102` | document key | PHEN2 1,687 rows, PHTRA 179 — key and totals unverified |
| Statement e-mail recipients | `RM00106` | CUSTNMBR | e-mail addresses — count, never list |
| Internet addresses (e-mail per address) | `SY01200` | Master_Type 'CUS', Master_ID, ADRSCODE | PHTRA 99 customer rows, PHEN2 none; there is **no** `Email_Type` column |
| Customer class | `RM00201` | CLASSID | GBP / EUR / USD only |
| Payment terms | `SY03300` | PYMTRMID | 22 terms, identical in both companies; D-terms (DUETYPE 1, DUEDTDS = days), D110/D120 (DUETYPE 3), EOM (DUETYPE 5) |
| Tax schedules | `TX00101` / `TX00102` | TAXSCHID | mapping to Fusion tax classification is **unverified** |
| Functional currency | `MC40000` (in each company DB) | — | GBP in both live companies |
| National accounts, salespeople, territories, customer bank (EFT) | `RM00105`, `RM00301`, `RM00303`, `SY06000` | — | unused: salesperson and territory blank for every customer; 3 inactive bank rows; Extender holds no customer data |

Column-level detail, the GP semantics (date sentinel 1900-01-01, HOLD vs INACTIVE, credit-limit
type codes, DEX_ROW_ID) and the Microsoft / azurecurve citations are in
`references/gp-source-model.md`.

## 5. The model translation

GP stores a customer flat: one `RM00101` row plus one or more `RM00102` addresses. Fusion
splits that into a chain of objects linked by original-system references, and the conversion
*manufactures* every link:

```
RM00101 (customer)            → HZ_PARTIES (ORGANIZATION … or PERSON — open decision)
                              → HZ_CUST_ACCOUNTS (account number = <DB>-<CUSTNMBR>)
RM00102 (address)             → HZ_LOCATIONS → HZ_PARTY_SITES → HZ_CUST_ACCT_SITES_ALL (SET_CODE)
PRBTADCD / PRSTADCD / STADDRCD→ HZ_CUST_SITE_USES_ALL (BILL_TO primary; SHIP_TO points at its BILL_TO)
CUSTCLAS, PYMTRMID, CRLMT*,
HOLD, STMTCYCL                → HZ_CUSTOMER_PROFILES_F (+ credit limit; RA_CUSTOMER_PROFILES_INT_ALL on import)
CNTCPRSN, SY01200, RM00106    → contacts / contact points (only if the data supports it)
```

Two Fusion facts change how you think about it:

- **Account sites carry a reference-data set (`SET_CODE`), not a business unit.** The business
  unit (`ORG_ID`) is supplied on the profile row (`RA_CUSTOMER_PROFILES_INT_ALL.ORG_ID`); whether
  the site-use row also needs it was not checked. The GP batches used `SET_CODE = ENTERPRISE`
  and business unit `RGE_UK_PH_GBP_BU`.
- **Every import row carries its own source-system reference and its parent's.** The scheme in
  use is `<cust>` for party and account, `<cust>-MAIN` for the location / party site / account
  site, `<cust>-MAIN-BILL_TO` for the site use, where `<cust>` is `PHEN2-D00189` style. The
  company prefix is not optional: PHTRA and PHEN2 share 1,163 customer numbers with different
  names behind them.

The FK chain, the real interface table names (and the plausible-looking names that **do not
exist**, such as `HZ_IMP_CUSTOMER_PROFILES_T`), DEV2's reference data and the known traps are in
`references/fusion-target-model.md`.

## 6. Population and selection

About 39 % of Picturehouse customers have never had a transaction. Three selection rules were
counted live on 2026-10-16 (`scripts/gp_customer_profile.sql`, query 5):

| Option | Rule | PHTRA | PHEN2 | PHBOO |
|---|---|---|---|---|
| A | has a non-void open document in RM20101 | 156 | 166 | 0 |
| B | A, or any document dated 2024-01-01 or later | 1,965 | 410 | 0 |
| C | all customers not flagged INACTIVE | 8,474 | 1,164 | 18 |

**The selection rule is an open decision for Jonathan.** Present the three counts, recommend B
with the reasoning (A alone cannot support a re-issued invoice or a credit for a 2025 sale; C
loads 7,000 dormant records into a system that validates every address), and record whichever he
picks in `references/lessons-and-decisions.md`.

Whatever the rule, these groups need a named treatment before load: the 224 PHTRA customers with
no class, currency or terms (219 of them with activity); intercompany customers with open AR
(Picturehouse Entertainment, Picturehouse Cinemas Ltd, Regal, Cineworld); PHEN2's EUR customers;
duplicate-name groups (PHTRA 114 names / 248 customers; across both companies 344 names / 722
customers); and customers with no address at all (19 in PHTRA).

## 7. Verified recipes

Each ran on 2026-10-16 against the named site. Run them again rather than quoting them —
the numbers move.

| # | Question | Script / query | Site(s) |
|---|---|---|---|
| R1 | Customer counts, inactive, hold, class / terms / currency distributions, blank-field rates | `scripts/gp_customer_profile.sql` query 1 | each PH site |
| R2 | Value distributions (CUSTCLAS, PYMTRMID, CURNCYID, COUNTRY, STATE, CRLMTTYP, STMTCYCL) | query 2 | each PH site |
| R3 | Customer-number clash and same-name-different-number across PHTRA and PHEN2 | query 3 | `PHTRA-Great-Plains` (cross-DB) |
| R4 | Open AR by customer, top balances, customers with non-zero open balance | query 4 | PHTRA, PHEN2 |
| R5 | Selection-option counts A / B / C | query 5 | each PH site |
| R6 | Conversion-shaped extract: one row per customer × address with every GP column the mapping needs plus open balance, last activity, has_activity and company code | `scripts/gp_customer_extract.sql` | each PH site; the three selection rules are commented WHERE options |
| R7 | Fusion: free batch id, batch summary, import errors, accounts/sites/site uses/profiles created, primary BILL_TO check, missing profiles, orig-system references, location shape, untrimmed text, reconciliation by company prefix | `scripts/fusion_post_load_checks.sql` checks 0–9 | DEV2 via the Fusion SQL MCP |

The extract returns yes/no flags for e-mail and phone; the value columns are present but
commented out (`[VALUE]`) for the controlled load run only.

## 8. Mapping

`references/field-mapping.md` holds one table per interface object in load order
(HZ_IMP_PARTIES_T, HZ_IMP_LOCATIONS_T, HZ_IMP_PARTYSITES_T, HZ_IMP_PARTYSITEUSES_T,
HZ_IMP_ACCOUNTS_T, HZ_IMP_ACCTSITES_T, HZ_IMP_ACCTSITEUSES_T, RA_CUSTOMER_PROFILES_INT_ALL),
each row tagged **verified** (used by a successful DEV2 batch), **documented** (Oracle or
Greenlight rule) or **proposed** (needs Jonathan). The shape of the verified pattern:

| Fusion attribute | Value the GP batches used |
|---|---|
| Source system | `GP` (enabled for 19 TCA entities on DEV2) |
| Account number | `<DB>-<CUSTNMBR>` (auto-numbering is on, but a supplied number is kept) |
| Customer class | `B2B` (customer-class lookup; a code missing from the lookup loads silently as blank) |
| Profile class / collector / terms / statement cycle | `DEFAULT` / `AR Manager` / `Net 30` / `Monthly` — conversion defaults, not yet a Regal decision |
| Business unit / set | `RGE_UK_PH_GBP_BU` / `ENTERPRISE` |
| Credit limit | none loaded yet; GP has CRLMTTYP 2 (amount) on 8,243 PHTRA and 1,081 PHEN2 customers |

Where GP has no source (collector, tolerance, five required profile flags) the file names the
default and who owns the decision. Where Fusion has no target (COMMENT1/2, USERDEF1/2,
TXRGNNUM) it says so rather than inventing a flexfield.

## 9. Cleansing rules and reason codes

Apply in this order, record a reason code per excluded or altered row, and keep the counts —
they are the LOAD + HELD + REJECT = SOURCE reconciliation later. The runbook's step 2
(`references/load-runbook.md`) defines the hold / exclude codes a load must use
(`HOLD_NO_ADDRESS`, `HOLD_NO_COUNTRY`, `HOLD_COUNTRY_CONFLICT`, `HOLD_NO_CITY`,
`HOLD_US_NO_STATE`, `HOLD_TERM_NO_TARGET`, `EXCL_INACTIVE`); the codes below add the
review and derivation flags that do not stop a row.

| Rule | Reason code | Evidence |
|---|---|---|
| Trim every char column | — | DEV2 holds an untrimmed name from an earlier batch |
| 1900-01-01 → null on every date | — | GP's "no date" sentinel; FRSTINDT is 1900-01-01 for all customers |
| Customer with no RM00102 row → hold | `HOLD_NO_ADDRESS` | 19 in PHTRA; Fusion needs a location to create a site |
| Blank CUSTCLAS / CURNCYID / PYMTRMID → fill from functional currency (GBP) and the agreed default terms, flag | `FILL_CLASS_DEFAULT` | 224 PHTRA customers; GP's own default class is USD, which is wrong for them |
| Free-text COUNTRY → ISO-2 (GB when blank is a **decision**, not a rule) | `COUNTRY_DERIVED` | mixed-case free text; 508 PHTRA blanks |
| GB addresses: city → geography township, STATE left blank, GP STATE (free-text county) → COUNTY or dropped (**decision**) | `ADDR_GB_SHAPE` | DEV2 geography validation; 360 distinct county strings |
| Address-code typos (MIAN, MAI, …) → treat as the customer's address, flag | `ADRSCODE_TYPO` | 11 rows in PHTRA, including the only 4 two-address customers |
| Duplicate names → review list, do not merge before load | `DUP_NAME_REVIEW` | merging after AR transactions exist means re-pointing transactions |
| Intercompany / related-party customers → separate list for the decision | `INTERCO_REVIEW` | Picturehouse Entertainment D05190 carries open AR with a blank currency |
| Documents dated 3026-05-27 / 8202-02-28 → report, never "fix" | `BAD_DATE_REPORT` | two open PHTRA documents |
| E-mail present (SY01200 / RM00106) → contact point only if the contacts decision is yes | `EMAIL_QUARANTINE` | 99 PHTRA rows; PII |

## 10. Loading into Fusion

`references/load-runbook.md` is the step-by-step; the shape, so you can tell when something is
off:

1. **Confirm the pod and a free batch id** (check 0) — batch ids collided before, and one UK
   load went to `iartqy-dev1` instead of `ichqjb-dev2`.
2. **Build the zip**: one headerless CSV per interface table, the column order taken from the
   template, exactly as the AX playbook and the GP proving batches did.
3. **Load Interface File for Import** → import process *Import Trading Community Data in Bulk*
   (ESS `InterfaceLoaderController`, then `CDMAutoBulkImportJob`).
4. **Preview first** (argument 14 = `Y`), read the batch summary, then **commit** (`N`) only on
   Jonathan's word. A blank argument 14 imports nothing and looks like success. Preview does
   not validate profiles.
5. **A profile row imports only in the batch that carries its account row.** Profiles appear
   about 30 seconds after the job reports done — wait before judging.
6. **Re-loading an existing reference fails** ("duplicate combination" is DEV2's top error);
   a re-run is an update, or a new batch of only the rows that failed.

## 11. Verification and reconciliation

After every batch, run `scripts/fusion_post_load_checks.sql` checks 1–9 and answer, per GP
company:

- accounts created = rows sent − rejects (by `HZ_IMP_ERRORS`), with the rejects explained;
- every account has exactly one primary active BILL_TO site use;
- every account has a current account-level profile (`HZ_CUSTOMER_PROFILES_F` with an open
  effective date range), with the five required flags populated;
- credit limits present where GP had CRLMTTYP = 2 (once that decision is made);
- no location with null city or postal code; no untrimmed text;
- `HZ_ORIG_SYS_REFERENCES` holds one `GP` reference per entity per row sent.

Then reconcile back to GP: LOAD + HELD (reason-coded) + REJECT = the extract count for the chosen
selection option, per company, and the open-AR total of the loaded customers equals query R4's
total for the same set.

## 12. Decisions, open questions, history

`references/lessons-and-decisions.md` is the project memory: a dated timeline (US AX golden run
on 2026-10-15, the UK GP proving loads of 2026-10-09, the UK-PH stream opened 2026-10-16), what
worked, what broke and why, the decisions register, Jonathan's working rules that apply, and
the open questions. The blocking ones at the time of writing (`lessons-and-decisions.md` section 4 is the authoritative register; this list is a summary of what is still open):

1. Selection rule (A / B / C) and the treatment of intercompany, EUR / USD and dormant customers.
2. Business unit and reference-data set per GP company (`RGE_UK_PH_GBP_BU` / `ENTERPRISE` are
   defaults-in-use from the proving batches, not a decision), and whether PHBOO is in scope.
3. Party type for individuals (PHTRA has many person-named customers) — ORGANIZATION for all,
   or PERSON where the name says so.
4. Profile defaults (class, collector, terms when GP's term has no Fusion twin, statement cycle,
   the five required flags) as a Regal decision rather than a conversion default.
5. Duplicate / same-name customers: merge before load, or load as-is and review.
6. Whether contacts / e-mail contact points are in scope for the first load.

Defaults-in-use that look like decisions but are not: account number `<DB>-<CUSTNMBR>` (kept
by Fusion with auto-numbering on), source system `GP`, the reference scheme. Open questions
without a register entry yet: the GB address shape (county → COUNTY or dropped; blank country
→ GB) and a RICE / conversion id for customers (none exists; the US stream uses
`CNV.FIN.OTC.001`).

Do not re-ask a question the register marks decided; do not treat a default-in-use as decided.

## 13. Answering style

- Lead with the answer and the number, then the company and the date, then how you got it.
- Quote GP columns by their real names (`CUSTCLAS`, `PRBTADCD`) and Fusion objects by their real
  table names; a wrong name costs an hour at load time.
- When asked for a load, restate the preconditions (pod, batch id, preview/commit, Jonathan's
  word) before anything else.
- When the data disagrees with a document, say so and prefer the data; when two systems disagree
  (a transcript versus DEV2), prefer the observed system state and note the correction.
- Say "unverified" out loud. It is the most useful word in this skill.

## 14. Files in this skill and sources

```
gp-customer-conversion/
  SKILL.md                          this file
  references/
    gp-source-model.md              PH databases, RM tables, columns, GP semantics, DQ profile, selection options
    fusion-target-model.md          TCA chain, Customer Import FBDI, DEV2 as configured, mapping targets, traps
    field-mapping.md                GP column → interface column, per object, verified / documented / proposed
    load-runbook.md                 build → preview → commit → verify → reconcile, with what each step shows
    lessons-and-decisions.md        timeline, what worked / broke, decisions register, open questions
  scripts/
    gp_customer_profile.sql         five profiling queries (ran 2026-10-16 on PHEN2 and PHTRA)
    gp_customer_extract.sql         conversion-shaped extract with selection options (ran 2026-10-16)
    fusion_post_load_checks.sql     ten read-only checks against FUSION for a GP batch
```

Primary sources (each reference file carries its own citations):

- Live: Regal SQL Server MCP sites `Great-Plains`, `PHTRA-Great-Plains`, `PHEN2-Great-Plains`,
  `PHBOO-Great-Plains`, `PHGAP-Great-Plains`; Fusion DEV2 `ichqjb-dev2` (FUSION schema);
  Greenlight REGALCHATTAPP (conversations, DQ findings, golden runs, load batches) — all read
  2026-10-16.
- Microsoft: Dynamics GP Receivables Management documentation (learn.microsoft.com) and the
  azurecurve GP table reference for RM00101 / RM00102 / RM00106 / RM10301.
- Oracle: Fusion Cloud Financials "Import Your Customer Data" and the Tables and Views reference
  for the HZ_* and RA_* objects (docs.oracle.com), release 25D.
- Project: `AIX-GreenLight/docs/playbooks/ax-to-fusion-fbdi-conversion-playbook.md` (the proven
  AX pattern), Greenlight skills "Oracle Customer Conversion Rules", "Great Plains ERP Skill",
  "Oracle Load Error Prediction", and the sibling skills `ax-erp-source`,
  `great-plains-erp-source`, `ar-transaction-conversion-profiling`.
