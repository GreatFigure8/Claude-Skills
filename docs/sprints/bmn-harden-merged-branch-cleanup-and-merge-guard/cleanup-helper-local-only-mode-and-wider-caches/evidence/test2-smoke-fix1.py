"""TEST2 smoke: FIX1 items R1-1 (--pushed), R1-2 (heads/), R1-3 (fish -C), R1-4 (doc), R1-6."""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

WT = Path(sys.argv[1])
SK = WT / "Skills/dev-bother-me-nope"
CLEAN = SK / "assets/bin/merged-branch-cleanup.py"
GUARD = SK / "assets/bin/deploy-guard.py"
ROOT = Path(tempfile.mkdtemp(prefix="bmn-fix1-"))
ENV = {"PATH": os.environ["PATH"], "HOME": str(ROOT), "GIT_CONFIG_GLOBAL": str(ROOT / "gc"),
       "GIT_CONFIG_NOSYSTEM": "1", "GIT_TERMINAL_PROMPT": "0"}
(ROOT / "gc").write_text("[user]\n name=T\n email=t@e.x\n[init]\n defaultBranch=trunk\n[commit]\n gpgsign=false\n")
RES = []


def check(label, ok, detail=""):
    RES.append(bool(ok))
    print(("PASS " if ok else "FAIL ") + label + (f"  [{detail}]" if not ok else ""))


def git(cwd, *a, check=True):
    p = subprocess.run(["git", "-C", str(cwd), *a], env=ENV, capture_output=True, text=True)
    if check and p.returncode:
        raise SystemExit(f"git {a}: {p.stderr}")
    return p.stdout.strip()


def world(name):
    base = ROOT / name
    base.mkdir()
    origin, clone = base / "o.git", base / "c"
    subprocess.run(["git", "init", "-q", "--bare", str(origin)], env=ENV, check=True)
    subprocess.run(["git", "clone", "-q", str(origin), str(clone)], env=ENV, check=True, capture_output=True)
    (clone / ".gitignore").write_text(".env\n.DS_Store\n")
    (clone / "a").write_text("a")
    git(clone, "add", "-A"); git(clone, "commit", "-qm", "i"); git(clone, "push", "-q", "origin", "trunk")
    git(clone, "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/trunk", check=False)
    git(clone, "branch", "dev"); git(clone, "push", "-q", "origin", "dev")
    git(clone, "switch", "-q", "-c", "wip/x/y")
    (clone / "w").write_text("w"); git(clone, "add", "-A"); git(clone, "commit", "-qm", "w")
    git(clone, "push", "-q", "origin", "wip/x/y")
    git(clone, "switch", "-q", "trunk")
    return origin, clone, base


def helper(clone, branch, target, *flags, log=None):
    env = dict(ENV)
    if log:
        sd = ROOT / "shim"; sd.mkdir(exist_ok=True)
        real = shutil.which("git")
        (sd / "git").write_text(f"#!{sys.executable}\nimport json,os,sys\nopen({str(log)!r},'a').write(json.dumps(sys.argv[1:])+'\\n')\nos.execv({real!r},[{real!r}]+sys.argv[1:])\n")
        os.chmod(sd / "git", 0o755)
        env["PATH"] = f"{sd}:{env['PATH']}"
    p = subprocess.run([sys.executable, str(CLEAN), "--repo", str(clone), "--branch", branch, "--target", target, *flags],
                       env=env, capture_output=True, text=True)
    try:
        return p.returncode, json.loads(p.stdout)
    except Exception:
        return p.returncode, {"raw": p.stdout, "err": p.stderr}


def osha(origin, ref):
    return subprocess.run(["git", "-C", str(origin), "rev-parse", "-q", "--verify", ref], env=ENV, capture_output=True, text=True).stdout.strip()


# R1-1: --pushed, worktree with .env kept
origin, clone, base = world("r11a")
wt = base / "wt"
git(clone, "worktree", "add", "-q", str(wt), "wip/x/y")
(wt / ".env").write_text("S=1\n")
b = osha(origin, "refs/heads/wip/x/y")
log = base / "log"
code, out = helper(clone, "wip/x/y", "origin/wip/x/y", "--pushed", log=log)
calls = [json.loads(l) for l in log.read_text().splitlines()]
check("R1-1 --pushed + ignored .env: worktree and .env kept, branch kept, no push, origin unchanged",
      code == 0 and (wt / ".env").read_text() == "S=1\n" and git(clone, "rev-parse", "-q", "--verify", "refs/heads/wip/x/y")
      and not any("push" in c for c in calls) and osha(origin, "refs/heads/wip/x/y") == b, out)
# clean worktree -> removed and local branch deleted, origin kept
origin, clone, base = world("r11b")
wt = base / "wt"
git(clone, "worktree", "add", "-q", str(wt), "wip/x/y")
(wt / ".DS_Store").write_text("x")
code, out = helper(clone, "wip/x/y", "origin/wip/x/y", "--pushed")
check("R1-1 --pushed clean (cache only) worktree: removed, local branch deleted, origin copy kept and reported",
      code == 0 and not wt.exists() and "local:wip/x/y" in out["deleted"]
      and any(l["ref"] == "origin:wip/x/y" for l in out["left"]) and osha(origin, "refs/heads/wip/x/y"), out)
