variable "cluster_name" {
  description = "Name of the kind cluster."
  type        = string
  default     = "observability-lab"
}

variable "worker_count" {
  description = "Number of kind worker nodes."
  type        = number
  default     = 2
}

variable "grafana_host_port" {
  description = "Port on localhost that serves Grafana."
  type        = number
  default     = 3000
}

variable "prometheus_host_port" {
  description = "Port on localhost that serves Prometheus."
  type        = number
  default     = 9090
}
