# Secrets roadmap

Two changes to the 1Password-source, gopass-snapshot model that need a human step
or a test install, so they are written down here instead of built. Everything else
in the hardening round is in the code (see `secrets.md`).

## 1. Per-host GPG recipients

Today one passphrase-less GPG key (uid `secauto automation`) decrypts the whole
secauto store on every host. A compromised reader (srv, the Mac) exposes every
entry, including ones it never uses.

Goal: each reader host holds its own key, and an entry is encrypted only to the
hosts that use it. srv would decrypt its automation entries and nothing else.

Plan:

1. Generate one passphrase-less key per reader host, on that host.
2. Split the store by consumer. Entries srv needs (the ones read by `claudoist`,
   `incident-investigator`, `secauto-pull` renders and the restic/syncthing/tailscale
   modules on srv) go to a recipient set of {qbert, srv}. Workstation-only entries
   stay at {qbert, mac}.
3. Re-encrypt with gopass: `gopass recipients add <key>` on the relevant store or
   mount, then `gopass fsck` or the re-encrypt that `recipients add` runs.
4. Update `push-gpg-key` to push each host its own key, not the shared one.
5. Retire the shared key once every host decrypts with its own.

UNVERIFIED before starting: whether one repo can carry two recipient sets (a
second gopass mount with its own `.gpg-id` is the likely shape, which means two
repos or a sub-store). Check `gopass recipients` and `gopass mounts` docs, and try
it on a throwaway store first. A mistake here can lock qbert out of its own store,
so keep the recovery copy (1Password Document `secauto-gpg-key`) until a clean
re-render from the new layout works on every host.

Human steps: key generation, the re-encrypt, and the cut-over. Claude can write
the `push-gpg-key` change and the map split once the layout is chosen.

## 2. Retire the service-account tooling (bootstrap redesign)

The accounts are being deleted. What still uses the service-account token:
`bootstrap-install-secrets.sh`, `render-secrets-bootstrap.sh`, `setup-op-token`,
`rotate-op-token`, `op-toggle`, the `onepassword.serviceAccountToken` template key
and the token auto-source in `render-secrets --from op`.

New-install flow without the token:

1. Boot the installer, reach an existing host (qbert) over SSH. `bootstrap.txt`
   already assumes this to copy SSH and GPG keys.
2. Copy the secauto GPG key from that host (the same stream `push-gpg-key` uses)
   and clone the secauto store with a deploy key.
3. Render `secrets.json` from gopass: `RENDER_SECRETS_ALLOW_MISSING=1 render-secrets
   --from gopass` (the override exists for this case).
4. Restore the identity-class keys from 1Password with the desktop session, not a
   service account: `just render-secrets-op` on the new workstation, which prompts
   once through the 1Password app.
5. First rebuild; from then on `just render-secrets` reads gopass.

Removal checklist, done together once a test install passes:

- delete `bootstrap-install-secrets.sh`, `render-secrets-bootstrap.sh`,
  `setup-op-service-account.sh`, `rotate-op-service-account.sh`, `lib/op-sa-token.sh`
- delete the `setup-op-token`, `rotate-op-token`, `bootstrap-secrets` recipes and
  the `rot` alias
- delete `op-toggle` from the fish module
- drop `onepassword.serviceAccountToken` from `secrets.json.tpl` and the SA token
  auto-source from `render-secrets.sh`
- update `bootstrap.txt`, `helpers.md` and `secrets.md`

Not done here because the replacement flow has never run on a real install, and a
broken bootstrap is only found on a new machine. Test it in a VM first.
