"""Reuse executed search tests only when every app/core/test file is unchanged."""
from pathlib import Path
import json
import runpy
import subprocess

ROOT = Path(__file__).resolve().parent.parent
TESTED = "7928c43824070623f9a9bf39f22d453bba8dff86"
runpy.run_path(str(ROOT / "Scripts/testflight-search-gate.py"), run_name="__main__")
evidence = json.loads((ROOT / "Scripts/testflight-search-evidence.json").read_text())
assert evidence["source"] == TESTED
assert evidence["archiveSHA256"] == "16bde961fcab82109526ddbbd56b6b23ccb44c49d8ef4bcd8d244d64c816813f"
reports = evidence["observedReports"]
assert reports["sourceGate"]["source"] == TESTED
assert reports["core"]["passed"] == 467 and reports["core"]["failed"] == 0
for section, count in (("native", 65), ("iPhone", 3), ("iPad", 3)):
    assert reports[section]["passedTests"] == count and reports[section]["failedTests"] == 0 and reports[section].get("skippedTests", 0) == 0
assert reports["signedIPA"]["signatureVerified"] is True
subprocess.run(["git", "diff", "--exit-code", TESTED, "--", "App", "Sources", "Tests", "Package.swift", "Package.resolved", ".swiftpm"], cwd=ROOT, check=True)
assert not subprocess.check_output(["git", "ls-files", "--others", "--exclude-standard", "--", "App", "Sources", "Tests"], cwd=ROOT).strip()
tested_project = subprocess.check_output(["git", "show", TESTED + ":project.yml"], cwd=ROOT)
expected_project = tested_project.replace(b' MARKETING_VERSION: "1.1.0"', b' MARKETING_VERSION: "1.1.1"')
assert (ROOT / "project.yml").read_bytes().replace(b"\r\n", b"\n") == expected_project.replace(b"\r\n", b"\n")
out = ROOT / "build/testflight-reviewed"
(out / "reused-search-validation.json").write_text(json.dumps(evidence, indent=2))
print("Exact app/core/test sources match passed validation:", TESTED)
print("Core 467/467, native 65/65, iPhone search 3/3, iPad search 3/3.")
print("Only required marketing-version increment and packaging metadata changed; archive and signature verification run again.")
