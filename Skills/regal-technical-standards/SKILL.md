---
name: regal-technical-standards
description: "REGAL PROJECT ONLY. Enforces Regal Entertainment Group's (RGE) official Oracle Cloud technical standards - RICE IDs, object naming, BIP catalog folder paths, mandatory data model history headers, ESS job names, OIC component naming, PaaS database object naming (XXFDL/XXERP/XXSCM/XXHCM), and VBCS naming - on every technical object created or reviewed for the Regal implementation. Trigger whenever work touches a Regal Fusion environment (ichqjb-* pods) or the Hackett Fusion MCP server and involves creating, naming, deploying, or reviewing BIP reports, data models, catalog folders, OIC integrations/connections/lookups, RICE inventory entries, custom database objects, ESS jobs, conversion pre/post/error reports, service accounts, or VBCS apps. Also trigger for 'what should this be named', 'where does this go in the catalog', 'give me a RICE ID', or validating existing names. Combine with regal-report-builder: that skill builds the report; THIS skill dictates names and paths."
---

# Regal Technical Standards (RGE Oracle Cloud Implementation)

Authority: *Oracle Cloud Applications Implementation — Technical Standards and Best Practices*, v1.0, Fredy Ramirez, 7/10/2026 (Hackett/Regal project document). This skill applies **only to the Regal project**. Do not apply these conventions to other clients.

## Why this exists

Every technical object on the Regal project — reports, data models, integrations, DB objects — must carry a standards-compliant name, live in the standards-compliant catalog folder, and (for data models) carry the mandatory history header. When building objects via the Hackett Fusion MCP server (`report_create`, `report_deploy`, `deploy_report_package`, `upload_data_model`, `upload_report`, `catalog_create_folder`), derive every name and path from this skill **before** calling the tool — never invent ad-hoc names.

## Workflow: naming any new object

1. **Classify the object**: report (seeded customization / new custom / integration report / conversion report), OIC component, DB object, ESS job, service account, or VBCS object.
2. **Derive the RICE identity first** (Company, Pillar, Module, Location, Type). Everything else derives from it. See "RICE Core" below.
3. **Look up the exact pattern** in `references/standards.md` for that object type. Read that file for anything beyond the quick patterns below — it contains the full tables verbatim-faithful to the source doc.
4. **Apply the pattern, then self-check**: pillar/module/location codes are from the allowed lists, case matches (UPPER for codes, Mixed Case for display names), and the name would reconcile with the RICE inventory.
5. **For data models: always inject the history header** (see below). This is called out in the source doc as "very Important."
6. **For SQL: always format it.** The standard says SQL "MUST BE Formatted" — uppercase keywords, aligned columns, one column per line in SELECT lists, indented joins/predicates.

## RICE Core (memorize this — everything derives from it)

Segments:

- **Company**: `RGE` (Regal), `HKT` (Hackett)
- **Pillar**: `ERP`, `SCM`, `HCM`, `EPM`
- **Module**: `GL, AP, AR, CM, FA, PO, INV, OM, PAY, BEN, FCC, ARCS` (HR for HCM core, per examples)
- **Location**: `ALL`, or specific `US, UK, PL, BL, SL`, or special `CCI`
- **Type**: `RPT` (report), `INT` (integration), `CNV` (conversion), `EXT` (extension)

Three renderings of the same identity:

| Form | Pattern | Example |
|---|---|---|
| RICE ID | `<Company>.<Pillar>.<Module>.<Location>.<Type>.<Seq>` | `RGE.ERP.AP.ALL.INT.001` · `RGE.SCM.INV.ALL.RPT.002` |
| RICE Code | `<Company>_<Pillar>_<Module>_<Location>_<Type>_<Code Name>` (UPPER) | `RGE_SCM_INV_ALL_RPT_INV_BAL` |
| RICE Name | `<Company> <Module> <Location> <Short Name>` (Mixed Case, no pillar) | `RGE INV ALL Inventory Balance` |

Note the asymmetry: RICE **Name** drops the pillar; RICE **ID/Code** include it. OIC integration names and report/layout/ESS display names must match the RICE Name form.

## Quick patterns — BIP (most common case)

**New custom BIP report** (full detail + seeded/integration/conversion variants in `references/standards.md`):

| Artifact | Pattern | Example |
|---|---|---|
| Data model folder | `/Shared Folders/Custom/<Company Name>/<Pillar>/<Module>/Data Models` | `/Shared Folders/Custom/Regal/Financials/Payables/Data Models` |
| Report folder | `/Shared Folders/Custom/<Company Name>/<Pillar>/<Module>` | `/Shared Folders/Custom/Regal/Financials/Payables` |
| Data model / data set name | `<RICE Code>_DM` | `RGE_AP_ALL_INVOICE_DM` |
| Layout name | `<RICE Name> Layout <Seq>` | `RGE AP ALL Invoice Layout 01` |
| RTF template name | `<RICE Name> Output` | `RGE AP ALL Invoice Output` |
| Report name | `<RICE Name> Report` | `RGE AP ALL Invoice Report` |
| ESS job name | `<RICE Name> Report` | `RGE AP ALL Invoice Report` |
| ESS job short name | `<RICE Code>_REP` | `RGE_AP_ALL_INVOICE_REP` |
| ESS job path | `/<module>/<reportShortName>` | |
| Parameter names | `P_XXXX` (new custom) · `XXRUN_P_XXXX` (seeded customization) | `P_INVOICE_DATE_FROM` |

