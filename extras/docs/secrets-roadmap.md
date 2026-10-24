# Secrets roadmap

Two changes to the 1Password-source, gopass-snapshot model. The tooling for both is
built and tested as far as it can be without your machines. What is left needs you
to generate keys, run commands on real hosts, or do a test install.

## 1. Per-host GPG recipients

Today one passphrase-less GPG key (uid `secauto automation`) decrypts the whole
secauto store on every host. A compromised reader (srv, the Mac) exposes every
entry, including ones it never uses.

Goal: each reader host holds its own key, and a directory of entries is encrypted
only to the hosts that use it.

**Verified** (throwaway store, throwaway keys, gopass 1.17.4, covered by
`tests/secauto-recipients.bats`): one store can carry different recipients per
directory through a `.gpg-id` file in that directory. Entry names do not change, so
`gopass-map.tsv` and `gopassRun` keep working. A host outside the list cannot
decrypt the entry.

**Built:** `extras/helpers/secauto-recipients.sh` (`just secauto-recipients plan`
and `apply --yes`), driven by two files of names and public fingerprints:
`extras/helpers/secauto-hosts.tsv` and `extras/helpers/secauto-recipients.tsv`. It
re-encrypts through a pipe and prints no value.

Steps, in order (all on real hosts, by you):

1. On each reader host (srv, the Mac), generate its own passphrase-less key. The
   command is in the header of `secauto-hosts.tsv`. Export the public key to qbert
   (`gpg --export <fpr> | ssh qbert gpg --import`).
2. Record each fingerprint in `secauto-hosts.tsv`, including qbert's own key. Make
   qbert's own key a recipient too, so the writer does not depend on the shared key.
3. Fill `secauto-recipients.tsv` one directory at a time. The file lists what srv
   reads today; verify each before adding it.
4. `just secauto-recipients plan`, then `just secauto-recipients apply --yes` on
   qbert, then `gopass sync`.
5. On srv, after the next `secauto-pull`: `gopass show -o <entry>` for one entry in
   each directory you opened to it, and check `secauto-pull`'s next render passes.
6. Repeat for the next directory. When every host works with its own key, remove the
   shared key from the root `.gpg-id` (`gopass recipients remove`) and retire
   `push-gpg-key`. Keep the 1Password recovery copy (`secauto-gpg-key`) until then.

Risk: a wrong row locks a host out of an entry it needs, and a mistake at the root
recipient step could lock qbert out of its own store. Do directories one at a time.

## 2. Retire the service-account tooling (bootstrap redesign)

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
