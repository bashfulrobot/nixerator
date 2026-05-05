# Suites

- Changes to a suite affect ALL hosts whose archetype enables it — check `archetypes/` to understand blast radius before modifying.
- Suites primarily enable other modules and set shared system defaults. App-specific packages and config belong in the app's own module under `apps/` or `system/`.
- Per-host module enables go in `hosts/<hostname>/modules.nix`, not in suites.
