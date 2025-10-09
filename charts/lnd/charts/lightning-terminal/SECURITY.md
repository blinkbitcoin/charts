# Lightning Terminal Security Guide

## Overview

This guide covers security best practices for deploying Lightning Terminal in production environments.

## 🔐 Password Management

### ❌ NOT RECOMMENDED: Plain Text Password

```yaml
# DO NOT USE IN PRODUCTION
lightning-terminal:
  lit:
    uiPassword: "MyPassword123"  # Visible in values file and Helm history
```

**Issues:**
- Password stored in plain text in values file
- Visible in Helm release history
- Visible in Git if values are committed
- Difficult to rotate without redeploying

### ✅ RECOMMENDED: Kubernetes Secret

#### Step 1: Create a Secret

```bash
# Create secret with strong password
kubectl create secret generic lit-ui-password \
  --from-literal=password="$(openssl rand -base64 32)" \
  --namespace default

# Or create from file
echo -n "YourVerySecurePassword123!@#" > password.txt
kubectl create secret generic lit-ui-password \
  --from-file=password=password.txt \
  --namespace default
rm password.txt  # Clean up
```

#### Step 2: Reference Secret in Values

```yaml
lightning-terminal:
  enabled: true
  lit:
    # Leave uiPassword empty
    uiPassword: ""
    # Reference the secret
    existingSecret: "lit-ui-password"
    existingSecretKey: "password"
```

#### Step 3: Deploy

```bash
helm install lnd ./charts/lnd -f values.yaml
```

### 🔄 Password Rotation

```bash
# Update the secret
kubectl create secret generic lit-ui-password \
  --from-literal=password="$(openssl rand -base64 32)" \
  --namespace default \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart the pod to pick up new password
kubectl rollout restart statefulset/lnd-lightning-terminal
```

## 🛡️ Network Security

### Network Policy

Enable network policies to restrict traffic to/from Lightning Terminal:

```yaml
lightning-terminal:
  networkPolicy:
    enabled: true
    ingress:
      # Only allow traffic from specific pods
      - from:
        - podSelector:
            matchLabels:
              app: my-app
    egress:
      # Allow to LND
      - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: lnd
        ports:
        - protocol: TCP
          port: 10009
      # Allow DNS
      - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
        ports:
        - protocol: UDP
          port: 53
```

### Service Type

**Default (Recommended):**
```yaml
lightning-terminal:
  service:
    type: ClusterIP  # Only accessible within cluster
```

**For External Access (Use with Caution):**
```yaml
lightning-terminal:
  service:
    type: LoadBalancer  # Exposes to internet - NOT RECOMMENDED
```

### Ingress with TLS

For production external access, use Ingress with proper TLS:

```yaml
lightning-terminal:
  service:
    type: ClusterIP
  
  ingress:
    enabled: true
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
      # Rate limiting
      nginx.ingress.kubernetes.io/limit-rps: "10"
      # IP whitelist (optional)
      nginx.ingress.kubernetes.io/whitelist-source-range: "1.2.3.4/32,5.6.7.8/32"
    hosts:
      - host: lit.yourdomain.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: lit-tls-cert
        hosts:
          - lit.yourdomain.com
```

## 🔒 Pod Security

### Security Contexts

The chart uses secure defaults:

```yaml
# Pod-level security context
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault

# Container-level security context
containerSecurityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false  # LiT needs to write temp files
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
    - ALL
  seccompProfile:
    type: RuntimeDefault
```

### Pod Security Standards

Lightning Terminal is compatible with the **Restricted** Pod Security Standard:

```yaml
# Namespace label for Pod Security Standards
apiVersion: v1
kind: Namespace
metadata:
  name: lightning
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

## 🔑 Credential Management

### Macaroon Security

Lightning Terminal uses the **admin macaroon** which provides full access to LND:

**Security Implications:**
- Full control over LND node
- Can create/close channels
- Can send/receive payments
- Can access all wallet functions

**Best Practices:**
1. Limit access to Lightning Terminal UI
2. Use strong passwords
3. Enable audit logging
4. Monitor for suspicious activity
5. Consider using custom macaroons with limited permissions (advanced)

### TLS Certificate

The chart mounts LND's TLS certificate as read-only:

```yaml
volumeMounts:
  - name: lnd-tls-cert
    mountPath: /lnd-data/tls.cert
    subPath: tls.cert
    readOnly: true  # Read-only mount
