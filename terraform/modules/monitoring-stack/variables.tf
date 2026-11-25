variable "namespace" {
  description = "Namespace for the monitoring stack."
  type        = string
  default     = "monitoring"
}

variable "kube_prometheus_stack_version" {
  description = "Version of the prometheus-community/kube-prometheus-stack chart."
  type        = string
  default     = "93.11.0"
}

variable "grafana_admin_password" {
  description = "Grafana admin password. Passed with set_sensitive so it never appears in plan output."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.grafana_admin_password) >= 12
    error_message = "grafana_admin_password must be at least 12 characters."
  }
}

variable "grafana_node_port" {
  description = "NodePort for Grafana. null keeps the service as ClusterIP (use port-forward)."
  type        = number
  default     = null
}

variable "prometheus_node_port" {
  description = "NodePort for Prometheus. null keeps the service as ClusterIP (use port-forward)."
  type        = number
  default     = null
}

variable "prometheus_retention" {
  description = "How long Prometheus keeps samples."
  type        = string
  default     = "24h"

  validation {
    condition     = can(regex("^[0-9]+(ms|s|m|h|d|w|y)$", var.prometheus_retention))
    error_message = "prometheus_retention must be a Prometheus duration such as 24h or 7d."
  }
}

variable "scrape_interval" {
  description = "Default Prometheus scrape interval."
  type        = string
  default     = "15s"
}

variable "disable_control_plane_scrapes" {
  description = "Skip etcd/scheduler/controller-manager/kube-proxy targets, which are not reachable on kind and managed clusters."
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Install metrics-server so HorizontalPodAutoscalers and `kubectl top` work."
  type        = bool
  default     = true
}

variable "metrics_server_version" {
  description = "Version of the kubernetes-sigs/metrics-server chart."
  type        = string
  default     = "3.14.0"
}

variable "metrics_server_insecure_tls" {
  description = "Pass --kubelet-insecure-tls (required on kind, where kubelet certs are self-signed). Disable on real clusters."
  type        = bool
  default     = true
}
