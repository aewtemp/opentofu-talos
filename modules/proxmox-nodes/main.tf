data "proxmox_virtual_environment_nodes" "available" {}

locals {
  # Online PVE hosts in the cluster, sorted for deterministic round-robin
  online_nodes = sort([
    for i, name in data.proxmox_virtual_environment_nodes.available.names :
    name if data.proxmox_virtual_environment_nodes.available.online[i]
  ])

  # Node name lists by role, sorted for stable index-based assignment
  cp_names     = sort([for name, node in var.nodes : name if node.role == "controlplane"])
  worker_names = sort([for name, node in var.nodes : name if node.role == "worker"])

  # Round-robin assignment: CP and workers distributed independently.
  # Explicit proxmox_host overrides auto-assignment (kept for host-pinned nodes).
  cp_assignments = {
    for i, name in local.cp_names :
    name => coalesce(var.nodes[name].proxmox_host, local.online_nodes[i % length(local.online_nodes)])
  }
  worker_assignments = {
    for i, name in local.worker_names :
    name => coalesce(var.nodes[name].proxmox_host, local.online_nodes[i % length(local.online_nodes)])
  }

  node_assignments = merge(local.cp_assignments, local.worker_assignments)

  # Only download the ISO to PVE hosts that will actually receive VMs
  used_hosts = toset(values(local.node_assignments))

  # Shared storage: download once to the first online node.
  # Local storage: download to every host that has VMs.
  iso_download_targets = var.iso_storage_shared ? { shared = local.online_nodes[0] } : { for h in local.used_hosts : h => h }

  # Key into iso_download_targets for each VM's cdrom reference
  iso_key_for_node = var.iso_storage_shared ? { for name in keys(var.nodes) : name => "shared" } : local.node_assignments

  # Resolved storage pools: per-node override > host_config > cluster default
  resolved_storage = {
    for name, node in var.nodes : name => {
      storage_pool = (
        node.storage_pool != null
        ? node.storage_pool
        : try(var.host_config[local.node_assignments[name]].storage_pool,
            var.default_storage_pool)
      )
      longhorn_storage_pool = (
        node.longhorn_storage_pool != null
        ? node.longhorn_storage_pool
        : try(var.host_config[local.node_assignments[name]].longhorn_storage_pool,
            var.default_longhorn_storage_pool)
      )
    }
  }
}

resource "proxmox_virtual_environment_download_file" "talos_iso" {
  for_each = local.iso_download_targets

  content_type = "iso"
  datastore_id = var.iso_storage_pool
  node_name    = each.value
  url          = var.talos_iso_url
  file_name    = var.talos_iso_filename
}

resource "proxmox_virtual_environment_vm" "node" {
  for_each = var.nodes

  name      = each.key
  node_name = local.node_assignments[each.key]
  tags      = each.value.role == "controlplane" ? ["kubernetes", "control"] : ["kubernetes", "worker"]

  vm_id       = each.value.vmid
  description = "Talos Kubernetes ${each.value.role == "controlplane" ? "Control Plane" : "Worker"} Node"
  on_boot     = true

  keyboard_layout = "de"

  startup {
    order      = each.value.role == "controlplane" ? "4" : "5"
    up_delay   = "30"
    down_delay = "30"
  }

  agent {
    enabled = true
    type    = "virtio"
  }

  machine = "q35"
  operating_system {
    type = "l26"
  }

  cpu {
    cores   = coalesce(each.value.cores, each.value.role == "controlplane" ? var.control_plane_defaults.cores : var.worker_defaults.cores)
    sockets = coalesce(each.value.sockets, each.value.role == "controlplane" ? var.control_plane_defaults.sockets : var.worker_defaults.sockets)
    type    = each.value.cpu_type
    flags   = ["+aes"]
  }

  memory {
    dedicated = coalesce(each.value.memory, each.value.role == "controlplane" ? var.control_plane_defaults.memory : var.worker_defaults.memory)
  }

  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0", "ide2"]

  # Primary network (Kubernetes traffic)
  network_device {
    model       = "virtio"
    bridge      = each.value.network_bridge
    vlan_id     = each.value.network_vlan
    firewall    = false
    mac_address = each.value.mac_address
  }

  # Optional secondary network (iSCSI traffic)
  dynamic "network_device" {
    for_each = each.value.iscsi_bridge != null ? [each.value.iscsi_bridge] : []
    content {
      model    = "virtio"
      bridge   = network_device.value
      firewall = false
    }
  }

  # System disk
  disk {
    interface    = "scsi0"
    datastore_id = local.resolved_storage[each.key].storage_pool
    size         = coalesce(each.value.disk_size, each.value.role == "controlplane" ? var.control_plane_defaults.disk_size : var.worker_defaults.disk_size)
    aio          = "threads"
    iothread     = true
    ssd          = true
    discard      = "on"
    backup       = true
    replicate    = false
  }

  # Optional Longhorn disk (workers only, when longhorn_storage_pool is resolved)
  dynamic "disk" {
    for_each = each.value.role == "worker" && local.resolved_storage[each.key].longhorn_storage_pool != null ? [local.resolved_storage[each.key].longhorn_storage_pool] : []
    content {
      interface    = "scsi1"
      datastore_id = disk.value
      size         = coalesce(each.value.disk_size_longhorn, var.worker_defaults.disk_size_longhorn)
      aio          = "threads"
      iothread     = true
      ssd          = true
      discard      = "on"
      backup       = false
      replicate    = false
    }
  }

  # Talos ISO — one download per host (local storage) or one shared download
  cdrom {
    interface = "ide2"
    file_id   = proxmox_virtual_environment_download_file.talos_iso[local.iso_key_for_node[each.key]].id
  }

  lifecycle {
    ignore_changes = [
      node_name, # prevents reshuffling when PVE hosts are added/removed
      network_device,
      description,
      boot_order,
    ]
  }
}
