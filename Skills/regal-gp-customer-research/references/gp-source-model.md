# GP source model: Picturehouse customers in Dynamics GP 2010

What this file is for: everything a converter needs to know about where Picturehouse customer
data lives in Dynamics GP, what the columns mean, and what the data actually holds, before
mapping anything to the Fusion Customer Import. Every number below comes from the read-only
research run of **2026-10-16** against the Regal SQL Server MCP. Quote the date with any
number you reuse, because the PH companies are live and still trading.

Scripts that go with this file:
- `scripts/gp_customer_profile.sql` re-runs the profile counters and value distributions.
- `scripts/gp_customer_extract.sql` produces the one-row-per-customer-per-address extract.

## Contents

1. [The Picturehouse GP databases](#1-the-picturehouse-gp-databases)
2. [The RM customer data model](#2-the-rm-customer-data-model)
3. [Column reference](#3-column-reference)
4. [GP semantics every converter must know](#4-gp-semantics-every-converter-must-know)
5. [Picturehouse data-quality profile](#5-picturehouse-data-quality-profile)
6. [Selection rule candidates (for Jonathan to decide)](#6-selection-rule-candidates-for-jonathan-to-decide)
7. [Sources and what was not verified](#7-sources-and-what-was-not-verified)

---

## 1. The Picturehouse GP databases

### 1.1 Environment

| Fact | Value | Why it matters |
|---|---|---|
| Host | `QC-ORACLESQL` (Regal SQL Server MCP), login `HKT-PH`, read-only | Nothing here may be changed; every query is a `SELECT`. |
| GP version | **Dynamics GP 2010**, 11.0.1752 in `DYNAMICS..DB_Upgrade` (PRODID 0) for all 55 databases, `db_status` 0 | GP 2010 keeps customer email in `SY01200`, not on the address row. |
| SQL Server | SQL Server 2022 (16.0.4275.2), Enterprise | The engine is modern, but the databases are not. |
| Company DB compatibility level | **100** (SQL 2008) | `STRING_AGG` fails ("Incorrect syntax near '('"). Concatenate with `STUFF(... FOR XML PATH(''))`. Avoid any post-2008 syntax. |
| Collation | Server `SQL_Latin1_General_CP850_CS_AS`; PHTRA `Latin1_General_CI_AS` | Comparisons inside a company DB are case-insensitive. A cross-DB join or a temp-table join may need `COLLATE DATABASE_DEFAULT`. |
| Cross-database reads | Work from any PH site (`PHEN2..RM00101` from the PHTRA site) | The customer-number clash check in section 5 relies on this. |

### 1.2 Companies in scope

`DYNAMICS..SY01500` (Company Master) holds 54 companies. **`INTERID` is the SQL database
name**, so it is also the company code to carry into Fusion source references.

| CMPANYID | CMPNYNAM | DB (`INTERID`) | MCP site | Customers |
|---|---|---|---|---|
| 36 | Picturehouse Cinemas Limited | PHTRA | `PHTRA-Great-Plains` | 8,484 |
| 47 | Picturehouse Entertainment Ltd (New) | PHEN2 | `PHEN2-Great-Plains` | 1,167 |
| 38 | Picture House Bookings | PHBOO | `PHBOO-Great-Plains` | 18 |
| 56 | PICTUREHOUSE US GAAP | PHGAP | `PHGAP-Great-Plains` | 0 |
| (system) | DYNAMICS | DYNAMICS | `Great-Plains` | n/a |

Out of reach: PHCON (Picturehouse Consolidated), PHENT (the old Picturehouse Entertainment,
superseded by PHEN2) and PHNMM (Picturehouse at NMM) have no MCP site and were not profiled.
The other companies on the server are Cineworld/Regal group entities and test/UAT copies
(including `TWO`, the Fabrikam sample).

**PHGAP drops out.** It is a US-GAAP reporting company with no customers. Its 1,611
`SY01200` rows belong to other master types, not customers.

### 1.3 Headline counts (rows, 2026-10-16)

| Table | Meaning | PHTRA | PHEN2 | PHBOO | PHGAP |
|---|---|---|---|---|---|
| RM00101 | Customer Master | 8,484 | 1,167 | 18 | 0 |
| RM00102 | Customer Address | 8,469 | 1,167 | 18 | 0 |
| RM00103 | Customer Summary | 8,484 | 1,167 | 18 | 0 |
| RM00106 | Statement email recipients | 99 | 11 | 1 | 0 |
| RM00201 | Customer Class | 3 | 3 | 3 | 0 |
| RM20101 | RM Open (documents) | 279 | 1,813 | 0 | 0 |
| RM30101 | RM History (documents) | 40,878 | 35,212 | 171 | 0 |
| SY01200 | Internet addresses (all masters) | 1,659 | 95 | 14 | 1,611 |
| SY03300 | Payment terms | 25 | 25 | 25 | 25 |
| MC020102 | RM multicurrency document amounts | 179 | 1,687 | not counted | not counted |
| TX00101 | Tax schedule header | 27 | 32 | 32 | 27 |

Across the three live companies there are **9,669 customers**, which reconciles to the
9,669 in the functional spec draft.

The SY03300 row counts come from the first-pass table inventory. The verification pass found
**22 distinct terms**, identical in PHTRA and PHEN2 (section 3.7); the difference between 25
rows and 22 terms was not explained.

**Functional currency is GBP** in both PHTRA and PHEN2 (`MC40000.FUNLCURR`, verification pass).
MC40000 lives in each company DB; DYNAMICS has no MC40000 table.

---

## 2. The RM customer data model

```
                          RM00201 Customer Class (CLASSID)
                                   ^  defaults only, copied at creation
                                   |  joined on RM00101.CUSTCLAS
SY03300 Terms (PYMTRMID) <--+      |      +--> TX00101/TX00102 Tax (TAXSCHID)
                            |      |      |
                       +---------------------------+
                       |  RM00101 Customer Master  |  PK CUSTNMBR
                       |  ADRSCODE (primary)       |---- RM00103 Summary (1:1, balances)
                       |  PRBTADCD (bill-to)       |---- RM00106 Statement emails (1:n)
                       |  PRSTADCD (ship-to)       |---- RM20101 Open docs  (1:n)
                       |  STADDRCD (statement-to)  |---- RM30101 History docs (1:n)
                       +---------------------------+
                          |  CUSTNMBR + address ID
                          v
                       +---------------------------+
                       | RM00102 Customer Address  |  PK (CUSTNMBR, ADRSCODE)
                       +---------------------------+
                          |  Master_Type='CUS', Master_ID=CUSTNMBR, ADRSCODE
                          v
                       SY01200 Internet Addresses (email per address)
```

How to read it:
- **RM00101 is the customer.** One row per customer per company. It also carries a
  denormalised copy of the primary address (ADDRESS1..FAX), which can drift from RM00102.
- **RM00102 is the address list.** The four address-ID pointers on RM00101 (ADRSCODE,
  PRBTADCD, PRSTADCD, STADDRCD) each name an RM00102 row for the same customer. They become
  the Fusion site uses BILL_TO, SHIP_TO and STATEMENTS.
- **RM00103** holds balances and statistics, one row per customer. `CUSTBLNC<>0` gives
  the same open-balance count as RM20101 (156 PHTRA, 166 PHEN2), so it is a quick check.
- **RM00106** holds statement email recipients per customer. **SY01200** holds email per
  customer *address*, keyed by `Master_Type` `'CUS'` + `Master_ID` + `ADRSCODE`. RM00102
  itself has no email column in GP 2010.
- **RM00201, SY03300, TX00101/TX00102** are setup tables the customer points at.
- **RM20101 / RM30101** are the open and history document files. They decide which
  customers are worth converting (open balance, last activity).

Tables that look relevant but are not here:

| Table | Why it doesn't matter for Picturehouse |
|---|---|
| RM00105 National Accounts | 0 rows in every company, and no customer carries `CPRCSTNM`. There is no hierarchy to convert. |
| RM00301 Salesperson / RM00303 Territory | 0 rows; `SLPRSNID` and `SALSTERR` are blank on 100% of customers. Nothing maps to Fusion salesreps. |
| SY06000 EFT bank details | PHTRA has 3 customer rows (SERIES 3), all inactive; PHEN2 and PHBOO have none. No customer bank accounts need converting. Values were never selected. |
| SY03900 Record Notes | Only 3 PHTRA customers have a real note. |
| Extender (EXT*) | Only vendor tolerance windows exist; no Extender data is attached to customers. |
| `gpCustomerException` | Custom table in PHEN2/PHGAP, 0 rows in PHEN2; purpose unverified. |
| `XW_*` | A third-party purchasing add-on; no customer data. |

---

## 3. Column reference

Only the columns a conversion reads. Types come from `INFORMATION_SCHEMA.COLUMNS` (PHTRA;
RM00101 has 103 columns in all three live companies). Meanings cite Microsoft Learn
*Receivables Management* (MS RM) or the azurecurve GP Table Reference (AC); see section 7.
Percentages are PHTRA unless stated.

### 3.1 RM00101 Customer Master

| Column | Type | Meaning (source) | What PH holds |
|---|---|---|---|
| CUSTNMBR | char(15) PK | Customer ID; unique per company DB only (AC RM00101) | All `D0nnnn`. PHTRA lengths 5:1, 6:8,478, 7:5; outliers `DO5594` (letter O), `D0803`, `D072010..D072014`. No spaces, lowercase or symbols. |
| CUSTNAME | char(65) | Customer name (AC) | Max length 62 PHTRA, 60 PHEN2. 114 duplicate-name groups PHTRA. Many are individuals. |
| SHRTNAME | char(15) | Short name for lookups | Filled 8,483 PHTRA, 1,163 PHEN2. |
| STMTNAME | char(65) | Name printed on statements | Differs from CUSTNAME for 21 PHTRA, 22 PHEN2. |
| CUSTCLAS | char(15) | Customer class (joins RM00201.CLASSID) (MS RM ch.3) | PHTRA GBP 8,244 / blank 223 / EUR 10 / USD 7. PHEN2 GBP 1,081 / EUR 63 / USD 18 / blank 5. |
| CNTCPRSN | char(61) | Contact person | Filled 3,032 PHTRA, 374 PHEN2. Personal data. |
| ADRSCODE | char(15) | Primary address ID (MS RM ch.4) | `MAIN` for almost all; typos listed in section 5. |
| PRBTADCD / PRSTADCD / STADDRCD | char(15) | Primary bill-to, ship-to, statement-to address IDs (AC; TrueCommerce) | All four equal ADRSCODE for 8,483 of 8,484 PHTRA, all PHEN2 and PHBOO. |
| ADDRESS1-3, CITY, STATE, ZIP | char(61/35/29/11) | Copy of the primary address | Prefer RM00102. Blank ADDRESS1 1,209 / CITY 2,342 / ZIP 1,661 PHTRA. |
| COUNTRY | char(61) | Country, free text | Blank 508 PHTRA, 115 PHEN2. Mixed case. |
| CCode | char(7) | Country code (ISO-2 in practice) | Blank 513 PHTRA, 115 PHEN2. GB 7,770 PHTRA. |
| PHONE1-3, FAX | char(21) | Phone numbers | PHONE1 blank 96% PHTRA, 86% PHEN2, 100% PHBOO. Values never selected. |
| PYMTRMID | char(21) | Payment terms (SY03300) | PHTRA D030 8,255 / D010 15 / blank 214. PHEN2 D030 1,161 / D005 1 / blank 5. PHBOO D010 16 / D030 2. |
| TAXSCHID | char(15) | Tax schedule (TX00101) | PHTRA VOS 8,176 / blank 176 / ROWO 100 / VOI 26 / VIS 2 / VOZ 2 / VIZ 1 / VOD 1. PHEN2 VOS 1,023 / VOI 84 / ROWO 49 / VOZ 8 / blank 3. PHBOO VOS 18. |
| SHIPMTHD | char(15) | Shipping method (SY03000) | `SALES` on 8,311 PHTRA, 1,162 PHEN2, 18 PHBOO; a placeholder, not a carrier. |
| SLPRSNID / SALSTERR | char(15) | Salesperson / territory | Blank 100% in every company. |
| CURNCYID | char(15) | Currency ID | PHTRA GBP 8,243 / EUR 10 / USD 7 / blank 224. PHEN2 GBP 1,081 / EUR 63 / USD 18 / blank 5. Blank currency lines up with CRLMTTYP 0 (224 and 5). |
| CRLMTTYP | smallint | Credit limit type (MS RM ch.4) | PHTRA 0:224 / 1:17 / 2:8,243. PHEN2 0:5 / 1:81 / 2:1,081 (both confirmed by the verification pass). PHBOO 2:18. |
| CRLMTAMT | numeric(19,5) | Credit limit amount when type 2 | Type 2 PHTRA: 8,242 at or under 10k, 1 above. PHEN2: all at or under 10k. |
| BALNCTYP | smallint | Open item or balance forward (MS RM ch.3) | 0 (open item) for every customer, confirmed by the verification pass in PHTRA and PHEN2. |
| STMTCYCL | smallint | Statement cycle (MS RM ch.3/4) | 5 for every customer (PHTRA 8,484, PHEN2 1,167; verification pass). |
| HOLD | tinyint | Temporary hold (MS RM ch.5) | PHTRA 2, PHEN2 1, PHBOO 0; all also inactive. |
| INACTIVE | tinyint | Inactive (MS RM ch.5) | PHTRA 10, PHEN2 3, PHBOO 0. |
| COMMENT1 / COMMENT2 | char(31) | Free-text comments (MS RM ch.4) | Filled 4,121 PHTRA, 506 PHEN2, 16 PHBOO. |
| USERDEF1 / USERDEF2 | char(21) | User-defined fields (MS RM ch.1) | Empty in every company. |
| TXRGNNUM | char(25) | Tax (VAT) registration number (MS RM ch.4) | Filled 1 PHTRA, 5 PHEN2, 0 PHBOO. |
| PRCLEVEL | char(11) | Price level | `STD` on 8,260 PHTRA, 1,162 PHEN2, 18 PHBOO. |
| RMARACC | int | Customer-level AR account index (GL00100/GL00105) | Set on 8,260 PHTRA, 1,162 PHEN2, 18 PHBOO. Index only; not resolved to strings. |
| Send_Email_Statements | tinyint | Email statements flag | 76 PHTRA, 0 PHEN2, 1 PHBOO. |
| NOTEINDX | numeric(19,5) | Link to SY03900 notes | Real note on 3 PHTRA customers. |
| FRSTINDT | datetime | First invoice date | `1900-01-01` for 100%: carries no information. |
| CREATDDT / MODIFDT | datetime | Created / modified dates | CREATDDT PHTRA 2015-02-16..2026-08-07; PHEN2 2017-04-27..2026-08-13; PHBOO 2015-02-16..2017-10-03. |
| CPRCSTNM | char(15) | National-account parent | Never set. |
| CRCRDNUM / BANKNAME | char(21/31) | Card number / bank name | Never extract CRCRDNUM. Both 0 filled (counted only). |
| DEX_ROW_ID / DEX_ROW_TS | int / datetime | Dexterity identity and last-modified timestamp | Not a business key. |

### 3.2 RM00102 Customer Master Address File (PK CUSTNMBR, ADRSCODE)

| Column | Type | Meaning | What PH holds |
|---|---|---|---|
| CUSTNMBR, ADRSCODE | char(15) | Key | 0 orphan rows; 19 PHTRA customers have no row at all. |
| CNTCPRSN | char(61) | Contact for this address | Personal data. |
| ADDRESS1-3 | char(61) | Address lines | Blank line 1 on many PHTRA rows (see section 5). |
| CITY / STATE / ZIP | char(35/29/11) | City, county, postcode | STATE is free-text county: 360 distinct PHTRA, 64 PHEN2, 2 PHBOO. |
| COUNTRY / CCode | char(61) / char(7) | Country text and code | See section 5, fact 6. |
| PHONE1-3, FAX | char(21) | Phones | Never selected. |
| SHIPMTHD, TAXSCHID, SLPRSNID, SALSTERR | char(15) | Address-level overrides of the customer defaults (MS RM ch.4) | 3 PHTRA addresses have a TAXSCHID different from the customer's; SLPRSNID never differs. |
| LOCNCODE | char(11) | Site (inventory location) default | Not profiled. |
| USERDEF1/2 | char(21) | User-defined | Not profiled at address level. |
| CREATDDT / MODIFDT | datetime | Dates | |

### 3.3 RM00103 Customer Master Summary

| Column | Type | Meaning | What PH holds |
|---|---|---|---|
| CUSTNMBR | char(15) | Key, 1:1 with RM00101 | 8,484 / 1,167 / 18 |
| CUSTBLNC | numeric(19,5) | Current customer balance | Non-zero for 156 PHTRA, 166 PHEN2: matches RM20101. |
| LSTTRXDT, LASTPYDT | numeric/int/datetime family (exact type not recorded) | Last transaction / payment date | Not profiled; the extract uses RM20101/RM30101 DOCDATE instead. |

### 3.4 RM00106 Statement email recipients

| Column | Type | Meaning | What PH holds |
|---|---|---|---|
| CUSTNMBR | char(15) | Customer | 99 PHTRA, 10 PHEN2, 1 PHBOO customers. |
| Email_Type | smallint | 1 To, 2 Cc, 3 Bcc (GP convention, **unverified** against MS docs) | Not profiled. This column is on RM00106 only; SY01200 has no Email_Type column. |
| Email_Recipient | char(81) | Email address (AC RM00106) | Personal data; only counted. |

### 3.5 SY01200 Internet Addresses (key Master_Type, Master_ID, ADRSCODE)

| Column | Type | Meaning | What PH holds |
|---|---|---|---|
| Master_Type | char(3) | `CUS`, `VEN`, `CMP` observed | Filter `'CUS'`. |
| Master_ID | char(31) | CUSTNMBR when Master_Type is `CUS` | Note char(31) vs CUSTNMBR char(15); RTRIM both sides when joining. |
| ADRSCODE | char(15) | Address ID, so email is per address | |
| INET1..INET8 | char(201) | Labelled internet fields; INET1 is email by default label | PHTRA 99 customer rows: 10 with INET1, 90 with EmailToAddress. PHEN2: 0 customer rows. |
| EmailToAddress / EmailCcAddress / EmailBccAddress | text | Email lists | Customers with email: 99 PHTRA, **0 PHEN2**, 1 PHBOO. Values never selected. |

### 3.6 RM00201 Customer Class Master (same three classes in each live DB)

| Column | Type | Meaning | What PH holds |
|---|---|---|---|
| CLASSID | char(15) | Class key (the customer column is CUSTCLAS) | GBP, EUR, USD |
| CLASDSCR | char(31) | Description | GBP/UK Customers, Euro Customers, US Dollar Customers |
| PYMTRMID / TAXSCHID / CURNCYID | char | Defaults copied to new customers (MS RM ch.3) | GBP: D030/VOS/GBP. EUR: D030/VOI/EUR. USD: D030/ROWO/USD. **PHBOO EUR: D030/ROWO/USD (misconfigured; no PHBOO EUR customers).** |
| BALNCTYP / CRLMTTYP | smallint | Defaults | BALNCTYP 0 for all. CRLMTTYP GBP 2, EUR 1, USD 1. |
| DEFLTCLS | tinyint | Default class flag | **USD is the default** in every DB, though about 97% of customers are GBP. |

### 3.7 SY03300 Payment Terms

| Column | Type | Meaning | What PH holds |
|---|---|---|---|
| PYMTRMID | char(21) | Terms key | 22 terms, identical in PHTRA and PHEN2: the D-codes and EOM. `Dnnn` = net nnn days. |
| DUETYPE | smallint | Due-date rule | 1 (net days) for the D-codes D000..D128; 3 for D110 and D120 (DUEDTDS 0); 5 for EOM. The meanings of codes 3 and 5 are GP convention, not confirmed in MS docs. |
| DUEDTDS | smallint | Due days or day of month | Equals the days in the code for DUETYPE 1 (D030 = 30); 0 for D110/D120; 15 for EOM. |
| DISCTYPE | smallint | Discount rule | 1 for every term. |

### 3.8 TX00101 Tax Schedule Header (details in TX00102 by TAXSCHID, TAXDTLID)

| Column | Type | Meaning | What PH holds |
|---|---|---|---|
| TAXSCHID | char(15) | Schedule key | Outputs VOS (Standard), VOZ (Zero), VOE (Exempt), VOO (Outside scope), VOI (EU sales), ROWO (Rest of World outputs), VO5, VO12.5, VOD (dummy). ALL-SALES/ALL-PURCHASES are aggregates. Inputs are VI*, ROWI, EE-*. PHEN2 also has G* schedules (GIS-3, GIE, GIS, GIZ, GOE, GOS, GOS-3, GOZ), purpose **unverified**. |
| TXSCHDSC | char(31) | Description | |

Every non-blank customer TAXSCHID and PYMTRMID exists in its master table (0 orphans in
PHTRA and PHEN2), so the lookups are safe to inner-join.

---

## 4. GP semantics every converter must know

**CHAR padding: RTRIM everything.** Every string column is fixed-width `char(n)` padded with
trailing spaces. There are no NULLs in GP tables; blank means `''` plus padding. Without
RTRIM, `'MAIN'` and `'MAIN           '` look different to the Fusion loader and lengths are
wrong. RTRIM on extract, and compare with `RTRIM(col)=''` to find blanks.

**The 1900-01-01 sentinel.** GP stores "no date" as `1900-01-01 00:00:00`. Map it to NULL
in the conversion; a literal 1900 date in Fusion is wrong data, not missing data.

**CUSTCLAS, not CLASSID.** The class column on RM00101 is `CUSTCLAS`; `CLASSID` exists only
on RM00201. Class values are defaults copied at creation (and on optional roll-down), and the
customer row keeps its own copy. Read terms, tax, currency and credit from the **customer
row**, never from the class.

**HOLD vs INACTIVE.** HOLD is a temporary stop on sales; payments can still be recorded.
INACTIVE is permanent: no transactions of any kind, and GP only allows it with no outstanding
invoices (MS RM ch.5). In PH every HOLD customer is also INACTIVE and no inactive customer
has an open balance, which is consistent with that rule.

**BALNCTYP.** 0 = open item (documents kept individually, multicurrency allowed), 1 = balance
forward. It cannot be changed once set. Every customer in PHTRA and PHEN2 is 0 (verification
pass), so the conversion only ever meets open item; the 0/1 code order is GP convention.

**CRLMTTYP / CRLMTAMT.** 0 = no credit, 1 = unlimited, 2 = specified amount in CRLMTAMT. The
order follows the MS wording "no credit, unlimited credit, or a specified amount"; the numeric
mapping is inferred from the class data (GBP class = 2 with amounts) and is **not printed in
the MS doc**. CRLMTPER/CRLMTPAM are period-based limits and were not profiled.

**STMTCYCL.** The drop-down is No Statement, Weekly, Biweekly, Semimonthly, Monthly,
Bimonthly, Quarterly. By GP convention 1..7 in that order, so 5 = Monthly. Every customer in
PHTRA and PHEN2 is 5 (verification pass), so the conversion maps one value. The meaning of
the other codes stays GP convention, not confirmed in MS docs.

**CURNCYID blank.** A blank customer currency is read as "use the functional currency", and
the functional currency is GBP in both PHTRA and PHEN2 (`MC40000.FUNLCURR`). 224 PHTRA and 5
PHEN2 customers are blank, including the intercompany customer D05190 with open AR. The same
customers have CRLMTTYP 0, which suggests they were created without a class rather than
deliberately. Map blank to GBP through an explicit defaulting rule, so the choice is recorded.

**DEX_ROW_ID.** An identity column Dexterity adds to every table. It is not a business key
and not stable across companies. Use it for ordering or change detection only.

**Document types (RMDTYPAL in RM20101/RM30101)** (AC RM10301):

| Code | Type | Effect on AR |
|---|---|---|
| 0 | Balance carried forward | |
| 1 | Sales / invoice | increases |
| 2 | Scheduled payment | increases |
| 3 | Debit memo | increases |
| 4 | Finance charge | increases |
| 5 | Service / repair | increases |
| 6 | Warranty | increases |
| 7 | Credit memo | decreases |
| 8 | Return | decreases |
| 9 | Payment | decreases |

CURTRXAM is always positive; the sign comes from the type. That is why the open-balance
formula is `SUM(CASE WHEN RMDTYPAL < 7 THEN CURTRXAM ELSE -CURTRXAM END)` with `VOIDSTTS = 0`.

**CURTRXAM vs ORTRXAMT.** CURTRXAM is the current (remaining) amount on an open document,
in **functional** currency; it is what an open balance is built from. ORTRXAMT, the original
document amount, exists in both RM20101 and RM30101 in PHTRA and PHEN2 (verification pass).
Use it to show how much of a document is still open, not to compute the balance. Note that
`ORCTRXAM` does not exist in RM20101 or RM30101; it is an MC020102 column.

**Multicurrency (MC020102).** Originating-currency amounts for RM documents live in MC020102,
with RMDTYPAL, DOCNUMBR and CUSTNMBR to tie it to RM20101/RM30101 (the table's key was not
confirmed), plus CURNCYID, XCHGRATE, EXCHDATE and the OR\*
amounts (ORCTRXAM is the current originating amount, ORAPPAMT applied, ORTAXAMT tax and so on).
It exists in both companies: PHTRA 179 rows, PHEN2 1,687. The join to RM20101 and the
originating-currency open balance of PHEN2's 41 EUR documents have **not been computed**; the
extract's open balance is functional (GBP) only.

**KPCALHST and the other KP\*HST flags** (KPDSTHST, KPCALHST, KPERHIST, KPTRXHST, tinyint)
exist on RM00101 and on RM00201. They were not profiled, their meaning was not researched, and
the conversion does not read them.

---

## 5. Picturehouse data-quality profile

Each fact gives the number, the company and the evidence. "Profile" means the counter of that
name in `scripts/gp_customer_profile.sql` (from the research's `q_profile.sql`); "dims" means
the distribution query (`q_dims.sql`).

1. **Customer numbers clash across companies (critical).** PHTRA and PHEN2 share **1,163**
   CUSTNMBRs and **0** of those pairs have the same name. PHTRA/PHBOO share 18 (0 same name),
   PHEN2/PHBOO 13 (0). Going the other way, joining PHTRA to PHEN2 on name gives 239 pairs
   (236 distinct PHTRA customers) with the same name but different numbers. Across both
   companies combined, 344 names cover 722 customers. Each company numbers its own customers from D00001 in the same `D0nnnn`
   space. So CUSTNMBR can never be the Fusion key on its own: qualify it with the company
   (for example `PHTRA-D00659`), or decide a name-based party merge deliberately. Evidence:
   cross-DB collision query run from the PHTRA site (profile query 3).
2. **224 PHTRA customers lack class, currency, terms and tax.** CUSTCLAS blank 223, CURNCYID
   blank 224 (one GBP-class customer has blank currency), PYMTRMID blank 214, TAXSCHID blank
   176. They were created 2015-03 to 2022-04 and 219 of them have activity, so they cannot
   simply be dropped. The GP default class is USD, which would be wrong for a GBP business.
   PHEN2 has 5 class-less customers. Evidence: profile `blank_class`, `blank_curncy`,
   `blank_pymtrmid`, `blank_taxschid`; dims `CLASS_vs_CURR`.
3. **19 PHTRA customers have no address row at all.** All have blank ADRSCODE and blank class
   and were created 2016-05 to 2018-03. Evidence: profile `no_addr_rows`,
   `blank_primary_adrscode`.
4. **Addresses are thin.** PHTRA RM00101: ADDRESS1 blank 1,209, CITY 2,342, ZIP 1,661,
   COUNTRY 508, CCode 513. PHEN2: 113 / 311 / 211 / 115 / 115. PHBOO: 2 / 9 / 2 / 1 / 1.
   STATE is free-text county (360 values PHTRA). Fusion needs at least a country per location,
   so a default (GB) or an exclusion rule is needed. Evidence: profile `blank_addr1`,
   `blank_city`, `blank_zip`, `blank_country`, `blank_ccode`, `distinct_state`.
5. **The primary address copy drifts.** RM00101's address differs from its RM00102 primary
   row for 2 PHTRA and 2 PHEN2 customers, so RM00102 is the source of truth. Evidence: profile
   `primary_addr_copy_drift`.
6. **COUNTRY is free text; use CCode.** PHTRA mixes `United Kingdom` (7,775), `AUSTRALIA`,
   `Ireland`, `UAE`, `ISLE OF MAN`. CCode is ISO-2 and populated wherever COUNTRY is, but the
   two can disagree: PHTRA has 7 CCode `FR` with no `FRANCE` text. PHEN2's text and codes are
   consistent. Evidence: dims `CCode`; RM00102 COUNTRY distribution.
7. **Address-ID typos, and every customer is really one site.** ADRSCODE is not `MAIN` on 11
   PHTRA rows (`M` x3, `MAI` x2, `MIAN` x2, `MIN`, `MAON`, a street-address string) and 1 PHEN2 row
   (`M`). Only 4 PHTRA customers have two addresses, and those are typo duplicates with a blank
   city beside `MAIN`. All four pointers are equal for 8,483 PHTRA customers. Collapse each
   customer to one site carrying BILL_TO, SHIP_TO and STATEMENTS. Evidence: profile
   `multi_addr_cust`, `max_addr_per_cust`, `all4_same`; dims `ADRSCODE`.
8. **Bad dates.** FRSTINDT is `1900-01-01` for 100% of customers in every company. Two open
   PHTRA documents carry impossible years: `D00301` doc 176 dated 3026-05-27 and `D02785`
   `CRD02556` dated 8202-02-28. They distort "last activity" and matter for the AR
   open-balance conversion. Map 1900-01-01 to NULL; clamp or flag future years. Evidence:
   profile `frstindt_sentinel`; dims `LASTACT_YEAR` (years 3026 and 8202).
9. **Duplicate names and personal data.** PHTRA has 114 duplicate-name groups (248
   customers), PHEN2 21 (42), PHBOO 0. Many PHTRA customers are individuals, which bears on the
   Fusion party type (Person vs Organization) and on keeping names out of reports. Phone is
   86-100% blank. Email exists for 99 PHTRA customers in SY01200 and **0** PHEN2 customers
   (PHEN2 has 10 statement emails in RM00106). Evidence: profile `dup_name_groups`,
   `dup_name_custs`, `blank_phone1`, `cust_with_email_sy01200`, `cust_with_rm00106`.
10. **Intercompany customers and EUR documents.** Group companies are customers carrying open
    AR: D05190 "Picturehouse Entertainment" in PHTRA (blank currency, 35,230.30 open), D00519
    "Picturehouse Cinemas Ltd" in PHEN2 (50,622.00), plus Regal Cinemas Inc (PHTRA D06015,
    47,815.83) and Cineworld Cinemas Ltd (PHEN2 D00116, 22,473.21). These need intercompany or
    related-party treatment in Fusion. PHEN2 has 41 EUR open documents (of 1,813), so it has
    foreign-currency AR; PHTRA's open documents are all GBP. Evidence: top open balances query
    (profile query 4); dims `RM20101_CURR`.

Minor notes, from the same run: 3 PHTRA customers sit on *input* tax schedules (VIS 2, VIZ 1),
a misconfiguration. PHBOO's EUR class carries USD/ROWO. Customers in other countries still sit
on GBP classes, so CUSTCLAS reflects billing currency, not geography. Open AR net (functional):
PHTRA **1,298,917.25**, PHEN2 **598,322.80**, PHBOO 0.

Possible link to the delivered May 2026 extract (unverified): that file shows 1,147 customers
under both `PICTUREHOUSE CINEMAS` and `PICTUREHOUSE BOOKINGS`, though PHBOO has only 18
customers. The 1,163 shared PHTRA/PHEN2 numbers are one possible explanation (two different
customers merged on number). Nobody has checked this.

---

## 6. Selection rule candidates (for Jonathan to decide)

**These are options, not decisions.** Which customers to convert is Jonathan's call and is
not recorded anywhere yet. Counts are as of 2026-10-16. PHBOO was not re-run in the verification pass.

| Option | Rule | PHTRA | PHEN2 | PHBOO | Total | Basis |
|---|---|---|---|---|---|---|
| A | Open balance only (any non-void RM20101 document with CURTRXAM <> 0) | 156 | 166 | 0 | 322 | Measured |
| B | Open balance **or** any document dated on or after 2024-01-01 (RM20101 or RM30101) | 1,965 | 410 | 0 | 2,375 | Measured (verification pass; the first pass reported 1,964 for PHTRA) |
| C | All active customers (`INACTIVE = 0`) | 8,474 | 1,164 | 18 | 9,656 | Measured PHTRA/PHEN2 (verification pass); PHBOO derived |
| (ref) | Customers with any activity ever | 5,183 | 727 | 5 | 5,915 | Derived: customers minus "no activity" (3,301 / 440 / 13) |

What each option costs:
- **A** is the minimum the AR open-balance conversion needs: every open document must find
  its customer. It leaves out customers who trade regularly but happen to be at zero.
- **B** matches "who is a real customer today". The PHTRA count includes the two bad-dated
  documents (3026, 8202); both are open, so they qualify under the open-balance half anyway.
  By last-activity year alone PHTRA has 653 + 648 + 656 = 1,957 customers in 2024-2026. PHBOO
  falls out entirely (no activity since 2022).
- **C** converts about 3,750 customers who have never transacted (39% of PHTRA, 38% of PHEN2,
  72% of PHBOO) along with every name duplicate and thin address. It is the least defensible
  for data quality.

Whatever the rule, the cross-company clash (fact 1) means the selected set must carry the
company code, and the class-less customers (fact 2) need a defaulting rule if any of them is
selected. The extract script carries all three options as commented-out WHERE clauses.

---

## 7. Sources and what was not verified

Sources:
- Live read-only queries, 2026-10-16, Regal SQL Server MCP sites `Great-Plains`,
  `PHTRA-Great-Plains`, `PHEN2-Great-Plains`, `PHBOO-Great-Plains`, `PHGAP-Great-Plains`.
- Microsoft Learn, *Microsoft Dynamics GP Receivables Management*:
  https://learn.microsoft.com/en-GB/dynamics-gp/financials/receivables-management
  (also https://support.microsoft.com/en-us/help/871990/receivables-management).
- azurecurve GP Table Reference: RM00101
  https://gptables.azurecurve.co.uk/products/microsoft dynamics gp-0/sales/rm-customer-mstr-rm00101 ;
  RM00106
  https://gptables.azurecurve.co.uk/products/microsoft-dynamics-gp-0/sales/rm-statements-e-mail-addresses-rm00106 ;
  RMDTYPAL via RM10301
  https://gptables.azurecurve.co.uk/products/microsoft-dynamics-gp-0/sales/rm-sales-work-file-rm10301
- PRSTADCD/RM00102 dependency:
  https://help.truecommerce.com/en/articles/6518720-dynamics-gp-standard-advance-error-primary-ship-to-address-id-prstadcd-does-not-exist-in-the-rm00102-table

Not verified:
- Originating-currency open balances: MC020102 exists and its columns are known, but the
  join and the totals were not computed.
- The code meanings of STMTCYCL (other than 5), RM00106 Email_Type, CRLMTTYP and SY03300
  DUETYPE 3/5 come from GP convention plus observation, not an explicit Microsoft table. The
  counts themselves are verified.
- Why SY03300 shows 25 rows in the inventory but 22 terms in the verification pass.
- RMARACC indexes were not resolved to GL account strings (GL00105).
- The purpose of `gpCustomerException` and of PHEN2's G* tax schedules is unknown.
- PHENT, PHCON and PHNMM have no MCP site and were not profiled.
- Both scripts were run live on PHEN2 and PHTRA on 2026-10-16 and needed no fixes. PHBOO was
  not re-run, so its numbers are from the first pass only.
