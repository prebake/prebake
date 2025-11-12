#!/usr/bin/env bash
# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0

set -eo pipefail

CURRENT=$(dirname "$(readlink -f "$0")")

echo "Running cel-policy-test..."
echo

cd "$CURRENT/tests/runner"
go run main.go ..
