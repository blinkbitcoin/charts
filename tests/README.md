# Chart render regression tests

These tests invoke `helm template` and parse the manifests with a YAML loader that
rejects duplicate mapping keys. They do not require a Kubernetes cluster.

With Helm and Python 3 installed, create a virtual environment and run:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install PyYAML==6.0.2
.venv/bin/python -B -m unittest discover -s tests -v
```

The Helm Lint and Test workflow runs the same suite. LNURL server cases cover
Ingress disabled, default/empty/unset annotations, a normal custom annotation,
multiline server snippets, and a collision with the fixed certificate issuer.
