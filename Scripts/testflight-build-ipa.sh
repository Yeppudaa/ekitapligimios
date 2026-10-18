#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$CM_BUILD_DIR/build/xcodebuild-raw"
status=0
xcode-project build-ipa \
  --project "$CM_BUILD_DIR/$XCODE_PROJECT" \
  --scheme "$XCODE_SCHEME" \
  --config "$XCODE_CONFIGURATION" \
  --archive-flags="-destination generic/platform=iOS -clonedSourcePackagesDirPath $CM_BUILD_DIR/.build/xcode-packages" \
  --disable-xcpretty 2>&1 | tee "$CM_BUILD_DIR/build/build-ipa.log" || status=$?
# Keep the underlying Xcode diagnostics even if the CLI exits before its normal log notice.
shopt -s nullglob
for log in /tmp/xcodebuild_logs/*.log; do
  cp "$log" "$CM_BUILD_DIR/build/xcodebuild-raw/"
done
if [ "$status" -ne 0 ]; then
  echo "ARCHIVE FAILURE DIAGNOSTICS (exit $status)"
  python3 - "$CM_BUILD_DIR/build/build-ipa.log" "$CM_BUILD_DIR/build/xcodebuild-raw" <<'PY'
from pathlib import Path
import re,sys
for path in [Path(sys.argv[1]),*Path(sys.argv[2]).glob('*.log')]:
    lines=path.read_text(errors='replace').splitlines()
    errors=[line for line in lines if re.search(r'error:|error:|failed|provisioning|signing|destination',line,re.I)]
    print(path.name)
    print('\n'.join(errors[-25:] if errors else lines[-35:]))
PY
fi
exit "$status"