# unpushed commit -> kept
origin, clone, base = world("r11c")
git(clone, "switch", "-q", "wip/x/y"); (clone / "more").write_text("m"); git(clone, "add", "-A"); git(clone, "commit", "-qm", "unpushed")
git(clone, "switch", "-q", "trunk")
code, out = helper(clone, "wip/x/y", "origin/wip/x/y", "--pushed")
check("R1-1 --pushed with an unpushed commit: local branch kept (nothing proven pushed)",
      git(clone, "rev-parse", "-q", "--verify", "refs/heads/wip/x/y") and "local:wip/x/y" not in out.get("deleted", []), out)
# wrong target refused
code, out = helper(clone, "wip/x/y", "origin/dev", "--pushed")
check("R1-1 --pushed with a target other than <remote>/<branch> is refused (exit 2)", code == 2 and "error" in out, out)
# own target without --pushed refused
code, out = helper(clone, "wip/x/y", "origin/wip/x/y")
check("R1-1 own-branch target without --pushed still refused", code == 2, out)
# move-computers text
mc = (SK / "skills/dev-bother-me-nope/references/move-computers.md").read_text()
step6 = mc.split("6. **Tidy this machine**", 1)[1].split("7. **Other repos.**", 1)[0]
check("R1-1 move-computers MOVE-OUT step 6 runs the helper with --pushed / --local-only", "--pushed" in step6 and "--local-only" in step6)
check("R1-1 move-computers step 6 only mentions hand-run remove/-D/prune inside a Never sentence",
      all(re.search(r"Never run", m.group(0)) for m in re.finditer(r"[^.]*(worktree remove|branch -D|worktree prune)[^.]*", step6, re.S) if "Never run" in step6) and "Never run `git worktree remove`" in step6)
step5 = mc.split("5. **Commit and push**", 1)[1].split("6. **Tidy", 1)[0]
check("R1-1 step 5 no longer carries a hand-run worktree remove / branch -D", "worktree remove" not in step5 and "branch -D" not in step5)

# R1-2/3 guard
root = Path(tempfile.mkdtemp(prefix="bmn-g-"))
subprocess.run(["git", "init", "-q", str(root)], check=True)
(root / "docs/sprints/bmn-demo").mkdir(parents=True)
(root / "docs/sprints/bmn-demo/bmn.json").write_text(json.dumps({"run": "bmn-demo", "phase": "build"}))


def g(cmd):
    p = subprocess.run([sys.executable, str(GUARD)], input=json.dumps({"cwd": str(root), "tool_name": "Bash", "tool_input": {"command": cmd}}),
                       capture_output=True, text=True)
    return p.returncode, p.stderr


A = "BMN_USER_APPROVED_DEPLOY=1 "
BR, MG, DP = "Blocked by dev-bother-me-nope branch guard:", "Blocked by dev-bother-me-nope merge guard:", "Blocked by dev-bother-me-nope deploy guard:"
cases = [
    ("git push origin --delete heads/dev", 2, BR), (A + "git push origin :heads/main", 2, BR),
    ("git push origin --delete refs/heads/dev", 2, BR), (A + "git push origin --delete heads/staging", 2, BR),
    ("git push origin --delete heads/feature", 0, None), ("git push origin --delete heads/wip/x/y", 0, None),
    ("git push origin HEAD:heads/main", 2, DP), (A + "git push origin HEAD:heads/main", 0, None),
    ("fish -C 'git merge --squash x' -c true", 2, MG), ("fish --init-command='git merge --squash x' -c true", 2, MG),
    ("fish --init-command 'git merge --squash x'", 2, MG), ("fish -lC 'git merge --squash x'", 2, MG),
    (A + "fish -C 'git merge --squash x' -c true", 2, MG), ("fish -C 'git status' -c true", 0, None),
    ("bash -C -c 'git status'", 0, None), ("fish script.fish -C 'git merge --squash x'", 0, None),
    ("git push origin --delete a b c d", 0, None),
]
for cmd, code, prefix in cases:
    rc, err = g(cmd)
    check(f"R1-2/3 {'block' if code else 'allow'}: {cmd}", rc == code and (prefix is None or err.startswith(prefix)), (rc, err[:160]))

# R1-4 doc
doc = (SK / "skills/dev-bother-me-nope/references/deploy-guards.md").read_text()
blind = re.search(r"\*\*Known blind spots\*\*.*?\n\n", doc, re.S).group(0)
check("R1-4 blind spots name gh api -X DELETE .../git/refs/heads/<protected> and the GitHub MCP branch tools",
      "gh api -X DELETE" in blind and "git/refs/heads/<protected>" in blind and "MCP" in blind and "branch" in blind)

# R1-6 local-only plan single place: exactly one origin: entry in each state incl. unmerged with fetch failure
origin, clone, base = world("r16")
git(clone, "remote", "set-url", "origin", str(base / "gone.git"))
code, out = helper(clone, "wip/x/y", "origin/wip/x/y", "--local-only", "--no-fetch")
check("R1-6 --local-only reports the origin copy exactly once even when origin is unreachable (no-fetch)",
      len([l for l in out.get("left", []) if l["ref"].startswith("origin:")]) <= 1, out)

print(f"\nSMOKE-FIX1 {sum(RES)} pass, {len(RES) - sum(RES)} fail")
shutil.rmtree(ROOT, ignore_errors=True)
sys.exit(0 if all(RES) else 1)
