# Hosts Reference

Detailed information about each host configuration.

## qbert (Desktop Workstation)

**Hardware:** Custom desktop with AMD GPU

**Features:**

- bcachefs filesystem (via disko)
- AMD GPU with specific power management workarounds
- USB wakeup configuration
- Wake-on-LAN enabled
- Syncthing for file sync
- KVM virtualization with network routing

**Key Files:**

- `hosts/qbert/configuration.nix` - Main config
- `hosts/qbert/disko.nix` - Disk partitioning
- `hosts/qbert/gpu.nix` - AMD GPU setup
- `hosts/qbert/power-management.nix` - AMD suspend workarounds
- `hosts/qbert/modules.nix` - Host-specific modules
- `hosts/qbert/reboot-windows.nix` - Dual-boot Windows support

**Archetype:** workstation

**Special Notes:**

- AMD GPU has suspend bugs; see `power-management.nix` for workarounds
- hyprflake configured with suspend disabled via `hyprflake.desktop.idle.suspendTimeout = 0`

## donkeykong (ThinkPad T14 Laptop)

**Hardware:** Lenovo ThinkPad T14 Intel Gen 6

**Features:**

- LUKS full-disk encryption
- disko declarative partitioning with ext4
- 32GB swap
- nixos-hardware ThinkPad T14 Intel Gen 6 module
- USB wakeup configuration
- Syncthing for file sync
- KVM virtualization with WiFi routing

**Key Files:**

- `hosts/donkeykong/configuration.nix` - Main config
- `hosts/donkeykong/disko.nix` - LUKS + ext4 partitioning
- `hosts/donkeykong/boot.nix` - Bootloader with LUKS support
- `hosts/donkeykong/usb-wakeup.nix` - Laptop wakeup config
- `hosts/donkeykong/modules.nix` - Host-specific modules

**Archetype:** workstation

**Hardware Module:** `nixos-hardware.nixosModules.lenovo-thinkpad-t14-intel-gen6`

## nixerator (VM Development Host)

**Hardware:** Virtual machine

**Features:**

- virtiofs shared folder support
- Development/testing environment
- Minimal hardware configuration

**Key Files:**

- `hosts/nixerator/configuration.nix` - Main config
- `hosts/nixerator/vm.nix` - VM-specific settings
- `hosts/nixerator/boot.nix` - Bootloader

**Archetype:** workstation

**Special Notes:**

- Used for testing NixOS changes before deploying to physical hosts

## srv (Home Server)

**Hardware:** Home server (static network configuration)

**Features:**

- Static IP: 192.168.168.1
- KVM virtualization with network routing
- NFS server for network storage
- Backrest (restic-backed) backup server (B2 cloud storage)
- Docker support
- Tailscale mesh networking

**Key Files:**

- `hosts/srv/configuration.nix` - Main config with static networking
- `hosts/srv/modules.nix` - Server-specific modules (manual imports)
- `hosts/srv/boot.nix` - Bootloader

**Archetype:** None (uses manual module imports)

**Services:**

| Service | Description |
|---------|-------------|
| NFS | Exports `/srv/nfs/spitfire` to 172.16.166.0/24 |
| Backrest + Restic | Scheduled backups at 03:00 daily to B2 |
| KVM | Virtualization with multiple bridge networks |
| Docker | Container runtime |

**Special Notes:**

- Does not auto-import modules; uses explicit imports in `modules.nix`
- Secrets for restic credentials used by the backup stack (repository, password, B2 credentials) are stored in git-crypt encrypted `secrets/secrets.json`

## Host Configuration Pattern

Each host follows this structure:

```
hosts/<hostname>/
├── configuration.nix      # Main entry point
├── hardware-configuration.nix  # Generated hardware config
├── home.nix               # Home Manager configuration
├── modules.nix            # Host-specific module enables
├── boot.nix               # Bootloader configuration
└── [other].nix            # Host-specific features
```

### Adding Host-Specific Modules

In `modules.nix`:

```nix
_:

{
  # Enable specific apps
  apps.cli.syncthing = {
    enable = true;
    host.<hostname> = true;
  };

  # Enable server features
  server.kvm = {
    enable = true;
    routing.enable = true;
  };
}
```
