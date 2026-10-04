#!/usr/bin/env python3
"""E2E smoke for run bmn-harden-merged-branch-cleanup-and-merge-guard (TEST1).

Everything runs in a tmp dir with a local bare origin; no real GitHub, nothing in the repo under test.
Usage: smoke.py <repo-under-test>   (a checkout at the sha under test)
"""
import ast
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(sys.argv[1]).resolve()
SKILL = REPO / "Skills" / "dev-bother-me-nope"
BIN = SKILL / "assets" / "bin"
CLEANUP = BIN / "merged-branch-cleanup.py"
GUARD = BIN / "deploy-guard.py"
SKILL_MD = SKILL / "skills" / "dev-bother-me-nope" / "SKILL.md"
BRIEFS = SKILL / "skills" / "dev-bother-me-nope" / "references" / "briefs.md"
DOC = SKILL / "skills" / "dev-bother-me-nope" / "references" / "deploy-guards.md"
PLUGIN = SKILL / ".claude-plugin" / "plugin.json"

WORK = Path(tempfile.mkdtemp(prefix="bmn-smoke-", dir=os.environ.get("SMOKE_TMP")))
REAL_GIT = shutil.which("git")
RESULTS = []


def check(label, ok, detail=""):
    RESULTS.append((label, bool(ok), detail))
    print(("PASS " if ok else "FAIL ") + label + ("" if ok else "  :: " + str(detail)[:600]))


def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


GITCONFIG = WORK / "gitconfig"
GITCONFIG.write_text("[user]\n\tname = T\n\temail = t@example.com\n[init]\n\tdefaultBranch = trunk\n"
                     "[commit]\n\tgpgsign = false\n[advice]\n\tdetachedHead = false\n")
HOME = WORK / "home"
HOME.mkdir()
SHIM_DIR = WORK / "shim"
SHIM_DIR.mkdir()
(SHIM_DIR / "git").write_text(
    f"#!{sys.executable}\nimport json, os, sys\nlog = os.environ.get('GIT_SHIM_LOG')\n"
    "if log:\n    open(log, 'a').write(json.dumps(sys.argv[1:]) + '\\n')\n"
    f"os.execv({REAL_GIT!r}, [{REAL_GIT!r}] + sys.argv[1:])\n")
(SHIM_DIR / "git").chmod(0o755)


def env(log=None):
    e = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    e.update(HOME=str(HOME), GIT_CONFIG_GLOBAL=str(GITCONFIG), GIT_CONFIG_NOSYSTEM="1",
             GIT_TERMINAL_PROMPT="0", PATH=f"{SHIM_DIR}:{e['PATH']}")
    if log:
        e["GIT_SHIM_LOG"] = str(log)
    return e


def git(cwd, *args, check_ok=True, extra_env=None):
    e = env()
    e.update(extra_env or {})
    p = subprocess.run([REAL_GIT, "-C", str(cwd), *args], capture_output=True, text=True, env=e)
    if check_ok and p.returncode:
        raise RuntimeError(f"git {args} failed: {p.stderr}")
    return p.stdout.strip()


def commit(cwd, name, text="x\n", msg=None):
    (Path(cwd) / name).parent.mkdir(parents=True, exist_ok=True)
    (Path(cwd) / name).write_text(text)
    git(cwd, "add", "-A")
    git(cwd, "commit", "-q", "-m", msg or f"add {name}")


IGNORES = ("/.env\n.env.local\nnext-env.d.ts\n*.tsbuildinfo\ntest-results/\nplaywright-report/\n"
           ".coverage\n.DS_Store\ndist/\n")


def scene(name, branch="fix/run", push=True, merge=True, worktree=True):
    """origin.git (default trunk) + clone with `dev`; run branch off dev, merged into dev."""
    root = WORK / name
    root.mkdir()
    origin = root / "origin.git"
    subprocess.run([REAL_GIT, "init", "-q", "--bare", "-b", "trunk", str(origin)], check=True, env=env())
    clone = root / "clone"
    subprocess.run([REAL_GIT, "clone", "-q", str(origin), str(clone)], check=True, env=env(),
                   capture_output=True)
    commit(clone, "README.md", "r\n")
    commit(clone, ".gitignore", IGNORES)
    git(clone, "push", "-q", "origin", "trunk")
    git(clone, "branch", "dev")
    git(clone, "push", "-q", "origin", "dev")
    git(clone, "remote", "set-head", "origin", "trunk")
    wt = root / "wt"
    git(clone, "branch", branch, "dev")
    if worktree:
        git(clone, "worktree", "add", "-q", str(wt), branch)
        commit(wt, "feature.txt", "f\n")
    else:
        git(clone, "switch", "-q", branch)
        commit(clone, "feature.txt", "f\n")
        git(clone, "switch", "-q", "trunk")
    if push:
        git(clone, "push", "-q", "origin", branch)
    if merge:
        git(clone, "switch", "-q", "dev")
        git(clone, "merge", "-q", "--no-ff", "-m", "merge run", branch)
        git(clone, "push", "-q", "origin", "dev")
        git(clone, "switch", "-q", "trunk")
    return root, clone, origin, wt


