# LND Helm Chart

This Helm chart deploys Lightning Network Daemon (LND) on Kubernetes with optional Static Channel Backup (SCB) functionality.

## Features

- **LND Node**: Full Lightning Network node with configurable parameters
- **Automatic Backup**: Built-in SCB backup service with multiple destination support
- **Secret Management**: Automatic export of LND credentials to Kubernetes secrets
- **Tor Support**: Built-in Tor proxy for privacy
- **Monitoring**: Prometheus metrics and health checks
- **Persistence**: Configurable persistent storage for LND data

## Quick Start

### Basic Installation

```bash
helm install lnd ./charts/lnd \
  --set global.network=mainnet \
  --set persistence.enabled=true
```

### With Backup Enabled

```bash
# Install with backup enabled (using MinIO for testing)
helm install lnd ./charts/lnd \
  --set backup.enabled=true \
  --set backup.s3.enabled=true \
  --set backup.s3.bucketName=your-backup-bucket \
  --set backup.s3.accessKeySecret.name=backup-credentials \
  --set backup.s3.secretKeySecret.name=backup-credentials
```

## Configuration

### Core Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.network` | Bitcoin network (mainnet/testnet/regtest) | `mainnet` |
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.size` | Storage size | `20Gi` |
| `resources` | Resource requests/limits | `{}` |

### Backup Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `backup.enabled` | Enable SCB backup service | `false` |
| `backupImage.repository` | Backup service image repository | `lnd-backup` |
| `backupImage.tag` | Backup service image tag | `latest` |
| `backup.gcs.enabled` | Enable Google Cloud Storage backup | `false` |
| `backup.s3.enabled` | Enable AWS S3/MinIO backup | `false` |
| `backup.nextcloud.enabled` | Enable Nextcloud backup | `false` |

For detailed backup configuration, see [README-backup.md](./README-backup.md).

## Static Channel Backup (SCB)

The chart includes an optional backup service that automatically backs up LND's Static Channel Backup files to cloud storage. This ensures you can recover your Lightning channels in case of node failure.

### Key Features

- **Real-time Backup**: Automatically triggered on channel state changes
- **Multiple Destinations**: Support for GCS, S3, MinIO, and Nextcloud
- **Auto-Detection**: Automatically detects MinIO in Kubernetes clusters
- **Separate Image**: Uses dedicated `lnd-backup` image independent of LND sidecar
- **Secure**: Uses Kubernetes secrets for credentials
- **Monitoring**: Full logging and error handling

### Setup

1. **Configure backup image and enable backup in values.yaml**:

   ```yaml
   backupImage:
     repository: lnd-backup
     tag: latest
     pullPolicy: IfNotPresent

   backup:
     enabled: true
     s3:
       enabled: true
       bucketName: "your-backup-bucket"
       region: "us-east-1"
       accessKeySecret:
         name: "backup-credentials"
         key: "access-key-id"
       secretKeySecret:
         name: "backup-credentials"
         key: "secret-access-key"
   ```

2. **Create required secrets**:

   ```bash
   kubectl create secret generic backup-credentials \
     --from-literal=access-key-id=YOUR_ACCESS_KEY \
     --from-literal=secret-access-key=YOUR_SECRET_KEY
   ```

3. **Deploy the chart**:

   ```bash
   helm upgrade --install lnd ./charts/lnd -f values.yaml
   ```

For complete backup setup instructions, see [README-backup.md](./README-backup.md).

## Monitoring

The chart exposes Prometheus metrics on port 9092 and includes health checks for:
- LND startup and readiness
- Backup service status
- Secret export functionality

Monitor backup operations:
```bash
kubectl logs -f lnd-0 -c backup
```

## Security

- TLS certificates are automatically generated or can be provided via secrets
- Macaroons and credentials are exported to Kubernetes secrets
- Backup credentials are stored securely in secrets
- Tor proxy provides additional privacy

## Troubleshooting

### Common Issues

1. **LND won't start**: Check bitcoind connectivity and network configuration
2. **Backup failures**: Verify credentials and bucket permissions
3. **Persistence issues**: Ensure storage class is available

### Debug Commands

```bash
# Check LND status
kubectl exec -it lnd-0 -- lncli getinfo

# View all container logs
kubectl logs lnd-0 --all-containers=true

# Test backup configuration
helm test lnd
```

## Testing

For development and testing of backup functionality:

```bash
cd dev/bitcoin/lnd-backup-test

# Build the backup image
./build-image.sh

# Deploy LND with backup functionality
./deploy.sh

# Test backup functionality
./test-backup.sh
```

The test setup includes MinIO auto-detection and comprehensive backup verification.

## Examples

For complete configuration examples, see:
- `dev/bitcoin/lnd-backup-test/values.yml`: Test configuration with backup
- [README-backup.md](./README-backup.md): Detailed backup configuration guide

## Contributing

When modifying the backup functionality:

1. Update the backup image in `images/lnd-backup/` if needed
2. Test with all backup destinations (GCS, S3, MinIO, Nextcloud)
3. Run the test suite in `dev/bitcoin/lnd-backup-test/`
4. Update documentation in both README files
5. Verify chart deployment and functionality

## License

This chart is part of the Blink/Galoy project and follows the same licensing terms.
