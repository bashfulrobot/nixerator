# yepanywhere

Mobile supervision for Claude Code and Codex agents. Approve sessions, get push notifications, and upload files from your phone.

## Enable

```nix
apps.cli.yepanywhere.enable = true;   # also enabled via ai suite
```

Requires `apps.cli.claude-code.enable = true` (assertion enforced).

## How It Works

Yepanywhere runs a local web server that auto-detects Claude Code installations by reading `~/.claude/`. It's deployed as a systemd user service that starts on login and restarts on failure.

Open the web UI from any device on your local network.

## Options

```nix
apps.cli.yepanywhere = {
  enable = true;
  port = 3400;          # default
  openFirewall = false;  # default -- set true for LAN access
};
```

## Usage

### Local access

After rebuild, the service starts automatically:

```bash
# Check service status
systemctl --user status yepanywhere

# View logs
journalctl --user -u yepanywhere -f

# Open the web UI
xdg-open http://localhost:3400
```

### LAN access (phone on same network)

1. Set `openFirewall = true` and rebuild
2. Find your machine's IP: `ip -4 addr show | grep inet`
3. Open `http://<your-ip>:3400` on your phone

### Remote access (anywhere)

One-time setup after first deploy:

```bash
yepanywhere --setup-remote-access --username <user> --password <pass>
```

This registers with the yepanywhere.com relay. Credentials are stored locally in `~/.yepanywhere/`. After setup, access your agents from anywhere via the relay.

## Service Management

```bash
# Restart
systemctl --user restart yepanywhere

# Stop (until next login)
systemctl --user stop yepanywhere

# Disable (persistent, until next rebuild)
systemctl --user disable yepanywhere
```

## Troubleshooting

**Service won't start**: Check logs with `journalctl --user -u yepanywhere -e`. Common issues:
- Port 3400 already in use -- change `port` option
- Node version too old -- module uses nixpkgs nodejs (>= 20)

**Phone can't connect**: Ensure `openFirewall = true` is set and both devices are on the same network.

**No sessions visible**: Verify Claude Code is running and has active sessions in `~/.claude/projects/`.

## Notes

- Built with `buildNpmPackage` from the npm registry tarball (reproducible, cached)
- Runs as your user (not root) via Home Manager systemd user service
- Version pinned in `settings/versions.nix`
- Source: https://github.com/kzahel/yepanywhere
