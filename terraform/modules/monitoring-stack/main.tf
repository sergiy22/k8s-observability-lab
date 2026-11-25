locals {
  release_name = "kps"

  # Service exposure is optional: NodePort for local clusters, ClusterIP elsewhere.
  # merge() keeps nodePort a number; a plain conditional between two different
  # object shapes would be unified to map(string) and render nodePort as "30300".
  grafana_service = merge(
    { type = var.grafana_node_port == null ? "ClusterIP" : "NodePort" },
    var.grafana_node_port == null ? {} : { nodePort = var.grafana_node_port },
  )
  prometheus_service = merge(
    { type = var.prometheus_node_port == null ? "ClusterIP" : "NodePort" },
    var.prometheus_node_port == null ? {} : { nodePort = var.prometheus_node_port },
  )

  kube_prometheus_stack_values = {
    fullnameOverride = local.release_name

    grafana = {
      service                   = local.grafana_service
      defaultDashboardsTimezone = "browser"
      # Dashboards are shipped as labelled ConfigMaps next to the workloads they
      # describe (see k8s/base/grafana-dashboard.yaml) and picked up by the sidecar.
      sidecar = {
        dashboards = {
          enabled         = true
          label           = "grafana_dashboard"
          labelValue      = "1"
          searchNamespace = "ALL"
        }
      }
    }

    prometheus = {
      service = local.prometheus_service
      prometheusSpec = {
        retention      = var.prometheus_retention
        scrapeInterval = var.scrape_interval
        # Select ServiceMonitors/PodMonitors/PrometheusRules from every namespace,
        # not only those labelled with this Helm release.
        serviceMonitorSelectorNilUsesHelmValues = false
        podMonitorSelectorNilUsesHelmValues     = false
        ruleSelectorNilUsesHelmValues           = false
        resources = {
          requests = { cpu = "200m", memory = "512Mi" }
          limits   = { memory = "1Gi" }
        }
      }
    }

    alertmanager = {
      alertmanagerSpec = {
        resources = {
          requests = { cpu = "10m", memory = "64Mi" }
          limits   = { memory = "128Mi" }
        }
      }
    }

    kubeEtcd              = { enabled = !var.disable_control_plane_scrapes }
    kubeControllerManager = { enabled = !var.disable_control_plane_scrapes }
    kubeScheduler         = { enabled = !var.disable_control_plane_scrapes }
    kubeProxy             = { enabled = !var.disable_control_plane_scrapes }
  }

  metrics_server_values = {
    args = var.metrics_server_insecure_tls ? ["--kubelet-insecure-tls"] : []
  }
}

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by"       = "terraform"
      "pod-security.kubernetes.io/enforce" = "privileged" # node-exporter needs host access
    }
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = local.release_name
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_version

  values = [yamlencode(local.kube_prometheus_stack_values)]

  set_sensitive = [{
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }]

  atomic          = true
  cleanup_on_fail = true
  timeout         = 900
}

resource "helm_release" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0

  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_version

  values = [yamlencode(local.metrics_server_values)]

  atomic  = true
  timeout = 300
}
