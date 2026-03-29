locals {
  enabled_apps = { for k, v in var.argocd_applications : k => v if v.enabled }
}

resource "kubectl_manifest" "this" {
  for_each = local.enabled_apps

  yaml_body = templatefile("${path.module}/templates/application.yaml.tftpl", {
    name              = each.key
    project           = each.value.project
    repo_url          = each.value.repo_url
    target_revision   = each.value.target_revision
    path              = each.value.path
    destination_ns    = each.value.destination_ns
    server            = each.value.server
    auto_prune        = each.value.auto_prune
    self_heal         = each.value.self_heal
    create_namespace  = each.value.create_namespace
    server_side_apply = each.value.server_side_apply
    sync_wave         = each.value.sync_wave
  })
}
