# Description Template

Use this exact structure when drafting the Case Description field. Omit any section or line where data is not available.

```
Opened on behalf of the customer.
---
Org ID ............ {Konnect/Kong Org ID if provided}

ISSUE SUMMARY
-------------
{2-4 sentence summary of what is happening, what is expected, and what has
been tried so far. Be specific -- include error messages, affected components,
and scope of impact.}

ENVIRONMENT
-----------
{Dot-leader aligned key-value pairs. Only include fields that are known.
Common fields: Product, Platform, Version, Region, Cluster, Deployment Mode.
Adapt to whatever is relevant from the context provided.}

KEY DETAILS
-----------
{Bullet points capturing:
- Timeline of events
- Technical observations
- Workarounds attempted or known
- Business impact if mentioned
- Relevant log snippets (keep brief, attach full logs as files)}
```

## Rules

- Omit the `Org ID` line entirely if no Org ID was provided
- Keep ISSUE SUMMARY factual and concise -- no speculation
- ENVIRONMENT fields should adapt to the product (Gateway vs Mesh vs Konnect etc.)
- KEY DETAILS bullets should be ordered chronologically when describing a timeline
- If log snippets are included, keep them under 10 lines -- attach full logs as files instead
- Use plain text only -- no markdown formatting (SFDC Description is plain text)
