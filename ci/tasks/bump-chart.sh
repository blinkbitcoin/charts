#!/bin/bash

set -eu

cd blink-deployments

cat > github.key <<EOF
${GITHUB_SSH_KEY}
EOF

REF=$(cat ../chart/.git/ref)
make bump-vendored-ref DEP=${CHART} REF=${REF}
GITHUB_SSH_KEY_BASE64=$(base64 -w 0 ./github.key) make vendir

make recompose-supergraph

if [[ -z $(git config --global user.email) ]]; then
  git config --global user.email "202112752+blinkbitcoinbot@users.noreply.github.com"
fi
if [[ -z $(git config --global user.name) ]]; then
  git config --global user.name "blinkbitcoinbot"
fi


(cd $(git rev-parse --show-toplevel)
git merge --no-edit ${BRANCH}
git add -A
git status
git commit -m "chore: bump ${CHART}-chart to '${REF}'"
)
