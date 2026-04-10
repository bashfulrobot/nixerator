# Kong Product Stack — Technical CSM Reference

Use this reference when you need product-specific detail for customer conversations,
QBR prep, migration planning, or competitive positioning.

## Table of Contents

1. [Kong Gateway](#1-kong-gateway)
2. [Kong Konnect](#2-kong-konnect)
3. [Kong Mesh](#3-kong-mesh)
4. [Kong Insomnia](#4-kong-insomnia)
5. [AI Gateway](#5-ai-gateway)
6. [Deployment Patterns](#6-deployment-patterns)
7. [Migration Paths](#7-migration-paths)
8. [Key Value Propositions](#8-key-value-propositions)
9. [Common Technical Challenges](#9-common-technical-challenges)
10. [Product Positioning Summary](#10-product-positioning-summary)

---

## 1. Kong Gateway

### OSS vs Enterprise

**Kong Gateway OSS** — Open-source, Lua/OpenResty-based API gateway on NGINX.

Core capabilities: request routing, load balancing, health checking, 100+ plugins,
Admin API, declarative YAML config (DB-less mode), Kubernetes Ingress Controller (KIC),
REST/gRPC/GraphQL/WebSocket proxying.

**Kong Gateway Enterprise** — Everything in OSS plus:

- **Kong Manager** — GUI for configuration, monitoring, operations
- **RBAC** — Role-based access control for Admin API and Kong Manager
- **Workspaces** — Multi-tenant configuration isolation
- **Secrets Management** — HashiCorp Vault, AWS Secrets Manager, GCP Secret Manager, Azure Key Vault, CyberArk
- **Enterprise plugins** — Rate Limiting Advanced (sliding window, Redis Cluster/Sentinel), OpenID Connect, OAuth2 Introspection, Mutual TLS Auth, SAML, Canary Release, Forward Proxy, GraphQL Rate Limiting Advanced, OPA, Kafka Log/Upstream, Datadog Tracing, Exit Transformer, Request Validator, Degraphql, Websocket Size/Validator
- **Keyring encryption** — Encrypt sensitive plugin fields at rest
- **Audit logging** — Track Admin API and Kong Manager actions
- **FIPS 140-2** — Available on specific builds

### Deployment Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **Traditional** | All nodes share PostgreSQL database | Simple/small deployments, dev/test |
| **DB-less** | Config loaded from YAML, no database | GitOps, immutable infra, Kubernetes |
| **Hybrid (CP/DP)** | CP with DB, DP nodes DB-less | Production enterprise, multi-region, multi-cloud |

**Hybrid mode detail:** CP manages config + Admin API; DP proxies traffic. CP-to-DP over
mTLS WebSocket (ports 8005/8006). DP caches config locally, continues operating during
CP outage. CP must be same or newer minor version than DP (upgrade CP first).

### Version Support

- 4 minor releases/year (March, June, September, December)
- March release = LTS (3 years support)
- **Current LTS:** 3.4 (through Aug 2026), 3.10 (through March 2028)
- Non-LTS receives patches only until next minor release

### Key Tooling

**decK** — Declarative config management CLI. YAML export/import, diff, sync, drift
detection. Supports Konnect targeting. CI/CD integration for APIOps.

Commands: `deck gateway dump`, `deck gateway sync`, `deck gateway diff`, `deck gateway validate`

---

## 2. Kong Konnect

SaaS unified control plane for all Kong components.

### Core Features

- **Control Planes** — Lightweight config isolation (evolution of Workspaces)
- **Control Plane Groups** — Shared policy management across CPs
- **Runtime Manager** — Provision and monitor DP instances
- **Analytics** — API traffic dashboards and reporting
- **Service Catalog** — System of record for all APIs across the org
- **Developer Portal (v3)** — API catalogs, dev self-service, key management
- **Konnect Debugger** — Real-time API traffic inspection
- **KAi** — Agentic AI co-pilot for the Konnect platform
- **Metering and Billing** — API monetization with real-time usage tracking

### Data Plane Options

| Option | Description |
|--------|-------------|
| **Self-hosted** | Customer runs DP on own infra (K8s, VMs, any OS) |
| **Dedicated Cloud Gateways** | Kong-managed DP on isolated infra (AWS, Azure, GCP) |

### Tiers

| Feature | Plus | Enterprise |
|---------|------|-----------|
| Gateway management | Yes | Yes |
| Analytics | Basic | Advanced |
| Developer Portal | Basic | Full customization |
| RBAC / SSO / SCIM | Limited | Full |
| Support | Standard | Diamond/Platinum/Business |
| Mesh Manager | No | Yes |

### Value vs Self-Hosted

- Reduced ops burden — no CP infra to manage
- Faster time to value — pre-built analytics, portal, catalog
- Built-in HA — 99.9% SLA
- Continuous updates — no customer upgrade cycles for CP
- Multi-team governance — CP Groups, RBAC, SSO OOTB
- PCI DSS 4.0 on Dedicated Cloud Gateways

---

## 3. Kong Mesh

Enterprise service mesh built on Kuma (CNCF) + Envoy.

- **mTLS by default** — Zero-trust, automatic cert rotation
- **Traffic management** — Routing, load balancing, circuit breaking, retries, timeouts, fault injection
- **Observability** — Prometheus, Jaeger/Zipkin, logging
- **Multi-zone / multi-cluster** — Federated CP across regions and clouds
- **Universal mode** — Kubernetes AND VMs/bare metal
- **Gateway integration** — Kong Gateway as mesh ingress/egress

### When Customers Use It

- East-west traffic alongside Kong Gateway for north-south
- Zero-trust security requirements
- Multi-cloud/hybrid service connectivity
- Mixed K8s + VM workloads
- Compliance requiring mTLS everywhere

---

## 4. Kong Insomnia

Open-source API client and development platform.

- API design (OpenAPI editor with linting)
- Request building (environments, chaining, auth helpers)
- Testing (automated suites, CI/CD integration)
- Mock servers (AI-powered)
- MCP testing (Insomnia 12) — test/debug MCP servers
- Git Sync, team collaboration
- Enterprise: SSO, SCIM, RBAC

**CSM relevance:** Often bundled in enterprise deals or used as developer adoption wedge.
Connects to Konnect for publishing to Developer Portal.

---

## 5. AI Gateway

Kong Gateway 3.11+ includes AI-specific capabilities:

- **AI Proxy** — Unified interface to LLM providers (OpenAI, Anthropic, Azure OpenAI, Cohere, Llama, Mistral, Bedrock)
- **AI Rate Limiting Advanced** — Token-based rate limiting
- **AI Prompt Guard / Decorator / Template** — Prompt security and management
- **AI Request/Response Transformer** — LLM-powered request modification
- **AI Semantic Cache / Semantic Prompt Guard** — Embedding-based caching and safety
- **AI Audit Log** — LLM interaction logging
- **AI MCP Proxy** (3.12) — Protocol bridge between MCP clients and HTTP APIs or upstream MCP servers
- **AI MCP OAuth2** (3.12) — OAuth 2.1 aligned with MCP spec
- **MCP Prometheus metrics** (3.12)

---

## 6. Deployment Patterns

### Hybrid Mode (Most Common Enterprise)

CP cluster (2-3 nodes + PostgreSQL) → mTLS → Distributed DP nodes (stateless, any env).
Config cached locally on DP; survives CP outage.

### Kubernetes-Native (KIC)

KIC as K8s Ingress or Gateway API implementation. Config via CRDs. Kong Gateway Operator
for lifecycle. Often combined with Konnect for visibility across clusters.

### Konnect + Self-Hosted DP

Konnect SaaS manages CP; customer runs DP on own infrastructure. Data never leaves
customer network (only config sync + telemetry to Konnect). Most popular model for
enterprises with data residency requirements.

### Konnect + Dedicated Cloud Gateways

Fully managed CP + DP by Kong. Min operational overhead. PCI DSS 4.0 attested.

### Gateway + Mesh (Full Platform)

Gateway = north-south, Mesh = east-west. Unified policy via Konnect.

---

## 7. Migration Paths

### OSS → Enterprise

1. Back up database (irreversible migration)
2. Download Enterprise matching current OSS version
3. Point at same PostgreSQL
4. `kong migrations up` → `kong migrations finish`
5. Apply licence, enable features incrementally

### Self-Hosted → Konnect

1. `deck gateway dump` to export config
2. Create CP in Konnect
3. Map Workspaces → Control Planes
4. `deck gateway sync --konnect-addr` to sync config
5. Register DP nodes with Konnect certs
6. Cut over traffic

**Note:** DB-less must migrate to hybrid first, then Konnect.

### Legacy Gateways → Kong

Common sources: Apigee, MuleSoft, AWS API Gateway, Azure APIM, IBM API Connect, CA Layer 7, WSO2.

Approach: API inventory → policy mapping to Kong plugins → parallel run (shadow/canary) → strangler fig migration → validate parity → DNS cutover.

---

## 8. Key Value Propositions

| Category | Value |
|----------|-------|
| **Unified Platform** | Single platform for REST, GraphQL, gRPC, events, AI/LLM, MCP |
| **Developer Productivity** | Sub-ms latency, GitOps via decK, Developer Portal, KIC |
| **Security & Governance** | Auth (JWT, OIDC, SAML, mTLS), rate limiting, OPA, vault integration, audit logging |
| **Observability** | Prometheus, OTel, Datadog, Konnect Analytics, Konnect Debugger |
| **Performance** | NGINX foundation, horizontal DP scaling, proxy cache, connection pooling |
| **AI Enablement** | AI Gateway, token rate limiting, prompt guard, semantic cache, MCP proxy |

---

## 9. Common Technical Challenges

### Upgrades

- Follow LTS-to-LTS guide. CP-first, DP-second in hybrid mode.
- Blue-green DP upgrades safest. `deck gateway diff` to validate config.
- Konnect eliminates CP upgrade burden.

### Plugin Compatibility

- Check compatibility matrix before upgrades. Custom Lua plugins: test against new PDK.
- External plugins (Go, Python, JS): verify pluginserver compat.
- Some plugins CP-only or DP-only — topology matters.

### Performance

- Plugin execution order matters — minimize expensive plugins early.
- DB-less/hybrid eliminates DB round-trips on DP.
- Tune NGINX workers and connections. Redis pooling for RLA and Session.
- Monitor p99 latency, error rates, connection pool exhaustion.

### CP/DP Connectivity

- DP caches config, operates during CP outage.
- Monitor `kong_data_plane_config_hash` and `kong_data_plane_last_seen`.
- mTLS cert rotation and expiry monitoring.
- Ports 8005 (config) and 8006 (telemetry) must be reachable.

### Multi-Team Governance

- Self-hosted: Workspaces + RBAC. Konnect: CPs + CP Groups.
- decK with tags for team-based CI/CD config ownership.
- Federated model: platform team sets guardrails, app teams self-serve.

---

## 10. Product Positioning Summary

| Product | What It Does | When to Talk About It |
|---------|-------------|----------------------|
| Gateway OSS | Open-source API gateway | Developer adoption, evaluation |
| Gateway Enterprise | Production API gateway + enterprise features | Self-hosted enterprise, regulated |
| Konnect | SaaS unified control plane | Reduce ops, multi-team governance |
| Mesh | Service mesh (east-west) | Zero-trust, multi-cloud, compliance |
| Insomnia | API design and testing | Developer experience, API-first |
| AI Gateway | AI/LLM traffic management | AI adoption, LLM governance, MCP |
| decK | Declarative config CLI | GitOps, CI/CD, APIOps, migration |
