output "namespace" {
  description = "Namespace the monitoring stack runs in."
  value       = kubernetes_namespace_v1.monitoring.metadata[0].name
}

output "release_name" {
  description = "Helm release name of kube-prometheus-stack (also its fullnameOverride)."
  value       = helm_release.kube_prometheus_stack.name
}

output "grafana_service" {
  description = "In-cluster Grafana service name."
  value       = "${local.release_name}-grafana"
}

output "prometheus_service" {
  description = "In-cluster Prometheus service name."
  value       = "${local.release_name}-prometheus"
}

output "chart_versions" {
  description = "Chart versions actually deployed."
  value = {
    kube_prometheus_stack = helm_release.kube_prometheus_stack.version
    metrics_server        = one(helm_release.metrics_server[*].version)
  }
}
