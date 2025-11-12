#!/usr/bin/env bash
# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0
set -eo pipefail

CURRENT=$(dirname "$(readlink -f "$0")")
REPO_DIR=$(dirname "$CURRENT")
CRDS_CHART="$REPO_DIR/cilium-crds/templates/external"

# Get latest cilium version (or specify DL_VERSION to pin)
# DL_VERSION="v1.17.5"
if [ -z "${DL_VERSION}" ]; then
    DL_VERSION=$(curl -fsSL "https://api.github.com/repos/cilium/cilium/releases/latest" | jq -r .tag_name)
    echo "Latest ${DL_VERSION}"
else
    echo "Using ${DL_VERSION}"
fi

# Fetch the latest v2 CRDs from the Cilium repository
BASE_URL="https://raw.githubusercontent.com/cilium/cilium/refs/tags/${DL_VERSION}/pkg/k8s/apis/cilium.io/client/crds/v2"
CRD_FILES=(
    ciliumclusterwideenvoyconfigs.yaml
    ciliumclusterwidenetworkpolicies.yaml
    ciliumegressgatewaypolicies.yaml
    ciliumendpoints.yaml
    ciliumenvoyconfigs.yaml
    ciliumexternalworkloads.yaml
    ciliumidentities.yaml
    ciliumlocalredirectpolicies.yaml
    ciliumnetworkpolicies.yaml
    ciliumnodeconfigs.yaml
    ciliumnodes.yaml
)
for file in "${CRD_FILES[@]}"; do
    CMD="curl -s -o ${CRDS_CHART}/${file} -L ${BASE_URL}/${file}"
    echo "$CMD"
    $CMD
done

# Fetch the latest v2alpha1 CRDs from the Cilium repository
BASE_URL="https://raw.githubusercontent.com/cilium/cilium/refs/tags/${DL_VERSION}/pkg/k8s/apis/cilium.io/client/crds/v2alpha1"
CRD_FILES=(
    ciliumbgpadvertisements.yaml
    ciliumbgpclusterconfigs.yaml
    ciliumbgpnodeconfigoverrides.yaml
    ciliumbgpnodeconfigs.yaml
    ciliumbgppeerconfigs.yaml
    ciliumbgppeeringpolicies.yaml
    ciliumcidrgroups.yaml
    ciliumendpointslices.yaml
    ciliuml2announcementpolicies.yaml
    ciliumloadbalancerippools.yaml
    ciliumpodippools.yaml
)
for file in "${CRD_FILES[@]}"; do
    CMD="curl -s -o ${CRDS_CHART}/${file} -L ${BASE_URL}/${file}"
    echo "$CMD"
    $CMD
done
