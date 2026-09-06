#!/usr/bin/env python3
"""Runtime-claim / hedge checker for a finished report (rubric A3).

Usage:
    python3 scripts/check_claims.py <report.html>

Reading an IAR tells you what an integration *would* do. It never tells you
what it *has* done. Unless the session actually opened the activity stream or
called the tenant, every sentence asserting observed behaviour — "this works
today", "Fusion has been consistent about that", "which is why nobody has
noticed" — is a claim with nothing behind it. Iteration-2 grading failed A3 on
exactly four such sentences in one report, under a handover framing that pulls
hard toward reassurance.

This flags the constructions mechanically. A sentence is a FAIL if it matches a
banned construction and carries no hedge in that same sentence: a blanket
disclaimer at the top of the report does not hedge the sentences below it,
because the reader reads the sentence, not the preamble.

It also flags mentions of the review process itself. The report is a
deliverable, not a work log: it should never name this skill's scripts,
working files, or SKILL.md, and should never narrate that a check or a skill
was used. Iteration-3 grading failed a report that named check_quotes.py and
work/checks.txt nine times in client-facing prose. No hedge rescues a tooling
mention — the fix is to delete it, not to qualify it.

<pre> blocks are skipped — Evidence is verbatim IAR text, checked by the quote
checker, and the file is allowed to say whatever it says.

Exit codes: 0 = clean (hedged runtime-claim matches are printed as notes),
1 = at least one unhedged runtime claim or one tooling/process mention,
2 = bad usage.
"""

from __future__ import annotations

import html
import re
import sys
from pathlib import Path

MAX_REPORTED = 40
MIN_SENTENCE_CHARS = 8
SENTENCE_MAX = 200

# Constructions that assert observed runtime behaviour, or reassure about it.
BANNED = [
    ("works-today", r"\b(?:this|it|that|which)\s+(?:currently\s+|still\s+)?works\b"),
    ("works-today", r"\bworks\s+(?:today|fine|correctly|as expected|in production)\b"),
    ("works-today", r"\bruns\s+(?:fine|cleanly|without\s+(?:error|issue|incident))\b"),
    ("unnoticed", r"\b(?:has|have|had)\s+(?:not|never)\s+been\s+"
                  r"(?:noticed|reported|hit|seen|an\s+issue|a\s+problem)\b"),
    ("unnoticed", r"\b(?:nobody|no\s+one|nothing)\s+has\s+"
                  r"(?:noticed|complained|reported|hit|seen)\b"),
    ("unnoticed", r"\bwhy\s+(?:it|this|that|nobody|no\s+one)\s+"
                  r"(?:still\s+)?(?:works|has\s+not|hasn't|never|noticed)\b"),
    ("observed-history", r"\bhas\s+been\s+(?:consistent|reliable|stable|returning)\b"),
    ("observed-history", r"\bhas\s+been\s+running\s+(?:fine|cleanly|without|for)\b"),
    ("observed-history", r"\b(?:always|never)\s+(?:returns|fails|fires|happens|has)\b"),
    ("observed-history", r"\bin\s+practice,?\s+(?:this|it|the|Fusion|Oracle)\b"),
    ("present-tense-runtime", r"\bcurrently\s+(?:returns|works|succeeds|passes|fails)\b"),
    ("present-tense-runtime", r"\bthe\s+common\s+case\s+today\b"),
    ("reassurance", r"\b(?:rest\s+assured|nothing\s+to\s+worry\s+about|"
                    r"no\s+cause\s+for\s+concern|perfectly\s+fine|entirely\s+safe)\b"),
]

# A hedge only rescues a sentence if it names the verification, in that same
# sentence. "it is an assumption" and "would" are deliberately NOT hedges: the
# grader failed a sentence that conceded an assumption and still asserted the
# behaviour. This errs toward flagging — a note you dismiss costs a second.
HEDGES = [
    r"\bverif(?:y|ied|ication|iable)\b", r"\bunverified\b",
    r"\bconfirm(?:ed|ation)?\b", r"\bnot\s+observed\b", r"\buntested\b",
    r"\bcannot\s+be\s+(?:confirmed|checked|known)\b", r"\bneeds?\s+checking\b",
    r"\bno\s+instance\s+data\b", r"\btest\s+pod\b", r"\bactivity\s+stream\b",
]

BANNED_RE = [(label, re.compile(pattern, re.I)) for label, pattern in BANNED]
HEDGE_RE = re.compile("|".join(HEDGES), re.I)

# The report is a deliverable, not a work log — it never names this skill, its
# scripts, its working files, or narrates the review process. No hedge rescues
# these; a mention is a FAIL outright. "work/" only needs a leading boundary —
# the trailing slash already distinguishes it from "workforce" etc.
TOOLING_TOKENS = [
    ("check_quotes.py", re.compile(r"\bcheck_quotes\.py\b", re.I)),
    ("check_claims.py", re.compile(r"\bcheck_claims\.py\b", re.I)),
    ("check_report.py", re.compile(r"\bcheck_report\.py\b", re.I)),
    ("checks.txt", re.compile(r"\bchecks\.txt\b", re.I)),
    ("work/", re.compile(r"\bwork/", re.I)),
    ("SKILL.md", re.compile(r"\bSKILL\.md\b", re.I)),
    ("skill", re.compile(r"\bskill\b", re.I)),
]
TOOLING_CONTEXT_CHARS = 45


