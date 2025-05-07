#!/bin/bash

set -eu

export digest=$(cat ./image/digest)
export ref=$(cat ./image-def/.git/short_ref)

pushd charts-repo

yq -i e ".${IMAGE_KEY_PATH}.digest = strenv(digest)" ./charts/${CHART}/values.yaml
yq -i e ".${IMAGE_KEY_PATH}.git_ref = strenv(ref)" ./charts/${CHART}/values.yaml

if [[ -z $(git config --global user.email) ]]; then
  git config --global user.email "202112752+blinkbitcoinbot@users.noreply.github.com"
fi
if [[ -z $(git config --global user.name) ]]; then
  git config --global user.name "blinkbitcoinbot"
fi

(
  cd $(git rev-parse --show-toplevel)
  git merge --no-edit ${BRANCH}
  git add -A
  git status
  git commit -m "chore(deps): bump ${IMAGE} image to '${digest}'"
)
