# Worked example, multi-tenant FR + two proxy votes

A single invocation of the `feature-request` skill processed running notes from two enterprise Konnect tenants, both asking for the same capability (per-token source-IP allowlist on Konnect API tokens). The skill produced three files: one customer-independent FR plus one proxy-vote per tenant. Customer names below are synthetic stand-ins (`Northwind Financial`, `Globex Industries`) so this example can be re-used as reference material; in a real run the proxy votes would carry real account names.

All three files were written after running every prose section through the `humanizer` skill and then a final em-dash scrub. The FR file contains zero customer names. Each proxy vote names exactly one customer and links the FR by filename.

---

## File 1, `2026-05-12-konnect-api-token-ip-allowlist-fr.md`

```markdown
# Feature Request: Per-token source-IP allowlist on Konnect API tokens

**Date captured:** 2026-05-12  ·  **Product area:** Konnect
**Category:** New functionality
**Priority:** High
**Proxy votes:** 2 attached

## Detailed description

An enterprise platform team operating Konnect under a corporate egress policy needs each Konnect API token (PAT, service account token) to be usable only from a defined set of source IP CIDRs. Today a leaked token works from anywhere on the public internet, which is the gap the security teams in the source material are flagging during their internal token-hygiene review. The requesting users framed this as "add an IP allowlist to API tokens"; the underlying problem is reducing the blast radius of a token leak by binding the token to the network the issuing tenant actually uses.

## Context and use cases

Persona: a platform security lead inside a regulated enterprise tenant, typically operating under SOC 2 or FedRAMP-class controls. Scale: multi-tenant Konnect deployments where each tenant has its own egress IP block and the tenants do not share network identity. Concrete use cases:

- Tenant A's CI/CD service-account token is rotated quarterly. The security lead wants the token to be unusable if it ever leaves Tenant A's runner network.
- A user PAT issued to a federated workforce identity needs to be scoped to the corporate VPN egress block, so that even a credential lifted from a developer laptop on a coffee-shop network cannot be used to read Konnect resources.

## Current behaviour / workaround

Today there is no built-in token IP allowlist. The available workaround is a network-side egress filter on the customer's side that gates traffic to the Konnect API; this leaves the token usable from any other network that can reach the Konnect API, which is the entire public internet. The workaround does not satisfy the customer-side security review, because the control is enforced on the customer's network and not bound to the credential itself.

## Suggested solution

> As a tenant security lead, I want to attach a list of source-IP CIDRs to a Konnect API token at issuance time, so that the token is rejected when presented from any other source IP.

PROPOSED implementation hint from one source: the allowlist is enforced at the Konnect API ingress, the token itself carries no IP claim, and the allowlist is mutable on the token without re-issuance.

## Benefits

- Reduces the blast radius of a leaked Konnect API token from "anywhere on the public internet" to "the issuing tenant's egress block".
- Closes a common gap on enterprise security questionnaires, where source-IP binding on credentials is a routine line item.
- Removes a class of support ticket where a customer asks Kong to invalidate a token they suspect has leaked.

## Acceptance criteria

- A Konnect admin can attach an IP CIDR allowlist to a PAT or service-account token at creation time.
- A Konnect admin can edit the allowlist on an existing token without re-issuing it.
- A Konnect API request presenting a valid token from a source IP outside the allowlist is rejected with a clear error code and a Konnect audit-log entry recording the rejection.
- The allowlist is enforced for both data-plane and control-plane traffic and the public Konnect API surface.
- An empty allowlist is treated as "no restriction" so existing tokens are not silently broken.

## Business impact

Renewal-blocker pattern at one named account in this submission (see linked proxy vote) and security-review blocker pattern at a second. Expansion-lever pattern across the broader regulated-enterprise segment, where token IP binding is a routine line item on procurement security questionnaires.

## Urgency / timing

Audit-cycle and security-review class. At least one source account has named a specific internal review date driving the ask (see linked proxy vote); the broader segment pattern is "tied to the customer's next external audit".

## Alternatives considered

- Customer-side egress filter on the Konnect API endpoint. Rejected by customer security review because the control is on the network and not bound to the token.
- Short-lived tokens with frequent rotation. Partial mitigation, does not address an in-flight leak.
- mTLS-backed admin API access. Not a fit for the script and service-account use case the customer is asking about.

## Open questions

- Does the allowlist enforcement need to live in the data plane as well, or only in the Konnect control plane?
- Is IPv6 in scope for the first release?
- How does the allowlist interact with federated identity tokens issued via SSO?
```

