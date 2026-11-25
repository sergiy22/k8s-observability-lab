# Runbooks

Each alert in [`k8s/base/monitoring.yaml`](../k8s/base/monitoring.yaml) links here.
Commands assume `export KUBECONFIG=terraform/environments/local/kubeconfig`.

## DemoApiDown

**Meaning:** Prometheus has no healthy `demo-api` scrape target for 2 minutes. Users are likely affected.

1. Are pods running?
   ```bash
   kubectl -n demo get pods -l app.kubernetes.io/name=demo-api -o wide
   ```
2. If pods are `CrashLoopBackOff` or `ImagePullBackOff`:
   ```bash
   kubectl -n demo describe pod <pod>
   kubectl -n demo logs <pod> --previous
   ```
3. If pods are healthy but the target is down, check that the Service and ServiceMonitor still match
   (`kubectl -n demo get endpointslices -l kubernetes.io/service-name=demo-api`) and that the
   NetworkPolicy still lets the `monitoring` namespace in.
4. Roll back a bad release: `kubectl -n demo rollout undo deploy/demo-api`.

## DemoApiHighErrorRate

**Meaning:** more than 5% of requests return 5xx for 5 minutes.

1. Open the **demo-api / RED overview** dashboard and see whether errors started with a deploy
   (`kubectl -n demo rollout history deploy/demo-api`).
2. Check the `ERROR_RATE` env var, which drives the simulated failures in this lab:
   `kubectl -n demo get deploy demo-api -o jsonpath='{.spec.template.spec.containers[0].env}'`.
3. Mitigate by rolling back, then find the root cause from the logs.

## DemoApiHighLatencyP95

**Meaning:** p95 latency is above 500 ms for 10 minutes.

1. Check for CPU saturation on the dashboard and `kubectl -n demo top pods`.
2. Check that the HPA is scaling: `kubectl -n demo get hpa demo-api`. If it shows `<unknown>`,
   metrics-server is missing or unhealthy.
3. Check `MAX_LATENCY_MS`, which drives simulated latency in this lab.

## DemoApiPodRestarting

**Meaning:** a container restarted more than twice in 15 minutes.

1. `kubectl -n demo describe pod <pod>` and look at **Last State**: `OOMKilled` means the memory
   limit is too low, a failed liveness probe means the app is stalling.
2. `kubectl -n demo logs <pod> --previous` for the crash output.
