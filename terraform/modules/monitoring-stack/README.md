# Module: monitoring-stack

Installs [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
(Prometheus Operator, Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics)
and, optionally, [metrics-server](https://github.com/kubernetes-sigs/metrics-server) into any cluster.
The caller configures the `helm` and `kubernetes` providers.

It is set up so that application teams can ship monitoring next to their workloads:

- Prometheus selects `ServiceMonitor`, `PodMonitor` and `PrometheusRule` objects from **all namespaces**,
  not only ones labelled with the Helm release.
- Grafana's sidecar loads dashboards from any ConfigMap labelled `grafana_dashboard: "1"`.

```hcl
module "monitoring" {
  source = "../../modules/monitoring-stack"

  grafana_admin_password = random_password.grafana.result
  grafana_node_port      = 30300 # omit on real clusters and use Ingress/port-forward
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `grafana_admin_password` | `string` (sensitive) | — | ≥ 12 chars; passed via `set_sensitive` |
| `namespace` | `string` | `monitoring` | Namespace to create |
| `kube_prometheus_stack_version` | `string` | `93.11.0` | Chart version |
| `grafana_node_port` / `prometheus_node_port` | `number` | `null` | Expose as NodePort; `null` keeps ClusterIP |
| `prometheus_retention` | `string` | `24h` | Retention, validated as a Prometheus duration |
| `scrape_interval` | `string` | `15s` | Default scrape interval |
| `disable_control_plane_scrapes` | `bool` | `true` | Skip etcd/scheduler/controller-manager/kube-proxy (unreachable on kind and managed clusters) |
| `enable_metrics_server` | `bool` | `true` | Install metrics-server for HPA and `kubectl top` |
| `metrics_server_version` | `string` | `3.14.0` | Chart version |
| `metrics_server_insecure_tls` | `bool` | `true` | `--kubelet-insecure-tls`, needed on kind only |

## Outputs

`namespace`, `release_name`, `grafana_service`, `prometheus_service`, `chart_versions`.

## Tests

`terraform test` runs against mocked providers. It checks service exposure, cross-namespace
discovery, the metrics-server toggle, password validation, and that the Grafana password never
appears in the rendered chart values.
