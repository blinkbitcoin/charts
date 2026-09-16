"""Exercise the smoke-test contract without network access or credentials."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "esign-smoketest.sh"


class SmokeTest(unittest.TestCase):
    def run_smoke(self, outcomes):
        with tempfile.TemporaryDirectory() as temp:
            cwd = Path(temp)
            (cwd / "smoketest-settings").mkdir()
            (cwd / "smoketest-settings/helpers.sh").write_text(
                'setting() { echo "https://esign.example.test"; }\n'
            )
            (cwd / "bin").mkdir()
            (cwd / "outcomes").write_text("\n".join(outcomes) + "\n")
            (cwd / "bin/curl").write_text(
                '#!/usr/bin/env python3\n'
                'from pathlib import Path\nimport sys\n'
                'assert sys.argv[-1] == "https://esign.example.test/health"\n'
                'p = Path("outcomes"); lines = p.read_text().splitlines()\n'
                'line = lines[0]; p.write_text("\\n".join(lines[1:] or lines) + "\\n")\n'
                'with Path("calls").open("a") as f: f.write("call\\n")\n'
                'if line == "CURL_ERROR": sys.exit(22)\n'
                'print(line)\n'
            )
            (cwd / "bin/sleep").write_text('#!/bin/sh\nexit 0\n')
            for executable in (cwd / "bin").iterdir():
                executable.chmod(0o755)
            result = subprocess.run(
                ["bash", str(SCRIPT)], cwd=cwd,
                env={**os.environ, "PATH": str(cwd / "bin") + ":" + os.environ["PATH"]},
                capture_output=True, text=True,
            )
            return result.returncode, len((cwd / "calls").read_text().splitlines())

    def test_healthy(self):
        self.assertEqual(self.run_smoke(['{"status":"ok","capabilities":["mint"],"mint":"webform"}']), (0, 1))

    def test_recovers_from_failed_request(self):
        self.assertEqual(self.run_smoke(['CURL_ERROR', '{"status":"ok","capabilities":["mint"],"mint":"webform"}']), (0, 2))

    def test_unhealthy(self):
        for body in [
            'CURL_ERROR',
            'not json',
            '{}',
            '{"status":"error","capabilities":["mint"],"mint":"webform"}',
            '{"status":"ok","capabilities":[],"mint":"webform"}',
            '{"status":"ok","capabilities":["mint"]}',
            '{"status":"ok","capabilities":["mint"],"mint":"envelope"}',
        ]:
            with self.subTest(body=body):
                self.assertEqual(self.run_smoke([body]), (1, 15))


if __name__ == "__main__":
    unittest.main()
