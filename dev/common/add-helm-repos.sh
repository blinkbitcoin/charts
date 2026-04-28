#!/bin/bash

function add_helm_repos() {
  yq e '.dependencies[] | select(.repository | test("^oci://") | not) | .name + " " + .repository' "$1" | while read -r name repo; do
      helm repo add "$name" "$repo"
  done
}

add_helm_repos "$1"
