#!/usr/bin/env bash
# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0
set -eo pipefail

CURRENT=$(dirname "$(readlink -f "$0")")
TEMP_DIR="$CURRENT/temp"
CRDS_CHART="$CURRENT/trust-manager-crds/templates/external"

# Create temp directory
mkdir "$TEMP_DIR"

# Get latest trust-manager version (or specify DL_VERSION to pin)
# DL_VERSION="v1.3.0"
if [ -z "${DL_VERSION}" ]; then
    DL_VERSION=$(curl -fsSL "https://api.github.com/repos/cert-manager/trust-manager/releases/latest" | jq -r .tag_name)
    echo "Latest ${DL_VERSION}"
else
    echo "Using ${DL_VERSION}"
fi

# Use `helm template` to render latest CRDs from https://charts.jetstack.io
helm template --namespace=system-trust-manager-crds trust-manager-crds cert-manager/trust-manager --output-dir="${TEMP_DIR}"

# Copy CRDs into templates
cp $TEMP_DIR/trust-manager/templates/crd-*.yaml "${CRDS_CHART}/"

# Clean up temp directory
rm -rf "$TEMP_DIR"

echo "Done. Please ensure both of the Chart.yml appVersion=${DL_VERSION}"
