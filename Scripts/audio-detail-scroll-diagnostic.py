#!/usr/bin/env python3
"""Local partial-diagnostic helpers: exact test-result gate and simulator-app sampling."""

import argparse
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import threading
import time


TEST_METHODS = {
    "testA00AudioDetailAppSwipeReachesItsChapterWithoutPlayback",
    "testA01AudioDetailTargetedDragReachesItsChapterWithoutPlayback",
}
APP_EXECUTABLE = "/Ekitapligim.app/Ekitapligim"


def verify(summary_path, tests_path, output):
    report = {"scope": "audio-detail-scroll-diagnostic-only", "expectedMethods": sorted(TEST_METHODS), "passed": False}
    errors = []
    try:
        summary = json.loads(summary_path.read_text(encoding="utf-8-sig"))
        tests = json.loads(tests_path.read_text(encoding="utf-8-sig"))
        counts = {key: summary.get(key) for key in ("totalTestCount", "passedTests", "failedTests", "skippedTests")}
        report["counts"] = counts
        expected = {"totalTestCount": 2, "passedTests": 2, "failedTests": 0, "skippedTests": 0}
        if any(type(counts[key]) is not int or counts[key] != value for key, value in expected.items()):
            errors.append("Summary must record exactly two passing tests, zero failures and zero skips")
        leaves = []

        def visit(node):
            if isinstance(node, dict):
                if str(node.get("nodeType", "")).lower().replace(" ", "") == "testcase":
                    identifiers = [node.get(key) for key in ("name", "nodeIdentifier", "nodeIdentifierURL")]
                    matches = {method for method in TEST_METHODS if any(isinstance(value, str) and re.search(r"(?:^|/)" + re.escape(method) + r"(?:\(\))?$", value) for value in identifiers)}
                    leaves.append({"methods": sorted(matches), "result": node.get("result")})
                for value in node.values():
                    visit(value)
            elif isinstance(node, list):
                for value in node:
                    visit(value)

        visit(tests)
        report["testCases"] = leaves
        if len(leaves) != 2 or any(len(leaf["methods"]) != 1 or leaf["result"] != "Passed" for leaf in leaves):
            errors.append("Tests tree must contain exactly two recognized passing test-case leaves")
        methods = [method for leaf in leaves for method in leaf["methods"]]
        if len(methods) != 2 or set(methods) != TEST_METHODS:
            errors.append("Exact selected UI methods did not each run once")
    except (OSError, ValueError, TypeError) as error:
        errors.append(f"Unable to verify structured results: {error}")
    report["errors"] = errors
    report["passed"] = not errors
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if report["passed"] else 1


def matching_processes(text, udid):
    """ps comm contains executable paths only; never persist unrelated process rows."""
    if not re.fullmatch(r"[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}", udid):
        raise ValueError("A concrete simulator UUID is required")
    prefix = "/CoreSimulator/Devices/" + udid + "/data/Containers/Bundle/Application/"
    found = {}
    for line in text.splitlines():
        pieces = line.strip().split(None, 1)
        if len(pieces) != 2 or not pieces[0].isdigit():
            continue
        pid, executable = int(pieces[0]), pieces[1]
        if pid > 1 and prefix in executable and executable.endswith(APP_EXECUTABLE):
            tail = executable.split(prefix, 1)[1]
            if re.fullmatch(r"[A-Fa-f0-9-]+/Ekitapligim\.app/Ekitapligim", tail):
                found[pid] = executable
    return found


def watch(udid, output):
    output.mkdir(parents=True, exist_ok=True)
    stop = threading.Event()
    child = None
    tracked = {}
    records = []
    errors = []
    matching_processes("", udid)  # Reject an invalid/ambiguous simulator selector before ps.

    def request_stop(_signum, _frame):
        stop.set()

    signal.signal(signal.SIGTERM, request_stop)
    signal.signal(signal.SIGINT, request_stop)
    try:
        while not stop.is_set():
            listing = subprocess.run(["/bin/ps", "-ww", "-axo", "pid=,comm="], capture_output=True, text=True, timeout=5, check=True)
            current = matching_processes(listing.stdout, udid)
            now = time.monotonic()
            for pid, executable in current.items():
                state = tracked.setdefault(pid, {"first": now, "count": 0, "executable": executable})
                threshold = 2 if state["count"] == 0 else 20
                if state["count"] >= 2 or now - state["first"] < threshold or stop.is_set():
                    continue
                # Defend against PID reuse and a launch on another simulator immediately before sampling.
                check = subprocess.run(["/bin/ps", "-ww", "-p", str(pid), "-o", "pid=,comm="], capture_output=True, text=True, timeout=5)
                if matching_processes(check.stdout, udid).get(pid) != executable:
                    continue
                name = f"app-{pid}-sample-{state['count'] + 1}.txt"
                log_name = f"app-{pid}-sample-{state['count'] + 1}-command.log"
                with (output / log_name).open("w", encoding="utf-8") as log:
                    child = subprocess.Popen(["/usr/bin/sample", str(pid), "2", "1", "-file", str(output / name)], stdout=log, stderr=subprocess.STDOUT)
                    deadline = time.monotonic() + 8
                    while child.poll() is None and not stop.wait(0.2) and time.monotonic() < deadline:
                        pass
                    if child.poll() is None:
                        child.terminate()
                        try:
                            child.wait(timeout=2)
                        except subprocess.TimeoutExpired:
                            child.kill()
                            child.wait(timeout=2)
                    code = child.returncode
                    child = None
                records.append({"pid": pid, "selectedSimulator": udid, "sampleFile": name, "durationSeconds": 2, "exitCode": code})
                if code != 0 and not stop.is_set():
                    errors.append(f"Selected-app sample command exited {code} (PID {pid})")
                state["count"] += 1
            stop.wait(0.5)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        errors.append(str(error))
    finally:
        if child is not None and child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=2)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=2)
        status = {"scope": "audio-detail-scroll-diagnostic-only", "selectedSimulator": udid, "sampledExecutable": "Ekitapligim.app/Ekitapligim", "processArgumentsCollected": False, "stopRequested": stop.is_set(), "samples": records, "errors": errors}
        (output / "watchdog-status.json").write_text(json.dumps(status, indent=2) + "\n", encoding="utf-8")
    return 1 if errors else 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    gate = commands.add_parser("verify")
    gate.add_argument("--summary", type=Path, required=True)
    gate.add_argument("--tests", type=Path, required=True)
    gate.add_argument("--output", type=Path, required=True)
    watcher = commands.add_parser("watch")
    watcher.add_argument("--device-udid", required=True)
    watcher.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "verify":
        raise SystemExit(verify(args.summary, args.tests, args.output))
    raise SystemExit(watch(args.device_udid, args.output))
