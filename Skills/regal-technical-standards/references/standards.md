# Regal Technical Standards — Full Reference

Source: *Oracle Cloud Applications Implementation — Technical Standards and Best Practices*, v1.0, Fredy Ramirez, 7/10/2026. This file is the complete, faithful transcription of the standard's tables. When SKILL.md's quick patterns are insufficient, this file is authoritative.

## Contents

1. RICE naming (ID / Code / Name)
2. Service account naming
3. OIC component naming
4. BIP/OTBI — Customize a Seeded Report
5. BIP — New Custom Report
6. BIP — Integration Reports
7. BIP — Conversion Reports (Pre / Post / Error)
8. PaaS Database objects & Regal schemas
9. VBCS objects
10. History header & comment standards
11. Worked end-to-end example

---

## 1. RICE naming

**RICE ID** — `<Company>.<Pillar>.<Module>.<Location>.<Type>.<Seq>`

Examples:
- `RGE.ERP.AP.ALL.INT.001`
- `RGE.SCM.INV.CCI.INT.002`
- `RGE.SCM.INV.ALL.RPT.002`
- `RGE.HCM.HR.PL.INT.001`
- `RGE.EPM.FCC.ALL.INT.001`

Allowed values:
- `<Company>` = `RGE`, `HKT`
- `<Pillar>` = `ERP`, `SCM`, `HCM`, `EPM`
- `<Module>` = `GL`, `AP`, `AR`, `CM`, `FA`, `PO`, `INV`, `OM`, `PAY`, `BEN`, `FCC`, `ARCS` (examples also use `HR` for HCM core)
- `<Location>` = `ALL`, or specific: `US`, `UK`, `PL`, `BL`, `SL`, or special: `CCI`
- `<Type>` = `RPT`, `INT`, `CNV`, `EXT`

**RICE Code** — `<Company>_<Pillar>_<Module>_<Location>_<Type>_<Code Name>` (UPPERCASE)

Examples:
- `RGE_ERP_AP_ALL_INT_INVO_CREATE`
- `RGE_SCM_INV_CCI_INT_ITEM_CREATE`
- `RGE_SCM_INV_ALL_RPT_INV_BAL`
- `RGE_HCM_HR_PL_INT_EMP_CREATE`
- `RGE_EPM_FCC_ALL_INT_TRIAL_BAL`

**RICE Name** — `<Company> <Module> <Location> <Short Name>` (Mixed Case, **no pillar segment**)

Examples:
- `RGE AP ALL Invoice Creation`
- `RGE INV CCI Item Creation`
- `RGE INV ALL Inventory Balance`
- `RGE HR PL Employee Creation`
- `RGE FCC ALL Trial Balance`

> Consistency rule: OIC Integration names and BIP layout/report/ESS display names must match the RICE Name form; codes/short names must match the RICE Code form.

---

## 2. Service account naming

Pattern for all tiers: `<Tier>_<Pillar>_<Use>_SVC`

| Tier | Examples |
|---|---|
| Fusion Applications (`FUS`) | `FUS_ERP_INT_SVC`, `FUS_ERP_CONV_SVC` (temp), `FUS_SCM_INT_SVC`, `FUS_SCM_CONV_SVC` (temp), `FUS_HCM_INT_SVC`, `FUS_HCM_CONV_SVC` (temp), `FUS_ERP_VERTEX_SVC` |
| OIC (`OIC`) | `OIC_ERP_INT_SVC`, `OIC_SCM_INT_SVC`, `OIC_HCM_INT_SVC` |
| OCI (`OCI`) | `OCI_ERP_INT_SVC`, `OCI_SCM_INT_SVC`, `OCI_HCM_INT_SVC` |
| Database (`DB`) | `DB_ERP_INT_SVC`, `DB_SCM_INT_SVC`, `DB_HCM_INT_SVC` |
| FTP/sFTP (`FTP`) | `FTP_ERP_INT_SVC`, `FTP_SCM_INT_SVC`, `FTP_HCM_INT_SVC` |

Note: **conversion (`CONV`) service accounts are temporary** and should be flagged for de-provisioning after conversion completes.

---

## 3. OIC component naming

