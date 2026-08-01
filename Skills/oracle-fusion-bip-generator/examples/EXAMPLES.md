# Examples

Worked examples showing complete BIP report artifacts. Read these to ground the patterns documented in `references/`.

**Important:** these are illustrative — they're written to be syntactically correct against standard Fusion DDL, but they have not been validated against a specific live pod. Before using them in real client work, run the SQL through `hackett-fusion:execute_sql` to verify column names, data types, and row counts against the target environment.

## Index

| Example | Demonstrates |
|---------|--------------|
| `ar-invoice-aging.xdm` + `.rtf` | Single dataset with cascading LOVs (BU → Customer), date-range parameters, aging buckets via CASE expression, Hackett-branded RTF with grouped totals. |
| `gl-trial-balance.xdm` | Minimal data model with a single ledger + period parameter, aggregated SQL with GROUP BY, simple flat output structure. |

## Adding new examples

When a real report is built through this skill and validated end-to-end against a pod, consider copying the generic version (with client-specific values redacted) into this folder as a future reference. Useful examples are:
- The first known case of a new pattern (e.g., first multi-org report, first cascading-3-deep LOV, first as-of-date HCM report).
- Reports that exposed an edge case worth documenting.
- Reports that ended up needing significant manual repair — those reveal gaps in the skill's coverage.
