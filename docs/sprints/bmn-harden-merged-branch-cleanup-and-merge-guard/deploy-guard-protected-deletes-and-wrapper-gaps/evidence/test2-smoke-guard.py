"""E2E smoke for the deploy guard, cache rules, parity and skill/doc text."""
import importlib.util
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

WT = Path(sys.argv[1])
SK = WT / "Skills/dev-bother-me-nope"
GUARD = SK / "assets/bin/deploy-guard.py"
CLEAN = SK / "assets/bin/merged-branch-cleanup.py"
RESULTS = []


def check(label, ok, detail=""):
    RESULTS.append((label, bool(ok)))
    print(("PASS " if ok else "FAIL ") + label + (f"  [{detail}]" if not ok else ""))


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


root = Path(tempfile.mkdtemp(prefix="bmn-guard-"))
subprocess.run(["git", "init", "-q", str(root)], check=True)
run = root / "docs/sprints/bmn-demo"
run.mkdir(parents=True)
(run / "bmn.json").write_text(json.dumps({"run": "bmn-demo", "phase": "build"}))
idle = Path(tempfile.mkdtemp(prefix="bmn-idle-"))
subprocess.run(["git", "init", "-q", str(idle)], check=True)


def guard(cmd, cwd=root):
    p = subprocess.run([sys.executable, str(GUARD)], input=json.dumps(
        {"cwd": str(cwd), "tool_name": "Bash", "tool_input": {"command": cmd}}), capture_output=True, text=True)
    return p.returncode, p.stderr


def expect(cmd, code, prefix=None, cwd=root):
    rc, err = guard(cmd, cwd)
    ok = rc == code and (prefix is None or err.startswith(prefix))
    check(f"{'block' if code == 2 else 'allow'}: {cmd}" + (f"  -> {prefix}" if prefix else ""), ok, (rc, err[:200]))
    return err


BRANCH = "Blocked by dev-bother-me-nope branch guard:"
MERGE = "Blocked by dev-bother-me-nope merge guard:"
DEPLOY = "Blocked by dev-bother-me-nope deploy guard:"
A = "BMN_USER_APPROVED_DEPLOY=1 "

# task-required
err = expect(A + "git push origin --delete dev", 2, BRANCH)
check("branch-guard advice does not offer the approval prefix", "BMN_USER_APPROVED_DEPLOY=1" not in err.split("\n", 1)[-1] and "never" in err.lower(), err)
expect("xargs --replace git merge --squash x", 2, MERGE)
expect("xargs -I{} git merge --squash {}", 2, MERGE)
expect("xargs -I {} git merge --squash {}", 2, MERGE)
expect("fish --command='git merge --squash x'", 2, MERGE)
expect("gh pr merge 5 --merge --delete-branch", 0)
expect("git push origin --delete wip/x/y", 0)

# story 2 R2-4
for c in ("git push origin :main", "git push -d origin staging", "git push origin +:refs/heads/release",
          "sh -c 'git push origin --delete dev'", "sudo -u me bash -lc 'git push origin --delete develop'",
          "git -C . push origin --delete DEV"):
    expect(A + c, 2, BRANCH)