| Component | Convention | Example |
|---|---|---|
| Project | `<Company Short Name> <Pillar>`; if common across clients use `<CLIENT> <Pillar>` | `RGE ERP`, `RGE HCM`, `RGE EPM` |
| Connection | `<Company> <Target System / Endpoint (short) / Operation / Purpose / Adapter> <Type: REST\|SOAP\|FTP\|Database> <Environment: DEV1\|DEV2\|TEST1\|PROD>`. Environment suffix **only** when one OIC instance serves multiple Fusion environments. Case: Mixed. Identifier: UPPERCASE of the name. Description required. | `RGE ERP Cloud REST DEV1`, `RGE ERP Cloud Report Invoke SOAP TEST1`, `RGE ATP Database DEV2` |
| Integration | `<Company> <Target Module (or Common)> <Target Location> <Operation/Purpose> [<Frequency: Daily\|Bi Weekly\|Weekly\|Monthly\|Yearly>] <Direction: Inbound\|Outbound>` (direction relative to Oracle Fusion). Case: Mixed. Identifier: UPPERCASE. Description required. **Must match RICE Name.** | `RGE INV CCI Create Items Outbound`, `RGE PO ALL Create Requisitions Inbound`, `RGE GL PL Currency Rates Daily Inbound` |
| Lookup | `<COMPANY>_<MODULE or COMMON>_<OBJECT>_LKP` — UPPERCASE | `RGE_AP_PAYMENTTERM_LKP` |
| Agent Group | `<COMPANY>_<TARGET SYSTEM or COMMON>_<OBJECT>_AG` — UPPERCASE | `RGE_INFINIUM_AG` |
| Variables | Globals: `g_<name>`; Locals: `l_<name>`; Mixed Case | `g_fileName`, `l_fileName` |
| Endpoint name | `<operation>_IN/FROM/TO_<AdapterName>` (no spaces). Description states exactly what the operation does. | `writeFile_TO_SFTP` — "This Operation will write Log file to SFTP server"; `submitESSJOB_IN_ERP_CLOUD` — "This Operation will submit Import Supplier ESS Job in Oracle Cloud ERP Application" |
| JavaScript function | `<MODULE or CMN>_<ACTION>_FNC` — UPPERCASE | `AP_VENDOR_LOOKUP_FNC` |
| Scope | `<name>Scope`, camelCase, with a proper description | `bodyScope` — "Scope to contain body of integration" |
| Notification | `<purpose>EmailNotification` (or similar descriptive camelCase) with description | `successEmailNotification` — "Notify the user for successful completion" |

Description quality bar (verbatim from the standard): "Provide a description your English professor would be proud of."

---

## 4. BIP/OTBI — Customize a Seeded Report

| Artifact | Convention | Example |
|---|---|---|
| Data model folder | `/Shared Folders/Custom/<PILLAR>/<MODULE>/Data Models` — mirror Oracle's standard folder structure and naming | `/Shared Folders/Custom/Financials/Receivables/Data Models` |
| Report folder | `/Shared Folders/Custom/<PILLAR>/<MODULE>` | `/Shared Folders/Custom/Financials/Receivables/` |
| Data model name | `<SEEDED CODE>` — **must remain identical to the seeded data model name** | `AR_INVOICE_DM` |
| Report name | `<SEEDED REPORT NAME>` — **must remain identical to seeded** | `AR_INVOICE_RPT` |
| Layout name | `<RICE Name> Layout <Seq>` | `RGE AR ALL Invoice Layout 01` |
| RTF template name | `<RICE Name> Output` | `RGE AR ALL Invoice Output` |
| ESS job name | `<RICE Name> Report` | `RGE AR ALL Invoice Report` |
| Data model parameter | `XXRUN_P_XXXX` | `XXRUN_P_INVOICE_NUM` |
| Data model column | `XXRUN_XXXX` | `XXRUN_INVOICE_TOTAL` |

Note the key difference from new custom reports: seeded customizations keep the **seeded** data model and report names and live under `/Custom/<PILLAR>/<MODULE>` (no company segment); only layouts, templates, and ESS jobs get RGE naming, and added parameters/columns get the `XXRUN_` prefix.

---

## 5. BIP — New Custom Report

