import copy
import unittest
from current_release_gate import GROUPS, IPAD_ONLY_TEST, PROTECTED, project_digest, verify

PROJECT = 'MARKETING_VERSION: "1.1.2"\nCURRENT_PROJECT_VERSION: "50"\nDependency: exact-version\n'


class CurrentReleaseGateTests(unittest.TestCase):
    def setUp(self):
        self.objects = {name: "a" * 40 for name in PROTECTED}
        self.evidence = {
            "source": "b" * 40, "protectedGitObjects": self.objects.copy(),
            "projectDigest": project_digest(PROJECT),
            "builds": {"core": 0, "development": 0, "production": 0},
            "screenshotsReviewed": ["iPhone-compact", "iPhone-large", "iPad"],
            "groups": {name: {"conclusion": "success", "exitCode": 0, "minimumTests": 12,
                "artifactSHA256": "c" * 64,
                "url": "https://github.com/Yeppudaa/ekitapligimios/actions/runs/123",
                "summary": {"totalTestCount": 12, "passedTests": 12, "failedTests": 0, "skippedTests": 0}}
                for name in GROUPS}}

    def test_release_numbers_can_change_but_dependencies_cannot(self):
        verify(self.evidence, self.objects, PROJECT.replace('1.1.2', '1.1.3').replace('"50"', '"51"'))
        with self.assertRaises(ValueError):
            verify(self.evidence, self.objects, PROJECT.replace('exact-version', 'other-version'))

    def test_changed_app_or_tests_or_core_prevents_publication(self):
        for key in ("App", "Sources", "Tests", "Package.swift"):
            changed = self.objects.copy(); changed[key] = "d" * 40
            with self.assertRaises(ValueError):
                verify(self.evidence, changed, PROJECT)

    def test_missing_device_review_prevents_publication(self):
        del self.evidence['groups']['iPad']
        with self.assertRaises(ValueError): verify(self.evidence, self.objects, PROJECT)

    def test_failed_skipped_or_incomplete_execution_prevents_publication(self):
        for key, value in (("failedTests", 1), ("skippedTests", 1), ("passedTests", 11), ("totalTestCount", 0)):
            bad = copy.deepcopy(self.evidence)
            bad['groups']['native-unit']['summary'][key] = value
            with self.assertRaises(ValueError): verify(bad, self.objects, PROJECT)

    def test_failed_build_prevents_publication(self):
        self.evidence['builds']['production'] = 1
        with self.assertRaises(ValueError): verify(self.evidence, self.objects, PROJECT)

    def test_unreviewed_visuals_prevent_publication(self):
        self.evidence['screenshotsReviewed'].remove('iPad')
        with self.assertRaises(ValueError): verify(self.evidence, self.objects, PROJECT)

    def test_ipad_only_case_may_skip_phones_only_when_it_passes_on_ipad(self):
        phone = self.evidence['groups']['iPhone-compact']
        phone['summary'].update(passedTests=11, skippedTests=1)
        phone['skippedTestIdentifiers'] = [IPAD_ONLY_TEST]
        with self.assertRaises(ValueError): verify(self.evidence, self.objects, PROJECT)
        self.evidence['groups']['iPad']['passedPlatformSpecificTests'] = [IPAD_ONLY_TEST]
        verify(self.evidence, self.objects, PROJECT)
        phone['skippedTestIdentifiers'] = ['UnrelatedTests/testMissingCoverage()']
        with self.assertRaises(ValueError): verify(self.evidence, self.objects, PROJECT)


if __name__ == '__main__': unittest.main()
