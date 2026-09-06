#!/usr/bin/env python3
"""Verbatim-quote checker for the report's finding Evidence blocks (rubric A1).

Usage:
    python3 scripts/check_quotes.py <report.html> <iar-or-extracted-dir>

Every Evidence quote in a delivered report must appear character-for-character
in the IAR. Iteration-1 grading failed A1 on 5/5 runs — not because the facts
were wrong, but because quotes were retyped from memory of the file: xml:id
attributes dropped from inside tags, &quot; rendered as ', `AND` lowercased,
`concat (` respaced, namespace prefixes stripped, and "..." elisions inside a
quoted string. One retyped quote fails the whole report.

The convention it enforces: inside an Evidence <pre>, an unmarked line IS a
verbatim quote. Anything you wrote yourself — a label, a file path, an arrow, a
summary line, a rendering of an attribute as `key = value` — must sit inside
<span class="cm">...</span> (the comment token the design system already uses)
or start with `//`. Then this checker greps every unmarked line, whitespace-
normalised, against the concatenated text of the extracted IAR, and anything it
cannot find is either a retyped quote or an unmarked annotation. Both are worth
fixing: the grader cannot tell them apart either.

Run it against a report written before that convention existed and nearly every
line will be flagged — that is the checker working, not a bug.

Exit codes: 0 = every quote found, 1 = at least one quote is not verbatim,
2 = bad usage / nothing to check.

Quotes that legitimately come from an Oracle doc rather than the IAR do not
belong in an Evidence block — put them in "judged against" / the sources tab.
"""

from __future__ import annotations

import html
import re
import sys
import tempfile
import zipfile
from pathlib import Path

TEXT_SUFFIXES = {
    ".xml", ".xsl", ".xslt", ".wsdl", ".xsd", ".jca", ".properties", ".dvm",
    ".json", ".txt", ".md", ".cfg", ".sql", ".csv", ".data",
}
MAX_FILE_BYTES = 8_000_000
MIN_QUOTE_CHARS = 8
MAX_REPORTED = 40
ELISION_MARKERS = ("…", "...")

CM_SPAN_RE = re.compile(r"<span[^>]*class=\"[^\"]*\bcm\b[^\"]*\"[^>]*>.*?</span>", re.S)
TAG_RE = re.compile(r"<[^>]+>")
PRE_RE = re.compile(r"<pre\b[^>]*>(.*?)</pre>", re.S)
EV_FIELD_RE = re.compile(r"\bev\s*:\s*(['\"])(.*?)(?<!\\)\1", re.S)


JS_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\"}


def unescape_js(value: str) -> str:
    """Undo the backslash escapes a JS string literal carries. UTF-8 safe."""
    return re.sub(r"\\(.)", lambda m: JS_ESCAPES.get(m.group(1), m.group(1)), value)


def normalise(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def iar_corpus(source: Path) -> str:
    """Whitespace-normalised text of every readable file under the IAR."""
    root = source
    tmp: tempfile.TemporaryDirectory | None = None
    if source.is_file():
        if not zipfile.is_zipfile(source):
            raise SystemExit(f"not a directory and not a zip/.iar: {source}")
        tmp = tempfile.TemporaryDirectory()
        with zipfile.ZipFile(source) as archive:
            archive.extractall(tmp.name)
        root = Path(tmp.name)

    chunks: list[str] = []
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        if path.suffix.lower() not in TEXT_SUFFIXES and path.suffix:
            continue
        try:
            if path.stat().st_size > MAX_FILE_BYTES:
                continue
            chunks.append(path.read_text(encoding="utf-8", errors="replace"))
        except OSError:
            continue
    if tmp is not None:
        corpus = "\n".join(chunks)
        tmp.cleanup()
        return normalise(corpus)
    return normalise("\n".join(chunks))


def evidence_blocks(report_html: str) -> list[str]:
    """<pre> blocks inside findings `ev:` fields, falling back to all <pre>."""
    ev_values = [match.group(2) for match in EV_FIELD_RE.finditer(report_html)]
    blocks: list[str] = []
    for value in ev_values:
        blocks.extend(PRE_RE.findall(unescape_js(value)))
    if blocks:
        return blocks
    return PRE_RE.findall(report_html)


def quote_lines(block: str) -> list[str]:
    without_comments = CM_SPAN_RE.sub("", block)
    plain = html.unescape(TAG_RE.sub("", without_comments))
    lines = []
    for raw in plain.splitlines():
        line = raw.strip()
        if not line or line.startswith("//") or line.startswith("#"):
            continue
        if len(line) < MIN_QUOTE_CHARS:
            continue
        lines.append(line)
    return lines


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__.strip().splitlines()[2].strip(), file=sys.stderr)
        print("usage: check_quotes.py <report.html> <iar-or-extracted-dir>", file=sys.stderr)
        return 2

    report = Path(argv[1])
    source = Path(argv[2])
    if not report.is_file():
        print(f"report not found: {report}", file=sys.stderr)
        return 2
    if not source.exists():
        print(f"IAR source not found: {source}", file=sys.stderr)
        return 2

    corpus = iar_corpus(source)
    if not corpus:
        print(f"no readable text under {source}", file=sys.stderr)
        return 2

    blocks = evidence_blocks(report.read_text(encoding="utf-8", errors="replace"))
    if not blocks:
        print("no <pre> evidence blocks found in the report", file=sys.stderr)
        return 2

    checked = 0
    misses: list[tuple[str, str]] = []
    for block in blocks:
        for line in quote_lines(block):
            checked += 1
            if any(marker in line for marker in ELISION_MARKERS):
                misses.append(("elided", line))
                continue
            if normalise(line) not in corpus:
                misses.append(("not found", line))

    print(f"checked {checked} evidence line(s) from {len(blocks)} <pre> block(s)")
    if not misses:
        print("PASS — every evidence line appears verbatim in the IAR")
        return 0

    print(f"FAIL — {len(misses)} line(s) are not verbatim IAR text:")
    for reason, line in misses[:MAX_REPORTED]:
        shown = line if len(line) <= 160 else line[:157] + "..."
        print(f"  [{reason}] {shown}")
    if len(misses) > MAX_REPORTED:
        print(f"  ... and {len(misses) - MAX_REPORTED} more")
    print("\nFix by copying the exact bytes out of the file (sed -n / grep -F),")
    print("not by retyping. Mark commentary with <span class=\"cm\">// ...</span>.")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