def helper(clone, branch, *flags, target="origin/dev", log=None):
    p = subprocess.run([sys.executable, str(CLEANUP), "--repo", str(clone), "--branch", branch,
                        "--target", target, *flags], capture_output=True, text=True, env=env(log))
    try:
        out = json.loads(p.stdout)
    except ValueError:
        out = {"_raw": p.stdout, "_err": p.stderr}
    return p.returncode, out


def calls(log):
    return [json.loads(l) for l in Path(log).read_text().splitlines()] if Path(log).exists() else []


def origin_sha(origin, branch):
    return git(origin, "rev-parse", "--verify", "-q", f"refs/heads/{branch}", check_ok=False)


def snapshot(clone):
    return (git(clone, "for-each-ref", "--format=%(refname) %(objectname)"),
            git(clone, "worktree", "list", "--porcelain"))


def refs_of(out, key):
    return [i["ref"] if isinstance(i, dict) else i for i in out.get(key, [])]


def wt_path(wt):
    return str(Path(wt).resolve())


# ======================================================================= STORY 1
print("=== story 1: cleanup-helper-local-only-mode-and-wider-caches")

# C1 + C2 + C4: --local-only keeps merged origin copy, no push, SHA unchanged
root, clone, origin, wt = scene("c1-merged")
log = root / "shim.log"
before = origin_sha(origin, "fix/run")
code, out = helper(clone, "fix/run", "--local-only", log=log)
pushes = [c for c in calls(log) if "push" in c]
check("S1.C1 --local-only exit 0", code == 0, out)
check("S1.C1 no git push run (shim log)", not pushes, pushes)
check("S1.C1 origin refs/heads/branch SHA unchanged (merged copy)",
      origin_sha(origin, "fix/run") == before and before != "", (before, origin_sha(origin, "fix/run")))
left_origin = [i for i in out.get("left", []) if i["ref"].startswith("origin:")]
check("S1.C2 left has exactly one origin entry with exact reason",
      left_origin == [{"ref": "origin:fix/run", "why": "origin copy kept: --local-only"}], out)
check("S1.C2 deleted has no origin: entry", not [r for r in refs_of(out, "deleted") if r.startswith("origin:")], out)
check("S1.C4 clean worktree removed + local branch deleted, listed in deleted",
      f"worktree:{wt_path(wt)}" in refs_of(out, "deleted") or f"worktree:{wt}" in refs_of(out, "deleted"),
      out)
check("S1.C4 local:<branch> in deleted and ref gone",
      "local:fix/run" in refs_of(out, "deleted") and not git(clone, "rev-parse", "--verify", "-q",
                                                              "refs/heads/fix/run", check_ok=False), out)
check("S1.C4 worktree directory gone", not Path(wt).exists())
force = [c for c in calls(log) if "--force" in c or "-f" in c]
check("S1.C4 no --force on any git call", not force, force)
cas = [c for c in calls(log) if "update-ref" in c and "-d" in c]
check("S1.C4 local delete is compare-and-swap (update-ref -d ref sha)",
      len(cas) == 1 and re.fullmatch(r"[0-9a-f]{40}", cas[0][-1] or "") is not None, cas)

# C2: unmerged origin copy
root, clone, origin, wt = scene("c2-unmerged-origin")
log = root / "shim.log"
git(wt, "switch", "-q", "--detach")  # free the branch checkout for committing on origin copy
git(clone, "switch", "-q", "--detach", "origin/fix/run")
commit(clone, "extra.txt", "e\n")
git(clone, "push", "-q", "origin", "HEAD:refs/heads/fix/run")
git(clone, "switch", "-q", "trunk")
before = origin_sha(origin, "fix/run")
code, out = helper(clone, "fix/run", "--local-only", log=log)
left_origin = [i for i in out.get("left", []) if i["ref"].startswith("origin:")]
check("S1.C2 unmerged origin copy: one origin entry, same reason",
      left_origin == [{"ref": "origin:fix/run", "why": "origin copy kept: --local-only"}], out)
check("S1.C1 unmerged origin copy: SHA unchanged, no push",
      origin_sha(origin, "fix/run") == before and not [c for c in calls(log) if "push" in c], out)

# C2: no remote copy
root, clone, origin, wt = scene("c2-no-remote", push=False)
code, out = helper(clone, "fix/run", "--local-only")
check("S1.C2 no remote copy: no origin entry in left or deleted",
      code == 0 and not [r for r in refs_of(out, "left") + refs_of(out, "deleted") if r.startswith("origin:")], out)
