#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${APP_STORE_APPLE_ID:?App Store application ID is required}"
directory="$PWD/build/release-version"
mkdir -p "$directory"
app-store-connect get-latest-testflight-build-number "$APP_STORE_APPLE_ID" --platform IOS --all-versions > "$directory/latest-testflight.txt"
app-store-connect get-latest-app-store-build-number "$APP_STORE_APPLE_ID" --platform IOS --all-versions > "$directory/latest-appstore.txt"
app-store-connect apps app-store-versions "$APP_STORE_APPLE_ID" --platform IOS --json > "$directory/appstore-versions.json"
python3 Scripts/release_version.py --directory "$directory"
if [ "${1:-}" = "--apply" ]; then
  next_build=$(python3 -c 'import json; print(json.load(open("build/release-version/version-plan.json"))["nextBuildNumber"])')
  agvtool new-version -all "$next_build"
elif [ "$#" -ne 0 ]; then
  printf 'Expected no argument (read-only) or --apply (assign build number)\n' >&2
  exit 1
fi
