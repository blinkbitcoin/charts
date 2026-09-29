"""Render real manifests to preserve existing offsets and isolate CI workers."""
from pathlib import Path
import re
from string import Template
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[3]
CHART = ROOT / "charts/kafka-connect"
TESTFLIGHT_VALUES = ROOT / "ci/testflight/kafka-connect/testflight-values.yml.tmpl"
KEYS = ("group.id", "offset.storage.topic", "config.storage.topic", "status.storage.topic")
LEGACY = ("connect-cluster", "connect-cluster-offsets",
          "connect-cluster-configs", "connect-cluster-status")


class ConnectIsolation(unittest.TestCase):
    def render(self, instance=None, release="kafka-connect", cluster_id=None,
               testflight=False):
        command = ["helm", "template", release, str(CHART),
                   "--show-only", "templates/kafka-connect.yaml"]
        values = None
        if testflight:
            values = Template(TESTFLIGHT_VALUES.read_text()).substitute(
                kafka_connect_instance_name=instance)
            command += ["--values", "-"]
        elif instance is not None:
            command += ["--set-string", f"kafkaConnectInstanceName={instance}"]
        if cluster_id is not None:
            command += ["--set-string", f"connectClusterId={cluster_id}"]
        result = subprocess.run(command, input=values, capture_output=True,
                                text=True, check=True)
        identities = []
        for key in KEYS:
            matches = re.findall(rf"^    {re.escape(key)}: (\S+)$", result.stdout, re.M)
            self.assertEqual(len(matches), 1, (key, result.stdout))
            identities.append(matches[0])
        self.assertIn('bootstrapServers: "kafka-kafka-plain-bootstrap:9092"', result.stdout)
        self.assertIn(f"  name: {instance or 'kafka'}\n", result.stdout)
        return tuple(identities)

    def test_default_and_explicit_kafka_preserve_existing_state(self):
        for instance in (None, "kafka"):
            for release in ("primary", "secondary"):
                with self.subTest(instance=instance, release=release):
                    self.assertEqual(self.render(instance, release), LEGACY)

    def test_custom_instance_names_preserve_existing_state(self):
        for instance in ("custom-prod", "isolated-worker"):
            with self.subTest(instance=instance):
                self.assertEqual(self.render(instance), LEGACY)

    def test_testflights_share_neither_group_nor_internal_topics(self):
        all_clusters = [set(LEGACY)]
        for instance in ("kafka-connect-testflight-0123456-kafka",
                         "kafka-connect-testflight-abcdef0-kafka"):
            values = self.render(instance, testflight=True)
            self.assertEqual(values, tuple(f"{instance}-{value}" for value in LEGACY))
            for other in all_clusters:
                self.assertTrue(set(values).isdisjoint(other))
            all_clusters.append(set(values))

    def test_explicit_identity_is_independent_of_resource_and_release_names(self):
        expected = ("durable-workers", "durable-workers-offsets",
                    "durable-workers-configs", "durable-workers-status")
        for instance in ("kafka", "custom-prod", "renamed-worker"):
            for release in ("release-one", "release-two"):
                with self.subTest(instance=instance, release=release):
                    self.assertEqual(self.render(instance, release, "durable-workers"),
                                     expected)

    def test_testflight_identity_is_stable_across_helm_release_names(self):
        instance = "kafka-connect-testflight-0123456-kafka"
        self.assertEqual(self.render(instance, "release-one", testflight=True),
                         self.render(instance, "release-two", testflight=True))


if __name__ == "__main__":
    unittest.main()
