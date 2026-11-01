# claude-code module

When working on this module, also load:

- When evaluating this module's setup against external Claude Code best-practices, read [`README.md`](./README.md).
- Before changing anything this module deploys into `~/.claude`, read [`.claude/docs/claude-stack-apply.md`](../../../../.claude/docs/claude-stack-apply.md). `apps.cli.claude-code.stackApply.enable` moves most of the settings surface to claude-skills, so the answer to "should this live here" depends on which keys the manifest owns.

## Reassessment

This module's external best-practices audit was last run on **2026-10-31**
against the ykdojo/claude-code-tips list (the source the colobu.com article
translated, now 50 tips), with Anthropic's context-engineering guidance for
Claude 5-generation models re-checked the same day. **Reassess by 2027-01-31.**

If today's date is on or after the reassessment date and you are working in
this module, surface a reminder to the user that the audit is due, and offer
to re-run the procedure documented at the bottom of `README.md`.
