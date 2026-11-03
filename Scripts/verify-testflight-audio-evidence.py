"""Reuse executed audio results with unchanged audio code and reviewed UI-only deltas."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parent.parent
EVIDENCE_SHA256 = "1b4c9f9c6007db5e589ffaceb9b9971c176591ad4061a17ac34f5c13dc22d1be"
# Exact reviewed blobs: accessibility grouping/identifiers and DEBUG fixture routing.
# No playback, session, networking, dependency or audio-test change is permitted.
REVIEWED_UI_BLOBS = {
    "App/Ekitapligim/Design/AgendaPhotoView.swift": "8ef17ae27f2a0edb00f5e2abc72fc9b4135a3110",
    "App/Ekitapligim/Features/BookAgendaView.swift": "d65c13eb8d8c2747dcce0d40b1bcfc2fa3f00625",
    "App/Ekitapligim/Features/ModernParityUITestHost.swift": "60a74eb8aaa023affe57e12ea7ac0b24388fd94e",
}


def verify(evidence, current_objects, changed_app=None):
    expected = evidence["protectedGitObjects"]
    if set(expected) != set(current_objects):
        raise ValueError("Protected source inventory changed")
    for path, original in expected.items():
        if current_objects[path] == original:
            continue
        if path != "App/Ekitapligim" or not changed_app:
            raise ValueError("App, dependencies or native audio tests changed; fresh audio evidence is required")
        if any(REVIEWED_UI_BLOBS.get(name) != blob for name, blob in changed_app.items()):
            raise ValueError("Unreviewed app change; fresh audio evidence is required")
    tests = evidence["audioTests"]
    names = {test["nodeIdentifier"] for test in tests}
    if len(tests) != 11 or len(names) != 11 or any(test["result"] != "Passed" for test in tests):
        raise ValueError("All 11 executed audio tests must have passed")
    if any(not name.startswith("AudioPlaybackRuntimeTests/") for name in names):
        raise ValueError("Evidence must contain the actual native audio suite")
    if evidence["xcresultArchiveSHA256"] != "25708904e565926aac549717306c2e38adab86dfe954feb817f7b3a6b484ed06":
        raise ValueError("Unexpected original result archive")


def main():
    raw = (ROOT / "Scripts/testflight-beta-audio-evidence.json").read_bytes().replace(b"\r\n", b"\n")
    if hashlib.sha256(raw).hexdigest() != EVIDENCE_SHA256:
        raise ValueError("The inspected audio evidence was modified")
    evidence = json.loads(raw)
    current = {path: subprocess.check_output(["git", "rev-parse", "HEAD:" + path], cwd=ROOT, text=True).strip()
               for path in evidence["protectedGitObjects"]}
    changed_paths = subprocess.check_output(["git", "diff", "--name-only", evidence["source"], "HEAD", "--",
                                             "App/Ekitapligim"], cwd=ROOT, text=True).splitlines()
    changed_app = {path: subprocess.check_output(["git", "rev-parse", "HEAD:" + path], cwd=ROOT, text=True).strip()
                   for path in changed_paths}
    verify(evidence, current, changed_app)
    changed = subprocess.check_output(["git", "diff", "--name-only", evidence["source"], "HEAD", "--",
                                       "App/EkitapligimTests"], cwd=ROOT, text=True).splitlines()
    if set(changed) - {"App/EkitapligimTests/PremiumAvatarLayoutTests.swift"}:
        raise ValueError("Native test helpers changed; fresh audio evidence is required")
    output = ROOT / "build/testflight-beta"
    output.mkdir(parents=True, exist_ok=True)
    (output / "audio-runtime-evidence.json").write_bytes(raw)
    (output / "audio-evidence-ui-deltas.json").write_text(json.dumps(changed_app, indent=2) + "\n")
    print("11/11 native audio tests passed on GitHub Xcode 26.3 / iOS 26.2.")
    print("Audio, Core, dependencies and audio tests match the executed revision; only exact reviewed UI/DEBUG blobs may differ.")
    print("All other native tests and 25 beta UI tests must still pass freshly on Codemagic.")


if __name__ == "__main__":
    main()