| Artifact | Convention | Example |
|---|---|---|
| Data model folder | `/Shared Folders/Custom/<COMPANY NAME>/<PILLAR>/<MODULE>/Data Models` | `/Shared Folders/Custom/Regal/Financials/Payables/Data Models` |
| Report folder | `/Shared Folders/Custom/<COMPANY NAME>/<PILLAR>/<MODULE>` | `/Shared Folders/Custom/Regal/Financials/Payables` |
| Data set / data model name | `<RICE Code>_DM` | `RGE_AP_ALL_INVOICE_DM` |
| Layout name | `<RICE Name> Layout <Seq>` | `RGE AP ALL Invoice Layout 01` |
| RTF template name | `<RICE Name> Output` | `RGE AR ALL Invoice Output` |
| Report name | `<RICE Name> Report` | `RGE AP ALL Invoice Report` |
| ESS job name | `<RICE Name> Report` (same as report name) | `RGE AP ALL Invoice Report` |
| ESS job short name | `<RICE Code>_REP` | `RGE_AP_ALL_INVOICE_REP` |
| ESS job path | `/<module>/<reportShortName>` | `/payables/RGE_AP_ALL_INVOICE_REP` |
| Data model parameter | `P_XXXX` | `P_INVOICE_DATE_FROM` |

Catalog folder pillar/module segments use Oracle **display names** (`Financials`, `Payables`, `Receivables`, `Human Capital Management`, etc.), not two-letter codes. Open question in v1.0: country subfolders — default no, location lives in the object name's `<Location>` segment.

---

## 6. BIP — Integration Reports

| Artifact | Convention | Example |
|---|---|---|
| Data model folder | `/Shared Folders/Custom/<COMPANY NAME>/Integrations/<System>/Data Models` | `/Shared Folders/Custom/Regal/Integrations/VISTA/Data Models` |
| Report folder | `/Shared Folders/Custom/<COMPANY NAME>/Integrations/<System>` | `/Shared Folders/Custom/Regal/Integrations/VISTA` |
| Everything else | Follows the "New Custom BI Publisher Report" standards above | |

`<System>` is the external system the integration touches (e.g., `VISTA`, `INFINIUM`, `VERTEX`). Reports supporting an OIC integration live here, not in the pillar/module folders.

---

## 7. BIP — Conversion Reports (Pre / Post / Error)

Hackett creates a **temporary** folder for conversion reports. Note: the v1.0 pattern text says `Custom/DC Reports/<Company>/…` but every example uses `Custom/<Company>/DC Reports/…` — follow the examples.

| Artifact | Convention | Example |
|---|---|---|
| Base directory | `Custom/Regal/DC Reports/<Conversion Name>` | `Custom/Regal/DC Reports/AR Customer` |
| Pre-load report dir | `…/<Conversion Name>/PreLoadReports` | `Custom/Regal/DC Reports/AR Customer/PreLoadReports` |
| Pre-load data model | `XXCONV_<MOD>_<OBJECT>_PRE_DM` | `XXCONV_AP_INVOICE_PRE_DM` |
| Pre-load report name | `Data Conv <MOD> <Conversion Name> Pre Load Report` | `Data Conv AP Invoice Pre Load Report` |
| Post-validation dir | `…/<Conversion Name>/PostValidationReps` | `Custom/Regal/DC Reports/AR Customer/PostValidationReps` |
| Post-validation data model | `XXCONV_<MOD>_<OBJECT>_POST_DM` | `XXCONV_AP_INVOICE_POST_DM` |
| Post-validation report name | `Data Conv <MOD> <Conversion Name> Post Validation Report` | `Data Conv AP Invoice Post Validation Report` |
| Error report dir | `…/<Conversion Name>/ErrorReports` | `Custom/Regal/DC Reports/AR Customer/ErrorReports` |
| Error data model | `XXCONV_<MOD>_<OBJECT>_ERR_DM` | `XXCONV_AP_INVOICE_ERR_DM` |
| Error report name | `Data Conv <MOD> <Conversion Name> Error Report` | `Data Conv AP Invoice Error Report` |

