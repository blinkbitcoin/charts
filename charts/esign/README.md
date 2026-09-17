# eSign

Deploys `ghcr.io/blinkbitcoin/esign-service:0.6.0` on port 4100.
The image is pinned by `image.digest`; update the tag and digest together for
release upgrades. `IfNotPresent` reuses only content matching that digest.
`PORT` is chart-owned: set `service.port` to change it. Setting `env.PORT`
is rejected, including when it matches `service.port`.
`ESIGN_MINT_MODE=envelope` selects the envelope mint, without a database.
Database-backed envelope orchestration is outside this deployment's scope.

Provide an existing Secret (default `esign`) containing the four DocuSign
JWT authentication variables: `DOCUSIGN_INTEGRATION_KEY`, `DOCUSIGN_USER_ID`,
`DOCUSIGN_ACCOUNT_ID`, and `DOCUSIGN_PRIVATE_KEY`. Preserve multiline PEM.

Supply non-secret runtime configuration through `env`:

- `DOCUSIGN_TEMPLATE_ID`: one ID or an ordered comma-separated list. Multiple
  templates produce one envelope, with documents in the listed order.
- `DOCUSIGN_SIGNER_ROLE`: the signer role shared by all templates.
- `DOCUSIGN_RETURN_URL`: the public service URL plus `/signing/return`.
- `DOCUSIGN_BASE_URL` and `DOCUSIGN_OAUTH_URL`: account-specific API endpoints.
- `ESIGN_TRUST_PROXY`: set `"true"` behind an ingress that overwrites forwarded
  client-address headers. The chart does not enable proxy trust by default.

Keep these settings out of the existing Secret to avoid duplicate ownership.
The default provider is `docusign`. The chart sets `ESIGN_STRICT=false` and leaves
`ESIGN_SESSION_JWKS_URL`, `ESIGN_SESSION_SECRET`, and `ESIGN_PREFILL_URL` unset:
the service takes a nonempty bearer token as the user ID and passes client
prefill directly to the envelope mint. Its boot banner reports these choices.
To enforce verification later, configure session verification and a prefill
callback before enabling `ESIGN_STRICT=true`.

See the [0.6.0 environment reference](https://github.com/blinkbitcoin/esign/blob/v0.6.0/packages/esign-service/README.md).

Enable ingress with `ingress.enabled=true` and `ingress.host`.
The ingress uses nginx and the existing `letsencrypt-issuer` ClusterIssuer.

## Ingress rate limiting

The nginx ingress applies these configurable defaults to every path, including
`/envelope/instance`, `/signing/return`, and `/health`:

| Value | Default |
| --- | --- |
| `ingress.limitRps` | 2 requests/second |
| `ingress.limitRpm` | 30 requests/minute |
| `ingress.limitBurstMultiplier` | 2 |
| `ingress.limitConnections` | 4 concurrent connections |

All four values must be positive integers; chart validation rejects zero,
negative, missing and non-integer settings. Both request-rate limits apply;
the burst multiplier sets each request-rate limit's burst allowance. It does
not affect the concurrent-connection limit or impose a global quota.

These limits are **per client IP and per ingress-nginx controller replica**.
Additional replicas increase aggregate capacity, and callers behind the same
NAT share the allowance. Exceeded limits normally return HTTP 503 unless the
controller's status-code configuration overrides it. See the
[ingress-nginx rate-limit reference](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#rate-limiting).

Before rollout, verify that the ingress sees the real client IP and accepts
forwarded IP headers only from trusted proxies. Check the effective controller
configuration and rejection behavior with harmless requests in staging; do not
load-test envelope creation against DocuSign. Tune values for legitimate traffic.

Rate limiting reduces per-IP request flooding. It does not authenticate callers,
validate signing data, impose a global DocuSign quota, or stop a distributed
bandwidth-saturation attack. Restricted tester access is still needed for an
unverified demo iteration; public production signing still needs session and
trusted signer/terms validation (or an equivalent enforced gateway boundary).

Startup, readiness, and liveness probes request `GET /health`. The smoke test
checks `status == "ok"`, capability `mint`, and `mint == "envelope"`, matching
the release health handler in `packages/esign-service/src/app.ts`. Basic health
assertions are in `packages/esign-service/tests/server.test.ts`. This verifies
reachability and mint mode; it does not exercise a DocuSign signing flow.

GitHub Actions runs Helm checks and smoke-script fixtures. Concourse
`esign-testflight` creates an isolated namespace and uses the mock provider in
envelope mode, with strict mode disabled and no ingress. It runs the health
smoke test and tears down on success.

Automatic promotion is initially disabled (`enable_esign_deployment_bump: false`
in `ci/values.yml`); testflight remains enabled. First merge this chart and pass
its testflight, then merge [the initial deployment target](https://github.com/blinkbitcoin/blink-deployments/pull/10299),
which includes the initial chart pin and vendored files. Confirm the configured
deployments branch contains both `esign_git_ref` and its eSign vendir source.
Then set `enable_esign_deployment_bump: true` and repipe `helm-charts` to enable
`bump-esign-in-deployments` for subsequent successful testflights.
