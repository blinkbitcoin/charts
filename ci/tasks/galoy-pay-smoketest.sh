#!/bin/bash

set -eu

source smoketest-settings/helpers.sh

hosts=`setting "galoy_pay_endpoints"`
port=`setting "galoy_pay_port"`

# Check if lnurl_check setting exists and set lnurl_check_disabled accordingly
if [[ $(setting_exists "lnurl_check_disabled") == "null" ]]; then
  lnurl_check_disabled="false"
else
  lnurl_check_disabled=`setting "lnurl_check_disabled"`
fi

# Username used for the lnurlp endpoint and invoice-request checks. Defaults to
# "test"; override on instances where that account is unsuitable (e.g. receive
# disabled by the custodial wind-down) with a controlled account instead.
if [[ $(setting_exists "lnurl_check_username") == "null" ]]; then
  lnurl_check_username="test"
else
  lnurl_check_username=`setting "lnurl_check_username"`
fi


set +e
for host in $(echo $hosts | jq -r '.[]'); do
  galoy_pay_success="false"
  lnurlp_endpoint_success="true"
  lnurlp_request_invoice_success="true"

  for i in {1..15}; do
    echo "Attempt ${i} to curl galoy pay on host ${host}"
    curl --location -f ${host}:${port}
    if [[ $? == 0 ]]; then galoy_pay_success="true"; break; fi;
    sleep 1
  done


  if [[ "$lnurl_check_disabled" != "true" ]]; then
    lnurlp_endpoint_success="false"
    lnurlp_request_invoice_success="false"
    for i in {1..15}; do
      echo "Attempt ${i} to curl lnurlp endpoint for user ${lnurl_check_username} on host ${host}"
      response=$(curl --location -fs ${host}/.well-known/lnurlp/${lnurl_check_username})
      is_response_valid=$(echo $response | jq -r 'has("callback") and has("minSendable") and has("maxSendable") and has("metadata") and has("tag")')
      if [[ "$is_response_valid" == "true" ]]; then lnurlp_endpoint_success="true"; break; fi;
      sleep 1
    done

    if [[ "$lnurlp_endpoint_success" == "true" ]]; then
      for i in {1..15}; do
        echo "Attempt ${i} to curl lnurlp endpoint to request an invoice for user ${lnurl_check_username} on host ${host}"
        response=$(curl --location -fs ${host}/lnurlp/${lnurl_check_username}/callback?amount=1000000)
        is_response_valid=$(echo $response | jq -r 'has("pr") and has("routes")')
        if [[ "$is_response_valid" == "true" ]]; then lnurlp_request_invoice_success="true"; break; fi;
        sleep 1
      done
    fi;
  fi

  if [[ "$galoy_pay_success" != "true" || "$lnurlp_endpoint_success" != "true" || "$lnurlp_request_invoice_success" != "true" ]]; then
    echo "Smoke test failed for host ${host}"
    exit 1
  fi;
done
set -e
