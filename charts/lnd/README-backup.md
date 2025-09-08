# LND Static Channel Backup (SCB) Service

This document describes the LND Static Channel Backup (SCB) service implementation that runs alongside the LND container to automatically backup channel state.

## Overview

The backup service is a separate container that:
- Monitors LND backup events using the `subscribeToBackups` gRPC API
- Reads the `channel.backup` file directly when backup events occur
- Automatically uploads SCB files when channel state changes
- Supports multiple backup destinations (GCS, S3, MinIO, Nextcloud)
- Runs independently from the main Galoy application
- Uses a dedicated backup image (`lnd-backup`) separate from the LND sidecar

## Configuration

### Backup Image

The backup service uses a separate image from the LND sidecar. The image is available online at `us.gcr.io/galoy-org/lnd-backup`.

**Security Features:**
- No shell access (shell binaries removed for security)
- Minimal attack surface with only required runtime
- Uses readonly macaroon for authentication

Configure it in your values file:

```yaml
backupImage:
  repository: us.gcr.io/galoy-org/lnd-backup
  tag: latest
  pullPolicy: IfNotPresent
```

### Enable Backup

To enable the backup service, set the following in your values file:

```yaml
backup:
  enabled: true
```

### Google Cloud Storage (GCS)

```yaml
backup:
  gcs:
    enabled: true
    bucketName: "your-backup-bucket"
    serviceAccountSecret:
      name: "gcs-service-account"
      key: "service-account.json"
```

Create the service account secret:
```bash
kubectl create secret generic gcs-service-account \
  --from-file=service-account.json=/path/to/service-account.json
```

### AWS S3

```yaml
backup:
  s3:
    enabled: true
    bucketName: "your-backup-bucket"
    region: "us-east-1"
    accessKeySecret:
      name: "aws-credentials"
      key: "access-key-id"
    secretKeySecret:
      name: "aws-credentials"
      key: "secret-access-key"
```

Create the AWS credentials secret:
```bash
kubectl create secret generic aws-credentials \
  --from-literal=access-key-id=YOUR_ACCESS_KEY \
  --from-literal=secret-access-key=YOUR_SECRET_KEY
```

### MinIO

MinIO is automatically detected when running in a Kubernetes cluster with a MinIO service. The backup service uses the same S3 configuration but automatically detects the MinIO endpoint:

```yaml
backup:
  s3:
    enabled: true
    bucketName: "your-backup-bucket"
    region: "us-east-1"
    accessKeySecret:
      name: "minio-credentials"
      key: "access-key-id"
    secretKeySecret:
      name: "minio-credentials"
      key: "secret-access-key"
```

Create the MinIO credentials secret:
```bash
kubectl create secret generic minio-credentials \
  --from-literal=access-key-id=YOUR_MINIO_ACCESS_KEY \
  --from-literal=secret-access-key=YOUR_MINIO_SECRET_KEY
```

**Note**: The backup service automatically detects MinIO by checking for `MINIO_SERVICE_HOST` environment variable that Kubernetes provides when a MinIO service exists in the cluster.

### Nextcloud

```yaml
backup:
  nextcloud:
    enabled: true
    url: "https://your-nextcloud.com/remote.php/dav/files/username"
    userSecret:
      name: "nextcloud-credentials"
      key: "username"
    passwordSecret:
      name: "nextcloud-credentials"
      key: "password"
```

Create the Nextcloud credentials secret:
```bash
kubectl create secret generic nextcloud-credentials \
  --from-literal=username=YOUR_USERNAME \
  --from-literal=password=YOUR_PASSWORD
```

## Multiple Destinations

You can enable multiple backup destinations simultaneously. The sidecar will upload to all configured destinations:

```yaml
backup:
  enabled: true
  gcs:
    enabled: true
    bucketName: "primary-backup-bucket"
    serviceAccountSecret:
      name: "gcs-service-account"
      key: "service-account.json"
  s3:
    enabled: true
    bucketName: "secondary-backup-bucket"
    region: "us-west-2"
    accessKeySecret:
      name: "aws-credentials"
      key: "access-key-id"
    secretKeySecret:
      name: "aws-credentials"
      key: "secret-access-key"
```

## Backup File Format

Backup files are stored with the following naming convention:
```
{NETWORK}_lnd_scb_{PUBKEY}_{TIMESTAMP}
```

For example:
```
mainnet_lnd_scb_03a6ce61fcaacd38d31d4e3ce2d506602818e3856b4b44faff1dde9642ba705976_1703123456
```

Files are stored in the `lnd_scb/` directory within the configured bucket.

## Monitoring

The backup service logs all backup events and upload status. Monitor the logs using:

```bash
kubectl logs -f statefulset/lnd -c backup
```

For a specific pod:
```bash
kubectl logs -f lnd-0 -c backup
```

## Troubleshooting

### Common Issues

1. **Backup service not starting**: Check that backup is enabled and at least one destination is configured
2. **Upload failures**: Verify credentials and bucket permissions
3. **No backup events**: Ensure LND is fully synced and has active channels
4. **MinIO not detected**: Verify MinIO service exists in the same namespace
5. **Image pull errors**: Ensure the backup image is available in your cluster

### Debug Commands

Check backup container status:
```bash
kubectl describe pod lnd-0 | grep -A 10 backup
```

View backup logs:
```bash
kubectl logs lnd-0 -c backup --tail=100
```

Debug backup container:
```bash
# Check backup container status
kubectl describe pod lnd-0

# View backup container environment variables
kubectl exec lnd-0 -c backup -- printenv | grep -E "(GCS|S3|NEXTCLOUD|AWS)"
```

**Note**: The backup container does not have shell access for security reasons. For testing cloud storage connectivity, use a separate debug pod or test from your local environment.

## Security Considerations

- Store credentials in Kubernetes secrets, not in values files
- Use least-privilege access for backup destinations
- Regularly rotate backup credentials
- Monitor backup upload logs for any failures

## Recovery

To restore from a backup:

1. Download the latest SCB file from your backup destination
2. Use `lncli restorechanbackup` to restore channel state
3. Restart LND to apply the restored channels

Example:
```bash
# Download backup
gsutil cp gs://your-bucket/lnd_scb/latest_backup ./backup.scb

# Restore channels
lncli restorechanbackup --multi_file=backup.scb
```
