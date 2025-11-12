#!/usr/bin/env bash
# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0
set -eo pipefail

CURRENT=$(dirname "$(readlink -f "$0")")
REPO_DIR=$(dirname "$CURRENT")
CRDS_DIR="${CURRENT}/templates/external"

# Get latest argocd version (or specify DL_VERSION to pin)
# DL_VERSION="v3.0.6"
if [ -z "${DL_VERSION}" ]; then
    DL_VERSION=$(curl -fsSL "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | jq -r .tag_name)
    echo "Latest ${DL_VERSION}"
else
    echo "Using ${DL_VERSION}"
fi

# Fetch the latest CRDs from the argocd repository
BASE_URL="https://raw.githubusercontent.com/argoproj/argo-cd/refs/tags/${DL_VERSION}/manifests/crds"
CRD_FILES=(
    application-crd.yaml
    applicationset-crd.yaml
    appproject-crd.yaml
)
for file in "${CRD_FILES[@]}"; do
    CMD="curl -s -o ${CRDS_DIR}/${file} -L ${BASE_URL}/${file}"
    echo "$CMD"
    $CMD
done
