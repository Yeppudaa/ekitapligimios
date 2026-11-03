import tempfile
import unittest
from pathlib import Path
from release_version import apple_build, make_plan, project_version


class ReleaseVersionTests(unittest.TestCase):
    def versions(self, version="1.1.1", state="READY_FOR_SALE"):
        return [{"attributes": {"versionString": version, "appStoreState": state}}]

    def test_current_source_has_one_marketing_version_and_build_floor(self):
        self.assertEqual(project_version(), ("1.1.2", 50))

    def test_build_exceeds_both_apple_channels_and_source_floor(self):
        for flight, store, expected in [("49", "49", 50), ("56", "49", 57), ("49", "80", 81), ("1", "2", 50)]:
            self.assertEqual(make_plan("1.1.2", 50, flight, store, self.versions())["nextBuildNumber"], expected)

    def test_released_version_cannot_be_reused_even_with_a_higher_build(self):
        for version in ["1.1.1", "1.1.0"]:
            with self.assertRaises(ValueError):
                make_plan(version, 50, "99", "49", self.versions())

    def test_version_comparison_is_numeric(self):
        self.assertEqual(make_plan("1.1.10", 50, "49", "49", self.versions("1.1.9"))["marketingVersion"], "1.1.10")

    def test_existing_editable_draft_is_allowed_but_in_review_is_not(self):
        make_plan("1.1.2", 50, "49", "49", {"data": self.versions("1.1.2", "PREPARE_FOR_SUBMISSION")})
        with self.assertRaises(ValueError):
            make_plan("1.1.2", 50, "49", "49", self.versions("1.1.2", "IN_REVIEW"))

    def test_unknown_lookup_output_never_falls_back_to_an_old_number(self):
        for value in ["", "None", "error: unauthorized", "49.1", "-1"]:
            with self.assertRaises(ValueError):
                apple_build(value)
        with self.assertRaises(ValueError):
            make_plan("1.1.2", 50, "49", "49", [])

    def test_duplicate_source_versions_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "project.yml"
            path.write_text('MARKETING_VERSION: "1.1.2"\nMARKETING_VERSION: "1.1.1"\nCURRENT_PROJECT_VERSION: "50"\n')
            with self.assertRaises(ValueError):
                project_version(path)


if __name__ == "__main__":
    unittest.main()
