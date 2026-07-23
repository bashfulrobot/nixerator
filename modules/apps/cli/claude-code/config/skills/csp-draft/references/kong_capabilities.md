# Kong Capabilities & Value Driver Mapping

Use this reference to populate Initiatives and suggest relevant Kong capabilities when source
documents are underspecified. Do NOT hallucinate capabilities — if a product feature is uncertain,
flag it as [VERIFY].

**For the full value driver → GOSIM mapping** (Objective language, current/future state signals,
Required Capabilities as Strategy candidates, metrics defaults, and persona-specific discovery
questions), read `references/value_drivers.md`.

---

## Kong's Four Value Drivers

These are the four business lenses through which Kong positions its platform. Use them to connect
Initiatives back to Goals and Objectives. Each maps to a customer archetype and a set of measurable
outcomes. **The names below are the official taxonomy — use these exactly in the CSP.**

1. **Reduce Cost** — Reduce tooling, project, and workforce costs across multiple areas of the
   business. Consolidate fragmented tooling, eliminate legacy overhead, automate manual processes,
   reduce SDLC cost.

2. **Strengthen Security Posture** — Avoid sacrificing security and compliance for the sake of
   rapid delivery and innovation. Automated discovery, security-as-code, governed API lifecycles,
   support for regulated markets.

3. **Enhance Developer Productivity & Developer Experience (DevProd & DevEx)** — Make the business
   a more developer-friendly organization by giving developers the tools to get their jobs done more
   efficiently. Self-serve, discoverability, API reuse, elimination of engineering toil.

4. **Innovate Faster** — Enable the business to take the raw materials of innovation (APIs, AI,
   microservices, real-time data) and turn them into competitive differentiation. Speed, agility,
   AI-readiness, multi-cloud, federated platform model.

A customer's CSP will typically have 1–3 active value drivers. Each active driver maps to one
**Objective** in the GOSIM framework. The overarching **Goal** is the strategic direction that
unifies all active drivers. See `references/value_drivers.md` for model Objective statements per
driver.

---

## Kong Product Portfolio (Current)

### Kong Konnect (SaaS Control Plane)
- Unified control plane for managing Kong Gateway, Mesh, AI Gateway, Event Gateway, and Insomnia
- Multi-cloud, multi-region, hybrid deployment support
- Role-based access control (RBAC), team management, SSO
- Analytics and observability dashboards
- API catalog, service discovery, and Service Catalog with compliance scoring
- **Value drivers**: Reduce Cost (consolidation), DevProd & DevEx (self-serve), Innovate Faster
  (federated platform)

### Kong Gateway (Core Runtime — Open Source + Enterprise)
- API gateway: routing, load balancing, rate limiting, caching
- Authentication plugins: OAuth2, OIDC, JWT, API keys, mTLS, LDAP, SAML
- Authorization: OPA integration, RBAC, ACL plugins
- Traffic management: circuit breaking, retries, canary routing, blue/green
- Logging and observability: Datadog, Prometheus, Splunk, ELK integrations
- Custom plugins in Lua, Go, Python
- Deployment options: self-hosted, hybrid (Konnect control plane + self-managed data plane), SaaS
- **Value drivers**: Strengthen Security Posture, Reduce Cost (consolidation), Innovate Faster

### Kong Mesh (Service Mesh)
- Envoy-based service mesh for east-west service-to-service traffic
- mTLS for all internal service communication (zero-trust)
- Traffic policies: traffic control, fault injection, health checks
- Multi-zone (multi-cluster, multi-cloud) support
- **Value drivers**: Strengthen Security Posture (zero-trust), Reduce Cost (removes custom infra)

### Kong AI Gateway
- LLM traffic routing: multi-provider (OpenAI, Azure OpenAI, Anthropic, Bedrock, etc.)
- Semantic caching: reduce token costs and latency for repeated queries
- Prompt injection protection, PII masking / sanitization, content guardrails
- Cost governance: per-team token budgets and rate limits
- AI observability: token usage tracking, model latency dashboards
- RAG pipeline support (Auto RAG — Kong is the only platform with native support)
- AI Agent integration: Kong as central hub for AI agents to consume APIs
- Pre-built AI security policies: no custom infrastructure required
- **Value drivers**: Innovate Faster (AI-readiness), Reduce Cost (token cost governance),
  Strengthen Security Posture (AI compliance), DevProd & DevEx (self-serve AI for developers)

### Kong Developer Portal
- Self-service API documentation and discovery
- Spec-first publishing: OpenAPI/AsyncAPI auto-rendering
- Support for synchronous, event, and LLM APIs in a single catalog
- Developer onboarding, application registration, API key provisioning
- Advanced customization; custom branding; authentication-gated access
- **Value drivers**: DevProd & DevEx (self-serve, API reuse), Innovate Faster (API productization),
  Reduce Cost (eliminates redundant API builds)

### Kong Service Catalog
- Automated service discovery, inventory, and scoring across the organization
- Continuous visibility: scores APIs for security, reliability, and production readiness
- Platform teams govern while developers build at speed
- Eliminates manual API reviews
- **Value drivers**: Strengthen Security Posture (compliance visibility), DevProd & DevEx
  (discoverability), Reduce Cost (reduces redundant work)

### Dedicated Cloud Gateways (DCGW)
- Engineers deploy runtime infrastructure in their preferred CSP and region
- Full control over runtime without compromising security, compliance, or multi-cloud flexibility
- Offloads API and connectivity infrastructure costs to cloud
- **Value drivers**: Reduce Cost, Innovate Faster (cloud-native), Strengthen Security Posture
  (compliance in preferred region)

