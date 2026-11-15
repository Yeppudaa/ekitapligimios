"""Publish only the code covered by completed, inspected native release reviews."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
EVIDENCE_SHA256 = "unverified"
GROUPS = {"native-unit", "iPhone-compact", "iPhone-large", "iPad"}
PROTECTED = ("App", "Sources", "Tests", "Backend", "Package.swift",
             "Scripts/modern-parity-macos-validation.sh", "Scripts/select-ci-xcode.sh",
             ".github/workflows/release-review.yml")


def project_digest(source):
    # Version/build numbers are assigned after the test run and verified in the signed IPA.
    # No dependency, scheme, entitlement, configuration or other project change is exempt.
    for key in ("MARKETING_VERSION", "CURRENT_PROJECT_VERSION"):
        source, count = re.subn(rf'(?m)^(\s*{key}:)\s*["\']?[0-9.]+["\']?\s*$', r'\1 RELEASE_NUMBER', source)
        if count != 1:
            raise ValueError("Expected one canonical " + key)
    return hashlib.sha256(source.replace("\r\n", "\n").encode()).hexdigest()


def verify(evidence, current_objects, current_project):
    if not re.fullmatch(r"[a-f0-9]{40}", evidence.get("source", "")):
        raise ValueError("Missing reviewed source revision")
    if set(evidence.get("protectedGitObjects", {})) != set(PROTECTED):
        raise ValueError("Incomplete protected source inventory")
    if current_objects != evidence["protectedGitObjects"]:
        raise ValueError("Application, tests, dependencies or server source changed after native review")
    if project_digest(current_project) != evidence.get("projectDigest"):
        raise ValueError("Project settings changed beyond release version/build numbers")
    if evidence.get("builds") != {"core": 0, "development": 0, "production": 0}:
        raise ValueError("Core, clean Development and Production builds must all pass")
    groups = evidence.get("groups", {})
    if set(groups) != GROUPS:
        raise ValueError("Every native and device review is required")
    for name, group in groups.items():
        result = group.get("summary", {})
        if group.get("conclusion") != "success" or group.get("exitCode") != 0:
            raise ValueError(name + ": review failed or is incomplete")
        total = result.get("totalTestCount", 0)
        if not isinstance(total, int) or total < group.get("minimumTests", 1) or total <= 0:
            raise ValueError(name + ": incomplete test execution")
        if result.get("passedTests") != total or result.get("failedTests") != 0 or result.get("skippedTests") != 0:
            raise ValueError(name + ": failed or skipped tests")
        if not re.fullmatch(r"[a-f0-9]{64}", group.get("artifactSHA256", "")):
            raise ValueError(name + ": missing original artifact digest")
        if not group.get("url", "").startswith("https://github.com/Yeppudaa/ekitapligimios/actions/runs/"):
            raise ValueError(name + ": missing original review location")
    if set(evidence.get("screenshotsReviewed", [])) != GROUPS - {"native-unit"}:
        raise ValueError("Device screenshots have not all been reviewed")


def main():
    raw = (ROOT / "Scripts/current-release-evidence.json").read_bytes().replace(b"\r\n", b"\n")
    if hashlib.sha256(raw).hexdigest() != EVIDENCE_SHA256:
        raise ValueError("Current release evidence is not the inspected result")
    evidence = json.loads(raw)
    current = {path: subprocess.check_output(["git", "rev-parse", "HEAD:" + path], cwd=ROOT, text=True).strip()
               for path in PROTECTED}
    verify(evidence, current, (ROOT / "project.yml").read_text(encoding="utf-8"))
    output = ROOT / "build/current-release"
    output.mkdir(parents=True, exist_ok=True)
    (output / "review-evidence.json").write_bytes(raw)
    print("Current application source matches the completed native and three-device reviews.")
    print("Reviewed source:", evidence["source"])


if __name__ == "__main__":
    main()
