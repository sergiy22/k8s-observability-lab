output "name" {
  description = "Cluster name."
  value       = kind_cluster.this.name
}

output "context" {
  description = "kubectl context name for this cluster."
  value       = "kind-${kind_cluster.this.name}"
}

output "endpoint" {
  description = "Kubernetes API server endpoint."
  value       = kind_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "PEM-encoded cluster CA certificate."
  value       = kind_cluster.this.cluster_ca_certificate
}

output "client_certificate" {
  description = "PEM-encoded client certificate for the admin user."
  value       = kind_cluster.this.client_certificate
}

output "client_key" {
  description = "PEM-encoded client key for the admin user."
  value       = kind_cluster.this.client_key
  sensitive   = true
}

output "kubeconfig_path" {
  description = "Path of the kubeconfig file written for this cluster."
  value       = kind_cluster.this.kubeconfig_path
}
