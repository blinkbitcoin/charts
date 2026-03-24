#!/bin/bash

set -eu

source smoketest-settings/helpers.sh

host=`setting "blink_terminal_endpoint"`
port=`setting "blink_terminal_port"`

set +e
for i in {1..15}; do
  echo "Attempt ${i} to curl blink-terminal"
  curl --location -f ${host}:${port}/api/health
  if [[ $? == 0 ]]; then success="true"; break; fi;
  sleep 1
done
set -e

if [[ "$success" != "true" ]]; then echo "Smoke test failed" && exit 1; fi;
