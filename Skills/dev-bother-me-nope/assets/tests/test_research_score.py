"""Tests for bmn-research-score.py, the RESEARCH step's scoring helper.

Each test writes a clusters.json under tmp_path and runs the script as a subprocess, so the exit
code, stdout JSON and stderr message are exactly what the synthesizer sees. Standard library plus
pytest; nothing touches this repo, the network or git.
"""
import json
import subprocess
import sys

import nextjs_doc_helpers as h
import pytest

SCRIPT = h.PLUGIN / "assets" / "bin" / "bmn-research-score.py"
ROSTER = [
    {"name": "reuse", "model": "haiku"}, {"name": "prior-art", "model": "sonnet"},
    {"name": "primary-docs", "model": "sonnet"}, {"name": "simplest", "model": "fable"},
    {"name": "risk", "model": "opus"},
]
LENSES = [r["name"] for r in ROSTER]


def vote(researcher, merit, confidence=1.0):
    return {"researcher": researcher, "merit": merit, "confidence": confidence}


def approach(ident, *votes, name=None):
    return {"id": ident, "name": name or f"approach {ident}", "votes": list(votes)}


def clusters(*approaches, researchers=None):
    return {"researchers": list(ROSTER if researchers is None else researchers),
            "approaches": list(approaches)}


def score(tmp_path, data, *extra, raw=None):
    path = tmp_path / "clusters.json"
    path.write_text(raw if raw is not None else json.dumps(data))
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), "--clusters", str(path), *extra],
        capture_output=True, text=True, check=False,
    )
    return proc


def ok(tmp_path, data, *extra):
    proc = score(tmp_path, data, *extra)
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


def fails(tmp_path, data, message, *extra, raw=None):
    proc = score(tmp_path, data, *extra, raw=raw)
    assert proc.returncode != 0
    assert proc.stdout == ""
    assert message in proc.stderr, proc.stderr


# --- scoring ------------------------------------------------------------------------------
# Default weights: merit 0.5, consensus 0.3, model agreement 0.2.


def test_merit_is_the_confidence_weighted_mean(tmp_path):
    data = clusters(approach("a1", vote("reuse", 8, 0.5), vote("risk", 4, 0.5),
                             vote("simplest", 10, 1.0)))
    row = ok(tmp_path, data)["ranked"][0]
    assert row["merit"] == 8.0
    assert row["supporters"] == 3


def test_merit_is_the_plain_mean_when_every_confidence_is_zero(tmp_path):
    data = clusters(approach("a1", vote("reuse", 8, 0), vote("risk", 4, 0)))
    assert ok(tmp_path, data)["ranked"][0]["merit"] == 6.0


def test_consensus_is_supporters_over_researchers(tmp_path):
    data = clusters(approach("a1", vote("reuse", 5), vote("risk", 5)))
    assert ok(tmp_path, data)["ranked"][0]["consensus"] == 0.4


def test_model_agreement_is_distinct_supporter_models_over_roster_models(tmp_path):
    data = clusters(approach("a1", vote("prior-art", 5), vote("primary-docs", 5),
                             vote("risk", 5)))
    row = ok(tmp_path, data)["ranked"][0]
    assert row["models"] == ["opus", "sonnet"]
    assert row["model_agreement"] == 0.5


def test_score_blends_merit_consensus_and_model_agreement(tmp_path):
    data = clusters(approach("a1", vote("reuse", 8), vote("risk", 8)))
    row = ok(tmp_path, data)["ranked"][0]
    assert row["score"] == round(0.5 * 8 + 0.3 * 10 * 0.4 + 0.2 * 10 * 0.5, 2) == 6.2


def test_weights_flag_changes_the_score(tmp_path):
    data = clusters(approach("a1", vote("reuse", 8), vote("risk", 8)))
    assert ok(tmp_path, data, "--weights", "1,0,0")["ranked"][0]["score"] == 8.0
    assert ok(tmp_path, data, "--weights", "0,1,0")["ranked"][0]["score"] == 4.0
    assert ok(tmp_path, data, "--weights", "0,0,1")["ranked"][0]["score"] == 5.0


def test_score_is_rounded_to_two_places(tmp_path):
    data = clusters(approach("a1", vote("reuse", 7, 0.3), vote("risk", 5, 0.7),
                             vote("simplest", 9, 0.1)))
    score_value = ok(tmp_path, data)["ranked"][0]["score"]
    assert score_value == round(score_value, 2)


def test_three_models_beat_one_model_at_equal_merit_and_supporters(tmp_path):
    roster = ROSTER + [{"name": "sonnet-extra", "model": "sonnet"}]
    narrow = approach("a1", vote("prior-art", 7), vote("primary-docs", 7),
                      vote("sonnet-extra", 7))
    wide = approach("a2", vote("reuse", 7), vote("prior-art", 7), vote("risk", 7))
    out = ok(tmp_path, clusters(narrow, wide, researchers=roster))
    rows = {r["id"]: r for r in out["ranked"]}
    assert rows["a1"]["supporters"] == rows["a2"]["supporters"] == 3
    assert rows["a1"]["merit"] == rows["a2"]["merit"]
    assert rows["a1"]["models"] == ["sonnet"] and rows["a2"]["models"] == ["haiku", "opus", "sonnet"]
    assert out["winner"] == "a2"


