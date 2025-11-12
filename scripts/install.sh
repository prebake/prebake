#!/usr/bin/env bash
# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0
set -eo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CURRENT=$(cd "${SCRIPT_DIR}/.." && pwd)

# Check dependencies
source "${SCRIPT_DIR}/deps.sh"
check_deps
setup_values_dir
check_setup

# Ensure webhooks are disabled then restored on script error/cancellation
patch_webhooks() {
    local policy="$1"
    if [[ "$policy" != "Ignore" ]] && [[ "$policy" != "Fail" ]]; then
        echo "Invalid patch_webhooks policy param: $policy. Must be 'Ignore' or 'Fail'."
        exit 1
    fi
    echo "Setting webhooks to ${policy}..."
    # Restore cert-manager webhooks
    kubectl patch mutatingwebhookconfiguration/system-cert-manager-webhook --type='json' -p="[{'op': 'replace', 'path': '/webhooks/0/failurePolicy', 'value': '${policy}'}]" &> /dev/null || true
    kubectl patch validatingwebhookconfiguration/system-cert-manager-webhook --type='json' -p="[{'op': 'replace', 'path': '/webhooks/0/failurePolicy', 'value': '${policy}'}]" &> /dev/null || true
    kubectl patch validatingwebhookconfiguration/system-cert-manager-approver-policy --type='json' -p="[{'op': 'replace', 'path': '/webhooks/0/failurePolicy', 'value': '${policy}'}]" &> /dev/null || true
    # Restore trust-manager webhooks
    kubectl patch validatingwebhookconfiguration/system-trust-manager --type='json' -p="[{'op': 'replace', 'path': '/webhooks/0/failurePolicy', 'value': '${policy}'}]" &> /dev/null || true
    echo "Webhooks set to ${policy} successfully."
}
trap 'patch_webhooks Fail' EXIT
# patch_webhooks 'Ignore'

# Install specific chart if provided, or pass all args to helmfile
if [[ -n "${1}" && ! "${1}" =~ ^-- ]]; then
    chart_name="${1}"
    shift
    echo "Installing specific chart: ${chart_name}"
    cd "${CURRENT}" && helmfile --skip-refresh --args "--skip-crds" -l "chart=${chart_name}" "$@" sync
else
    echo "Installing all charts with helmfile..."
    cd "${CURRENT}" && helmfile --skip-refresh --args "--skip-crds" "$@" sync
fi
