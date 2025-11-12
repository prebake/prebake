#!/usr/bin/env bash
# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0
set -eo pipefail

CM_NAME=argocd-cm
CM_NS=system-argocd

CURRENT=$(dirname "$(readlink -f "$0")")

# Exit early if configmap already exists
kubectl get configmap -n "${CM_NS}" "${CM_NAME}" &>/dev/null && echo "${CM_NAME} exists." && exit 0 || true

# Extract hostname from values file
ARGOCD_DOMAIN=$(yq eval '.prebake.argocd.hostname' "${CURRENT}/../../_values/argocd.yaml")

# Check argocd domain was extracted
if [ -z "${ARGOCD_DOMAIN}" ] || [ "${ARGOCD_DOMAIN}" = "null" ]; then
  echo "Failed to extract hostname from _values/argocd.yaml"
  exit 1
fi

# Load configmap template, replace vars, and apply to cluster
CM_CONFIGMAP=$(cat "${CURRENT}/cm-configmap.yaml"| sed "s/argocd.local.env.cool/${ARGOCD_DOMAIN}/g")
echo "${CM_CONFIGMAP}" | kubectl apply -n "${CM_NS}" -f -
