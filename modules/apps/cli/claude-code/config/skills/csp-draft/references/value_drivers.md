# Kong Value Drivers — GOSIM Reference

This file is the authoritative mapping between Kong's four value drivers and the GOSIM framework.
Use it during **Step 2 (GOSIM Extraction)** to enrich Objectives with value-driver language and during
**Step 3 (Gap Flags)** to select persona-appropriate discovery questions.

## How to Use This File

1. **Identifying Objectives**: When extracting Objectives from customer inputs, check each candidate
   against the four value drivers below. A well-formed Objective will map to at least one driver.
   If a candidate Objective doesn't map to any driver, flag it as [CAPTURE] — it's likely too vague
   or misclassified.

2. **Enriching Objectives**: If an Objective is directionally correct but missing language, use the
   **Future State / Positive Business Outcomes** section to sharpen it. Use the **Metrics** section
   to suggest measurable outcomes when the customer hasn't specified any.

3. **Identifying Strategies**: The **Required Capabilities** section describes vendor-neutral
   architectural and process decisions the customer needs to make. These are Strategy candidates —
   not Kong products.

4. **Populating Initiatives**: The **Kong Capabilities** section in each driver maps to the I layer.
   Cross-reference with `kong_capabilities.md` for full product detail.

5. **Gap discovery questions**: Organized by persona AND by GOSIM stage (Before/After/Capabilities
   & Metrics). Select the 2–3 most relevant questions for the customer's specific context.
   Always adapt them — replace "X" with the company name and reference specific gaps.

---

## Value Driver 1: Reduce Cost

**Overview**: Reduce tooling, project, and workforce costs across multiple areas of the business.

**As a GOSIM Objective, this sounds like**:
> "[Owner] to reduce total API platform cost by [X]% / [$Y] by [date], measured by [metric]."

### Current State Signals (Before Kong)
Look for these in discovery notes, sales docs, or web research — they indicate this driver is active:
- High cost legacy incumbent solutions (MuleSoft, Apigee, IBM DataPower)
- Multiple tools for various API platform tasks (fragmented tooling spend)
- Self-managed API infrastructure with high ops overhead
- Slow, costly software development lifecycle (SDLC)
- Manual change management processes causing frequent failures
- Difficulty resourcing and maintaining projects in a disjointed environment

### Negative Consequences (current-state urgency language)
Use these to validate the Goal and build the "why now" case:
- High total cost of ownership; too much time maintaining legacy systems
- Frequent and high-cost failures due to manual change management
- Difficulty resourcing and maintaining projects in a disjointed environment
- Forced to spend more money building or buying new solutions for new use cases

### Future State / Positive Business Outcomes (Objective language)
Use these to draft the Objective statement when the customer hasn't specified one:
- Predictable, lower cost through scalable architecture and lower overhead
- Drastic cost savings and efficiencies — reinvest to drive innovation vs. "keeping the lights on"
- Ability to leverage modern architectures for business durability and scalability
- Reduced overhead for engineering personnel
- Reduced cost of non-compliance and breaches

### Required Capabilities → Strategy Candidates
These are vendor-neutral — they belong in **S**, not **I**:
- Support for synchronous and asynchronous API patterns
- Support for modern, event-based communication patterns
- Support for microservices communication via ingress controller and service mesh
- Full API lifecycle management from design to deprecation
- External, internal, and service-to-service connectivity patterns
- Modern deployment models including SaaS, hybrid, and multi-cloud
- Extensible platform that addresses new/changing business needs without new tooling

### Kong Capabilities → Initiative Candidates
These are Kong-specific — they belong in **I**:
- **Unified API Platform (Konnect)**: Consolidates API Gateway, AI Gateway, Event Gateway, Ingress
  Controller, and Service Mesh into one platform — eliminating multi-tool spend
- **Dedicated Cloud Gateways (DCGW)**: Offload infrastructure costs to cloud without sacrificing
  security or multi-cloud flexibility
- **Automated Deployments / APIOps**: CI/CD, IaC, Kubernetes Operator, decK CLI — reduces manual
  ops overhead and delivery time/cost
