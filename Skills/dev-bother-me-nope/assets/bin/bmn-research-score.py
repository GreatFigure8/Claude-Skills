#!/usr/bin/env python3
"""bmn-research-score.py — scores the approaches the RESEARCH step's researchers voted for.

Purpose:
  The RESEARCH step fans out N >= 5 independent researchers, each on its own lens and its own
  model (haiku, sonnet, opus, fable; every model runs at least once). The synthesizer clusters
  their equivalent approaches into canonical ids and writes research/clusters.json. This helper
  turns that file into a ranking in which consensus adds weight, and agreement reached by
  DIFFERENT models adds more than agreement within one model, so the winner is a formula.

Contract:
  bmn-research-score.py --clusters <path> [--weights 0.5,0.3,0.2]
  Input: {"researchers": [{"name": "reuse", "model": "haiku"}, ...], "approaches": [{"id": "a1",
          "name": "...", "votes": [{"researcher": "reuse", "merit": 8, "confidence": 0.7}]}]}
  Per approach: merit = sum(confidence * merit) / sum(confidence) over its votes (the plain mean
  of merit when every confidence is 0); consensus = supporters / N, N = len(researchers);
  model_agreement = distinct models among supporters / distinct models in the roster;
  score = W_MERIT * merit + W_CONSENSUS * 10 * consensus + W_MODELS * 10 * model_agreement,
  rounded to 2 places. Default weights 0.5, 0.3, 0.2. Ranked by score, then consensus, then
  model_agreement, then merit, then id.
  stdout {"ranked": [{id, name, supporters, models, merit, consensus, model_agreement, score}],
          "winner": "<id>"}.
  Exit 2 with one message on stderr (stdout empty) for: unreadable or invalid JSON, fewer than 5
  researchers, a researcher without a name, duplicate names, a model that is not one of the
  four, a roster missing one of the four models, no approaches, an approach with no votes, a
  vote from an unknown researcher, a researcher voting twice on one approach, merit outside
  0-10, confidence outside 0-1, weights that are not three numbers in 0-1 summing to 1.

Safety:
  Reads the one file named by --clusters and writes nothing. No subprocess, no network. A
  failure here is an assumption in the run, never a blocker: the synthesizer then applies the
  same formula by hand and says so in research.md.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

MIN_RESEARCHERS = 5
MODELS = ("haiku", "sonnet", "opus", "fable")
W_MERIT = 0.5
W_CONSENSUS = 0.3
W_MODELS = 0.2
WEIGHT_TOLERANCE = 1e-9
MAX_MERIT = 10
EXIT_USAGE = 2


class ScoreError(Exception):
    """Raised for any input the helper refuses; the message goes to stderr."""


def load(path: str) -> dict:
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except OSError as exc:
        raise ScoreError(f"cannot read {path}: {exc.strerror or exc}") from exc
    except ValueError as exc:
        raise ScoreError(f"invalid JSON in {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise ScoreError("clusters file must be a JSON object")
    return data


def is_number(value) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def check_researchers(data: dict) -> dict:
    """Validate the roster; return {name: model}."""
    roster = data.get("researchers")
    if not isinstance(roster, list):
        raise ScoreError("researchers must be a list of {name, model} objects")
    models: dict = {}
    for entry in roster:
        name = entry.get("name") if isinstance(entry, dict) else None
        if not isinstance(name, str) or not name:
            raise ScoreError("every researcher needs a name")
        if name in models:
            raise ScoreError(f"duplicate researcher names: {name!r}")
        model = entry.get("model")
        if model not in MODELS:
            raise ScoreError(f"researcher {name!r}: unknown model {model!r}")
        models[name] = model
    if len(models) < MIN_RESEARCHERS:
        raise ScoreError(f"need at least {MIN_RESEARCHERS} researchers, got {len(models)}")
    missing = [m for m in MODELS if m not in models.values()]
    if missing:
        raise ScoreError(f"roster must run every model at least once; missing {missing}")
    return models


def check_vote(vote, ident: str, researchers: list, seen: set) -> None:
    if not isinstance(vote, dict):
        raise ScoreError(f"approach {ident}: a vote must be an object")
    who = vote.get("researcher")
    if who not in researchers:
        raise ScoreError(f"approach {ident}: vote from unknown researcher {who!r}")
    if who in seen:
        raise ScoreError(f"approach {ident}: researcher {who!r} voted twice")
    seen.add(who)
    merit, confidence = vote.get("merit"), vote.get("confidence")
    if not is_number(merit) or not 0 <= merit <= MAX_MERIT:
        raise ScoreError(f"approach {ident}: merit must be 0-10, got {merit!r}")
    if not is_number(confidence) or not 0 <= confidence <= 1:
        raise ScoreError(f"approach {ident}: confidence must be 0-1, got {confidence!r}")


def check_approaches(data: dict, researchers: list) -> list:
    approaches = data.get("approaches")
    if not isinstance(approaches, list) or not approaches:
        raise ScoreError("no approaches to score")
    for item in approaches:
        if not isinstance(item, dict) or not item.get("id"):
            raise ScoreError("every approach needs an id")
        votes = item.get("votes")
        if not isinstance(votes, list) or not votes:
            raise ScoreError(f"approach {item['id']}: no votes")
        seen: set = set()
        for vote in votes:
            check_vote(vote, item["id"], researchers, seen)
    return approaches


def mean_merit(votes: list) -> float:
    weight = sum(v["confidence"] for v in votes)
    if weight == 0:
        return sum(v["merit"] for v in votes) / len(votes)
    return sum(v["confidence"] * v["merit"] for v in votes) / weight


def score_approach(item: dict, models: dict, weights: tuple) -> dict:
    votes = item["votes"]
    merit = mean_merit(votes)
    consensus = len(votes) / len(models)
    used = sorted({models[v["researcher"]] for v in votes})
    agreement = len(used) / len(set(models.values()))
    w_merit, w_consensus, w_models = weights
    blended = w_merit * merit + w_consensus * MAX_MERIT * consensus + w_models * MAX_MERIT * agreement
    return {"id": item["id"], "name": item.get("name", ""), "supporters": len(votes),
            "models": used, "merit": round(merit, 2), "consensus": round(consensus, 2),
            "model_agreement": round(agreement, 2), "score": round(blended, 2),
            "_key": (-round(blended, 2), -consensus, -agreement, -merit, str(item["id"]))}


def rank(data: dict, weights: tuple) -> dict:
    models = check_researchers(data)
    approaches = check_approaches(data, list(models))
    rows = sorted((score_approach(item, models, weights) for item in approaches),
                  key=lambda row: row["_key"])
    ranked = [{k: v for k, v in row.items() if k != "_key"} for row in rows]
    return {"ranked": ranked, "winner": ranked[0]["id"]}


def parse_weights(text: str) -> tuple:
    try:
        weights = tuple(float(part) for part in text.split(","))
    except ValueError as exc:
        raise ScoreError(f"--weights must be three numbers, got {text!r}") from exc
    if len(weights) != 3 or not all(0 <= w <= 1 for w in weights):
        raise ScoreError(f"--weights must be three numbers in 0-1, got {text!r}")
    if abs(sum(weights) - 1) > WEIGHT_TOLERANCE:
        raise ScoreError(f"--weights must sum to 1, got {text!r}")
    return weights


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="bmn-research-score.py")
    parser.add_argument("--clusters", required=True)
    parser.add_argument("--weights", default=f"{W_MERIT},{W_CONSENSUS},{W_MODELS}")
    args = parser.parse_args(argv)
    try:
        result = rank(load(args.clusters), parse_weights(args.weights))
    except ScoreError as exc:
        print(f"bmn-research-score.py: {exc}", file=sys.stderr)
        return EXIT_USAGE
    print(json.dumps(result, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