check("S1.C2 no remote copy: local branch + worktree still deleted",
      "local:fix/run" in refs_of(out, "deleted") and not Path(wt).exists(), out)

# C3: .env kept
for tag, push in (("c3-env-no-origin", False), ("c3-env-origin-copy", True)):
    root, clone, origin, wt = scene(tag, push=push)
    (wt / ".env").write_bytes(b"FOO=bar\n\x00bytes\n")
    before = (wt / ".env").read_bytes()
    code, out = helper(clone, "fix/run", "--local-only")
    left = {i["ref"]: i["why"] for i in out.get("left", [])}
    wl = [k for k in left if k.startswith("worktree:")]
    check(f"S1.C3[{tag}] exit 0, worktree dir and .env bytes intact",
          code == 0 and wt.exists() and (wt / ".env").exists() and (wt / ".env").read_bytes() == before, out)
    check(f"S1.C3[{tag}] left has worktree:<path> with reason naming the ignored file",
          len(wl) == 1 and ".env" in left[wl[0]] and wt.name in wl[0], out)
    check(f"S1.C3[{tag}] local branch kept, local:<branch> in left",
          "local:fix/run" in left and git(clone, "rev-parse", "--verify", "-q", "refs/heads/fix/run",
                                          check_ok=False) != "", out)
    check(f"S1.C3[{tag}] deleted has nothing", not out.get("deleted"), out)

# C5: rebase in progress / bisect / unmerged
def busy_scene(tag, kind):
    root, clone, origin, wt = scene(tag, push=False)
    commit(wt, "second.txt", "2\n")
    git(clone, "switch", "-q", "dev")
    git(clone, "merge", "-q", "--no-ff", "-m", "merge again", "fix/run")
    git(clone, "switch", "-q", "trunk")
    git(clone, "push", "-q", "origin", "dev")
    if kind == "rebase":
        git(wt, "rebase", "-i", "HEAD~2", extra_env={"GIT_SEQUENCE_EDITOR": "sed -i.bak 's/^pick/edit/'",
                                                      "GIT_EDITOR": "true"})
    else:
        git(wt, "bisect", "start")
    return root, clone, origin, wt


for kind in ("rebase", "bisect"):
    res = {}
    for mode in ("default", "local"):
        root, clone, origin, wt = busy_scene(f"c5-{kind}-{mode}", kind)
        flags = ("--local-only",) if mode == "local" else ()
        code, out = helper(clone, "fix/run", *flags)
        res[mode] = (code, {i["ref"]: i["why"] for i in out.get("left", [])},
                     git(clone, "rev-parse", "--verify", "-q", "refs/heads/fix/run", check_ok=False))
    code, left, sha = res["local"]
    check(f"S1.C5[{kind}] --local-only keeps the local branch with the busy reason",
          code == 0 and "local:fix/run" in left and "in progress" in left["local:fix/run"] and sha != "", res["local"])
    dleft = res["default"][1]
    check(f"S1.C5[{kind}] same reason as the default mode",
          left.get("local:fix/run", "").split(" (")[0] == dleft.get("local:fix/run", "x").split(" (")[0], (res))

root, clone, origin, wt = scene("c5-unmerged", merge=False, push=False)
code, out = helper(clone, "fix/run", "--local-only")
left = {i["ref"]: i["why"] for i in out.get("left", [])}
check("S1.C5 unmerged local branch kept with 'not merged into'",
      code == 0 and "not merged into" in left.get("local:fix/run", "") and wt.exists(), out)

# C6: --local-only --dry-run
root, clone, origin, wt = scene("c6-dry")
log = root / "shim.log"
snap0 = snapshot(clone)
osha = origin_sha(origin, "fix/run")
code, out = helper(clone, "fix/run", "--local-only", "--dry-run", log=log)
check("S1.C6 dry-run: exit 0, dry_run true", code == 0 and out.get("dry_run") is True, out)
check("S1.C6 dry-run: no <remote>: entry in deleted, left has the kept-copy entry",
      not [r for r in refs_of(out, "deleted") if r.startswith("origin:")]
      and {"ref": "origin:fix/run", "why": "origin copy kept: --local-only"} in out.get("left", []), out)
fetches = [c for c in calls(log) if "fetch" in c]
check("S1.C6 dry-run runs no fetch", not fetches, fetches)
mut = [c for c in calls(log) if any(w in c for w in ("push", "update-ref", "remove", "branch", "config"))
       and c[2:3] != ["config"]]
check("S1.C6 dry-run: no mutating git call", not [c for c in calls(log)
      if any(w in c for w in ("push", "update-ref", "remove", "fetch", "prune"))], calls(log))
check("S1.C6 dry-run: every ref/worktree identical, origin unchanged",
      snapshot(clone) == snap0 and origin_sha(origin, "fix/run") == osha and wt.exists())
check("S1.C6 dry-run lists the local deletions in the plan",
      "local:fix/run" in refs_of(out, "deleted"), out)

