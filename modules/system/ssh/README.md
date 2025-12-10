# SSH Module

OpenSSH server and client configuration with predefined host aliases.

## Features

- **OpenSSH Server**: Enables system-wide SSH daemon
- **SSH Client Config**: Preconfigured host aliases for common servers
- **Key Management**: Automatic key addition to agent for all hosts

## Usage

Enable in your host configuration:

```nix
system.ssh.enable = true;
```

## Predefined Hosts

### Personal Infrastructure
- `remi` - Home server (72.51.28.133)
- `gigi` - Home server (100.96.21.6)
- `camino` - Cloud server

### Ubuntu Budgie Servers
- `ub-ubuntubudgieorg` - Main Ubuntu Budgie server
- `ub-ubuntubudgieorg-webpub` - Web publishing user
- `ub-docker-root` - Docker host (dustin user)
- `ub-docker-admin` - Docker host (docker-admin user)

### Services
- `feral` - Feral hosting server

### Git Providers
- `github.com` - Configured with ed25519 key
- `bitbucket.org` - Configured with ed25519 key
- `git.srvrs.co` - Private git server

### Development/Testing
- `192.168.168.1` - Local KVM/Terraform testing (disables host key checking)

## Global Configuration

All hosts are configured with:
- `AddKeysToAgent yes` - Automatically add keys to SSH agent
- `UseKeychain yes` - Use macOS keychain (ignored on Linux)
- `IdentitiesOnly yes` - Only use explicitly specified keys

## Customization

Edit `modules/system/ssh/default.nix` to add or modify host configurations.

## Security Notes

- The `192.168.168.1` host disables strict host key checking for local development
- All other hosts use standard SSH security practices
- Ensure your `~/.ssh/id_ed25519` key is properly secured with a passphrase
