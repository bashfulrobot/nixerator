# Conventions

Workflow rules: how to build, lint, format, manage upgrades, and handle secrets in nixerator.

## Builds and rebuilds

- **Always use the justfile.** `just qr` (alias for `just quiet-rebuild`) for the current host; per-host aliases for other targets. Never run raw `sudo nixos-rebuild build/switch ...` — the justfile wraps rebuilds with logging, spinners, and post-rebuild hooks (voxtype-setup, etc.) that direct invocations bypass.
- **Don't run `nix build` directly to test configurations.** The justfile is the only sanctioned interface.
- **Quiet variants capture output:** `just quiet-rebuild` writes to `/tmp/nixerator-rebuild.log`; `just quiet-upgrade` writes to `/tmp/nixerator-upgrade.log`. **On failure, spawn a Nix subagent** to read the log and propose a fix — do **not** read the log in the main context (they're noisy and burn tokens).
- **Testing local hyprflake changes:** `just hyprflake-test` (alias `just hft`) rebuilds the current host with the `hyprflake` flake input overridden to a local working tree, so hyprflake changes can be tried without committing/pushing hyprflake or bumping `flake.lock`. Defaults to `~/git/hyprflake`; pass a path to test a different checkout/worktree (e.g. `just hft /home/dustin/git/.worktrees/hyprflake-feature`). It wraps `sudo nixos-rebuild switch --impure --flake .#<host> --override-input hyprflake path:<path>` and targets whichever host it runs on, like `just rebuild`.

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

- **All secrets live in the `nixerator` 1Password vault.** Nix-eval secrets render to `~/.config/nixos-secrets/secrets.json` via `just render-secrets`; Okular signature PNGs fetch to `~/.kde/share/icons/` via `just fetch-signatures`. See `extras/docs/secrets.md`.
- **Never read `~/.config/nixos-secrets/` or `~/.config/op/`** from agent tooling — both paths are on Claude Code's Read `permissions.deny`. To inspect the schema, read `secrets.json.tpl` (placeholders only).
- **Never re-introduce `secrets/secrets.json`, `secrets/sg.png`, or `secrets/init.png`** in the repo. `.gitignore` blocks them; git-crypt has been retired (#86).
- Per-host network identity (Tailscale IPs, syncthing peer IDs) is NOT secret and lives in `settings/globals.nix` under `hosts.{qbert,donkeykong,srv}`.

## Searching nixpkgs

```bash
nix search github:NixOS/nixpkgs/nixos-unstable#PACKAGE-NAME --json
```
