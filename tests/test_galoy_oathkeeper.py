"""Render regressions for the galoy Oathkeeper access rules and NetworkPolicies.

Requires the galoy chart dependencies (helm dependency build charts/galoy).
"""

import re
import subprocess
import unittest
from pathlib import Path

import yaml

from test_lnurl_ingress import UniqueKeyLoader


CHART = Path(__file__).resolve().parents[1] / "charts" / "galoy"
INTERNAL_RULES = ("admin-backend", "blink-lnurl-server-internal")
PUBLIC_URLS = (
    "https://api.blink.sv/lnurl-internal/internal/blink/accounts",
    "https://api.blink.sv:443/lnurl-internal/internal/blink/accounts",
    "https://api.blink.sv/admin/graphql",
    "https://admin.blink.sv/admin/graphql",
    "https://galoy-oathkeeper-proxy.evil.example/lnurl-internal/x",
    "https://galoy-oathkeeper-proxy.evil.example/admin/graphql",
    "https://galoy-oathkeeper-proxy.ns.svc.cluster.local.evil.example/admin/graphql",
    "https://xgaloy-oathkeeper-proxy/lnurl-internal/x",
)


def setUpModule():
    if not (CHART / "charts" / "oathkeeper").exists() and not any(
        (CHART / "charts").glob("oathkeeper-*.tgz")
    ):
        raise unittest.SkipTest("run `helm dependency build charts/galoy` first")


def render(values=None):
    result = subprocess.run(
        ["helm", "template", "galoy", str(CHART), "--values", "-"],
        input=yaml.safe_dump(values or {}),
        text=True,
        capture_output=True,
        check=True,
    )
    return [doc for doc in yaml.load_all(result.stdout, Loader=UniqueKeyLoader) if doc]


def oathkeeper_regex(pattern):
    """Compile an Oathkeeper regexp match URL: text outside <...> is literal."""
    parts = re.split(r"(<[^<>]*>)", pattern)
    body = "".join(
        part[1:-1] if part.startswith("<") else re.escape(part) for part in parts
    )
    return re.compile(f"^{body}$")


class AccessRulesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        configmap = next(
            doc
            for doc in render()
            if doc["kind"] == "ConfigMap"
            and doc["metadata"]["name"] == "galoy-oathkeeper-rules"
        )
        rules = yaml.load(
            configmap["data"]["access-rules.json"], Loader=UniqueKeyLoader
        )
        cls.rules = {rule["id"]: oathkeeper_regex(rule["match"]["url"]) for rule in rules}

    def assertMatches(self, rule_id, url):
        self.assertRegex(url, self.rules[rule_id], f"{rule_id} should match {url}")

    def test_internal_rules_reject_public_hosts(self):
        for rule_id in INTERNAL_RULES:
            for url in PUBLIC_URLS:
                with self.subTest(rule=rule_id, url=url):
                    self.assertNotRegex(url, self.rules[rule_id])

    def test_lnurl_internal_matches_in_cluster_callers(self):
        for url in (
            "http://galoy-oathkeeper-proxy:4455/lnurl-internal/internal/blink/accounts",
            "http://galoy-oathkeeper-proxy/lnurl-internal/x",
            "http://galoy-oathkeeper-proxy.galoy-staging-galoy.svc.cluster.local:4455/lnurl-internal/x",
        ):
            with self.subTest(url=url):
                self.assertMatches("blink-lnurl-server-internal", url)

    def test_lnurl_internal_rejects_localhost(self):
        self.assertNotRegex(
            "http://localhost:4455/lnurl-internal/x",
            self.rules["blink-lnurl-server-internal"],
        )

    def test_admin_matches_in_cluster_callers(self):
        for url in (
            "http://galoy-oathkeeper-proxy:4455/admin/graphql",
            "http://galoy-oathkeeper-proxy.galoy-dev-galoy.svc.cluster.local:4455/admin/graphql",
            # dev regtest admin ingress (Decision API, X-Forwarded-Host: localhost)
            "http://localhost/admin/graphql",
        ):
            with self.subTest(url=url):
                self.assertMatches("admin-backend", url)

    def test_public_graphql_still_matches(self):
        self.assertMatches("galoy-router", "https://api.blink.sv/graphql")


