resource "proxmox_virtual_environment_download_file" "talos_iso" {
  content_type = "iso"
  datastore_id = var.iso_storage_pool
  node_name    = values(var.nodes)[0].proxmox_host
  url          = var.talos_iso_url
  file_name    = var.talos_iso_filename
}

resource "proxmox_virtual_environment_vm" "node" {
  for_each = var.nodes

  name      = each.key
  node_name = each.value.proxmox_host
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
    datastore_id = each.value.storage_pool
    size         = coalesce(each.value.disk_size, each.value.role == "controlplane" ? var.control_plane_defaults.disk_size : var.worker_defaults.disk_size)
    aio          = "threads"
    iothread     = true
    ssd          = true
    discard      = "on"
    backup       = true
    replicate    = false
  }

  # Optional Longhorn disk (workers only, when longhorn_storage_pool is set)
  dynamic "disk" {
    for_each = each.value.role == "worker" && each.value.longhorn_storage_pool != null ? [each.value.longhorn_storage_pool] : []
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

  # Talos ISO (auto-downloaded from factory.talos.dev)
  cdrom {
    interface = "ide2"
    file_id   = proxmox_virtual_environment_download_file.talos_iso.id
  }

  lifecycle {
    ignore_changes = [
      network_device,
      description,
      boot_order,
    ]
  }
}
