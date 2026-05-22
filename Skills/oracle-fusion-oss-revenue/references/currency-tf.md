# Currency Handling — the (T) and (F) Convention

Cross-currency contracts are where the waterfall report went most subtly wrong. ~3,000 cross-currency POLs in Imagine were mislabeled or given wrong functional values. The root cause is that **three different currency concepts get conflated**. Get them straight first; everything else follows.

## Table of contents
1. The three currencies
2. The (T)/(F) column convention
3. The original bugs
4. The correct FX resolution logic
5. At-or-before-date semantics (why it matters)
6. Conversion type via name, never internal id
7. Multi-functional-currency ledgers
8. Worked example (POL 30001)

---

## 1. The three currencies

| Concept | Source column | What it denominates |
|---|---|---|
| **Transaction / entered currency** | `vpo.line_currency_code` | The currency `net_line_amt`, `entered_cur_recog_rev_amt`, `entered_cur_billed_amt` are actually in. **This is (T).** |
| **Contract currency** | `vcc.contract_currency_code` | The currency the contract was struck in. **Informational only.** It is NOT the denomination of the engine amounts and must not be used as an FX source or a display label for the amounts. |
| **Functional currency** | `gl_ledgers.currency_code` (of the document's ledger, via `vss.ledger_id`) | The ledger/reporting currency. **This is the basis for (F).** |

For a US-parent customer the functional/reporting currency is typically USD, but **do not assume USD** — Imagine has USD, INR, AUD, EUR, and GBP ledgers. The functional currency must come from the document's actual ledger.

---

## 2. The (T)/(F) column convention

- `_t` suffix = **transaction** currency value (entered). Native engine amounts: `net_line_tcv_t = net_line_amt`, `recognized_revenue_t = recog_amt`, etc. No conversion.
- `_f` suffix = **functional** currency value = `T × conversion_rate_tf`.
- `conversion_rate_tf` = the rate actually used to go transaction → functional.
- `functional_currency` column = `gl_ledgers.currency_code`.
- `currency` (display label for the T amounts) = `line_currency_code`.

When **transaction = functional** (the common case), there is no conversion:
```sql
CASE WHEN transaction_currency = functional_currency THEN TO_CHAR(SYSDATE,'MM/DD/YYYY')  -- conversion_date
     ELSE TO_CHAR(fx_conversion_date,'MM/DD/YYYY') END
CASE WHEN transaction_currency = functional_currency THEN 'N/A'                          -- conversion_type
     WHEN period_end_rate IS NOT NULL THEN 'Period End'
     WHEN corporate_rate  IS NOT NULL THEN 'Corporate' END
CASE WHEN transaction_currency = functional_currency THEN 1                              -- conversion_rate_tf
     ELSE NVL(period_end_rate, corporate_rate) END
```

So same-currency lines get rate 1, type `'N/A'`, date = today; cross-currency lines get the resolved FX.

---

## 3. The original bugs (all fixed)

1. **Wrong-currency FX source.** Used `vcc.contract_currency_code` to source the rate, but multiplied that rate against `net_line_amt`, which is in *entered* (`line_currency_code`) currency. For 1,911 EUR-entered / GBP-contract POLs (and HKD/SGD/CAD populations) this produced wrong-currency labels and wrong F values.
2. **Hardcoded opaque rate-type id** `'300000002367347'`. It happens to be 'Period End' in this tenant. Non-portable; replace with a `user_conversion_type` name join.
3. **No fallback when the exact-date rate isn't loaded.** For `:p_period='APR-26'`, Imagine's Period End rates only ran through March 2026, and Corporate rates for EUR/INR/NZD/OMR only through mid-April. Exact-date matching recovered only ~10 of 3,024 cross-currency POLs.

---

## 4. The correct FX resolution logic

Two CTEs:

**`fx_rate`** — pivot rates by readable type, for *all* currency pairs (don't hardcode `to_currency`):
```sql
fx_rate AS (
  SELECT r.from_currency, r.to_currency, r.conversion_date,
         MAX(CASE WHEN dct.user_conversion_type='Period End' THEN r.conversion_rate END) period_end_rate,
         MAX(CASE WHEN dct.user_conversion_type='Corporate'  THEN r.conversion_rate END) corporate_rate
  FROM gl_daily_rates r, gl_daily_conversion_types dct
  WHERE dct.conversion_type = r.conversion_type
    AND dct.user_conversion_type IN ('Period End','Corporate')
  GROUP BY r.from_currency, r.to_currency, r.conversion_date )
```

**`pol_fx`** — resolve one rate per cross-currency source line, latest at-or-before the target date:
```sql
pol_fx AS (
  SELECT document_line_id, transaction_currency, functional_currency,
         fx_conversion_date, period_end_rate, corporate_rate
  FROM ( SELECT vsd.document_line_id,
                vpo.line_currency_code transaction_currency,
                sd.functional_currency,
                fr.conversion_date fx_conversion_date,
                fr.period_end_rate, fr.corporate_rate,
                ROW_NUMBER() OVER (PARTITION BY vsd.document_line_id
                                   ORDER BY fr.conversion_date DESC) rn
         FROM vrm_source_doc_lines vsd, vrm_perf_obligation_lines vpo,
              src_docs sd, period_der pd, fx_rate fr, pdt
         WHERE vsd.document_type_code='FUSION_OSS'
           AND vpo.document_line_id = vsd.document_line_id
           AND vpo.removed_flag='N'
           AND sd.document_id = vsd.document_id
           AND vpo.line_currency_code <> sd.functional_currency       -- cross-currency only
           AND pd.document_line_id (+) = vsd.document_line_id
           AND fr.from_currency = vpo.line_currency_code               -- FROM transaction
           AND fr.to_currency   = sd.functional_currency               -- TO functional
           AND fr.conversion_date <= NVL(pd.bill_date, LAST_DAY(pdt.p_date))   -- at-or-before
           AND NVL(fr.period_end_rate, fr.corporate_rate) IS NOT NULL )
  WHERE rn = 1 )
```

Downstream: same-currency lines have no `pol_fx` row → treated as rate 1 / 'N/A'. Cross-currency lines use `NVL(period_end_rate, corporate_rate)` (Period End preferred, Corporate fallback).

---

## 5. At-or-before-date semantics (why it matters)

The target date per line is the last billing date if billed, else the period end:
```sql
fr.conversion_date <= NVL(pd.bill_date, LAST_DAY(pdt.p_date))
```
combined with `ROW_NUMBER ... ORDER BY conversion_date DESC = 1` → "the most recent rate on or before the target date." This is essential because:
- Rates aren't loaded for weekends/holidays.
- Future-dated periods have no exact rate yet.

Exact-date matching recovered ~10 of 3,024 cross-currency POLs; at-or-before recovered ~100%.

---

## 6. Conversion type via name, never internal id

Join `GL_DAILY_CONVERSION_TYPES` and filter on `user_conversion_type IN ('Period End','Corporate')`. Period End is the right rate type for revenue reporting (the original developer's intent was correct; only the opaque hardcoded id was wrong). Never hardcode the numeric `conversion_type` id — it differs per tenant.

---

## 7. Multi-functional-currency ledgers

Because the `to_currency` is whatever the document's ledger uses, the lookup naturally supports a POL booked to a USD ledger getting a transaction→USD rate, an INR-ledger POL getting transaction→INR, etc. The earlier hardcoded `to_currency='USD'` broke every non-USD ledger. For a future non-USD-parent tenant nothing needs changing in `fx_rate`/`pol_fx`; only a *reporting*-currency override (if the business wants everything in one currency) would touch the functional source.

---

## 8. Worked example — POL 30001

- Contract currency: GBP. Transaction currency: USD. Ledger (functional): USD.
- **Old (buggy):** labeled GBP, sourced a GBP rate (1.3497), multiplied an already-USD `net_line_amt` → **$6.2M** (wrong: double-applied an FX to a USD amount and mislabeled it).
- **Correct:** transaction = functional = USD → no conversion, rate 1, type 'N/A' → **$4.6M**, labeled USD.

The lesson: always check `line_currency_code` (T) against `gl_ledgers.currency_code` (F) first. If they match, do nothing. The contract currency is a distraction.
