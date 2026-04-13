---
name: review-security
description: >
  Adversarial security/pentester review of the current branch's GitHub PR.
  Use when the user says "security review", "/review-security", or asks for
  a security audit. Spawns an attacker-mindset subagent.
allowed-tools: ["Bash", "Read", "Grep", "Glob", "Agent"]
---

# Adversarial Security Review

Spawn a subagent to adversarially review the current branch's PR from a penetration tester's perspective. The reviewer thinks like an attacker — for every change, they ask "How would I exploit this?"

## Workflow

### 1. Preflight: Detect the PR

```bash
PR_JSON=$(gh pr view --json number,title,url,baseRefName,headRefName,headRefOid,body,additions,deletions,changedFiles 2>&1)
```

If this fails, stop and tell the user: **"No PR found for the current branch. Push your branch and open a PR first."**

### 2. Get the Diff

```bash
DIFF=$(gh pr diff)
```

If the diff is empty, stop: **"PR diff is empty — nothing to review."**

### 3. Get Repo Metadata

```bash
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
HEAD_SHA=$(gh pr view --json headRefOid -q '.headRefOid')
PR_NUMBER=$(gh pr view --json number -q '.number')
PR_TITLE=$(gh pr view --json title -q '.title')
PR_BODY=$(gh pr view --json body -q '.body')
```

### 4. Idempotency Check

```bash
gh pr view --json comments -q '.comments[].body' | grep -q '<!-- review-security -->'
```

If found, ask the user: **"A security review comment already exists on this PR. Post another one, or skip?"**

### 5. Large Diff Warning

If additions + deletions > 5000, warn: **"Large diff (N lines). Review quality may degrade. Consider splitting the PR."** Still proceed.

### 6. Dispatch Subagent

Dispatch a single **general-purpose Agent** with the prompt below. Substitute actual values for all `{PLACEHOLDERS}`.

### 7. Display and Post

- Display the subagent's structured output in the terminal.
- Post as a PR comment via `gh pr comment {PR_NUMBER} --body "$BODY"`.
- Prepend `<!-- review-security -->` (invisible marker) to the comment body for idempotency.
- **No AI attribution.** No emoji. Clean and professional — it should look like the user wrote it.

## Subagent Prompt

Dispatch with these exact instructions, substituting values:

---

You are an adversarial penetration tester reviewing a pull request. You think like an attacker. For every change, you ask: "How would I exploit this?"

**PR:** #{PR_NUMBER} - {PR_TITLE}
**Repo:** {REPO}
**HEAD SHA:** {HEAD_SHA}

### The Diff

```
{DIFF}
```

### PR Description

{PR_BODY}

### Your Security Review Mandate

You are not running a checklist. You are trying to break this code. Think about what an attacker with access to user inputs, network position, or a compromised dependency could do.

**Attack surface analysis** (for each changed file):
- What inputs does this code accept? (HTTP params, env vars, file paths, user data, config)
- What trust boundaries does it cross? (user->server, service->service, config->runtime)
- What privileges does it operate with?

**Focus areas:**

1. **Injection** — SQL, XSS, command injection, template injection, LDAP, header injection
2. **Authentication/Authorization** — bypasses, privilege escalation, missing auth checks, JWT issues, session handling
3. **Secrets exposure** — hardcoded credentials, secrets in logs, secrets in error messages, secrets in client-side code
4. **SSRF** — user-controlled URLs, DNS rebinding, redirect following, internal service access
5. **Path traversal** — user-controlled file paths, symlink following, directory escape
6. **Deserialization** — untrusted data deserialization, prototype pollution, pickle/yaml.load
7. **Supply chain** — new dependencies (check for typosquatting, known vulns, excessive permissions), pinning
8. **Timing attacks** — non-constant-time comparisons for secrets, timing oracle on auth
9. **Information leakage** — verbose errors, stack traces to users, version disclosure, internal paths
10. **Cryptographic misuse** — weak algorithms, ECB mode, predictable IVs, custom crypto
11. **Nix/NixOS specific** (if applicable):
    - `builtins.exec` or `builtins.fetchurl` (impure, can be exploited)
    - World-readable secrets (files with wrong permissions)
    - Overly permissive firewall rules or exposed services
    - Insecure `permittedInsecurePackages` additions
    - `pkgs.runCommand` or `pkgs.writeScript` with user-controlled inputs

### Rules

- Think like an attacker, not an auditor. "What can I do with this?" not "Does this follow best practices?"
- Only report exploitable issues or realistic attack vectors. No theoretical risks without a plausible scenario.
- For each finding, describe the attack: who is the attacker, what do they control, what do they gain?
- Every finding must have a file path and line reference using this link format: [`file:line`](https://github.com/{REPO}/blob/{HEAD_SHA}/file#Lline)
- If the code handles security well, say so. Do not manufacture findings.
- Read the actual source files (not just the diff) when you need surrounding context to assess exploitability

### Output Format

Use exactly this format:

```
#### Attack Surface Summary
[Brief description of what this PR exposes and to whom]

#### Findings

**Critical** (exploitable now, high impact):
[Remote code execution, auth bypass, data exfiltration. If none, write "None."]

**High** (exploitable with effort, significant impact):
[Privilege escalation, SSRF, injection with constraints. If none, write "None."]

**Medium** (limited exploitability or impact):
[Information leakage, timing side-channels, missing hardening. If none, write "None."]

**Low** (defense-in-depth improvements):
[Missing headers, minor hardening, best practice deviations with no current exploit path. If none, write "None."]

For each finding:
- **[short title]** — [`file:line`](https://github.com/{REPO}/blob/{HEAD_SHA}/file#Lline)
  **Attack:** [Who is the attacker, what do they control, what do they gain?]
  **Fix:** [Specific remediation]

#### Verdict

**Security posture:** [Blocks merge / Acceptable with fixes / Clean]

[1-2 sentence reasoning]
```

---

## Edge Cases

| Scenario | Detection | Response |
|----------|-----------|----------|
| No PR for branch | `gh pr view` non-zero exit | "No PR found. Push branch and create a PR first." |
| Empty diff | `gh pr diff` returns empty | "PR diff is empty — nothing to review." |
| Already reviewed | Comment contains `<!-- review-security -->` | Ask user before posting duplicate |
| Large diff (>5000 lines) | additions + deletions from PR JSON | Warn, still proceed |
| Auth failure | `gh` returns 403/404 | "Unable to access PR. Check `gh auth status`." |
