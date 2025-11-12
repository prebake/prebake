#!/usr/bin/env bash
# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0
set -eo pipefail

CURRENT=$(dirname "$(readlink -f "$0")")
REPO_DIR=$(dirname "$CURRENT")
TEMP_DIR="$REPO_DIR/temp"
CRDS_CHART="$REPO_DIR/gateway-api-crds/templates/external"

# Create temp directory
mkdir "$TEMP_DIR"

# Get latest gateway-api version (or specify DL_VERSION to pin)
# DL_VERSION="v1.3.0"
if [ -z "${DL_VERSION}" ]; then
    DL_VERSION=$(curl -fsSL "https://api.github.com/repos/kubernetes-sigs/gateway-api/releases/latest" | jq -r .tag_name)
fi
echo "${DL_VERSION}"

# Download latest YAML files
for install_kind in "standard-install" "experimental-install"; do
    DL_URL="https://github.com/kubernetes-sigs/gateway-api/releases/download/${DL_VERSION}/${install_kind}.yaml"
    mkdir -p "${TEMP_DIR}/${install_kind}"
    echo "curl -o ${TEMP_DIR}/${install_kind}/${install_kind}.yaml ${DL_URL}"
    curl --show-error -L -o "${TEMP_DIR}/${install_kind}/${install_kind}.yaml" "${DL_URL}"
    # Split multi-document YAML file into separate YAML files
    PREV=$(pwd)
    cd "${TEMP_DIR}/${install_kind}"
    echo "yq -s '.metadata.name + \".yaml\"' ${install_kind}.yaml"
    yq -s '.metadata.name + ".yaml"' "${install_kind}.yaml"
    rm "${install_kind}.yaml"
    cd "${PREV}"
    echo "Done."
done

# Update chart templates
#mv $TEMP_DIR/standard-install/*.yaml "$CRDS_CHART/"
mv $TEMP_DIR/experimental-install/*.yaml "$CRDS_CHART/"

# Clean up temp directory
rm -rf "${TEMP_DIR}"

echo "Please ensure both of the Chart.yml appVersion=${DL_VERSION}"
