#!/usr/bin/env python3
"""Phase-3 Batch B: machine-enforced CI security policy for this repository.

Runs as the FIRST step of the read-only verify job, so any workflow change
that violates the policy fails CI before anything else executes.

Policy:
  P1  top-level permissions are deny-all ({}), each job declares its own
  P2  verify job: permissions == {contents: read}, holds no secrets
  P3  release job: needs: verify, permissions == {contents: write}
  P4  every `uses:` is pinned to an immutable 40-hex commit SHA
  P5  no pull_request_target anywhere (untrusted PRs never get write scope)
  P6  release creation is gated on a not-yet-existing version tag
  P7  production signing gate exists (production mode fails w/o keystore)
  P8  no `overwrite_files` (published releases are never mutated)
"""
import re, sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
WF_DIR = ROOT / ".github" / "workflows"
SHA_RE = re.compile(r"uses:\s*\S+@[0-9a-f]{40}\b")

failures: list[str] = []

def fail(rule, msg):
    failures.append(f"{rule}: {msg}")

def job_uses(job):
    for step in job.get("steps", []) or []:
        u = step.get("uses")
        if u:
            yield step, u

for wf in sorted(WF_DIR.glob("*.yml")):
    text = wf.read_text(encoding="utf-8")
    try:
        doc = yaml.safe_load(text)
    except Exception as e:  # pragma: no cover
        fail("YAML", f"{wf.name} does not parse: {e}")
        continue

    # P1
    top = doc.get("permissions")
    if top != {}:
        fail("P1", f"{wf.name}: top-level permissions must be {{}} (deny-all), got {top!r}")

    jobs = doc.get("jobs", {}) or {}
    verify = jobs.get("verify")
    release = jobs.get("release")
    if verify is None or release is None:
        fail("P2", f"{wf.name}: expected verify+release jobs")
        continue

    # P2
    if (verify.get("permissions") or {}).get("contents") != "read":
        fail("P2", f"{wf.name}: verify job must declare contents: read")
    vtxt = yaml.safe_dump(verify)
    if "secrets." in vtxt:
        fail("P2", f"{wf.name}: verify job must not reference secrets")

    # P3
    if "verify" not in (release.get("needs") or []):
        fail("P3", f"{wf.name}: release job must need verify")
    if (release.get("permissions") or {}).get("contents") != "write":
        fail("P3", f"{wf.name}: release job must declare contents: write (and nothing broader)")
    extra = set((release.get("permissions") or {})) - {"contents"}
    if extra:
        fail("P3", f"{wf.name}: release job requests extra permissions: {extra}")

    # P4 — every uses pinned by SHA, in every job of every workflow
    for job in jobs.values():
        for _step, u in job_uses(job):
            if not SHA_RE.search(f"uses: {u}"):
                fail("P4", f"{wf.name}: action not SHA-pinned: {u}")

    # P5
    if "pull_request_target" in text:
        fail("P5", f"{wf.name}: pull_request_target is forbidden")

    # P6
    rel_txt = yaml.safe_dump(release)
    if "Create GitHub Release" in rel_txt:
        if "exists == 'false'" not in rel_txt and 'exists == "false"' not in rel_txt:
            fail("P6", f"{wf.name}: release step must be gated on a not-yet-existing tag")
        if "overwrite_files" in rel_txt:
            fail("P8", f"{wf.name}: overwrite_files must not be used")

    # P7
    if "Production signing gate" not in rel_txt:
        fail("P7", f"{wf.name}: production signing gate step missing")
    elif "exit 1" not in rel_txt:
        fail("P7", f"{wf.name}: production gate must fail the job without keystore")

if failures:
    print("CI POLICY VIOLATIONS:")
    for f in failures:
        print("  ✗", f)
    sys.exit(1)
print("CI policy check: PASS (P1-P8)")
