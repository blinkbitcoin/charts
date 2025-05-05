#!/bin/bash

set -eu

digest=$(cat ./image/digest)

pushd charts-repo

ref=$(yq e ".${IMAGE_KEY_PATH}.git_ref" charts/${CHART}/values.yaml)
git checkout ${BRANCH}
old_ref=$(yq e ".${IMAGE_KEY_PATH}.git_ref" charts/${CHART}/values.yaml)

cat <<EOF >> ../body.md
# Bump ${IMAGE} image

The ${IMAGE} image will be bumped to digest:
\`\`\`
${digest}
\`\`\`

Code diff contained in this image:

https://github.com/blinkbitcoin/charts/compare/${old_ref}...${ref}
EOF

gh pr close ${BOT_BRANCH} || true
gh pr create \
  --title "chore(deps): bump-${IMAGE}-image-${ref}" \
  --body-file ../body.md \
  --base ${BRANCH} \
  --head ${BOT_BRANCH} \
  --label blinkbitcoinbot \
  --label ${CHART}
