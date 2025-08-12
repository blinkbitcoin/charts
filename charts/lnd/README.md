# LND Helm Chart

This Helm chart deploys Lightning Network Daemon (LND) on Kubernetes with optional Static Channel Backup (SCB) functionality.

## Features

- **LND Node**: Full Lightning Network node with configurable parameters
- **Automatic Backup**: Built-in SCB backup sidecar with multiple destination support
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
# First, create backup secrets (see backup documentation)
./scripts/setup-backup-secrets.sh

# Install with backup enabled
helm install lnd ./charts/lnd \
  --values examples/backup-values.yaml
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
| `backup.enabled` | Enable SCB backup sidecar | `true` |
| `backup.gcs.enabled` | Enable Google Cloud Storage backup | `false` |
| `backup.s3.enabled` | Enable AWS S3 backup | `false` |
| `backup.nextcloud.enabled` | Enable Nextcloud backup | `false` |

For detailed backup configuration, see [README-backup.md](./README-backup.md).

## Static Channel Backup (SCB)

The chart includes an optional backup sidecar that automatically backs up LND's Static Channel Backup files to cloud storage. This ensures you can recover your Lightning channels in case of node failure.

### Key Features

- **Real-time Backup**: Automatically triggered on channel state changes
- **Multiple Destinations**: Support for GCS, S3, and Nextcloud
- **Secure**: Uses Kubernetes secrets for credentials
- **Monitoring**: Full logging and error handling

### Setup

1. **Enable backup in values.yaml**:
   ```yaml
   backup:
     enabled: true
     gcs:
       enabled: true
       bucketName: "your-backup-bucket"
   ```

2. **Create required secrets**:
   ```bash
   ./scripts/setup-backup-secrets.sh
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
kubectl logs -f statefulset/lnd -c backup
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

## Examples

See the `examples/` directory for complete configuration examples:
- `backup-values.yaml`: Full backup configuration
- `production-values.yaml`: Production-ready settings

## Contributing

When modifying the backup functionality:
1. Update the sidecar image if needed
2. Test with all backup destinations
3. Update documentation
4. Run chart tests

## License

This chart is part of the Blink/Galoy project and follows the same licensing terms.
