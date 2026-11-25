variable "name" {
  description = "Cluster name. Also used as the kubeconfig context suffix (kind-<name>)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]{0,30}[a-z0-9])?$", var.name))
    error_message = "name must be a lowercase DNS label of at most 32 characters."
  }
}

variable "node_image" {
  description = "kindest/node image (pin by digest for reproducible clusters)."
  type        = string
  default     = "kindest/node:v1.36.4@sha256:099e049362a1526b2db71494e1947aae99bd16290d7c895f2b7ea312e3cbfaed"
}

variable "worker_count" {
  description = "Number of worker nodes in addition to the control plane."
  type        = number
  default     = 2

  validation {
    condition     = var.worker_count >= 0 && var.worker_count <= 10 && floor(var.worker_count) == var.worker_count
    error_message = "worker_count must be an integer between 0 and 10."
  }
}

variable "port_mappings" {
  description = "Host ports mapped to NodePorts on the control-plane node, e.g. for Grafana and Prometheus."
  type = list(object({
    container_port = number
    host_port      = number
    listen_address = optional(string, "127.0.0.1")
    protocol       = optional(string, "TCP")
  }))
  default = []

  validation {
    condition     = alltrue([for m in var.port_mappings : m.container_port >= 30000 && m.container_port <= 32767])
    error_message = "container_port must be in the default NodePort range (30000-32767)."
  }

  validation {
    condition     = length(distinct([for m in var.port_mappings : m.host_port])) == length(var.port_mappings)
    error_message = "host_port values must be unique."
  }
}

variable "kubeconfig_path" {
  description = "Where to write the kubeconfig. null lets the provider choose its default."
  type        = string
  default     = null
}
