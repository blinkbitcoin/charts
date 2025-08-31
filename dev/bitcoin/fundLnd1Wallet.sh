#!/bin/bash

set -e

NAMESPACE="galoy-dev-bitcoin"
LND_POD="lnd1-0"

echo "Funding LND1 wallet..."

# Check if LND is ready
if ! kubectl get pod $LND_POD -n $NAMESPACE >/dev/null 2>&1; then
    echo "LND1 pod not found, skipping wallet funding"
    exit 0
fi

# Check if LND is responding
if ! kubectl exec -n $NAMESPACE $LND_POD -c lnd -- lncli --network=regtest getinfo >/dev/null 2>&1; then
    echo "LND1 not ready yet, skipping wallet funding"
    exit 0
fi

# Generate a new address
NEW_ADDRESS=$(kubectl exec -n $NAMESPACE $LND_POD -c lnd -- lncli --network=regtest newaddress p2wkh | grep address | cut -d'"' -f4)

if [ -z "$NEW_ADDRESS" ]; then
    echo "Failed to generate address, skipping wallet funding"
    exit 0
fi

echo "Generated address: $NEW_ADDRESS"

# Send funds from bitcoind to the LND wallet
kubectl exec -n $NAMESPACE bitcoind-0 -- bitcoin-cli -regtest generatetoaddress 101 "$NEW_ADDRESS"

# Generate additional blocks to confirm the funding transaction
MINING_ADDRESS=$(kubectl exec -n $NAMESPACE bitcoind-0 -- bitcoin-cli -regtest getnewaddress)
kubectl exec -n $NAMESPACE bitcoind-0 -- bitcoin-cli -regtest generatetoaddress 6 "$MINING_ADDRESS"

echo "LND1 wallet funded successfully"

# Check the wallet balance
sleep 5
BALANCE=$(kubectl exec -n $NAMESPACE $LND_POD -c lnd -- lncli --network=regtest walletbalance | grep confirmed_balance | cut -d'"' -f4 || echo "0")
echo "LND1 wallet balance: $BALANCE satoshis"
