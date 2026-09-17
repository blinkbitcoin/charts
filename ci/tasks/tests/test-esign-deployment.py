"""Exercise the chart-owned port and immutable image contract through Helm."""
import re
from pathlib import Path
import subprocess
import unittest

CHART = Path(__file__).resolve().parents[3] / "charts/esign"
DIGEST = "sha256:93f6eae73129911eb8b14a58aa9975c565692606aa74512e5cdd5ddf742139c7"


class DeploymentContract(unittest.TestCase):
    def render(self, *settings):
        command = ["helm", "template", "esign", str(CHART)]
        for setting in settings:
            command.extend(["--set", setting])
        return subprocess.run(command, capture_output=True, text=True)

    def test_port_and_probes_stay_aligned(self):
        for settings, port in [((), 4100), (("service.port=4200",), 4200)]:
            with self.subTest(port=port):
                result = self.render(*settings, "env.EXTRA=example")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(re.findall(r'- name: PORT\s+value: "(\d+)"', result.stdout),
                                 [str(port)])
                self.assertIn(f"containerPort: {port}", result.stdout)
                self.assertRegex(result.stdout, rf"port: {port}\s+targetPort: http")
                self.assertEqual(len(re.findall(r"path: /health\s+port: http", result.stdout)), 3)
                self.assertIn('- name: EXTRA\n              value: "example"', result.stdout)

    def test_env_port_is_rejected_even_when_matching(self):
        for port in (4100, 4200):
            with self.subTest(port=port):
                result = self.render(f"env.PORT={port}")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("env.PORT is reserved; set service.port instead", result.stderr)

    def test_default_image_is_pinned(self):
        result = self.render()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f'image: "ghcr.io/blinkbitcoin/esign-service:0.6.0@{DIGEST}"', result.stdout)

    def test_image_override_remains_pinned(self):
        digest = "sha256:" + "a" * 64
        result = self.render("image.repository=example.test/esign", "image.tag=next",
                             f"image.digest={digest}")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f'image: "example.test/esign:next@{digest}"', result.stdout)

    def test_invalid_or_missing_digest_rejected(self):
        for digest in ("", "null", "latest", "sha256:abc", "sha256:" + "g" * 64):
            with self.subTest(digest=digest):
                result = self.render(f"image.digest={digest}")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("digest", result.stderr)


if __name__ == "__main__":
    unittest.main()
