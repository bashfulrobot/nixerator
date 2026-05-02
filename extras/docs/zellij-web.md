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

## After deploy: mint a token

Zellij web requires a bearer token to authenticate. Tokens are minted
on the host:

```
ssh srv
zellij web --create-token srv-primary
```

The command prints a one-time URL of the form
`https://zellij.goat-cloud.ts.net/?token=<token>`. Open that URL in any
browser on the tailnet; the cookie set on the first visit is what
keeps you authenticated thereafter.

Tokens are bearer credentials -- treat them like passwords. Do **not**
commit them to Nix or activation scripts.

## Listing, revoking, rotating

```
zellij web --list-tokens                  # list active tokens
zellij web --revoke-token <name>          # revoke by name
zellij web --revoke-all-tokens            # nuclear option
```

To rotate, revoke the old name and create a new one with the same name
(or a new name).

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
