data "proxmox_virtual_environment_nodes" "available" {}

locals {
  online_nodes = sort([
    for i, name in data.proxmox_virtual_environment_nodes.available.names :
    name if data.proxmox_virtual_environment_nodes.available.online[i]
  ])
}

# Set the timezone on every online PVE host in the cluster
resource "proxmox_virtual_environment_time" "node" {
  for_each = var.time_zone != null ? toset(local.online_nodes) : toset([])

  node_name = each.value
  time_zone = var.time_zone
}

# Manage datacenter-level cluster options (one per Proxmox cluster)
resource "proxmox_virtual_environment_cluster_options" "this" {
  count = var.cluster_options != null ? 1 : 0

  language                  = var.cluster_options.language
  keyboard                  = var.cluster_options.keyboard
  email_from                = var.cluster_options.email_from
  max_workers               = var.cluster_options.max_workers
  bandwidth_limit_default   = var.cluster_options.bandwidth_limit_default
  bandwidth_limit_clone     = var.cluster_options.bandwidth_limit_clone
  bandwidth_limit_migration = var.cluster_options.bandwidth_limit_migration
  bandwidth_limit_move      = var.cluster_options.bandwidth_limit_move
  bandwidth_limit_restore   = var.cluster_options.bandwidth_limit_restore
  migration_cidr            = var.cluster_options.migration_cidr
  migration_type            = var.cluster_options.migration_type
  next_id                   = var.cluster_options.next_id
  notify                    = var.cluster_options.notify
}
