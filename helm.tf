# Cilium is rendered locally at plan time and embedded as a Talos inline manifest.
# This ensures CNI is available before any workload is scheduled.
data "helm_template" "cilium" {
  provider     = helm.local
  name         = "cilium"
  repository   = var.cilium_chart_repository
  chart        = "cilium"
  version      = var.cilium_chart_version
  namespace    = "kube-system"
  kube_version = var.kubernetes_version
  values       = [file("${path.module}/helm/cilium/values.yaml")]
}

# Wait for all nodes to pass Talos and Kubernetes health checks before deploying workloads.
data "talos_cluster_health" "health" {
  depends_on = [
    talos_machine_configuration_apply.control_plane,
    talos_machine_configuration_apply.worker,
  ]

  client_configuration = talos_machine_secrets.cluster_secrets.client_configuration
  endpoints            = local.control_plane_ips
  control_plane_nodes  = local.control_plane_ips
  worker_nodes         = local.worker_ips

  timeouts = {
    read = "10m"
  }
}

module "helm_releases" {
  source           = "./modules/helm-releases"
  helm_releases    = var.helm_releases
  values_base_path = "${path.module}/helm"

  values_template_vars = {
    argocd = {
      argocd_domain        = var.argocd_domain
      argocd_trusted_certs = var.argocd_trusted_certs
    }
  }

  depends_on = [
    data.talos_cluster_health.health,
    talos_cluster_kubeconfig.kubeconfig,
  ]
}