---

## File 2, `2026-05-12-northwind-financial-proxy-vote.md`

```markdown
# Proxy vote: Northwind Financial on Per-token source-IP allowlist on Konnect API tokens

**Customer:** Northwind Financial  ·  **Date captured:** 2026-05-12
**Linked FR:** [2026-05-12-konnect-api-token-ip-allowlist-fr.md](2026-05-12-konnect-api-token-ip-allowlist-fr.md)
**Source materials:** call recording 2026-05-08, running notes /accounts/northwind-financial/2026-05.md, Slack thread #cust-northwind 2026-05-09

## Account context

Northwind Financial is in the top-quartile ECV bucket for the regulated-enterprise segment, renewal due in Q3, expansion-in-flight on a second Konnect tenant for their wealth-management business unit. Engagement surface: CSM (the user), SE Priya N., AE Marcus L., executive sponsor on Kong side is the regional VP. Stakeholders surfaced in the sources: Sasha Okafor (Head of Platform Security, owns the security review gating renewal), Dmitri Volkov (Principal SRE, owns the corporate egress policy), Lina Ortega (Director of API Platform, owns the Konnect rollout).

## Why this idea matters to this account

Northwind's internal token-hygiene review is part of their annual security audit, which is itself an evidence input for their renewal of their financial-services regulatory authorization. The Konnect API token surface is currently the only credential in their stack that does not support source-IP binding, which the security lead has flagged as a blocker on the audit checklist. If unresolved by their audit date, Northwind has stated they will block the Q3 Konnect renewal.

## Customer-stated risk framing

> "We are not signing off on the Konnect renewal until every credential type in our stack supports a source-IP allowlist. Every other vendor we touch does it. This is the only one outstanding."
> , Sasha Okafor, Head of Platform Security, 2026-05-08, call recording 2026-05-08

> "We cannot reasonably tell our auditor that we have token hygiene if the token works from a coffee shop in Bali. That is the gap."
> , Sasha Okafor, Head of Platform Security, 2026-05-08, call recording 2026-05-08

## Tactical workaround being offered

SE Priya N. has authored an account-specific egress filter recipe on the customer side that gates traffic to the Konnect API surface from Northwind's VPN egress block. This has been deployed and is operating, but Sasha Okafor has rejected it as a long-term answer because the control is on the network and not bound to the credential. Northwind's audit team has accepted the recipe as a compensating control until the Q3 audit, but not beyond it.

## Customer-facing meeting and current commitments

- 2026-05-22, internal touchpoint between CSM, SE, and Lina Ortega, status check on the audit checklist.
- 2026-06-05, Kong-side commitment to deliver a written roadmap response on per-token IP allowlist, owner CSM, attendees Sasha Okafor and Lina Ortega.
- 2026-06-26, customer-driven audit dress-rehearsal; Kong has been invited to observe the Konnect-related portion.

## Customer trust signal

Northwind has filed two prior AHA ideas in the last 12 months. One shipped (a fine-grained RBAC role for Konnect plan management), one is still open (a Konnect audit-log streaming integration with their SIEM). Sasha Okafor has been told both times that "the AHA system is what gets ideas to the product team", which sets up the expectation that this idea will be filed and visible. Frustration signal in the 2026-05-09 Slack thread: "If this lands in a backlog and we hear nothing, we will be reading that as the answer".

## Filing path

- AHA idea filed from the Northwind Financial Salesforce account, not from a case.
- Submitter: CSM (the user).
- Attachments: this proxy-vote file, the linked FR file, the call recording 2026-05-08 (Sasha quote source).
- Internal channel for the filed pair: post the AHA link in #renewals-q3-2026 tagging the AE and the regional VP.

## Open questions specific to this account

- Does Northwind's audit team accept "scheduled to ship by Q4" as a roadmap response, or do they need "in the product by audit date"?
- Will Sasha Okafor accept a phased rollout (allowlist supported on new tokens first, retrofitted onto existing tokens later)?
- See also `2026-05-12-globex-industries-proxy-vote.md`, the second proxy vote on this FR.
```