- **Service Catalog**: Automates service discovery and scoring — reduces redundant API builds
- **Developer Portal**: Reduces time and cost spent searching for or duplicating APIs in the SDLC
- **AI Gateway — Semantic Caching / Token Budgets**: Reduces LLM token costs without custom infra

### Metrics (pre-populated defaults — validate with customer)
- $ total cost / TCO (baseline required)
- Compute cost per transaction
- Ongoing delivery time / cost
- Improvement in eNPS / developer job satisfaction scores
- Reduction in operational overhead (FTE hours)
- Time to initial value for new projects
- Fewer and lower-cost defects
- Time and cost to enter new markets

### Discovery Questions by Persona

**Executive/VP — Before (Current State / Negative Consequences)**
- "Walk me through how responding to a competitor or major industry shift has looked at [Company] in
  the past. How did [Company] mobilize Engineering resources to respond? When you think about a
  situation like this today, how do tighter budgets and market preference for high efficiency change
  how you'd respond?"
- "You've identified cost savings and efficiencies as a major driver. How are you going to balance
  this priority with the often-desired 'let every dev bring on whatever tools they want' approach?"

**Executive/VP — After (Future State / Positive Outcomes)**
- "Have you had any conversations around looking into what tooling already exists and exploring areas
  of redundancy and consolidation? If so, how have those conversations gone?"

**Executive/VP — Capabilities and Metrics**
- "At what point does cost efficiency from consolidation outweigh the benefit of giving devs the
  freedom to choose their own tools? How many different API and AI tools do you need to eliminate?"

**Platform Owner — Before**
- "When you're handed a list of new priorities from your executives, how are you all working together
  to ensure projects are delivered on time and at or under budget?"
- "How are you balancing a need for cost-efficiency with a desire to let Developers choose their
  own tooling?"

**Platform Owner — Capabilities and Metrics**
- "Once all the tooling is in place, walk me through your strategy around automating as much of the
  provisioning and interaction with that tooling. How is that playing into an overall strategy of
  cost reduction?"
- "How do you think about the cost implications of bridging the gap between API producer and consumer?"

**AI Team — Before**
- "You've been given a mandate to innovate with AI. Walk me through early strategic conversations
  around requirements for timing, budget constraints, compliance, and ROI expectations. How does the
  org plan to make AI projects more powerful via new LLMs without blowing cost structures?"

**AI Team — After**
- "Let's imagine the projects run without any problems — what does [Company]'s R&D function now
  look like?"

**AI Team — Capabilities and Metrics**
- "The AI project succeeds — how did you get here? What people, process, and technology changes did
  you make to drive success and cost efficiency? How did things like token-based rate limiting and
  semantic caching play into this?"

---

## Value Driver 2: Strengthen Security Posture

**Overview**: Avoid sacrificing security and compliance for the sake of rapid delivery and innovation.

**As a GOSIM Objective, this sounds like**:
> "[Owner] to achieve [compliance standard / security score / breach reduction target] by [date],
> measured by [metric]."

### Current State Signals (Before Kong)
- Legacy tooling with legacy security implementations — poor security posture by default
- Significant "unknowns" in API security posture (ungoverned APIs)
- Spending more time plugging security holes than building new products
- Can't enter markets with higher security standards/regulations
- AI projects held back by security and compliance concerns
- Poor relationship between security teams and developers
- Lengthy, manual security reviews
- Prevented from moving to the cloud due to compliance concerns

### Negative Consequences
- Costly breaches and higher cyber insurance premiums
- Poor customer trust and loss of market share
- Slower release cycles due to security bottlenecks
- Poor DevEx — devs working around security standards
- Costly self-hosted infrastructure setups

### Future State / Positive Business Outcomes
- Lower cyber insurance premiums
- Reduction in breaches; more confidence shipping fast
- Faster releases and improved time-to-market
- More revenue from new markets (especially regulated industries)
- Competitive advantage over competitors with slow security processes
- Lower infrastructure and security costs
- Visibility into every API and service and how it's secured
- Security baked into the entire API lifecycle via guardrails
- Automated security review — friendly to both Devs and Security teams

