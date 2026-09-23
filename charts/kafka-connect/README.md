# Kafka Connect worker isolation

The default `kafkaConnectInstanceName: kafka` retains `connect-cluster` and
`connect-cluster-{offsets,configs,status}`. These identities own the existing
connector state and must not change during this upgrade.

Other instance names use `<instance>-connect-cluster` and corresponding internal
topics. When testflight runs share brokers with another deployment, unique
Kubernetes resource names alone do not isolate their Kafka Connect workers.
Group ID and all three internal topics must be isolated together. See the
[Strimzi multiple-instance requirements](https://strimzi.io/docs/operators/0.46.0/deploying.html#con-kafka-connect-multiple-instances-str).

## Upgrade and recovery

Changing a non-default instance's identity starts an independent Connect cluster
without its former shared configurations or offsets. This is intentional for CI
testflight workers. Inventory any non-testflight custom instances and plan their
state migration separately before upgrading them.

Updating the chart does not repair an already-running old Helm release. Before
recovery, verify worker group membership, internal topic names, resource
ownership, and active CI runs. Prevent an old testflight from being recreated or
reconciled into the shared group. Stop only a confirmed abandoned testflight
through its owner; retain topics, offsets, connector definitions and Helm
metadata. Let the intended workers elect their leader and reconcile connectors.

Do not delete connector definitions through the REST API while workers share a
group: that can remove configurations used by another deployment. Avoid broker
restarts, topic deletion, or offset resets as a shortcut for worker isolation.

Render new testflight manifests and verify all four identities are isolated
before starting them. Long-lived default deployments keep their legacy
identities. Update vendored chart copies through their normal regeneration flow.

## Verification and rollback

The existing smoke test checks `/connector-plugins`, which does not establish
connector or task health. Verify that every intended connector exists, each
connector and expected task is RUNNING, and configuration forwarding no longer
times out. An empty tasks array is not a healthy source/sink. Observe fresh
source events reaching their destination and check logs across severity levels.
Historical completeness and any required backfill need separate verification.

Record replica counts and identities before changing an existing deployment.
If a newly isolated testflight fails, leave it stopped while diagnosing;
reverting it to the shared group can recreate the collision. Restore a stopped
worker only after reviewing its group membership and potential leadership role.
Preserve evidence if expired resume tokens, missing topics, offset gaps or
schema failures surface after recovery. Do not discard state to hide failures.

## Local regression checks

```sh
python3 ci/tasks/tests/test-kafka-connect-isolation.py
helm lint charts/kafka-connect
```

These tests render real Helm manifests for the legacy instance and concurrent
testflights, including stable identity across Helm release names. They do not
contact a cluster or prove live recovery.
