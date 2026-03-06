# SSH Module

OpenSSH server and client configuration with predefined host aliases.

## Enable

```nix
system.ssh.enable = true;
```

## Predefined Hosts

**Remote**: `camino` (64.225.50.102, root), `budgie` (ubuntubudgie.org), `feral` (prometheus.feralhosting.com)

**Local Network**: `qbert` (192.168.169.2), `srv` (192.168.168.1), `dk` (192.168.169.3)

**Git Providers**: `github.com`, `bitbucket.org`, `git.srvrs.co` (all ed25519)

**Dev/Testing**: `192.168.168.1` (KVM, host key checking disabled)

## Global Client Settings

All hosts: `AddKeysToAgent yes`, `UseKeychain yes`, `IdentitiesOnly yes`

Edit host configs in `modules/system/ssh/default.nix`.
