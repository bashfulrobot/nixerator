---
name: code-style
description: >-
  Dustin's DRY and over-abstraction rules. Use before extracting a helper,
  function, module, or shared config; when repeated logic tempts you to factor it
  out; when refactoring, deduplicating, or consolidating; when reviewing a diff
  that adds an abstraction; or when the user says DRY this up or refactor this.
  The threshold is three occurrences, not two.
allowed-tools: ["Read", "Grep", "Glob", "Edit", "Write"]
---

# Code Style

- **Write DRY code where appropriate** — if the same logic appears in three or more places, extract it (function, module, variable, config). Two occurrences is usually a coincidence; three is a pattern.
- **Do not over-abstract** — DRY applies to genuine duplication of *intent*, not incidental similarity of *shape*. If two code paths happen to look alike but can evolve independently, leave them alone. Premature abstraction is worse than duplication.
- Before adding a new helper, grep for existing utilities that already cover the case. Reuse beats re-implement.
