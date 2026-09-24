"""Render real manifests to preserve existing offsets and isolate CI workers."""
from pathlib import Path
import re
import subprocess
import unittest

CHART = Path(__file__).resolve().parents[3] / "charts/kafka-connect"
KEYS = ("group.id", "offset.storage.topic", "config.storage.topic", "status.storage.topic")
LEGACY = ("connect-cluster", "connect-cluster-offsets",
          "connect-cluster-configs", "connect-cluster-status")


class ConnectIsolation(unittest.TestCase):
    def render(self, instance=None, release="kafka-connect"):
        command = ["helm", "template", release, str(CHART),
                   "--show-only", "templates/kafka-connect.yaml"]
        if instance is not None:
            command += ["--set-string", f"kafkaConnectInstanceName={instance}"]
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        values = []
        for key in KEYS:
            matches = re.findall(rf"^    {re.escape(key)}: (\S+)$", result.stdout, re.M)
            self.assertEqual(len(matches), 1, (key, result.stdout))
            values.append(matches[0])
        self.assertIn('bootstrapServers: "kafka-kafka-plain-bootstrap:9092"', result.stdout)
        self.assertIn(f"  name: {instance or 'kafka'}\n", result.stdout)
        return tuple(values)

    def test_default_and_explicit_kafka_preserve_existing_state(self):
        for instance in (None, "kafka"):
            for release in ("primary", "secondary"):
                with self.subTest(instance=instance, release=release):
                    self.assertEqual(self.render(instance, release), LEGACY)

    def test_testflights_share_neither_group_nor_internal_topics(self):
        all_clusters = [set(LEGACY)]
        for instance in ("kafka-connect-testflight-0123456-kafka",
                         "kafka-connect-testflight-abcdef0-kafka"):
            values = self.render(instance)
            self.assertEqual(values, tuple(f"{instance}-{value}" for value in LEGACY))
            for other in all_clusters:
                self.assertTrue(set(values).isdisjoint(other))
            all_clusters.append(set(values))

    def test_identity_is_stable_across_helm_release_names(self):
        instance = "isolated-worker"
        self.assertEqual(self.render(instance, "release-one"),
                         self.render(instance, "release-two"))


if __name__ == "__main__":
    unittest.main()
