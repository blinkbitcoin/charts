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

if [[ "$success" != "true" ]]; then
  echo "Health smoke test failed"
  exit 1
fi

status=$(curl --location --silent --output /tmp/blink-lnurl-server-smoketest-body --write-out "%{http_code}" "${host}:${port}/.well-known/lnurlp/__smoketest__" || true)
if [[ "$status" == "200" || "$status" == "404" ]]; then
  exit 0
fi

if grep -Eiq "not.?found|domain|user|identifier" /tmp/blink-lnurl-server-smoketest-body; then
  exit 0
fi

echo "LNURL discovery smoke test failed with HTTP status ${status}"
cat /tmp/blink-lnurl-server-smoketest-body
exit 1