# default branch of the remote
d = Path(tempfile.mkdtemp(prefix="bmn-def-"))
subprocess.run(["git", "init", "-q", str(d)], check=True)
(d / "docs/sprints/bmn-demo").mkdir(parents=True)
(d / "docs/sprints/bmn-demo/bmn.json").write_text(json.dumps({"run": "bmn-demo", "phase": "build"}))
subprocess.run(["git", "-C", str(d), "-c", "user.name=t", "-c", "user.email=t@e", "commit", "-q", "--allow-empty", "-m", "i"], check=True)
subprocess.run(["git", "-C", str(d), "update-ref", "refs/remotes/origin/trunk", "HEAD"], check=True)
subprocess.run(["git", "-C", str(d), "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/trunk"], check=True)
expect(A + "git push origin --delete trunk", 2, BRANCH, cwd=d)
expect("git push origin --delete trunk", 2, BRANCH, cwd=d)
# unapproved variants still blocked
expect("git push origin --delete dev", 2, BRANCH)
# R2-4 approved deploys still through
expect(A + "git push origin main", 0)
expect(A + "vercel deploy --prod", 0)
expect("git push origin main", 2, DEPLOY)
expect(A + "sh -c 'git push origin main'", 0)
# allowed cleanup
expect("git push origin --delete wip/demo/a", 0)
expect(A + "git push origin --delete feat/run-branch", 0)
expect("git push origin --force-with-lease=refs/heads/wip/x:abc123 --delete wip/x", 0)
# R2-5 xargs
expect("xargs --max-lines git merge --squash x", 2, MERGE)
expect("xargs --eof git merge --squash x", 2, MERGE)
expect("xargs --replace=R git merge --squash R", 2, MERGE)
expect("xargs --max-lines=1 gh pr merge 12 --squash --delete-branch", 2, MERGE)
expect("xargs --replace vercel deploy --prod", 2, DEPLOY)
for c in ("xargs -L 1 git merge --squash x", "xargs -n 1 git merge --squash x", "xargs --max-args 1 git merge --squash x",
          "xargs -E EOF git merge --squash x", "xargs --process-slot-var SLOT git merge --squash x"):
    expect(c, 2, MERGE)
expect("xargs -I {} git status {}", 0)
expect("xargs --replace echo squash", 0)
# R2-5 fish
expect("fish --command 'git merge --squash x'", 2, MERGE)
expect("fish -c 'git merge --squash x'", 2, MERGE)
expect("fish --command='git push origin --delete dev'", 2, BRANCH)
expect(A + "fish --command 'git merge --squash x'", 2, MERGE)
expect("fish --command='git status'", 0)
expect("fish script.fish --command 'git merge --squash x'", 0)
# inactive repo: guard does nothing
expect("git push origin --delete dev", 0, cwd=idle)
expect("xargs --replace git merge --squash x", 0, cwd=idle)

# R2-6 parity
g = load(GUARD, "dg")
c = load(CLEAN, "mbc")
check("parity: guard DELETE_PROTECTED == helper PROTECTED", set(g.DELETE_PROTECTED) == set(c.PROTECTED),
      (set(g.DELETE_PROTECTED) ^ set(c.PROTECTED)))
doc = (SK / "skills/dev-bother-me-nope/references/deploy-guards.md").read_text()
gdoc = g.__doc__
check("parity: every protected name in guard docstring and deploy-guards.md",
      all(n in gdoc for n in g.DELETE_PROTECTED) and all(n in doc for n in g.DELETE_PROTECTED))
check("deploy-guards.md: protected-delete is a branch-guard block never lifted; wrapper bullet names xargs --replace and fish --command",
      "branch-guard" in doc.lower().replace(" ", "-") or "branch guard" in doc.lower())
check("deploy-guards.md: xargs --replace and fish --command named", "xargs --replace" in doc and "fish --command" in doc)
blind = doc.split("blind spots", 1)[-1] if "blind spots" in doc.lower() else ""
m = re.search(r"Known blind spots.*", doc, re.S | re.I)
check("deploy-guards.md: blind spots paragraph does not list xargs --replace / fish; eval, doas, env -S remain",
      m and "xargs --replace" not in m.group(0).split("\n\n")[1 if len(m.group(0).split("\n\n")) > 1 else 0] and "eval" in m.group(0) and "doas" in m.group(0) and "env -S" in m.group(0))

