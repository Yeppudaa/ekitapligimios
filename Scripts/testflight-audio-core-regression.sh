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
python3 - "$EVIDENCE/baseline-metadata.log" "$BASELINE_EXIT" <<'PY'
from pathlib import Path
import re,sys
log=Path(sys.argv[1]).read_text()
# Apple SwiftPM does not emit XCTest XML for this nonparallel failing run.
# Require the actual executed assertion and exact selected test summary.
assert int(sys.argv[2])!=0 and 'Build complete!' in log
assert 'testMissingHeadLengthOrRangeAdvertisementUsesOnlyOneAuthenticatedByte' in log
assert re.search(r'Executed 1 test, with 1 failure',log)
assert 'caught error: "invalidRange"' in log or 'threw error "invalidRange"' in log
print('Original TestFlight45 source reproduced the missing HEAD metadata failure.')
PY
swift test --xunit-output "$EVIDENCE/core-tests.xml" 2>&1 | tee "$EVIDENCE/core-tests.log"
python3 - "$EVIDENCE" <<'PY'
from pathlib import Path
import json,re,sys
out=Path(sys.argv[1]); log=(out/'core-tests.log').read_text()
results=[(int(n),int(f)) for n,f in re.findall(r'Executed (\d+) tests?, with (\d+) failures?',log)]
assert results and max(n for n,_ in results)>=450 and all(f==0 for _,f in results)
report={'passed':max(n for n,_ in results),'failed':0,'platform':'macOS','source':'current build'}
(out/'core-tests-summary.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
PY
