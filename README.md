# Galoy Kubernetes Helm Charts

Galoy community banking application, launchable on Kubernetes using [Kubernetes Helm](https://github.com/helm/helm).

## Before you begin

### Setup a Kubernetes Cluster

These charts have been tested on top of the galoy infrastructure ([`blink-infra`](https://github.com/blinkbitcoin/blink-infra)).

### Install Helm
[Helm](https://helm.sh) must be installed to use the charts.
Please refer to Helm's [documentation](https://helm.sh/docs/) to get started.

## What's included

This repo includes charts for:
- [`galoy`](https://github.com/GaloyMoney/galoy) Our bitcoin banking application
  - [`galoy-pay`](https://github.com/GaloyMoney/galoy-pay)
  - [`admin-panel`](https://github.com/GaloyMoney/admin-panel)
  - [`price`](https://github.com/GaloyMoney/price)

- [`bitcoind`](https://github.com/bitcoin/bitcoin) Bitcoin full node

- [`lnd`](https://github.com/lightningnetwork/lnd) Lightning Network daemon & client

- [`specter`](https://github.com/cryptoadvance/specter-desktop) On-chain wallet and multisig co-ordinator

- `monitoring` Metrics dashboard
  - [`grafana`](https://github.com/grafana/grafana)
  - [`prometheus`](https://github.com/prometheus/prometheus)
