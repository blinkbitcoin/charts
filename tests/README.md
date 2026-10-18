# Chart render regression tests

These tests invoke `helm template` and parse the manifests with a YAML loader that
rejects duplicate mapping keys. They do not require a Kubernetes cluster.

With Helm and Python 3 installed, create a virtual environment and run:

```sh
helm repo add ory https://k8s.ory.sh/helm/charts
helm dependency build charts/galoy
python3 -m venv .venv
.venv/bin/python -m pip install PyYAML==6.0.2
.venv/bin/python -B -m unittest discover -s tests -v
```

The Helm Lint and Test workflow runs the same suite. LNURL server cases cover
Ingress disabled, default/empty/unset annotations, a normal custom annotation,
multiline server snippets, and a collision with the fixed certificate issuer.

Galoy Oathkeeper cases convert the rendered access rule match URLs into Python
regexes and check that the internal rules (`admin-backend`,
`blink-lnurl-server-internal`) reject public hosts while the in-cluster proxy
URLs still match, and that the optional Oathkeeper NetworkPolicies render only
when `networkPolicy.enabled` is set. They are skipped when the galoy chart
dependencies have not been built.
