#!/usr/bin/env bats

# Test autofees macaroon permissions in dev environment

setup() {
    # Set dev environment configuration
    export NETWORK="regtest"
    export NAMESPACE="galoy-dev-bitcoin"
    export LND1_POD="lnd1-0"
    export LND_DIR="/root/.lnd"
    export MACAROON_PATH="$LND_DIR/data/chain/bitcoin/$NETWORK/autofees.macaroon"

    # Check if LND pod is running
    if ! kubectl get pod $LND1_POD -n $NAMESPACE >/dev/null 2>&1; then
        skip "LND pod $LND1_POD not found in namespace $NAMESPACE"
    fi

    # Check if LND is responding
    if ! kubectl exec -n $NAMESPACE $LND1_POD -c lnd -- lncli --network=$NETWORK getinfo >/dev/null 2>&1; then
        skip "LND not ready in pod $LND1_POD"
    fi

    # Check if autofees macaroon exists
    if ! kubectl exec -n $NAMESPACE $LND1_POD -c lnd -- test -f "$MACAROON_PATH" 2>/dev/null; then
        skip "autofees.macaroon not found at $MACAROON_PATH in pod $LND1_POD"
    fi
}

@test "autofees macaroon: can read node info" {
    run kubectl exec -n $NAMESPACE $LND1_POD -c lnd -- lncli -n regtest --macaroonpath="$MACAROON_PATH" getinfo
    [ "$status" -eq 0 ]
    [[ "$output" == *"identity_pubkey"* ]]
}

@test "autofees macaroon: can read wallet balance" {
    run kubectl exec -n $NAMESPACE $LND1_POD -c lnd -- lncli -n regtest --macaroonpath="$MACAROON_PATH" walletbalance
    [ "$status" -eq 0 ]
    [[ "$output" == *"total_balance"* ]]
}

@test "autofees macaroon: can read channel balance" {
    run kubectl exec -n $NAMESPACE $LND1_POD -c lnd -- lncli -n regtest --macaroonpath="$MACAROON_PATH" channelbalance
    [ "$status" -eq 0 ]
    [[ "$output" == *"local_balance"* ]]
}

@test "autofees macaroon: can list channels" {
    run kubectl exec -n $NAMESPACE $LND1_POD -c lnd -- lncli -n regtest --macaroonpath="$MACAROON_PATH" listchannels
    [ "$status" -eq 0 ]
    [[ "$output" == *"channels"* ]]
}

@test "autofees macaroon: can get fee report" {
    run kubectl exec -n $NAMESPACE $LND1_POD -c lnd -- lncli -n regtest --macaroonpath="$MACAROON_PATH" feereport
    [ "$status" -eq 0 ]
    [[ "$output" == *"channel_fees"* ]]
}

@test "autofees macaroon: can get forwarding history" {
    run kubectl exec -n $NAMESPACE $LND1_POD -c lnd -- lncli -n regtest --macaroonpath="$MACAROON_PATH" fwdinghistory
    [ "$status" -eq 0 ]
    [[ "$output" == *"forwarding_events"* ]]
}

@test "autofees macaroon: can update channel policy (set fees)" {
    # First check if we have any channels
    run kubectl exec -n $NAMESPACE $LND1_POD -c lnd -- lncli -n regtest --macaroonpath="$MACAROON_PATH" listchannels
    if [[ "$output" == *'"channels": []'* ]]; then
        skip "No channels available for fee update test"
    fi
    
    # Test global fee update
    run kubectl exec -n $NAMESPACE $LND1_POD -c lnd -- lncli -n regtest --macaroonpath="$MACAROON_PATH" updatechanpolicy --base_fee_msat 1000 --fee_rate 0.001 --time_lock_delta 40
    [ "$status" -eq 0 ]
}

@test "autofees macaroon: CANNOT send on-chain payment" {
    run kubectl exec -n $NAMESPACE $LND1_POD -c lnd -- lncli -n regtest --macaroonpath="$MACAROON_PATH" sendcoins --addr bcrt1qw508d6qejxtdg4y5r3zarvary0c5xw7kygt080 --amt 1000
    [ "$status" -ne 0 ]
    [[ "$output" == *"permission denied"* ]] || [[ "$output" == *"insufficient permissions"* ]]
}

