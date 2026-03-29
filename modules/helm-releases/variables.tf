variable "helm_releases" {
  description = "Map of Helm releases to deploy"
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
}

variable "values_base_path" {
  description = "Base path to helm values files (convention: {base_path}/{key}/values.yaml)"
  type        = string
}

variable "values_template_vars" {
  description = "Template variables per release key. When provided, the values file is treated as a .tftpl template and rendered with templatefile()."
  type        = map(any)
  default     = {}
}
