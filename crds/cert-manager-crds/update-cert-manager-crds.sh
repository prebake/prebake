#!/usr/bin/env bash
# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0
set -eo pipefail

CURRENT=$(dirname "$(readlink -f "$0")")

# DL_VERSION="v1.16.2"
if [ -z "${DL_VERSION}" ]; then
    DL_VERSION=$(curl -fsSL "https://api.github.com/repos/cert-manager/cert-manager/releases/latest" | jq -r .tag_name)
fi
echo "${DL_VERSION}"

DL_URL="https://github.com/cert-manager/cert-manager/releases/download/${DL_VERSION}/cert-manager.crds.yaml"

echo "curl -o ${CURRENT}/templates/external/crds.yaml ${DL_URL}"
curl --show-error -L -o "${CURRENT}/templates/external/crds.yaml" "${DL_URL}"

echo "yq -s '.metadata.name + \".yaml\"' crds.yaml"
PREV=$(pwd)
cd "${CURRENT}/templates/external"
yq -s '.metadata.name + ".yaml"' "crds.yaml"
rm "crds.yaml"
cd "${PREV}"
echo "Done."

echo "Please ensure Chart.yml appVersion=${DL_VERSION}"
