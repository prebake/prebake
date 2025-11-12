#!/usr/bin/env bash
# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0
set -eo pipefail

CURRENT=$(dirname "$(readlink -f "$0")")
TEMPLATES_DIR="$CURRENT/templates/external"

# Get latest external-snapshotter tag (or specify DL_VERSION to pin)
# DL_VERSION="v8.3.0"
if [ -z "${DL_VERSION}" ]; then
    DL_VERSION=$(curl -fsSL "https://api.github.com/repos/kubernetes-csi/external-snapshotter/releases/latest" | jq -r .tag_name)
fi
echo "${DL_VERSION}"

# CRD files to download
CRD_FILES=(
    groupsnapshot.storage.k8s.io_volumegroupsnapshotclasses.yaml
    groupsnapshot.storage.k8s.io_volumegroupsnapshotcontents.yaml
    groupsnapshot.storage.k8s.io_volumegroupsnapshots.yaml
    snapshot.storage.k8s.io_volumesnapshotclasses.yaml
    snapshot.storage.k8s.io_volumesnapshotcontents.yaml
    snapshot.storage.k8s.io_volumesnapshots.yaml
)

# Download files
for FILE in "${CRD_FILES[@]}"; do
    DL_URL="https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/refs/tags/${DL_VERSION}/client/config/crd/${FILE}"
    echo "curl -o ${TEMPLATES_DIR}/${FILE} ${DL_URL}"
    curl --show-error -L -o "${TEMPLATES_DIR}/${FILE}" "${DL_URL}"
    echo "Done."
done

echo "Please ensure Chart.yml appVersion=${DL_VERSION}"
