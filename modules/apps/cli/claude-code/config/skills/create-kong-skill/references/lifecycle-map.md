# Lifecycle map

One-line summary of every skill the metaskill orchestrates. SKILL.md links here instead of re-quoting Kong's verb docs.

## Kong lifecycle verbs (Kong/cs-skills marketplace)

| Verb | Purpose |
|---|---|
| `kong-skill-init` | Scaffold the plugin folder, manifest, draft SKILL.md, marketplace catalog entry, and grand-meta dependency wiring. Dry-run by default; `--write` applies. |
| `kong-skill-author` | Pre-load Kong conventions (naming, cross-platform, requirements, surface caveats) into context, then delegate the SKILL.md drafting to upstream `skill-creator:skill-creator`. |
| `kong-skill-finalize` | Scan SKILL.md and bundled scripts for tool invocations against the team dep registry. Populates `requirements`, `platforms`, `surfaces` in `plugin.json`. Dry-run by default; `--write` applies. |
| `kong-skill-lint` | Static checks across one or all skills: em-dashes, GNU-only shell flags, frontmatter sloppiness, naming-rule violations, broken intra-skill markdown links. Read-only. Exits non-zero on findings. |
| `kong-skill-test` | `mkdocs build --strict` of the docs site, then opens the rendered catalog page for the named skill. Use `--no-open` in unattended runs. |
| `kong-skill-open-pr` | Detect git state, create `feat/<slug>` branch when needed, push with `-u`, open the PR with the team's quality-bar checklist embedded. Dry-run by default; `--apply` mutates. |
| `kong-skill-watch-checks` | Poll scanner CI on the open PR (Cisco AI Defense, Snyk, risk-capture). One-shot by default; `--watch` polls until terminal. |

## Local review skills

| Skill | Purpose |
|---|---|
| `review-dev` | Adversarial senior-engineer pass on the current branch's GitHub PR. |
| `review-security` | Adversarial pentester pass on the current branch's GitHub PR. |

## Upstream drafting skill

| Skill | Purpose |
|---|---|
| `skill-creator:skill-creator` | Generic SKILL.md drafting dialog. Invoked through `kong-skill-author`, never directly. |
