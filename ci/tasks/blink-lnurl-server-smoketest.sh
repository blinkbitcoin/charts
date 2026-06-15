#!/bin/bash

set -eu

source smoketest-settings/helpers.sh

host=`setting "blink_lnurl_server_endpoint"`
port=`setting "blink_lnurl_server_port"`

success="false"
set +e
for i in {1..15}; do
  echo "Attempt ${i} to curl blink-lnurl-server health"
  curl --location -f "${host}:${port}/health"
  if [[ $? == 0 ]]; then success="true"; break; fi;
  sleep 1
done
set -e

if [[ "$success" != "true" ]]; then echo "Health smoke test failed" && exit 1; fi;

set +e
status_code=$(curl --location --silent --output /tmp/blink-lnurl-server-smoketest.out --write-out "%{http_code}" \
  "${host}:${port}/.well-known/lnurlp/__smoketest__")
curl_exit=$?
set -e

if [[ "$curl_exit" != "0" ]]; then
  echo "LNURL discovery smoke test failed to reach service"
  cat /tmp/blink-lnurl-server-smoketest.out
  exit 1
fi

if [[ "$status_code" != "200" && "$status_code" != "404" ]]; then
  echo "LNURL discovery smoke test failed with HTTP ${status_code}"
  cat /tmp/blink-lnurl-server-smoketest.out
  exit 1
fi
