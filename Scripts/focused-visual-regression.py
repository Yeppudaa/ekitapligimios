#!/usr/bin/env python3
"""Exact selected UI-result gate for the manual visual regression only."""
import argparse
import json
from pathlib import Path
import re

TEST_METHODS = {
    "testA00AudioDetailAppSwipeReachesItsChapterWithoutPlayback",
    "testA01AudioDetailTargetedDragReachesItsChapterWithoutPlayback",
    "testChatTranscriptScrollDoesNotMoveItsHeaderOrExposeRemovedRoomTabs",
    "testHomeLowerScenicSectionsRemainReachableAndContained",
    "testHomeGenreOpensFilteredCatalogAndReturnsToHomeInTheSameNavigationStack",
    "testLibraryArtworkAndActualShelfNavigationRemainReachable",
    "testProfileFavoriteShelfAndDetailBackNavigationKeepTheChosenShelf",
}

def verify(summary_path, tests_path, output):
    errors = []
    report = {"scope": "focused-visual-regression-only", "expectedMethods": sorted(TEST_METHODS), "passed": False}
    try:
        summary = json.loads(summary_path.read_text(encoding="utf-8-sig"))
        tests = json.loads(tests_path.read_text(encoding="utf-8-sig"))
        counts = {key: summary.get(key) for key in ("totalTestCount", "passedTests", "failedTests", "skippedTests")}
        report["counts"] = counts
        expected = {"totalTestCount": len(TEST_METHODS), "passedTests": len(TEST_METHODS), "failedTests": 0, "skippedTests": 0}
        if any(type(counts[key]) is not int or counts[key] != value for key, value in expected.items()):
            errors.append("Summary must record exactly the seven selected passing cases, zero failures and zero skips")
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
        if len(leaves) != len(TEST_METHODS) or any(len(leaf["methods"]) != 1 or leaf["result"] != "Passed" for leaf in leaves):
            errors.append("Tree must contain exactly seven recognized passing test-case leaves")
        methods = [method for leaf in leaves for method in leaf["methods"]]
        if len(methods) != len(TEST_METHODS) or set(methods) != TEST_METHODS:
            errors.append("Exact selected UI methods did not each run once")
    except (OSError, ValueError, TypeError) as error:
        errors.append(f"Unable to verify structured results: {error}")
    report["errors"] = errors
    report["passed"] = not errors
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if report["passed"] else 1

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", type=Path, required=True)
    parser.add_argument("--tests", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    raise SystemExit(verify(args.summary, args.tests, args.output))
