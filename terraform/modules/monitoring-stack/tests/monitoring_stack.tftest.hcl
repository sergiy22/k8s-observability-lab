# Unit tests: run with `terraform test` — no cluster required.
mock_provider "helm" {}
mock_provider "kubernetes" {}

variables {
  grafana_admin_password = "unit-test-password-123"
}

run "defaults_are_cluster_internal" {
  command = plan

  assert {
    condition     = yamldecode(helm_release.kube_prometheus_stack.values[0]).grafana.service.type == "ClusterIP"
    error_message = "Without a node port, Grafana must not be exposed."
  }

  assert {
    condition     = yamldecode(helm_release.kube_prometheus_stack.values[0]).prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues == false
    error_message = "Prometheus must discover ServiceMonitors from every namespace."
  }

  assert {
    condition     = length(helm_release.metrics_server) == 1
    error_message = "metrics-server should be installed by default."
  }

  assert {
    condition     = !strcontains(helm_release.kube_prometheus_stack.values[0], var.grafana_admin_password)
    error_message = "The Grafana password must not leak into plain chart values."
  }
}

run "node_ports_expose_ui" {
  command = plan

  variables {
    grafana_node_port    = 30300
    prometheus_node_port = 30900
  }

  assert {
    condition     = yamldecode(helm_release.kube_prometheus_stack.values[0]).grafana.service.nodePort == 30300
    error_message = "Grafana NodePort not applied."
  }

  assert {
    condition     = yamldecode(helm_release.kube_prometheus_stack.values[0]).prometheus.service.type == "NodePort"
    error_message = "Prometheus service should be NodePort when a port is given."
  }
}

run "metrics_server_can_be_disabled" {
  command = plan

  variables {
    enable_metrics_server = false
  }

  assert {
    condition     = length(helm_release.metrics_server) == 0
    error_message = "metrics-server should not be installed when disabled."
  }
}

run "rejects_weak_password" {
  command = plan

  variables {
    grafana_admin_password = "short"
  }

  expect_failures = [var.grafana_admin_password]
}
