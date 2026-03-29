# One pair of module blocks per Proxmox cluster — copy/change suffix and alias to add a new cluster.

module "proxmox_cluster_config_a" { # cluster_a: Proxmox Clustername
  source    = "./modules/proxmox-cluster-config"
  providers = { proxmox = proxmox.cluster_a }

  time_zone       = var.proxmox_clusters["cluster_a"].time_zone
  cluster_options = var.proxmox_clusters["cluster_a"].cluster_options
}

module "proxmox_cluster_config_b" { # cluster_b: Proxmox Clustername
  source    = "./modules/proxmox-cluster-config"
  providers = { proxmox = proxmox.cluster_b }

  time_zone       = var.proxmox_clusters["cluster_b"].time_zone
  cluster_options = var.proxmox_clusters["cluster_b"].cluster_options
}

module "proxmox_cluster_config_c" { # cluster_c: Proxmox Clustername
  source    = "./modules/proxmox-cluster-config"
  providers = { proxmox = proxmox.cluster_c }

  time_zone       = var.proxmox_clusters["cluster_c"].time_zone
  cluster_options = var.proxmox_clusters["cluster_c"].cluster_options
}

module "proxmox_cluster_config_d" { # cluster_d: Proxmox Clustername
  source    = "./modules/proxmox-cluster-config"
  providers = { proxmox = proxmox.cluster_d }

  time_zone       = var.proxmox_clusters["cluster_d"].time_zone
  cluster_options = var.proxmox_clusters["cluster_d"].cluster_options
}



module "proxmox_cluster_a" { # cluster_a: Proxmox Clustername
  source    = "./modules/proxmox-nodes"
  providers = { proxmox = proxmox.cluster_a }

  nodes                         = local.nodes_by_proxmox_cluster["cluster_a"]
  host_config                   = var.proxmox_clusters["cluster_a"].host_config
  default_storage_pool          = var.proxmox_clusters["cluster_a"].default_storage_pool
  default_longhorn_storage_pool = var.proxmox_clusters["cluster_a"].default_longhorn_storage_pool
  control_plane_defaults        = var.control_plane_defaults
  worker_defaults               = var.worker_defaults
  iso_storage_pool              = var.proxmox_clusters["cluster_a"].iso_storage_pool
  iso_storage_shared            = var.proxmox_clusters["cluster_a"].iso_storage_shared
  talos_iso_url                 = local.talos_iso_url
  talos_iso_filename            = local.talos_iso_filename
}

module "proxmox_cluster_b" { # cluster_b: Proxmox Clustername
  source    = "./modules/proxmox-nodes"
  providers = { proxmox = proxmox.cluster_b }

  nodes                         = local.nodes_by_proxmox_cluster["cluster_b"]
  host_config                   = var.proxmox_clusters["cluster_b"].host_config
  default_storage_pool          = var.proxmox_clusters["cluster_b"].default_storage_pool
  default_longhorn_storage_pool = var.proxmox_clusters["cluster_b"].default_longhorn_storage_pool
  control_plane_defaults        = var.control_plane_defaults
  worker_defaults               = var.worker_defaults
  iso_storage_pool              = var.proxmox_clusters["cluster_b"].iso_storage_pool
  iso_storage_shared            = var.proxmox_clusters["cluster_b"].iso_storage_shared
  talos_iso_url                 = local.talos_iso_url
  talos_iso_filename            = local.talos_iso_filename
}

module "proxmox_cluster_c" { # cluster_c: Proxmox Clustername
  source    = "./modules/proxmox-nodes"
  providers = { proxmox = proxmox.cluster_c }

  nodes                         = local.nodes_by_proxmox_cluster["cluster_c"]
  host_config                   = var.proxmox_clusters["cluster_c"].host_config
  default_storage_pool          = var.proxmox_clusters["cluster_c"].default_storage_pool
  default_longhorn_storage_pool = var.proxmox_clusters["cluster_c"].default_longhorn_storage_pool
  control_plane_defaults        = var.control_plane_defaults
  worker_defaults               = var.worker_defaults
  iso_storage_pool              = var.proxmox_clusters["cluster_c"].iso_storage_pool
  iso_storage_shared            = var.proxmox_clusters["cluster_c"].iso_storage_shared
  talos_iso_url                 = local.talos_iso_url
  talos_iso_filename            = local.talos_iso_filename
}

module "proxmox_cluster_d" { # cluster_d: Proxmox Clustername
  source    = "./modules/proxmox-nodes"
  providers = { proxmox = proxmox.cluster_d }

  nodes                         = local.nodes_by_proxmox_cluster["cluster_d"]
  host_config                   = var.proxmox_clusters["cluster_d"].host_config
  default_storage_pool          = var.proxmox_clusters["cluster_d"].default_storage_pool
  default_longhorn_storage_pool = var.proxmox_clusters["cluster_d"].default_longhorn_storage_pool
  control_plane_defaults        = var.control_plane_defaults
  worker_defaults               = var.worker_defaults
  iso_storage_pool              = var.proxmox_clusters["cluster_d"].iso_storage_pool
  iso_storage_shared            = var.proxmox_clusters["cluster_d"].iso_storage_shared
  talos_iso_url                 = local.talos_iso_url
  talos_iso_filename            = local.talos_iso_filename
}

locals {
  # Add module.<name>.vm_ips and module.<name>.node_hosts here for each new cluster.
  all_vm_ips = merge(
    module.proxmox_cluster_a.vm_ips,
    module.proxmox_cluster_b.vm_ips,
    module.proxmox_cluster_c.vm_ips,
    module.proxmox_cluster_d.vm_ips,
  )

  all_node_hosts = merge(
    module.proxmox_cluster_a.node_hosts,
    module.proxmox_cluster_b.node_hosts,
    module.proxmox_cluster_c.node_hosts,
    module.proxmox_cluster_d.node_hosts,
  )

  control_plane_ips = compact([for name in local.cp_node_names : lookup(local.all_vm_ips, name, "")])
  worker_ips        = compact([for name in local.worker_node_names : lookup(local.all_vm_ips, name, "")])
  all_node_ips      = compact([for name in concat(local.cp_node_names, local.worker_node_names) : lookup(local.all_vm_ips, name, "")])
}
