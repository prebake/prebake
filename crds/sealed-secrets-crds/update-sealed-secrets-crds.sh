#!/usr/bin/env bash
# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0
set -eo pipefail

CURRENT=$(dirname "$(readlink -f "$0")")
REPO_DIR=$(dirname "$CURRENT")
CRDS_DIR="${CURRENT}/templates/external"

# Get latest sealed-secrets version (or specify DL_VERSION to pin)
# DL_VERSION="v0.30.0"
if [ -z "${DL_VERSION}" ]; then
    DL_VERSION=$(curl -fsSL "https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest" | jq -r .tag_name)
    echo "Latest ${DL_VERSION}"
else
    echo "Using ${DL_VERSION}"
fi

# Fetch the latest CRDs from the sealed-secrets repository
BASE_URL="https://raw.githubusercontent.com/bitnami-labs/sealed-secrets/refs/tags/${DL_VERSION}/helm/sealed-secrets/crds"
CRD_FILES=(
    bitnami.com_sealedsecrets.yaml
)
for file in "${CRD_FILES[@]}"; do
    CMD="curl -s -o ${CRDS_DIR}/${file} -L ${BASE_URL}/${file}"
    echo "$CMD"
    $CMD
done