# C7: docstring, --help, refusals with the flag
mod = load_module(CLEANUP, "mbc")
doc = mod.__doc__
contract = [l for l in doc.splitlines() if "[--local-only]" in l]
check("S1.C7 docstring Contract line lists [--local-only]", len(contract) == 1, doc[:400])
check("S1.C7 docstring says remote copy never touched and reported in left",
      "never touches the remote" in doc.replace("\n", " ").replace("  ", " ") and "left" in doc, doc[:900])
h = subprocess.run([sys.executable, str(CLEANUP), "--help"], capture_output=True, text=True)
check("S1.C7 --help names --local-only", "--local-only" in h.stdout, h.stdout[:300])

root, clone, origin, wt = scene("c7-refuse")
snap0 = snapshot(clone)
refusals = [("--branch", "main"), ("--branch", "DEV"), ("--branch", "release"), ("--branch", "trunk"),
            ("--branch", "-x"), ("--branch", "refs/heads/x"), ("--target", "-x"), ("--target", "HEAD~0"),
            ("--target", "fix/run")]
for kind_, val in refusals:
    branch = val if kind_ == "--branch" else "fix/run"
    target = val if kind_ == "--target" else "origin/dev"
    p = subprocess.run([sys.executable, str(CLEANUP), "--repo", str(clone), "--branch", branch, "--target",
                        target, "--local-only"], capture_output=True, text=True, env=env())
    try:
        err = json.loads(p.stdout).get("error")
    except ValueError:
        err = None
    check(f"S1.C7 refusal with --local-only: {kind_} {val!r} -> exit 2 + error", p.returncode == 2 and err, (p.stdout, p.stderr))
check("S1.C7 refusals changed nothing", snapshot(clone) == snap0)
p = subprocess.run([sys.executable, str(CLEANUP), "--repo", str(clone), "--branch", "fix/run", "--target",
                    "origin/dev", "--local-onl"], capture_output=True, text=True, env=env())
check("S1.C7 abbreviated --local-onl is refused (allow_abbrev off)", p.returncode == 2, (p.stdout, p.stderr))

# C8 / C9 / C14 text
skill = SKILL_MD.read_text()
briefs = BRIEFS.read_text()


def section(text, start_pat, end_pat):
    m = re.search(start_pat, text)
    n = re.search(end_pat, text[m.end():])
    return text[m.start(): m.end() + (n.start() if n else len(text))]


cl_skill = section(skill, r"### 10b · CLEANUP", r"\n### 11 ")
cl_brief = section(briefs, r"## cleaner ", r"\n## db-sync")
cmd = "python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py --repo %s --branch %s --target origin/dev --local-only"
check("S1.C8 SKILL.md CLEANUP step 2 has the --local-only command",
      cmd % ("<main checkout>", "<integration>") in cl_skill, cl_skill[-1500:])
check("S1.C8 cleaner brief step 2 has the --local-only command",
      cmd % ("{repo_path}", "{integration}") in cl_brief)
for needle in ("worktree remove <path>", "update-ref -d", 'merge-base --is-ancestor "$sha"', "sha=$(",
               "the helper has no flag"):
    check(f"S1.C8 hand-run text gone from both: {needle!r}", needle not in cl_skill and needle not in cl_brief)
for label, text in (("SKILL", cl_skill), ("brief", cl_brief)):
    flat = " ".join(text.split())
    check(f"S1.C8 {label}: origin copy stays + listed as origin:<integration>",
          "origin copy not pushed by this run" in flat and re.search(r"`origin:(<integration>|\{integration\})`", flat) is not None
          or re.search(r"origin:(<integration>|\{integration\})", flat) is not None and "origin copy not pushed by this run" in flat, flat[-900:])
    check(f"S1.C8 {label}: local branch and every worktree still deleted",
          "local branch and every worktree on it are still deleted" in flat, flat[-900:])
leftover = section(skill, r"\*\*Leftover sweep:\*\*", r"\n\nA run resumed")
check("S1.C9 Leftover sweep passes --local-only when integration_pushed false",
      "--local-only" in leftover and "integration_pushed" in leftover and "python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/" in leftover, leftover)
inv = re.findall(r"(\S+)\s+\$?\{?CLAUDE_PLUGIN_ROOT\}?/assets/bin/merged-branch-cleanup\.py", skill + briefs)
invalid = [m.group(0) for m in re.finditer(r"[^\s`]*merged-branch-cleanup\.py", skill + briefs)
           if not m.group(0).startswith("${CLAUDE_PLUGIN_ROOT}/assets/bin/") and m.group(0) != "merged-branch-cleanup.py"]
check("S1.C9 no bare-path helper invocation (only plugin-root form or the bare name)", not invalid, invalid)

