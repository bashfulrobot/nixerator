# Zellij Web (browser-accessible terminal multiplexer)

`zellij web` exposes a browser client for Zellij sessions. On `srv`, it
runs as a systemd user service, fronted by Caddy on its own tsnet
identity, reachable from any tailnet device.

**URL:** `https://zellij.goat-cloud.ts.net/`

## Prerequisites (one-time)

1. **Tailscale auth key for Caddy.** The system Caddy module
   (`modules/system/caddy`) reads `secrets.tailscale.caddyAuthKey` from
   the git-crypt'd `secrets/secrets.json`. If absent, mint a *reusable*
   auth key in the Tailscale admin console and add it before deploying
   any host that runs Caddy with a tsnet vhost.

2. **First boot of a new tsnet identity.** The first time srv comes up
   with the `zellij` tsnet node configured, Caddy registers it on the
   tailnet (~30 s) and provisions a Let's Encrypt cert via Tailscale's
   HTTPS service. Watch:

   ```
   journalctl -u caddy -f
   ```

## Security model (read this first)

The token is a *bearer credential* for a shell as the `dustin` user on
`srv`. Any device on the tailnet that obtains the token (or the cookie
set after first use) can attach to running zellij sessions and run
arbitrary commands. There is **no second factor**. Mitigations baked
into this deployment:

- The Caddy vhost is bound to a Tailscale identity (`bind tailscale/zellij`);
  there is no public-internet listener.
- `srv` runs `security.sudo.wheelNeedsPassword = true` (NixOS default),
  so a stolen token is **not** equivalent to root -- escalation requires
  `dustin`'s password.
- Caddy strips `Referer` on outbound responses (`Referrer-Policy: no-referrer`),
  so the token cannot leak via Referer when the operator clicks an external
  link from inside a session.
- The vhost is non-frameable (`Content-Security-Policy: frame-ancestors 'none'`).

Operationally:

- Treat the token like a root SSH key. Rotate quarterly at minimum.
- Do **not** commit tokens to Nix, activation scripts, dotfiles, or
  shell history.

## After deploy: mint a token

Zellij web requires a bearer token to authenticate. Tokens are minted
on the host:

```
ssh srv
zellij web --create-token --token-name srv-primary
```

`--token-name` is optional; omit it and zellij auto-names the token
(`token_1`, `token_2`, ...). The command prints the token once -- it
cannot be retrieved later.

The first-visit URL form `https://zellij.goat-cloud.ts.net/?token=<token>`
puts the secret in your browser history, sync, and any server access log
the proxy keeps. Prefer either:

1. Open the bare URL in a browser, then paste the token into the
   in-page login field if zellij offers one (preferred), or
2. Set the auth cookie out-of-band and import it:

   ```
   curl -c cookies.txt "https://zellij.goat-cloud.ts.net/?token=<token>" -o /dev/null
   # then import cookies.txt into the browser via an extension
   ```

The cookie set on first visit is what keeps you authenticated thereafter.

## Listing, revoking, rotating

```
zellij web --list-tokens                  # list token names + creation dates
zellij web --revoke-token <name>          # revoke by name
zellij web --revoke-all-tokens            # nuclear option
```

To rotate: `--revoke-token <old-name>`, then
`--create-token --token-name <new-name>` (or reuse the old name once
the revocation is in).

## Verifying the service

```
systemctl --user status zellij-web        # service health
ss -ltnp | grep 8082                      # confirm zellij is listening
journalctl --user -u zellij-web -f        # tail logs
```

If the browser cannot reach `https://zellij.goat-cloud.ts.net/`, check:

1. The host actually joined the tailnet under that name --
   `tailscale status` from another tailnet device should list it.
2. Caddy is up -- `systemctl status caddy` on srv.
3. The cert was issued -- `journalctl -u caddy | grep -i certificate`.

## Token storage on disk

zellij persists token metadata under `${XDG_DATA_HOME:-~/.local/share}/zellij/`.
If you ever expand `apps.cli.restic.backup.backupPaths` to include
`/home/dustin`, exclude the zellij data directory -- otherwise tokens
end up in the offsite B2 backup.