### Serverless API Gateways
- Simplest, most cost-efficient way to spin up API Gateways for non-prod and non-critical use cases
- Fully managed; no ops overhead
- **Value drivers**: DevProd & DevEx (developer self-serve), Reduce Cost

### Kong Insomnia
- API design-first tooling: spec authoring, linting, validation
- Collaboration: shared collections, environments, team workspaces
- Pre-request testing, automated test suites
- Git sync for spec lifecycle management
- **Value drivers**: DevProd & DevEx (API-first development), Strengthen Security Posture
  (spec-level security validation)

### APIOps / Infrastructure as Code (decK, Kubernetes Operator, Admin API)
- decK CLI: declarative config management for non-Kubernetes environments
- Kubernetes Operator: declarative K8s-native management
- Admin API: imperative management with full documentation
- More automation options than any other vendor — deeply integrated across the platform
- Provides clear audit trail of every step, commit, and action taken
- **Value drivers**: Reduce Cost (lower ops overhead), Strengthen Security Posture (security
  as code, auditability), DevProd & DevEx (developer autonomy), Innovate Faster (CI/CD integration)

---

## Common Initiative Patterns by Customer Archetype

### Financial Services / FinTech
Active drivers: **Strengthen Security Posture** + **Reduce Cost**
- Phase 1 (Now): Gateway + centralized auth (OAuth2/OIDC) for Open Banking / compliance baseline;
  self-hosted or hybrid deployment for data sovereignty
- Phase 2 (Next): Service Catalog for API visibility and compliance scoring; RBAC rollout
- Phase 3 (Later): Kong Mesh for zero-trust east-west within PCI scope; AI Gateway for
  secure LLM access
- Key metrics: audit pass rate, # APIs under known management, security score, breach cost,
  cyber insurance premium delta

### Retail / E-Commerce
Active drivers: **Innovate Faster** + **DevProd & DevEx**
- Phase 1 (Now): Gateway for external API program (partners, 3P integrations); rate limiting
  and caching for peak traffic
- Phase 2 (Next): Dev Portal for third-party developer ecosystem; self-serve API catalog
- Phase 3 (Later): AI Gateway for AI-driven personalization and recommendation services
- Key metrics: partner integration time, API availability during peak, dev adoption rate,
  time between API design and consumption

### Pharma / Healthcare / Regulated Industries
Active drivers: **Strengthen Security Posture** + **DevProd & DevEx**
- Phase 1 (Now): Hybrid Gateway with compliance-grade deployment; automated CI/CD pipeline
  using Kong plugins within regulated environments
- Phase 2 (Next): Security guardrails as code; automated compliance scanning via Service Catalog
- Phase 3 (Later): Dev Portal for internal discoverability; Kong Mesh for zero-trust internal
  service communication
- Key metrics: deployment cycle time, compliance audit results, redundant coding eliminated,
  time to market for new services

### Telco / Media / Platform Companies
Active drivers: **Reduce Cost** + **Innovate Faster**
- Phase 1 (Now): Gateway consolidation (replace 3–5 legacy gateways); Konnect RBAC for
  multi-team platform model
- Phase 2 (Next): API monetization / tiered access via Dev Portal; Service Catalog rollout
- Phase 3 (Later): AI Gateway for AI-driven features; DCGW for multi-cloud flexibility
- Key metrics: number of gateways consolidated, API products published, revenue via API,
  TCO delta

### Enterprise Digital Transformation
Active drivers: **All four** (sequence by business priority)
- Phase 1 (Now): Gateway as first step toward microservices migration; Insomnia for API-first
  design culture adoption
- Phase 2 (Next): Dev Portal + Service Catalog for internal platform model; decK/APIOps for
  IaC governance
- Phase 3 (Later): Kong Mesh for service-to-service as monolith decomposes; AI Gateway for
  AI capability layer
- Key metrics: time-to-market for new services, % APIs with published specs, MTTR, eNPS,
  TCO vs. prior platform

### AI-Forward Customers
Active drivers: **Innovate Faster** + **Strengthen Security Posture** (+ often **Reduce Cost**)
- Phase 1 (Now): AI Gateway for LLM request routing (cost control, multi-provider, semantic
  caching); PII masking and prompt guardrails for compliance
- Phase 2 (Next): RAG pipeline deployment; AI observability dashboards; token budget governance
  per team
- Phase 3 (Later): AI Agent integration as central hub; full API + AI platform consolidation
- Key metrics: token cost reduction, AI-related security incidents, latency by model, time for
  dev teams to ship AI features

---

## What Kong Does NOT Do (Avoid Overclaiming)

- Kong is not an ESB (Enterprise Service Bus) — it is not a message transformation or orchestration
  layer. Flag any Initiative implying transformation logic as [VERIFY].
- Kong Gateway alone is not a full API management lifecycle tool — design lives in Insomnia,
  analytics in Konnect. A "full API lifecycle" Initiative requires multiple products.
- Kong Mesh operates at L7 — it is not a replacement for network-layer (L3/L4) security.
- Kong does not manage raw TCP protocols natively. gRPC and WebSockets are supported.
- Kong does not do API monetization billing natively — integrations with billing systems are
  required.
- Kong AI Gateway does not replace the underlying LLM — it governs, secures, and optimizes access
  to LLMs provided by third parties.

Flag any Initiative that implies Kong capabilities outside this scope as [VERIFY].
