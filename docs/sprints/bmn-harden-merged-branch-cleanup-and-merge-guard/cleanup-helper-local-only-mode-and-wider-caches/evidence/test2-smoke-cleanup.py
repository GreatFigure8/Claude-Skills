"""E2E smoke for the cleanup helper (local bare origin, tmp dir only)."""
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

WT = Path(sys.argv[1])
CLEANUP = WT / "Skills/dev-bother-me-nope/assets/bin/merged-branch-cleanup.py"
ROOT = Path(tempfile.mkdtemp(prefix="bmn-smoke-"))
ENV = {"PATH": os.environ["PATH"], "HOME": str(ROOT), "GIT_CONFIG_GLOBAL": str(ROOT / "gitconfig"),
       "GIT_CONFIG_NOSYSTEM": "1", "GIT_TERMINAL_PROMPT": "0"}
(ROOT / "gitconfig").write_text("[user]\n name=T\n email=t@e.x\n[init]\n defaultBranch=trunk\n[commit]\n gpgsign=false\n")
RESULTS = []


def git(cwd, *a, check=True):
    p = subprocess.run(["git", "-C", str(cwd), *a], env=ENV, capture_output=True, text=True)
    if check and p.returncode:
        raise SystemExit(f"git {a} failed: {p.stderr}")
    return p.stdout.strip()


def world(name):
    """origin bare + clone, `trunk` default, `dev` branch, run branch fix/run merged into dev."""
    base = ROOT / name
    base.mkdir()
    origin, clone = base / "origin.git", base / "clone"
    subprocess.run(["git", "init", "-q", "--bare", str(origin)], env=ENV, check=True)
    subprocess.run(["git", "clone", "-q", str(origin), str(clone)], env=ENV, check=True, capture_output=True)
    (clone / ".gitignore").write_text(".env\ntest-results/\nplaywright-report/\n*.tsbuildinfo\nnext-env.d.ts\n.coverage\n.DS_Store\n")
    (clone / "a.txt").write_text("a")
    git(clone, "add", "-A"); git(clone, "commit", "-qm", "init"); git(clone, "push", "-q", "origin", "trunk")
    git(clone, "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/trunk", check=False)
    git(clone, "branch", "dev"); git(clone, "push", "-q", "origin", "dev")
    git(clone, "branch", "fix/run")
    return origin, clone, base


def merge_run(clone, origin_push):
    """Make fix/run carry a commit and be merged into origin/dev."""
    git(clone, "switch", "-q", "fix/run")
    (clone / "run.txt").write_text("r")
    git(clone, "add", "-A"); git(clone, "commit", "-qm", "run")
    git(clone, "switch", "-q", "dev")
    git(clone, "merge", "-q", "--no-ff", "fix/run", "-m", "merge run")
    git(clone, "push", "-q", "origin", "dev")
    if origin_push:
        git(clone, "push", "-q", "origin", "fix/run")
    git(clone, "switch", "-q", "trunk")


def helper(clone, *args, shim_log=None):
    env = dict(ENV)
    if shim_log:
        sd = ROOT / "shim"
        sd.mkdir(exist_ok=True)
        real = shutil.which("git")
        (sd / "git").write_text(f"#!{sys.executable}\nimport json,os,sys\nopen({str(shim_log)!r},'a').write(json.dumps(sys.argv[1:])+'\\n')\nos.execv({real!r},[{real!r}]+sys.argv[1:])\n")
        os.chmod(sd / "git", 0o755)
        env["PATH"] = f"{sd}:{env['PATH']}"
    p = subprocess.run([sys.executable, str(CLEANUP), "--repo", str(clone), "--branch", "fix/run",
                        "--target", "origin/dev", *args], env=env, capture_output=True, text=True)
    try:
        out = json.loads(p.stdout)
    except Exception:
        out = {"raw": p.stdout, "err": p.stderr}
    return p.returncode, out


def check(label, ok, detail=""):
    RESULTS.append((label, bool(ok), detail))
    print(("PASS " if ok else "FAIL ") + label + (f"  [{detail}]" if not ok else ""))


def origin_sha(origin, ref="refs/heads/fix/run"):
    p = subprocess.run(["git", "-C", str(origin), "rev-parse", "--verify", "-q", ref], env=ENV, capture_output=True, text=True)
    return p.stdout.strip()


