# Requires Cilium CRDs — applied via kubectl_manifest so plan succeeds before CRDs exist
resource "kubectl_manifest" "cilium_lb_ippool" {
  yaml_body = templatefile("${path.module}/manifests/cilium-lb-ippool.yaml.tftpl", {
    name                = var.cilium_lb_pool.name
    cidr                = var.cilium_lb_pool.cidr
    allow_first_last_ip = var.cilium_lb_pool.allow_first_last_ip
    service_selector    = var.cilium_lb_pool.service_selector
  })

  depends_on = [data.talos_cluster_health.health]
}

resource "kubectl_manifest" "cilium_bgp_peering" {
  yaml_body = templatefile("${path.module}/manifests/cilium-BGPpeering.yaml.tftpl", {
    local_asn             = var.cilium_bgp_peering.local_asn
    peer_asn              = var.cilium_bgp_peering.peer_asn
    peer_address          = var.cilium_bgp_peering.peer_address
    connect_retry_seconds = var.cilium_bgp_peering.connect_retry_seconds
    hold_time_seconds     = var.cilium_bgp_peering.hold_time_seconds
    keepalive_seconds     = var.cilium_bgp_peering.keepalive_seconds
    service_selector      = var.cilium_bgp_peering.service_selector
  })

  depends_on = [data.talos_cluster_health.health]
}

resource "kubectl_manifest" "cilium_l2_announce" {
  yaml_body = templatefile("${path.module}/manifests/cilium-L2annouce.yaml.tftpl", {
    interface_regex  = var.cilium_l2_announce.interface_regex
    service_selector = var.cilium_l2_announce.service_selector
  })

  depends_on = [data.talos_cluster_health.health]
}


# ---------------------------------------------------------------------------
# ArgoCD: config, repository secret, projects
# ---------------------------------------------------------------------------

resource "kubectl_manifest" "argocd_repo_secret" {
  for_each = var.argocd_repo_secrets

  yaml_body = templatefile("${path.module}/manifests/argocd-repo-secret.yaml.tftpl", {
    repo_name     = each.key
    repo_url      = each.value.url
    repo_username = each.value.username
    repo_token    = var.argocd_repo_tokens[each.key]
  })
  sensitive_fields = ["data"]

  depends_on = [module.helm_releases]
}

resource "kubectl_manifest" "argocd_project_infra" {
  yaml_body = templatefile("${path.module}/manifests/argocd-project-infra.yaml.tftpl", {
    source_repos = [for v in var.argocd_repo_secrets : v.url]
  })

  depends_on = [module.helm_releases]
}

resource "kubectl_manifest" "argocd_project_apps" {
  yaml_body = templatefile("${path.module}/manifests/argocd-project-apps.yaml.tftpl", {
    source_repos = [for v in var.argocd_repo_secrets : v.url]
  })

  depends_on = [module.helm_releases]
}


# ---------------------------------------------------------------------------
# ArgoCD: applications (variable-driven)
# ---------------------------------------------------------------------------

locals {
  # Resolve repo_url: when repo_secret is set, look up the URL from argocd_repo_secrets.
  argocd_applications_resolved = {
    for k, v in var.argocd_applications : k => merge(v, {
      repo_url = v.repo_secret != "" ? var.argocd_repo_secrets[v.repo_secret].url : v.repo_url
    })
  }
}

module "argocd_applications" {
  source              = "./modules/argocd-applications"
  argocd_applications = local.argocd_applications_resolved

  depends_on = [module.helm_releases]
}
