"""Check both bootstrap and automatic-promotion pipeline configurations."""
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[3]
BUMP = "bump-esign-in-deployments"
TESTFLIGHT = "esign-testflight"


class PromotionBootstrap(unittest.TestCase):
    def render(self, enabled=None):
        command = ["ytt", "-f", "ci/pipeline.yml", "-f", "ci/pipeline-fragments.lib.yml",
                   "-f", "ci/values.yml", "-o", "json"]
        if enabled is not None:
            command.extend(["--data-value-yaml", f"enable_esign_deployment_bump={str(enabled).lower()}"])
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_explicitly_disabled(self):
        pipeline = self.render(False)
        jobs = {job["name"] for job in pipeline["jobs"]}
        self.assertIn(TESTFLIGHT, jobs)
        self.assertNotIn(BUMP, jobs)
        for group in pipeline["groups"]:
            self.assertNotIn(BUMP, group["jobs"])
            if group["name"] in ("all", "esign"):
                self.assertIn(TESTFLIGHT, group["jobs"])

    def test_enabled_promotion_requires_successful_testflight(self):
        pipeline = self.render(True)
        self.assertEqual(self.render(), pipeline)
        job = next(job for job in pipeline["jobs"] if job["name"] == BUMP)
        resource = next(step for step in job["plan"][0]["in_parallel"] if step["get"] == "esign-chart")
        self.assertEqual(resource["passed"], [TESTFLIGHT])
        self.assertIs(resource["trigger"], True)
        groups = {group["name"]: group["jobs"] for group in pipeline["groups"]}
        self.assertIn(BUMP, groups["all"])
        self.assertEqual(groups["esign"], [TESTFLIGHT, BUMP])
        # Enabling promotion adds only that job and its group references.
        disabled = self.render(False)
        pipeline["jobs"].remove(job)
        for group in pipeline["groups"]:
            if BUMP in group["jobs"]:
                group["jobs"].remove(BUMP)
        self.assertEqual(pipeline, disabled)


if __name__ == "__main__":
    unittest.main()