# --- AC1/2: origin copy merged, --local-only never touches it, no push
origin, clone, base = world("ac12")
merge_run(clone, origin_push=True)
before = origin_sha(origin)
log = base / "shim.log"
code, out = helper(clone, "--local-only", shim_log=log)
calls = [json.loads(l) for l in log.read_text().splitlines()] if log.exists() else []
pushes = [c for c in calls if "push" in c]
check("AC1 --local-only: exit 0, no git push run", code == 0 and not pushes, (code, pushes))
check("AC1 origin refs/heads/fix/run unchanged (merged origin copy)", origin_sha(origin) == before and before, (before, origin_sha(origin)))
rem = [l for l in out.get("left", []) if l["ref"].startswith("origin:")]
check("AC2 exactly one origin: left entry, reason 'origin copy kept: --local-only'",
      len(rem) == 1 and rem[0] == {"ref": "origin:fix/run", "why": "origin copy kept: --local-only"}, rem)
check("AC2 deleted has no origin: entry; local deleted", not any(d.startswith("origin:") for d in out.get("deleted", [])) and "local:fix/run" in out["deleted"], out)

# AC2 no remote copy -> no origin entry
origin, clone, base = world("ac2b")
merge_run(clone, origin_push=False)
code, out = helper(clone, "--local-only")
check("AC2 no remote copy: no origin: entry in left", code == 0 and not any(l["ref"].startswith("origin:") for l in out["left"]), out)

# unmerged origin copy
origin, clone, base = world("ac2c")
git(clone, "switch", "-q", "fix/run"); (clone / "x").write_text("x"); git(clone, "add", "-A"); git(clone, "commit", "-qm", "x")
git(clone, "push", "-q", "origin", "fix/run"); git(clone, "switch", "-q", "trunk")
b = origin_sha(origin)
code, out = helper(clone, "--local-only")
rem = [l for l in out["left"] if l["ref"].startswith("origin:")]
check("AC2/5 unmerged branch: origin copy entry exactly once with --local-only reason; local kept 'not merged'; origin unchanged",
      len(rem) == 1 and rem[0]["why"] == "origin copy kept: --local-only"
      and any(l["ref"] == "local:fix/run" and "not merged into origin/dev" in l["why"] for l in out["left"]) and origin_sha(origin) == b, out)

# --- AC3: .env in worktree kept
origin, clone, base = world("ac3")
merge_run(clone, origin_push=False)
wtp = base / "run-wt"
git(clone, "worktree", "add", "-q", str(wtp), "fix/run")
(wtp / ".env").write_bytes(b"SECRET=1\n")
code, out = helper(clone, "--local-only")
w = [l for l in out["left"] if l["ref"] == f"worktree:{wtp.resolve()}" or l["ref"] == f"worktree:{wtp}"]
check("AC3 unpushed branch + ignored .env: worktree dir and .env intact (R2-1)", code == 0 and (wtp / ".env").read_bytes() == b"SECRET=1\n", out)
check("AC3 left names worktree with a reason citing .env; local branch kept in left",
      bool(w) and ".env" in w[0]["why"] and any(l["ref"] == "local:fix/run" for l in out["left"]) and git(clone, "rev-parse", "--verify", "refs/heads/fix/run"), out)

# --- AC4 clean worktree removed
origin, clone, base = world("ac4")
merge_run(clone, origin_push=False)
wtp = base / "run-wt"
git(clone, "worktree", "add", "-q", str(wtp), "fix/run")
code, out = helper(clone, "--local-only")
check("AC4 clean worktree removed, local deleted (CAS), deleted lists both",
      code == 0 and not wtp.exists() and any(d.startswith("worktree:") for d in out["deleted"]) and "local:fix/run" in out["deleted"]
      and not git(clone, "rev-parse", "--verify", "-q", "refs/heads/fix/run", check=False), out)

# --- AC5 busy rebase
origin, clone, base = world("ac5")
merge_run(clone, origin_push=False)
wtp = base / "run-wt"
git(clone, "worktree", "add", "-q", str(wtp), "fix/run")
gd = Path(git(wtp, "rev-parse", "--absolute-git-dir"))
(gd / "rebase-merge").mkdir()
(gd / "rebase-merge" / "head-name").write_text("refs/heads/fix/run\n")
code, out = helper(clone, "--local-only")
loc = [l for l in out["left"] if l["ref"] == "local:fix/run"]
check("AC5 rebase in progress keeps local branch (busy_with runs in --local-only)",
      code == 0 and loc and "rebase or bisect" in loc[0]["why"] and git(clone, "rev-parse", "--verify", "refs/heads/fix/run"), out)