prune_hits = []
for label, text in (("SKILL 10b", cl_skill), ("brief", cl_brief)):
    for m in re.finditer(r"worktree prune", text):
        before_txt = " ".join(text[max(0, m.start() - 60): m.start()].split())
        if not re.search(r"[Nn]ever (run )?`?(git)? ?$", before_txt):
            prune_hits.append((label, before_txt))
check("S1.C14 no 'worktree prune' in CLEANUP text except as a never-run sentence", not prune_hits, prune_hits)
check("S1.C14 cleaner text has no repo-wide prune: still says never run it",
      "Never run `git worktree prune`" in cl_skill.replace("\n   ", " ") or "Never run `git worktree prune`" in " ".join(cl_skill.split()), "")
check("S1.C14 helper never runs worktree prune",
      "prune" not in re.sub(r"(--prune|prunes other|never forces|\"fetch\", \"--prune\")", "", CLEANUP.read_text().split('"""')[2]),
      "")
check("S1.C14 helper docstring: never ... prunes other worktrees", "prunes other worktrees" in doc)

# C10 / C11 / C12 is_cache
POS = ["!! next-env.d.ts", "!! web/next-env.d.ts", "!! tsconfig.tsbuildinfo", "!! app/tsconfig.app.tsbuildinfo",
       "!! test-results/", "!! e2e/test-results/x.png", "!! playwright-report/", "!! .coverage",
       "!! .coverage.host.123.456", "!! .DS_Store", "!! docs/.DS_Store", "!! src/pkg.egg-info/",
       "!! pkg.egg-info/PKG-INFO", "!! htmlcov/", "!! .tox/", "!! .nox/", "!! .turbo/", "!! .parcel-cache/",
       "!! .eslintcache"]
NEG = ["!! .env", "!! config/.env", "!! .venv", "!! build/", "?? node_modules/", " M tracked.py",
       "!! .env.local", "!! secrets.pem", "!! next-env.d.ts.bak", "!! notes.tsbuildinfo.txt", "?? next-env.d.ts",
       "?? .DS_Store", " M test-results/keep.txt", "!! dist/", "!! coverage.json",
       "!! NEXT-ENV.D.TS", "!! .ds_store", "!! Test-Results/", "!! my-test-results/", "!! test-results-old/",
       "!! xnext-env.d.ts", "!! a.coverage", "!! .coveragerc", "!! .env.coverage"]
bad = [e for e in POS if not mod.is_cache(e)]
check("S1.C10 is_cache True for all 19 listed ignored entries", not bad, bad)
bad = [e for e in NEG if mod.is_cache(e)]
check("S1.C11 is_cache False for all existing + near-miss entries", not bad, bad)
check("S1.C12 cache rules are immutable named constants (tuple/frozenset)",
      isinstance(mod.CACHE_DIRS, (tuple, frozenset)) and isinstance(mod.CACHE_FILES, (tuple, frozenset)), "")
mut_globals = [n for n, v in vars(mod).items() if not n.startswith("__") and isinstance(v, (list, dict, set, bytearray))]
check("S1.C12 no mutable module-level state", not mut_globals, mut_globals)
tree = ast.parse(CLEANUP.read_text())
check("S1.C12 no global statements", not [n for n in ast.walk(tree) if isinstance(n, ast.Global)])

# C13 caches only -> removed; plus .env -> kept
root, clone, origin, wt = scene("c13-cache-only")
for rel in ("next-env.d.ts", "web/next-env.d.ts", "tsconfig.tsbuildinfo", "test-results/a.png",
            "e2e/test-results/b.png", "playwright-report/index.html", ".coverage", ".DS_Store"):
    (wt / rel).parent.mkdir(parents=True, exist_ok=True)
    (wt / rel).write_text("x")
code, out = helper(clone, "fix/run", "--local-only")
check("S1.C13 worktree with only Next.js/Playwright leftovers is removed, branch deleted (local-only)",
      code == 0 and not wt.exists() and "local:fix/run" in refs_of(out, "deleted") and not out["left"][1:] , out)
root, clone, origin, wt = scene("c13-cache-only-default")
for rel in ("next-env.d.ts", "tsconfig.tsbuildinfo", "test-results/a.png", "playwright-report/index.html",
            ".coverage", ".DS_Store"):
    (wt / rel).parent.mkdir(parents=True, exist_ok=True)
    (wt / rel).write_text("x")
code, out = helper(clone, "fix/run")
check("S1.C13 default mode: leftovers-only worktree removed, local + origin copy deleted",
      code == 0 and not wt.exists() and {"local:fix/run", "origin:fix/run"} <= set(refs_of(out, "deleted")), out)
root, clone, origin, wt = scene("c13-cache-plus-env")
for rel in ("next-env.d.ts", "tsconfig.tsbuildinfo", "test-results/a.png", "playwright-report/index.html",
            ".coverage", ".DS_Store"):
    (wt / rel).parent.mkdir(parents=True, exist_ok=True)
    (wt / rel).write_text("x")
