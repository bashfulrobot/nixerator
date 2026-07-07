# Recipes

Copy-paste starting points for the common tasks. All assume `GRAFANA_TOKEN`
is already set (see `references/cluster-setup.md` for where it comes from)
and that you're running these from `scripts/` in this skill, or with the
scripts on PATH.

## Cluster health at a glance

```bash
# Nodes reporting up
grafana-query.sh prom 'count(up{cluster="darkstar", app="node-exporter"} == 1)'

# Pod counts by namespace (right now)
grafana-query.sh prom 'count by(namespace) (kube_pod_info{cluster="darkstar"})'

# Cluster-wide restarts in the last hour
grafana-query.sh prom 'sum(increase(kube_pod_container_status_restarts_total{cluster="darkstar"}[1h]))'
```

## Find what's actually broken

```bash
# Every container currently in a bad waiting state, with the reason
grafana-query.sh prom 'kube_pod_container_status_waiting_reason{cluster="darkstar"} == 1'

# Every container whose last termination looks bad (OOMKilled, Error, ...)
grafana-query.sh prom 'kube_pod_container_status_last_terminated_reason{cluster="darkstar"} == 1'

# Pods not in Running phase right now
grafana-query.sh prom 'kube_pod_status_phase{cluster="darkstar"} == 1 and on(pod,namespace) kube_pod_status_phase{cluster="darkstar", phase!="Running"}'

# Cluster-wide Warning events from the last hour (crash loops, failed pulls, scheduling failures, ...)
grafana-query.sh loki '{cluster="darkstar", source="kubernetes-events", level="Warning"}' --since 1h --limit 50
```

Narrow any of the above to one namespace by adding `, namespace="<ns>"` inside
the label matcher (Prometheus) or on the stream selector (Loki).

## Drill into one workload

Given a `namespace` and `pod`:

```bash
ns=monitoring
pod=grafana-alloy-metrics-abc123

# CPU/memory: usage vs request vs limit (right-sizing)
grafana-query.sh prom "sum(rate(container_cpu_usage_seconds_total{cluster=\"darkstar\", namespace=\"$ns\", pod=\"$pod\", container!=\"\", container!=\"POD\"}[5m]))"
grafana-query.sh prom "sum(kube_pod_container_resource_requests{cluster=\"darkstar\", namespace=\"$ns\", pod=\"$pod\", resource=\"cpu\"})"
grafana-query.sh prom "sum(kube_pod_container_resource_limits{cluster=\"darkstar\", namespace=\"$ns\", pod=\"$pod\", resource=\"cpu\"})"
# swap resource="cpu" for resource="memory", and container_cpu_usage_seconds_total
# for container_memory_working_set_bytes, for the memory-side numbers.

# Restarts in the last hour
grafana-query.sh prom "sum(increase(kube_pod_container_status_restarts_total{cluster=\"darkstar\", namespace=\"$ns\", pod=\"$pod\"}[1h]))"

# Warning events for just this pod (namespace label + name via structured metadata)
grafana-query.sh loki "{cluster=\"darkstar\", source=\"kubernetes-events\", namespace=\"$ns\", level=\"Warning\"} | name=\"$pod\"" --since 6h

# Its application logs
grafana-query.sh loki "{cluster=\"darkstar\", namespace=\"$ns\", pod=\"$pod\"}" --since 30m --limit 200
```

This is exactly what the **Kubernetes Workload Drilldown** dashboard shows for
the `$namespace`/`$pod` you pick -- these are the same queries, useful when
you want the answer inline in a terminal/chat instead of opening Grafana.

## Trend over time (not just "right now")

Add `--since <window> --step <interval>` to any `prom` query to get a range
instead of an instant value -- useful for "has memory usage been climbing" or
"did CPU spike around the time it restarted":

```bash
grafana-query.sh prom 'sum(container_memory_working_set_bytes{cluster="darkstar", namespace="monitoring", pod="grafana-alloy-metrics-abc123", container!="", container!="POD"})' --since 6h --step 5m
```

## Find a dashboard, then read or update it

```bash
grafana.sh get search -q 'query=kubernetes'
grafana.sh get dashboards/uid/k8s-cluster-overview | jq '.dashboard.panels[].title'
```

## Publish a dashboard change

1. Edit the dashboard JSON in `iac`'s `manifests/base/observability/dashboards/`.
2. Validate it's well-formed: `jq -e '.dashboard.title' path/to/file.json`.
3. Push it:
   ```bash
   grafana.sh post dashboards/db -d @manifests/base/observability/dashboards/k8s-cluster-overview.json
   ```
   Or, from within the `iac` repo, push every dashboard in the directory at
   once: `just push-dashboards op://automation/grafana-cloud-dashboards/token https://bashfulrobot.grafana.net`.
4. Confirm: `grafana.sh get search -q 'query=<dashboard title>'` and check the
   returned `url`, or re-fetch `dashboards/uid/<uid>` and diff the panel you
   changed.

Keep `dashboard.uid` stable across pushes -- that's what makes `overwrite:
true` update in place instead of creating a duplicate dashboard.

## Check for firing alerts

```bash
grafana.sh get v1/provisioning/alert-rules
grafana.sh get alertmanager/grafana/api/v2/alerts
```

Both return `[]` today -- no alert rules are configured on this org yet. That
means "no alerts" currently proves nothing about cluster health; don't treat
an empty response here as a clean bill of health until rules actually exist.
