locals {
  enabled_releases = { for k, v in var.helm_releases : k => v if v.enabled }

  # Resolve the values file path for each release.
  # Explicit values_file takes precedence; otherwise fall back to the convention path.
  # Supports both plain .yaml and .yaml.tftpl — the .tftpl variant is used when
  # values_template_vars is provided for that release key.
  values_path = {
    for k, v in local.enabled_releases :
    k => coalesce(
      v.values_file,
      contains(keys(var.values_template_vars), k)
      ? "${var.values_base_path}/${k}/values.yaml.tftpl"
      : "${var.values_base_path}/${k}/values.yaml"
    )
  }
}

resource "helm_release" "this" {
  for_each = local.enabled_releases

  name             = each.key
  repository       = each.value.repository
  chart            = each.value.chart
  version          = each.value.version
  namespace        = each.value.namespace
  create_namespace = each.value.create_namespace

  values = concat(
    [
      contains(keys(var.values_template_vars), each.key)
      ? templatefile(local.values_path[each.key], var.values_template_vars[each.key])
      : file(local.values_path[each.key])
    ],
    each.value.extra_values
  )

  set = [
    for k, v in each.value.set : {
      name  = k
      value = v
    }
  ]

  wait    = true
  timeout = 600
}
