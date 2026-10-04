"""The two protected-branch lists must name the same branches.

deploy-guard.py refuses to delete these on origin (DELETE_PROTECTED) and merged-branch-cleanup.py
refuses to clean them up (PROTECTED). They are typed by hand in two files; this test compares the
live module constants, so a name added to one list only fails here instead of silently bringing
back the R1-6 disagreement. The documented lists (the guard's docstring and the protected-delete
bullet of references/deploy-guards.md) are pinned to the same constant.
Run: python3 -m pytest Skills/dev-bother-me-nope/assets/tests -q
"""
import hashlib
import importlib.util
import re
import sys
from pathlib import Path

import pytest

BIN = Path(__file__).resolve().parents[1] / "bin"
GUARD_SCRIPT = BIN / "deploy-guard.py"
CLEANUP_SCRIPT = BIN / "merged-branch-cleanup.py"
DEPLOY_GUARDS_DOC = (Path(__file__).resolve().parents[2] / "skills" / "dev-bother-me-nope"
                     / "references" / "deploy-guards.md")
DELETE_BULLET = "- Deleting a protected branch on origin"
EXTRA_NAME = "qa"


def lowercase(names):
    return frozenset(name.lower() for name in names)


def drift(guard, helper):
    """(names only the guard protects, names only the cleanup helper protects), lowercase."""
    guard_names, helper_names = lowercase(guard.DELETE_PROTECTED), lowercase(helper.PROTECTED)
    return guard_names - helper_names, helper_names - guard_names


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


@pytest.fixture
def load_copy(tmp_path, monkeypatch):
    """Load a copy of a bin script with one extra line appended; the original is untouched."""

    def load(script, appended_line):
        copy = tmp_path / f"{script.stem.replace('-', '_')}_drifted.py"
        copy.write_text(f"{script.read_text()}\n{appended_line}\n")
        name = f"drifted_{copy.stem}"
        spec = importlib.util.spec_from_file_location(name, copy)
        module = importlib.util.module_from_spec(spec)
        monkeypatch.setitem(sys.modules, name, module)
        spec.loader.exec_module(module)
        return module

    return load


@pytest.fixture
def live(load_script):
    return load_script("deploy-guard"), load_script("merged-branch-cleanup")


def normalised(text):
    return " ".join(text.split())


def delete_bullet():
    doc = DEPLOY_GUARDS_DOC.read_text()
    begin = doc.index(DELETE_BULLET)
    ends = [doc.find(separator, begin + 1) for separator in ("\n- ", "\n\n")]
    return normalised(doc[begin:min(end for end in ends if end != -1)])


# ---- AC9: the live lists agree ----

def test_guard_and_cleanup_protect_the_same_branches(live):
    guard, helper = live
    assert drift(guard, helper) == (frozenset(), frozenset())
    assert guard.DELETE_PROTECTED, "the guard protects no branch at all"


# ---- AC10: the comparison bites ----

def test_parity_reports_a_name_only_the_guard_protects(live, load_copy):
    _, helper = live
    before = (digest(GUARD_SCRIPT), digest(CLEANUP_SCRIPT))
    drifted = load_copy(GUARD_SCRIPT,
                        f"DELETE_PROTECTED = DELETE_PROTECTED | frozenset({{{EXTRA_NAME!r}}})")
    assert drift(drifted, helper) == (frozenset({EXTRA_NAME}), frozenset())
    assert (digest(GUARD_SCRIPT), digest(CLEANUP_SCRIPT)) == before


def test_parity_reports_a_name_only_the_cleanup_protects(live, load_copy):
    guard, _ = live
    before = (digest(GUARD_SCRIPT), digest(CLEANUP_SCRIPT))
    drifted = load_copy(CLEANUP_SCRIPT,
                        f"PROTECTED = frozenset(PROTECTED) | frozenset({{{EXTRA_NAME!r}}})")
    assert drift(guard, drifted) == (frozenset(), frozenset({EXTRA_NAME}))
    assert (digest(GUARD_SCRIPT), digest(CLEANUP_SCRIPT)) == before


def test_parity_compares_lowercase_names(live, load_copy):
    guard, _ = live
    drifted = load_copy(CLEANUP_SCRIPT, 'PROTECTED = frozenset(PROTECTED) | frozenset({"DEV"})')
    assert "DEV" in drifted.PROTECTED
    assert drift(guard, drifted) == (frozenset(), frozenset())


# ---- AC11 / AC12: the documented lists cannot drift either ----

def test_every_protected_name_is_in_the_guard_docstring(live):
    guard, _ = live
    docstring = normalised(guard.__doc__)
    listed = re.search(r"protected branch \(([^)]*)\)", docstring)
    assert listed, "the docstring has no `protected branch (<names>)` list"
    words = frozenset(re.findall(r"[a-z]+", listed.group(1).lower()))
    assert not lowercase(guard.DELETE_PROTECTED) - words


def test_every_protected_name_is_in_the_doc_bullet(live):
    guard, _ = live
    bullet = delete_bullet()
    missing = [name for name in sorted(guard.DELETE_PROTECTED) if f"`{name}`" not in bullet]
    assert not missing, missing


def test_doc_says_the_list_is_checked_against_the_cleanup_helper():
    bullet = delete_bullet()
    assert "merged-branch-cleanup.py" in bullet
    assert "test_protected_branch_parity.py" in bullet