(wt / ".env").write_text("K=v\n")
code, out = helper(clone, "fix/run", "--local-only")
check("S1.C13 same worktree plus ignored .env is kept with .env intact",
      code == 0 and wt.exists() and (wt / ".env").read_text() == "K=v\n" and not out.get("deleted"), out)
# near misses in a real worktree
for tag, rel in (("dist", "dist/app.js"), ("env.local", ".env.local"), ("untracked-next-env", None)):
    root, clone, origin, wt = scene("c13-near-" + tag.replace(".", "-"))
    if rel:
        (wt / rel).parent.mkdir(parents=True, exist_ok=True)
        (wt / rel).write_text("x")
    else:
        # untracked, not ignored: name is cache-like but only in a subdir not covered by ignore rules
        (wt / "sub").mkdir()
        (wt / "sub" / ".eslintrc-untracked").write_text("x")
    code, out = helper(clone, "fix/run", "--local-only")
    check(f"S1.C13 near-miss {tag} keeps the worktree", code == 0 and wt.exists() and not out.get("deleted"), out)

# C15 / C16
check("S1.C15 plugin.json version is 1.6.1", json.loads(PLUGIN.read_text())["version"] == "1.6.1")
n_lines = len(CLEANUP.read_text().splitlines())
check("S1.C16 helper under 400 lines", n_lines < 400, n_lines)


def long_functions(path, limit=50):
    t = ast.parse(Path(path).read_text())
    return [(n.name, n.end_lineno - n.lineno + 1) for n in ast.walk(t)
            if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)) and n.end_lineno - n.lineno + 1 >= limit]


check("S1.C16 every helper function under 50 lines", not long_functions(CLEANUP), long_functions(CLEANUP))
p3 = subprocess.run(["/usr/bin/python3", str(CLEANUP), "--help"], capture_output=True, text=True)
check("S1.C16 helper runs on /usr/bin/python3 3.9", p3.returncode == 0 and "--local-only" in p3.stdout, p3.stderr[:300])

# ======================================================================= STORY 2
print("=== story 2: deploy-guard-protected-deletes-and-wrapper-gaps")
root, clone, origin, wt = scene("guard")
run = clone / "docs" / "sprints" / "bmn-demo"
run.mkdir(parents=True)
(run / "bmn.json").write_text(json.dumps({"run": "bmn-demo", "phase": "build"}))
inactive = WORK / "guard-inactive"
inactive.mkdir()
subprocess.run([REAL_GIT, "init", "-q", str(inactive)], check=True, env=env())


def hook(command, cwd=clone):
    p = subprocess.run([sys.executable, str(GUARD)], input=json.dumps(
        {"cwd": str(cwd), "tool_name": "Bash", "tool_input": {"command": command}}),
        capture_output=True, text=True, env=env())
    return p.returncode, p.stderr


def blocked(label, cmd, prefix=None, absent=None, cwd=clone):
    rc, err = hook(cmd, cwd)
    ok = rc == 2 and (prefix is None or err.startswith(prefix)) and (absent is None or absent not in err)
    check(label + f" :: {cmd}", ok, (rc, err))


def allowed(label, cmd, cwd=clone):
    rc, err = hook(cmd, cwd)
    check(label + f" :: {cmd}", rc == 0, (rc, err))


BR = "Blocked by dev-bother-me-nope branch guard:"
MG = "Blocked by dev-bother-me-nope merge guard:"
DG = "Blocked by dev-bother-me-nope deploy guard:"
A = "BMN_USER_APPROVED_DEPLOY=1 "
for cmd in (A + "git push origin --delete dev", A + "git push origin :main", A + "git push -d origin staging",
            A + "git push origin +:refs/heads/release", A + "sh -c 'git push origin --delete dev'",
            A + "sudo -u me bash -lc 'git push origin --delete develop'", A + "git -C . push origin --delete DEV",
            A + "git push origin --delete trunk",  # remote's default branch
            ):
    blocked("S2.C1 approved protected delete blocked w/ branch-guard prefix, no approval advice", cmd, BR,
            absent="BMN_USER_APPROVED_DEPLOY")
rc, err = hook(A + "git push origin --delete dev")
check("S2.C2 message names the refspec + 'deletes a protected branch'", "deletes a protected branch" in err and "dev" in err, err)
check("S2.C2 message says Jonathan deletes it himself / never inside a run",
      "Jonathan" in err and ("never" in err.lower()), err)