class NetworkPolicyTest(unittest.TestCase):
    def policies(self, values=None):
        return {
            doc["metadata"]["name"]: doc
            for doc in render(values)
            # The bitnami subcharts render their own policies.
            if doc["kind"] == "NetworkPolicy"
            and doc["metadata"]["name"].startswith("galoy-oathkeeper")
        }

    def ingress_rule(self, policy, port):
        return next(
            rule
            for rule in policy["spec"]["ingress"]
            if rule["ports"] == [{"port": port, "protocol": "TCP"}]
        )

    def app_values(self, rule):
        return next(
            peer["podSelector"]["matchExpressions"][0]["values"]
            for peer in rule["from"]
            if "matchExpressions" in peer.get("podSelector", {})
        )

    def test_disabled_by_default(self):
        self.assertEqual(self.policies(), {})

    def test_enabled(self):
        policies = self.policies({"networkPolicy": {"enabled": True}})
        self.assertEqual(set(policies), {"galoy-oathkeeper-proxy", "galoy-oathkeeper-api"})
        oathkeeper = {"app.kubernetes.io/name": "oathkeeper", "app.kubernetes.io/instance": "galoy"}
        nginx = {
            "namespaceSelector": {
                "matchLabels": {"kubernetes.io/metadata.name": "ingress-nginx"}
            },
            "podSelector": {"matchLabels": {"app.kubernetes.io/name": "ingress-nginx"}},
        }
        for policy in policies.values():
            self.assertEqual(policy["spec"]["podSelector"], {"matchLabels": oathkeeper})
            self.assertEqual(policy["spec"]["policyTypes"], ["Ingress"])

        proxy = self.ingress_rule(policies["galoy-oathkeeper-proxy"], "http-proxy")
        self.assertIn(nginx, proxy["from"])
        self.assertEqual(
            self.app_values(proxy),
            ["api", "websocket", "trigger", "exporter", "galoy-cronjob", "consent"],
        )

        api = self.ingress_rule(policies["galoy-oathkeeper-api"], "http-api")
        self.assertIn(nginx, api["from"])
        self.assertIn({"podSelector": {"matchLabels": oathkeeper}}, api["from"])
        self.assertEqual(
            self.app_values(api),
            ["api", "websocket", "trigger", "exporter", "galoy-cronjob", "api-keys", "notifications"],
        )

        metrics = self.ingress_rule(policies["galoy-oathkeeper-api"], "http-metrics")
        self.assertNotIn("from", metrics)

    def test_extra_peers(self):
        addons = {"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "addons"}}}
        lnurl = {"podSelector": {"matchLabels": {"app": "blink-lnurl-server"}}}
        prometheus = {"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "monitoring"}}}
        policies = self.policies(
            {
                "networkPolicy": {
                    "enabled": True,
                    "oathkeeperProxy": {"extraFrom": [addons]},
                    "oathkeeperApi": {"extraFrom": [lnurl]},
                    "oathkeeperMetrics": {"from": [prometheus]},
                }
            }
        )
        proxy = self.ingress_rule(policies["galoy-oathkeeper-proxy"], "http-proxy")
        self.assertEqual(proxy["from"][-1], addons)
        self.assertNotIn(lnurl, proxy["from"])
        api = self.ingress_rule(policies["galoy-oathkeeper-api"], "http-api")
        self.assertEqual(api["from"][-1], lnurl)
        self.assertNotIn(addons, api["from"])
        metrics = self.ingress_rule(policies["galoy-oathkeeper-api"], "http-metrics")
        self.assertEqual(metrics["from"], [prometheus])


if __name__ == "__main__":
    unittest.main()
