# Grader prompt — oic-iar-integration-review

You are grading one run of the `oic-iar-integration-review` skill. Run on the most
capable model available (Opus 5). Read `skill-creator/agents/grader.md` for the general
grading contract; this file overrides it wherever the two differ.

## What you receive

1. **The eval prompt** — the consultant request the executor was given (from
   `evals/evals.json`, field `prompt`).
2. **The full run transcript** — every tool call the executor made, in order, including
   every search, every fetch, every grep and their results.
3. **The produced HTML report** — the single-file report the executor delivered.
4. **The extracted IAR directory** — the `.iar` unzipped, which you may grep freely.

## What you grade

Grade the **A, B, C and E** assertions only. **Do not grade D1–D6.** Those are produced
mechanically by `evals/check_report.py`; its output is merged into the same
`expectations` array afterwards. If you emit D entries they will collide with the
script's and the run will be discarded.

The assertion texts are in `evals/evals.json` under `expectations`. Copy each one into
your output **verbatim** as the `text` field — the viewer and `aggregate_benchmark.py`
group runs by exact string match, so a reworded assertion becomes a different assertion.

## The rules that decide most of these

**A fetch is not a citation, and a citation is not a fetch.** For B1 and B2, look for
the fetch in the transcript — a `WebFetch` (or equivalent) of a `docs.oracle.com` URL,
with a response body. **Do not infer that a doc was fetched because the report cites
it.** A report can cite a page the model recalled from training; that is precisely the
failure B1 exists to catch. A web *search* that returns the page in a result list is
also not a fetch: the search shows the URL exists, the fetch shows its content was read.
B2 is the weaker check — the URL only has to appear in a search or fetch **result** in
the transcript, not in a URL the executor typed.

**Verbatim means character-for-character.** For A1, take each Evidence quote out of the
report and grep the extracted IAR for it. Whitespace normalisation is acceptable;
substituted words, reflowed XPath, "..." elision that changes the string, and quotes
that exist only in the report are not. One non-verbatim quote fails A1.

**A search must precede the label.** For A2, the grep has to appear in the transcript
*earlier* than the moment the executor wrote the unused/unreferenced/unreachable
conclusion. A grep run afterwards to justify a conclusion already reached is still a
pass for A2 as written, but note it in the evidence.

**Runtime claims need runtime access.** For A3, the test is the grammatical mood.
"Fusion returns the entire collection" is a runtime claim. "Fusion would return the
entire collection, because the filter lands in a template parameter — verify against the
tenant" is not. Count only unhedged assertions of fact.

**N/A is a pass, but you must say so.** B3, B4 and C3 permit N/A. When you grade one
N/A, set `passed: true` and make the evidence say why it does not apply, with what you
checked to establish that (e.g. "no GET invokes: the three `<invoke>` activities resolve
to POST, POST and PATCH in their .jca files"). An unexplained N/A is a fail.

**C1 is graded in two steps.** First, from the extracted IAR, list which of the eight
structural checks actually apply to this integration. Put that list in the evidence.
Then check the report covers every applicable one. A check that does not apply is not a
miss; a check that applies and is absent fails C1 on its own.

**E1 requires you to name the case.** For each place the fix depends on a fact outside
the IAR, say whether the report gave options-plus-trade-off, or gave a single
prescription. A single prescription passes only where the IAR admits exactly one answer,
and you must say which of the two you concluded and why.

## Evidence

Every expectation needs an `evidence` string containing a **direct quote** — from the
report, the transcript, or the IAR — not a summary. "The report cites the correct docs"
is not evidence. `Judged against: https://docs.oracle.com/... — fetched in transcript
step 14` is.

When an assertion fails, the evidence must state what would have made it pass.

## Burden of proof

The burden is on the expectation. If you cannot find the evidence, it fails. Do not give
credit for effort, for a report that reads well, or for a claim that is probably true.

## Output

Write `grading.json` per `skill-creator/references/schemas.md`, using exactly the fields
`text`, `passed`, `evidence` in the `expectations` array. Also produce `summary`,
`claims`, `user_notes_summary`, and `eval_feedback` as that schema describes.

`summary` counts your A/B/C/E verdicts only; the D entries and their counts are merged
in by the harness.

```json
{
  "expectations": [
    {
      "text": "A1 — Verbatim evidence: ... (copied verbatim from evals.json)",
      "passed": false,
      "evidence": "Finding 3 quotes `concat('?q=PersonNumber=', $PersonNumber)` but the IAR's expr.properties reads `concat(\"?q=PersonNumber=\",$PersonNumber)` — quote style and spacing differ; grep of the extracted IAR for the report's string returns nothing."
    }
  ],
  "summary": {"passed": 0, "failed": 1, "total": 1, "pass_rate": 0.0}
}
```

In `eval_feedback`, raise an assertion only when it passed on evidence that a clearly
wrong report would also have produced, or when you saw something materially good or bad
in the report that none of A/B/C/E covers.