### Required Capabilities → Strategy Candidates
- Flexible deployment models: cloud-based, hybrid, fully self-hosted
- Compliance with industry security standards
- Automated discovery of all APIs and services
- Automated security scanning and measurement for APIs and services
- Ability to define and automate enforcement of security guardrails
- Audit trail of all in-platform activities
- Threat protection policies and runtime logic
- Strict RBAC for platform stakeholders

### Kong Capabilities → Initiative Candidates
- **Self-Hosted / Hybrid Gateway**: Control plane managed by Kong, data plane self-managed — full
  security compliance without sacrificing cloud flexibility
- **Automated Security & Lifecycle Control (decK/APIOps)**: Security best practices enforced as
  code throughout the API lifecycle; audit trail of every commit and action
- **Advanced RBAC (Konnect)**: Fine-grained access control across teams and environments
- **Service Catalog Compliance**: Discover every API, assess compliance with security best practices
- **Dedicated Cloud Gateways**: Deploy runtime in preferred CSP/region with full control
- **Pre-built Security Policies for APIs and AI**: PII sanitization, RAG pipeline security,
  semantic caching, token-based rate limiting — no custom infrastructure required
- **Kong Mesh**: Zero-trust east-west service-to-service traffic via mTLS

### Metrics (pre-populated defaults — validate with customer)
- Time to market (TTM) / release cycle time
- Speed to compliance with regulations
- $ spent on cyber insurance (before/after)
- # of APIs under known management (coverage %)
- Security score across API ecosystem
- # of security incidents / breaches
- Developer satisfaction with security processes (eNPS proxy)

### Discovery Questions by Persona

**Executive/VP — Before**
- "How are you balancing a growing need to innovate, especially in AI, with a growing need to ensure
  your API security posture is strict?"
- "Where is API Security owned today? How are teams ensuring that every API across the organization
  is accounted for and following security standards and best practices?"

**Executive/VP — After**
- "How does automating security standards and enforcement play into larger strategies around improving
  time to market?"

**Executive/VP — Capabilities and Metrics**
- "When you run your retro on a successful major project, what are you pointing to to prove that
  Engineering was as efficient as possible?"
- "How are you currently measuring the overall API security posture at your organization? Are there
  metrics you look at? Are they project-specific?"

**Platform Owner — Before**
- "Where is API Security owned today? How are teams ensuring that every API across the organization
  is accounted for and following security standards?"
- "Walk me through where you have the most concern about Engineers following API Security best
  practices. How often do you think your Developers are thinking about the OWASP Top 10?"
- "How do you handle tough conversations with Developers around making changes to their APIs today?"

**Platform Owner — After**
- "Walk me through how API Security plays into the larger API Platform strategy."
- "How are you balancing enforcing security standards with Engineering velocity? How does this factor
  into choosing between a unified platform or a multi-tool strategy?"

**Platform Owner — Capabilities and Metrics**
- "Walk me through the north star metrics for Platform initiatives at your company. For example,
  Rabobank actively measures Developer Satisfaction and time to market before and after. Are you
  doing anything like this?"
- "Once all the tooling is in place, walk me through your strategy around making sure everything is
  secure and only the right people can access the right infrastructure and functionality. How are you
  going to prove that your platform is secure?"

**AI Team — Before**
- "You've been given a mandate to innovate with AI. Walk me through early strategic conversations
  around requirements for security and compliance. How well does leadership understand the technical
  complexities of making innovation happen quickly with strict security requirements?"

**AI Team — After**
- "Let's imagine the projects run without any problems — what does [Company]'s R&D function now look
  like, especially as it pertains to balancing DevEx with strict security and compliance concerns?"

**AI Team — Capabilities and Metrics**
- "The AI project succeeds — how did you get here? What people, process, and technology changes did
  you make? How were security and compliance handled, and how do you prove it to leadership?"

**Security Team — Before**
- "Where is API Security owned today? How are teams ensuring every API is accounted for and following
  security standards and best practices?"
