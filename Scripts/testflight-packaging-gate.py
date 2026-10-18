"""Reuse completed build-10 tests only for byte-identical application and test sources."""
from pathlib import Path
import hashlib
import json
import subprocess
import runpy

ROOT = Path(__file__).resolve().parent.parent
TESTED = "dc7e93abaf10fa730837ad8fb1f1332086c97f95"

runpy.run_path(str(ROOT / "Scripts/testflight-current-gate.py"), run_name="__main__")
evidence = json.loads((ROOT / "Scripts/testflight-build10-validation.json").read_text())
assert evidence["source"] == TESTED
assert evidence["results"] == {"core": {"passed": 450, "failed": 0}, "native": {"passed": 31, "failed": 0, "skipped": 0}, "ui": {"passed": 10, "failed": 0, "skipped": 0}}
subprocess.run(["git", "diff", "--exit-code", TESTED, "HEAD", "--", "App", "Sources", "Tests", "project.yml", "Package.swift", "Package.resolved", ".swiftpm"], cwd=ROOT, check=True)
tested_manifest = json.loads(subprocess.check_output(["git", "show", TESTED + ":Scripts/testflight-current-source.json"], cwd=ROOT))
current = {}
for folder in ("App", "Sources", "Tests"):
    for path in (ROOT / folder).rglob("*"):
        if path.is_file():
            current[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
assert current == tested_manifest["sourceFiles"], "Application or test sources differ from successful build 10"
out = ROOT / "build/testflight-reviewed"
(out / "reused-validation.json").write_text(json.dumps(evidence, indent=2))
print("Validated identical app/test/resources:", len(current))
print("Completed validation: Core 450/450, native 31/31, UI 10/10; only CI packaging changed.")
