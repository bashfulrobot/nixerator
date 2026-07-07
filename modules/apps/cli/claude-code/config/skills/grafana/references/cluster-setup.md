# What's actually collecting data (darkstar cluster snapshot)

This is a snapshot of how telemetry gets from the `darkstar` Talos cluster
into this Grafana Cloud org, current as of when this skill was written. The
source of truth is the `iac` repo, not this file -- if something here seems
wrong or you're debugging a collection gap, re-verify against
`manifests/base/observability/values.yaml` and `docs/observability.md` in
that repo rather than trust this snapshot. Other clusters (e.g. `spitfire`)
may or may not run the same stack; check that repo's `clusters/<name>/`
before assuming.

## Pipeline

`grafana/k8s-monitoring` Helm chart (Grafana Alloy as the collector) runs two
Alloy instances:

- **alloy-metrics** (Deployment) -- scrapes cluster metrics: kube-state-metrics,
  kubelet/cAdvisor, node-exporter, and any pod/service annotated
  `prometheus.io/scrape: "true"` (annotation autodiscovery). Pushed to the
  `grafanacloud-bashfulrobot-prom` Prometheus datasource.
- **alloy-singleton** (single replica) -- gathers cluster-wide, non-duplicable
  data: Kubernetes events and pod logs (via the Kubernetes API, not hostPath --
  Talos-compatible). Pushed to the `grafanacloud-bashfulrobot-logs` Loki
  datasource.

Both push destinations are external-labeled with `cluster=darkstar` (or
whatever `cluster.name` is set to for that cluster), which is why every query
in this skill filters on `cluster="<name>"` -- without it you're querying
across every cluster pushing into this same Grafana Cloud org.

## What's actually queryable

**Metrics** -- kube-state-metrics and cAdvisor are scraped through a
*default allow-list*, not full firehose (cost control on the free tier). Key
metrics confirmed present (see `references/recipes.md` for how they're used):

- `kube_pod_info`, `kube_pod_status_phase`, `kube_pod_status_reason`
- `kube_pod_container_status_restarts_total`
- `kube_pod_container_status_waiting_reason` (CrashLoopBackOff, ImagePullBackOff, ContainerCreating, ...)
- `kube_pod_container_status_last_terminated_reason` (OOMKilled, Error, Completed, ...) --
  note: NOT `..._terminated_reason` (no `last_`), that metric doesn't exist
- `kube_pod_container_resource_requests` / `kube_pod_container_resource_limits` (labeled `resource="cpu"|"memory"`)
- `container_cpu_usage_seconds_total`, `container_memory_working_set_bytes` (cAdvisor)
- `node_cpu_seconds_total`, `node_memory_MemAvailable_bytes`, `node_memory_MemTotal_bytes`, `node_network_*_bytes_total` (node-exporter)
- `up` (per-target scrape health -- `label_values(up, cluster)` is how dashboards populate the cluster picker)

If a metric you expect isn't showing up, check
`manifests/base/observability/values.yaml`'s `clusterMetrics.metricsTuning`
section (or the chart's own `default-allow-lists/`) before assuming it's a
scrape failure -- it may just not be on the allow-list.

**Logs / events** (Loki), two distinct streams, distinguishable by labels:

- Kubernetes events: labels `namespace`, `job`, `instance`, `source="kubernetes-events"`,
  `level` (`Info`/`Warning`/`Error` -- Normal is normalized to Info), `reason`
  (BackOff, Failed, FailedScheduling, Unhealthy, ...), and `node` (only on
  Node-kind events). The event's target object name is in **structured
  metadata**, not a label -- filter on it with `| name="<pod-name>"`, not
  `{name="..."}`.
- Pod application logs: labels `namespace`, `pod`, `container`, `job`
  (`<namespace>/<container>`), `service_name`.

Both streams carry the `cluster` label too.

## Where dashboards live

`iac` repo, `manifests/base/observability/dashboards/*.json`. Each file is the
full push envelope (`{dashboard, overwrite, message}`), pushed via
`just push-dashboards <token_path> <grafana_url>` (loops every file in that
directory) or one at a time via `scripts/grafana.sh post dashboards/db -d @file`.

Current dashboards (verify with `grafana.sh get search -q 'tag=kubernetes'`
since this list goes stale):

- **Kubernetes Cluster Overview** (`k8s-cluster-overview`) -- node/cluster
  health at a glance: node/pod counts, CPU/mem/network per node, pods by
  namespace, cluster-wide Warning events.
- **Kubernetes Workload Drilldown** (`k8s-workload-drilldown`) -- pick a
  `$namespace`/`$pod`, get resource usage vs requests/limits (right-sizing),
  restart count, active waiting/terminated reasons (crash loops, image pull
  errors, OOMKilled), Warning events scoped to that pod, and its logs.

## Where the secrets live (do not read the values -- only the locations)

Two separate Grafana Cloud credentials exist for this org; neither should
ever be printed to a terminal, chat, or log -- only their *locations*:

- **Metrics/logs push credentials** (used by Alloy inside the cluster, not by
  this skill): 1Password item `op://automation/grafana-cloud-darkstar` --
  fields `metrics-username`, `logs-username`, `password` (a MetricsPublisher-role
  API token). Consumed via a Kubernetes Secret created by
  `just cluster=darkstar create-grafana-secret op://automation/grafana-cloud-darkstar`
  in the `iac` repo -- this skill has nothing to do with that credential.
- **Dashboard-API / query Service Account token** (what this skill's scripts
  use): 1Password item `op://automation/grafana-cloud-dashboards/token` --
  an Editor-role Grafana Service Account token. It's wired into this user's
  shell as `$GRAFANA_TOKEN` by the shared fish module
  (`modules/apps/cli/fish/default.nix` in this repo), sourced from the
  rendered secrets blob (`secrets.json.tpl` -> `render-secrets` ->
  `~/.config/nixos-secrets/secrets.json` -> `jq` -> `set -gx GRAFANA_TOKEN`).
  It is **not** read directly by any script in this skill -- if `$GRAFANA_TOKEN`
  is unset, the fix is "run `render-secrets` and open a new shell," never
  "`op read` the token and paste it."

If you ever need to reference the token's location in conversation, cite the
`op://` path above -- never the value, a prefix of it, or its length.
