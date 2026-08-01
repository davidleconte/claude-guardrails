#!/usr/bin/env python3
"""Generic advisory governance-hook engine for Claude Code. Stdlib only.

Design invariants (inherited from the quant prototype it generalizes):
  - ADVISORY, NON-BLOCKING: every path exits 0; it warns on stderr, never denies.
  - CONTEXT-ACTIVATED: a repo opts in with a `.guardrails.json` marker. No marker
    -> silent no-op. This is what stops governance from firing in unrelated repos.
  - POLICY-AS-DATA: the domain logic lives in JSON profiles, not in this code.

Subcommands (wired from thin bash hooks):
  precheck        PreToolUse/Bash — scan changed files before a matched command
  session-review  SessionEnd      — print the governance checklist for active profiles
  policy-drift    SessionEnd      — run each profile's drift check, warn on nonzero
  status          diagnostics     — show active profiles for the current repo

Test overrides (env): GUARDRAILS_REPO, GUARDRAILS_SCOPE, GUARDRAILS_CMD.
"""
from __future__ import annotations
import fnmatch
import glob
import json
import os
import re
import subprocess
import sys


def find_repo_root(start: str | None = None) -> str:
    start = start or os.getcwd()
    try:
        out = subprocess.run(["git", "-C", start, "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True)
        if out.returncode == 0 and out.stdout.strip():
            return out.stdout.strip()
    except Exception:
        pass
    return start


def engine_dir() -> str:
    return os.path.dirname(os.path.abspath(__file__))


def _read_json(path: str):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return None


def load_marker(repo: str):
    return _read_json(os.path.join(repo, ".guardrails.json"))


def load_profile(name: str, repo: str):
    # repo-local override first, then the shipped shared library.
    for cand in (os.path.join(repo, ".guardrails.d", name + ".json"),
                 os.path.normpath(os.path.join(engine_dir(), "..", "profiles", name + ".json"))):
        if os.path.isfile(cand):
            prof = _read_json(cand)
            if prof is not None:
                prof["_name"] = name
                return prof
    return None


def active_profiles(repo: str, marker):
    profs = []
    for name in (marker or {}).get("profiles", []):
        prof = load_profile(name, repo)
        if prof:
            profs.append(prof)
    return profs


def drain_stdin() -> str:
    try:
        if not sys.stdin.isatty():
            return sys.stdin.read()
    except Exception:
        pass
    return ""


def hook_command(event_json: str) -> str:
    try:
        obj = json.loads(event_json)
        return (obj.get("tool_input") or {}).get("command", "") or ""
    except Exception:
        return ""


def _candidate_files(repo: str, include, scope: str):
    files = []
    if scope == "repo":
        for pat in include or ["*"]:
            files += glob.glob(os.path.join(repo, "**", pat), recursive=True)
    else:  # "diff": only what changed (staged/unstaged/untracked)
        for args in (["diff", "--name-only", "HEAD"],
                     ["diff", "--name-only", "--cached"],
                     ["ls-files", "--others", "--exclude-standard"]):
            try:
                out = subprocess.run(["git", "-C", repo] + args, capture_output=True, text=True)
                if out.returncode == 0:
                    files += [os.path.join(repo, ln.strip()) for ln in out.stdout.splitlines() if ln.strip()]
            except Exception:
                pass
    return files


def scan_files(repo: str, include, exclude, scope: str):
    exc = [re.compile(e) for e in (exclude or [])]
    seen, out = set(), []
    for f in _candidate_files(repo, include, scope):
        if not os.path.isfile(f) or f in seen:
            continue
        rel = os.path.relpath(f, repo)
        base = os.path.basename(f)
        if include and not any(fnmatch.fnmatch(base, g) for g in include):
            continue
        if any(e.search(rel) for e in exc):
            continue
        seen.add(f)
        out.append(f)
    return out


def cmd_precheck(profs, repo, scope, command):
    for p in profs:
        pc = p.get("precheck")
        if not pc:
            continue
        trig = pc.get("trigger")
        if trig and not fnmatch.fnmatch(command.strip(), trig):
            continue
        files = scan_files(repo, pc.get("include", []), pc.get("exclude", []), scope)
        hits = []
        for rule in pc.get("rules", []):
            pat = re.compile(rule["pattern"])
            for f in files:
                try:
                    with open(f, encoding="utf-8", errors="replace") as fh:
                        for i, line in enumerate(fh, 1):
                            if pat.search(line):
                                hits.append((rule.get("severity", "med"),
                                             rule.get("label", rule["pattern"]),
                                             os.path.relpath(f, repo), i, line.strip()[:160]))
                except Exception:
                    continue
        if hits:
            hits.sort(key=lambda h: {"high": 0, "med": 1, "low": 2}.get(h[0], 1))
            sys.stderr.write(f"  ── guardrails[{p['_name']}] · {len(hits)} signal(s) avant « {command.strip()} »\n")
            for sev, label, rel, ln, code in hits:
                sys.stderr.write(f"    ⚠ [{sev}] {label}\n        {rel}:{ln}  {code}\n")
            sys.stderr.write("    → advisory : résous ou justifie avant de faire confiance (non bloquant).\n")


def cmd_session_review(profs):
    blocks = [p for p in profs if p.get("session_review")]
    if not blocks:
        return
    sys.stderr.write("  " + "─" * 58 + "\n")
    sys.stderr.write("  SESSION-END REVIEW · guardrails\n")
    for p in blocks:
        sr = p["session_review"]
        sys.stderr.write(f"  [{p['_name']}] {sr.get('when', '(toujours)')}\n")
        for d in sr.get("dispatch", []):
            sys.stderr.write(f"    • {d['agent']}\n")
            sys.stderr.write(f"        Agent(subagent_type:\"{d['agent']}\", prompt:\"{d.get('prompt', '')}\")\n")
    sys.stderr.write("  " + "─" * 58 + "\n")


def cmd_policy_drift(profs, repo):
    for p in profs:
        pd = p.get("policy_drift")
        if not pd or not pd.get("check_cmd"):
            continue
        try:
            out = subprocess.run(pd["check_cmd"], shell=True, cwd=repo, capture_output=True, text=True)
        except Exception:
            continue
        if out.returncode != 0:
            sys.stderr.write(f"  ⚠ guardrails[{p['_name']}] dérive de policy :\n")
            for ln in (out.stdout + out.stderr).splitlines():
                sys.stderr.write("      " + ln + "\n")
            if pd.get("fix_hint"):
                sys.stderr.write(f"      fix: {pd['fix_hint']}\n")


def cmd_status(profs, repo):
    names = [p["_name"] for p in profs]
    print(f"repo: {repo}")
    print("active profiles: " + (", ".join(names) if names else "(aucun — pas de .guardrails.json)"))


def main():
    argv = sys.argv[1:]
    sub = argv[0] if argv else "status"
    repo = os.environ.get("GUARDRAILS_REPO") or find_repo_root()
    event = drain_stdin()
    marker = load_marker(repo)
    scope = os.environ.get("GUARDRAILS_SCOPE") or (marker or {}).get("scan_scope", "diff")
    profs = active_profiles(repo, marker)
    try:
        if sub == "precheck":
            cmd_precheck(profs, repo, scope, os.environ.get("GUARDRAILS_CMD") or hook_command(event))
        elif sub == "session-review":
            cmd_session_review(profs)
        elif sub == "policy-drift":
            cmd_policy_drift(profs, repo)
        else:
            cmd_status(profs, repo)
    except Exception as exc:  # never let governance break a session
        sys.stderr.write(f"  · guardrails skipped ({exc})\n")
    sys.exit(0)


if __name__ == "__main__":
    main()
