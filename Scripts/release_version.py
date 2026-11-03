"""Use project.yml as the version source and Apple's actual builds as the build floor."""
from pathlib import Path
import argparse
import json
import os
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def version_key(value):
    if not isinstance(value, str) or not re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,2}", value):
        raise ValueError("Invalid marketing version")
    parts = tuple(int(part) for part in value.split("."))
    return parts + (0,) * (3 - len(parts))


def project_version(path=ROOT / "project.yml"):
    source = path.read_text(encoding="utf-8")
    values = []
    for name in ("MARKETING_VERSION", "CURRENT_PROJECT_VERSION"):
        matches = re.findall(rf'^\s*{name}:\s*[\"\']?([0-9.]+)[\"\']?\s*$', source, re.MULTILINE)
        if len(matches) != 1:
            raise ValueError(f"Expected one canonical {name} in project.yml")
        values.append(matches[0])
    version_key(values[0])
    if not values[1].isdigit() or int(values[1]) < 1:
        raise ValueError("The source build floor must be a positive integer")
    return values[0], int(values[1])


def apple_build(value):
    value = value.strip()
    if not re.fullmatch(r"[0-9]+", value):
        raise ValueError("Apple build lookup did not return an integer; refusing to guess")
    return int(value)


def make_plan(version, floor, testflight, app_store, versions):
    candidate = version_key(version)
    resources = versions.get("data") if isinstance(versions, dict) else versions
    if not isinstance(resources, list) or not resources:
        raise ValueError("App Store version lookup is empty or malformed")
    records = []
    closed = {"READY_FOR_SALE", "READY_FOR_DISTRIBUTION", "REPLACED_WITH_NEW_VERSION",
              "PENDING_APPLE_RELEASE", "PENDING_DEVELOPER_RELEASE", "PREORDER_READY_FOR_SALE",
              "DEVELOPER_REMOVED_FROM_SALE", "REMOVED_FROM_SALE", "PROCESSING_FOR_APP_STORE",
              "PROCESSING_FOR_DISTRIBUTION", "PENDING_CONTRACT"}
    editable = {"PREPARE_FOR_SUBMISSION", "REJECTED", "DEVELOPER_REJECTED", "METADATA_REJECTED", "INVALID_BINARY"}
    for resource in resources:
        attributes = resource.get("attributes", resource)
        number = attributes.get("versionString")
        state = attributes.get("appStoreState") or attributes.get("appVersionState")
        key = version_key(number)
        if not isinstance(state, str) or not state:
            raise ValueError("App Store version state is missing")
        if state in closed and candidate <= key:
            raise ValueError(f"Candidate {version} must exceed approved/closed version {number} ({state})")
        if candidate == key and state not in editable:
            raise ValueError(f"Candidate {version} already has an active App Store state: {state}")
        records.append({"version": number, "state": state})
    return {"marketingVersion": version, "sourceBuildFloor": floor,
            "latestTestFlightBuild": apple_build(testflight), "latestAppStoreBuild": apple_build(app_store),
            "nextBuildNumber": max(floor, apple_build(testflight) + 1, apple_build(app_store) + 1),
            "appStoreVersions": records,
            "note": "Rechecked during signing; this read-only plan does not reserve or upload a build."}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", type=Path, required=True)
    args = parser.parse_args()
    version, floor = project_version()
    plan = make_plan(version, floor,
        (args.directory / "latest-testflight.txt").read_text(),
        (args.directory / "latest-appstore.txt").read_text(),
        json.loads((args.directory / "appstore-versions.json").read_text()))
    plan["source"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    (args.directory / "version-plan.json").write_text(json.dumps(plan, indent=2), encoding="utf-8")
    if os.environ.get("CM_ENV"):
        with Path(os.environ["CM_ENV"]).open("a", encoding="utf-8") as output:
            output.write(f"\nEXPECTED_MARKETING_VERSION={version}\nTESTFLIGHT_NEXT_BUILD_NUMBER={plan['nextBuildNumber']}\n")
    print(json.dumps(plan, indent=2))


if __name__ == "__main__":
    main()
