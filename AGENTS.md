# Repository Guidelines

## Project Structure & Module Organization
- `flake.nix` defines inputs and host configurations; `flake.lock` is the pinned dependency set.
- `hosts/` contains per-host configs (e.g., `hosts/qbert/configuration.nix`).
- `modules/` holds reusable modules by category (`apps/`, `system/`, `suites/`, `archetypes/`, `server/`, `dev/`).
- `settings/` stores shared defaults (`globals.nix`) and version pins (`versions.nix`).
- `packages/` contains custom package overrides and tracking docs.
- `extras/docs/` has deep-dive documentation; `extras/helpers/` includes helper scripts.
- `secrets/` is git-crypt–encrypted; do not commit plaintext secrets.

## Build, Test, and Development Commands
- `just check` — runs `nix flake check` for fast validation.
- `just test` — dry-run rebuild (`nixos-rebuild dry-build`) to catch build errors.
- `just build` — dev rebuild of the current host; add `trace=true` for stack traces.
- `just rebuild` — production rebuild for the current host.
- `just fmt` — format Nix files via `nix fmt`.
- `just lint` / `just health` — statix and deadnix checks across Nix files.

## Coding Style & Naming Conventions
- Prefer small, pure functions and immutable values where possible.
- Follow Nix formatting via `nix fmt` (don’t hand-format).
- Keep module names and option paths consistent with existing structure, e.g.
  `modules/apps/cli/<app>.nix` and `apps.cli.<app>.enable`.
- Files must end with a trailing blank line.

## Testing Guidelines
- Tests should validate behavior, not implementation details.
- Never mock; use real schemas/types in tests.
- Use `just check` and `just test` as the primary validation steps.
- If adding tests, place them under `tests/` and mirror the module layout.

## Commit & Pull Request Guidelines
- Commit messages follow a conventional pattern: `type(scope): <emoji> message`.
  Examples: `feat(media): ✨ add v4l-utils`, `fix(apple-fonts): 🐛 ...`, `deps(flake): ⬆️ ...`.
- PRs should include a short summary, affected hosts/modules, and commands run.
  Add screenshots only when UI/desktop changes are involved.

## Security & Configuration Tips
- Keep secrets in `secrets/` and reference them via module options.
- Avoid committing host-specific or machine-local paths; prefer `settings/globals.nix`.
