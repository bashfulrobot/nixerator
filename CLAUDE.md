# Nixerator

## Rules

- Never commit plaintext secrets; use `secrets/`.
- Avoid host-specific or machine-local paths; prefer `settings/globals.nix`.
- Use `nix fmt` and `statix` + `deadnix`.

## Docs (open only when needed)

- `extras/docs/commands.md` — commands.
- `extras/docs/architecture.md` — architecture & module system.
- `extras/docs/secrets.md` — secrets setup.
