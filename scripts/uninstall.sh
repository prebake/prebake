#!/usr/bin/env bash
# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0
# Helmfile-based replacement for uninstall.sh

set -eo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CURRENT=$(cd "${SCRIPT_DIR}/.." && pwd)

# Check dependencies
source "${SCRIPT_DIR}/deps.sh"
check_deps

# Uninstall specific chart if provided
if [[ -n "${1}" ]]; then
    echo "Uninstalling specific chart: ${1}"
    helmfile -l "name=${1}" destroy
else
    echo "Uninstalling all charts with helmfile..."
    helmfile destroy
fi
