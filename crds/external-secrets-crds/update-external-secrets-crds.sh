#!/usr/bin/env bash
# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0
set -eo pipefail

CURRENT=$(dirname "$(readlink -f "$0")")
REPO_DIR=$(dirname $(dirname "$CURRENT"))
TEMP_DIR="$CURRENT/temp"
TEMPLATES_DIR="$CURRENT/templates/external"

# Create temp directory
mkdir "$TEMP_DIR"

# Get latest external-secrets version (or specify DL_VERSION to pin)
# DL_VERSION="v0.19.2"
if [ -z "${DL_VERSION}" ]; then
    DL_VERSION=$(curl -fsSL "https://api.github.com/repos/external-secrets/external-secrets/releases/latest" | jq -r .tag_name)
fi
echo "${DL_VERSION}"

# Download latest YAML file
DL_URL="https://raw.githubusercontent.com/external-secrets/external-secrets/refs/tags/${DL_VERSION}/deploy/crds/bundle.yaml"
echo "curl -o ${TEMP_DIR}/bundle.yaml ${DL_URL}"
curl --show-error -L -o "${TEMP_DIR}/bundle.yaml" "${DL_URL}"
# Split multi-document YAML file into separate YAML files
PREV=$(pwd)
cd "${TEMP_DIR}"
echo "yq -s '.metadata.name + \".yaml\"' bundle.yaml"
yq -s '.metadata.name + ".yaml"' "bundle.yaml"
rm "bundle.yaml"
cd "${PREV}"
echo "Done."

# Update chart templates
mv $TEMP_DIR/*.yaml "$TEMPLATES_DIR/"

# Clean up temp directory
rm -rf "${TEMP_DIR}"

echo "Please ensure both of the Chart.yml appVersion=${DL_VERSION}"
