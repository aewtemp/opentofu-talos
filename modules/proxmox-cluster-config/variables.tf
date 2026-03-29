variable "time_zone" {
  description = "IANA timezone to apply to every online PVE host (e.g. \"Europe/Berlin\", \"UTC\"). Null = skip time management."
  type        = string
  default     = null
}

variable "cluster_options" {
  description = "Proxmox datacenter-level cluster options. Null = skip cluster options management."
  type = object({
    language                   = optional(string)
    keyboard                   = optional(string)
    email_from                 = optional(string)
    max_workers                = optional(number)
    bandwidth_limit_default    = optional(number)
    bandwidth_limit_clone      = optional(number)
    bandwidth_limit_migration  = optional(number)
    bandwidth_limit_move       = optional(number)
    bandwidth_limit_restore    = optional(number)
    migration_cidr             = optional(string)
    migration_type             = optional(string) # "secure" or "insecure"
    next_id = optional(object({
      lower = optional(number)
      upper = optional(number)
    }))
    notify = optional(object({
      ha_fencing_mode            = optional(string)
      ha_fencing_target          = optional(string)
      package_updates            = optional(string)
      package_updates_target     = optional(string)
      package_replication        = optional(string)
      package_replication_target = optional(string)
    }))
  })
  default = null
}
