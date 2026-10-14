"""Offline checks for local testflight charts and dependency triggers."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "ci/tasks/prepare-testflight.sh"


class TestflightPreparation(unittest.TestCase):
    def prepare(self, chart, fallback=False, missing_dependency=False):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        directory = Path(tmp.name)
        repo = directory / "repo"
        (repo / ".git").mkdir(parents=True)
        (repo / ".git/short_ref").write_text("1234abc\n")
        (directory / "testflight").mkdir()
        tf_source = directory / "pipeline-tasks" if fallback else repo
        shutil.copytree(ROOT / f"ci/testflight/{chart}", tf_source / f"ci/testflight/{chart}")
        shutil.copytree(ROOT / f"charts/{chart}", repo / f"charts/{chart}")
        if chart == "fulcrum" and not missing_dependency:
            shutil.copytree(ROOT / "charts/bitcoind", repo / "charts/bitcoind")
        result = subprocess.run(["bash", str(SCRIPT)], cwd=directory,
                                env={**os.environ, "CHART": chart}, capture_output=True, text=True)
        return directory, result

    def test_fulcrum_uses_checkout_dependency_and_renders_offline(self):
        directory, result = self.prepare("fulcrum")
        self.assertEqual(result.returncode, 0, result.stderr)
        tf = directory / "testflight/tf"
        self.assertRegex((tf / "main.tf").read_text(), r'chart\s*=\s*"\$\{path.module\}/bitcoind-chart"')
        block = (tf / "main.tf").read_text().split('resource "helm_release" "bitcoind"')[1].split('resource "helm_release" "fulcrum"')[0]
        self.assertNotIn("repository", block)
        for source in (directory / "repo/charts/bitcoind").rglob("*"):
            if source.is_file():
                self.assertEqual(source.read_bytes(), (tf / "bitcoind-chart" / source.relative_to(directory / "repo/charts/bitcoind")).read_bytes())
        for chart, values in [("bitcoind-chart", "bitcoind-values.yml"), ("chart", "testflight-values.yml")]:
            result = subprocess.run(["helm", "template", "test", str(tf / chart), "-f", str(tf / values)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("kind: StatefulSet", result.stdout)
        self.assertEqual((directory / "testflight/env_name").read_text(), "fulcrum-testflight-1234abc\n")
        self.assertEqual((tf / "terraform.tfvars").read_text(), 'testflight_namespace = "fulcrum-testflight-1234abc"\n')

    def test_other_chart_and_fallback_preparation(self):
        for fallback in [False, True]:
            with self.subTest(fallback=fallback):
                directory, result = self.prepare("bitcoind", fallback=fallback)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue((directory / "testflight/tf/chart/Chart.yaml").exists())
                self.assertFalse((directory / "testflight/tf/bitcoind-chart").exists())
                self.assertEqual((directory / "testflight/env_name").read_text(), "bitcoind-testflight-1234abc\n")

    def test_missing_fulcrum_dependency_fails_before_handoff(self):
        directory, result = self.prepare("fulcrum", missing_dependency=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((directory / "testflight/env_name").exists())

    def test_dependency_changes_trigger_fulcrum_testflight(self):
        result = subprocess.run(["ytt", "-f", "ci/pipeline.yml", "-f", "ci/pipeline-fragments.lib.yml",
                                 "-f", "ci/values.yml", "-o", "json"], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        pipeline = json.loads(result.stdout)
        resources = {r["name"]: r for r in pipeline["resources"]}
        source = resources["fulcrum-chart"]["source"]
        self.assertEqual(source["uri"], "git@github.com:blinkbitcoin/charts.git")
        self.assertIn("private_key", source)
        self.assertIn("charts/bitcoind/*", source["paths"])
        self.assertIn("charts/bitcoind/**/*", source["paths"])
        self.assertNotIn("charts/bitcoind/Chart.yaml", source["ignore_paths"])
        self.assertNotIn("charts/bitcoind/**/*", resources["lnd-chart"]["source"]["paths"])
        job = next(j for j in pipeline["jobs"] if j["name"] == "fulcrum-testflight")
        self.assertEqual(job["plan"][0]["in_parallel"], [{"get": "fulcrum-chart", "trigger": True}])
        prepare = job["plan"][1]["config"]
        self.assertEqual(prepare["inputs"], [{"name": "fulcrum-chart", "path": "repo"}])
        self.assertEqual(prepare["params"]["CHART"], "fulcrum")


if __name__ == "__main__":
    unittest.main()
