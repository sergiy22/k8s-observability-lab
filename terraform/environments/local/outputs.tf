output "kubeconfig_path" {
  description = "export KUBECONFIG=<this> to use kubectl against the lab cluster."
  value       = module.cluster.kubeconfig_path
}

output "kube_context" {
  description = "kubectl context of the lab cluster."
  value       = module.cluster.context
}

output "grafana_url" {
  description = "Grafana UI (user: admin)."
  value       = "http://localhost:${var.grafana_host_port}"
}

output "prometheus_url" {
  description = "Prometheus UI."
  value       = "http://localhost:${var.prometheus_host_port}"
}

output "grafana_admin_password" {
  description = "Read with: terraform output -raw grafana_admin_password"
  value       = random_password.grafana_admin.result
  sensitive   = true
}

output "monitoring_namespace" {
  description = "Namespace of the monitoring stack."
  value       = module.monitoring.namespace
}
