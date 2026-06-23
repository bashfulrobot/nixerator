# Gap Discovery Questions

Use these questions to populate the **Gaps & Discovery** section of the CSP Draft output.

This file has two sections:
1. **GOSIM-Layer Questions** — generic questions organized by what structural element is missing
   (owner, deadline, metric, etc.). Use these for any gap regardless of value driver.
2. **Value Driver Questions** — persona-specific questions from Kong's value driver job aids,
   organized by driver and GOSIM stage. Use these when the value driver is known and you need
   questions that resonate at a specific stakeholder level.

Present the most relevant **2–3 questions** per gap, not all of them. Always adapt questions to
the customer context — replace "[Company]" with the customer name and reference the specific gap.

---

# PART 1: GOSIM-Layer Discovery Questions

---

## Goals — Discovery Questions

Use when Goals are [MISSING], [VERIFY], or [CAPTURE] (too vague or at the wrong level).

**The core technique — eliciting the departmental Goal:**
The CSP Goal is not the company's mission statement — it is the executive stakeholder's answer to
"how does my function contribute to the company's strategy?" Come to the conversation prepared with
the company's public strategic direction, present it, and ask the exec directly. Their answer is the
Goal.

Step 1 — Present the company context:
- "I was reading [Company]'s annual report / latest press release / CEO's blog post and I noticed
  [Company] is focused on [company-level strategic direction]. Is that a fair characterization of
  where the business is headed?"

Step 2 — Ask the one-rung-down question:
- "So how does your team / department / function contribute to that? What would you consider your
  overarching goal in helping the company get there?"
- "If you had to articulate what your function's north star is in service of that company direction
  — what would it be?"
- "What does success look like for your org specifically over the next 12–18 months, in terms of
  how you're contributing to [company's stated direction]?"

Step 3 — Confirm and capture in their language:
- "So if I were to summarize it — your goal is to [paraphrase back]. Does that feel right?"
- Use their exact words wherever possible. The Goal should sound like them, not like a Kong deck.

**When the Goal is missing entirely [MISSING]:**
- "Before we get into the specifics of what we're building together — help me understand what
  you're ultimately trying to achieve in your role over the next year or two. What does a win
  look like for your team?"
- "If this engagement goes exactly as planned, what changes for your function? What can you do
  12 months from now that you can't do today?"
- "What's driving the urgency behind this initiative — what happens if nothing changes in the
  next 12 months?"

**When the Goal is too high / corporate-level [CAPTURE]:**
This happens when the CSM has captured the company's mission statement rather than the executive
stakeholder's departmental goal. The Objectives won't connect to it credibly.
- "That's the company's north star — I want to make sure we're also capturing what that means
  specifically for your team. How does your department contribute to [company goal]?"
- "If your CEO is focused on [company goal], what's the version of that that your function owns?
  What do you need to deliver for that to happen?"

**When the Goal is too tactical / looks like a Strategy or Initiative [CAPTURE]:**
- "If we stepped back from the API work for a moment — what business problem is this solving?
  What does it unblock for the business?"
- "Can you help me translate this into the outcome your leadership cares about — not the technical
  approach, but the business result?"
- "What would your CTO / VP / exec sponsor say if you asked them why this work matters to the
  company?"

**Probing for unstated pressure:**
- "Are there competitive pressures, regulatory requirements, or internal mandates shaping the
  direction for your function right now?"
- "Who owns this outcome — is there a named executive who has put their name on it?"
- "Where does this initiative sit in terms of company priority — is it a top-3 initiative for the
  year, or one of twenty things in flight?"

---

## Objectives — Discovery Questions

Use when Objectives are missing a required element (owner, deadline, or measurable outcome).

**Missing owner:**
- "Who in your organization is accountable for this outcome — not just supportive of it, but has
  it in their OKRs or performance review?"
- "If this doesn't get done by [date], who gets the call from leadership?"

**Missing deadline:**
- "Is there a hard date this needs to land by — a product launch, a regulatory deadline, a board
  review?"
- "What's the natural forcing function here? What event or milestone creates urgency?"

**Missing measurable outcome:**
- "How would you define 'done' for this objective? What does success look like at the end of the
  period?"
- "If you had to put a number on it — what would success be? A headcount reduction, a time saved,
  a revenue target?"
- "What would your sponsor point to in a business review as evidence this worked?"