Folder pillar/module names in catalog paths use Oracle's **display** names (Financials, Receivables, Payables…), not the two-letter codes. Note: on the report folder for data models, the `Data Models` subfolder is part of the path.

**Mandatory data-model history header** — inject at the top of every data model (and PaaS DB package/procedure):

```
/*************************************************************
** Name: RGE_AP_ALL_SUPPLIER_DM
** Desc:   AP Supplier Site Data Model
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

Data-model comment on any change: `Added as part of Project <COMPANY> Implementation – MM/DD/YYYY` (append `AZURE#-1234-` before the date when tied to an Azure DevOps item).

## Quick patterns — OIC

| Component | Pattern | Example |
|---|---|---|
| Project | `<Company> <Pillar>` (`<CLIENT>` if common) | `RGE ERP` |
| Connection | `<Company> <Target System> <Type: REST/SOAP/FTP/Database> <Env>` — env suffix only when one OIC serves multiple pods | `RGE ERP Cloud REST DEV2` |
| Integration | `<Company> <Module> <Location> <Operation> [<Frequency>] <Inbound/Outbound>` — must match RICE Name | `RGE INV CCI Create Items Outbound` |
| Lookup | `<COMPANY>_<MODULE>_<OBJECT>_LKP` (UPPER; `COMMON` if shared) | `RGE_AP_PAYMENTTERM_LKP` |
| JS Function | `<MOD>_<ACTION>_FNC` (UPPER; `CMN` if common) | `AP_VENDOR_LOOKUP_FNC` |
| Agent Group | `<COMPANY>_<SYSTEM>_AG` | `RGE_INFINIUM_AG` |
| Variables | globals `g_name`, locals `l_name` (Mixed Case) | `g_fileName`, `l_fileName` |
| Endpoint | `<operation>_IN/FROM/TO_<AdapterName>` | `writeFile_TO_SFTP` |
| Scope / Notification | camelCase descriptive + suffix | `bodyScope`, `successEmailNotification` |

Every connection, endpoint, scope, and notification gets a real English description ("a description your English professor would be proud of") — never blank, never a repeat of the name.

## Quick patterns — PaaS Database

Regal schemas: **XXFDL, XXERP, XXSCM, XXHCM**. Objects use `XX_<RICE Code>` + suffix: table (none), view `_V`, PK `_PK`, index `_INX<n>`, trigger `_T<n>`, sequence `_S`, function `_F`, procedure `_P`, package `_PKG`. Example family: `XX_INV_ALL_ITEMS`, `XX_INV_ALL_ITEMS_V`, `XX_INV_ALL_ITEMS_PKG`. Packages/procedures carry the same history header as data models.

## MCP server integration rules

When using the Hackett Fusion MCP server for Regal:

- `report_create` / `deploy_report_package`: data model name = `<RICE Code>_DM`; report display name = `<RICE Name> Report`; SQL formatted; history header as the leading comment of the primary dataset SQL.
- `report_deploy` / `catalog_create_folder`: deploy target must be the standards folder (`/Shared Folders/Custom/Regal/<Pillar>/<Module>[/Data Models]` for new custom; conversion reports go under the `DC Reports` structure — see references). Create missing folders along the standards path rather than deploying to an ad-hoc location.
- Parameters: `P_XXXX` on new custom, `XXRUN_P_XXXX` when customizing a seeded model. LOV names should follow the same `P_` stem.
- Before deploying, echo the derived RICE ID / Code / Name and target path to the user in one short block so naming can be caught before it lands in the catalog.

## Known open items in the source standard (flag, don't guess)

- The standard leaves "sub-folder by country?" as an open question for custom and integration report folders — default to **no country subfolder** (use the `<Location>` segment in names instead) unless the user says otherwise.
- Conversion report base path appears both as `Custom/DC Reports/<Company>/…` (pattern) and `Custom/<Company>/DC Reports/…` (all examples). Follow the **examples**: `Custom/Regal/DC Reports/<Conversion Name>/…`. Note it to the user the first time it matters.
- VBCS table defines Project/Workspace patterns only; Repository, Job, Pipeline, Configuration are blank in v1.0 — ask rather than invent.

For anything not covered by the quick patterns above (seeded-report customization details, integration report folders, conversion pre/post/error report naming, service accounts, VBCS), read `references/standards.md`.
