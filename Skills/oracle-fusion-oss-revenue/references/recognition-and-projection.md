# Revenue Recognition & Projection

How OSS revenue gets recognized over time, and how the report represents past (recognized) vs. future (projected) periods. This is the conceptual heart of the waterfall — and the area where Murray's review proposed the deepest structural change.

## Table of contents
1. Two regimes: past = engine-truth, future = projection
2. POLD as engine-truth for past periods
3. Satisfaction events for future projection
4. The combined per-period pattern
5. Measurement models
6. Terminations (Option B)
7. Modifications
8. Catch-up bookings
9. Where the current report differs from the POLD rewrite

---

## 1. Two regimes

Revenue for a POL splits cleanly into two time regimes around "now":
- **Past / already processed** — the rev-rec engine has run and posted actual distributions. *Truth lives in POLD.*
- **Future / not yet processed** — rev-rec hasn't run. The best available signal is the engine's *intended* schedule. *Truth lives in satisfaction events.*

The cleanest model uses POLD for the past and satisfaction events for the future, joined per (POL, period). The current shipped report instead uses a single straight-line proration for *all* buckets (Jay's chosen spec) and uses POLD only for period attribution and the GL segments — see §9 for the difference and why.

---

## 2. POLD as engine-truth for past periods

`VRM_PERF_OBLIGATION_LIN_DISTS` (POLD) is the engine's accounting distribution table: **one row per (POL × period × account_class)**. Each row carries:
- `amount` — entered/transaction currency (T)
- `acctd_amount` — ledger/functional currency (F)
- `original_accounting_date` — the period the revenue belongs to (use for attribution)
- `accounting_date` — the GL date it was booked (often a catch-up date; never attribute by this)
- `code_combination_id`, `ledger_id`, `event_id`, `exchange_rate` — directly on the row

Engine-recognized revenue per (POL, period) in entered currency:
```sql
SELECT perf_obligation_line_id,
       TRUNC(original_accounting_date,'MM') period,
       SUM(amount) recog_entered,
       SUM(acctd_amount) recog_functional
FROM vrm_perf_obligation_lin_dists
WHERE account_class = 'ORA_REV'
GROUP BY perf_obligation_line_id, TRUNC(original_accounting_date,'MM')
```
This reconciles exactly to `POL.entered_cur_recog_rev_amt` (sum over periods). `SUM(acctd_amount)` reconciles to `POL.contr_cur_recog_rev_amt` (contract cur, which equals ledger for most Imagine contracts).

Two big consequences of using POLD:
- **FX is already in the data.** POLD's `acctd_amount` / `exchange_rate` are the engine's actual per-period rates — a POLD-based F column needs no `gl_daily_rates` lookup at all.
- **The XLA traversal collapses.** `company`/`department`/period come from `vpold → gl_code_combinations, gl_ledgers` directly (2 joins) instead of `xdl→xal→xah→glp→gcc→gll` (6 joins).

Filtering POLD to `account_class='ORA_REV'` is cleaner than the original event-type filter `IN ('REV_PERF_OBL_SATISFIED','REV_PERF_OBL_BILLED','REV_INITIAL_PERF')`, which mixed billing events into revenue.

---

## 3. Satisfaction events for future projection

For periods rev-rec hasn't processed yet, project with the engine's schedule from `VRM_POL_SATISFACTION_EVENTS`:
```
projection = (satisfaction_period_proportion / satisfaction_base_proportion) × net_line_amt
```
filtered to `discarded_flag='N'`. This is the *intent* the engine will realize. It's the same ratio the original SQL used for `revenue_amt`, but applied to `net_line_amt` (correct base) rather than `recog_amt` (wrong base — lifetime recognized; see gotchas #5 and #1).

- `satisfaction_period_proportion` = "sbl" (per-event/period proportion, from VPS).
- `satisfaction_base_proportion` = "sbh" (base proportion, from VPO).
- `processed_flag='Y'` marks events already recognized; `discarded_flag='Y'` marks events removed by modification/termination.

For bucket-level reporting you need the **full** satisfaction schedule (all events per POL), not just the latest. The current report's `base_data_se` keeps only the latest event (`rn=1`) — fine for the satisfaction-date display column, insufficient for a true per-period projection.

---

## 4. The combined per-period pattern

The structurally-correct waterfall bucket for (POL, period):
```
LEFT JOIN satisfaction_events ↔ pold_recognized  ON (POL, period)
period_amount = COALESCE(pold.recog_entered, satisfaction_event_projection)
```
- Past periods take the POLD actual.
- Future periods fall back to the satisfaction-event projection.
- **Reversals net automatically** via the SUM (a termination reversal is a negative POLD amount in its period).
- **Modifications drop out** via `discarded_flag='N'`.
- No special-case branching needed.

---

## 5. Measurement models

`vpo.satisfaction_measurement_model` ∈:
- `ORA_MEASURE_PERIOD_SATISFIED` — period/ratable. **All Imagine OSS POLs are this.** revenue_amt = `(sbl/sbh) × base`.
- `ORA_MEASURE_QUANTITY_SATISFIED` — quantity-based. revenue_amt = base directly. Used by FUSION_DOO/FUSION_CONTRACTS, filtered out of this report.
- `ORA_MEASURE_PERCENT_SATISFIED` — percent-based. **No branch in the current CASE** → NULL if encountered. Harmless today (no OSS POLs use it) but brittle; add the branch if touching the logic.

Display mapping: PERIOD→'Period', QUANTITY→'Quantity', PERCENT→'Percent'.

---

## 6. Terminations (Option B)

When a POL is terminated (`removed_flag='Y'` or a discard), the report uses **Option B**:
- **Past periods**: show actual recognized amounts *including* the termination reversal the engine writes — typically a negative bucket in the termination period.
- **Future periods**: zero — discarded satisfaction events naturally don't appear (`discarded_flag='N'` filter).
- A `terminated_flag` column indicates the terminated state.

The active report set filters `vpo.removed_flag='N'`. Termination reversals still surface through POLD for the periods they occurred in, so the net revenue stays correct.

---

## 7. Modifications

A modification creates a new VSD version and may create/discard POLs. Two effects to handle:
- **Version skew** (gotchas #2): the POL still anchors to the *old* VSD version's `document_line_id`. Don't dedup VSD by version on the POL spine, or the modified-contract POLs vanish.
- **Discarded events**: superseded satisfaction events get `discarded_flag='Y'` and naturally fall out of projection.

Modifications are present in Imagine today (`LineSplitsTest04`, `CA000000866S`), so this isn't hypothetical.

---

## 8. Catch-up bookings

86% of Imagine POLD revenue rows are catch-ups: `accounting_date` (when booked) ≠ `original_accounting_date` (when earned). Migrations and backdated activations cause this. Always attribute by `original_accounting_date`. Worst observed: $62,844 belonging to Apr-2020 booked in Apr-2026 — attributing by `accounting_date` would dump six years of revenue into one month. (See gotchas #3.)

---

## 9. Where the current report differs from the POLD rewrite

Murray's review proposed replacing the straight-line bucket proration with the POLD-actual + satisfaction-projection model (§4). **That structural rewrite was declined** in favor of Jay's simpler even-split spec for the buckets (gotchas #4 notes the divergence for modified contracts). What *was* adopted from the review:
- `original_accounting_date` attribution (#8, gotchas #3) ✓
- the product-id bridge (gotchas #1, #6) ✓
- the no-version-dedup POL spine + separate header-TCV dedup (gotchas #2, #8) ✓
- the corrected (T)/(F) currency handling (`currency-tf.md`) ✓
- applying satisfaction ratio to `net_line_amt` not `recog_amt` (gotchas #5) ✓

So the shipped report is a hybrid: straight-line buckets (Jay's spec) on top of the corrected plumbing (Murray's fixes). If a future requirement needs buckets to match exactly what posted to GL for modified/carve-out contracts, the POLD-actual model in §2–4 is the path — it's understood and validated, just not currently wired into the bucket columns.
