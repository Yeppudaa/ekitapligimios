"""Pin the temporary build's archive and export to the validated renewed identity."""
from pathlib import Path
import hashlib
import plistlib
import subprocess

TEAM = "QA67383767"
BUNDLE = "com.ekitapligim.app"
IDENTITY = "2D336E3D11A04C7E0644846019C9E850159DA36B"

root = Path(__file__).resolve().parent.parent
identities = subprocess.check_output(
    ["security", "find-identity", "-v", "-p", "codesigning"], text=True
)
assert any(IDENTITY in line and f"({TEAM})" in line for line in identities.splitlines()), "Renewed signing identity is not valid"
profiles = list((root / "build/push-signing/profiles").glob("*.mobileprovision"))
assert len(profiles) == 1, "Expected the current build's single App Store profile"
profile = plistlib.loads(subprocess.check_output(["security", "cms", "-D", "-i", str(profiles[0])]))
certificates = {hashlib.sha1(value).hexdigest().upper() for value in profile["DeveloperCertificates"]}
assert certificates == {IDENTITY}, "App Store profile must use only the renewed identity"
assert profile["Entitlements"]["application-identifier"] == TEAM + "." + BUNDLE
assert profile["Entitlements"]["aps-environment"] == "production"

options_path = Path.home() / "export_options.plist"
options = plistlib.loads(options_path.read_bytes())
assert options["teamID"] == TEAM
assert options["provisioningProfiles"][BUNDLE] == profile["Name"]
options["signingCertificate"] = IDENTITY
options_path.write_bytes(plistlib.dumps(options))
print("Archive and export pinned to renewed valid Apple Distribution identity:", IDENTITY)
