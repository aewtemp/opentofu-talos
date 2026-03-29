# Talos Kubernetes on Proxmox — OpenTofu

Full-lifecycle deployment of a production-grade [Talos Linux](https://talos.dev) Kubernetes cluster
spanning multiple [Proxmox VE](https://pve.proxmox.com) hypervisor clusters, managed entirely with
[OpenTofu](https://opentofu.org). From bare-metal VMs to a GitOps-managed cluster in one `tofu apply`.

## Architecture

```
┌───────────────────────────────────────────────────────────────────┐
│  Kubernetes cluster "chaoskube" (single K8s, multiple sites)      │
│                                                                   │
│   cluster_a (primary)        cluster_b      cluster_c / cluster_d │
│   ┌──────────────────┐   ┌────────────────┐   ┌───────────────┐   │
│   │ cp01 cp02 cp03   │   │ cp04  cp05     │   │ cp06   cp07   │   │
│   │ wn01 wn02        │   │ wn05  wn06     │   │ wn07   wn09   │   │
│   │ wn03 wn04        │   │                │   │ wn08   wn10   │   │
│   └──────────────────┘   └────────────────┘   └───────────────┘   │
└───────────────────────────────────────────────────────────────────┘
         │
         ├── CNI: Cilium (eBPF, BGP LoadBalancer, L2 announcements)
         ├── GitOps: ArgoCD → gitlab deployments repo
         └── Storage: Longhorn (distributed block storage)
```

**17 nodes** — 7 control plane + 10 workers — across 4 Proxmox clusters (`cluster_a`..`cluster_d`).

## Stack

| Layer          | Technology                                                         |
| -------------- | ------------------------------------------------------------------ |
| Infrastructure | [OpenTofu](https://opentofu.org)                                   |
| Hypervisor     | [Proxmox VE](https://pve.proxmox.com) (bpg/proxmox provider)       |
| OS             | [Talos Linux](https://talos.dev) — immutable, API-driven           |
| CNI            | [Cilium](https://cilium.io) — eBPF, BGP peering, L2 announcements  |
| GitOps         | [ArgoCD](https://argoproj.github.io/cd)                            |
| Ingress        | Traefik                                                            |
| Storage        | [Longhorn](https://longhorn.io) + iSCSI                            |
| Secrets        | [SOPS](https://github.com/getsops/sops) + age                      |
| Certificates   | cert-manager + Let's Encrypt (DNS-01 via Domain Offensive webhook) |

## Quick Start

### 1. Prerequisites

- OpenTofu >= 1.0 (`brew install opentofu` or [opentofu.org/docs/intro/install](https://opentofu.org/docs/intro/install/))
- Proxmox VE with API token for each cluster
- DNS or external LB entry pointing `<cluster_endpoint>` at your control-plane IPs

### 2. Configure

```bash
# Infrastructure, versions, Proxmox endpoints
cp terraform.tfvars.example terraform.tfvars

# Node inventory and sizing
cp nodes.auto.tfvars.example nodes.auto.tfvars

# Helm chart versions and releases
cp helm.auto.tfvars.example helm.auto.tfvars

# ArgoCD application catalog
cp argocd.auto.tfvars.example argocd.auto.tfvars

# API tokens and deploy credentials (gitignored)
cp secrets.tfvars.example secrets.tfvars
```

Edit each file to match your environment. See [Configuration Files](#configuration-files) below.

### 3. Add provider aliases for your Proxmox clusters

For each entry in `proxmox_clusters` (terraform.tfvars) you need a matching `provider "proxmox"` block
in `providers.tf`. The four existing aliases (`cluster_a`, `cluster_b`, `cluster_c`, `cluster_d`) can serve as templates.

### 4. Deploy

```bash
tofu init
tofu plan  -var-file=secrets.tfvars
tofu apply -var-file=secrets.tfvars
```

### 5. Access the cluster

```bash
export TALOSCONFIG=$(pwd)/talosconfig
export KUBECONFIG=$(pwd)/kubeconfig

talosctl health
kubectl get nodes -o wide
```

## Project Structure

```
.
├── versions.tf           # OpenTofu version + required_providers
├── providers.tf          # All provider configurations (proxmox, talos, helm, kubectl)
├── variables.tf          # Input variable declarations
├── locals.tf             # Computed locals (node partitioning, IP lists, ISO URL)
├── main.tf               # Proxmox VM module instances (one per cluster)
├── talos.tf              # Talos lifecycle: secrets, config, bootstrap, upgrade, kubeconfig
├── helm.tf               # Cilium (inline manifest) + post-bootstrap Helm releases
├── kubernetes.tf         # kubectl manifests (Cilium CRDs, ArgoCD projects/apps)
├── outputs.tf            # Cluster endpoints, configs, ArgoCD password command
│
├── terraform.tfvars      # Proxmox clusters + cluster identity + versions  [auto-loaded]
├── nodes.auto.tfvars     # Node inventory + VM sizing                       [auto-loaded]
├── helm.auto.tfvars      # Helm chart versions + releases                   [auto-loaded]
├── argocd.auto.tfvars    # ArgoCD application catalog                       [auto-loaded]
├── secrets.tfvars        # API tokens + deploy tokens  (gitignored)         [-var-file]
│
├── helm/
│   ├── cilium/values.yaml        # Cilium Helm values (BGP, Hubble, kube-proxy replacement)
│   └── argocd/values.yaml        # ArgoCD Helm values (HA, Traefik ingress, KSOPS)
│
├── patches/                      # Talos machine config patches (YAML, templated)
│   ├── common.yaml.tftpl         # All nodes: install, KubeSpan, cluster network, CNI=none
│   ├── control-plane.yaml.tftpl  # CP nodes: Cilium inline manifest, node labels, iSCSI NIC
│   ├── worker.yaml.tftpl         # Worker nodes: Longhorn mounts, UserVolumeConfig, iSCSI NIC
│   ├── trusted-roots.yaml        # Custom CA certificate injection
│   └── trusted-roots.yaml.example  # Example/template for trusted-roots.yaml
│
├── manifests/                    # Raw Kubernetes manifests applied via kubectl_manifest
│   ├── cilium-lb-ippool.yaml.tftpl      # CiliumLoadBalancerIPPool
│   ├── cilium-BGPpeering.yaml.tftpl     # CiliumBGPPeeringPolicy
│   ├── cilium-L2annouce.yaml.tftpl      # CiliumL2AnnouncementPolicy
│   ├── argocd-project-infra.yaml.tftpl  # ArgoCD AppProject: infrastructure workloads
│   ├── argocd-project-apps.yaml.tftpl   # ArgoCD AppProject: application workloads
│   ├── argocd-repo-secret.yaml.tftpl    # ArgoCD repository credentials (templated)
│   └── certmanager-dns-resolver-do.yaml # cert-manager DNS01 webhook (Domain Offensive)
│
└── modules/
    ├── proxmox-nodes/    # Creates Proxmox VMs: downloads ISO, provisions VMs per node map
    ├── helm-releases/    # Deploys Helm charts from the helm_releases variable map
    └── argocd-applications/  # Creates ArgoCD Application CRs from the argocd_applications map
```

## Configuration Files

| File                 | Purpose                                                              | Auto-loaded? |
| -------------------- | -------------------------------------------------------------------- | :----------: |
| `terraform.tfvars`   | Proxmox cluster endpoints, cluster name/endpoint, Talos/K8s versions |     Yes      |
| `nodes.auto.tfvars`  | Node inventory (all VMs across all sites) and default sizing         |     Yes      |
| `helm.auto.tfvars`   | Cilium chart version, post-bootstrap Helm releases                   |     Yes      |
| `argocd.auto.tfvars` | ArgoCD application catalog and repo username                         |     Yes      |
| `secrets.tfvars`     | Proxmox API tokens, ArgoCD deploy token (**gitignored**)             | `-var-file`  |

Each has a matching `.example` file.

## Operational Tasks

### Add a Proxmox cluster

1. Copy a `provider "proxmox"` block in `providers.tf`, change `alias` to the new cluster key (e.g. `cluster_e`)
2. Copy a `module "proxmox_<key>"` block in `main.tf`, change suffix and alias to match
3. Add `module.proxmox_<key>.vm_ips` to the `merge()` in `main.tf`
4. Add an entry to `proxmox_clusters` in `terraform.tfvars`
5. Add credentials to `secrets.tfvars` under `proxmox_cluster_credentials`
6. Add nodes with `proxmox_cluster = "<key>"` in `nodes.auto.tfvars`

`locals.tf`, `variables.tf`, and `talos.tf` need no changes.

Current sites: `cluster_a` (cluster_a-PVE), `cluster_b` (cluster_b-PVE), `cluster_c` (cluster_c-PVE), `cluster_d` (cluster_d-PVE)

### Add or remove nodes

Edit `nodes.auto.tfvars`, then:

```bash
tofu plan  -var-file=secrets.tfvars
tofu apply -var-file=secrets.tfvars
```

### Upgrade Talos or Kubernetes

Change `talos_version` or `kubernetes_version` in `terraform.tfvars`, then apply.
The `null_resource.upgrade_*` provisioners perform rolling `talosctl upgrade` runs automatically.

### Add an ArgoCD application

Add an entry to `argocd_applications` in `argocd.auto.tfvars`. Available fields:

```hcl
my-app = {
  project           = "apps"           # default: "apps"
  repo_url          = "https://..."    # required
  target_revision   = "main"           # default: "HEAD"
  path              = "apps/my-app"    # required
  destination_ns    = "my-app"         # required
  create_namespace  = true             # default: true
  server_side_apply = false            # default: false
  auto_prune        = true             # default: true
  self_heal         = true             # default: true
}
```

### Deploy additional Helm charts via OpenTofu

Add entries to `helm_releases` in `helm.auto.tfvars`. Values files are read from
`helm/<release-name>/values.yaml` automatically.

## Design Decisions

**Why Talos?** Immutable, minimal OS purpose-built for Kubernetes. No SSH, no package manager,
no shell by default — dramatically reduced attack surface and operational overhead.

**Why Cilium as inline manifest?** Cilium is injected into the Talos machine config before
cluster bootstrap so CNI is available the moment the first node starts. This avoids a
chicken-and-egg problem where pods can't schedule without CNI but CNI can't deploy without pods.

**Why a flat node map?** A single `nodes` variable spanning all Proxmox clusters keeps the
inventory in one place, making it easy to see the full cluster topology at a glance. OpenTofu
partitions it by `proxmox_cluster` internally in `locals.tf`.

**Why split tfvars?** The original single `terraform.tfvars` grew to 16KB. Splitting by domain
(infrastructure, inventory, helm, argocd) makes each file focused and diff-friendly — adding
an ArgoCD app no longer pollutes the same file as node changes.

## See Also

- [MIGRATION.md](MIGRATION.md) — how this cluster was originally imported from a single-cluster layout
- [Talos docs](https://talos.dev/docs) — machine configuration reference
- [bpg/proxmox provider](https://registry.opentofu.org/providers/bpg/proxmox/latest/docs)
- [siderolabs/talos provider](https://registry.opentofu.org/providers/siderolabs/talos/latest/docs)
