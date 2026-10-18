#!/usr/bin/env bash
set -euo pipefail
EVIDENCE="$PWD/build/testflight-reviewed"
mkdir -p "$EVIDENCE"
BASELINE=$(mktemp -d)
trap 'rm -rf "$BASELINE"' EXIT
python3 - "$BASELINE" <<'PY'
from pathlib import Path
import shutil,subprocess,sys
root=Path.cwd(); baseline=Path(sys.argv[1])
for name in ('Sources','Tests'): shutil.copytree(root/name,baseline/name)
shutil.copy2(root/'Package.swift',baseline/'Package.swift')
for name in ('AudioPolicy.swift','AudioRepository.swift','AudioBoundedMediaTransport.swift'):
    path='Sources/EkitapligimCore/'+name
    (baseline/path).write_bytes(subprocess.check_output(['git','show','874b8e47c62b26a7e9f302d58bea27ab950f2954:'+path]))
PY
set +e
swift test --package-path "$BASELINE" \
  --filter AudioMetadataCompatibilityTests.testMissingHeadLengthOrRangeAdvertisementUsesOnlyOneAuthenticatedByte \
  --xunit-output "$EVIDENCE/baseline-metadata.xml" \
  2>&1 | tee "$EVIDENCE/baseline-metadata.log"
BASELINE_EXIT=${PIPESTATUS[0]}
set -e
python3 - "$EVIDENCE/baseline-metadata.xml" "$BASELINE_EXIT" <<'PY'
from pathlib import Path
import sys,xml.etree.ElementTree as ET
root=ET.parse(sys.argv[1]).getroot()
cases=list(root.iter('testcase')); failures=list(root.iter('failure'))
assert int(sys.argv[2])!=0 and len(cases)==1 and len(failures)==1
assert 'invalidRange' in ET.tostring(root,encoding='unicode'), 'Expected original metadata error was not reproduced'
print('Original TestFlight45 source reproduced the missing HEAD metadata failure.')
PY
swift test --xunit-output "$EVIDENCE/core-tests.xml" 2>&1 | tee "$EVIDENCE/core-tests.log"
