# oracle-fusion-bip-generator

A Claude skill for building Oracle Fusion BI Publisher (BIP) reports end-to-end. Converts a natural-language requirement into validated Oracle-style SQL, a complete `.xdm` data model with parameters and cascading LOVs, a branded RTF template, and (optionally) a deployed BIP catalog object — all gated on user confirmation at each phase.

## What this skill does

Given a report requirement like "show me AR invoices aged by due date, with multi-BU filter and aging buckets," the skill:

1. **Drafts Oracle-style SQL** following strict house conventions (WHERE-clause joins, `(+)` outer join notation, no ANSI syntax).
2. **Validates the SQL live** against the connected Fusion environment via the `hackett-fusion` MCP server. No file is delivered until validation passes.
3. **Generates a BIP Data Model (`.xdm`)** with the requested parameters (text, date, single-select menu, multi-select menu) and any cascading LOV relationships.
4. **Generates a branded RTF template** matching either a user-supplied design (prose, file, image, or brand reference) or Hackett brand defaults.
5. **Optionally deploys** the bundle to the live BIP catalog via SOAP/REST (Phase 4, opt-in only).

## Requirements

- A Claude environment that supports user skills (claude.ai consumer interface, or Claude Code with skill support).
- The `hackett-fusion` MCP server connected and configured with credentials for the target Fusion pod(s).
- Optional: the `hackett-brand-guidelines` skill installed for Hackett-branded RTF defaults.
- Optional: `libreoffice` or `pandoc` available locally if RTF generation uses the docx-first conversion path.

## Installation

See `INSTALL.md` for environment-specific installation instructions (claude.ai web/mobile, Claude Code, packaging as `.skill` file).

## Structure

```
oracle-fusion-bip-generator/
├── SKILL.md                              # Main entry — process + triggers + agent rules
├── README.md                             # This file
├── INSTALL.md                            # Installation guide
├── references/
│   ├── oracle-sql-conventions.md         # SQL standards and common patterns
│   ├── xdm-structure.md                  # XDM XML format reference
│   ├── rtf-syntax.md                     # BIP RTF tag cookbook + generation approaches
│   ├── common-lov-sources.md             # Catalog of go-to LOV queries by domain
│   └── catalog-deployment.md             # Phase 4 MCP tool signatures + SOAP/REST payloads
├── templates/
│   ├── data-model.xdm                    # Starter XDM skeleton
│   ├── rtf-base-hackett.rtf              # Hackett-branded RTF starter
│   └── readme.md                         # Companion README template
└── examples/
    ├── EXAMPLES.md                       # Index of worked examples
    ├── ar-invoice-aging.xdm              # Single dataset + cascading LOV + multi-select + aging buckets
    ├── ar-invoice-aging.rtf              # Matching Hackett-branded RTF
    └── gl-trial-balance.xdm              # Minimal data model with cascading LOV
```

## How it triggers

The skill auto-loads when Claude detects any of these in user input:
- "BIP", "BI Publisher", "Publisher report"
- ".xdm", ".rtf", ".xdo"
- "Fusion report", "Oracle report", "data model"
- SQL requests referencing `FUSION.*` tables in a reporting context
- Phrases like "build me a report," "write a query for Fusion," "create a data model," "make an RTF template"

The full trigger logic is in `SKILL.md` frontmatter.

## Companion MCP server

Phase 4 (catalog deployment) uses five tools on the `hackett-fusion` MCP server:

- `upload_data_model` — package raw XDM into a `.xdmz` and upload
- `upload_report` — package the `.xdo` descriptor + embedded RTF into a `.xdoz` and upload
- `catalog_object_exists` — pre-flight check / post-flight verify
- `catalog_delete_object` — rollback / overwrite support
- `catalog_create_folder` — create parent folders as needed

Tool signatures and underlying SOAP transport are documented in `references/catalog-deployment.md`. Phases 1-3 of the skill work without these tools — they only require `execute_sql`, `run_bip_report`, and `identify_environment` from the base MCP server.

## Versioning

This skill follows semantic versioning at the skill level. Generated report artifacts are versioned independently per-report under `/mnt/user-data/outputs/{report_short_name}/v{N}/`.

## Contributing

When the skill is used to build a real report and validated against a pod, consider contributing back:
- A redacted copy of the worked example to `examples/`.
- Documentation of new LOV sources discovered to `references/common-lov-sources.md`.
- Edge cases or pattern gaps to a CHANGELOG or issues list.

## License

Internal — Hackett Group.
