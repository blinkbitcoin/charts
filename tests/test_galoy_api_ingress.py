"""Render regressions for the galoy api Ingress authMode and Oathkeeper serving knobs.

Requires the galoy chart dependencies (helm dependency build charts/galoy).
"""

import subprocess
import unittest

import yaml

from test_galoy_oathkeeper import render, setUpModule  # noqa: F401
from test_lnurl_ingress import UniqueKeyLoader


HOST = "api.example.com"
PROXY = ("galoy-oathkeeper-proxy", 4455)
AUTH_ANNOTATIONS = {
    "nginx.ingress.kubernetes.io/auth-url": "http://galoy-oathkeeper-api.default.svc.cluster.local:4456/decisions",
    "nginx.ingress.kubernetes.io/auth-method": "GET",
    "nginx.ingress.kubernetes.io/auth-response-headers": "Authorization, Set-Cookie, X-Appcheck-Jti",
    "nginx.ingress.kubernetes.io/auth-forward-cookie": "*",
    "nginx.ingress.kubernetes.io/auth-snippet": (
        "proxy_set_header X-Original-URL $request_uri;\n"
        "proxy_set_header X-Forwarded-Method $request_method;\n"
        "proxy_set_header X-Forwarded-Proto $scheme;\n"
        "proxy_set_header X-Forwarded-Host $host;\n"
        "proxy_set_header X-Forwarded-Uri $request_uri;\n"
    ),
}
KEPT_ANNOTATIONS = {
    "cert-manager.io/cluster-issuer": "letsencrypt-issuer",
    "nginx.ingress.kubernetes.io/enable-cors": "true",
    "nginx.ingress.kubernetes.io/cors-allow-headers": "DNT,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization,X-API-KEY,oauth2-token",
    "nginx.ingress.kubernetes.io/proxy-read-timeout": "3600",
    "nginx.ingress.kubernetes.io/proxy-send-timeout": "3600",
    "nginx.ingress.kubernetes.io/proxy-connect-timeout": "1s",
    "nginx.ingress.kubernetes.io/proxy-next-upstream": "error timeout",
    "nginx.ingress.kubernetes.io/proxy-next-upstream-tries": "3",
    "nginx.ingress.kubernetes.io/limit-rpm": "120",
    "nginx.ingress.kubernetes.io/limit-burst-multiplier": "20",
    "nginx.ingress.kubernetes.io/limit-connections": "80",
}
INTERNAL_PATHS = (
    "/lnurl-internal/internal/blink/accounts",
    "/lnurl-internal/",
    "/admin/graphql",
    "/admin/",
)


def api_ingress(**ingress):
    documents = render(
        {"galoy": {"api": {"ingress": {"enabled": True, "hosts": [HOST], **ingress}}}}
    )
    ingresses = [
        doc
        for doc in documents
        if doc["kind"] == "Ingress" and doc["metadata"]["name"] == "api"
    ]
    if len(ingresses) != 1:
        raise AssertionError(f"expected one api Ingress, got {len(ingresses)}")
    return ingresses[0]


def paths(ingress):
    (rule,) = ingress["spec"]["rules"]
    return [
        (
            path["pathType"],
            path["path"],
            path["backend"]["service"]["name"],
            path["backend"]["service"]["port"]["number"],
        )
        for path in rule["http"]["paths"]
    ]


def routes(path_type, path, request_path):
    """Kubernetes Exact/Prefix semantics; nginx treats ImplementationSpecific as a prefix."""
    if path_type == "Exact":
        return request_path == path
    if path_type == "Prefix":
        prefix = path.rstrip("/")
        return request_path == prefix or request_path.startswith(prefix + "/")
    return request_path.startswith(path)


