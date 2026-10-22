"""Permit only the catalog search correction over the last TestFlight source."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parent.parent
BASE = "189765c276ddc160e7d84316c7161abc8ce7f655"


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def sha(data):
    return hashlib.sha256(data.replace(b"\r\n", b"\n")).hexdigest()


def main():
    subprocess.run(["git", "merge-base", "--is-ancestor", BASE, "HEAD"], cwd=ROOT, check=True)
    manifest = json.loads((ROOT / "Scripts/testflight-search-source.json").read_text())
    allowed = set(manifest["sourceFiles"])
    changed = set(git("diff", "--name-only", BASE, "--", "App", "Sources", "Tests", "Package.swift", "project.yml").decode().splitlines())
    untracked = set(git("ls-files", "--others", "--exclude-standard", "--", "App", "Sources", "Tests").decode().splitlines())
    assert changed | untracked <= allowed | {"project.yml"}, "Unexpected app changes: " + str(sorted((changed | untracked) - allowed - {"project.yml"}))
    for name, expected in manifest["sourceFiles"].items():
        assert sha((ROOT / name).read_bytes()) == expected, "Search source mismatch: " + name
    protected = json.loads((ROOT / "Scripts/testflight-current-source.json").read_text())["protectedFiles"]
    for name in protected:
        assert sha((ROOT / name).read_bytes()) == sha(git("show", BASE + ":" + name)), "Protected source changed: " + name
    for name in ("App/Ekitapligim/Features/PremiumView.swift", "App/Ekitapligim/Design/PremiumDesign.swift"):
        assert sha((ROOT / name).read_bytes()) == sha(git("show", BASE + ":" + name)), "Protected presentation/config changed: " + name
    project = git("show", BASE + ":project.yml").replace(b' MARKETING_VERSION: "1.1.0"', b' MARKETING_VERSION: "1.1.1"')
    assert sha((ROOT / "project.yml").read_bytes()) == sha(project), "Only the required marketing version increment is permitted"
    report = {"source": git("rev-parse", "HEAD").decode().strip(), "previousTestFlightSource": BASE,
              "protectedFilesUnchanged": len(protected) + 2, "searchSourceFiles": sorted(allowed),
              "marketingVersion": "1.1.1",
              "validationRequired": "Fresh Core, native model/layout tests, iPhone and iPad CatalogSearchUITests, clean signed Production archive and IPA verification.",
              "distribution": "TestFlight only"}
    out = ROOT / "build/testflight-reviewed"
    out.mkdir(parents=True, exist_ok=True)
    (out / "search-source-gate.json").write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
