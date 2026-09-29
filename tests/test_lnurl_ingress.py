"""Render regressions: python -m unittest discover -s tests -v (requires PyYAML)."""

import subprocess
import unittest
from pathlib import Path

import yaml


CHART = Path(__file__).resolve().parents[1] / "charts" / "blink-lnurl-server"
ISSUER = "cert-manager.io/cluster-issuer"


class UniqueKeyLoader(yaml.SafeLoader):
    """Reject duplicate mapping keys instead of silently accepting the last value."""

    def construct_mapping(self, node, deep=False):
        keys = set()
        for key_node, _ in node.value:
            key = self.construct_object(key_node, deep=deep)
            if key in keys:
                raise ValueError(f"duplicate mapping key: {key}")
            keys.add(key)
        return super().construct_mapping(node, deep=deep)


def render(values):
    result = subprocess.run(
        ["helm", "template", "test", str(CHART), "--values", "-"],
        input=yaml.safe_dump(values),
        text=True,
        capture_output=True,
        check=True,
    )
    return [doc for doc in yaml.load_all(result.stdout, Loader=UniqueKeyLoader) if doc]


class IngressAnnotationsTest(unittest.TestCase):
    def ingress(self, **values):
        documents = render(
            {"ingress": {"enabled": True, "hosts": ["lnurl.example.com"], **values}}
        )
        ingresses = [doc for doc in documents if doc["kind"] == "Ingress"]
        self.assertEqual(len(ingresses), 1)
        return ingresses[0]

    def test_ingress_disabled_by_default(self):
        self.assertFalse(any(doc["kind"] == "Ingress" for doc in render({})))

    def test_default_annotations(self):
        self.assertEqual(
            self.ingress()["metadata"]["annotations"], {ISSUER: "letsencrypt-issuer"}
        )

    def test_empty_annotations(self):
        self.assertEqual(
            self.ingress(annotations={})["metadata"]["annotations"],
            {ISSUER: "letsencrypt-issuer"},
        )

    def test_unset_annotations(self):
        # Helm removes the default key when the override is null.
        self.assertEqual(
            self.ingress(annotations=None)["metadata"]["annotations"],
            {ISSUER: "letsencrypt-issuer"},
        )

    def test_custom_annotation(self):
        self.assertEqual(
            self.ingress(annotations={"nginx.ingress.kubernetes.io/limit-rps": "5"})[
                "metadata"
            ]["annotations"],
            {ISSUER: "letsencrypt-issuer", "nginx.ingress.kubernetes.io/limit-rps": "5"},
        )

    def test_multiline_server_snippet(self):
        snippet = "location ~ ^/verify/ {\n  return 429;\n}\n"
        self.assertEqual(
            self.ingress(
                annotations={"nginx.ingress.kubernetes.io/server-snippet": snippet}
            )["metadata"]["annotations"],
            {
                ISSUER: "letsencrypt-issuer",
                "nginx.ingress.kubernetes.io/server-snippet": snippet,
            },
        )

    def test_builtin_issuer_wins_collision(self):
        ingress = self.ingress(
            annotations={ISSUER: "custom-issuer", "example.com/custom": "preserved"}
        )
        self.assertEqual(
            ingress["metadata"]["annotations"],
            {ISSUER: "letsencrypt-issuer", "example.com/custom": "preserved"},
        )


if __name__ == "__main__":
    unittest.main()