---

## File 3, `2026-05-12-globex-industries-proxy-vote.md`

```markdown
# Proxy vote: Globex Industries on Per-token source-IP allowlist on Konnect API tokens

**Customer:** Globex Industries  ·  **Date captured:** 2026-05-12
**Linked FR:** [2026-05-12-konnect-api-token-ip-allowlist-fr.md](2026-05-12-konnect-api-token-ip-allowlist-fr.md)
**Source materials:** running notes /accounts/globex-industries/2026-05.md, internal SE channel #se-globex 2026-05-06

## Account context

Globex Industries is in the mid-market ECV bucket, renewal not due until late 2027, but expansion-in-flight on a Konnect Mesh add-on. Engagement surface: CSM (the user), SE Quinn R., AE Hank G. Stakeholders surfaced in the sources: Mei Tanaka (Lead Platform Engineer, owns the Konnect tenant), Aaron Pierce (Security Engineer, owns the token-issuance policy).

## Why this idea matters to this account

Globex is not blocked on a renewal. The ask is driven by an internal security-review checklist Mei Tanaka is preparing as part of the Konnect Mesh expansion business case. The expansion executive sponsor at Globex has told Mei that "no checklist item can be open at proposal time"; per-token source-IP binding is one of three open items, and the only one Mei has not been able to close internally. If unresolved by the proposal date, Globex is unlikely to walk away from the renewal but may delay or descope the Mesh expansion.

## Customer-stated risk framing

> "I am not asking for this to make the gateway tighter. I am asking for it because if I cannot tick this box, my expansion case does not get reviewed."
> , Mei Tanaka, Lead Platform Engineer, 2026-05-06, internal SE channel #se-globex 2026-05-06

## Tactical workaround being offered

No customer-side workaround was offered. SE Quinn R. has suggested rotating service-account tokens on a 24-hour cadence as a partial mitigation. Mei Tanaka has not accepted this as sufficient for the checklist.

## Customer-facing meeting and current commitments

- 2026-05-19, working session between CSM, SE, and Mei Tanaka, walk through the expansion-case checklist line by line.
- 2026-06-12, Kong-side commitment to provide a written statement on per-token IP allowlist status, owner CSM, attendee Mei Tanaka.

## Customer trust signal

Globex has filed one prior AHA idea, still open (a Konnect plugin-version pinning UX improvement). No frustration signal in the sources; Mei is collaborative and the relationship is healthy. The risk on this account is silent attrition of the expansion, not vocal escalation.

## Filing path

- AHA idea filed from the Globex Industries Salesforce account, not from a case.
- Submitter: CSM (the user).
- Attachments: this proxy-vote file, the linked FR file.
- Internal channel for the filed pair: post the AHA link in #expansion-mesh tagging the SE and the AE.

## Open questions specific to this account

- Does Mei need the capability to be in the product, or is "publicly announced on the roadmap by proposal date" enough?
- Would Globex accept a Konnect Mesh-only first cut, or do they need the allowlist on the Konnect Gateway tokens too?
- See also `2026-05-12-northwind-financial-proxy-vote.md`, the second proxy vote on this FR.
```

---

## Notes on this example

- The FR body contains zero matches for either `Northwind Financial` or `Globex Industries`, zero ARR figures, zero stakeholder names, zero dated quotes. All customer-identifying facts are pushed into the proxy votes.
- Each proxy vote names exactly one customer in its header and body, links the FR by filename, and includes at least one dated, attributed quote.
- The two proxy votes cross-reference each other in their respective `Open questions` sections.
- The FR's `Proxy votes:` header line records the *count* (`2 attached`) without listing customer-slug filenames, so the FR body remains free of customer names. The back-link is one-way, each proxy vote links the FR by filename, but the FR does not name any proxy vote.
- The FR's `Priority:` is `High` because Northwind has a documented renewal-block path with a date; if Northwind had not been in the source material, the same FR with only Globex as a proxy vote would land at `Medium`.
- Every prose section in all three files passes the `humanizer` skill's AI-vocabulary checks (no `align with`, `stands as`, `serves as`, `underscore`, `highlight`, `delve`, etc.) and the em-dash scrub. None of the three files contains any of `—`, `–`, `‒`, or `―`, and none contains a bare ASCII `--` outside a CLI flag or numeric range.
