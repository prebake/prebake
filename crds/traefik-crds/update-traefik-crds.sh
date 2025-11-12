#!/usr/bin/env bash
# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0
set -eo pipefail

CURRENT=$(dirname "$(readlink -f "$0")")
TEMP_DIR="$CURRENT/temp"
CRDS_CHART="$CURRENT/templates/external"

# Create temp directory
mkdir "$TEMP_DIR"

# Get latest traefik helm chart version (or specify DL_VERSION to pin)
# DL_VERSION="v37.0.0"
if [ -z "${DL_VERSION}" ]; then
    DL_VERSION=$(curl -fsSL "https://api.github.com/repos/traefik/traefik-helm-chart/releases/latest" | jq -r .tag_name)
    echo "Latest ${DL_VERSION}"
else
    echo "Using ${DL_VERSION}"
fi

# Use `helm template` to render latest CRDs from https://traefik.github.io/charts
helm template --include-crds --namespace=system-traefik-crds traefik-crds traefik/traefik --output-dir="${TEMP_DIR}"

# Copy CRDs into templates
cp $TEMP_DIR/traefik/crds/hub.traefik.io_*.yaml "${CRDS_CHART}/"
cp $TEMP_DIR/traefik/crds/traefik.io_*.yaml "${CRDS_CHART}/"

# Clean up temp directory
rm -rf "$TEMP_DIR"

echo "Done. Please ensure both of the Chart.yml appVersion=${DL_VERSION}"
