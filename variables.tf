variable "proxmox_clusters" {
  description = "Non-sensitive Proxmox cluster config keyed by alias (must match provider aliases in provider.tf)"
  type = map(object({
    api_url          = string
    tls_insecure     = bool
    iso_storage_pool   = optional(string, "local")
    iso_storage_shared = optional(bool, false) # true = shared datastore, download ISO once
    zone             = optional(string) # topology.kubernetes.io/zone label; defaults to the map key
    default_storage_pool          = optional(string) # cluster-wide storage pool fallback
    default_longhorn_storage_pool = optional(string) # cluster-wide Longhorn pool fallback
    host_config = optional(map(object({
      storage_pool          = string           # host-specific override (takes precedence over cluster default)
      longhorn_storage_pool = optional(string)
    })), {})
  }))
}

variable "proxmox_cluster_credentials" {
  description = "Credentials for each Proxmox cluster alias — keep in secrets.tfvars"
  type = map(object({
    api_token = string
    username  = optional(string)
    password  = optional(string)
  }))
  sensitive = true
}

variable "nodes" {
  description = "Flat map of all nodes across all Proxmox clusters, keyed by node name"
  type = map(object({
    role                  = string           # "controlplane" or "worker"
    proxmox_cluster       = string           # key into proxmox_clusters (must match a provider alias)
    proxmox_host          = optional(string) # PVE node name; null = auto-assigned via round-robin
    mac_address           = string
    ip_address_iscsi      = optional(string) # null = no iSCSI IP assignment
    vmid                  = optional(number)
    storage_pool          = optional(string) # null = resolved from proxmox_clusters[*].host_config
    longhorn_storage_pool = optional(string) # null = resolved from host_config (no disk if host has none)
    network_bridge        = string
    network_vlan          = optional(number)
    iscsi_bridge          = optional(string) # null = no second NIC
    cores                 = optional(number)
    sockets               = optional(number, 1)
    memory                = optional(number)
    disk_size             = optional(number)
    disk_size_longhorn    = optional(number)
    cpu_type              = optional(string, "x86-64-v3")
  }))
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
    cores     = 4
    sockets   = 1
    memory    = 3072
    disk_size = 24
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
    memory             = 5120
    disk_size          = 24
    disk_size_longhorn = 64
  }
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "talos-k8s"
}

variable "cluster_endpoint" {
  description = "Cluster endpoint IP or hostname (external LB or DNS name, without https:// and port)"
  type        = string
}

variable "talos_version" {
  description = "Talos version to deploy"
  type        = string
  default     = "v1.10.9"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.33.6"
}

variable "talos_extensions" {
  description = "List of Talos system extension names to include in the install image"
  type        = list(string)
  default     = []
}

variable "cilium_lb_pool" {
  description = "Cilium LoadBalancerIPPool settings"
  type = object({
    name                = optional(string, "cilium-bgp-pool")
    cidr                = string
    allow_first_last_ip = optional(string, "No")
    service_selector    = optional(string, "loadbalance: external")
  })
}

variable "cilium_bgp_peering" {
  description = "Cilium BGPPeeringPolicy virtualRouter settings"
  type = object({
    local_asn             = number
    peer_asn              = number
    peer_address          = string
    connect_retry_seconds = optional(number, 120)
    hold_time_seconds     = optional(number, 90)
    keepalive_seconds     = optional(number, 30)
    service_selector      = optional(string, "loadbalance: external")
  })
}

variable "cilium_l2_announce" {
  description = "Cilium L2AnnouncementPolicy settings"
  type = object({
    interface_regex  = optional(string, "^ens18$")
    service_selector = optional(string, "loadbalance: external")
  })
  default = {}
}

variable "cilium_chart_version" {
  description = "Cilium Helm chart version"
  type        = string
}

variable "cilium_chart_repository" {
  description = "Cilium Helm chart repository URL"
  type        = string
  default     = "https://helm.cilium.io/"
}

variable "argocd_repo_secrets" {
  description = "Map of ArgoCD repository configs to deploy as Kubernetes Secrets. Key becomes the Secret name suffix (argocd-repo-<key>). Tokens are in argocd_repo_tokens."
  type = map(object({
    url      = string
    username = string
  }))
  default = {}
}

variable "argocd_repo_tokens" {
  description = "Sensitive tokens for each argocd_repo_secrets entry — must have the same keys."
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "argocd_applications" {
  description = "Map of ArgoCD Application resources to deploy. Use repo_secret (key into argocd_repo_secrets) or repo_url directly."
  type = map(object({
    enabled           = optional(bool, true)
    project           = optional(string, "apps")
    repo_secret       = optional(string, "") # key into argocd_repo_secrets; takes precedence over repo_url
    repo_url          = optional(string, "") # used when repo_secret is not set
    target_revision   = optional(string, "HEAD")
    path              = string
    destination_ns    = string
    server            = optional(string, "https://kubernetes.default.svc")
    auto_prune        = optional(bool, true)
    self_heal         = optional(bool, true)
    create_namespace  = optional(bool, true)
    server_side_apply = optional(bool, false)
    sync_wave         = optional(string, "1")
  }))
  default = {}
}

variable "argocd_domain" {
  description = "FQDN for the ArgoCD server (used for global.domain and server.ingress.hostname)"
  type        = string
}

variable "argocd_trusted_certs" {
  description = "Map of hostname → PEM certificate added to ArgoCD configs.tls.certificates (e.g. internal CA certs)"
  type        = map(string)
  default     = {}
}

variable "helm_releases" {
  description = "Map of Helm releases to deploy post-bootstrap"
  type = map(object({
    repository       = string
    chart            = string
    version          = string
    namespace        = string
    create_namespace = optional(bool, true)
    enabled          = optional(bool, true)
    values_file      = optional(string)
    extra_values     = optional(list(string), [])
    set              = optional(map(string), {})
  }))
  default = {}
}
