#!/bin/bash

set -eu

pushd charts-repo

cat <<EOF >> ../body.md
This PR updates Helm Chart Dependencies.
EOF

export GH_TOKEN="$(ghtoken generate -b "${GH_APP_PRIVATE_KEY}" -i "${GH_APP_ID}" | jq -r '.token')"

gh pr close ${BOT_BRANCH} || true
gh pr create \
  --title "chore(deps): update $DEP helm chart in $DIR" \
  --body-file ../body.md \
  --base ${BRANCH} \
  --head ${BOT_BRANCH} \
  --label blinkbitcoinbot \
  --label helm || true
