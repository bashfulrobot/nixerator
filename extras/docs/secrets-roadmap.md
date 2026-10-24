# Secrets roadmap

## Decision: one GPG key for the secauto store

One passphrase-less GPG key (uid `secauto automation`) decrypts the whole store on
every reader host. That is intentional (Dustin, 2026-10-24), so there is no per-host
key split. What follows from it:

- A compromised reader exposes every entry in the store. The accepted mitigations are
  the single-user hosts, the private repo, 2FA on the GitHub account and signed pulls
  (see "What the pull trusts" in `secrets.md`).
- Anything that must not reach every host stays out of gopass: SSH identity keys,
  git-crypt keys, `incus-ui.pfx` and `okular-*` live in 1Password only.
- The recovery copy of the key is the 1Password Document `secauto-gpg-key`
  (Personal vault). `just push-gpg-key <host>` stays the way a NixOS host gets it.

(Per-host recipients do work in gopass 1.17.4: a `.gpg-id` in a subdirectory of one
store sets who can decrypt it, with entry names unchanged. It was tested on a
throwaway store and then removed from the repo. Reintroduce it only if the decision
changes.)

## Signed pulls

qbert signs its secauto commits with Dustin's SSH signing key (the git module sets
`commit.gpgsign`). srv sets `apps.cli.secauto-pull.allowedSignersFile` to a file
holding that public key, so its pull merges only commits signed by it. The Mac's pull
is not managed by Nix and still accepts unsigned commits.

## Service-account tooling: retired (2026-10-24)

Removed: `bootstrap-install-secrets.sh`, `render-secrets-bootstrap.sh`,
`setup-op-service-account.sh`, `rotate-op-service-account.sh`, `lib/op-sa-token.sh`,
the `setup-op-token`, `rotate-op-token` and `bootstrap-secrets` recipes and the `rot`
alias, `op-toggle`, the `onepassword.serviceAccountToken` template key and the token
auto-source in `render-secrets.sh`. `import-op-to-gopass.sh` and
`fetch-okular-signatures.sh` now use the 1Password desktop app only.

Replacement for a fresh install: `extras/helpers/bootstrap-install-gopass.sh`
(`stage` and `promote`). It streams the secauto key and the encrypted store from an
existing host over SSH, renders `secrets.json` with `render-secrets --from gopass`
(`RENDER_SECRETS_ALLOW_MISSING=1`), and copies the result onto the target. SSH and
git-crypt keys come back after first boot with `just render-secrets-op`.

**Not verified:** the script has never run on a live USB. The SSH, key-stream and
`promote` steps need a VM or a spare machine. Until that run passes, a fresh install
has no tested secrets path. The old scripts are in git history if a rollback is
needed.

Manual cleanup on each host: delete `~/.config/op/service-account-token`.
