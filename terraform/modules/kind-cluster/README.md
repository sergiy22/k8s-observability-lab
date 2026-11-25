# Module: kind-cluster

Creates a local multi-node Kubernetes cluster with [kind](https://kind.sigs.k8s.io/)
using the [`tehcyx/kind`](https://registry.terraform.io/providers/tehcyx/kind) provider.

```hcl
module "cluster" {
  source = "../../modules/kind-cluster"

  name         = "observability-lab"
  worker_count = 2
  port_mappings = [
    { container_port = 30300, host_port = 3000 }, # Grafana NodePort -> localhost:3000
  ]
}

provider "kubernetes" {
  host                   = module.cluster.endpoint
  cluster_ca_certificate = module.cluster.cluster_ca_certificate
  client_certificate     = module.cluster.client_certificate
  client_key             = module.cluster.client_key
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | — | Cluster name (DNS label, ≤ 32 chars) |
| `node_image` | `string` | `kindest/node:v1.36.4@sha256:…` | Node image, pinned by digest |
| `worker_count` | `number` | `2` | Worker nodes besides the control plane (0–10) |
| `port_mappings` | `list(object)` | `[]` | NodePort (30000–32767) to host port mappings on the control plane, bound to `127.0.0.1` by default |
| `kubeconfig_path` | `string` | `null` | Where to write the kubeconfig |

## Outputs

`name`, `context`, `endpoint`, `cluster_ca_certificate`, `client_certificate`, `client_key` (sensitive), `kubeconfig_path`.

## Tests

```bash
terraform init -backend=false && terraform test
```

The tests use a mocked `kind` provider, so they need neither Docker nor a cluster. They cover
node topology, port mapping placement and input validation.