- "Walk me through where you have the most concern about Engineers following API Security best
  practices. How often do you think Developers are thinking about OWASP Top 10 API threats?"
- "How do you handle tough conversations with Developers around making changes to their APIs?"

**Security Team — After**
- "Imagine you get automated visibility and security scoring for every API and service running. How
  does this work into your overarching security goals at [Company]?"

**Security Team — Capabilities and Metrics**
- "What metrics or measurements do you point to in order to prove a strict security posture?"

---

## Value Driver 3: Enhance Developer Productivity & Developer Experience (DevProd & DevEx)

**Overview**: Make your business a more developer-friendly organization by giving developers the
tools they need to get their jobs done more efficiently.

**As a GOSIM Objective, this sounds like**:
> "[Owner] to improve developer time-to-value by [X]% (measured by [metric]) by [date], reducing
> engineering toil and enabling self-service API consumption."

### Current State Signals (Before Kong)
- Organizational inefficiency and friction — technical debt and siloed teams
- Inconsistent operator/developer experience deploying and maintaining applications
- Difficult API consumption experience — frustration, lack of API reuse and discoverability
- Lack of reproducibility and portability across environments
- Inability to introduce new products relying on AI or new communication patterns
- Bottlenecks due to legacy API team practices and gatekeeping

### Negative Consequences
- Tech debt and engineering toil consuming developer capacity
- Low developer productivity — inefficiencies cascading through delivery
- Poor DevEx leading to difficulty retaining top engineering talent
- Frequent bugs and system failures from fragmented processes
- Forced to spend more building or buying new solutions for new use cases
- Slower time to market
- Opened up for disruption by competitors moving faster

### Future State / Positive Business Outcomes
- Better Developer Satisfaction and talent retention
- Lower risk of quality, performance, and resilience issues
- Reduced overhead for engineering personnel
- Ability to rapidly scale teams based on reuse and common architectural patterns
- Faster time to enter new markets
- Developers can self-serve everything they need to build new APIs and API-driven products
- Rapid time to product and feature delivery through API reuse and discoverability

### Required Capabilities → Strategy Candidates
- Self-serve access for developers to spin up API and connectivity infrastructure
- Self-serve access for developers to find APIs they need to build apps
- Automated service discovery and governance
- Rich support for automation and governance of infrastructure as code (IaC)
- Modern deployment models: SaaS, hybrid, multi-cloud
- Pre-built policies and business logic (eliminate custom boilerplate)

### Kong Capabilities → Initiative Candidates
- **Developer Portal (Konnect)**: Next-gen self-serve API catalog — brings producers and consumers
  together; OpenAPI/AsyncAPI spec rendering; supports synchronous, event, and LLM APIs
- **Service Catalog**: Automates service discovery, inventory, and scoring across the org;
  continuous visibility; eliminates manual reviews
- **Automating / Governing API Platform as Code (decK, Kubernetes Operator, Admin API)**: Full
  APIOps and IaC for managing the entire platform declaratively
- **Self-Service Offerings (Konnect)**: Spin up and manage AI Gateways, Event Gateways, Service
  Meshes, and Ingress Controllers through self-service
- **Dedicated Cloud Gateway**: Engineers deploy runtime in their preferred CSP/region — self-serve
  without ops bottleneck
- **Serverless API Gateways**: Simplest, most cost-efficient way for devs to spin up gateways for
  non-prod use cases
- **Pre-built Policies**: AI and LLM use cases (PII sanitization, RAG pipelines, semantic caching,
  token-based rate limiting) — eliminates custom business logic
- **Auto RAG (AI Gateway)**: Only platform to natively support Auto RAG — removes friction for AI
  service developers

### Metrics (pre-populated defaults — validate with customer)
- Ongoing delivery time / cost (release cycle time)
- eNPS / developer job satisfaction score
- Reduction in operational overhead (FTE hours saved)
- Time to initial value for new API projects
- Fewer and lower-cost defects
- Time and cost to enter new markets
- # of new projects delivered per quarter
- New customer acquisition influenced by platform
- Product backlog acceleration rate

