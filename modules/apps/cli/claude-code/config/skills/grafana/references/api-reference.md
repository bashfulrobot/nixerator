# Grafana Cloud API reference (bashfulrobot org)

Base URL: `https://bashfulrobot.grafana.net` (override via `GRAFANA_URL`).
Auth: `Authorization: Bearer $GRAFANA_TOKEN` on every call. Both scripts in
this skill add this header automatically.

All endpoints below were verified live against this org's Grafana Cloud
instance while building this skill. If a call here starts failing, re-verify
against the current state rather than assume the org's setup hasn't changed --
datasource uids and dashboard uids in particular are this-org-specific facts,
not stable Grafana defaults.

## Datasource inventory (verified)

Fetch the live list any time with `grafana.sh get datasources`. As of writing,
the ones that matter for this cluster:

| Name | Type | uid | Use for |
|---|---|---|---|
| `grafanacloud-bashfulrobot-prom` | prometheus | `grafanacloud-prom` | Cluster/node/pod metrics (kube-state-metrics, cAdvisor, node-exporter) |
| `grafanacloud-bashfulrobot-logs` | loki | `grafanacloud-logs` | Kubernetes events + pod application logs |

**Traps -- do not use these for cluster data even though they look similar:**

| Name | Type | Why not |
|---|---|---|
| `grafanacloud-bashfulrobot-prom-nonprovisioned` | prometheus | Legacy duplicate datasource, same account, not the one dashboards/queries are built against |
| `grafanacloud-bashfulrobot-logs-nonprovisioned` | loki | Same URL as the real one, but a separate legacy datasource object (different uid) |
| `grafanacloud-bashfulrobot-alert-state-history` | loki | Grafana's own alert-firing history, not your cluster's logs |
| `grafanacloud-bashfulrobot-usage-insights` | loki | Grafana Cloud's own query/usage telemetry, not your cluster's logs |

`grafana-query.sh` defaults to the two correct ones (`GRAFANA_PROM_DATASOURCE`,
`GRAFANA_LOKI_DATASOURCE`) and resolves name -> uid itself via
`GET /datasources/name/:name`, so this table is background, not something you
need to paste into every query -- but know it exists before you `grafana.sh get
datasources` and pick one that merely *looks* right.

## Querying metrics (Prometheus, via datasource proxy)

Prefer `scripts/grafana-query.sh prom '<promql>'` over calling this directly --
it resolves the uid and handles seconds-based start/end for you. Raw shape,
for reference:

```
GET /datasources/proxy/uid/<uid>/api/v1/query?query=<promql>
GET /datasources/proxy/uid/<uid>/api/v1/query_range?query=<promql>&start=<unix_seconds>&end=<unix_seconds>&step=<seconds_or_duration>
```

`start`/`end` are **unix seconds** (not milliseconds, not RFC3339).

## Querying logs and events (Loki, via datasource proxy)

Prefer `scripts/grafana-query.sh loki '<logql>'`. Raw shape:

```
GET /datasources/proxy/uid/<uid>/loki/api/v1/query_range?query=<logql>&start=<unix_nanoseconds>&end=<unix_nanoseconds>&limit=<n>&direction=backward
```

`start`/`end` are **unix nanoseconds** -- 1000x the Prometheus convention.
This is the single easiest mistake to make against this API; getting it wrong
doesn't error, it just returns an empty result set that looks like "no
matching logs."

Other useful Loki endpoints (not wrapped by a script -- use `grafana.sh` with
a full proxy path if needed):

```
GET /datasources/proxy/uid/<uid>/loki/api/v1/labels?start=...&end=...
GET /datasources/proxy/uid/<uid>/loki/api/v1/label/<name>/values?start=...&end=...
```

## Dashboards

```
GET  /search?query=<term>                 # find dashboards by title
GET  /search?tag=kubernetes                # find dashboards by tag
GET  /dashboards/uid/<uid>                 # full dashboard JSON (incl. current version, folder)
POST /dashboards/db                        # create or update (see below)
```

`POST /dashboards/db` expects this envelope as the body:

```json
{
  "dashboard": { "...": "the actual dashboard JSON, with uid/title/panels" },
  "overwrite": true,
  "message": "why this update happened"
}
```

The dashboard JSON files in the `iac` repo
(`manifests/base/observability/dashboards/*.json`) already carry this exact
envelope at the top level, so pushing one is:

```bash
bash scripts/grafana.sh post dashboards/db -d @manifests/base/observability/dashboards/k8s-cluster-overview.json
```

`overwrite: true` + a stable `dashboard.uid` is what makes re-pushing
idempotent -- same uid updates in place instead of creating a duplicate.

The `iac` repo also has `just push-dashboards <token_path> <grafana_url>`,
which loops every `*.json` in that directory through this same endpoint. Use
that when you're already in `iac` and want to push everything; use
`grafana.sh post dashboards/db` directly when you're elsewhere, pushing one
file, or the target dashboard doesn't live in that repo.

## Alerting

```
GET /v1/provisioning/alert-rules              # configured alert rules
GET /alertmanager/grafana/api/v2/alerts       # currently firing/pending alerts
```

Both return an empty array on this org today (no alert rules are configured
yet) -- an empty array is a correct, healthy response here, not an error.

## Folders

```
GET /folders                    # list folders
GET /folders/:uid                # one folder
```

Dashboards pushed without a `folderUid` in the envelope land in the root
("General") folder -- that's where both `k8s-cluster-overview` and
`k8s-workload-drilldown` currently live.
