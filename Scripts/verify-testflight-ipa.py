"""Check the actual signed IPA without printing profiles, certificate bytes or credentials."""
from pathlib import Path
from datetime import datetime, timezone
import fnmatch
import hashlib
import json
import os
import plistlib
import subprocess
import tempfile
import zipfile

BUNDLE = "com.ekitapligim.app"
TEAM = "QA67383767"
DOMAINS = {"applinks:ekitapligim.com", "applinks:www.ekitapligim.com"}


def allows(value, patterns):
    return any(fnmatch.fnmatchcase(value, pattern) for pattern in patterns)


def main():
    root = Path(__file__).resolve().parent.parent
    ipas = list((root / "build/ios/ipa").glob("*.ipa"))
    assert len(ipas) == 1, "Expected one signed IPA"
    ipa = ipas[0]
    with tempfile.TemporaryDirectory(prefix="ekitapligim-testflight-verify-") as temp:
        folder = Path(temp)
        # IPA is created by this build, but do not accept an archive escaping the inspection folder.
        with zipfile.ZipFile(ipa) as archive:
            for item in archive.infolist():
                path = folder / item.filename
                assert path.resolve().is_relative_to(folder.resolve())
        # Preserve executable modes and framework links in the actual signed bundle.
        subprocess.run(["/usr/bin/ditto", "-x", "-k", str(ipa), str(folder)], check=True, capture_output=True)
        apps = list((folder / "Payload").glob("*.app"))
        assert len(apps) == 1
        app = apps[0]
        subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True, capture_output=True)
        signed = subprocess.run(["codesign", "-d", "--entitlements", ":-", str(app)], check=True, capture_output=True)
        ent = plistlib.loads(signed.stdout)
        info = plistlib.loads((app / "Info.plist").read_bytes())
        profile = plistlib.loads(subprocess.check_output(["security", "cms", "-D", "-i", str(app / "embedded.mobileprovision")]))
        permitted = profile["Entitlements"]
        assert {hashlib.sha1(value).hexdigest().upper() for value in profile["DeveloperCertificates"]} == {"45A48456F6BC51F7DBC9C2E1F571543462585C33"}
        assert info["CFBundleIdentifier"] == BUNDLE
        assert info["CFBundleShortVersionString"] == "1.1.1"
        assert info["CFBundleVersion"] == os.environ["TESTFLIGHT_NEXT_BUILD_NUMBER"]
        assert info["EKITAPLIGIM_ENVIRONMENT"] == "production"
        assert info["EKITAPLIGIM_API_BASE_URL"] == "https://ekitapligim.com/ios-api/v1/"
        assert ent["aps-environment"] == "production" == permitted["aps-environment"]
        assert ent.get("get-task-allow", False) is False
        assert permitted.get("get-task-allow", False) is False
        assert ent["com.apple.developer.team-identifier"] == TEAM
        assert TEAM in profile["TeamIdentifier"]
        assert ent["application-identifier"] == TEAM + "." + BUNDLE
        assert allows(ent["application-identifier"], [permitted["application-identifier"]])
        assert set(ent.get("com.apple.developer.associated-domains", [])) == DOMAINS
        for domain in DOMAINS:
            assert allows(domain, permitted.get("com.apple.developer.associated-domains", []))
        for group in ent.get("keychain-access-groups", []):
            assert allows(group, permitted.get("keychain-access-groups", []))
        expiry = profile["ExpirationDate"]
        if expiry.tzinfo is None:
            expiry = expiry.replace(tzinfo=timezone.utc)
        assert expiry > datetime.now(timezone.utc)
        report = {"bundle": BUNDLE, "team": TEAM, "version": info["CFBundleShortVersionString"],
                  "build": info["CFBundleVersion"], "signatureVerified": True,
                  "apsEnvironment": ent["aps-environment"], "associatedDomains": sorted(DOMAINS),
                  "debugEntitlementAbsent": True, "profileSupportsEntitlements": True,
                  "ipaSHA256": hashlib.sha256(ipa.read_bytes()).hexdigest(),
                  "destination": "TestFlight only"}
        out = root / "build/testflight-reviewed"
        out.mkdir(parents=True, exist_ok=True)
        (out / "signed-ipa-verification.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
