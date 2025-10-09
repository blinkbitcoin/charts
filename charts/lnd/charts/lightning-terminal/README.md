# Lightning Terminal Subchart

This is a subchart for the LND Helm chart that deploys Lightning Terminal (LiT), a web-based UI for managing your Lightning Network node.

## Overview

Lightning Terminal provides a modern web interface for managing LND and accessing Lightning Labs' suite of tools including Loop, Pool, and Faraday.

## Features

- **Web UI**: Modern, user-friendly web interface for LND management
- **Integrated Tools**: Access to Loop (submarine swaps), Pool (liquidity marketplace), and Faraday (channel analytics)
- **Secure**: Password-protected HTTPS interface
- **Remote Mode**: Connects securely to the parent LND node
- **Health Checks**: Built-in liveness and readiness probes
- **Resource Efficient**: Configurable resource limits

## Prerequisites

**Important**: Lightning Terminal requires LND to have RPC middleware enabled. This is already configured in the parent LND chart's default values.

If you're using custom LND configuration, ensure you have:

```yaml
lndGeneralConfig:
  - rpcmiddleware.enable=true
```

Or in your `lnd.conf`:
```
rpcmiddleware.enable=true
```

Without this setting, Lightning Terminal will fail to start with the error:
```
RPC middleware not enabled in config
```

## Configuration

### Basic Configuration (Development)

```yaml
lightning-terminal:
  enabled: true
  image:
    repository: lightninglabs/lightning-terminal
    tag: v0.14.1-alpha  # Configurable version
  lit:
    uiPassword: "YourSecurePassword"  # NOT RECOMMENDED FOR PRODUCTION
```

### Secure Configuration (Production)

**Step 1: Create a Kubernetes Secret**

```bash
# Generate a strong random password
kubectl create secret generic lit-ui-password \
  --from-literal=password="$(openssl rand -base64 32)" \
  --namespace default
```

**Step 2: Configure to use the secret**

```yaml
lightning-terminal:
  enabled: true
  image:
    repository: lightninglabs/lightning-terminal
    tag: v0.14.1-alpha
  lit:
    # Use existing secret instead of plain text password
    existingSecret: "lit-ui-password"
    existingSecretKey: "password"
    # Leave uiPassword empty
    uiPassword: ""
```

### Advanced Configuration

```yaml
lightning-terminal:
  enabled: true
  
  # Image configuration
  image:
    repository: lightninglabs/lightning-terminal
    tag: v0.14.1-alpha
    pullPolicy: IfNotPresent
  
  # Service configuration
  service:
    type: ClusterIP
    port: 8443
  
  # Lightning Terminal configuration
  lit:
    uiPassword: "YourSecurePassword"
    httpListen: "0.0.0.0:8443"
  
  # Resource limits
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi

  # Persistent storage for Lightning Terminal data
  # Stores data for integrated daemons (tapd, faraday, loop, pool)
  persistence:
    enabled: true
    size: 5Gi
    accessMode: ReadWriteOnce
    # storageClass: ""  # Use default storage class

  # Additional command line arguments
  extraArgs:
    - --log.level=debug
```

## Persistent Storage

Lightning Terminal requires persistent storage to maintain data for its integrated daemons:

- **Taproot Assets (tapd)**: Stores taproot asset databases and state
- **Faraday**: Stores channel analytics and historical data
- **Loop**: Stores submarine swap history and state
- **Pool**: Stores liquidity marketplace data

### Storage Configuration

By default, persistence is **enabled** with a 5Gi volume. The data is stored in `/data` with the following structure:

```
/data/
├── .lit/       # Lightning Terminal configuration and state
├── .tapd/      # Taproot Assets daemon data
├── .faraday/   # Faraday analytics data
├── .loop/      # Loop swap data
└── .pool/      # Pool liquidity data
```

### Customizing Storage

