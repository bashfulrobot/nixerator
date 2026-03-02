# SSH Module

OpenSSH server and client configuration with predefined host aliases.

## Enable

```nix
system.ssh.enable = true;
```

## Predefined Hosts

**Personal Infrastructure**: `remi` (72.51.28.133), `gigi` (100.96.21.6), `camino`

**Ubuntu Budgie Servers**: `ub-ubuntubudgieorg`, `ub-ubuntubudgieorg-webpub`, `ub-docker-root`, `ub-docker-admin`

**Services**: `feral`

**Git Providers**: `github.com`, `bitbucket.org`, `git.srvrs.co` — all ed25519

**Dev/Testing**: `192.168.168.1` — local KVM (host key checking disabled)

## Global Client Settings

All hosts: `AddKeysToAgent yes`, `UseKeychain yes`, `IdentitiesOnly yes`

Edit host configs in `modules/system/ssh/default.nix`.
