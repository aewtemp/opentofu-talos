variable "argocd_applications" {
  description = "Map of ArgoCD Application resources to deploy"
  type = map(object({
    enabled           = optional(bool, true)
    project           = optional(string, "apps")
    repo_url          = string
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