```

## 🔍 Audit and Monitoring

### Enable Audit Logging

```yaml
lightning-terminal:
  extraArgs:
    - --log.level=info
    - --log.console=true
```

### Monitor Access

```bash
# View access logs
kubectl logs -f lnd-lightning-terminal-0 | grep "HTTP"

# Monitor authentication attempts
kubectl logs -f lnd-lightning-terminal-0 | grep "auth"
```

### Set Up Alerts

Example Prometheus alert for failed login attempts:

```yaml
- alert: LightningTerminalFailedLogins
  expr: rate(litd_auth_failures_total[5m]) > 5
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Multiple failed login attempts to Lightning Terminal"
```

## 🚫 Access Control

### RBAC

The chart creates minimal RBAC permissions:

```yaml
serviceAccount:
  create: true  # Dedicated service account
  
rbac:
  create: true  # Minimal permissions (currently empty rules)
```

### Namespace Isolation

Deploy in a dedicated namespace:

```bash
kubectl create namespace lightning
helm install lnd ./charts/lnd --namespace lightning
```

## 🔐 Secrets Management

### Using External Secrets Operator

For advanced secret management:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: lit-ui-password
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: lit-ui-password
    creationPolicy: Owner
  data:
    - secretKey: password
      remoteRef:
        key: lightning/lit-password
        property: password
```

### Using Sealed Secrets

```bash
# Create sealed secret
echo -n "YourPassword" | kubectl create secret generic lit-ui-password \
  --dry-run=client --from-file=password=/dev/stdin -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml

# Apply sealed secret
kubectl apply -f sealed-secret.yaml
```

## 📋 Security Checklist

### Pre-Production

- [ ] Use Kubernetes Secret for password (not plain text)
- [ ] Enable network policies
- [ ] Configure proper TLS/Ingress
- [ ] Review and harden security contexts
- [ ] Set up monitoring and alerting
- [ ] Document access procedures
- [ ] Test password rotation
- [ ] Review RBAC permissions

### Production

- [ ] Strong password (32+ characters, random)
- [ ] TLS certificate from trusted CA
- [ ] IP whitelisting on Ingress
- [ ] Rate limiting enabled
- [ ] Audit logging enabled
- [ ] Regular security updates
- [ ] Incident response plan
- [ ] Regular access reviews

### Ongoing

- [ ] Monitor access logs
- [ ] Rotate passwords quarterly
- [ ] Update to latest versions
- [ ] Review security advisories
- [ ] Test disaster recovery
- [ ] Audit user access

## 🚨 Security Incidents

### Suspected Compromise

1. **Immediately disable access:**
   ```bash
   kubectl scale statefulset lnd-lightning-terminal --replicas=0
   ```

2. **Rotate credentials:**
   ```bash
   # Rotate UI password
   kubectl create secret generic lit-ui-password \
     --from-literal=password="$(openssl rand -base64 32)" \
     --dry-run=client -o yaml | kubectl apply -f -
   
   # Restart LND to regenerate macaroons (if needed)
   kubectl rollout restart statefulset/lnd
   ```

3. **Review logs:**
   ```bash
   kubectl logs lnd-lightning-terminal-0 > incident-logs.txt
   ```

4. **Investigate and remediate**

5. **Re-enable with new credentials**

## 📚 Additional Resources

- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/security-checklist/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Lightning Terminal Security](https://docs.lightning.engineering/lightning-network-tools/lightning-terminal/security)
- [LND Security](https://docs.lightning.engineering/lightning-network-tools/lnd/security)

## 🔗 Related Documentation

- [README.md](./README.md) - General usage
- [QUICK_START.md](./QUICK_START.md) - Quick start guide
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Architecture overview

