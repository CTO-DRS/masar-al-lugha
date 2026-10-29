#!/usr/bin/env python3
"""Machine-enforced CI security policy for this repository.

Runs as the FIRST step of the read-only verify job, so any workflow change
that violates the policy fails CI before anything else executes.
Also self-tested (``--self-test``): positive and negative fixtures prove the
checker REJECTS violating workflows, not merely that it recognises keys.

Policy:
  P1   top-level permissions are deny-all ({}), each job declares its own
  P2   verify job: permissions == {contents: read}, holds no secrets
  P3   release job: needs: verify, permissions == {contents: write} only
  P4   every `uses:` is pinned to an immutable 40-hex commit SHA
  P5   no pull_request_target anywhere (untrusted PRs never get write scope)
  P6   release creation is gated on a not-yet-existing version tag
  P7   production signing gate exists (production mode fails w/o keystore)
  P8   no `overwrite_files` (published releases are never mutated)
  P9   every checkout step sets persist-credentials: false
  P10  release job is ref-restricted (no workflow_dispatch off main) and the
       publish step only fires on a push to main
  P11  anti shell-injection: run: steps never inline ${{ inputs./steps./
       github.event }}; a version-format validation step sits between
       "Read app version" and the first consumer of those outputs
  P12  the APK artifact upload declares retention-days
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
WF_DIR = ROOT / ".github" / "workflows"
SHA_RE = re.compile(r"@\s*[0-9a-f]{40}\b")
INLINE_CTX_RE = re.compile(r"\$\{\{\s*(inputs\.|steps\.|github\.event\.)")


def check_workflow(wf_name: str, text: str) -> list[str]:
    """Return the list of policy violations for one workflow document."""
    failures: list[str] = []

    def fail(rule: str, msg: str) -> None:
        failures.append(f"{rule}: {msg}")

    try:
        doc = yaml.safe_load(text)
    except Exception as e:
        fail("YAML", f"{wf_name} does not parse: {e}")
        return failures
    if not isinstance(doc, dict):
        fail("YAML", f"{wf_name}: not a mapping document")
        return failures

    # P1 — deny-all at the top level
    if doc.get("permissions") != {}:
        fail("P1", f"{wf_name}: top-level permissions must be {{}} (deny-all), got {doc.get('permissions')!r}")

    jobs = doc.get("jobs") or {}
    verify = jobs.get("verify")
    release = jobs.get("release")
    if verify is None or release is None:
        fail("P2", f"{wf_name}: expected verify+release jobs")
        return failures

    # P2 — verify stays read-only and secret-free
    if (verify.get("permissions") or {}).get("contents") != "read":
        fail("P2", f"{wf_name}: verify job must declare contents: read")
    vtxt = yaml.safe_dump(verify)
    if "secrets." in vtxt:
        fail("P2", f"{wf_name}: verify job must not reference secrets")

    # P3 — release is the only write-scoped job and depends on verify
    if "verify" not in (release.get("needs") or []):
        fail("P3", f"{wf_name}: release job must need verify")
    rel_perms = release.get("permissions") or {}
    if rel_perms.get("contents") != "write":
        fail("P3", f"{wf_name}: release job must declare contents: write (and nothing broader)")
    if set(rel_perms) - {"contents"}:
        fail("P3", f"{wf_name}: release job requests extra permissions: {set(rel_perms) - {'contents'}}")

    # P4 — every action pinned to an immutable SHA, in every job
    for job in jobs.values():
        for step in (job.get("steps") or []):
            u = step.get("uses")
            if u and not SHA_RE.search(u):
                fail("P4", f"{wf_name}: action not SHA-pinned: {u}")

    # P5 — pull_request_target is forbidden outright
    if "pull_request_target" in text:
        fail("P5", f"{wf_name}: pull_request_target is forbidden")

    rel_txt = yaml.safe_dump(release)
    # safe_dump wraps long lines and can split key phrases (e.g. "exit 1")
    # across a line break — normalise whitespace before any substring check.
    rel_norm = re.sub(r"\s+", " ", rel_txt)
    publish_gated = "Create GitHub Release" in rel_norm

    # P6 — publish only for a not-yet-existing tag
    if publish_gated:
        if "exists == 'false'" not in rel_norm and 'exists == "false"' not in rel_norm:
            fail("P6", f"{wf_name}: release step must be gated on a not-yet-existing tag")
        # P8 — published releases are never mutated
        if "overwrite_files" in rel_norm:
            fail("P8", f"{wf_name}: overwrite_files must not be used")

    # P7 — honest production signing gate
    if "Production signing gate" not in rel_norm:
        fail("P7", f"{wf_name}: production signing gate step missing")
    elif "exit 1" not in rel_norm:
        fail("P7", f"{wf_name}: production gate must fail the job without keystore")

    # P9 — checkouts never persist git credentials
    for job_name, job in jobs.items():
        for step in (job.get("steps") or []):
            if isinstance(step.get("uses"), str) and step["uses"].startswith("actions/checkout"):
                persist = (step.get("with") or {}).get("persist-credentials")
                if persist is not False:
                    fail("P9", f"{wf_name}: checkout in job '{job_name}' must set persist-credentials: false")

    # P10 — write-scoped job restricted to trusted refs
    if "workflow_dispatch" in text:
        job_if = str(release.get("if") or "")
        if "refs/heads/main" not in job_if or "workflow_dispatch" not in job_if:
            fail("P10", f"{wf_name}: release job must restrict workflow_dispatch to refs/heads/main")
    if publish_gated:
        for step in (release.get("steps") or []):
            if step.get("name") == "Create GitHub Release with APK":
                step_if = str(step.get("if") or "")
                if "refs/heads/main" not in step_if or "workflow_dispatch" not in step_if:
                    fail("P10", f"{wf_name}: publish step must fire only on a push to main (not dispatch)")

    # P11 — anti shell-injection around repo-derived values
    for job_name, job in jobs.items():
        for step in (job.get("steps") or []):
            run = step.get("run")
            if isinstance(run, str) and INLINE_CTX_RE.search(run):
                fail("P11", f"{wf_name}: step '{step.get('name')}' in job '{job_name}' "
                            f"interpolates event/step context inline into run: — use env instead")
    names = [s.get("name") for s in (release.get("steps") or [])]
    if "Read app version" in names:
        if "Validate version format" not in names:
            fail("P11", f"{wf_name}: version outputs must pass a format-validation step before use")
        else:
            i_read = names.index("Read app version")
            i_val = names.index("Validate version format")
            consumers = [i for i, n in enumerate(names) if n in ("Check release tag existence", "Rename APK with version")]
            if not (i_read < i_val and all(i_val < c for c in consumers)):
                fail("P11", f"{wf_name}: version validation must sit between 'Read app version' and its consumers")
            val_step = (release.get("steps") or [])[i_val]
            if "grep -Eq" not in str(val_step.get("run") or ""):
                fail("P11", f"{wf_name}: version validation must enforce an explicit regex format")

    # P12 — artifact retention declared
    uploads = [s for job in jobs.values() for s in (job.get("steps") or [])
               if isinstance(s.get("uses"), str) and s["uses"].startswith("actions/upload-artifact")]
    for s in uploads:
        if "retention-days" not in (s.get("with") or {}):
            fail("P12", f"{wf_name}: artifact upload '{s.get('name')}' must declare retention-days")

    return failures


def main() -> int:
    if "--self-test" in sys.argv:
        return self_test()

    failures: list[str] = []
    for wf in sorted(WF_DIR.glob("*.yml")):
        failures.extend(check_workflow(wf.name, wf.read_text(encoding="utf-8")))

    if failures:
        print("CI POLICY VIOLATIONS:")
        for f in failures:
            print("  ✗", f)
        return 1
    print("CI policy check: PASS (P1-P12)")
    return 0


# ---------------------------------------------------------------------------
# Self test — proves the checker rejects violations (negative fixtures) and
# accepts a compliant workflow (positive fixture). Any unexpected behaviour
# is a hard failure of the gate itself.
# ---------------------------------------------------------------------------

POSITIVE = r"""
name: ok
on:
  push:
    branches: ["**"]
  workflow_dispatch:
    inputs:
      production: {type: boolean, default: false}
