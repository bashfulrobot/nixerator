# Dependabot Remediation Workflow - Conventions

## Commit Format

Format: `<type>(<scope>): <emoji> <description>`

Rules:
- Type: use `security` for vulnerability fixes, `deps` for version bumps
- Scope (REQUIRED): lowercase, kebab-case module name (e.g., `clay`, `nodemailer`)
- Emoji: single emoji after colon+space
- Description: imperative mood, lowercase start, no period
- Sign commits: always use `-S` flag
- Do NOT add Co-Authored-By lines
- Include CVE/GHSA ID in commit body

Examples:
- `security(clay): :lock: fix nodemailer addressparser DoS (CVE-2025-14874)`
- `deps(clay): :arrow_up: bump esbuild to 0.25.1`

## Remediation Guidelines

- Update the vulnerable package to at least the patched version specified
- Update both the direct dependency file (package.json) and lock file (package-lock.json)
- If the vulnerable package is a transitive dependency, update the parent package that pulls it in
- Run `npm install` or equivalent to regenerate the lock file after version changes
- If a build script exists in the manifest directory, run it to verify the build still works
- Do not make unrelated changes; keep the fix scoped to the vulnerability

## PR Body Format

When creating a PR, use this body structure:

```
## Summary
<1-3 bullet points describing what changed and why>

## Test plan
- [ ] <manual or automated verification steps>
```
