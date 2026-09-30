"""Check the ingress rate-limit contract through Helm's actual rendered manifest."""
import json
from pathlib import Path
import re
import subprocess
import unittest

CHART = Path(__file__).resolve().parents[3] / "charts/esign"
PREFIX = "nginx.ingress.kubernetes.io/"
LIMITS = {
    "limitRps": ("limit-rps", 2),
    "limitRpm": ("limit-rpm", 30),
    "limitBurstMultiplier": ("limit-burst-multiplier", 2),
    "limitConnections": ("limit-connections", 4),
}


class IngressRateLimits(unittest.TestCase):
    def render(self, *settings):
        command = ["helm", "template", "esign", str(CHART),
                   "--set", "ingress.enabled=true", "--set", "ingress.host=esign.example.test"]
        for setting in settings:
            command.extend(["--set", setting])
        return subprocess.run(command, capture_output=True, text=True)

    def limits(self, manifest):
        # JSON decoding checks that Kubernetes annotation values are quoted strings.
        entries = re.findall(r"^\s+(nginx\.ingress\.kubernetes\.io/limit-[\w-]+): (.+)$",
                             manifest, re.MULTILINE)
        self.assertEqual(len(entries), len(LIMITS))
        result = {key: json.loads(value) for key, value in entries}
        self.assertTrue(all(isinstance(value, str) for value in result.values()))
        return result

    def test_default_limits(self):
        result = self.render()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.limits(result.stdout),
                         {PREFIX + annotation: str(value) for annotation, value in LIMITS.values()})

    def test_custom_limits(self):
        result = self.render(*(f"ingress.{key}={value + 1}" for key, (_, value) in LIMITS.items()))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.limits(result.stdout),
                         {PREFIX + annotation: str(value + 1) for annotation, value in LIMITS.values()})

    def test_disabled_ingress(self):
        result = self.render("ingress.enabled=false")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("kind: Ingress", result.stdout)
        self.assertNotIn(PREFIX, result.stdout)

    def test_invalid_limits_rejected(self):
        for key in LIMITS:
            for value in ["0", "-1", "1.5", "false", "invalid", "null"]:
                with self.subTest(key=key, value=value):
                    result = self.render(f"ingress.{key}={value}")
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(key, result.stderr)

    def test_minimum_limits(self):
        result = self.render(*(f"ingress.{key}=1" for key in LIMITS))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(set(self.limits(result.stdout).values()), {"1"})


if __name__ == "__main__":
    unittest.main()