### Discovery Questions by Persona

**Executive/VP — Before**
- "Walk me through how responding to a competitor or major industry shift has looked at [Company]
  in the past. How did [Company] mobilize Engineering resources? If this happened again, where would
  there be greater opportunities to make those Engineering resources even more productive?"

**Executive/VP — After**
- "How does a great Developer Experience play into the success of your major technology initiatives?
  What does recruitment and retention of engineers mean to your org?"
- "Where do you see Developer Experience and Productivity driving greater cost efficiencies?"

**Executive/VP — Capabilities and Metrics**
- "When you run your retro on a successful major project, what are you pointing to to prove
  Engineering was as efficient as possible? Specifically, what is the board looking for?"
- "How are you currently measuring the overall Developer Experience at your organization?"

**Platform Owner — Before**
- "When you're handed a list of new priorities from your executives, how are you working together
  to ensure projects are delivered on time?"
- "How are you balancing a need for productivity and efficiency with a desire to let Developers
  choose their own tooling?"
- "Explain the challenges you might have today related to bringing API producers and consumers
  together. What does a typical workflow look like between when a backend API is built and when a
  consumer starts using it?"

**Platform Owner — After**
- "Walk me through your strategies to get the best possible API solutions in the hands of your
  Developers."
- "What is the impact radius of a shortened time between API design and API discovery and
  consumption? Where are efficiencies gained across the business?"

**Platform Owner — Capabilities and Metrics**
- "Walk me through the north star metrics for Platform initiatives at your company. Rabobank actively
  measures Developer Satisfaction and time to market before and after. Are you doing anything like this?"
- "Once all the tooling is in place, walk me through your strategy around automating as much of the
  provisioning and interaction with that tooling. How is that playing into the overall DevEx?"
- "How do you plan to reduce the time between API design and API consumption? Where and how is this
  being measured? How is it being linked to overall business metrics like time to market?"

**AI Team — Before**
- "You've been given a mandate to innovate with AI. Walk me through early strategic conversations
  around requirements for timing, budget constraints, compliance, and ROI. How does the org plan to
  make AI projects more powerful via new LLMs without overburdening Engineers?"

**AI Team — After**
- "Let's imagine the projects run without any problems — what does [Company]'s R&D function now look
  like, especially as it pertains to Developer Experience? How does it improve the DevEx for the
  Developer building AI services? How does it improve the DevEx of the Developer consuming them?"

**AI Team — Capabilities and Metrics**
- "The AI project succeeds — how did you get here? What people, process, and technology changes did
  you make? How was the Developer Experience materially improved? And how do you prove it to
  leadership?"

---

## Value Driver 4: Innovate Faster

**Overview**: Enable your business to take the raw materials of innovation (APIs, AI, microservices,
real-time data) and turn them into competitive differentiation.

**As a GOSIM Objective, this sounds like**:
> "[Owner] to [launch X AI/API capability / reach Y% faster release cycles / enter Z new market]
> by [date], measured by [ROI metric / release cycle time / competitive win rate]."

### Current State Signals (Before Kong)
- Unable to turn investments in innovative practices (API-first, AI, real-time/EDA) into actual
  business value
- Slow to react to changing market conditions and competitive pressure
- Siloed legacy code and infrastructure slowing engineering down
- Inability to discover and reuse existing capabilities to drive innovation
- New Engineering projects seen as massive cost centers rather than value drivers

### Negative Consequences
- Loss of market share to competitors
- Losing customers and revenue
- High costs to enter new markets
- Negative brand impact from sub-par user experience
- Difficult to retain and attract technical talent
- Reduced developer productivity
- Future strategic direction constrained by past technical decisions

### Future State / Positive Business Outcomes
- Gain competitive advantage: access new markets and expand in existing ones
- Retain existing customer base (remain unconquerable)
- Cost-effective: lower cost and decreased risk of project failure
- Attract top talent while increasing employee satisfaction
- Protect brand value and customer experience
- Faster time to value/profitability for new projects
- Engineering and their new projects are seen as massive value centers for the business
- Rapid and effective responses to new market pressures
- Driving more and more ROI on past efforts through reusability of existing resources

