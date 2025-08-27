# LND Backup Testing

This directory contains test files and scripts for testing LND Static Channel Backup (SCB) functionality.

## Overview

The LND backup system automatically backs up channel state to cloud storage (S3, MinIO, GCS, or Nextcloud) whenever channels are opened, closed, or updated. This ensures that funds can be recovered even if the LND node is completely lost.

## Files

- `build-image.sh` - Sets up the backup image configuration (online by default, local build optional)
- `deploy.sh` - Deploys LND with backup functionality enabled
- `test-backup.sh` - Tests and verifies backup functionality
- `values.yml` - Helm values for testing backup functionality
- `README.md` - This file

## Quick Start

### 1. Setup the Backup Image Configuration

```bash
cd dev/bitcoin/lnd-backup-test
chmod +x build-image.sh
./build-image.sh
```

This will:

- Configure the test to use the online `us.gcr.io/galoy-org/lnd-backup:latest` image
- Create/update the test values file

#### Optional: Build Local Image

If you need to test local changes to the backup image:

```bash
./build-image.sh --local
```

This will:

- Build the `lnd-backup:latest` image locally
- Load it into the k3d cluster
- Configure the test to use the local image

### 2. Deploy LND with Backup

```bash
chmod +x deploy.sh
./deploy.sh
```

This will:
- Create the required namespace and secrets
- Deploy LND with backup functionality enabled
- Wait for all pods to be ready

### 3. Test Backup Functionality

```bash
chmod +x test-backup.sh
./test-backup.sh
```

This will:
- Check pod status
- Show recent backup logs
- Verify LND is running
- Test backup environment and connectivity

## Manual Testing

### Check Backup Logs
```bash
kubectl logs -n galoy-dev-bitcoin lnd-backup-test-0 -c backup
```

### Monitor Backup Events
```bash
kubectl logs -n galoy-dev-bitcoin lnd-backup-test-0 -c backup -f
```

### Check LND Status
```bash
kubectl exec -n galoy-dev-bitcoin lnd-backup-test-0 -c lnd -- lncli getinfo
```

### Trigger Backup Event
To test backup functionality, you need to create a channel:
1. Connect to another LND node
2. Open a channel
3. Watch backup logs for automatic upload

## Configuration

The backup system supports multiple storage backends:

### MinIO (Default for Testing)
- Automatically detected via Kubernetes service discovery
- Uses `test-access-key` / `test-secret-key` credentials
- Uploads to `test-backup-bucket`

### AWS S3
Set environment variables:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `S3_BUCKET`
- `S3_REGION`

### Google Cloud Storage
Set environment variables:
- `GCS_BUCKET_NAME`
- `GOOGLE_APPLICATION_CREDENTIALS` (path to service account key)

### Nextcloud
Set environment variables:
- `NEXTCLOUD_URL`
- `NEXTCLOUD_USERNAME`
- `NEXTCLOUD_PASSWORD`
- `NEXTCLOUD_BACKUP_PATH`

## Troubleshooting

### Backup Container Not Starting
```bash
kubectl describe pod lnd-backup-test-0 -n galoy-dev-bitcoin
```

### No Backup Events
- Check if channels exist: `kubectl exec -n galoy-dev-bitcoin lnd-backup-test-0 -c lnd -- lncli listchannels`
- Verify backup file exists: `kubectl exec -n galoy-dev-bitcoin lnd-backup-test-0 -c lnd -- ls -la /root/.lnd/data/chain/bitcoin/regtest/channel.backup`

### Upload Failures
- Check credentials: `kubectl get secret lnd-backup-aws-creds -n galoy-dev-bitcoin -o yaml`
- Verify MinIO connectivity: `kubectl exec -n galoy-dev-bitcoin lnd-backup-test-0 -c backup -- env | grep MINIO`

## Cleanup

```bash
helm uninstall lnd-backup-test -n galoy-dev-bitcoin
kubectl delete namespace galoy-dev-bitcoin
```
