---
name: grafana
description: >-
  Query and manage the bashfulrobot Grafana Cloud org via its REST API --
  cluster/pod metrics (Prometheus), Kubernetes events and pod logs (Loki),
  dashboard search/read/publish, and alert status. Use when the user asks
  about Grafana, Grafana Cloud, cluster/pod metrics, CPU or memory usage,
  right-sizing, CrashLoopBackOff/ImagePullBackOff/OOMKilled, Kubernetes
  events, pod logs, dashboard creation or updates, or invokes /grafana.
  Trigger phrases include "check Grafana for X", "query the cluster metrics",
  "is pod X crash-looping", "why is this pod OOMKilled", "tail warning events
  for namespace Y", "push this dashboard", "what dashboards do we have",
  "are there any firing alerts". Every call goes through the two scripts in
  this skill (never hand-rolled curl) so datasource uids, Prometheus-seconds
  vs Loki-nanoseconds, and dashboard push envelopes stay correct by
  construction rather than re-derived per session. Read-only by default;
  dashboard pushes (writes) get a one-line confirmation of what's being
  pushed and to which uid before running.
---

# Grafana Cloud (grafana)

Work with the bashfulrobot Grafana Cloud org through `scripts/grafana.sh`
(generic REST API wrapper) and `scripts/grafana-query.sh` (PromQL/LogQL via
the datasource proxy). Both read auth from `$GRAFANA_TOKEN` and default the
base URL to this org, so most calls need no extra plumbing.

## Why this skill exists

This session's own history is the reason it exists: building two dashboards
required rediscovering, by trial and API introspection, that Forgejo doesn't
expose an HTTP-rate metric at all, that `kube_pod_container_status_terminated_reason`
doesn't exist (it's `..._last_terminated_reason`), that the Loki proxy wants
nanoseconds while the Prometheus proxy wants seconds, and that this org has
several near-duplicate datasources where picking the wrong one fails silently
instead of erroring. None of that is discoverable from Grafana's generic
docs -- it's specific to what's actually deployed here. This skill bakes that
knowledge in once so it doesn't get re-derived (or re-gotten-wrong) every
session.

## Prerequisites

- `$GRAFANA_TOKEN` set in the environment -- a Grafana Service Account token
  (Editor role). On this user's machines it's already exported by the shared
  fish module from the rendered nixerator secrets blob; see
  `references/cluster-setup.md` for exactly where it comes from and how to
  fix it if it's missing. **Never fetch it manually with `op read` and paste
  it** -- if it's unset, the fix is `render-secrets` + a new shell.
- `curl`, `jq`, `date` on PATH.
- Default org is `bashfulrobot.grafana.net`. Override with `GRAFANA_URL` if
  ever working against a different Grafana instance.

## The two tools

### scripts/grafana.sh -- generic API wrapper

For anything not metrics/logs: dashboard search/get/push, datasource listing,
alert rules, folders.

```bash
grafana.sh get search -q 'query=kubernetes'
grafana.sh get dashboards/uid/k8s-cluster-overview
grafana.sh post dashboards/db -d @manifests/base/observability/dashboards/k8s-cluster-overview.json
grafana.sh get datasources
grafana.sh get v1/provisioning/alert-rules
```

### scripts/grafana-query.sh -- metrics and logs

For anything that's a PromQL or LogQL query. Handles datasource-name-to-uid
resolution and the seconds-vs-nanoseconds time-unit conversion so you don't
have to.

```bash
grafana-query.sh prom 'count(up{cluster="darkstar"})'                       # instant
grafana-query.sh prom 'sum(rate(...))' --since 6h --step 5m                 # range/trend
grafana-query.sh loki '{cluster="darkstar", source="kubernetes-events", level="Warning"}' --since 1h
```

Run either with `--help` for the full flag list. For the full endpoint
catalogue and exact param shapes, read `references/api-reference.md`. For
copy-paste troubleshooting/right-sizing/dashboard-publish workflows, read
`references/recipes.md`. For what's actually deployed and collecting data
(and where the credentials physically live), read `references/cluster-setup.md`.