**General Objective-setting:**
- "You've described a few areas of focus. If you had to rank-order these by business impact, which
  one is the non-negotiable for this fiscal year?"
- "Is there a version of this where partial success is still acceptable — or is it all-or-nothing?"

**When an Objective doesn't map to a known value driver ([CAPTURE]):**
- "Can you help me understand what problem this is solving for the business — not just for
  Engineering? What's the impact if this doesn't get done?"
- "How would your CFO or COO describe this initiative if they were presenting it to the board?"
- See `references/value_drivers.md` — check whether this Objective maps to Reduce Cost,
  Strengthen Security Posture, Enhance DevProd & DevEx, or Innovate Faster. If it doesn't map
  to any driver, it may be a Strategy misplaced as an Objective.

---

## Strategies — Discovery Questions

Use when Strategies are [MISSING] or seem to be guessed rather than confirmed.

**Architecture / operating model:**
- "How are you thinking about API ownership across your teams — do you have a central platform
  team, or is it federated? Or somewhere in between?"
- "What's your current stance on standardization vs. team autonomy when it comes to API design
  and runtime?"
- "Are you moving toward a microservices architecture, or is that already your current state?"
- "How are you handling east-west service traffic today — and is that changing?"

**Build vs. buy / vendor posture:**
- "How does your organization think about buying platforms vs. building tooling internally?"
- "Are there architectural principles — like cloud-first, zero-trust, or API-first — that govern
  your decisions here?"

**Organizational strategy:**
- "Is there a platform team model in play, or are you still working out who owns shared
  infrastructure?"
- "How do developer teams currently consume APIs — do they have a discovery mechanism, or is
  it largely informal?"

**Confirming what was surfaced from documents:**
- "We found references to a [federated model / cloud-first principle / zero-trust initiative] in
  your materials — is that an accurate description of your current strategy, or has it evolved?"

**When all Strategies look like Kong products (common CSP error):**
- "Before we talk about specific Kong capabilities — what architectural decisions has your team
  already made, independent of vendor? For example, have you decided to go hybrid cloud? To
  adopt a platform team model? To move toward IaC?"
- "The decisions in this column should be vendor-neutral — they should be true regardless of
  whether you chose Kong or a competitor. What are those?"

---

## Initiatives — Discovery Questions

Use when Initiatives are vague, missing phase/scope, or can't be traced to a Strategy or Objective.

**Scoping and phasing:**
- "Where are you in the deployment journey — is this greenfield, a migration, or expanding an
  existing footprint?"
- "What's in scope for Phase 1 vs. what comes later? Is there a natural first win you want to
  point to?"
- "Which teams or environments are included in the initial rollout — and which are explicitly out
  of scope for now?"

**Tracing to business value:**
- "For each of these initiatives — what Objective does it directly move the needle on?"
- "Is there an initiative here that's a prerequisite for everything else? What's the critical
  path?"

**Kong-specific capabilities:**
- "Are there specific Kong capabilities you're expecting to leverage — like the Dev Portal, Mesh,
  AI Gateway, or Konnect's analytics?"
- "Have you scoped the authentication/authorization requirements yet — OIDC, mTLS, RBAC?"
- "Is there a plugin or integration requirement we should know about now, before we lock in the
  design?"

---

## Metrics — Discovery Questions

Use when Metrics are missing baseline, target, owner, or cadence — or when Metrics only measure
Kong configuration (not business outcomes).

**Missing baseline:**
- "Do you have current-state data on [metric] — even a rough estimate? If not, is establishing a
  baseline something we should plan for in Phase 1?"
- "What does this look like today? Even a directional 'way too slow' or '5 incidents last quarter'
  helps us start somewhere."

**Missing target:**
- "What would good look like, in your mind? Is there an industry benchmark you're comparing
  against, or an internal target?"
- "Is there a number your leadership has committed to externally — like in an investor presentation
  or SLA commitment?"

**Missing owner:**
- "Who will be tracking this in your organization — and will they have the data they need to
  report on it?"

**Missing cadence:**
- "How often should we be reviewing this together — monthly, quarterly, at key milestones?"
- "Is this a metric that lives in a business review, or is it more of an engineering dashboard?"

**Business outcome metrics (when CSP only has technical metrics):**
- "Beyond deployment metrics — what business outcomes should this be moving? Revenue? Customer
  retention? Developer velocity?"