(The v1.0 doc's error-report naming row contains a copy-paste of "Post Validation Report" in the pattern cell; the example `Data Conv AP Invoice Error Report` is correct — use "Error Report".)

---

## 8. PaaS Database objects & Regal schemas

**Regal project schemas**: `XXFDL`, `XXERP`, `XXSCM`, `XXHCM` (general schema pattern: `XX<SHORT_CODE>`, e.g., `XXINV`).

All objects derive from `XX_<RICE Code>` (the RICE Code without company prefix collision — examples use `XX_<MODULE>_<LOCATION>_<OBJECT>`):

| Object | Pattern | Example |
|---|---|---|
| Table | `XX_<STANDARD>` | `XX_INV_ALL_ITEMS` |
| View | `XX_<STANDARD>_V` | `XX_INV_ALL_ITEMS_V` |
| Primary key | `XX_<STANDARD>_PK` | `XX_INV_ALL_ITEMS_PK` |
| Index | `XX_<STANDARD>_INX<Seq>` | `XX_INV_ALL_ITEMS_INX1` |
| Trigger | `XX_<STANDARD>_T<Seq>` | `XX_INV_ALL_ITEMS_T1` |
| Sequence | `XX_<STANDARD>_S` | `XX_INV_ALL_ITEMS_S` |
| Function | `XX_<STANDARD>_F` | `XX_INV_ALL_ITEMS_F` |
| Procedure | `XX_<STANDARD>_P` | `XX_INV_ALL_ITEMS_P` |
| Package | `XX_<STANDARD>_PKG` | `XX_INV_ALL_ITEMS_PKG` |

DB packages/procedures carry the same history header block as data models. SQL must be formatted.

---

## 9. VBCS objects

| Object | Convention | Example |
|---|---|---|
| Project | `<Company> <Pillar> <Short Name>` | `RGE HCM Premier` |
| Workspace | `<Company> <Module> <Location> <Short Name>` | `RGE HR ALL Employee Screen – add DFF` |
| Repository / Job / Pipeline / Configuration | **Not defined in v1.0** — ask the user; do not invent | |

---

## 10. History header & comment standards

Mandatory header ("This is very Important. Please make sure to follow this.") for every data model and DB package/procedure — fill in real values:

```
/*************************************************************
** Name: <OBJECT NAME, e.g., RGE_AP_ALL_SUPPLIER_DM>
** Desc:   <one-line description, e.g., AP Supplier Site Data Model>
** Auth:   The Hackett Group
** Date:   MM/DD/YYYY
** Company:  Regal Entertainment Group
**************************
** Change History
**************************
** Bug   Date        Author      Description
** --   --------    -------     --------------------------------
**
****************************************************************/
```

Inline change comments:
- Initial: `Added as part of Project <COMPANY> Implementation – MM/DD/YYYY`
- Azure-tracked: `Added as part of Project <COMPANY> Implementation – AZURE#-1234-MM/DD/YYYY`

SQL formatting is mandatory ("MUST BE Formatted"): uppercase SQL keywords, one column per line in SELECT lists, aligned aliases, indented JOIN/WHERE clauses, meaningful table aliases.

---

## 11. Worked end-to-end example

Task: new custom BIP report — AP open invoices for all locations.

1. RICE identity: Company `RGE`, Pillar `ERP`, Module `AP`, Location `ALL`, Type `RPT`, next seq (say) `004`.
   - RICE ID: `RGE.ERP.AP.ALL.RPT.004`
   - RICE Code: `RGE_ERP_AP_ALL_RPT_OPEN_INV` → naming stem used in BIP artifacts: `RGE_AP_ALL_OPEN_INV` (BIP examples drop the pillar and type from the stem, matching `RGE_AP_ALL_INVOICE_DM`)
   - RICE Name: `RGE AP ALL Open Invoices`
2. Artifacts:
   - Data model: `RGE_AP_ALL_OPEN_INV_DM` in `/Shared Folders/Custom/Regal/Financials/Payables/Data Models`
   - Report: `RGE AP ALL Open Invoices Report` in `/Shared Folders/Custom/Regal/Financials/Payables`
   - Layout: `RGE AP ALL Open Invoices Layout 01`; RTF: `RGE AP ALL Open Invoices Output`
   - ESS job: name `RGE AP ALL Open Invoices Report`, short name `RGE_AP_ALL_OPEN_INV_REP`, path `/payables/RGE_AP_ALL_OPEN_INV_REP`
   - Parameters: `P_AS_OF_DATE`, `P_BUSINESS_UNIT`
3. SQL: leading history header, formatted SQL, `Added as part of Project Regal Implementation – MM/DD/YYYY` comment on the dataset.
4. Deploy via MCP: create any missing folders along the standards path with `catalog_create_folder`, then `report_deploy` to the report folder. Echo the RICE block to the user before deploying.

Note the stem ambiguity in step 1: the standard's BIP examples (`RGE_AP_ALL_INVOICE_DM`) omit pillar and type from the artifact stem even though the RICE Code definition includes them. Follow the BIP examples for BIP artifact names; use the full RICE Code for the RICE inventory entry itself.
