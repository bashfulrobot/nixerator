# CLAUDE.md Optimization (on-demand)

Use this only when editing or restructuring `CLAUDE.md` or related docs.

Best-practices reference:
- https://www.builder.io/blog/claude-md-guide

## CLAUDE.md Structure

The top-level `CLAUDE.md` follows this pattern:

1. Keep it concise (under ~50 lines) with essentials, gotchas, and project map.
2. Use a single `@import` for `extras/docs/commands.md` to keep commands accessible.
3. Reference deep docs directly — no intermediate stub indexes.
4. Each doc reference includes a short description so Claude knows when to open it.
5. Move meta-guidance (like this file) out of the main CLAUDE.md.

## Process Summary (2026-02-11)

What was optimized:

- Made `CLAUDE.md` concise with essentials, common commands, and gotchas.
- Kept only a single @import (`extras/docs/commands.md`) to reduce context usage.
- Moved external dependency details into `extras/docs/external-deps.md`.
- Replaced topic index stubs with direct doc references in main CLAUDE.md.
- Added project conventions (formatter, linter, trailing newline rule).

If updating further:

- Keep `CLAUDE.md` short; move detail into `extras/docs/` and reference directly.
- Add new rules only when real mistakes surface.
- Ensure every file ends with exactly one trailing newline.
