#!/usr/bin/env python3
"""Mechanical checker for D1-D6 of the oic-iar-integration-review eval rubric.

Usage:
    ./check_report.py <report.html> [<source.iar>] [--json grading-D.json]

Playwright is required for D4/D5/D6. If it is not importable the script
re-executes itself under uv, so the zero-setup invocation is just:

    uv run --with playwright evals/check_report.py report.html source.iar

To install it permanently instead, one line:

    pip install playwright && playwright install chromium

Without the .iar, D2 and D3 cannot be evaluated: they are emitted with
"passed": null and evidence "IAR not available ...", and are excluded from the
summary counts. skill-creator's viewer renders a null "passed" as a failure, so
a null entry means "not checked", never "checked and passed".

Output is a grading.json fragment using skill-creator's exact expectation field
names (text / passed / evidence) so it can be merged into the grader's
expectations array without translation.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent

# ---------------------------------------------------------------------------
# Rubric constants
# ---------------------------------------------------------------------------

TAB_IDS = ["overview", "trace", "findings", "api", "target", "sources"]
WIDTHS = [420, 820, 1000, 1280, 1440]
VIEWPORT_HEIGHT = 1000
MIN_FONT_PX = 13.0
BANNED_LABELS = ["dead", "garbage", "broken", "junk"]
OVERFLOW_TOLERANCE_PX = 1.0

# Elements inside <orchestration> that are containers or declarations rather
# than executable activities. Everything else carrying an id is counted as an
# activity. Kept explicit so the count is reproducible and arguable.
NON_ACTIVITY_TAGS = {
    "orchestration",
    "integrationMetadata",
    "globalVariable",
    "globalTry",
    "label",
    "route",
    "try",
}

FALLBACK_TEXT = {
    "D1": "D1 — Six tabs present.",
    "D2": "D2 — Trace completeness: NODES count equals orchestration activity count.",
    "D3": "D3 — Cost meter accuracy: final totals equal invoke and lookup counts.",
    "D4": "D4 — No horizontal overflow at 420/820/1000/1280/1440px.",
    "D5": "D5 — Minimum text size: no computed font-size below 13px.",
    "D6": "D6 — Neutral wording: no loaded one-word labels.",
}


def rubric_text() -> dict[str, str]:
    """Use the assertion strings from evals.json verbatim when available."""
    text = dict(FALLBACK_TEXT)
    evals_path = HERE / "evals.json"
    if not evals_path.exists():
        return text
    try:
        doc = json.loads(evals_path.read_text())
    except (json.JSONDecodeError, OSError):
        return text
    for eval_case in doc.get("evals", []):
        for expectation in eval_case.get("expectations", []):
            key = expectation[:2]
            if key in text and expectation.startswith(key + " "):
                text[key] = expectation
    return text


# ---------------------------------------------------------------------------
# IAR side: project.xml activity, invoke and lookup counts
# ---------------------------------------------------------------------------


class IarFacts:
    def __init__(self, activities: int, invokes: int, lookups: int, breakdown: dict[str, int], project_xml: str):
        self.activities = activities
        self.invokes = invokes
        self.lookups = lookups
        self.breakdown = breakdown
        self.project_xml = project_xml


def _local_name(tag: str) -> str:
    return tag.split(":")[-1]


def _orchestration_block(xml: str) -> str:
    match = re.search(r"<((?:[\w.-]+:)?orchestration)\b[^>]*>", xml)
    if not match:
        raise ValueError("no <orchestration> element found in project.xml")
    close = "</" + match.group(1) + ">"
    end = xml.find(close, match.start())
    if end == -1:
        raise ValueError("unterminated <orchestration> element in project.xml")
    return xml[match.start() : end + len(close)]


def read_iar(iar_path: Path) -> IarFacts:
    workdir = Path(tempfile.mkdtemp(prefix="iar-check-"))
    try:
        with zipfile.ZipFile(iar_path) as archive:
            archive.extractall(workdir)

        candidates = sorted(workdir.rglob("PROJECT-INF/project.xml")) or sorted(workdir.rglob("project.xml"))
        if not candidates:
            raise ValueError(f"no project.xml inside {iar_path.name}")
        project_xml = candidates[0]
        block = _orchestration_block(project_xml.read_text(encoding="utf-8", errors="replace"))

        breakdown: dict[str, int] = {}
        for tag in re.findall(r"<((?:[\w.-]+:)?[A-Za-z][\w.-]*)\b[^>]*\bid=", block):
            name = _local_name(tag)
            breakdown[name] = breakdown.get(name, 0) + 1

        activities = sum(count for tag, count in breakdown.items() if tag not in NON_ACTIVITY_TAGS)
        invokes = breakdown.get("invoke", 0)

        lookups = 0
        for expr in workdir.rglob("expr.properties"):
            lookups += expr.read_text(encoding="utf-8", errors="replace").count("dvm:lookupValue")

        rel = project_xml.relative_to(workdir).as_posix()
        return IarFacts(activities, invokes, lookups, breakdown, rel)
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


# ---------------------------------------------------------------------------
# HTML side: static parse of NODES and the tab scaffolding
# ---------------------------------------------------------------------------


def extract_nodes_array(html: str) -> str | None:
    match = re.search(r"\bNODES\s*=\s*\[", html)
    if not match:
        return None
    i = match.end() - 1
    depth = 0
    quote = None
    while i < len(html):
        ch = html[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = None
        elif ch in "'\"`":
            quote = ch
        elif ch in "[{":
            depth += 1
        elif ch in "]}":
            depth -= 1
            if depth == 0:
                return html[match.end() - 1 : i + 1]
        i += 1
    return None


def count_nodes(array_src: str) -> int:
    """Count top-level object literals in the NODES array."""
    depth = 0
    quote = None
    count = 0
    i = 0
    while i < len(array_src):
        ch = array_src[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = None
        elif ch in "'\"`":
            quote = ch
        elif ch in "[{":
            depth += 1
            if ch == "{" and depth == 2:
                count += 1
        elif ch in "]}":
            depth -= 1
        i += 1
    return count


def static_cost_totals(array_src: str) -> dict[str, int]:
    totals = {"c": 0, "l": 0, "x": 0}
    for body in re.findall(r"cost\s*:\s*\{([^}]*)\}", array_src):
        for key in totals:
            found = re.search(rf"\b{key}\s*:\s*(-?\d+)", body)
            if found:
                totals[key] += int(found.group(1))
    return totals


def check_tabs(html: str) -> tuple[bool, str]:
    buttons = set(re.findall(r'data-tab=["\']([\w-]+)["\']', html))
    panels = set(re.findall(r'<section[^>]*\bclass="[^"]*\bpanel\b[^"]*"[^>]*\bid="([\w-]+)"', html))
    panels |= set(re.findall(r'<section[^>]*\bid="([\w-]+)"[^>]*\bclass="[^"]*\bpanel\b[^"]*"', html))

    missing_buttons = [t for t in TAB_IDS if t not in buttons]
    missing_panels = [t for t in TAB_IDS if t not in panels]
    extra = sorted((buttons & panels) - set(TAB_IDS))

    if missing_buttons or missing_panels:
        parts = []
        if missing_buttons:
            parts.append(f"no button[data-tab] for {missing_buttons}")
        if missing_panels:
            parts.append(f"no section.panel#id for {missing_panels}")
        return False, "; ".join(parts) + f" (buttons found: {sorted(buttons)}; panels found: {sorted(panels)})"

    note = f"; additional non-rubric tabs present: {extra}" if extra else ""
    return True, f"all six tab ids paired as button[data-tab] + section.panel#id: {TAB_IDS}{note}"


# ---------------------------------------------------------------------------
# Browser side: D4 overflow, D5 font size, D6 wording
# ---------------------------------------------------------------------------

PROBE_JS = r"""
(args) => {
  const {minFont, banned, tolerance} = args;
  const vw = window.innerWidth;
  const label = (el) => {
    const t = (el.tagName || '').toLowerCase();
    const p = el.getPathTag ? el.getPathTag() : '';
    const cls = (el.className && el.className.baseVal !== undefined)
      ? el.className.baseVal : (el.className || '');
    return t + (el.id ? '#' + el.id : '') + (cls ? '.' + String(cls).trim().split(/\s+/).join('.') : '') + p;
  };
  const visible = (el) => {
    const cs = getComputedStyle(el);
    if (cs.display === 'none' || cs.visibility === 'hidden' || cs.opacity === '0') return false;
    const r = el.getBoundingClientRect();
    return r.width > 0 && r.height > 0;
  };

  const overflow = [];
  const small = [];
  const labelHits = [];
  const textHits = [];
  const bannedRe = banned.map(w => new RegExp('\\b' + w + '\\b', 'i'));
  const LABELISH = '.pill,.badge,.chip,.tag,.st,.k,.kind,.eyebrow,.item,.sev,.dot,.lbl,.l,label,th,legend,summary,button';

  document.querySelectorAll('body *').forEach(el => {
    if (!visible(el)) return;

    if (!el.closest('.tw')) {
      const r = el.getBoundingClientRect();
      if (r.right > vw + tolerance) {
        overflow.push({sel: label(el), right: Math.round(r.right), vw: vw});
      }
    }

    const own = Array.from(el.childNodes)
      .filter(n => n.nodeType === 3 && n.textContent.trim().length)
      .map(n => n.textContent.trim()).join(' ');
    if (own) {
      const fs = parseFloat(getComputedStyle(el).fontSize);
      if (fs && fs < minFont) {
        small.push({sel: label(el), px: fs, text: own.slice(0, 60)});
      }
    }
  });

  document.querySelectorAll(LABELISH).forEach(el => {
    if (!visible(el)) return;
    const t = (el.innerText || el.textContent || '').trim().replace(/[^A-Za-z]+$/, '');
    if (!t) return;
    if (/\s/.test(t)) return;                       // one-word labels only
    if (bannedRe.some(re => re.test(t))) {
      labelHits.push({sel: label(el), text: t});
    }
  });

  const bodyText = document.body.innerText || '';
  bannedRe.forEach((re, i) => {
    const m = bodyText.match(new RegExp('.{0,45}\\b' + banned[i] + '\\b.{0,45}', 'i'));
    if (m) textHits.push({word: banned[i], context: m[0].replace(/\s+/g, ' ')});
  });

  return {overflow, small, labelHits, textHits};
}
"""


def render_checks(report: Path) -> dict:
    from playwright.sync_api import sync_playwright

    findings = {
        "overflow": [],
        "small": [],
        "label_hits": [],
        "text_hits": [],
        "widths": list(WIDTHS),
        "tabs_visited": [],
        "meter": None,
    }
    seen_overflow: set[tuple] = set()
    seen_small: set[tuple] = set()
    seen_label: set[tuple] = set()
    seen_text: set[tuple] = set()

    with sync_playwright() as pw:
        browser = _launch(pw)
        try:
            for width in WIDTHS:
                page = browser.new_page(viewport={"width": width, "height": VIEWPORT_HEIGHT})
                page.goto(report.as_uri(), wait_until="load")
                tab_ids = page.eval_on_selector_all(
                    "button[data-tab], a[data-tab]", "els => [...new Set(els.map(e => e.dataset.tab))]"
                ) or [None]

                for tab in tab_ids:
                    if tab:
                        page.click(f"button[data-tab='{tab}']", timeout=5000)
                    page.evaluate("() => document.querySelectorAll('details').forEach(d => d.open = true)")
                    page.wait_for_timeout(120)

                    if tab == "trace" and findings["meter"] is None:
                        findings["meter"] = _read_meter(page)

                    result = page.evaluate(
                        PROBE_JS,
                        {"minFont": MIN_FONT_PX, "banned": BANNED_LABELS, "tolerance": OVERFLOW_TOLERANCE_PX},
                    )
                    for row in result["overflow"]:
                        key = (width, tab, row["sel"], row["right"])
                        if key not in seen_overflow:
                            seen_overflow.add(key)
                            findings["overflow"].append({"width": width, "tab": tab, **row})
                    for row in result["small"]:
                        key = (row["sel"], round(row["px"], 2))
                        if key not in seen_small:
                            seen_small.add(key)
                            findings["small"].append({"width": width, "tab": tab, **row})
                    for row in result["labelHits"]:
                        key = (row["sel"], row["text"].lower())
                        if key not in seen_label:
                            seen_label.add(key)
                            findings["label_hits"].append({"tab": tab, **row})
                    for row in result["textHits"]:
                        key = (row["word"], row["context"])
                        if key not in seen_text:
                            seen_text.add(key)
                            findings["text_hits"].append({"tab": tab, **row})
                    if width == WIDTHS[0]:
                        findings["tabs_visited"].append(tab)
                page.close()
        finally:
            browser.close()
    return findings


def _launch(pw):
    try:
        return pw.chromium.launch()
    except Exception:
        subprocess.run([sys.executable, "-m", "playwright", "install", "chromium"], check=True)
        return pw.chromium.launch()


def _read_meter(page) -> dict | None:
    """Click the last trace node and read the cumulative cost meter."""
    js = """
    () => {
      const nodes = document.querySelectorAll('#flow .node');
      if (!nodes.length) return null;
      nodes[nodes.length - 1].click();
      const cells = [...document.querySelectorAll('.meter > div')].map(d => ({
        value: (d.querySelector('.v') || {}).textContent,
        label: ((d.querySelector('.l') || {}).textContent || '').trim()
      }));
      return {rendered_nodes: nodes.length, cells};
    }
    """
    try:
        return page.evaluate(js)
    except Exception:
        return None


def _meter_value(meter: dict | None, *keywords: str) -> int | None:
    if not meter:
        return None
    for cell in meter.get("cells", []):
        label = (cell.get("label") or "").lower()
        if all(k in label for k in keywords):
            try:
                return int(str(cell.get("value")).strip())
            except (TypeError, ValueError):
                return None
    return None


# ---------------------------------------------------------------------------
# Assembly
# ---------------------------------------------------------------------------


def build_expectations(report: Path, iar: Path | None, browser_ok: bool) -> tuple[list[dict], dict]:
    text = rubric_text()
    html = report.read_text(encoding="utf-8", errors="replace")
    out: list[dict] = []
    context: dict = {}

    # D1
    passed, evidence = check_tabs(html)
    out.append({"text": text["D1"], "passed": passed, "evidence": evidence})

    # NODES
    array_src = extract_nodes_array(html)
    node_count = count_nodes(array_src) if array_src else None
    static_totals = static_cost_totals(array_src) if array_src else None
    context["node_count"] = node_count
    context["static_cost_totals"] = static_totals

    facts = read_iar(iar) if iar else None
    if facts:
        context["iar"] = {
            "project_xml": facts.project_xml,
            "activities": facts.activities,
            "invokes": facts.invokes,
            "lookups": facts.lookups,
            "tag_breakdown": facts.breakdown,
            "non_activity_tags_excluded": sorted(NON_ACTIVITY_TAGS),
        }

    browser = render_checks(report) if browser_ok else None
    context["browser"] = browser
    meter = browser.get("meter") if browser else None

    # D2
    if facts is None:
        out.append(
            {
                "text": text["D2"],
                "passed": None,
                "evidence": "IAR not available — D2 needs the source .iar to count orchestration activities; not checked.",
            }
        )
    elif node_count is None:
        out.append({"text": text["D2"], "passed": False, "evidence": "No NODES array found in the report; trace step count could not be read."})
    else:
        counted = ", ".join(f"{k}={v}" for k, v in sorted(facts.breakdown.items()) if k not in NON_ACTIVITY_TAGS)
        out.append(
            {
                "text": text["D2"],
                "passed": node_count == facts.activities,
                "evidence": (
                    f"NODES entries = {node_count}; orchestration activities in {facts.project_xml} = {facts.activities} "
                    f"({counted}); excluded as containers/declarations: {sorted(NON_ACTIVITY_TAGS)}. "
                    f"Difference = {node_count - facts.activities}."
                ),
            }
        )

    # D3
    meter_calls = _meter_value(meter, "fusion", "call")
    meter_lookups = _meter_value(meter, "lookup")
    calls = meter_calls if meter_calls is not None else (static_totals or {}).get("c")
    lookups = meter_lookups if meter_lookups is not None else (static_totals or {}).get("l")
    source = "rendered cost meter on the final trace step" if meter_calls is not None else "static sum of NODES[].cost"

    if facts is None:
        out.append(
            {
                "text": text["D3"],
                "passed": None,
                "evidence": (
                    f"IAR not available — D3 needs the source .iar to count invoke activities and dvm:lookupValue "
                    f"occurrences; not checked. Report side read {calls} Fusion calls / {lookups} lookups from the {source}."
                ),
            }
        )
    elif calls is None or lookups is None:
        out.append({"text": text["D3"], "passed": False, "evidence": "Cost meter totals could not be read from the report."})
    else:
        out.append(
            {
                "text": text["D3"],
                "passed": calls == facts.invokes and lookups == facts.lookups,
                "evidence": (
                    f"Report final totals ({source}): {calls} Fusion calls, {lookups} DVM lookups. "
                    f"IAR: {facts.invokes} <invoke> activities, {facts.lookups} dvm:lookupValue occurrences in expr.properties."
                ),
            }
        )

    # D4 / D5 / D6
    if not browser:
        for key in ("D4", "D5", "D6"):
            out.append(
                {
                    "text": text[key],
                    "passed": None,
                    "evidence": "Browser checks skipped (--no-browser, or Playwright unavailable) — run `uv run --with playwright evals/check_report.py <report.html> [<file.iar>]`; not checked.",
                }
            )
        return out, context

    overflow = browser["overflow"]
    sample = "; ".join(f"{o['tab']}@{o['width']}px {o['sel']} right={o['right']}>{o['vw']}" for o in overflow[:5])
    out.append(
        {
            "text": text["D4"],
            "passed": not overflow,
            "evidence": (
                f"Rendered at {WIDTHS}px, tabs {browser['tabs_visited']}, all <details> forced open. "
                + (f"{len(overflow)} overflowing element(s): {sample}" if overflow else
                   f"0 elements exceed the viewport right edge (tolerance {OVERFLOW_TOLERANCE_PX}px; .tw descendants exempt).")
            ),
        }
    )

    small = browser["small"]
    sample = "; ".join(f"{s['sel']} {s['px']}px \"{s['text']}\"" for s in small[:5])
    out.append(
        {
            "text": text["D5"],
            "passed": not small,
            "evidence": (
                f"{len(small)} text-bearing element(s) below {MIN_FONT_PX}px: {sample}" if small
                else f"0 text-bearing elements have a computed font-size below {MIN_FONT_PX}px across all tabs and widths."
            ),
        }
    )

    label_hits = browser["label_hits"]
    text_hits = browser["text_hits"]
    prose = (
        " Banned words do appear in prose (not as labels), which D6 does not fail on: "
        + "; ".join(f"'{h['word']}' in \"{h['context']}\"" for h in text_hits[:4])
        if text_hits else ""
    )
    out.append(
        {
            "text": text["D6"],
            "passed": not label_hits,
            "evidence": (
                (f"{len(label_hits)} one-word label/pill using banned wording: "
                 + "; ".join(f"{h['sel']} = \"{h['text']}\"" for h in label_hits[:5])) if label_hits
                else f"0 one-word labels or pills use {BANNED_LABELS} in visible text."
            ) + prose,
        }
    )
    return out, context


def summarize(expectations: list[dict]) -> dict:
    graded = [e for e in expectations if e["passed"] is not None]
    passed = sum(1 for e in graded if e["passed"])
    total = len(graded)
    return {
        "passed": passed,
        "failed": total - passed,
        "total": total,
        "pass_rate": round(passed / total, 2) if total else 0.0,
        "not_checked": len(expectations) - total,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Check D1-D6 of an oic-iar-integration-review report.")
    parser.add_argument("report", type=Path, help="the generated single-file HTML report")
    parser.add_argument("iar", type=Path, nargs="?", help="the source .iar (required for D2 and D3)")
    parser.add_argument("--json", type=Path, help="write the grading.json fragment here")
    parser.add_argument("--no-browser", action="store_true", help="skip D4/D5/D6 (no Playwright)")
    args = parser.parse_args()
    args.report = args.report.expanduser().resolve()
    if args.iar:
        args.iar = args.iar.expanduser().resolve()

    if not args.report.exists():
        print(f"error: report not found: {args.report}", file=sys.stderr)
        return 2
    if args.iar and not args.iar.exists():
        print(f"error: iar not found: {args.iar}", file=sys.stderr)
        return 2

    browser_ok = not args.no_browser
    if browser_ok:
        try:
            import playwright  # noqa: F401
        except ImportError:
            if os.environ.get("IAR_CHECK_REEXEC"):
                print("error: playwright still unavailable after re-exec", file=sys.stderr)
                return 2
            if not shutil.which("uv"):
                print("error: playwright missing and uv not found. pip install playwright && playwright install chromium", file=sys.stderr)
                return 2
            env = {**os.environ, "IAR_CHECK_REEXEC": "1"}
            cmd = ["uv", "run", "--with", "playwright", "python", str(Path(__file__).resolve()), *sys.argv[1:]]
            return subprocess.run(cmd, env=env).returncode

    expectations, context = build_expectations(args.report, args.iar, browser_ok)
    fragment = {"expectations": expectations, "summary": summarize(expectations), "context": context}

    if args.json:
        args.json.write_text(json.dumps(fragment, indent=2) + "\n")

    for item in expectations:
        key = item["text"][:2]
        state = "PASS" if item["passed"] else ("FAIL" if item["passed"] is False else "NOT CHECKED")
        print(f"{key}: {state}")
        print(f"    {item['evidence']}")
    summary = fragment["summary"]
    print(f"\nsummary: {summary['passed']} passed, {summary['failed']} failed of {summary['total']} checked "
          f"({summary['not_checked']} not checked)")

    return 1 if summary["failed"] else 0


if __name__ == "__main__":
    sys.exit(main())
