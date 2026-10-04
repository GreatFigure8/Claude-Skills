"""Static quality gates for the helper scripts in assets/bin (AC 21).

Run: uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q
Ruff and the full-suite run are gates the author runs; these tests pin the properties of the
scripts themselves: executable, stdlib only, small, documented, no shared mutable state.
"""
import ast
import os
import re
import sys
from pathlib import Path

import pytest

BIN = Path(__file__).resolve().parents[1] / "bin"
SCRIPTS = [BIN / "merged-branch-cleanup.py", BIN / "repo-merge-policy.py"]
IDS = [script.name for script in SCRIPTS]
MAX_SCRIPT_LINES = 400
MAX_FUNCTION_LINES = 50
MUTABLE_FACTORIES = frozenset({"list", "dict", "set", "defaultdict", "deque", "Counter"})
MUTABLE_LITERALS = (ast.List, ast.Dict, ast.Set, ast.ListComp, ast.DictComp, ast.SetComp)


def parse(script):
    return ast.parse(script.read_text())


def module_assignments(tree):
    return [node for node in tree.body if isinstance(node, (ast.Assign, ast.AnnAssign))]


@pytest.mark.unit
@pytest.mark.parametrize("script", SCRIPTS, ids=IDS)
def test_script_is_executable_with_env_python3_shebang(script):
    assert os.access(script, os.X_OK), f"{script.name} is not executable"
    assert script.read_text().splitlines()[0] == "#!/usr/bin/env python3"


@pytest.mark.unit
@pytest.mark.parametrize("script", SCRIPTS, ids=IDS)
def test_script_imports_stdlib_only(script):
    imported = set()
    for node in ast.walk(parse(script)):
        if isinstance(node, ast.Import):
            imported.update(alias.name.split(".")[0] for alias in node.names)
        if isinstance(node, ast.ImportFrom):
            assert node.level == 0, "relative import"
            imported.add((node.module or "").split(".")[0])
    assert imported and imported <= set(sys.stdlib_module_names), imported - set(sys.stdlib_module_names)


@pytest.mark.unit
@pytest.mark.parametrize("script", SCRIPTS, ids=IDS)
def test_script_under_400_lines(script):
    assert len(script.read_text().splitlines()) < MAX_SCRIPT_LINES


@pytest.mark.unit
@pytest.mark.parametrize("script", SCRIPTS, ids=IDS)
def test_module_docstring_states_purpose_contract_and_safety(script):
    doc = ast.get_docstring(parse(script)) or ""
    assert doc.splitlines()[0].startswith(script.name), "first line must name the script"
    assert re.search(r"^Purpose:", doc, re.MULTILINE), "docstring needs a Purpose: section"
    assert re.search(r"^Contract:", doc, re.MULTILINE), "docstring needs a Contract: section"
    assert re.search(r"^Safety:", doc, re.MULTILINE), "docstring needs a Safety: section"


@pytest.mark.unit
@pytest.mark.parametrize("script", SCRIPTS, ids=IDS)
def test_functions_under_50_lines(script):
    long_ones = [
        f"{node.name} ({node.end_lineno - node.lineno + 1} lines)"
        for node in ast.walk(parse(script))
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
        and node.end_lineno - node.lineno + 1 >= MAX_FUNCTION_LINES
    ]
    assert long_ones == []


@pytest.mark.unit
@pytest.mark.parametrize("script", SCRIPTS, ids=IDS)
def test_no_global_statements_or_mutable_module_constants(script):
    tree = parse(script)
    assert not [node for node in ast.walk(tree) if isinstance(node, ast.Global)]
    mutable = []
    for node in module_assignments(tree):
        value = node.value
        is_factory = isinstance(value, ast.Call) and ast.unparse(value.func) in MUTABLE_FACTORIES
        if isinstance(value, MUTABLE_LITERALS) or is_factory:
            mutable.append(ast.unparse(node)[:60])
    assert mutable == []


@pytest.mark.unit
@pytest.mark.parametrize("script", SCRIPTS, ids=IDS)
def test_subprocess_calls_are_argument_lists_without_shell(script, subprocess_violations):
    assert subprocess_violations(script) == []
