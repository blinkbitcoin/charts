#!/bin/bash

set -eu

VERSION=$(cat helm-resource/version)

pushd charts-repo/charts/$DIR

yq -i "(.dependencies[] | select(.name == \"$DEP\") | .version) = \"$VERSION\"" Chart.yaml

helm dependency update

if [[ -z $(git config --global user.email) ]]; then
  git config --global user.email "202112752+blinkbitcoinbot@users.noreply.github.com"
fi
if [[ -z $(git config --global user.name) ]]; then
  git config --global user.name "blinkbitcoinbot"
fi

cd $(git rev-parse --show-toplevel)
git add -A
git status

# Only commit if there are uncommitted staged files
if ! git diff --cached --exit-code; then
  git commit -m "chore(deps): update $DEP helm chart in $DIR"
fi
