#!/bin/bash

set -e

echo "=== Deploying LND with Backup Functionality ==="

# Check if we're in the right directory
if [ ! -f "values.yml" ]; then
    echo "Error: values.yml not found. Please run this script from the lnd-backup-test directory."
    exit 1
fi

# Configuration
NAMESPACE="galoy-dev-bitcoin"
RELEASE_NAME="lnd-backup-test"
CHART_PATH="../../../charts/lnd"

echo "1. Checking if namespace exists..."
kubectl get namespace $NAMESPACE >/dev/null 2>&1 || {
    echo "Creating namespace $NAMESPACE..."
    kubectl create namespace $NAMESPACE
}

echo "2. Deploying MinIO for backup storage..."
# Deploy MinIO
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: $NAMESPACE
  labels:
    app: minio
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: minio/minio:latest
        args:
        - server
        - /data
        - --console-address
        - ":9001"
        env:
        - name: MINIO_ROOT_USER
          value: "test-access-key"
        - name: MINIO_ROOT_PASSWORD
          value: "test-secret-key"
        ports:
        - containerPort: 9000
          name: api
        - containerPort: 9001
          name: console
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: $NAMESPACE
  labels:
    app: minio
spec:
  selector:
    app: minio
  ports:
  - name: api
    port: 9000
    targetPort: 9000
  - name: console
    port: 9001
    targetPort: 9001
  type: ClusterIP
EOF

echo "Waiting for MinIO to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/minio -n $NAMESPACE

echo "3. Creating MinIO credentials secret..."

# Create AWS credentials secret for LND backup
kubectl get secret lnd-backup-aws-creds -n $NAMESPACE >/dev/null 2>&1 || {
    echo "Creating MinIO credentials secret..."
    kubectl create secret generic lnd-backup-aws-creds \
        --from-literal=access-key-id=test-access-key \
        --from-literal=secret-access-key=test-secret-key \
        -n $NAMESPACE
}

echo "4. Deploying LND with backup functionality..."
HELM_BIN=$(ls /nix/store/*/bin/helm 2>/dev/null | head -1)
if [ -z "$HELM_BIN" ]; then
    echo "Error: Helm not found. Please ensure Helm is installed."
    exit 1
fi

$HELM_BIN upgrade --install $RELEASE_NAME $CHART_PATH \
    --namespace=$NAMESPACE \
    --values=./values.yml \
    --set backup.s3.accessKeySecret.name=lnd-backup-aws-creds \
    --set backup.s3.secretKeySecret.name=lnd-backup-aws-creds \
    --wait \
    --timeout=300s

echo "5. Creating MinIO bucket..."
# Wait for LND backup container to be ready
echo "Waiting for LND backup container to be ready..."
kubectl wait --for=condition=ready --timeout=300s pod/$RELEASE_NAME-0 -n $NAMESPACE

# Get MinIO service IP
MINIO_IP=$(kubectl get service minio -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
echo "MinIO service IP: $MINIO_IP"

# Create the backup bucket using the LND backup container
echo "Creating MinIO bucket using LND backup container..."
kubectl exec -n $NAMESPACE $RELEASE_NAME-0 -c backup -- aws s3 mb s3://test-backup-bucket --endpoint-url "http://$MINIO_IP:9000" || echo "Bucket may already exist"

echo "6. Checking deployment status..."
kubectl get pods -n $NAMESPACE $RELEASE_NAME-0

echo ""
echo "=== Deployment Complete ==="
echo "Release: $RELEASE_NAME"
echo "Namespace: $NAMESPACE"
echo ""
echo "Useful commands:"
echo "1. Check backup logs: kubectl logs -n $NAMESPACE $RELEASE_NAME-0 -c backup"
echo "2. Check all containers: kubectl get pods -n $NAMESPACE $RELEASE_NAME-0"
echo "3. Get LND info: kubectl exec -n $NAMESPACE $RELEASE_NAME-0 -c lnd -- lncli getinfo"
echo "4. Monitor backup events: kubectl logs -n $NAMESPACE $RELEASE_NAME-0 -c backup -f"
