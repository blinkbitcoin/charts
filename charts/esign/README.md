# eSign

Deploys `ghcr.io/blinkbitcoin/esign-service:0.6.0` on port 4100.
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

Startup, readiness, and liveness probes request `GET /health`. The smoke test
checks `status == "ok"`, capability `mint`, and `mint == "envelope"`, matching
the release health handler in `packages/esign-service/src/app.ts`. Basic health
assertions are in `packages/esign-service/tests/server.test.ts`. This verifies
reachability and mint mode; it does not exercise a DocuSign signing flow.

GitHub Actions runs Helm checks and smoke-script fixtures. Concourse
`esign-testflight` creates an isolated namespace and uses the mock provider in
envelope mode, with strict mode disabled and no ingress. It runs the health
smoke test and tears down on success. A passing testflight feeds
`bump-esign-in-deployments`.