## Workflow

### Step 1: Classify the request

- **Read** -- any GET: metrics query, log/event query, dashboard search/get,
  datasource list, alert status. Safe; proceed. This is nearly everything.
- **Write** -- dashboard create/update (`POST dashboards/db`). Stop and follow
  the confirmation step below. There's no delete/mutate path in this skill
  beyond dashboard publish -- nothing here touches cluster config, secrets,
  or alert rules.

### Step 2 (reads): Pick the right tool and datasource

- Metrics question ("how much CPU", "is X restarting", "what's the resource
  request/limit") -> `grafana-query.sh prom`.
- Logs or events question ("why did this crash", "what happened around time
  T", "tail this pod's logs") -> `grafana-query.sh loki`.
- Dashboard/alert/meta question -> `grafana.sh` against the relevant path.
- If you're unsure a metric or label exists, check
  `references/cluster-setup.md` first rather than guessing a plausible-looking
  name -- this org runs a curated allow-list, not every metric Kubernetes can
  emit, and Forgejo-style "the name looks right but doesn't exist" mistakes
  are exactly what this skill exists to prevent.
- Always scope queries with `cluster="<name>"` -- this Grafana org receives
  data from more than one cluster; an unscoped query silently mixes them.

### Step 3 (writes): Confirm before publishing a dashboard

1. State the exact file being pushed and its `dashboard.uid` (uid determines
   whether this creates a new dashboard or overwrites an existing one --
   getting the uid wrong either clobbers the wrong dashboard or silently
   forks a duplicate).
2. Get an explicit "yes" for *this* push. Approval of one push isn't approval
   of the next.
3. Run it, then `grafana.sh get dashboards/uid/<uid>` (or re-open in the UI)
   to confirm the change actually landed as intended.

## What NOT to do

- Do not hand-roll `curl` against the Grafana API when a script here covers
  it -- that's exactly how the seconds/nanoseconds and datasource-uid mistakes
  happen. If a needed call genuinely isn't covered, extend `grafana.sh`
  (it's a generic method+path wrapper, so most new endpoints need zero new
  code) rather than reaching for raw `curl`.
- Do not fetch or print `$GRAFANA_TOKEN`'s value, a prefix of it, or its
  length, under any circumstance -- reference the `op://` path instead (see
  `references/cluster-setup.md`).
- Do not guess a metric or label name because it "sounds right." Verify
  against `references/cluster-setup.md`, or query
  `grafana-query.sh prom '{__name__=~".+"}'`-style discovery, or just try it
  and check for an empty vs. populated result before building a dashboard
  panel or alert on it.
- Do not push a dashboard without stating the uid and getting a yes first --
  a wrong uid either overwrites the wrong dashboard or forks a duplicate.
- Do not treat an empty alert-rules/firing-alerts response as "cluster is
  healthy" -- no alert rules are configured on this org yet, so that
  endpoint currently can't tell you anything either way.

## Files in this skill

### scripts/
- `grafana.sh` -- generic REST API wrapper. Auth from `GRAFANA_TOKEN`, query
  encoding, body from inline JSON or `@file`, jq pretty-printing.
- `grafana-query.sh` -- PromQL/LogQL wrapper via the datasource-proxy API.
  Resolves datasource name -> uid, handles instant vs. range Prometheus
  queries and the Loki nanosecond time format.

### references/
- `cluster-setup.md` -- what's actually deployed and collecting data (Alloy
  pipeline, allow-listed metrics, Loki label schema, current dashboards, and
  exactly where the credentials live without exposing their values).
- `api-reference.md` -- endpoint catalogue, exact param shapes, and the
  verified datasource inventory (including the near-duplicate traps to avoid).
- `recipes.md` -- copy-paste commands for cluster health checks, finding
  what's broken, drilling into one workload, trending a metric over time,
  and publishing a dashboard.
