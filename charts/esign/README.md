# eSign

Deploys `ghcr.io/blinkbitcoin/esign-service:0.5.0` on port 4100.
The hosted-form mint runs without a database. Envelope orchestration is outside
this deployment's scope; it additionally needs PostgreSQL and webhook signing.

Provide an existing Secret (default `esign`) containing the six `DOCUSIGN_*`
variables: `INTEGRATION_KEY`, `USER_ID`, `ACCOUNT_ID`, `PRIVATE_KEY`, `WEBFORM_ID`,
and `TEMPLATE_ID`. The private key is the original multiline PEM.

Set non-secret runtime configuration through `env`: `SESSION_JWKS_URL`,
`TERMS_URL`, `DOCUSIGN_RETURN_URL`, and the account's DocuSign API endpoints.
The default provider is `docusign` and `ESIGN_ENV` is `production`.
Production configuration must satisfy the service's boot guards. No insecure
authentication or client-prefill bypass is enabled by the chart.

Enable ingress with `ingress.enabled=true` and `ingress.host`.
The ingress uses nginx and the existing `letsencrypt-issuer` ClusterIssuer.

Startup, readiness, and liveness probes request `GET /health`. The smoke test
also checks `status == "ok"` and the `mint` capability, matching eSign v0.5.0
`packages/esign-service/tests/server.test.ts` and `scripts/ci/docker-smoke.sh`.
This tests endpoint reachability and service health, not a DocuSign signing flow.

CI runs Helm checks and smoke-script fixtures in GitHub Actions. Concourse
`esign-testflight` creates an isolated namespace, uses the mock provider with
explicit insecure development mode and no ingress, runs the health smoke test,
and tears down on success. A passing testflight feeds `bump-esign-in-deployments`.