def tooling_mentions(text: str) -> list[tuple[str, str]]:
    """(token, context-snippet) for every banned-tooling-token hit in visible text."""
    hits: list[tuple[str, str]] = []
    for label, pattern in TOOLING_TOKENS:
        for match in pattern.finditer(text):
            start = max(0, match.start() - TOOLING_CONTEXT_CHARS)
            end = min(len(text), match.end() + TOOLING_CONTEXT_CHARS)
            snippet = re.sub(r"\s+", " ", text[start:end]).strip()
            hits.append((label, snippet))
    return hits

PRE_RE = re.compile(r"<pre\b[^>]*>.*?</pre>", re.S | re.I)
STYLE_RE = re.compile(r"<style\b[^>]*>.*?</style>", re.S | re.I)
TAG_RE = re.compile(r"<[^>]+>")
SENTENCE_SPLIT_RE = re.compile(r"(?<=[.!?;])\s+|\\n")


def prose(report_html: str) -> str:
    """Report text with evidence blocks and CSS removed, tags stripped."""
    text = STYLE_RE.sub(" ", report_html)
    text = PRE_RE.sub(" ", text)
    text = TAG_RE.sub(" ", text)
    text = html.unescape(text)
    return re.sub(r"[ \t]+", " ", text)


def full_text(report_html: str) -> str:
    """Report text with CSS stripped and tags removed, Evidence <pre> blocks
    kept. Tooling/process mentions belong nowhere in the delivered report,
    including inside an Evidence annotation span — unlike a runtime claim, an
    annotation explaining away a checker limitation is exactly the leak this
    rule exists to catch (iteration-3: '.data is outside check_quotes.py's
    suffix index', three times, plus a `ref:` field citing work/checks.txt)."""
    text = STYLE_RE.sub(" ", report_html)
    text = TAG_RE.sub(" ", text)
    text = html.unescape(text)
    return re.sub(r"[ \t]+", " ", text)


def sentences(text: str) -> list[str]:
    out = []
    for chunk in SENTENCE_SPLIT_RE.split(text):
        sentence = chunk.strip()
        if len(sentence) >= MIN_SENTENCE_CHARS:
            out.append(sentence)
    return out


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: check_claims.py <report.html>", file=sys.stderr)
        return 2
    report = Path(argv[1])
    if not report.is_file():
        print(f"report not found: {report}", file=sys.stderr)
        return 2

    raw_html = report.read_text(encoding="utf-8", errors="replace")
    all_sentences = sentences(prose(raw_html))
    fails: list[tuple[str, str]] = []
    notes: list[tuple[str, str]] = []
    for sentence in all_sentences:
        for label, pattern in BANNED_RE:
            if not pattern.search(sentence):
                continue
            bucket = notes if HEDGE_RE.search(sentence) else fails
            bucket.append((label, sentence))
            break

    tooling_hits = tooling_mentions(full_text(raw_html))

    print(f"scanned {len(all_sentences)} sentence(s) of report prose "
          f"(<pre> evidence blocks skipped)")
    for label, sentence in notes[:MAX_REPORTED]:
        shown = sentence if len(sentence) <= SENTENCE_MAX else sentence[:SENTENCE_MAX - 3] + "..."
        print(f"  [note: {label}, hedged in-sentence] {shown}")

    if tooling_hits:
        print(f"FAIL — {len(tooling_hits)} tooling/process mention(s) naming the "
              f"skill's own scripts, work files, or process:")
        for label, snippet in tooling_hits[:MAX_REPORTED]:
            print(f"  [{label}] ...{snippet}...")
        if len(tooling_hits) > MAX_REPORTED:
            print(f"  ... and {len(tooling_hits) - MAX_REPORTED} more")
        print("\nThe report is a deliverable, not a work log — delete these, don't hedge")
        print("them. Checker output and working files stay in work/, never in the report.")
    else:
        print("PASS — no mentions of the skill's own tooling or process")

    if not fails and not tooling_hits:
        print("PASS — no unhedged runtime claims")
        return 0

    if fails:
        print(f"FAIL — {len(fails)} unhedged runtime claim(s):")
        for label, sentence in fails[:MAX_REPORTED]:
            shown = sentence if len(sentence) <= SENTENCE_MAX else sentence[:SENTENCE_MAX - 3] + "..."
            print(f"  [{label}] {shown}")
        if len(fails) > MAX_REPORTED:
            print(f"  ... and {len(fails) - MAX_REPORTED} more")
        print("\nRewrite each in the conditional, deriving from the artifact: not")
        print("'with one record it is correct, which is why nobody noticed', but")
        print("'with exactly one record the PATCH targets the intended row; with two or")
        print("more it targets whichever Fusion returns first — verify on the pod'.")

    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