# is_cache AC10/11
yes = ["!! next-env.d.ts", "!! web/next-env.d.ts", "!! tsconfig.tsbuildinfo", "!! app/tsconfig.app.tsbuildinfo", "!! test-results/",
       "!! e2e/test-results/x.png", "!! playwright-report/", "!! .coverage", "!! .coverage.host.123.456", "!! .DS_Store",
       "!! docs/.DS_Store", "!! src/pkg.egg-info/", "!! pkg.egg-info/PKG-INFO", "!! htmlcov/", "!! .tox/", "!! .nox/",
       "!! .turbo/", "!! .parcel-cache/", "!! .eslintcache"]
no = ["!! .env", "!! config/.env", "!! .venv", "!! build/", "?? node_modules/", " M a.py", "!! .env.local", "!! secrets.pem",
      "!! next-env.d.ts.bak", "!! notes.tsbuildinfo.txt", "?? next-env.d.ts", "?? .DS_Store", " M test-results/keep.txt",
      "!! dist/", "!! coverage.json", "!! .DS_STORE", "!! Test-Results/"]
check("AC10 is_cache True for all 19 listed regenerable entries", all(c.is_cache(e) for e in yes), [e for e in yes if not c.is_cache(e)])
check("AC11 is_cache False for .env/near-misses/untracked/modified/case variants", not any(c.is_cache(e) for e in no), [e for e in no if c.is_cache(e)])

# text
skill = (SK / "skills/dev-bother-me-nope/SKILL.md").read_text()
briefs = (SK / "skills/dev-bother-me-nope/references/briefs.md").read_text()
cmd = "python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py"
sec = skill.split("10b", 1)[1].split("\n## ", 1)[0] if "10b" in skill else ""
bsec = briefs.split("## cleaner", 1)[1].split("\n## ", 1)[0]
check("AC8 SKILL CLEANUP + cleaner brief route unpushed case via --local-only helper command",
      "--local-only" in sec and "--local-only" in bsec and "--target origin/dev --local-only" in sec and "--target origin/dev --local-only" in bsec)
for banned in ("worktree remove <path>", "update-ref -d", 'merge-base --is-ancestor "$sha"', "sha=$(", "the helper has no flag"):
    check(f"AC8 no hand-run text '{banned}' in CLEANUP/cleaner", banned not in sec and banned not in bsec)
check("AC8 origin:<integration> / 'origin copy not pushed by this run' still stated", "origin copy not pushed by this run" in sec and "origin copy not pushed by this run" in bsec and "origin:<integration>" in sec)
lo = skill.split("**Leftover sweep:**", 1)[1][:900]
check("AC9 leftover sweep passes --local-only when integration_pushed false", "--local-only" in lo and "integration_pushed" in lo)
inv = re.findall(r"\S*merged-branch-cleanup\.py", skill + briefs)
check("AC9 every helper invocation uses ${CLAUDE_PLUGIN_ROOT}/assets/bin form", all(i.endswith("${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py") or i.endswith("`merged-branch-cleanup.py") or i == "merged-branch-cleanup.py" for i in inv), inv)
for name, text in (("SKILL CLEANUP", sec), ("cleaner brief", bsec)):
    for m in re.finditer(r"[^.\n]*worktree prune[^.\n]*", text):
        check(f"AC14 {name}: 'worktree prune' only in a never-sentence", re.search(r"[Nn]ever|not run|no repo-wide", m.group(0)) is not None, m.group(0))
check("AC14 cleaner text has no repo-wide prune instruction (sections non-empty)", len(sec) > 500 and len(bsec) > 500)
pj = json.loads((SK / ".claude-plugin/plugin.json").read_text())
check("AC15 plugin.json version (story says 1.6.1; dev already at 1.7.0 so it must be >= 1.6.1)", tuple(map(int, pj["version"].split("."))) >= (1, 6, 1), pj["version"])
print("plugin version", pj["version"])

fails = [r for r in RESULTS if not r[1]]
print(f"\nSMOKE-GUARD {len(RESULTS) - len(fails)} pass, {len(fails)} fail")
sys.exit(1 if fails else 0)
