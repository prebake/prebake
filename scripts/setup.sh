#!/usr/bin/env bash
# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0
set -eo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CURRENT=$(cd "${SCRIPT_DIR}/.." && pwd)

# Check dependencies
source "${SCRIPT_DIR}/deps.sh"
check_deps

# Default values
INGRESS_HOSTNAME=""
CLUSTER_TYPE="prebake"

# Parse command line flags
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domain)
            INGRESS_HOSTNAME="$2"
            shift 2
            ;;
        -t|--type)
            CLUSTER_TYPE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 -d <domain> [-t <cluster-type>]"
            echo "  -d, --domain       Ingress hostname (required)"
            echo "  -t, --type         Cluster type (default: prebake, valid: prebake|nadrama|eks)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 -d <domain> [-t <cluster-type>]"
            exit 1
            ;;
    esac
done

# Check required params
if [ -z "${INGRESS_HOSTNAME}" ]; then
    echo "Error: Domain is required"
    echo "Usage: $0 -d <domain> [-t <cluster-type>]"
    exit 1
fi

# Validate cluster type
if [[ "${CLUSTER_TYPE}" != "prebake" && "${CLUSTER_TYPE}" != "nadrama" && "${CLUSTER_TYPE}" != "eks" ]]; then
    echo "Error: Invalid cluster type '${CLUSTER_TYPE}'. Valid options: prebake, nadrama, eks"
    exit 1
fi
INGRESS_PORT=""
if [[ "${INGRESS_HOSTNAME}" = "local.env.cool" ]]; then
    # Nadrama dev-specific override
    INGRESS_PORT=":4433"
fi

# Prevent overwriting existing values files
if [ -d "${CURRENT}/_values" ]; then
    echo "${CURRENT}/_values directory already exists. Please remove it before running this script."
    exit 1
fi

# Create _values directory
mkdir -p "${CURRENT}/_values"

# Default value for all CSI drivers apps
CSI_ALL="false"
if [[ "${CSI_ALL}" == "true" ]] || [[ "${CSI_ALL}" == 1 ]]; then
    CSI_ALL="true"
fi

# Define network settings
IP_FAMILY_POLICY="PreferDualStack"
IP_FAMILIES_IPV4='- "IPv4"'
IP_FAMILIES_IPV6='- "IPv6"'
if [ "${CLUSTER_TYPE}" = "eks" ]; then
  IP_FAMILY_POLICY="SingleStack"
  IP_FAMILIES_IPV4='- "IPv4"'
  IP_FAMILIES_IPV6=""
fi

# Create values files

cat > "${CURRENT}/_values/platform.yaml" <<EOF
platform:
  cluster:
    type: "${CLUSTER_TYPE}"
    networking:
      ipFamilyPolicy: "${IP_FAMILY_POLICY}"
      ipFamilies:
        ${IP_FAMILIES_IPV4}
        ${IP_FAMILIES_IPV6}
  system:
    # CRDs
    crds:
      cilium-crds:
        enabled: true
      snapshot-crds:
        enabled: true
      cert-manager-crds:
        enabled: true
      trust-manager-crds:
        enabled: true
      gateway-api-crds:
        enabled: true
      traefik-crds:
        enabled: true
      argocd-crds:
        enabled: true
      sealed-secrets-crds:
        enabled: true
      external-secrets-crds:
        enabled: true
    # Apps
    apps:
      namespaces:
        enabled: true
      rbac:
        enabled: true
      cilium:
        enabled: true
      coredns:
        enabled: true
      snapshot:
        enabled: true
      csi-aws-ebs:
        enabled: ${CSI_ALL}
      cert-manager:
        enabled: true
      trust-manager:
        enabled: true
      traefik:
        enabled: true
      trust-bundles:
        enabled: true
      sealed-secrets:
        enabled: true
      argocd:
        enabled: true
EOF

if [ "${CLUSTER_TYPE}" = "eks" ]; then
cat > "${CURRENT}/_values/cilium.yaml" <<EOF
cilium:
  ipv4:
    enabled: true
  ipv6:
    enabled: true
  routingMode: "native"
  tunnelProtocol: ""
  ipam:
    mode: "eni"
  eni:
    enabled: true
    # ARN of IAM Role with required privileges
    # @see: https://docs.cilium.io/en/latest/network/concepts/ipam/eni/#required-privileges
    iamRole: "<CILIUM-ENI-IAM-ROLE-ARN>"
  egressMasqueradeInterfaces: "eth+"
  k8sServicePort: 443
  # Configure AWS_REGION on operator so AWS SDK can successfully perform STS AssumeRole
  operator:
    extraEnv:
    - name: AWS_REGION
      value: "<YOUR-REGION>"
  # EKS API Server Endpoint (without "https://" prefix)
  k8sServiceHost: "<PART-1>.<PART-2>.<YOUR-REGION>.eks.amazonaws.com"
