# Prebake - Agent Guide

## Commands
- **Render all charts**: `make render` (generates manifests to `_rendered/`)
- **Install all charts**: `make install` (installs all charts to Kubernetes current context)
- **Uninstall all charts**: `make uninstall` (removes all charts from Kubernetes current context)
- **Single chart operations**: `make render CHART=<chart-name>`, `make install.sh CHARTT=<chart-name>`, `make uninstall CHART=<chart-name>`
- **Dependencies**: Requires `helm`, `helmfile`, `gcsplit` (from coreutils), `jq`, `yq`

Note: agents must NEVER run `./scripts/setup.sh` or `make setup`.

## Architecture
- **Core charts**: Critical infrastructure (cilium, coredns, cert-manager, traefik, cluster-wide) managed by Prebake not users
- **Addon charts**: Can later be installed/uninstalled if the user chooses
- **Default charts**: Pre-installed charts a user can edit (nadrama-hello)
- **Namespace convention**: Core & Addon charts use `system-` prefix plus chart name, Default charts use just chart name. For charts which only contain cluster-wide resources (e.g. CRD charts), we use the special `system-cluster` namespace, which should remain empty.
- **Network**: Dual-stack IPv4/IPv6 with specific CIDR blocks (Pod IPv4 `100.64.0.0/10` IPv6 `fd64::/48`, Service IPv4 `198.18.0.0/15` IPv6 `fdc6::/108`). CoreDNS IPv4 `198.19.255.254` IPv6 `fdc6::ffff`.
- **Structure**: Each chart has standard Helm chart files like Chart.yaml, values.yaml, templates/, optional dependencies in charts/

## Code Style
- **Helm charts**: Follow standard Helm conventions with dependencies in Chart.yaml
- **Bash scripts**: Use strict error handling (`set -eo pipefail`)
- **Chart ordering**: Critical - defined in config.sh arrays like INSTALL_CHARTS
- **Naming**: Use kebab-case for chart names, system- prefix for core namespaces
- **Dependencies**: External charts via Chart.yaml dependencies, not subcharts
