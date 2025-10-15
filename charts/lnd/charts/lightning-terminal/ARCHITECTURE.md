# Lightning Terminal Architecture

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         LND Helm Chart                          │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                    LND StatefulSet                        │ │
│  │  ┌─────────────────────────────────────────────────────┐  │ │
│  │  │  LND Container                                      │  │ │
│  │  │  - Port 10009 (gRPC)                               │  │ │
│  │  │  - Port 8080 (REST)                                │  │ │
│  │  │  - Port 9735 (P2P)                                 │  │ │
│  │  │  - Generates: tls.cert, admin.macaroon            │  │ │
│  │  └─────────────────────────────────────────────────────┘  │ │
│  │                                                             │ │
│  │  ┌─────────────────────────────────────────────────────┐  │ │
│  │  │  Export Secrets Container                          │  │ │
│  │  │  - Exports credentials to K8s Secret               │  │ │
│  │  └─────────────────────────────────────────────────────┘  │ │
│  └───────────────────────────────────────────────────────────┘ │
│                              │                                  │
│                              │ Exports to Secret                │
│                              ▼                                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │         lnd-credentials Secret                            │ │
│  │  - tls.cert                                               │ │
│  │  - admin.macaroon                                         │ │
│  │  - readonly.macaroon                                      │ │
│  │  - autofees.macaroon                                      │ │
│  └───────────────────────────────────────────────────────────┘ │
│                              │                                  │
│                              │ Mounted by                       │
│                              ▼                                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │         Lightning Terminal StatefulSet (Subchart)         │ │
│  │  ┌─────────────────────────────────────────────────────┐  │ │
│  │  │  Init Container: wait-for-lnd                      │  │ │
│  │  │  - Waits for LND port 10009 to be ready            │  │ │
│  │  └─────────────────────────────────────────────────────┘  │ │
│  │                              │                             │ │
│  │                              ▼                             │ │
│  │  ┌─────────────────────────────────────────────────────┐  │ │
│  │  │  Lightning Terminal Container                       │  │ │
│  │  │  - Port 8443 (HTTPS Web UI)                        │  │ │
│  │  │  - Connects to LND via gRPC                        │  │ │
│  │  │  - Uses admin.macaroon for auth                    │  │ │
│  │  │  - Provides Loop, Pool, Faraday access            │  │ │
│  │  │                                                     │  │ │
│  │  │  Volume Mounts:                                    │  │ │
│  │  │  - /lnd-data/tls.cert (from secret)               │  │ │
│  │  │  - /lnd-data/.../autofees.macaroon (from secret)     │  │ │
│  │  └─────────────────────────────────────────────────────┘  │ │
│  └───────────────────────────────────────────────────────────┘ │
│                              │                                  │
│                              │ Exposed via                      │
│                              ▼                                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │         lightning-terminal Service                        │ │
│  │  - Type: ClusterIP                                        │ │
│  │  - Port: 8443                                             │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Port-forward for access
                              ▼
                    ┌──────────────────────┐
                    │   User's Browser     │
                    │  https://localhost:  │
                    │        8443          │
                    └──────────────────────┘
```

## Data Flow

### 1. LND Startup
1. LND starts and generates TLS certificate and macaroons
2. Export secrets container copies credentials to Kubernetes Secret
3. Secret `lnd-credentials` contains:
   - `tls.cert` - TLS certificate
   - `admin.macaroon` - Admin authentication token
   - `readonly.macaroon` - Read-only authentication token

### 2. Lightning Terminal Startup
1. Init container waits for LND to be ready (port 10009)
2. Lightning Terminal container starts
3. Mounts credentials from `lnd-credentials` secret:
   - TLS cert at `/lnd-data/tls.cert`
   - Admin macaroon at `/lnd-data/data/chain/bitcoin/{network}/admin.macaroon`
4. Connects to LND via gRPC at `lnd.{namespace}.svc.cluster.local:10009`
5. Starts HTTPS server on port 8443

### 3. User Access
1. User port-forwards service: `kubectl port-forward svc/lnd-lightning-terminal 8443:8443`
2. User opens browser to `https://localhost:8443`
3. User authenticates with configured password
4. Lightning Terminal proxies requests to LND using admin macaroon

## Security Model

### Network Isolation
- **LND Service**: ClusterIP, only accessible within cluster
- **Lightning Terminal Service**: ClusterIP, only accessible within cluster
- **User Access**: Via kubectl port-forward (requires cluster access)

### Authentication Layers
1. **Kubernetes RBAC**: User must have cluster access
2. **Port-forward**: User must have kubectl permissions
3. **Web UI Password**: User must know configured password
4. **LND Macaroon**: Lightning Terminal uses admin macaroon for LND access

### Credential Management
- **TLS Certificate**: Mounted read-only from secret
- **Macaroons**: Mounted read-only from secret
- **Secrets**: Managed by Kubernetes, not in container filesystem
- **No Persistence**: Lightning Terminal data stored in emptyDir (ephemeral)

## Resource Allocation

### LND Container
- Configurable via parent chart values
- Typically: 1-2 CPU, 2-4Gi memory

### Lightning Terminal Container
- Default Limits: 200m CPU, 256Mi memory
- Default Requests: 100m CPU, 128Mi memory
- Configurable via `lightning-terminal.resources`

## High Availability Considerations

### Current Implementation
- **Single Replica**: StatefulSet with 1 replica
- **No Persistence**: Uses emptyDir for temporary data
- **Stateless**: All state in LND, Lightning Terminal is just a UI

### Future Enhancements
- Could add persistent storage for Lightning Terminal session data
- Could implement multiple replicas with session affinity
- Could add ingress for external access with proper TLS

## Monitoring

### Health Checks
- **Liveness Probe**: HTTP GET on port 8443, checks if service is responsive
- **Readiness Probe**: HTTP GET on port 8443, checks if ready to serve traffic

### Logging
- Container logs available via `kubectl logs lnd-lightning-terminal-0`
- Logs include:
  - Connection status to LND
  - Web UI access attempts
  - Loop/Pool/Faraday operations

### Metrics
- Lightning Terminal exposes Prometheus metrics
- Can be scraped for monitoring

## Comparison with lndmon Subchart

| Feature | lndmon | lightning-terminal |
|---------|--------|-------------------|
| Purpose | Prometheus metrics | Web UI management |
| Port | 9092 | 8443 |
| Protocol | HTTP (metrics) | HTTPS (web UI) |
| Macaroon | readonly.macaroon | admin.macaroon |
| Access Level | Read-only | Full admin |
| User Interface | None (metrics only) | Web UI |
| Resource Usage | Lower (50m CPU, 64Mi RAM) | Higher (100m CPU, 128Mi RAM) |
| Security Risk | Lower (read-only) | Higher (admin access) |

## Configuration Inheritance

Lightning Terminal inherits configuration from parent chart:

```yaml
# Parent chart sets:
global.network: mainnet

# Subchart receives:
lightning-terminal.global.network: mainnet
lightning-terminal.lnd.serviceName: lnd
lightning-terminal.lnd.network: mainnet
```

This is handled by `charts/lnd/templates/lightning-terminal-config.yaml`.