class AuthModeTest(unittest.TestCase):
    def test_decision_is_default(self):
        self.assertEqual(api_ingress(), api_ingress(authMode="decision"))

    def test_decision_mode(self):
        ingress = api_ingress()
        self.assertEqual(
            ingress["metadata"]["annotations"], {**KEPT_ANNOTATIONS, **AUTH_ANNOTATIONS}
        )
        self.assertEqual(
            paths(ingress),
            [
                ("ImplementationSpecific", "/graphql", "galoy-router", 80),
                ("ImplementationSpecific", "/", "api", 4002),
            ],
        )

    def test_proxy_mode(self):
        ingress = api_ingress(authMode="proxy")
        annotations = ingress["metadata"]["annotations"]
        self.assertEqual(annotations, KEPT_ANNOTATIONS)
        self.assertFalse(
            [key for key in annotations if key.startswith("nginx.ingress.kubernetes.io/auth-")]
        )
        self.assertEqual(
            paths(ingress),
            [("Exact", "/graphql", *PROXY), ("Prefix", "/auth/", *PROXY)],
        )
        self.assertEqual(ingress["spec"]["tls"], [{"hosts": [HOST], "secretName": f"{HOST}-tls"}])

    def test_proxy_mode_keeps_custom_annotations(self):
        annotations = api_ingress(authMode="proxy", annotations={"example.com/x": "custom"})[
            "metadata"
        ]["annotations"]
        self.assertEqual(annotations, {**KEPT_ANNOTATIONS, "example.com/x": "custom"})

    def test_proxy_mode_routes(self):
        rendered = paths(api_ingress(authMode="proxy"))

        def backends(request_path):
            return [
                (name, port)
                for path_type, path, name, port in rendered
                if routes(path_type, path, request_path)
            ]

        for request_path in INTERNAL_PATHS + ("/", "/graphql/x", "/graphqlx", "/authx"):
            with self.subTest(path=request_path):
                self.assertEqual(backends(request_path), [])
        for request_path in ("/graphql", "/auth/phone/login", "/auth/"):
            with self.subTest(path=request_path):
                self.assertEqual(backends(request_path), [PROXY])

    def test_proxy_mode_renders_extra_paths(self):
        extra = {
            "path": "/healthz",
            "pathType": "Exact",
            "backend": {"service": {"name": "api", "port": {"number": 4002}}},
        }
        self.assertEqual(
            paths(api_ingress(authMode="proxy", extraPaths=[extra]))[0],
            ("Exact", "/healthz", "api", 4002),
        )

    def test_invalid_auth_mode_fails(self):
        for values in (
            {"galoy": {"api": {"ingress": {"authMode": "bogus"}}}},
            {"galoy": {"api": {"ingress": {"enabled": True, "authMode": "Proxy"}}}},
        ):
            with self.subTest(values=values):
                with self.assertRaises(subprocess.CalledProcessError) as raised:
                    render(values)
                self.assertIn("galoy.api.ingress.authMode must be", raised.exception.stderr)


class OathkeeperServingTest(unittest.TestCase):
    def named(self, documents, kind, name="galoy-oathkeeper"):
        return [
            doc
            for doc in documents
            if doc["kind"] == kind and doc["metadata"]["name"] == name
        ]

    def test_proxy_timeouts_match_ingress(self):
        configmap = self.named(render(), "ConfigMap", "galoy-oathkeeper-config")[0]
        config = yaml.load(configmap["data"]["config.yaml"], Loader=UniqueKeyLoader)
        self.assertEqual(
            config["serve"]["proxy"]["timeout"],
            {"read": "3600s", "write": "3600s", "idle": "3600s"},
        )

    def test_pdb_and_hpa_disabled_by_default(self):
        documents = render()
        self.assertEqual(self.named(documents, "PodDisruptionBudget"), [])
        self.assertEqual(self.named(documents, "HorizontalPodAutoscaler"), [])

    def test_pdb_and_hpa_enabled(self):
        documents = render(
            {
                "oathkeeper": {
                    "pdb": {"enabled": True},
                    "deployment": {
                        "autoscaling": {
                            "enabled": True,
                            "targetCPU": {"type": "Utilization", "averageUtilization": 80},
                        }
                    },
                }
            }
        )
        (pdb,) = self.named(documents, "PodDisruptionBudget")
        self.assertEqual(pdb["spec"]["maxUnavailable"], 1)
        self.assertNotIn("minAvailable", pdb["spec"])
        self.assertEqual(
            pdb["spec"]["selector"]["matchLabels"],
            {"app.kubernetes.io/name": "oathkeeper", "app.kubernetes.io/instance": "galoy"},
        )
        (hpa,) = self.named(documents, "HorizontalPodAutoscaler")
        self.assertEqual(hpa["spec"]["scaleTargetRef"]["name"], "galoy-oathkeeper")
        self.assertEqual((hpa["spec"]["minReplicas"], hpa["spec"]["maxReplicas"]), (2, 5))


if __name__ == "__main__":
    unittest.main()
