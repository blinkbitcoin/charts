# Testing LND Backup Functionality

## Demo Script
To demonstrate the complete LND backup functionality, run the `demo-backup-functionality.sh` script. This script:
* Checks backup service status
* Connects LND1 and LND2
* Opens a channel between them
* Monitors backup events
* Verifies backup in MinIO

## GCS Backup Testing
* Enable gcs backup in the `lnd-regtest-values.yml` file
```
  # Enable GCS backup
  gcs:
    enabled: true
    bucketName: "dev-test-backups"  # Replace with your actual bucket name
    serviceAccountSecret:
      name: "lnd-backup-gcs-sa"
      key: "service-account.json"
```
* Create a service account with write permissions to the bucket
* Create a secret from the service account key
```bash
kubectl create secret generic lnd-backup-gcs-sa \
  --from-file=service-account.json=./dev-test-backups-sa-creds.json \
  -n galoy-dev-bitcoin
```

## Local changes to the backup image
* Build and use local backup image
```bash
docker build -t lnd-backup:latest images/lnd-backup/
nix develop --command k3d image import lnd-backup:latest
```

* Modify the Tiltfile to use the local image

```
helm_resource(
  name="lnd1",
  chart="../../charts/lnd",
  namespace=bitcoin_namespace,
  flags=[
    '--values=./lnd-regtest-values.yml',
    '--set=backupImage.repository=lnd-backup',
    '--set=backupImage.tag=latest',
    '--set=backupImage.pullPolicy=Never',
  ],
  labels='bitcoin',
```