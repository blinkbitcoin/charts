#!/bin/bash

set -eu

source smoketest-settings/helpers.sh

kafka_broker_host=$(setting "kafka_broker_endpoint")
kafka_broker_port=$(setting "kafka_broker_port")
kafka_topic=$(setting "smoketest_topic")
kafka_bootstrap_service="kafka-kafka-plain-bootstrap"
kafka_namespace=$(setting "kafka_namespace")
setting "smoketest_kubeconfig" | base64 --decode >kubeconfig.json
export KUBECONFIG=$(pwd)/kubeconfig.json

cat <<EOF >topic.tf
provider "kafka" {
  bootstrap_servers = [
    "${kafka_bootstrap_service}.${kafka_namespace}:9092"
  ]
  tls_enabled = false
}

terraform {
  required_providers {
    kafka = {
      source  = "Mongey/kafka"
      version = "0.5.2"
    }
  }
}

resource "kafka_topic" "smoketest_topic" {
  name               = "${kafka_topic}"
  replication_factor = 3
  partitions         = 3
}
EOF

set +e
for i in 1 2 3; do
  kubectl -n $kafka_namespace wait --for=condition=Ready pod -l strimzi.io/component-type=kafka && break
  sleep 5
done
set -e

tofu init

set +e
for i in 1 2 3; do
  tofu apply -auto-approve && break
  sleep 5
done

msg="kafka message"
for i in {1..15}; do
  echo "Attempt ${i} to produce and consume from kafka"
  echo $msg | kcat -P -b $kafka_broker_host:$kafka_broker_port -t $kafka_topic
  consumed_message=$(kcat -C -b $kafka_broker_host:$kafka_broker_port -t $kafka_topic -e)
  if [[ "$consumed_message" == "$msg" ]]; then
    success="true"
    break
  fi
  sleep 1
done

tofu destroy -auto-approve

if [[ "$success" != "true" ]]; then echo "Smoke test failed" && exit 1; fi

set -e
