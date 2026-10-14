#!/bin/bash

set -eu

echo "Preparing testflight"

if [[ -d "repo/ci/testflight/${CHART}" ]]; then
  cp -r "repo/ci/testflight/${CHART}" testflight/tf
else
  cp -r "pipeline-tasks/ci/testflight/${CHART}" testflight/tf
fi
cp -r "repo/charts/${CHART}" testflight/tf/chart

if [[ "$CHART" == "fulcrum" ]]; then
  cp -r repo/charts/bitcoind testflight/tf/bitcoind-chart
fi

cat <<EOF > testflight/tf/terraform.tfvars
testflight_namespace = "${CHART}-testflight-$(cat repo/.git/short_ref)"
EOF

cat <<EOF > testflight/env_name
${CHART}-testflight-$(cat repo/.git/short_ref)
EOF
