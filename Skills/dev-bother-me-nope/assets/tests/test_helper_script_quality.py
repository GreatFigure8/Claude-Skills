"""Static quality gates for the helper scripts in assets/bin (AC 21).

Run: uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q
Ruff and the full-suite run are gates the author runs; these tests pin the properties of the
scripts themselves: executable, stdlib only, small, documented, no shared mutable state.
"""
import ast
import os
import pkgutil
import re
import sys
import sysconfig
from pathlib import Path

import pytest

BIN = Path(__file__).resolve().parents[1] / "bin"
SCRIPTS = [BIN / "merged-branch-cleanup.py", BIN / "repo-merge-policy.py", BIN / "bmn-lessons.py",
           BIN / "bmn-research-score.py"]
IDS = [script.name for script in SCRIPTS]
MAX_SCRIPT_LINES = 400
MAX_FUNCTION_LINES = 50
MUTABLE_FACTORIES = frozenset({"list", "dict", "set", "defaultdict", "deque", "Counter"})
MUTABLE_LITERALS = (ast.List, ast.Dict, ast.Set, ast.ListComp, ast.DictComp, ast.SetComp)


def parse(script):
    return ast.parse(script.read_text())


def module_assignments(tree):
    return [node for node in tree.body if isinstance(node, (ast.Assign, ast.AnnAssign))]


def top_level_imports(script):
    imported = set()
    for node in ast.walk(parse(script)):
        if isinstance(node, ast.Import):
            imported.update(alias.name.split(".")[0] for alias in node.names)
        if isinstance(node, ast.ImportFrom):
            assert node.level == 0, "relative import"
            imported.add((node.module or "").split(".")[0])
    return imported


def stdlib_from_interpreter_dirs():
    """The stdlib as this interpreter installs it: builtins plus its stdlib and lib-dynload dirs."""
    paths = sysconfig.get_paths()
    dirs = {paths["stdlib"], paths["platstdlib"], os.path.join(paths["platstdlib"], "lib-dynload")}
    found = {module.name for module in pkgutil.iter_modules(sorted(dirs))}
    return frozenset(found | set(sys.builtin_module_names))


def stdlib_names():
    """sys.stdlib_module_names exists from Python 3.10; the hooks also run on macOS's 3.9."""
    names = getattr(sys, "stdlib_module_names", None)
    return frozenset(names) if names is not None else stdlib_from_interpreter_dirs()


@pytest.mark.unit
@pytest.mark.parametrize("script", SCRIPTS, ids=IDS)
def test_script_is_executable_with_env_python3_shebang(script):
    assert os.access(script, os.X_OK), f"{script.name} is not executable"
    assert script.read_text().splitlines()[0] == "#!/usr/bin/env python3"


@pytest.mark.unit
@pytest.mark.parametrize("script", SCRIPTS, ids=IDS)
def test_script_imports_stdlib_only(script):
    imported = top_level_imports(script)
    assert imported and imported <= stdlib_names(), imported - stdlib_names()


@pytest.mark.unit
@pytest.mark.parametrize("script", SCRIPTS, ids=IDS)
def test_pre_310_stdlib_fallback_accepts_the_imports_and_rejects_third_party(script):
    fallback = stdlib_from_interpreter_dirs()

    assert top_level_imports(script) <= fallback, top_level_imports(script) - fallback
    assert not {"pytest", "requests", "yaml"} & fallback


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
