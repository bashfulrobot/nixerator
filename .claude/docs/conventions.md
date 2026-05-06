# Conventions

Workflow rules: how to build, lint, format, manage upgrades, and handle secrets in nixerator.

## Builds and rebuilds

- **Always use the justfile.** `just qr` (alias for `just quiet-rebuild`) for the current host; per-host aliases for other targets. Never run raw `sudo nixos-rebuild build/switch ...` — the justfile wraps rebuilds with logging, spinners, and post-rebuild hooks (voxtype-setup, etc.) that direct invocations bypass.
- **Don't run `nix build` directly to test configurations.** The justfile is the only sanctioned interface.
- **Quiet variants capture output:** `just quiet-rebuild` writes to `/tmp/nixerator-rebuild.log`; `just quiet-upgrade` writes to `/tmp/nixerator-upgrade.log`. **On failure, spawn a Nix subagent** to read the log and propose a fix — do **not** read the log in the main context (they're noisy and burn tokens).

## Upgrades

- **Never run upgrades unprompted.** Upgrades depend on upstream repos being pushed first.
- When asked to upgrade, use `just quiet-upgrade` (alias `just qu`).

## Git

- **Never run `git commit` or `git push`.** The user handles commits.
- After making changes, suggest a conventional commit scope and title (e.g. `feat(fish): add zoxide integration`).

## Lint and format

- Format with `nix fmt`.
- Lint with `statix` and `deadnix`.

## Path discipline

- Avoid host-specific or machine-local paths. Prefer `settings/globals.nix` so values flow through the global config layer.

## Secrets

- **Never commit plaintext secrets.** Use the `secrets/` directory (encrypted via git-crypt).

## Searching nixpkgs

```bash
nix search github:NixOS/nixpkgs/nixos-unstable#PACKAGE-NAME --json
```
