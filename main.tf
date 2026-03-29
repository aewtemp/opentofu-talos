# One module block per Proxmox cluster — copy/change suffix and alias to add a new cluster.

module "proxmox_cluster_a" { # cluster_a: AV-PVE / va-pve02
  source    = "./modules/proxmox-nodes"
  providers = { proxmox = proxmox.cluster_a }

  nodes                  = local.nodes_by_proxmox_cluster["cluster_a"]
  control_plane_defaults = var.control_plane_defaults
  worker_defaults        = var.worker_defaults
  iso_storage_pool       = var.proxmox_clusters["cluster_a"].iso_storage_pool
  talos_iso_url          = local.talos_iso_url
  talos_iso_filename     = local.talos_iso_filename
}

module "proxmox_cluster_b" { # cluster_b: MP-PVE
  source    = "./modules/proxmox-nodes"
  providers = { proxmox = proxmox.cluster_b }

  nodes                  = local.nodes_by_proxmox_cluster["cluster_b"]
  control_plane_defaults = var.control_plane_defaults
  worker_defaults        = var.worker_defaults
  iso_storage_pool       = var.proxmox_clusters["cluster_b"].iso_storage_pool
  talos_iso_url          = local.talos_iso_url
  talos_iso_filename     = local.talos_iso_filename
}

module "proxmox_cluster_c" { # cluster_c: depve10
  source    = "./modules/proxmox-nodes"
  providers = { proxmox = proxmox.cluster_c }

  nodes                  = local.nodes_by_proxmox_cluster["cluster_c"]
  control_plane_defaults = var.control_plane_defaults
  worker_defaults        = var.worker_defaults
  iso_storage_pool       = var.proxmox_clusters["cluster_c"].iso_storage_pool
  talos_iso_url          = local.talos_iso_url
  talos_iso_filename     = local.talos_iso_filename
}

module "proxmox_cluster_d" { # cluster_d: depve20
  source    = "./modules/proxmox-nodes"
  providers = { proxmox = proxmox.cluster_d }

  nodes                  = local.nodes_by_proxmox_cluster["cluster_d"]
  control_plane_defaults = var.control_plane_defaults
  worker_defaults        = var.worker_defaults
  iso_storage_pool       = var.proxmox_clusters["cluster_d"].iso_storage_pool
  talos_iso_url          = local.talos_iso_url
  talos_iso_filename     = local.talos_iso_filename
}

locals {
  # Add module.<name>.vm_ips here for each new cluster.
  all_vm_ips = merge(
    module.proxmox_cluster_a.vm_ips,
    module.proxmox_cluster_b.vm_ips,
    module.proxmox_cluster_c.vm_ips,
    module.proxmox_cluster_d.vm_ips,
  )

  control_plane_ips = compact([for name in local.cp_node_names : lookup(local.all_vm_ips, name, "")])
  worker_ips        = compact([for name in local.worker_node_names : lookup(local.all_vm_ips, name, "")])
  all_node_ips      = compact([for name in concat(local.cp_node_names, local.worker_node_names) : lookup(local.all_vm_ips, name, "")])
}
