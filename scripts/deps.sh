#!/usr/bin/env bash
# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0
set -eo pipefail

# Check base + (optional) additional dependencies are installed
check_deps() {
    local additional_deps=("$@")
    local deps=(
        kubectl
        helm
        helmfile
        jq
        yq
    )
    if [[ ${#additional_deps[@]} -gt 0 ]]; then
        deps+=("${additional_deps[@]}")
    fi
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            echo "Error: $dep command not found. Please install '$dep' first. Exiting..."
            exit 1
        fi
    done
}

# Detect and validate values directory path
# Sets VALUES_DIR environment variable
setup_values_dir() {
    # Use environment variable or default to _values
    if [[ -z "${VALUES_DIR:-}" ]]; then
        export VALUES_DIR="_values"
    fi
    # Convert to absolute path if relative
    if [[ "${VALUES_DIR}" != /* ]]; then
        export VALUES_DIR="${CURRENT}/${VALUES_DIR}"
    fi
}

# Check setup was run
check_setup() {
    if [ ! -d "${VALUES_DIR}" ]; then
        echo "Error: ${VALUES_DIR} directory not found. Please run setup.sh first or set VALUES_DIR. Exiting..."
        exit 1
    fi
    # validate cluster type in platform values file
    if [ ! -f "${VALUES_DIR}/platform.yaml" ]; then
        echo "Error: platform.yaml not found in values directory ${VALUES_DIR}. Please run setup.sh first. Exiting..."
        exit 1
    fi
    CLUSTER_TYPE=$(yq '.platform.cluster.type' "${VALUES_DIR}/platform.yaml")
    if [[ "${CLUSTER_TYPE}" != "prebake" && "${CLUSTER_TYPE}" != "nadrama" && "${CLUSTER_TYPE}" != "eks" ]]; then
        echo "Error: Invalid cluster type '${CLUSTER_TYPE}' found in ${VALUES_DIR}/platform.yaml. Valid options: prebake, nadrama, eks"
        exit 1
    fi
}