blocked("S2.C2 unapproved protected delete -> branch guard", "git push origin --delete dev", BR, absent="BMN_USER_APPROVED_DEPLOY")
allowed("S2.C3 approved deploy push passes", A + "git push origin main")
allowed("S2.C3 approved vercel deploy --prod passes", A + "vercel deploy --prod")
allowed("S2.C3 approved shell deploy passes", A + "sh -c 'git push origin main'")
blocked("S2.C3 unapproved push to main -> deploy guard", "git push origin main", DG)
for cmd in ("git push origin --delete wip/demo/a", A + "git push origin --delete feat/run-branch",
            "git push origin --force-with-lease=refs/heads/wip/x:" + "a" * 40 + " --delete wip/x",
            "git push origin --delete wip/x/y", "git push origin dev", "git push origin :wip/x",
            "git branch -D wip/x", "git worktree remove /tmp/x", "git worktree prune",
            "gh pr merge 5 --merge --delete-branch", "git merge --no-ff x"):
    allowed("S2.C4 allowed cleanup", cmd)

for cmd, pre in (("xargs --replace git merge --squash x", MG), ("xargs --max-lines git merge --squash x", MG),
                 ("xargs --eof git merge --squash x", MG), ("xargs --replace=R git merge --squash R", MG),
                 ("xargs --max-lines=1 gh pr merge 12 --squash --delete-branch", MG),
                 ("xargs --replace vercel deploy --prod", DG),
                 ("xargs -I{} git merge --squash {}", MG)):
    blocked("S2.C5 xargs GNU optional-value long flags", cmd, pre)
for cmd in ("xargs -I {} git merge --squash {}", "xargs -L 1 git merge --squash x", "xargs -n 1 git merge --squash x",
            "xargs --max-args 1 git merge --squash x", "xargs -E EOF git merge --squash x",
            "xargs --process-slot-var SLOT git merge --squash x"):
    blocked("S2.C6 value-taking xargs flags still consume", cmd, MG)
for cmd in ("xargs -I {} git status {}", "xargs --replace echo squash"):
    allowed("S2.C6 benign xargs allowed", cmd)
for cmd in ("fish --command='git merge --squash x'", "fish --command 'git merge --squash x'",
            "fish -c 'git merge --squash x'", A + "fish --command 'git merge --squash x'"):
    blocked("S2.C7 fish command string read (merge)", cmd, MG)
blocked("S2.C7 fish --command push --delete dev -> branch guard", "fish --command='git push origin --delete dev'", BR)
for cmd in ("fish --command='git status'", "fish script.fish --command 'git merge --squash x'"):
    allowed("S2.C7 fish benign/argument not read", cmd)
for sh in ("sh", "bash", "zsh", "dash", "ksh"):
    blocked(f"S2.C7 --command read for every shell ({sh})", f"{sh} --command 'git merge --squash x'", MG)

# run-context required
blocked("RUNCTX approved delete dev", A + "git push origin --delete dev", BR)
blocked("RUNCTX xargs --replace squash", "xargs --replace git merge --squash x", MG)
blocked("RUNCTX xargs -I{} squash", "xargs -I{} git merge --squash {}", MG)
blocked("RUNCTX fish --command squash", "fish --command='git merge --squash x'", MG)
allowed("RUNCTX gh pr merge allowed", "gh pr merge 5 --merge --delete-branch")
allowed("RUNCTX delete wip branch allowed", "git push origin --delete wip/x/y")
allowed("RUNCTX inactive repo: guard does nothing outside a run", "git push origin --delete dev", cwd=inactive)

# C8 / C12 docs
dtxt = DOC.read_text()
dflat = " ".join(dtxt.split())
blind = section(dtxt, r"\*\*Known blind spots\*\*", r"\n## How the work stays")
bullet = section(dtxt, r"- Deleting a protected branch on origin", r"\n\n\*\*Allowed")
check("S2.C8 wrapper bullet names xargs --replace and fish -c / --command",
      "xargs --replace" in dtxt and "fish -c" in dtxt and "fish --command" in dtxt, "")
check("S2.C8 blind spots paragraph does not list xargs --replace / fish --command as blind",
      "xargs --replace" not in blind and "fish --command" not in blind and "fish -c '" not in blind, blind[:700])
for needle in ("eval", "doas", "env -S"):
    check(f"S2.C8 blind spot still listed: {needle}", needle in blind)
check("S2.C12 protected-delete bullet: branch-guard block never lifted by the prefix",
      "branch-guard" in " ".join(bullet.split()) and "never lifts" in " ".join(bullet.split())
      and "This is a deploy-guard block, not a merge-guard one" not in dflat, bullet)
check("S2.C12 'approval prefix does not apply' paragraph covers protected deletes",
      re.search(r"approval prefix does not apply.*protected", dflat) is not None)
check("S2.C12 doc says list checked against merged-branch-cleanup.py by a test",
      "test_protected_branch_parity" in dflat and "merged-branch-cleanup.py" in dflat)
gmod = load_module(GUARD, "dg")
gdoc = " ".join(gmod.__doc__.split())
check("S2.C12 guard docstring says the same (branch guard never lifted + parity)",
      "branch guard" in gdoc and "approved deploy or not" in gdoc and "test_protected_branch_parity" in gdoc, gdoc[:300])

