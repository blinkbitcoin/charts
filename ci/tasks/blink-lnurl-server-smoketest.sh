#!/bin/bash

set -eu

source smoketest-settings/helpers.sh

host=`setting "blink_lnurl_server_endpoint"`
port=`setting "blink_lnurl_server_port"`

success="false"
set +e
for i in {1..15}; do
  echo "Attempt ${i} to curl blink-lnurl-server health"
  curl --location -f ${host}:${port}/health
  if [[ $? == 0 ]]; then success="true"; break; fi;
  sleep 1
done
set -e

if [[ "$success" != "true" ]]; then echo "Health smoke test failed" && exit 1; fi;

lnurl_status="000"
set +e
for i in {1..15}; do
  echo "Attempt ${i} to curl blink-lnurl-server LNURL discovery"
  lnurl_status=$(curl --location --silent --show-error --output /dev/null --write-out "%{http_code}" ${host}:${port}/.well-known/lnurlp/__smoketest__)
  if [[ "$lnurl_status" == "200" || "$lnurl_status" == "400" || "$lnurl_status" == "404" ]]; then success="true"; break; fi;
  sleep 1
done
set -e

if [[ "$lnurl_status" != "200" && "$lnurl_status" != "400" && "$lnurl_status" != "404" ]]; then
  echo "LNURL discovery smoke test failed with HTTP status ${lnurl_status}" && exit 1
fi;
