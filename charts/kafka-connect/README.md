# Kafka Connect worker isolation

`kafkaConnectInstanceName` controls Kubernetes resource naming only.
`connectClusterId` selects the durable Kafka worker group and the prefix for
all three internal topics. Its default, `connect-cluster`, retains the existing
group and `connect-cluster-{offsets,configs,status}` topics for every instance
name, including pre-existing custom names such as `custom-prod`. A chart upgrade
without an explicit `connectClusterId` change preserves these identities.

Independent workers sharing brokers must explicitly select unique
`connectClusterId` values. The CI testflight values template opts in with
`${kafka_connect_instance_name}-connect-cluster`; arbitrary custom instance names
do not opt in automatically. When testflight runs share brokers with another
deployment, unique Kubernetes resource names alone do not isolate their workers.
Group ID and all three internal topics must be isolated together. See the
[Strimzi multiple-instance requirements](https://strimzi.io/docs/operators/0.46.0/deploying.html#con-kafka-connect-multiple-instances-str).

## Upgrade and recovery

Changing `connectClusterId` starts an independent Connect cluster without its
former shared configurations or offsets. This is intentional for new CI
testflight workers, not a routine upgrade of a long-lived deployment. Preserve
the existing ID unless an operator has explicitly reviewed the state migration.
For existing testflights still using shared state, stop the old workers through
their owner before starting replacements with the new testflight values.

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
before starting them. Long-lived deployments, including custom names, keep their
legacy identities. Update vendored chart copies through their normal regeneration
flow.

Isolated testflight topics are durable and can accumulate. Before sustained use,
define a bounded cleanup policy based on confirmed abandoned testflight ownership;
never delete shared topics or topics belonging to an active worker.

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

These tests render real Helm manifests for default and custom legacy instances,
explicit durable identities, and concurrent testflights using the actual CI
values template. They verify stable identity across Kubernetes resource and Helm
release names. The Helm workflow runs them for chart, testflight values template,
regression test, and workflow changes. They do not contact a cluster or prove live
recovery.