def test_consensus_can_outrank_a_higher_merit_approach(tmp_path):
    lone = approach("a1", vote("reuse", 10))
    shared = approach("a2", *(vote(lens, 7) for lens in LENSES))
    out = ok(tmp_path, clusters(lone, shared))
    assert out["winner"] == "a2"
    assert [row["id"] for row in out["ranked"]] == ["a2", "a1"]


def test_ties_break_on_consensus_then_model_agreement_then_merit_then_id(tmp_path):
    same = clusters(approach("b", vote("reuse", 6)), approach("a", vote("risk", 6)))
    assert ok(tmp_path, same)["winner"] == "a"
    # equal score 3.0 at weights 0,1,0 (consensus only) and 0,0,1: tie on consensus, id decides
    out = ok(tmp_path, clusters(approach("b", vote("reuse", 5), vote("simplest", 9)),
                                approach("a", vote("prior-art", 9), vote("primary-docs", 5))),
             "--weights", "0,1,0")
    assert out["ranked"][0]["score"] == out["ranked"][1]["score"]
    assert out["winner"] == "b"  # same consensus, more models (haiku+fable vs sonnet)
    by_merit = ok(tmp_path, clusters(approach("b", vote("reuse", 5)), approach("a", vote("risk", 9))),
                  "--weights", "0,1,0")
    assert by_merit["winner"] == "a"


def test_output_row_has_exactly_the_documented_keys(tmp_path):
    out = ok(tmp_path, clusters(approach("a1", vote("reuse", 5), name="Use X")))
    assert set(out) == {"ranked", "winner"}
    assert set(out["ranked"][0]) == {"id", "name", "supporters", "models", "merit", "consensus",
                                     "model_agreement", "score"}
    assert out["ranked"][0]["name"] == "Use X"


# --- validation ---------------------------------------------------------------------------


def good():
    return clusters(approach("a1", vote("reuse", 5)))


def test_fewer_than_five_researchers_is_refused(tmp_path):
    data = clusters(approach("a1", vote("reuse", 5)), researchers=ROSTER[:4])
    fails(tmp_path, data, "at least 5 researchers")


def test_a_roster_missing_a_model_is_refused(tmp_path):
    roster = [dict(r, model="sonnet" if r["model"] == "fable" else r["model"]) for r in ROSTER]
    fails(tmp_path, clusters(approach("a1", vote("reuse", 5)), researchers=roster), "fable")


def test_an_unknown_model_is_refused(tmp_path):
    roster = [dict(r, model="gpt" if r["name"] == "risk" else r["model"]) for r in ROSTER]
    fails(tmp_path, clusters(approach("a1", vote("reuse", 5)), researchers=roster), "unknown model")


def test_a_researcher_that_is_not_an_object_is_refused(tmp_path):
    fails(tmp_path, clusters(approach("a1", vote("reuse", 5)), researchers=LENSES), "name")


def test_more_than_five_researchers_is_fine(tmp_path):
    data = clusters(approach("a1", vote("reuse", 5)),
                    researchers=ROSTER + [{"name": "ux", "model": "opus"}])
    assert ok(tmp_path, data)["ranked"][0]["consensus"] == 0.17


def test_duplicate_researcher_names_are_refused(tmp_path):
    data = clusters(approach("a1", vote("reuse", 5)), researchers=ROSTER[:4] + [ROSTER[0]])
    fails(tmp_path, data, "duplicate researcher")


@pytest.mark.parametrize("merit", [-1, 10.5, 11])
def test_merit_outside_0_to_10_is_refused(tmp_path, merit):
    fails(tmp_path, clusters(approach("a1", vote("reuse", merit))), "merit")


@pytest.mark.parametrize("confidence", [-0.1, 1.1, 2])
def test_confidence_outside_0_to_1_is_refused(tmp_path, confidence):
    fails(tmp_path, clusters(approach("a1", vote("reuse", 5, confidence))), "confidence")


def test_vote_from_an_unknown_researcher_is_refused(tmp_path):
    fails(tmp_path, clusters(approach("a1", vote("ghost", 5))), "unknown researcher")


def test_a_researcher_voting_twice_on_one_approach_is_refused(tmp_path):
    fails(tmp_path, clusters(approach("a1", vote("reuse", 5), vote("reuse", 6))), "twice")


def test_an_approach_with_no_votes_is_refused(tmp_path):
    fails(tmp_path, clusters(approach("a1")), "no votes")


@pytest.mark.parametrize("weights", ["0.5,0.3", "0.5,0.3,0.3", "-0.1,0.6,0.5", "1.5,-0.25,-0.25",
                                     "a,b,c", "0.5,0.3,0.2,0"])
def test_bad_weights_are_refused(tmp_path, weights):
    fails(tmp_path, good(), "weights", "--weights", weights)


def test_no_approaches_is_refused(tmp_path):
    fails(tmp_path, clusters(), "no approaches")


def test_unreadable_file_is_refused(tmp_path):
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), "--clusters", str(tmp_path / "missing.json")],
        capture_output=True, text=True, check=False,
    )
    assert proc.returncode != 0 and "cannot read" in proc.stderr


def test_invalid_json_is_refused(tmp_path):
    fails(tmp_path, None, "invalid JSON", raw="{not json")


def test_wrong_shape_is_refused_without_a_traceback(tmp_path):
    proc = score(tmp_path, None, raw=json.dumps([1, 2]))
    assert proc.returncode != 0
    assert "Traceback" not in proc.stderr
