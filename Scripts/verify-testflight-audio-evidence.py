"""Reuse executed audio results only while the complete app and audio tests are identical."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parent.parent
EVIDENCE_SHA256 = "1b4c9f9c6007db5e589ffaceb9b9971c176591ad4061a17ac34f5c13dc22d1be"


def verify(evidence, current_objects):
    if evidence["protectedGitObjects"] != current_objects:
        raise ValueError("App, dependencies or native audio tests changed; fresh audio evidence is required")
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
    verify(evidence, current)
    changed = subprocess.check_output(["git", "diff", "--name-only", evidence["source"], "HEAD", "--",
                                       "App/EkitapligimTests"], cwd=ROOT, text=True).splitlines()
    if set(changed) - {"App/EkitapligimTests/PremiumAvatarLayoutTests.swift"}:
        raise ValueError("Native test helpers changed; fresh audio evidence is required")
    output = ROOT / "build/testflight-beta"
    output.mkdir(parents=True, exist_ok=True)
    (output / "audio-runtime-evidence.json").write_bytes(raw)
    print("11/11 native audio tests passed on GitHub Xcode 26.3 / iOS 26.2.")
    print("Complete app, Core sources, dependency declarations and audio test code match that executed revision.")
    print("All other native tests and 25 beta UI tests must still pass freshly on Codemagic.")


if __name__ == "__main__":
    main()