# --- AC6 dry-run
origin, clone, base = world("ac6")
merge_run(clone, origin_push=True)
wtp = base / "run-wt"
git(clone, "worktree", "add", "-q", str(wtp), "fix/run")
snap = lambda: (git(clone, "for-each-ref"), git(origin, "for-each-ref"), git(clone, "worktree", "list"))
s0 = snap(); log = base / "shim.log"
code, out = helper(clone, "--local-only", "--dry-run", shim_log=log)
calls = [json.loads(l) for l in log.read_text().splitlines()] if log.exists() else []
check("AC6 --local-only --dry-run: no fetch, no push, nothing changed, no origin: in deleted, origin left entry",
      code == 0 and out["dry_run"] and not any("fetch" in c or "push" in c for c in calls) and snap() == s0
      and not any(d.startswith("origin:") for d in out["deleted"])
      and [l for l in out["left"] if l["ref"].startswith("origin:")] == [{"ref": "origin:fix/run", "why": "origin copy kept: --local-only"}], out)

# --- AC7 refusals with flag + help
origin, clone, base = world("ac7")
merge_run(clone, origin_push=False)
bad = []
for args in (["--branch", "dev"], ["--branch", "main"], ["--branch", "trunk"], ["--branch", "STAGING"]):
    p = subprocess.run([sys.executable, str(CLEANUP), "--repo", str(clone), "--target", "origin/dev", *args, "--local-only"],
                       env=ENV, capture_output=True, text=True)
    if p.returncode != 2 or "error" not in p.stdout:
        bad.append((args, p.returncode, p.stdout))
p = subprocess.run([sys.executable, str(CLEANUP), "--repo", str(clone), "--branch", "fix/run", "--target", "origin/nope", "--local-only"],
                   env=ENV, capture_output=True, text=True)
if p.returncode != 2:
    bad.append(("bad target", p.returncode, p.stdout))
check("AC7 protected/default/bad-target refusals still exit 2 with --local-only", not bad, bad)
h = subprocess.run([sys.executable, str(CLEANUP), "--help"], env=ENV, capture_output=True, text=True).stdout
check("AC7 --help names --local-only", "--local-only" in h)
doc = CLEANUP.read_text().split('"""')[1]
check("AC7 docstring contract lists [--local-only]", "[--local-only" in doc and "never touches the remote" in doc)

# --- AC13 + task: leftovers only -> removed; with .env kept
origin, clone, base = world("ac13")
merge_run(clone, origin_push=False)
wtp = base / "run-wt"
git(clone, "worktree", "add", "-q", str(wtp), "fix/run")
for d in ("test-results", "playwright-report"):
    (wtp / d).mkdir(); (wtp / d / "f.txt").write_text("x")
for f in ("tsconfig.tsbuildinfo", "next-env.d.ts", ".coverage", ".DS_Store"):
    (wtp / f).write_text("x")
code, out = helper(clone, "--local-only")
check("AC13 only Next.js/Playwright leftovers: worktree removed and branch deleted",
      code == 0 and not wtp.exists() and "local:fix/run" in out["deleted"], out)
origin, clone, base = world("ac13b")
merge_run(clone, origin_push=False)
wtp = base / "run-wt"
git(clone, "worktree", "add", "-q", str(wtp), "fix/run")
(wtp / "next-env.d.ts").write_text("x"); (wtp / "test-results").mkdir(); (wtp / "test-results" / "f").write_text("x"); (wtp / ".env").write_text("K=1\n")
code, out = helper(clone, "--local-only")
check("AC13 same plus ignored .env: worktree kept with .env intact", code == 0 and (wtp / ".env").read_text() == "K=1\n" and (wtp / "next-env.d.ts").exists(), out)

# default mode (no flag) still deletes a merged origin copy (regression)
origin, clone, base = world("reg")
merge_run(clone, origin_push=True)
code, out = helper(clone)
check("regression: default mode deletes merged origin copy and local", "origin:fix/run" in out["deleted"] and "local:fix/run" in out["deleted"] and not origin_sha(origin), out)

# also the pushed-run-branch default-mode worktree with leftovers
origin, clone, base = world("reg2")
merge_run(clone, origin_push=True)
wtp = base / "run-wt"
git(clone, "worktree", "add", "-q", str(wtp), "fix/run")
(wtp / ".DS_Store").write_text("x"); (wtp / "tsconfig.tsbuildinfo").write_text("x")
code, out = helper(clone)
check("regression: default mode with only cache leftovers removes worktree", not wtp.exists() and "origin:fix/run" in out["deleted"], out)

fails = [r for r in RESULTS if not r[1]]
print(f"\nSMOKE-CLEANUP {len(RESULTS) - len(fails)} pass, {len(fails)} fail; tmp={ROOT}")
shutil.rmtree(ROOT, ignore_errors=True)
sys.exit(1 if fails else 0)