### Required Capabilities → Strategy Candidates
- Confidence that the vendor will stay ahead of market trends
- Solutions for AI governance, security, and overall AI readiness
- Cloud-native and multi-cloud ready infrastructure
- Infrastructure as Code support that plugs into existing CI/CD dev tools
- Federated, self-serve platform capabilities
- Platform support for all API patterns: REST, microservices, AI/LLM/agentic, event-driven,
  and future trends
- Everything must be done in a secure, compliant manner

### Kong Capabilities → Initiative Candidates
- **AI Gateway**: Secure, centralized API access to LLMs — more feature-complete when integrated
  with the broader platform; most feature-complete solution in the market
- **Deployment Flexibility**: The most cloud-ready, deployment-agnostic platform — self-hosted,
  hybrid, and fully cloud-based; no other vendor offers this range
- **Multi-Cloud (AWS, Azure, GCP)**: Dedicated Cloud Gateway lets engineers set up runtime
  infrastructure in any CSP and region
- **Infrastructure as Code (Kubernetes Operator, decK CLI, Admin API)**: More automation options
  than any other vendor; deeply integrated across the platform
- **Provisioning / Self-Service (Konnect)**: One-stop platform for API provisioning; most
  customizable and API productization-ready Developer Portal in the market
- **RAG Pipelines**: Only platform to offer built-in RAG pipeline setup — seamless AI workflows
- **AI Agent Integration**: Kong as central hub for AI agents to consume APIs — automates business
  processes and drives efficiency
- **All-in-One Platform**: Only true API Platform supporting all communication patterns, API styles,
  and protocols — all API runtime infrastructure needed to drive innovation in one solution

### Metrics (pre-populated defaults — validate with customer)
- ROI for API, microservices, AI, and real-time data projects (NPS, influenced/attached revenue,
  competitive win rate)
- Release cycle time (internal efficiency)
- Change in # of features released per release cycle
- Share of TAM (total addressable market)
- Uptime/downtime for business-critical services
- Developer efficiency metrics

### Discovery Questions by Persona

**Executive/VP — Before**
- "Walk me through how responding to a competitor or major industry shift has looked at [Company] in
  the past. How did [Company] mobilize Engineering resources to respond?"
- "You've identified [focus area — AI, real-time data, etc.] as the technical asset driving most
  innovation and value. How are you making sure these projects don't chew through budgets, result in
  compliance/security risks, take too long to roll out, or introduce unnecessary load on Engineers?"

**Executive/VP — After**
- "Let's imagine the projects run without issue — what does [Company] now look like? How does this
  translate into value for your customers? Your staff? And what does this mean for [Company]'s
  competitors?"

**Executive/VP — Capabilities and Metrics**
- "Walk me through the major technical initiatives that will drive success here. How are you planning
  to make sure these initiatives succeed? What did you measure and what did those metrics look like
  on the way to success?"

**Platform Owner — Before**
- "Walk me through the main areas of new investment for your executives and how you're planning to
  proactively address related challenges and concerns for Engineering teams."
- "When your execs talk about capturing opportunities for innovation, how likely is it that they
  directly attach the success of those initiatives to work you all are doing?"
- "When you're handed a list of new priorities from executives, how are you working together to
  ensure projects are delivered on time and at or under budget?"

**Platform Owner — After**
- "Let's imagine the projects run without issue — what would [Company]'s R&D function look like?
  How does this translate into value for customers and staff? What does this mean for future
  technical or AI projects?"

**Platform Owner — Capabilities and Metrics**
- "When you think about [focus area for innovation], walk me through your top three areas of
  prioritization. How are you going to explain your reasoning to leadership?"
- "Let's break down one of these top priorities. What do you and your various stakeholders need to
  be successful? When it succeeds, how are you going to prove the value to leadership — is there a
  dashboard or number you point to?"
- "How often is leadership thinking about these areas? How well do they understand the relationship
  between what you're doing and where they want the business to go — especially with something as
  new as AI?"

