# Hosts Reference

Active `nixosConfigurations` outputs: `donkeykong`, `qbert`, `srv`.

## qbert (Desktop Workstation)

**Hardware**: Custom desktop, AMD GPU
**Archetype**: workstation

- ext4 (disko), AMD GPU with suspend workarounds (`power-management.nix`)
- USB wakeup, Wake-on-LAN, Syncthing, KVM with network routing, whisper-server
- `reboot-windows.nix` for dual-boot EFI reboot
- hyprflake: `desktop.idle.suspendTimeout = 0` (AMD suspend bugs)

## donkeykong (ThinkPad T14 Laptop)

**Hardware**: Lenovo ThinkPad T14 Intel Gen 6
**Archetype**: workstation

- LUKS full-disk encryption, disko ext4 partitioning, 32GB swap
- nixos-hardware: `lenovo-thinkpad-t14-intel-gen6`
- `usb-wakeup.nix`, Syncthing, KVM with WiFi routing

## nixerator (VM Profile)

Reusable VM profile files  -- not a standalone `nixosConfigurations` output.

- `hosts/nixerator/vm.nix`  -- virtiofs shared-folder setup
- `hosts/nixerator/home.nix`  -- Home Manager profile
- Import `vm.nix` into a VM host configuration to enable

## srv (Home Server)

**Hardware**: Home server, static IP 192.168.168.1
**Archetype**: none (manual module imports in `modules.nix`)

- KVM with network routing, NFS server, Docker, Tailscale
- Backrest (restic-backed) backup to B2 cloud storage
- NFS exports `/srv/nfs/spitfire` to 172.16.166.0/24
- Restic `backup-mgr`: daily at 03:00 to B2
- Backrest: on-demand via `backrest`, UI at `http://127.0.0.1:9898`
- Secrets for restic credentials in git-crypt `secrets/secrets.json`

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
