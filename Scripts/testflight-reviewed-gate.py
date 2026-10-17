"""Require the reviewed app and preserve the provenance of the actual executed tests."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parent.parent
REVIEW = "5e8a245faf70dd977458f9fefc498b61d1f38f54"
ALLOWED = {
    "codemagic.yaml", "Scripts/testflight-reviewed-evidence.json",
    "Scripts/testflight-reviewed-gate.py", "Scripts/verify-testflight-ipa.py",
}


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def main():
    subprocess.run(["git", "merge-base", "--is-ancestor", REVIEW, "HEAD"], cwd=ROOT, check=True)
    changed = set(git("diff", "--name-only", REVIEW, "HEAD").splitlines())
    if changed - ALLOWED:
        raise SystemExit("App changes since reviewed source require fresh native validation: " + ", ".join(sorted(changed - ALLOWED)))
    evidence = json.loads((ROOT / "Scripts/testflight-reviewed-evidence.json").read_text(encoding="utf-8"))
    assert evidence["reviewedSource"] == REVIEW
    assert evidence["evidenceArchiveSHA256"] == "f589e2724f291413f4350277e134aebfe7d0010eadf543531255945f19a8b189"
    assert evidence["core"]["passed"] == 416 and evidence["core"]["failed"] == 0
    assert evidence["native"]["passed"] == 143 and evidence["native"]["failed"] == 0
    assert evidence["compactScoped"]["passed"] == 6 and evidence["compactScoped"]["failed"] == 1
    assert evidence["premiumFailureRecovery"] == {"source": REVIEW, "passed": 1, "failed": 0, "assertionUnchanged": True}
    assert evidence["iPadScoped"]["passed"] == 3 and evidence["iPadScoped"]["failed"] == 0
    assert evidence["iPadPageRendering"]["pages"] == 17 and evidence["iPadPageRendering"]["failed"] == 0
    assert evidence["productionBuild"] == {"source": REVIEW, "exit": 0}
    assert not git("diff", "--name-only", evidence["core"]["source"], REVIEW, "--", "Sources", "Tests")
    assert not git("diff", "--name-only", evidence["native"]["source"], REVIEW, "--", "App/EkitapligimTests", "App/Ekitapligim/App/AppContainer.swift")
    audio_changes = set(git("diff", "--name-only", evidence["native"]["source"], REVIEW, "--", "App/Ekitapligim/Audio").splitlines())
    assert audio_changes <= {"App/Ekitapligim/Audio/AudioComponents.swift"}, "Native audio logic must match the executed runtime tests"
    entitlements = "App/Ekitapligim/Support/Ekitapligim.entitlements"
    expected = subprocess.check_output(["git", "show", REVIEW + ":" + entitlements], cwd=ROOT)
    # Git checkout may normalize newlines on Windows; signing restores these exact Git bytes on Mac.
    current = (ROOT / entitlements).read_bytes().replace(b"\r\n", b"\n")
    assert current == expected.replace(b"\r\n", b"\n")
    report = {"reviewedSource": REVIEW, "buildSource": git("rev-parse", "HEAD"),
              "appSourceUnchanged": True, "previousEvidence": evidence,
              "productionEntitlementsSHA256": hashlib.sha256(expected).hexdigest(),
              "scope": "Signed TestFlight upload only; no App Store review or production release."}
    out = ROOT / "build/testflight-reviewed"
    out.mkdir(parents=True, exist_ok=True)
    (out / "source-gate.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("Reviewed app source unchanged:", REVIEW)
    print("Existing native evidence: Core416/416; native143/143; scoped UI and recovered premium assertion recorded.")


if __name__ == "__main__":
    main()
