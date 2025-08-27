#!/bin/bash

set -e

echo "=== LND Backup Image Setup for Testing ==="

# Configuration
ONLINE_IMAGE_REPO="us.gcr.io/galoy-org/lnd-backup"
LOCAL_IMAGE_NAME="lnd-backup"
IMAGE_TAG="latest"
BUILD_LOCAL=${1:-false}

if [ "$BUILD_LOCAL" = "true" ] || [ "$BUILD_LOCAL" = "--local" ]; then
    echo "Building local backup image..."

    echo "1. Building backup image..."
    cd ../../../images/lnd-backup

    # Build the image
    docker build -t $LOCAL_IMAGE_NAME:$IMAGE_TAG .

    echo "2. Loading image into k3d cluster..."
    k3d image import $LOCAL_IMAGE_NAME:$IMAGE_TAG

    echo "3. Verifying image is available in cluster..."
    docker exec k3d-k3s-default-server-0 crictl images | grep $LOCAL_IMAGE_NAME || echo "Image not found in cluster"

    IMAGE_REPO=$LOCAL_IMAGE_NAME
    echo "Using locally built image: $LOCAL_IMAGE_NAME:$IMAGE_TAG"
else
    echo "Using online backup image: $ONLINE_IMAGE_REPO:$IMAGE_TAG"
    IMAGE_REPO=$ONLINE_IMAGE_REPO
fi

echo "4. Creating test values file..."
cd ../../../dev

cat > bitcoin/lnd-backup-test/values.yml << EOF
global:
  network: regtest

# Use the backup image
backupImage:
  repository: $IMAGE_REPO
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
echo "=== Setup Complete ==="
echo "Backup image: $IMAGE_REPO:$IMAGE_TAG"
echo "Test values file: bitcoin/lnd-backup-test/values.yml"
echo ""
echo "Next steps:"
echo "1. Deploy LND with backup: ./deploy.sh"
echo "2. Test backup functionality: ./test-backup.sh"
echo ""
echo "Manual deployment:"
echo "helm upgrade --install lnd-backup-test ../../charts/lnd --namespace=galoy-dev-bitcoin --values=./values.yml --set backup.s3.accessKeySecret.name=lnd-backup-aws-creds --set backup.s3.secretKeySecret.name=lnd-backup-aws-creds"
