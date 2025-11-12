#!/usr/bin/env bash
# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0
set -eo pipefail

SECRET_NAME="argocd-redis"
SECRET_NS="system-argocd"

# Exit early if secret already exists
kubectl get secret -n "${SECRET_NS}" "${SECRET_NAME}" &>/dev/null && exit 0

# Generate password and create secret
PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
ENCODED_PASSWORD=$(echo -n "${PASSWORD}" | base64)
kubectl apply -n "${SECRET_NS}" -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${SECRET_NS}
  labels:
    app.kubernetes.io/name: ${SECRET_NAME}
    app.kubernetes.io/part-of: argocd
type: Opaque
data:
  auth: ${ENCODED_PASSWORD}
EOF
echo "argocd redis password created"
