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

## Retire the service-account tooling (bootstrap redesign)

**Built:** `extras/helpers/bootstrap-install-gopass.sh` (`stage` and `promote`). It
streams the secauto key and the encrypted store from an existing host over SSH,
renders `secrets.json` with `render-secrets --from gopass` (with
`RENDER_SECRETS_ALLOW_MISSING=1`), and copies the result onto the target. It does
not touch the SSH or git-crypt keys: after first boot, `just render-secrets-op`
restores them from the 1Password desktop session. `bootstrap.txt` points to it as an
alternative to Step 4. shellcheck is clean; the render step it relies on is covered
by `tests/render-hardening.bats`.

**Not verified:** the script has never run on a live USB. The SSH, key-stream and
`promote` steps need a VM or a spare machine. Do that run before the removal below.

Removal checklist, done together after a clean test install and once the service
accounts are deleted:

- delete `bootstrap-install-secrets.sh`, `render-secrets-bootstrap.sh`,
  `setup-op-service-account.sh`, `rotate-op-service-account.sh`, `lib/op-sa-token.sh`
- delete the `setup-op-token`, `rotate-op-token`, `bootstrap-secrets` recipes and
  the `rot` alias
- delete `op-toggle` from the fish module
- drop `onepassword.serviceAccountToken` from `secrets.json.tpl` and the token
  auto-source from `render-secrets.sh`
- point `bootstrap.txt` Step 4, `helpers.md` and `secrets.md` at the new script
