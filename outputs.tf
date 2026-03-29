output "control_plane_ips" {
  description = "IP addresses of control plane nodes"
  value       = local.control_plane_ips
}

output "worker_ips" {
  description = "IP addresses of worker nodes"
  value       = compact([for name in local.worker_node_names : lookup(local.all_vm_ips, name, "")])
}

output "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  value       = "https://${var.cluster_endpoint}:6443"
}

output "talos_config" {
  description = "Talos client configuration"
  value       = data.talos_client_configuration.client_config.talos_config
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubernetes configuration"
  value       = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  sensitive   = true
}

output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = var.cluster_name
}

output "argocd_admin_password_command" {
  description = "Command to retrieve ArgoCD initial admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}