# C9 / C10 / C11 parity
helper_mod = load_module(CLEANUP, "mbc2")
check("PARITY guard DELETE_PROTECTED == helper PROTECTED (lowercase sets)",
      {n.lower() for n in gmod.DELETE_PROTECTED} == {n.lower() for n in helper_mod.PROTECTED},
      (sorted(gmod.DELETE_PROTECTED), sorted(helper_mod.PROTECTED)))
check("PARITY eight names", len(gmod.DELETE_PROTECTED) == 8 and len(helper_mod.PROTECTED) == 8)
src = GUARD.read_text()
mut = WORK / "mutated"
mut.mkdir()
(mut / "deploy-guard.py").write_text(src.replace('frozenset({"dev", "develop", "staging"})',
                                                 'frozenset({"dev", "develop", "staging", "qa"})'))
mg = load_module(mut / "deploy-guard.py", "dg_mut")
check("PARITY mutated guard copy reports exactly {'qa'} guard-only",
      {n.lower() for n in mg.DELETE_PROTECTED} - {n.lower() for n in helper_mod.PROTECTED} == {"qa"})
hsrc = CLEANUP.read_text()
(mut / "merged-branch-cleanup.py").write_text(hsrc.replace('"staging"})', '"staging", "qa"})', 1))
mh = load_module(mut / "merged-branch-cleanup.py", "mbc_mut")
check("PARITY mutated helper copy reports exactly {'qa'} helper-only",
      {n.lower() for n in mh.PROTECTED} - {n.lower() for n in gmod.DELETE_PROTECTED} == {"qa"})
check("PARITY every protected name appears in guard docstring and doc bullet",
      all(n in gmod.__doc__ for n in gmod.DELETE_PROTECTED) and all(n in bullet for n in gmod.DELETE_PROTECTED),
      [n for n in gmod.DELETE_PROTECTED if n not in gmod.__doc__ or n not in bullet])
check("S2.C13 guard < 800 lines, no function >= 50 lines",
      len(src.splitlines()) < 800 and not long_functions(GUARD), (len(src.splitlines()), long_functions(GUARD)))
p3 = subprocess.run(["/usr/bin/python3", str(GUARD)], input="{}", capture_output=True, text=True)
check("S2.C13 guard runs on /usr/bin/python3 3.9", p3.returncode == 0, p3.stderr[:300])

# ------------------------------------------------------------- adversarial probes (not criteria)
print("=== probes beyond the criteria")
PROBES_BLOCK = [
    ("git push origin :refs/heads/dev", BR), ("git push --delete origin dev", BR),
    (A + "git push --delete origin Dev", BR), ("git push origin --delete refs/heads/main", BR),
    ("git push origin --delete wip/x dev", BR), (A + "env git push origin --delete dev", BR),
    (A + "xargs --replace git push origin --delete dev", BR),
    ("xargs --null git merge --squash x", MG), ("xargs -r git merge --squash x", MG),
    ("xargs -0 -n1 git merge --squash", MG), ("xargs --max-procs 4 git merge --squash x", MG),
    ("xargs --no-run-if-empty git merge --squash x", MG), ("xargs -t -r --verbose git merge --squash x", MG),
    ("xargs -i git merge --squash {}", MG), ("xargs -l git merge --squash x", MG), ("xargs -e git merge --squash x", MG),
    ("find . | xargs --replace git push origin --delete dev", BR),
    ("fish --login --command='git merge --squash x'", MG), ("fish -lc 'git merge --squash x'", MG),
    ("fish --command 'git push origin --delete main'", BR),
    ("timeout 5 xargs --replace git merge --squash x", MG), ("sudo -u me fish --command 'git merge --squash x'", MG),
    ("fish --command='fish --command=\"git merge --squash x\"'", MG),
    ("xargs --replace git push origin main", DG),
    ("xargs --replace -t git merge --squash x", MG),
]
for cmd, pre in PROBES_BLOCK:
    rc, err = hook(cmd)
    check("PROBE blocked :: " + cmd, rc == 2 and (pre is None or err.startswith(pre)), (rc, err))
for cmd in ("xargs --replace git status", "xargs --max-lines=1 git log", "fish --command='git log'",
            "echo xargs --replace git merge --squash x", "git push origin --delete wip/dev", "git push origin --delete dev-x",
            "git push origin --delete feature/dev", "git push origin :wip/main/x"):
    rc, err = hook(cmd)
    check("PROBE allowed :: " + cmd, rc == 0, (rc, err))

# ------------------------------------------------------------- summary
passed = sum(1 for _, ok, _ in RESULTS if ok)
failed = [(l, d) for l, ok, d in RESULTS if not ok]
print(f"\nSUMMARY pass={passed} fail={len(failed)} work={WORK}")
for l, d in failed:
    print("FAILED:", l, "::", str(d)[:400])
sys.exit(1 if failed else 0)
