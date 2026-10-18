"""Verify the captured current app and unchanged purchase/authentication implementation."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parent.parent

def sha(data):
    return hashlib.sha256(data.replace(b'\r\n', b'\n')).hexdigest()

def main():
    manifest = json.loads((ROOT/'Scripts/testflight-current-source.json').read_text(encoding='utf-8'))
    for name, digest in manifest['sourceFiles'].items():
        if sha((ROOT/name).read_bytes()) != digest:
            raise SystemExit('Captured current source mismatch: '+name)
    for name, digest in manifest['protectedFiles'].items():
        original = subprocess.check_output(['git','show',manifest['previousTestFlightSource']+':'+name],cwd=ROOT)
        assert sha(original) == digest == sha((ROOT/name).read_bytes()), 'Protected purchase/auth/config change: '+name
    report = {
        'source': subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        'capturedSourceFiles': len(manifest['sourceFiles']),
        'protectedFilesUnchanged': len(manifest['protectedFiles']),
        'previousTestFlightSource': manifest['previousTestFlightSource'],
        'validationRequired': 'Fresh full Core suite, native audio/model/layout tests, targeted current UI tests and signed IPA checks.',
        'distribution': 'TestFlight only; no public App Store release or backend deployment.',
        'historicalEvidence': 'Previous build45 tests are historical and do not validate the current changed views.'
    }
    out=ROOT/'build/testflight-reviewed'
    out.mkdir(parents=True,exist_ok=True)
    (out/'current-source-gate.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report,indent=2))

if __name__ == '__main__': main()
