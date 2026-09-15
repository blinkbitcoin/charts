#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source smoketest-settings/helpers.sh
endpoint="$(setting esign_endpoint)"

for attempt in {1..15}; do
  echo "eSign health check attempt ${attempt}"
  if body=$(curl --fail --silent --show-error --connect-timeout 5 --max-time 10 "${endpoint}/health") &&
    jq -e '.status == "ok" and (.capabilities | index("mint") != null)' <<<"$body" >/dev/null; then
    exit 0
  fi
  sleep 1
done

echo "eSign health smoke test failed" >&2
exit 1
