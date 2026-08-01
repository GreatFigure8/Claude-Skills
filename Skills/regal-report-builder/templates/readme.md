# {{REPORT_TITLE}}

**Short name:** `{{report_short_name}}`
**Version:** v{{N}}
**Generated:** {{TIMESTAMP}}
**Environment validated against:** {{ENV_FINGERPRINT}}

## Purpose

{{ONE_PARAGRAPH_DESCRIPTION}}

## Grain

One row per {{GRAIN_DESCRIPTION}}.

## Data source

**Name:** `{{DATA_SOURCE_REF}}`
**Type:** {{DATA_SOURCE_TYPE}}  (e.g., ApplicationDB_FSCM = Financials/SCM, ApplicationDB_HCM = Human Capital)

## Parameters

| Name | Type | Label | Default | Required | LOV / Notes |
|------|------|-------|---------|----------|-------------|
| `{{param_1}}` | {{type}} | {{label}} | {{default}} | {{Y/N}} | {{LOV name or "—"}} |
| `{{param_2}}` | {{type}} | {{label}} | {{default}} | {{Y/N}} | {{LOV name or "—"}} |

## LOV Sources

| LOV Name | Backing Query | Cascade From | Source Table(s) |
|----------|---------------|--------------|-----------------|
| `{{LOV_1}}` | {{purpose}} | — | {{source_tables}} |
| `{{LOV_2}}` | {{purpose}} | `{{parent_param}}` | {{source_tables}} |

## Cascade Map

{{If no cascades, write "No cascading LOVs in this data model."}}

```
{{parent_param}}  ──▶  {{child_param}}  ──▶  {{grandchild_param}}
```

Behavior: changing `{{parent_param}}` refreshes the `{{child_param}}` LOV list. {{Document depth-2+ cascades explicitly.}}

## Output Structure

Root group: `{{ROOT_GROUP_NAME}}`
Row tag: `{{ROW_GROUP_NAME}}`

| Element Name (XML) | SQL Alias | Data Type |
|--------------------|-----------|-----------|
| `{{ELEMENT_1}}` | `{{sql_alias_1}}` | {{type}} |
| `{{ELEMENT_2}}` | `{{sql_alias_2}}` | {{type}} |

## Sample API Invocation (BIP `runReport`)

```xml
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                  xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService">
  <soapenv:Body>
    <pub:runReport>
      <pub:reportRequest>
        <pub:reportAbsolutePath>{{CATALOG_PATH}}/{{report_short_name}}.xdo</pub:reportAbsolutePath>
        <pub:attributeFormat>pdf</pub:attributeFormat>
        <pub:attributeLocale>en_US</pub:attributeLocale>
        <pub:attributeTemplate>Default RTF</pub:attributeTemplate>
        <pub:byPassCache>true</pub:byPassCache>
        <pub:parameterNameValues>
          <pub:item>
            <pub:name>{{param_1}}</pub:name>
            <pub:values>
              <pub:item>{{sample_value_1}}</pub:item>
            </pub:values>
          </pub:item>
        </pub:parameterNameValues>
      </pub:reportRequest>
      <pub:userID>{user}</pub:userID>
      <pub:password>{password}</pub:password>
    </pub:runReport>
  </soapenv:Body>
</soapenv:Envelope>
```

## Source SQL (Main Dataset)

```sql
{{MAIN_SQL_QUERY}}
```

## Branding

{{Note which brand was applied to the RTF template:
- "Hackett default brand standards (navy/gold)"
- "Moss & Associates brand (forest green / warm gold / cream)"
- "Ochsner Health brand (navy / blue / gold)"
- "Custom brand: {{describe}}"
- "Image-based: layout interpreted from user-provided screenshot. Approximate spacing/fonts; refine in Word as needed."}}

## Validation Notes

- SQL validated against `{{ENV_FINGERPRINT}}` on {{TIMESTAMP}}.
- Row count at validation time: {{N}} rows.
- Grain verified: {{COUNT(*)}} total rows, {{COUNT(DISTINCT grain_key)}} distinct on grain key.
- All LOV queries validated independently.

## Deployment

{{If deployed:
- Catalog path: {{CATALOG_PATH}}
- Data model object: {{DM_PATH}}
- Report object: {{REPORT_PATH}}
- Smoke test result: {{PASS/FAIL}}
- See {{report_short_name}}_deployment.md for full receipt.

If not deployed:
- "Not yet uploaded to BIP catalog. To deploy: open conversation with the oracle-fusion-bip-generator skill and request Phase 4 upload."}}

## Change Log

- **v{{N}}** ({{TIMESTAMP}}) — {{description of changes from prior version, or "Initial version."}}
