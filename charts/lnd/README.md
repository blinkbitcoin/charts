# LND Helm Chart

This Helm chart deploys Lightning Network Daemon (LND) on Kubernetes with optional Static Channel Backup (SCB) functionality.

## Features

- **LND Node**: Full Lightning Network node with configurable parameters
- **Automatic Backup**: Built-in SCB backup service with multiple destination support
- **Secret Management**: Automatic export of LND credentials to Kubernetes secrets
- **Tor Support**: Built-in Tor proxy for privacy
- **Monitoring**: Prometheus metrics and health checks
- **LND Monitoring**: Optional lndmon subchart for enhanced LND-specific metrics
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

### With LND Monitoring Enabled

```bash
# Install with lndmon monitoring enabled
helm install lnd ./charts/lnd \
  --set global.network=mainnet \
  --set persistence.enabled=true \
  --set lndmon.enabled=true
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
| `backupImage.repository` | Backup service image repository | `us.gcr.io/galoy-org/lnd-backup` |
| `backupImage.tag` | Backup service image tag | `latest` |
| `backup.gcs.enabled` | Enable Google Cloud Storage backup | `false` |
| `backup.s3.enabled` | Enable AWS S3/MinIO backup | `false` |
| `backup.nextcloud.enabled` | Enable Nextcloud backup | `false` |

For detailed backup configuration, see [README-backup.md](./README-backup.md).

### LND Monitoring Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `lndmon.enabled` | Enable lndmon monitoring subchart | `false` |
| `lndmon.image.repository` | lndmon image repository | `lightninglabs/lndmon` |
| `lndmon.image.tag` | lndmon image tag | `v0.2.12` |
| `lndmon.service.port` | Prometheus metrics port | `9092` |
| `lndmon.resources` | Resource requests/limits | See values.yaml |

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
     repository: us.gcr.io/galoy-org/lnd-backup
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

## LND Monitoring (lndmon)

The chart includes an optional lndmon subchart that provides enhanced Prometheus metrics specifically for LND nodes. This monitoring solution runs as a separate container and connects to your LND instance to collect detailed metrics.

### Key Features

- **LND-Specific Metrics**: Comprehensive metrics for channels, peers, payments, and node health
- **Prometheus Integration**: Native Prometheus metrics endpoint with automatic service discovery
- **Secure Access**: Uses read-only macaroons for secure LND API access
- **Isolated Deployment**: Runs as a separate subchart with minimal RBAC permissions
- **Resource Efficient**: Lightweight container with configurable resource limits
- **Health Monitoring**: Built-in health checks and monitoring capabilities

### Setup

1. **Enable lndmon in values.yaml**:

   ```yaml
   lndmon:
     enabled: true
     image:
       repository: lightninglabs/lndmon
       tag: v0.2.12
     service:
       port: 9092
       annotations:
         prometheus.io/scrape: "true"
         prometheus.io/port: "9092"
         prometheus.io/path: "/metrics"
   ```

2. **Deploy with lndmon enabled**:

   ```bash
   helm upgrade --install lnd ./charts/lnd \
     --set lndmon.enabled=true \
     --set global.network=mainnet
   ```

3. **Access metrics**:

   ```bash
   # Port-forward to access metrics locally
   kubectl port-forward svc/lnd-lndmon 9092:9092

   # View metrics
   curl http://localhost:9092/metrics
   ```

### Available Metrics

lndmon provides detailed metrics including:
- Channel state and capacity information
- Peer connection status
- Payment routing statistics
- Node synchronization status
- Wallet balance and transaction data
- Network graph information

## Monitoring

The chart provides comprehensive monitoring capabilities:

### Built-in Monitoring
- LND startup and readiness health checks
- Backup service status monitoring
- Secret export functionality monitoring
- Basic Prometheus metrics on port 9092

### Enhanced LND Monitoring (lndmon)
When lndmon is enabled, additional detailed metrics are available:
- Advanced LND-specific metrics on port 9092
- Channel state and capacity monitoring
- Peer connection and routing statistics
- Payment and transaction metrics
- Network graph and synchronization status

Monitor operations:
```bash
# Monitor backup operations
kubectl logs -f lnd-0 -c backup

# Monitor lndmon metrics (if enabled)
kubectl logs -f lnd-lndmon-0

# Access lndmon metrics endpoint
kubectl port-forward svc/lnd-lndmon 9092:9092
curl http://localhost:9092/metrics
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
4. **lndmon connection issues**: Verify LND is running and macaroons are accessible

# Check lndmon status (if enabled)
kubectl logs lnd-lndmon-0
kubectl describe pod lnd-lndmon-0

# Test lndmon metrics endpoint
kubectl port-forward svc/lnd-lndmon 9092:9092 &
curl http://localhost:9092/metrics
