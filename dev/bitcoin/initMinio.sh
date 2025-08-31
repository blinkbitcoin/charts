#!/bin/bash

set -e

NAMESPACE="galoy-dev-bitcoin"
MINIO_ACCESS_KEY="dev-access-key"
MINIO_SECRET_KEY="dev-secret-key"

echo "Initializing MinIO..."

# Check if MinIO is ready
if ! kubectl get pod -l app=minio -n $NAMESPACE >/dev/null 2>&1; then
    echo "MinIO pod not found, skipping initialization"
    exit 0
fi

# Wait for MinIO to be ready
echo "Waiting for MinIO to be ready..."
kubectl wait --for=condition=ready pod -l app=minio -n $NAMESPACE --timeout=120s || {
    echo "MinIO not ready yet, skipping initialization"
    exit 0
}

# Get MinIO service IP
MINIO_IP=$(kubectl get service minio -n $NAMESPACE -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
if [ -z "$MINIO_IP" ]; then
    echo "MinIO service not found, skipping initialization"
    exit 0
fi

echo "MinIO service IP: $MINIO_IP"

# Create a temporary pod with AWS CLI to initialize MinIO
echo "Creating temporary pod for MinIO initialization..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: minio-init
  namespace: $NAMESPACE
spec:
  restartPolicy: Never
  containers:
  - name: aws-cli
    image: amazon/aws-cli:latest
    command: ['sleep', '300']
    env:
    - name: AWS_ACCESS_KEY_ID
      value: "$MINIO_ACCESS_KEY"
    - name: AWS_SECRET_ACCESS_KEY
      value: "$MINIO_SECRET_KEY"
    - name: AWS_DEFAULT_REGION
      value: "us-east-1"
EOF

# Wait for the init pod to be ready
echo "Waiting for init pod to be ready..."
kubectl wait --for=condition=ready pod/minio-init -n $NAMESPACE --timeout=60s

# Create buckets
echo "Creating MinIO buckets..."
ENDPOINT_URL="http://$MINIO_IP:9000"

# Create backup bucket for LND
kubectl exec -n $NAMESPACE minio-init -- aws s3 mb s3://lnd-backup-bucket --endpoint-url "$ENDPOINT_URL" || echo "Bucket lnd-backup-bucket may already exist"

# Create general storage bucket
kubectl exec -n $NAMESPACE minio-init -- aws s3 mb s3://dev-storage --endpoint-url "$ENDPOINT_URL" || echo "Bucket dev-storage may already exist"

# Create test bucket
kubectl exec -n $NAMESPACE minio-init -- aws s3 mb s3://test-backup-bucket --endpoint-url "$ENDPOINT_URL" || echo "Bucket test-backup-bucket may already exist"

# List buckets to verify
echo "Verifying created buckets..."
kubectl exec -n $NAMESPACE minio-init -- aws s3 ls --endpoint-url "$ENDPOINT_URL"

# Clean up init pod
echo "Cleaning up initialization pod..."
kubectl delete pod minio-init -n $NAMESPACE --ignore-not-found=true

echo "MinIO initialization complete!"
echo ""
echo "MinIO Console: http://$MINIO_IP:9001"
echo "MinIO API: http://$MINIO_IP:9000"
echo "Access Key: $MINIO_ACCESS_KEY"
echo "Secret Key: $MINIO_SECRET_KEY"
echo ""
echo "Available buckets:"
echo "- lnd-backup-bucket (for LND backups)"
echo "- dev-storage (for general development)"
echo "- test-backup-bucket (for testing)"