EOF
else
cat > "${CURRENT}/_values/cilium.yaml" <<EOF
cilium:
  ipv4:
    enabled: true
  ipv6:
    enabled: true
  routingMode: "tunnel"
  tunnelProtocol: "vxlan"
  ipam:
    mode: "kubernetes"
EOF
fi

COREDNS_IPV4="198.19.255.254"
COREDNS_IPV6='- "fdc6::ffff"'
if [ "${CLUSTER_TYPE}" = "eks" ]; then
  COREDNS_IPV4="10.200.255.254"
  COREDNS_IPV6=""
fi
cat > "${CURRENT}/_values/coredns.yaml" <<EOF
coredns:
  service:
    clusterIP: "${COREDNS_IPV4}"
    clusterIPs:
      - "${COREDNS_IPV4}"
      ${COREDNS_IPV6}
    ipFamilyPolicy: "${IP_FAMILY_POLICY}"
    ipFamilies:
      ${IP_FAMILIES_IPV4}
      ${IP_FAMILIES_IPV6}
#   # loads the upstream nameserver config from systemd-resolve
#   # see https://coredns.io/plugins/loop/#troubleshooting-loops-in-kubernetes-clusters
#   extraVolumes:
#     - name: systemd-resolve
#       hostPath:
#         path: /run/systemd/resolve/resolv.conf
#         type: File
#   extraVolumeMounts:
#     - name: systemd-resolve
#       mountPath: /etc/resolv.conf
#       readOnly: true
EOF
if [ "${CLUSTER_TYPE}" = "eks" ]; then
  cat >> "${CURRENT}/_values/coredns.yaml" <<EOF
  # override just the "forward" plugin
  servers:
    - zones:
        - zone: .
          use_tcp: true
      port: 53
      plugins:
        - name: errors
        - name: health
          configBlock: |-
            lameduck 10s
        - name: ready
        - name: kubernetes
          parameters: cluster.local in-addr.arpa ip6.arpa
          configBlock: |-
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
            ttl 30
        - name: autopath
          parameters: "@kubernetes"
        - name: prometheus
          parameters: 0.0.0.0:9153
        - name: forward
          parameters: . 169.254.169.254
        - name: cache
          parameters: 30
        - name: loop
        - name: reload
        - name: loadbalance
EOF
fi

cat > "${CURRENT}/_values/csi-aws-ebs.yaml" <<EOF
# aws-ebs-csi-driver:
#   controller:
#     podAnnotations:
#       iam.amazonaws.com/role: "arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:role/nadrama-<YOUR_CLUSTER_SLUG>-ebs-csi"
EOF

cat > "${CURRENT}/_values/cert-manager.yaml" <<EOF
prebake:
  cert-manager:
    clusterCA:
      commonName: "${INGRESS_HOSTNAME}"
    traefikDefaultCertificatePolicy:
      allowedHostname: "${INGRESS_HOSTNAME}"
EOF

cat > "${CURRENT}/_values/traefik.yaml" <<EOF
prebake:
  traefik:
    # defaultCertificateSecret: system-traefik-casigned-certificate-secret
    certificates:
      dnsNames:
      - "${INGRESS_HOSTNAME}"
      - "*.${INGRESS_HOSTNAME}"
      selfsigned:
        issuerRef:
          name: system-selfsigned-clusterissuer
      casigned:
        issuerRef:
          # name: system-env-cool-clusterissuer
traefik:
  service:
    spec:
      clusterIP: "198.18.0.2"
      clusterIPs:
        - "198.18.0.2"
        - "fdc6::2"
    ipFamilyPolicy: "${IP_FAMILY_POLICY}"
    ipFamilies:
      ${IP_FAMILIES_IPV4}
      ${IP_FAMILIES_IPV6}
EOF

cat > "${CURRENT}/_values/argocd.yaml" <<EOF
prebake:
  argocd:
    hostname: "argocd.${INGRESS_HOSTNAME}"
argo-cd:
  global:
    dualStack:
      ipFamilyPolicy: "${IP_FAMILY_POLICY}"
      ipFamilies:
        ${IP_FAMILIES_IPV4}
        ${IP_FAMILIES_IPV6}
EOF

# Create empty values files for charts that don't need configuration
for chart in namespaces rbac snapshot trust-manager trust-bundles sealed-secrets platform; do
  if [ ! -f "${CURRENT}/_values/${chart}.yaml" ]; then
    touch "${CURRENT}/_values/${chart}.yaml"
  fi
done

# Add Helm repositories from helmfile
helmfile repos

echo "Setup complete. Created _values directory with individual chart values files and added Helm repositories."
