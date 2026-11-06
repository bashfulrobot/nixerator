# ncspot: pinned fork with its own Spotify client ID

Why ncspot on NixOS is built from `bashfulrobot/ncspot` instead of nixpkgs, how
the pin and its hashes work, and how to bump or retire it. Read this before
editing `ncspotPin` or the ncspot override in `modules/apps/cli/spotify/default.nix`.

## Why

- ncspot ships one Spotify client ID for every user. Spotify rate limits the Web
  API per client ID, so from Oct 2026 startup hits 429s and shows a blank screen
  for 20 seconds or more (hrkfdn/ncspot#1867, #1757).
- Upstream fixes #1886 and #1887 cut the request volume. They are on upstream
  main but not in release 1.5.0, which is what nixpkgs ships.
- ncspot has no setting for a client ID (a constant in `src/authentication.rs`).
  A personal client ID needs a patched build.

## What the pin is

- Fork: `github.com/bashfulrobot/ncspot`, branch `dk`, tags `v<upstream>-dk<N>`.
  Upstream main plus a few small commits: a fixed redirect port (8888, because
  Spotify's dashboard rejects a portless loopback URI), the personal client ID,
  and a maintenance `justfile` (`just status` in the fork lists them).
- `programs.ncspot.package` is `pkgs.ncspot.override { withMPRIS = true; }`
  with `overrideAttrs` swapping in the fork's source and cargo vendor. The pin
  (`rev`, `version`, `srcHash`, `cargoHash`) sits in one `let` block.
- The override applies only while `pkgs.ncspot.version` is older than 1.5.1
  (`lib.versionOlder`). That guard retires upstream's gap, not the fork: the
  client ID patch is only in the fork. Revisit the guard when the pin moves.
- The Mac pins the same rev in donkeykong's `Cargofile`. Keep both on one rev.

## Rebuild rule (do not break)

`rev`, `version` and both hashes are fixed, so the derivation is constant and a
normal `just qr` reuses the store path. Rebuilds of ncspot happen only when `rev`
changes. Never add anything per-rebuild (timestamps, `builtins.currentTime`,
`fetchGit` without a rev).

## Bump the pin

1. In the fork (`~/git/ncspot`): `just sync`, `just tag`, `just pins` for the rev.
2. Compute both hashes on qbert, not on the Mac (it has no nix):
   - `srcHash`: `nix-prefetch-url --unpack https://github.com/bashfulrobot/ncspot/archive/<rev>.tar.gz`, then convert with `nix hash convert --hash-algo sha256 --to sri <hash>`.
   - `cargoHash`: set it to `lib.fakeHash`, build only the package
     (`nix build` of the override, not a system rebuild), and copy the `got:` hash
     from the mismatch of the `vendor-staging` derivation.
   - Wrap remote scripts as `ssh qbert bash -s < script` (login shell is fish).
3. Edit the `let` block, build the package on qbert, check `ncspot --version`.
4. `buildRustPackage` consumes `cargoHash` before `overrideAttrs`, so the module
   replaces `cargoDeps` outright. `preVersionCheck = "version=1.5.0"` keeps
   `versionCheckHook` happy while upstream's Cargo.toml says 1.5.0.

## Secrets

- Client ID and secret live in 1Password (Personal vault, item `spotify.com`,
  fields `ncspot-client-id`, `ncspot-client-secret`) and reach gopass as
  `spotify/ncspot-client-id` and `spotify/ncspot-client-secret` through rows in
  `modules/apps/cli/render-secrets/gopass-map.tsv`, imported by Dustin with
  `just import-secrets-to-gopass` on qbert.
- ncspot uses PKCE, so the secret is never used. The client ID is public and is
  committed in the fork. Never read either value into the conversation. Follow
  `extras/docs/secrets.md`.
- The Spotify app's redirect URI is exactly `http://127.0.0.1:8888/ncspot_login`.
  After a client ID change, the first login runs a browser OAuth round trip.

## Retire the fork

Do it when upstream lets users set their own client ID, or when the shared ID
stops being throttled and nixpkgs ships a release with #1886 and #1887. Then
remove the override and `ncspotPin`, go back to `pkgs.ncspot.override`, and
update the donkeykong pin in the same sitting.

## Related

- `ncspot-save-playing` sends `save current` over ncspot's IPC socket; plain
  `save` acts on the selected item, not the playing one (PR #755).
- On the Mac, donkeykong's `docs/ai/ncspot.md` covers the Cargofile side.
