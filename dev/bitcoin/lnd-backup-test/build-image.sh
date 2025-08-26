#!/bin/bash

set -e

echo "=== Building LND Backup Image for Testing ==="

# Configuration
IMAGE_NAME="lnd-backup"
IMAGE_TAG="latest"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

echo "1. Building backup image..."
cd ../../../images/lnd-backup

# Build the image
docker build -t $FULL_IMAGE_NAME .

echo "2. Loading image into k3d cluster..."
k3d image import $FULL_IMAGE_NAME

echo "3. Verifying image is available in cluster..."
docker exec k3d-k3s-default-server-0 crictl images | grep $IMAGE_NAME || echo "Image not found in cluster"

echo "4. Creating test values file with local backup image..."
cd ../../../dev

cat > bitcoin/lnd-backup-test/values.yml << EOF
global:
  network: regtest

# Use the locally built backup image
backupImage:
  repository: $IMAGE_NAME
  tag: $IMAGE_TAG
  pullPolicy: IfNotPresent

resources:
  limits:
    cpu: 200m
    memory: 512Mi

terminationGracePeriodSeconds: 0

persistence:
  enabled: false

# Enable backup for testing
backup:
  enabled: true
  s3:
    enabled: true
    bucketName: "test-backup-bucket"
    region: "us-east-1"

configmap:
  customValues:
  - bitcoin.regtest=true
  - bitcoin.defaultchanconfs=0
  - noseedbackup=1
  - bitcoind.rpchost=bitcoind:18443
  - keysend-hold-time=2s
  - tlsextradomain=lnd1.galoy-dev-bitcoin.svc.cluster.local
EOF

echo ""
echo "=== Build Complete ==="
echo "Local backup image: $FULL_IMAGE_NAME"
echo "Test values file: bitcoin/lnd-backup-test/values.yml"
echo ""
echo "Next steps:"
echo "1. Deploy LND with backup: helm upgrade --install lnd-backup-test ../../charts/lnd --namespace=galoy-dev-bitcoin --values=./values.yml --set backup.s3.accessKeySecret.name=lnd-backup-aws-creds --set backup.s3.secretKeySecret.name=lnd-backup-aws-creds"
echo "2. Check backup functionality with: kubectl logs -n galoy-dev-bitcoin lnd-backup-test-0 -c backup"