@test "autofees macaroon: CANNOT send lightning payment" {
    # Create a dummy invoice first (this should fail too, but let's test payment sending)
    run kubectl exec -n $NAMESPACE $LND1_POD -c lnd -- lncli -n regtest --macaroonpath="$MACAROON_PATH" payinvoice -f lnbcrt10u1p5w2cajpp5rkxh77tpywevs9rvrmq2eu59e0tv2muvw03jqmka424umvc26yhsdqqcqzpuxqyz5vqsp557qwpaqqwayzq6ay0kszy4c54qkxq5ffqla433h4ppau67ffe0yq9qxpqysgqt6lpktl07r3csjus5uywzskhtlkg2wcdyg77n8azsp5wf8zzahf4fadk42qjyqzdzcl6yjeak2hm0rcvwf4m4jyyr9m9x6gprykvpgspzfklrd
    [ "$status" -ne 0 ]
    [[ "$output" == *"permission denied"* ]] || [[ "$output" == *"insufficient permissions"* ]] || [[ "$output" == *"invalid"* ]] || [[ "$output" == *"unable to decode"* ]] || [[ "$output" == *"decode"* ]]
}

@test "autofees macaroon: CANNOT open channel" {
    # Use a dummy pubkey for testing
    run kubectl exec -n $NAMESPACE $LND1_POD -c lnd -- lncli -n regtest --macaroonpath="$MACAROON_PATH" openchannel --node_key 02deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef --local_amt 100000
    [ "$status" -ne 0 ]
    [[ "$output" == *"permission denied"* ]] || [[ "$output" == *"insufficient permissions"* ]]
}

@test "autofees macaroon: CANNOT close channel" {
    # Use dummy channel point
    run kubectl exec -n $NAMESPACE $LND1_POD -c lnd -- lncli -n regtest --macaroonpath="$MACAROON_PATH" closechannel --funding_txid deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef --output_index 0
    [ "$status" -ne 0 ]
    [[ "$output" == *"permission denied"* ]] || [[ "$output" == *"insufficient permissions"* ]]
}

@test "autofees macaroon: CANNOT create invoice" {
    run kubectl exec -n $NAMESPACE $LND1_POD -c lnd -- lncli -n regtest --macaroonpath="$MACAROON_PATH" addinvoice --amt 1000
    [ "$status" -ne 0 ]
    [[ "$output" == *"permission denied"* ]] || [[ "$output" == *"insufficient permissions"* ]]
}

@test "autofees macaroon: CANNOT generate new address" {
    run kubectl exec -n $NAMESPACE $LND1_POD -c lnd -- lncli -n regtest --macaroonpath="$MACAROON_PATH" newaddress p2wkh
    [ "$status" -ne 0 ]
    [[ "$output" == *"permission denied"* ]] || [[ "$output" == *"insufficient permissions"* ]]
}

@test "autofees macaroon: CANNOT bake new macaroon" {
    run kubectl exec -n $NAMESPACE $LND1_POD -c lnd -- lncli -n regtest --macaroonpath="$MACAROON_PATH" bakemacaroon info:read
    [ "$status" -ne 0 ]
    [[ "$output" == *"permission denied"* ]] || [[ "$output" == *"insufficient permissions"* ]]
}

@test "autofees macaroon: can list peers" {
    run kubectl exec -n $NAMESPACE $LND1_POD -c lnd -- lncli -n regtest --macaroonpath="$MACAROON_PATH" listpeers
    [ "$status" -eq 0 ]
    [[ "$output" == *"peers"* ]]
}

@test "autofees macaroon: can list invoices (read-only)" {
    run kubectl exec -n $NAMESPACE $LND1_POD -c lnd -- lncli -n regtest --macaroonpath="$MACAROON_PATH" listinvoices
    [ "$status" -eq 0 ]
    [[ "$output" == *"invoices"* ]]
}

@test "autofees macaroon: can list payments (read-only)" {
    run kubectl exec -n $NAMESPACE $LND1_POD -c lnd -- lncli -n regtest --macaroonpath="$MACAROON_PATH" listpayments
    [ "$status" -eq 0 ]
    [[ "$output" == *"payments"* ]]
}

teardown() {
    # Clean up any test artifacts if needed
    true
}