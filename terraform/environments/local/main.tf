locals {
  grafana_node_port    = 30300
  prometheus_node_port = 30900
}

module "cluster" {
  source = "../../modules/kind-cluster"

  name            = var.cluster_name
  worker_count    = var.worker_count
  kubeconfig_path = abspath("${path.root}/kubeconfig")

  port_mappings = [
    { container_port = local.grafana_node_port, host_port = var.grafana_host_port },
    { container_port = local.prometheus_node_port, host_port = var.prometheus_host_port },
  ]
}

# Providers are configured from the cluster module's outputs, so a single
# `terraform apply` creates the cluster and then installs charts into it.
provider "kubernetes" {
  host                   = module.cluster.endpoint
  cluster_ca_certificate = module.cluster.cluster_ca_certificate
  client_certificate     = module.cluster.client_certificate
  client_key             = module.cluster.client_key
}

provider "helm" {
  kubernetes = {
    host                   = module.cluster.endpoint
    cluster_ca_certificate = module.cluster.cluster_ca_certificate
    client_certificate     = module.cluster.client_certificate
    client_key             = module.cluster.client_key
  }
}

resource "random_password" "grafana_admin" {
  length  = 24
  special = false
}

module "monitoring" {
  source = "../../modules/monitoring-stack"

  grafana_admin_password = random_password.grafana_admin.result
  grafana_node_port      = local.grafana_node_port
  prometheus_node_port   = local.prometheus_node_port
}