- "How does your business leader measure the value of what we're doing together? What do they
  look at?"

**Suggesting metrics by value driver (when customer hasn't specified any):**
- Reduce Cost → suggest: TCO, compute cost per transaction, delivery time/cost, eNPS, time to
  initial value. Ask: "Are any of these the right starting point for how you'd measure success?"
- Strengthen Security Posture → suggest: # APIs under known management, security score, TTM,
  cyber insurance spend, # breaches. Ask: "Which of these does your security leadership already
  track?"
- DevProd & DevEx → suggest: eNPS, delivery time, time from API design to consumption, defect
  rate, # new projects delivered. Ask: "How are you currently measuring Developer Experience —
  is there a satisfaction score or productivity metric you report on?"
- Innovate Faster → suggest: release cycle time, features per release, ROI on AI/API projects,
  share of TAM, uptime. Ask: "How does leadership measure whether these innovation investments
  are paying off?"

---

## Champions — Discovery Questions

Use when champion information is absent or unclear.

**Identifying the champion:**
- "Who is your internal champion for this initiative — someone who has skin in the game and will
  advocate for it when you're not in the room?"
- "Is there someone on your team we should be building a relationship with at every level —
  technical, business, and executive?"

**Champion strength:**
- "How embedded is [champion name] in the decision process — do they have budget authority, or
  are they more of an influencer?"
- "Who does [champion name] need to bring along internally for this to succeed? Is there a
  skeptic we should be aware of?"

**Multi-stakeholder mapping:**
- "Beyond [champion], are there other key stakeholders — procurement, security, a competing
  vendor relationship — who will shape how this goes?"

---

## Executive Sponsor / Quote — Discovery Questions

Use when no exec quote or sponsor is identified for the L1 Strategic Anchor header.

- "Who is the executive sponsor of this initiative — and can you get me a sentence from them on
  why this matters?"
- "What's the language your CTO / VP Engineering / CDO uses when they talk about this program
  to their peers?"
- "Is there a public statement — earnings call, blog post, press release — where your leadership
  has described this initiative?"
- "If we were crafting a headline that your executive sponsor would be proud to have attributed
  to them, what would it say?"

---

# PART 2: Value Driver Discovery Questions (by Persona)

Use these when the active value driver is known and you need persona-resonant questions at a
specific GOSIM stage. These come directly from Kong's value driver job aids.

Select based on: (a) which driver is active, (b) who you're talking to, and (c) which GOSIM stage
the gap is at (Before = Current State / Objectives context; After = Future State / Outcomes;
Capabilities & Metrics = Strategies, Initiatives, Metrics).

---

## Reduce Cost

### Executive/VP
**Before (Current State / Negative Consequences)**
- "Walk me through how responding to a competitor or major industry shift has looked at [Company]
  in the past. How did [Company] mobilize Engineering resources? When you think about a situation
  like this today, how do tighter budgets and market preference for efficiency change how you'd
  respond?"
- "You've identified cost savings and efficiencies as a major driver. How are you going to balance
  this with the often-desired 'let every dev bring on whatever tools they want' approach?"

**After (Future State / Positive Outcomes)**
- "Have you had conversations about looking into what tooling already exists and exploring areas of
  redundancy and consolidation? How have those conversations gone?"

**Capabilities and Metrics**
- "At what point does cost efficiency from consolidation outweigh the benefit of giving devs
  freedom to choose their own tools? How many different API and AI tools do you need to eliminate?"

### Platform Owner
**Before**
- "When you're handed a list of new priorities from your executives, how are you working together
  to ensure projects are delivered on time and at or under budget?"
- "How are you balancing a need for cost-efficiency with a desire to let Developers choose their
  own tooling?"

**Capabilities and Metrics**
- "Once all the tooling is in place, walk me through your strategy around automating as much of
  the provisioning and interaction with that tooling. How is that playing into an overall strategy
  of cost reduction?"
- "How do you think about the cost implications of bridging the gap between API producer and
  consumer?"

### AI Team
**Before**
- "You've been given a mandate to innovate with AI. Walk me through early strategic conversations
  around requirements for timing, budget constraints, compliance, and ROI. How does the org plan
  to make AI projects more powerful via new LLMs without blowing cost structures?"

**After**
- "Let's imagine the projects run without any problems — what does [Company]'s R&D function now
  look like?"

**Capabilities and Metrics**
- "The AI project succeeds — how did you get here? What people, process, and technology changes
  did you make to drive success and cost efficiency? How did things like token-based rate limiting
  and semantic caching play into this?"

---

## Strengthen Security Posture

### Executive/VP
**Before**
- "How are you balancing a growing need to innovate, especially in AI, with a growing need to
  ensure your API security posture is strict?"
- "Where is API Security owned today? How are teams ensuring every API is accounted for and
  following security standards and best practices?"

**After**
- "How does automating security standards and enforcement play into larger strategies around
  improving time to market?"

**Capabilities and Metrics**
- "When you run your retro on a successful major project, what are you pointing to to prove
  Engineering was as efficient as possible?"
- "How are you currently measuring the overall API security posture at your organization? Are
  there metrics you look at? Are they project-specific?"

### Platform Owner
**Before**
- "Where is API Security owned today? How are teams ensuring every API is accounted for and
  following security standards?"
- "Walk me through where you have the most concern about Engineers following API Security best
  practices. How often do you think Developers are thinking about the OWASP Top 10?"
- "How do you handle tough conversations with Developers around making changes to their APIs?"

**After**
- "Walk me through how API Security plays into the larger API Platform strategy."
- "How are you balancing enforcing security standards with Engineering velocity? How does this
  factor into choosing between a unified platform or a multi-tool strategy?"

**Capabilities and Metrics**
- "Walk me through the north star metrics for Platform initiatives at your company. Rabobank
  actively measures Developer Satisfaction and time to market before and after. Are you doing
  anything like this?"
- "Once all the tooling is in place, walk me through your strategy around making sure everything
  is secure and only the right people can access the right infrastructure. How are you going to
  prove your platform is secure?"

### AI Team
**Before**
- "You've been given a mandate to innovate with AI. Walk me through early strategic conversations
  around requirements for security and compliance. How well does leadership understand the technical
  complexities of making innovation happen quickly with strict security requirements?"

**After**
- "Let's imagine the projects run without any problems — what does [Company]'s R&D function now
  look like, especially as it pertains to balancing DevEx with strict security and compliance?"

**Capabilities and Metrics**
- "The AI project succeeds — how did you get here? What people, process, and technology changes
  did you make? How were security and compliance handled, and how do you prove it to leadership?"

### Security Team
**Before**
- "Where is API Security owned today? How are teams ensuring every API is accounted for and
  following security standards?"
- "Walk me through your biggest concern about Engineers following API Security best practices.
  How often do you think Developers are thinking about OWASP Top 10 API threats?"
- "How do you handle tough conversations with Developers around making changes to their APIs?"

**After**
- "Imagine you get automated visibility and security scoring for every API and service running.
  How does this work into your overarching security goals at [Company]?"

**Capabilities and Metrics**
- "What metrics or measurements do you point to in order to prove a strict security posture?"

---

## Enhance Developer Productivity & Developer Experience (DevProd & DevEx)

### Executive/VP
**Before**
- "Walk me through how responding to a competitor or major industry shift has looked at [Company]
  in the past. If it happened again, where would there be greater opportunities to make Engineering
  resources even more productive?"

**After**
- "How does a great Developer Experience play into the success of your major technology initiatives?
  What does recruitment and retention of engineers mean to your org?"
- "Where do you see Developer Experience and Productivity driving greater and greater cost
  efficiencies?"

**Capabilities and Metrics**
- "When you run your retro on a successful major project, what are you pointing to to prove
  Engineering was as efficient as possible? Specifically, what is the board looking for?"
- "How are you currently measuring the overall Developer Experience at your organization? Are
  there satisfaction metrics you look at?"

### Platform Owner
**Before**
- "When you're handed a list of new priorities from executives, how are you working together to
  ensure projects are delivered on time?"
- "How are you balancing a need for productivity and efficiency with a desire to let Developers
  choose their own tooling?"
- "Explain the challenges you have today related to bringing API producers and consumers together.
  What does a typical workflow look like between when a backend API is built and when a consumer
  starts using it?"

**After**
- "Walk me through your strategies to get the best possible API solutions in the hands of your
  Developers."
- "What is the impact radius of a shortened time between API design and API discovery and
  consumption? Where are efficiencies gained across the business?"

**Capabilities and Metrics**
- "Walk me through the north star metrics for Platform initiatives at your company. Rabobank
  actively measures Developer Satisfaction and time to market before and after. Are you doing
  anything like this?"
- "Once all the tooling is in place, walk me through your strategy around automating as much of
  the provisioning and interaction with that tooling. How is that playing into the overall DevEx?"
- "How do you plan to reduce the time between API design and API consumption? Where and how is
  this being measured? How is it linked to overall business metrics like time to market?"

### AI Team
**Before**
- "You've been given a mandate to innovate with AI. Walk me through early strategic conversations
  around requirements for timing, budget constraints, compliance, and ROI. How does the org plan
  to make AI projects more powerful via new LLMs without overburdening Engineers?"

**After**
- "Let's imagine the projects run without any problems — what does [Company]'s R&D function now
  look like, especially as it pertains to Developer Experience? How does it improve the DevEx for
  the Developer building AI services? How does it improve the DevEx of the Developer consuming
  AI services?"

**Capabilities and Metrics**
- "The AI project succeeds — how did you get here? What people, process, and technology changes
  did you make? How was the Developer Experience materially improved? And how do you prove it to
  leadership?"

---

## Innovate Faster

### Executive/VP
**Before**
- "Walk me through how responding to a competitor or major industry shift has looked at [Company]
  in the past. How did [Company] mobilize Engineering resources?"
- "You've identified [focus area — AI, real-time data, etc.] as the technical asset driving most
  innovation. How are you making sure these projects don't chew through budgets, result in
  compliance/security risks, take too long to roll out, or introduce unnecessary load on Engineers?"

**After**
- "Let's imagine the projects run without issue — what does [Company] now look like? How does this
  translate into value for your customers? Your staff? And what does this mean for [Company]'s
  competitors?"

**Capabilities and Metrics**
- "Walk me through the major technical initiatives that will drive success here. How are you
  planning to make sure these initiatives succeed? What did you measure and what did those metrics
  look like on the way to success?"

### Platform Owner
**Before**
- "Walk me through the main areas of new investment for your executives and how you're planning to
  proactively address related challenges and concerns for Engineering teams."
- "When your execs talk about capturing opportunities for innovation, how likely is it that they
  directly attach the success of those initiatives to work you all are doing?"
- "When you're handed a list of new priorities from executives, how are you working together to
  ensure projects are delivered on time and at or under budget?"

**After**
- "Let's imagine the projects run without issue — what would [Company]'s R&D function look like?
  How does this translate into value for customers and staff? What does this mean for future
  technical or AI projects?"

**Capabilities and Metrics**
- "When you think about [focus area for innovation], walk me through your top three areas of
  prioritization. How are you going to explain your reasoning to leadership?"
- "Let's break down one of these top priorities. What do you and your various stakeholders need
  to be successful? When it succeeds, how are you going to prove value to leadership — is there a
  dashboard or number you point to?"
- "How often is leadership thinking about these areas? How well do they understand the relationship
  between what you're doing and where they want the business to go — especially with something as
  new as AI?"

### AI Team
**Before**
- "You've been given a mandate to figure out how your organization is going to innovate with AI.
  Walk me through early strategic conversations around requirements for timing, budget constraints,
  compliance, and ROI. How well does leadership understand the technical complexities given these
  requirements? How are you currently equipping teams to deliver against them?"

**After**
- "Let's imagine the projects run without issue — what would [Company]'s R&D function look like?
  How does this translate into value for customers and staff? What does this mean for future
  technical or AI projects?"

### Developer
**Before**
- "Walk me through the existing challenges your org has around either getting new services to
  production quickly or making those services easily discoverable by consumers once built."
- "As your organization and leadership talk about innovation and AI, how do you feel the Developer
  Experience is being prioritized? Walk me through areas where this could be better."

**After**
- "Walk me through how your organization's innovation priorities affect you positively. How is your
  life better once these projects succeed?"
- "How do you hope leadership thinks about the work you do and how it drives overall business
  success?"

**Capabilities and Metrics**
- "You're tasked with [focus area for innovation]. Walk me through the three things you're hoping
  to get from Kong to make the jobs to be done here less difficult. If your leadership asks why
  you need these things, how are you making that case to them?"
- "Were there any specific technical initiatives or projects across different teams that you kept
  a close eye on? How might they have been measured differently from others?"