**AI Team — Before**
- "You've been given a mandate to figure out how your organization is going to innovate with AI.
  Walk me through early strategic conversations around requirements for timing, budget constraints,
  compliance, and ROI. How well does leadership understand the technical complexities given these
  requirements? How are you currently equipping teams to deliver against them?"

**AI Team — After**
- "Let's imagine the projects run without issue — what would [Company]'s R&D function look like?
  How does this translate into value for customers and staff? What does this mean for future
  technical or AI projects?"

**Developer — Before**
- "Walk me through the existing challenges your org has around either getting new services to
  production quickly or making those services easily discoverable by consumers once built."
- "As your organization and leadership talk about innovation and AI, how do you feel the Developer
  Experience is being prioritized? Walk me through areas where this could be better."

**Developer — After**
- "Walk me through how your organization's innovation priorities affect you positively. How is your
  life better once these projects succeed?"
- "How do you hope leadership thinks about the work you do and how it drives overall business success?"

**Developer — Capabilities and Metrics**
- "You're tasked with [focus area for innovation]. Walk me through the three things you're hoping to
  get from Kong to make the jobs to be done here less difficult. If your leadership asks why you
  need these things, how are you making that case to them?"
- "Were there any specific technical initiatives or projects across different teams that you kept a
  close eye on? How might they have been measured differently from others?"

---

## Multi-Driver Patterns

Some customers will have 2–3 active value drivers simultaneously. Common combinations:

**Reduce Cost + Strengthen Security Posture**
Common in: regulated industries (financial services, pharma, healthcare) consolidating legacy
infrastructure. The Goal is often something like "modernize the API platform to reduce TCO while
meeting stricter compliance requirements." Both Objectives coexist; security investment is framed
as enabling cost reduction (lower insurance premiums, fewer breach costs).

**Innovate Faster + Enhance DevProd & DevEx**
Common in: high-growth tech companies, digital-first organizations investing in AI. The Goal is
often competitive differentiation. Developer Experience is the enabler for innovation velocity —
frame DevProd/DevEx as the Strategy-layer answer to "how do we innovate faster."

**All Four Drivers**
Common in: large enterprise transformation programs (3–5 year platform plays). When all four are
present, the CSM must select the ONE Goal that unifies them all (usually the board-level strategic
direction) and treat each driver as a distinct Objective with its own owner, deadline, and metrics.
Do not collapse them into a single Objective.

---

## Value Driver → GOSIM Cheat Sheet

| Value Driver | G (informs) | O (is) | S (Required Capabilities) | I (Kong products) | M (default metrics) |
|---|---|---|---|---|---|
| Reduce Cost | Platform cost is constraining innovation | Achieve X% TCO reduction by [date] | Unified platform, IaC, multi-cloud deployment model | Konnect, DCGW, decK/APIOps, Service Catalog, Developer Portal | TCO, compute cost/tx, delivery time, eNPS |
| Strengthen Security Posture | Cannot enter new markets / ship fast due to security debt | Achieve [compliance target] / reduce breach risk by [date] | Automated discovery, security-as-code, RBAC, audit trail, flexible deployment | Self-hosted/hybrid GW, Kong Mesh (mTLS), Konnect RBAC, AI security policies | TTM, # APIs governed, security score, breach $, insurance $ |
| Enhance DevProd & DevEx | Engineering talent and velocity are constraining growth | Achieve X% improvement in developer time-to-value by [date] | Self-serve infra, automated governance, IaC, pre-built policies | Developer Portal, Service Catalog, Serverless GW, decK, pre-built AI policies | eNPS, delivery time, time to API consumption, defect rate |
| Innovate Faster | Must turn tech investments into competitive advantage | Launch [capability] / reach [market] / achieve [ROI target] by [date] | Cloud-native, multi-cloud, IaC, federated self-serve, AI/EDA-ready patterns | AI Gateway, DCGW, Kubernetes Operator, Konnect self-service, RAG pipelines | ROI, release cycle time, features/release, share of TAM, uptime |
