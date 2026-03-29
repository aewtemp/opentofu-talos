data "talos_image_factory_extensions_versions" "this" {
  talos_version = var.talos_version
  filters = {
    names = var.talos_extensions
  }
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode(
    {
      customization = {
        systemExtensions = {
          officialExtensions = data.talos_image_factory_extensions_versions.this.extensions_info[*].name
        }
      }
    }
  )
}

# Generate machine secrets for the Kubernetes cluster (single resource, one K8s cluster)
resource "talos_machine_secrets" "cluster_secrets" {
  talos_version = var.talos_version

  lifecycle {
    ignore_changes = [talos_version]
  }
}

# Generate Talos client configuration
data "talos_client_configuration" "client_config" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster_secrets.client_configuration

  endpoints = local.control_plane_ips
  nodes     = local.all_node_ips
}

# Generate machine configurations for control plane nodes
data "talos_machine_configuration" "control_plane" {
  for_each = local.control_plane_nodes

  cluster_name       = var.cluster_name
  machine_type       = "controlplane"
  cluster_endpoint   = "https://${var.cluster_endpoint}:6443"
  machine_secrets    = talos_machine_secrets.cluster_secrets.machine_secrets
  kubernetes_version = var.kubernetes_version
  talos_version      = var.talos_version

  config_patches = [
    templatefile("${path.module}/patches/common.yaml.tftpl", {
      talos_version      = var.talos_version
      talos_schematic_id = talos_image_factory_schematic.this.id
      cluster_endpoint   = var.cluster_endpoint
    }),
    templatefile("${path.module}/patches/control-plane.yaml.tftpl", {
      hostname        = each.key
      ip_iscsi        = each.value.ip_address_iscsi != null ? each.value.ip_address_iscsi : ""
      proxmox_cluster = local.proxmox_clusters[each.value.proxmox_cluster].zone
      proxmox_host    = each.value.proxmox_host
      cilium_manifest = local.cilium_manifest
    }),
    file("${path.module}/patches/trusted-roots.yaml"),
  ]
}

# Generate machine configurations for worker nodes
data "talos_machine_configuration" "worker" {
  for_each = local.worker_nodes

  cluster_name       = var.cluster_name
  machine_type       = "worker"
  cluster_endpoint   = "https://${var.cluster_endpoint}:6443"
  machine_secrets    = talos_machine_secrets.cluster_secrets.machine_secrets
  kubernetes_version = var.kubernetes_version
  talos_version      = var.talos_version

  config_patches = [
    templatefile("${path.module}/patches/common.yaml.tftpl", {
      talos_version      = var.talos_version
      talos_schematic_id = talos_image_factory_schematic.this.id
      cluster_endpoint   = var.cluster_endpoint
    }),
    templatefile("${path.module}/patches/worker.yaml.tftpl", {
      hostname        = each.key
      ip_iscsi        = each.value.ip_address_iscsi != null ? each.value.ip_address_iscsi : ""
      proxmox_cluster = local.proxmox_clusters[each.value.proxmox_cluster].zone
      proxmox_host    = each.value.proxmox_host
    }),
    file("${path.module}/patches/trusted-roots.yaml"),
  ]
}

# Apply configurations to control plane nodes
resource "talos_machine_configuration_apply" "control_plane" {
  for_each = local.control_plane_nodes

  depends_on = [null_resource.upgrade_control_plane]

  client_configuration        = talos_machine_secrets.cluster_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane[each.key].machine_configuration

  endpoint = lookup(local.all_vm_ips, each.key, "")
  node     = lookup(local.all_vm_ips, each.key, "")
}

# Bootstrap the Talos cluster (single bootstrap against the first CP node)
resource "talos_machine_bootstrap" "bootstrap" {
  depends_on = [
    talos_machine_configuration_apply.control_plane
  ]

  client_configuration = talos_machine_secrets.cluster_secrets.client_configuration

  endpoint = lookup(local.all_vm_ips, local.bootstrap_node, "")
  node     = lookup(local.all_vm_ips, local.bootstrap_node, "")
}

# Apply configurations to worker nodes (after bootstrap)
resource "talos_machine_configuration_apply" "worker" {
  for_each = local.worker_nodes

  depends_on = [
    talos_machine_bootstrap.bootstrap,
    null_resource.upgrade_worker,
  ]

  client_configuration        = talos_machine_secrets.cluster_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[each.key].machine_configuration

  endpoint = lookup(local.all_vm_ips, each.key, "")
  node     = lookup(local.all_vm_ips, each.key, "")
}

# Upgrade Talos OS on control plane nodes (before config apply)
resource "null_resource" "upgrade_control_plane" {
  for_each = local.control_plane_nodes

  depends_on = [local_file.talsconfig]

  triggers = {
    talos_version = var.talos_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      NODE_IP=${lookup(local.all_vm_ips, each.key, "")}
      CURRENT=$(talosctl version \
        --talosconfig ${path.module}/talosconfig \
        --nodes $NODE_IP \
        --short 2>/dev/null | grep 'Tag:' | tail -1 | awk '{print $NF}') || true

      if [ -z "$CURRENT" ] || [ "$CURRENT" = "${var.talos_version}" ]; then
        echo "Skipping upgrade (maintenance mode or already at ${var.talos_version})"
        exit 0
      fi

      talosctl upgrade \
        --talosconfig ${path.module}/talosconfig \
        --nodes $NODE_IP \
        --image factory.talos.dev/installer/${talos_image_factory_schematic.this.id}:${var.talos_version} \
        --preserve

      talosctl health \
        --talosconfig ${path.module}/talosconfig \
        --nodes $NODE_IP \
        --wait-timeout 10m
    EOT
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Upgrade Talos OS on worker nodes (after all CP nodes, before config apply)
resource "null_resource" "upgrade_worker" {
  for_each = local.worker_nodes

  depends_on = [null_resource.upgrade_control_plane]

  triggers = {
    talos_version = var.talos_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      NODE_IP=${lookup(local.all_vm_ips, each.key, "")}
      CURRENT=$(talosctl version \
        --talosconfig ${path.module}/talosconfig \
        --nodes $NODE_IP \
        --short 2>/dev/null | grep 'Tag:' | tail -1 | awk '{print $NF}') || true

      if [ -z "$CURRENT" ] || [ "$CURRENT" = "${var.talos_version}" ]; then
        echo "Skipping upgrade (maintenance mode or already at ${var.talos_version})"
        exit 0
      fi

      talosctl upgrade \
        --talosconfig ${path.module}/talosconfig \
        --nodes $NODE_IP \
        --image factory.talos.dev/installer/${talos_image_factory_schematic.this.id}:${var.talos_version} \
        --preserve

      talosctl health \
        --talosconfig ${path.module}/talosconfig \
        --nodes $NODE_IP \
        --wait-timeout 10m
    EOT
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Generate kubeconfig
resource "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on = [
    talos_machine_bootstrap.bootstrap
  ]

  client_configuration = talos_machine_secrets.cluster_secrets.client_configuration

  endpoint = lookup(local.all_vm_ips, local.bootstrap_node, "")
  node     = lookup(local.all_vm_ips, local.bootstrap_node, "")
}

# Write talosconfig to local file
resource "local_file" "talsconfig" {
  content  = data.talos_client_configuration.client_config.talos_config
  filename = "${path.module}/talosconfig"
}

# Write kubeconfig to local file
resource "local_file" "kubeconfig" {
  content  = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  filename = "${path.module}/kubeconfig"
}
