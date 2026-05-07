# Brief shape

The brief is the input the metaskill collects (conversationally, from args, or from a `--brief <path>` file) before the lifecycle chain runs. Every field listed below is filled in before Phase 1 starts. If a field is missing from context, the metaskill asks for it.

## Schema

```yaml
skill-name: kebab-case-name
# Required. Lowercase letters, digits, and hyphens, starts with a letter,
# max 64 chars, no `anthropic` or `claude` substring. Validated against
# kong-skill-init's naming rules (see Kong/cs-skills docs/mkdocs/docs/contributing/naming.md).

purpose: one-line description
# Required. Becomes the SKILL.md `lifecycle-when` field. Plain prose, single
# sentence, what the skill does.

description: longer description
# Required. Becomes the SKILL.md `description` frontmatter, the trigger
# surface Claude reads at skill-load time. Written for relevance, not promotion.

triggers:
  - "natural-language phrase that should fire the skill"
  - "another phrase"
# Required. At least one. The metaskill folds these into the description prose
# during Phase 2 so skill-creator picks them up when drafting.

workflow: |
  1. First step the skill takes when invoked.
  2. Next step.
  3. ...
# Required. What the skill DOES, in order. Plain prose. The drafting handoff
# in Phase 2 turns this into the SKILL.md ## Process section.

requirements:
  - python
  - gh
# Optional. Shell tools or Python deps the skill invokes. If absent,
# Phase 3 (kong-skill-finalize) detects them from the drafted SKILL.md.

disable-model-invocation: false
# Optional. Default false. Set true for slash-command-only verbs (rare).
```

## Conversational intake

When invoked without args or `--brief`, the metaskill walks through the fields in the order above, skipping any already in conversation context (chat history, MCP outputs, prior turns, pasted snippets). Single-question-per-turn. `requirements` is the only optional field; everything else is required.

## File intake

`--brief <path>` accepts YAML or markdown with the same field names. Missing required fields trigger the same conversational follow-up as fully-conversational mode.
