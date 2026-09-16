# eSign

Deploys `ghcr.io/blinkbitcoin/esign-service:0.6.0` on port 4100.
`ESIGN_MINT_MODE=webform` selects the hosted-form mint, without a database.
Database-backed envelope orchestration is outside this deployment's scope.

Provide an existing Secret (default `esign`) containing the six `DOCUSIGN_*`
variables: `INTEGRATION_KEY`, `USER_ID`, `ACCOUNT_ID`, `PRIVATE_KEY`, `WEBFORM_ID`,
and `TEMPLATE_ID`. The private key is the original multiline PEM. `TEMPLATE_ID`
is retained for future envelope use; the Web Form mint uses `WEBFORM_ID`.

Set non-secret runtime configuration through `env`, including
`DOCUSIGN_RETURN_URL` and the account's DocuSign API endpoints. The default
provider is `docusign`. The chart explicitly sets `ESIGN_STRICT=false` and leaves
`ESIGN_SESSION_JWKS_URL`, `ESIGN_SESSION_SECRET`, and `ESIGN_PREFILL_URL` unset:
the service takes a nonempty bearer token as the user ID and passes client
prefill directly to the form. Its boot banner reports these choices. To enforce
verification later, configure session verification and a prefill callback before
enabling `ESIGN_STRICT=true`.

Release 0.6.0 replaces the old `ALLOW_INSECURE_DEV`,
`ESIGN_ALLOW_CLIENT_PREFILL`, and `ESIGN_ENV` switches with this contract. See the
[release environment reference](https://github.com/blinkbitcoin/esign/blob/v0.6.0/packages/esign-service/README.md).

Enable ingress with `ingress.enabled=true` and `ingress.host`.
The ingress uses nginx and the existing `letsencrypt-issuer` ClusterIssuer.

Startup, readiness, and liveness probes request `GET /health`. The smoke test
checks `status == "ok"`, the `mint` capability, and `mint == "webform"`, matching
the health contract in eSign v0.6.0 `packages/esign-service/src/app.ts` and the
basic health assertions in `packages/esign-service/tests/server.test.ts`. This
tests endpoint reachability and the configured mint mode, not a DocuSign signing flow.

CI runs Helm checks and smoke-script fixtures in GitHub Actions. Concourse
`esign-testflight` creates an isolated namespace, uses the mock provider with
strict mode disabled and no ingress, runs the health smoke test, and tears down
on success. A passing testflight feeds `bump-esign-in-deployments`.
