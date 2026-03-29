variable "nodes" {
  description = "Map of node objects keyed by node name"
  type = map(object({
    role                  = string
    proxmox_host          = optional(string) # null = auto-assign via round-robin
    mac_address           = string
    ip_address_iscsi      = optional(string)
    vmid                  = optional(number)
    storage_pool          = optional(string) # null = resolved from host_config
    longhorn_storage_pool = optional(string) # null = resolved from host_config
    network_bridge        = string
    network_vlan          = optional(number)
    iscsi_bridge          = optional(string)
    cores                 = optional(number)
    sockets               = optional(number, 1)
    memory                = optional(number)
    disk_size             = optional(number)
    disk_size_longhorn    = optional(number)
    cpu_type              = optional(string, "x86-64-v3")
  }))
  default = {}
}

variable "default_storage_pool" {
  description = "Cluster-wide fallback storage pool. Used when a node has no explicit storage_pool and no matching host_config entry."
  type        = string
  default     = null
}

variable "default_longhorn_storage_pool" {
  description = "Cluster-wide fallback Longhorn storage pool. Used when a node has no explicit longhorn_storage_pool and no matching host_config entry. Null = no Longhorn disk by default."
  type        = string
  default     = null
}

variable "host_config" {
  description = "Per-PVE-host defaults (storage pools). Keys are PVE host names within the cluster. Used for auto-assigned nodes that do not specify storage_pool / longhorn_storage_pool."
  type = map(object({
    storage_pool          = string
    longhorn_storage_pool = optional(string)
  }))
  default = {}
}

variable "iso_storage_pool" {
  description = "Proxmox storage pool to download the Talos ISO into"
  type        = string
  default     = "local"
}

variable "iso_storage_shared" {
  description = "Set to true when iso_storage_pool is a shared datastore (NFS, Ceph, etc.). The ISO is then downloaded exactly once to the first online node instead of once per used host, preventing duplicate/conflicting download tasks."
  type        = bool
  default     = false
}

variable "talos_iso_url" {
  description = "URL to download the Talos ISO from (factory.talos.dev)"
  type        = string
}

variable "talos_iso_filename" {
  description = "Filename for the downloaded ISO on Proxmox storage"
  type        = string
  default     = "talos-factory.iso"
}

variable "control_plane_defaults" {
  description = "Default sizing for control plane nodes"
  type = object({
    cores     = number
    sockets   = number
    memory    = number
    disk_size = number
  })
  default = {
    cores     = 2
    sockets   = 1
    memory    = 2048
    disk_size = 50
  }
}

variable "worker_defaults" {
  description = "Default sizing for worker nodes"
  type = object({
    cores              = number
    sockets            = number
    memory             = number
    disk_size          = number
    disk_size_longhorn = number
  })
  default = {
    cores              = 4
    sockets            = 1
    memory             = 4096
    disk_size          = 50
    disk_size_longhorn = 50
  }
}