```yaml
lightning-terminal:
  persistence:
    enabled: true
    size: 10Gi  # Adjust based on your needs
    accessMode: ReadWriteOnce
    storageClass: "fast-ssd"  # Optional: specify storage class
    # existingClaim: "my-existing-pvc"  # Optional: use existing PVC
```

### Disabling Persistence (Not Recommended)

For testing purposes only, you can disable persistence:

```yaml
lightning-terminal:
  persistence:
    enabled: false
```

**⚠️ Warning**: Disabling persistence will result in data loss on pod restarts!

## Usage

### Installation

Install LND with Lightning Terminal enabled:

```bash
helm install lnd ./charts/lnd \
  --set lightning-terminal.enabled=true \
  --set lightning-terminal.lit.uiPassword=YourSecurePassword \
  --set global.network=mainnet
```

### Accessing the Web UI

1. Port-forward the service to your local machine:

```bash
kubectl port-forward svc/lnd-lightning-terminal 8443:8443
```

2. Open your browser and navigate to:

```
https://localhost:8443
```

3. Accept the self-signed certificate warning (or configure proper TLS certificates)

4. Log in with the password you configured

### Monitoring

Check the Lightning Terminal logs:

```bash
kubectl logs -f lnd-lightning-terminal-0
```

Check the pod status:

```bash
kubectl describe pod lnd-lightning-terminal-0
```

## Security Considerations

### Critical Security Practices

1. **Password Management**
   - ✅ **RECOMMENDED**: Use `existingSecret` to reference a Kubernetes secret
   - ❌ **NOT RECOMMENDED**: Use `uiPassword` with plain text (development only)
   - Generate strong passwords: `openssl rand -base64 32`
   - Rotate passwords regularly

2. **TLS/HTTPS**
   - The service uses HTTPS with a self-signed certificate by default
   - For production, configure proper TLS certificates via Ingress
   - Use cert-manager for automated certificate management

3. **Access Control**
   - Lightning Terminal uses the **admin macaroon** (full LND access)
   - Limit who can access the web UI
   - Consider IP whitelisting on Ingress
   - Enable network policies to restrict traffic

4. **Network Exposure**
   - Default: ClusterIP (only accessible within cluster) ✅
   - Use kubectl port-forward for local access
   - If external access needed, use Ingress with proper security
   - Never use LoadBalancer or NodePort in production

5. **Monitoring**
   - Enable audit logging
   - Monitor for failed login attempts
   - Set up alerts for suspicious activity

### Security Resources

- **[SECURITY.md](./SECURITY.md)** - Comprehensive security guide
- **[Production Example](../../examples/lightning-terminal-production.yaml)** - Secure configuration example

## Troubleshooting

### Lightning Terminal won't start

1. Check if LND is running:
```bash
kubectl get pods | grep lnd
```

2. Check Lightning Terminal logs:
```bash
kubectl logs lnd-lightning-terminal-0
```

3. Verify the admin macaroon is available:
```bash
kubectl get secret lnd-credentials -o yaml
```

### Cannot access the web UI

1. Verify the service is running:
```bash
kubectl get svc lnd-lightning-terminal
```

2. Check if port-forward is active:
```bash
kubectl port-forward svc/lnd-lightning-terminal 8443:8443
```

3. Verify the password is correct

### Connection to LND fails

1. Check if LND service is accessible:
```bash
kubectl get svc lnd
```

2. Verify the init container completed successfully:
```bash
kubectl describe pod lnd-lightning-terminal-0
```

## Version Compatibility

- Lightning Terminal v0.14.1-alpha (default)
- Compatible with LND v0.18.x
- Requires admin macaroon access

## Resources

- [Lightning Terminal Documentation](https://docs.lightning.engineering/lightning-network-tools/lightning-terminal)
- [Lightning Terminal GitHub](https://github.com/lightninglabs/lightning-terminal)
- [Docker Hub](https://hub.docker.com/r/lightninglabs/lightning-terminal)

