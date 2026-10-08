# Hosts Reference

Active `nixosConfigurations` outputs: `qbert`, `srv`.

## qbert (Desktop Workstation)

**Hardware**: Custom desktop, AMD GPU
**Archetype**: workstation

- ext4 (disko), AMD GPU with suspend workarounds (`power-management.nix`)
- USB wakeup, Wake-on-LAN, Syncthing, KVM with network routing, whisper-server
- `reboot-windows.nix` for dual-boot EFI reboot
- hyprflake: `desktop.idle.suspendTimeout = 0` (AMD suspend bugs)

## srv (Home Server)

**Hardware**: Home server, static IP 192.168.168.1
**Archetype**: none (manual module imports in `modules.nix`)

- KVM with network routing, NFS server, Docker, Tailscale
- Backrest (restic-backed) backup to B2 cloud storage
- NFS exports `/srv/nfs/spitfire` to 172.16.166.0/24
- Restic `backup-mgr`: daily at 03:00 to B2
- Backrest: on-demand via `backrest`, UI at `http://127.0.0.1:9898`
- Secrets for restic credentials in git-crypt `secrets/secrets.json`
- Claude Code stack (cherry-picked from `suites/ai`) -- `claude-code` runs in `serverProfile = "minimal"` (kubernetes MCP omitted)

## Host-Specific Modules

In `modules.nix`:

```nix
_:
{
  apps.cli.syncthing = {
    enable = true;
    host.<hostname> = true;
  };
  server.kvm = {
    enable = true;
    routing.enable = true;
  };
}
```
