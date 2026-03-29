# ── Proxmox providers (one static block per cluster) ─────────────────────────
# Aliases must match the keys in var.proxmox_clusters (terraform.tfvars).
# To add a new Proxmox cluster:
#   1. Copy a block below, change alias to the new cluster key
#   2. Copy the matching module block in main.tf with the same suffix
#   3. Add module.proxmox_<key>.vm_ips to the merge() in main.tf
#   4. Add entries to proxmox_clusters (terraform.tfvars) and
#      proxmox_cluster_credentials (secrets.tfvars)
# locals.tf, variables.tf, and talos.tf need no changes.
# ─────────────────────────────────────────────────────────────────────────────

provider "proxmox" {
  alias = "cluster_a" # First clustername and — IP

  endpoint  = local.proxmox_clusters["cluster_a"].api_url
  api_token = local.proxmox_clusters["cluster_a"].api_token
  insecure  = local.proxmox_clusters["cluster_a"].tls_insecure
}

provider "proxmox" {
  alias = "cluster_b" # Second clustername and — IP

  endpoint  = local.proxmox_clusters["cluster_b"].api_url
  api_token = local.proxmox_clusters["cluster_b"].api_token
  insecure  = local.proxmox_clusters["cluster_b"].tls_insecure
}

provider "proxmox" {
  alias = "cluster_c" # Thrid clustername and — IP

  endpoint  = local.proxmox_clusters["cluster_c"].api_url
  api_token = local.proxmox_clusters["cluster_c"].api_token
  insecure  = local.proxmox_clusters["cluster_c"].tls_insecure
}

provider "proxmox" {
  alias = "cluster_d" # Fourth clustername and — IP

  endpoint  = local.proxmox_clusters["cluster_d"].api_url
  api_token = local.proxmox_clusters["cluster_d"].api_token
  insecure  = local.proxmox_clusters["cluster_d"].tls_insecure
}

# ── Talos ─────────────────────────────────────────────────────────────────────

provider "talos" {}

# ── Helm ──────────────────────────────────────────────────────────────────────

# Alias used only for helm_template (local rendering, no cluster connection).
# A separate alias avoids a dependency cycle:
#   helm_template → kubeconfig → bootstrap → machine_config → cilium_manifest → helm_template
provider "helm" {
  alias = "local"
}

# Default provider — reads kubeconfig from the file written by local_file.kubeconfig.
# Using config_path (a static string) avoids "depends on values unknown until apply" errors.
provider "helm" {
  kubernetes = {
    config_path = "${path.module}/kubeconfig"
  }
}

# ── Kubectl ───────────────────────────────────────────────────────────────────

# Reads kubeconfig from the file written by local_file.kubeconfig.
provider "kubectl" {
  config_path = "${path.module}/kubeconfig"
}
