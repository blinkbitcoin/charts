#!/bin/bash

set -eu

source smoketest-settings/helpers.sh

host=$(setting "galoy_endpoint")
port=$(setting "galoy_port")

function break_and_display_on_error_response() {
  if [[ $(jq -r '.errors' <./response.json) != "null" ]]; then
    echo Smoketest failed! - Response:
    cat response.json
    echo Contains "errors" key
    exit 1
  fi
}

# galoy-backend unauthenticated
set +e
for i in {1..15}; do
  echo "Attempt ${i} to curl the public galoy API"
  curl --location -sSf --request POST "${host}:${port}/graphql"\
   --header 'Content-Type: application/json' \
   --data-raw '{"query":"query realtimePrice { realtimePrice { id timestamp btcSatPrice { base offset } } }","variables":{}}' > response.json
  if [[ $? == 0 ]]; then success="true"; break; fi;
  sleep 1
done
set -e

break_and_display_on_error_response

# price history server healthcheck
# The following health.proto file has been copied from
# https://github.com/blinkbitcoin/price/blob/main/history/src/servers/protos/health.proto
cat << EOF > health.proto
syntax = "proto3";

package grpc.health.v1;

message HealthCheckRequest {
  string service = 1;
}

message HealthCheckResponse {
  enum ServingStatus {
    UNKNOWN = 0;
    SERVING = 1;
    NOT_SERVING = 2;
    SERVICE_UNKNOWN = 3;  // Used only by the Watch method.
  }
  ServingStatus status = 1;
}

service Health {
  rpc Check(HealthCheckRequest) returns (HealthCheckResponse);

  rpc Watch(HealthCheckRequest) returns (stream HealthCheckResponse);
}
EOF

host=`setting "price_history_endpoint"`
port=`setting "price_history_port"`

set +e
for i in {1..15}; do
  echo "Attempt ${i} to curl price history server"
  grpcurl -plaintext -proto health.proto ${host}:${port} grpc.health.v1.Health.Check
  if [[ $? == 0 ]]; then price_history_healthz="true"; break; fi;
  sleep 1
done
set -e

if [[ "$price_history_healthz" != "true" ]]; then echo "Smoke test failed; price history server healthcheck failed" && exit 1; fi;

## cronjob
set +e
if [[ `setting_exists "smoketest_kubeconfig"` != "null" ]]; then
  setting "smoketest_kubeconfig" | base64 --decode > kubeconfig.json
  export KUBECONFIG=$(pwd)/kubeconfig.json
  namespace=`setting "galoy_namespace"`
  job_name="${namespace}-cronjob-smoketest"
  kubectl -n ${namespace} delete job "${job_name}" || true
  echo "Executing cronjob"
  kubectl -n ${namespace} create job --from=cronjob/galoy-cronjob "${job_name}"
  for i in {1..150}; do
    kubectl -n ${namespace}  wait --for=condition=complete job "${job_name}"
    if [[ $? -eq 0 ]]; then
      echo "Cronjob execution completed"
      break
    fi
    if [[ $i -gt 30 ]]; then
      echo "If cronjob is taking too long, consider closing channels with offline nodes"
    fi
    sleep 2
  done
  status="$(kubectl -n ${namespace} get job ${job_name} -o jsonpath='{.status.succeeded}')"
  if [[ "${status}" != "1" ]]; then
    echo "Cronjob failed!"
    exit 1
  else
    echo "Cronjob succeeded!"
  fi
  kubectl -n ${namespace} delete job "${job_name}"
fi
set -e
