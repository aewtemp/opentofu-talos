locals {
  # Merge non-sensitive cluster config with credentials from secrets.tfvars.
  # zone defaults to the map key when not explicitly set.
  proxmox_clusters = {
    for k, v in var.proxmox_clusters : k => merge(v, var.proxmox_cluster_credentials[k], {
      zone = v.zone != null ? v.zone : k
    })
  }

  # Partition all nodes by their proxmox_cluster key
  nodes_by_proxmox_cluster = {
    for cluster_key in keys(var.proxmox_clusters) :
    cluster_key => {
      for name, node in var.nodes :
      name => node
      if node.proxmox_cluster == cluster_key
    }
  }

  # Filter by role
  control_plane_nodes = { for name, node in var.nodes : name => node if node.role == "controlplane" }
  worker_nodes        = { for name, node in var.nodes : name => node if node.role == "worker" }

  # Sorted node name lists for stable ordering
  cp_node_names     = sort(keys(local.control_plane_nodes))
  worker_node_names = sort(keys(local.worker_nodes))

  # First CP node alphabetically used for bootstrap
  bootstrap_node = local.cp_node_names[0]

  # Cilium manifest content (rendered via helm_template in helm.tf)
  cilium_manifest = data.helm_template.cilium.manifest

  # Talos factory ISO download URL and filename
  talos_iso_url      = "https://factory.talos.dev/image/${talos_image_factory_schematic.this.id}/${var.talos_version}/nocloud-amd64.iso"
  talos_iso_filename = "talos-${var.talos_version}-${substr(talos_image_factory_schematic.this.id, 0, 8)}.iso"
}
