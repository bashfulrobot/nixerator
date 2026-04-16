---
name: dependabot
description: Use when working on a Dependabot alert (by number), checking remediation
  status, resuming interrupted remediation work, addressing PR review feedback, or
  cleaning up after a merged fix. Also trigger when the user mentions a Dependabot
  alert or wants to fix a security vulnerability.
---

# Dependabot Remediation Workflow

State-machine orchestrator for Dependabot alert remediation. Uses the `dependabot` CLI for all mechanical operations (alert fetching, worktree creation, state management, push+PR, cleanup). AI handles only judgment work — implementation, review evaluation.

All work happens in an isolated git worktree. Never implement in the main working tree.

## Worktree Anchoring

**Before every action**, verify working directory:

```bash
dependabot validate-cwd <alert-number>
```

If `valid` is false, run the `fix` command. **Repeat after invoking any sub-skill** (verification, receiving-code-review).

## Entry Point

### 1. Audit active worktrees

```bash
dependabot audit
```

Report any active worktrees. Flag `done` worktrees for cleanup.

### 2. If no alert number provided — list open alerts

```bash
gh api 'repos/{owner}/{repo}/dependabot/alerts?state=open' --jq '.[] | {number, package: .dependency.package.name, severity: .security_advisory.severity, summary: .security_advisory.summary}'
```

Present the list. Let the user pick one.

### 3. Detect state

```bash
dependabot status <alert-number>
```

Route on `workflow_step`. If `workflow_step` is null (v1 migration), fall back to `state`.

## State Routing

| `workflow_step` | Action |
|----------------|--------|
| (no worktree) | `dependabot setup <N>`, proceed to implement |
| `implement` | Fix the vulnerability in the worktree |
| `verify` | Invoke `superpowers:verification-before-completion` |
| `push` | `dependabot push <N>` |
| `review_dev` | Suggest `/review-dev`, handle findings |
| `review_security` | Suggest `/review-security`, handle findings |
| `waiting` | Re-check status for PR state changes |
| `revamp` | Address review feedback, verify, push |
| `done` | `dependabot cleanup <N>` |
| `closed` | Report to user, offer options |

## Step Details

### Setup (no worktree)

```bash
dependabot setup <alert-number>
```

Parse JSON response for `worktree`, `branch`, `package_name`, `manifest_path`, `patched_version`, and `advisory_summary`. Change into worktree:

```bash
cd <worktree>
```

The alert context is available in `.dependabot-alert.json` inside the worktree for full details.

Proceed to implement (setup already sets `workflow_step: "implement"`).

### Implement

Fix the vulnerability:

1. Read the alert context from the setup response or `.dependabot-alert.json`
2. Update the vulnerable package to at least the patched version
3. Update both the dependency file and lock file
4. If the vulnerable package is a transitive dependency, update the parent package
5. Run `npm install` or equivalent to regenerate the lock file
6. If a build script exists, verify the build still works
7. Keep changes scoped to the vulnerability — no unrelated changes

Follow commit conventions:
- Format: `security(<scope>): fix <summary> (CVE-XXXX-XXXXX)`
- Sign with `-S`, no Co-Authored-By
- Include CVE/GHSA ID in commit body

When implementation is believed complete:

```bash
dependabot transition <N> verify
```

### Verify

**Invoke `superpowers:verification-before-completion`.** After invoking, validate-cwd.

Run the project's test suite, linters, and build.

- If verification fails: `dependabot transition <N> implement` (loop back)
- If verification passes: `dependabot transition <N> push`

### Push

```bash
dependabot push <alert-number>
```

Report `pr_url` and `ci_status` from response. Then:

```bash
dependabot transition <N> review_dev
```

### Review (Dev)

Suggest running `/review-dev` on the PR:

```
"PR created: <pr_url>
Recommend running /review-dev to catch issues before merge."
```

After dev review runs, parse the summary line if present:
- `REVIEW_DEV_SUMMARY: verdict=block` or `verdict=fix`: implement fixes, verify, push
- `verdict=clean`: transition to next step
- No summary line (backward compat): ask user if there are findings to address

If findings addressed (or user declines review):

```bash
dependabot transition <N> review_security
```

### Review (Security)

Suggest running `/review-security`:

```
"Dev review complete.
Recommend running /review-security for a security audit before merge."
```

Same summary parsing pattern:
- `REVIEW_SECURITY_SUMMARY: verdict=block` or `verdict=fix`: implement fixes, verify, push
- `verdict=clean`: transition
- No summary line: ask user

After all fixes (or user declines):

```bash
dependabot transition <N> waiting
```

### Waiting

Re-check status:

```bash
dependabot status <N>
```

Reconciliation auto-detects:
- PR merged -> advances to `done`
- Changes requested -> advances to `revamp`
- PR closed -> advances to `closed`

If still waiting, report current state.

### Revamp

1. Evaluate review feedback technically (don't blindly agree)
2. Implement fixes with focused commits
3. **Invoke `superpowers:verification-before-completion`**
4. Push: `dependabot push <N>`

Then:

```bash
dependabot transition <N> verify --detail-json '{"revamp_round": <round+1>}'
```

### Done (Cleanup)

```bash
dependabot cleanup <alert-number>
```

Removes worktree, deletes branches, dismisses the Dependabot alert.

### Closed

PR closed without merge. Report to user. Offer: reopen PR, create new PR, or abandon.

## Interruption Recovery

The skill reads `workflow_step` from `status` and picks up where it left off. The `status` command reconciles state with git/PR signals automatically.

## Conventions

### Commit Format

Format: `<type>(<scope>): <description>`

Rules:
- Type: use `security` for vulnerability fixes, `deps` for version bumps
- Scope (REQUIRED): lowercase, kebab-case module name (e.g., `clay`, `nodemailer`)
- Description: imperative mood, lowercase start, no period
- Sign commits: always use `-S` flag
- Do NOT add Co-Authored-By lines
- Include CVE/GHSA ID in commit body

Examples:
- `security(clay): fix nodemailer addressparser DoS (CVE-2025-14874)`
- `deps(clay): bump esbuild to 0.25.1`

### Remediation Guidelines

- Update the vulnerable package to at least the patched version specified
- Update both the direct dependency file (package.json) and lock file (package-lock.json)
- If the vulnerable package is a transitive dependency, update the parent package that pulls it in
- Run `npm install` or equivalent to regenerate the lock file after version changes
- If a build script exists in the manifest directory, run it to verify the build still works
- Do not make unrelated changes; keep the fix scoped to the vulnerability

### PR Body Format

When creating a PR, the `dependabot push` command auto-generates:

```
## Summary
Fixes Dependabot alert #<N>
- Package: <name>
- <summary>

<commit log entries>
```
