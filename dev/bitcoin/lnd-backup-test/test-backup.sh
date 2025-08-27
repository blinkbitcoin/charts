#!/bin/bash

set -e

echo "=== Testing LND Backup Functionality ==="

# Configuration
NAMESPACE="galoy-dev-bitcoin"
RELEASE_NAME="lnd-backup-test"

echo "1. Checking if LND is running..."
kubectl get pods -n $NAMESPACE $RELEASE_NAME-0

echo "2. Checking backup container logs..."
echo "--- Recent backup logs ---"
kubectl logs -n $NAMESPACE $RELEASE_NAME-0 -c backup --tail=20

echo ""
echo "3. Checking LND status..."
kubectl exec -n $NAMESPACE $RELEASE_NAME-0 -c lnd -- lncli --network=regtest getinfo

echo ""
echo "4. Checking if channel backup file exists..."
kubectl exec -n $NAMESPACE $RELEASE_NAME-0 -c lnd -- ls -la /root/.lnd/data/chain/bitcoin/regtest/channel.backup 2>/dev/null || echo "No channel backup file found (normal if no channels exist)"

echo ""
echo "5. Checking backup environment variables..."
echo "--- MinIO detection ---"
kubectl exec -n $NAMESPACE $RELEASE_NAME-0 -c backup -- env | grep -E "(MINIO|S3_|AWS_)" | head -5

echo ""
echo "6. Testing backup upload capability..."
# Get the actual MinIO service IP
MINIO_IP=$(kubectl get service minio -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
echo "MinIO service IP: $MINIO_IP"

# Test bucket access
echo "--- Testing bucket access ---"
kubectl exec -n $NAMESPACE $RELEASE_NAME-0 -c backup -- aws s3 ls --endpoint-url "http://$MINIO_IP:9000" 2>/dev/null && echo "✅ MinIO accessible" || echo "❌ MinIO not accessible"

# Test bucket contents
echo "--- Checking backup bucket contents ---"
kubectl exec -n $NAMESPACE $RELEASE_NAME-0 -c backup -- aws s3 ls s3://test-backup-bucket/ --endpoint-url "http://$MINIO_IP:9000" 2>/dev/null && echo "✅ Bucket accessible" || echo "❌ Bucket not accessible"

# Check for actual backup files
echo "--- Checking for backup files ---"
BACKUP_COUNT=$(kubectl exec -n $NAMESPACE $RELEASE_NAME-0 -c backup -- aws s3 ls s3://test-backup-bucket/lnd_scb/ --endpoint-url "http://$MINIO_IP:9000" 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt 0 ]; then
    echo "✅ Found $BACKUP_COUNT backup file(s):"
    kubectl exec -n $NAMESPACE $RELEASE_NAME-0 -c backup -- aws s3 ls s3://test-backup-bucket/lnd_scb/ --endpoint-url "http://$MINIO_IP:9000"
else
    echo "❌ No backup files found"
fi

echo ""
echo "=== Test Complete ==="
echo ""
echo "To monitor backup events in real-time:"
echo "kubectl logs -n $NAMESPACE $RELEASE_NAME-0 -c backup -f"
echo ""
echo "To trigger a backup event (create a channel):"
echo "1. Connect to another LND node"
echo "2. Open a channel"
echo "3. Watch backup logs for upload events"
