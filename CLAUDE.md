# Nixerator

## Rules

- Never commit plaintext secrets; use `secrets/`.
- Avoid host-specific or machine-local paths; prefer `settings/globals.nix`.
- Use `nix fmt` and `statix` + `deadnix`.
- Never run `nixos-rebuild` or `git commit`/`git push` — the user handles rebuilds and commits. After changes, suggest a conventional commit scope and title (e.g., `feat(fish): add zoxide integration`).

## Docs (open only when needed)

- `extras/docs/commands.md` — commands.
- `extras/docs/architecture.md` — architecture & module system.
- `extras/docs/secrets.md` — secrets setup.

## Tools

- To search nixpkgs unstable: `nix search github:NixOS/nixpkgs/nixos-unstable#PACKAGE-NAME --json`