permissions: {}
jobs:
  verify:
    runs-on: ubuntu-latest
    permissions: {contents: read}
    steps:
      - name: Checkout code
        uses: actions/checkout@1111111111111111111111111111111111111111 # v4.4.0
        with: {persist-credentials: false}
      - run: echo verify-only
  release:
    needs: [verify]
    runs-on: ubuntu-latest
    permissions: {contents: write}
    if: github.event_name == 'push' || (github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/main')
    steps:
      - name: Checkout code
        uses: actions/checkout@1111111111111111111111111111111111111111 # v4.4.0
        with: {persist-credentials: false}
      - name: Production signing gate
        run: |
          if [ true = true ]; then echo mode=production >> "$GITHUB_OUTPUT"; else exit 1; fi
      - name: Read app version
        id: version
        run: echo version=1.2.3 >> "$GITHUB_OUTPUT"
      - name: Validate version format
        env: {APP_VERSION: "${{ steps.version.outputs.version }}"}
        run: |
          printf '%s' "$APP_VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'
      - name: Check release tag existence
        run: echo check
      - name: Upload APK artifact
        uses: actions/upload-artifact@2222222222222222222222222222222222222222 # v4.6.2
        with: {name: apk, path: app.apk, retention-days: 30}
      - name: Create GitHub Release with APK
        if: github.ref == 'refs/heads/main' && github.event_name != 'workflow_dispatch' && steps.tagcheck.outputs.exists == 'false'
        uses: softprops/action-gh-release@3333333333333333333333333333333333333333 # v2.6.2
        with: {tag_name: v1.2.3, files: app.apk}
"""

NEGATIVES: dict[str, str] = {
    "P1 top-level permissions not deny-all": POSITIVE.replace(
        "permissions: {}", "permissions: {contents: write}", 1),
    "P2 verify holds write scope": POSITIVE.replace(
        "permissions: {contents: read}", "permissions: {contents: write}", 1),
    "P3 release does not need verify": POSITIVE.replace(
        "needs: [verify]", "needs: []", 1),
    "P4 floating tag instead of SHA": POSITIVE.replace(
        "actions/checkout@1111111111111111111111111111111111111111 # v4.4.0", "actions/checkout@v4", 1),
    "P5 pull_request_target present": POSITIVE.replace(
        'name: ok\non:', 'name: ok\non:\n  pull_request_target:\n    branches: [main]', 1),
    "P6 publish not gated on missing tag": POSITIVE.replace(
        "steps.tagcheck.outputs.exists == 'false'", "always()", 1),
    "P7 production gate missing": POSITIVE.replace(
        "- name: Production signing gate\n        run: |\n          if [ true = true ]; then echo mode=production >> \"$GITHUB_OUTPUT\"; else exit 1; fi", "", 1),
    "P8 overwrite_files mutates releases": POSITIVE.replace(
        "with: {tag_name: v1.2.3, files: app.apk}", "with: {tag_name: v1.2.3, files: app.apk, overwrite_files: true}", 1),
    "P9 checkout persists credentials": POSITIVE.replace(
        "with: {persist-credentials: false}", "with: {persist-credentials: true}", 1),
    "P10 release dispatch allowed off main": POSITIVE.replace(
        "if: github.event_name == 'push' || (github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/main')",
        "if: true", 1),
    "P11 inline context in run shell": POSITIVE.replace(
        "run: echo version=1.2.3 >> \"$GITHUB_OUTPUT\"",
        "run: echo version=${{ inputs.version }} >> \"$GITHUB_OUTPUT\"", 1),
    "P11 no version format validation": POSITIVE.replace(
        "      - name: Validate version format\n        env: {APP_VERSION: \"${{ steps.version.outputs.version }}\"}\n        run: |\n          printf '%s' \"$APP_VERSION\" | grep -Eq '^[0-9]+\\.[0-9]+\\.[0-9]+$'\n", "", 1),
    "P12 artifact upload without retention": POSITIVE.replace(
        "with: {name: apk, path: app.apk, retention-days: 30}", "with: {name: apk, path: app.apk}", 1),
}


def self_test() -> int:
    problems: list[str] = []

    ok_failures = check_workflow("positive-fixture.yml", POSITIVE)
    if ok_failures:
        problems.append(f"compliant fixture must PASS but got: {ok_failures}")

    for label, fixture in NEGATIVES.items():
        got = check_workflow("negative-fixture.yml", fixture)
        rule = label.split()[0]
        if not any(f.startswith(rule + ":") for f in got):
            problems.append(f"fixture '{label}' must be rejected with {rule} but got: {got or 'NO violations'}")

    if problems:
        print("POLICY SELF-TEST FAILURES:")
        for p in problems:
            print("  ✗", p)
        return 1
    n_neg = len(NEGATIVES)
    print(f"Policy self-test: PASS (1 positive + {n_neg} negative fixtures)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
