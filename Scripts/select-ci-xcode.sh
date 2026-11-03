#!/usr/bin/env bash
set -euo pipefail
# Distribution has required the iOS 26 SDK since April 28, 2026.
developer=$(python3 - <<'PY'
import re
from pathlib import Path
choices = []
for path in Path('/Applications').glob('Xcode*.app'):
    version = tuple(map(int, re.findall(r'\d+', path.stem)))
    if version and version[0] >= 26 and 'beta' not in path.name.lower():
        choices.append((version, path))
if not choices:
    raise SystemExit('A stable Xcode 26 or later installation is required')
print(max(choices)[1] / 'Contents/Developer')
PY
)
sudo xcode-select -s "$developer"
xcodebuild -version
sdk=$(xcrun --sdk iphoneos --show-sdk-version)
if [ "${sdk%%.*}" -lt 26 ]; then printf 'iOS SDK 26 or later is required\n' >&2; exit 1; fi
