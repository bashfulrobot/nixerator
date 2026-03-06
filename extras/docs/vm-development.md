# VM Development

Development VM using virtiofs to share the repository from the host machine. Edit on host, test in VM, rebuild without affecting your host system.

## Prerequisites

- libvirt/KVM on host
- NixOS VM
- virtiofs support (qemu 5.0+, libvirt 6.2+)

## Variables

Set once before running commands (bash shown; for fish use `set -gx` instead of `export`):

```bash
export VM_NAME="<your-vm-name>"
export REPO_PATH="$HOME/dev/nix/nixerator"
export SHARE_TAG="mount_nixerator"
export CURRENT_HOST="$(hostname)"
export CURRENT_USER="$(id -un)"
export CURRENT_GROUP="$(id -gn)"
```

## Host Setup

### 1. Configure virtiofs Share

Add to VM's libvirt XML (inside `<devices>`):

```xml
<filesystem type="mount" accessmode="passthrough">
  <driver type="virtiofs"/>
  <source dir="/path/on/host/to/nixerator"/>
  <target dir="mount_nixerator"/>
</filesystem>
```

Or via virt-manager: Add Hardware > Filesystem > Driver: virtiofs, Source: repo path, Target: `mount_nixerator`.

### 2. Start VM

```bash
virsh start "$VM_NAME"
```

## VM Initial Setup

```bash
sudo mkdir -p "$REPO_PATH"
sudo mount -t virtiofs "$SHARE_TAG" "$REPO_PATH"
sudo chown -R "$CURRENT_USER:$CURRENT_GROUP" "$REPO_PATH"
cd "$REPO_PATH" && sudo nixos-rebuild switch --flake ".#$CURRENT_HOST"
```

After first rebuild, mount is persistent (configured in `hosts/nixerator/vm.nix`):

```nix
fileSystems.${globals.paths.nixerator} = {
  device = "mount_nixerator";
  fsType = "virtiofs";
  options = [ "rw" ];
};
```

## Development Workflow

1. Edit on host in `$REPO_PATH`
2. In VM: `nix flake check --show-trace`, then `sudo nixos-rebuild switch --flake ".#$CURRENT_HOST"`
3. Commit from either side (same repo)

## Troubleshooting

- **`mount: no such device`** -- virtiofs not configured in XML. Fully shut down VM (`virsh shutdown` / `virsh destroy`), edit XML, restart.
- **Permission denied** -- `sudo chown -R "$CURRENT_USER:$CURRENT_GROUP" "$REPO_PATH"`
- **Mount gone after reboot** -- run `nixos-rebuild switch` at least once with VM host target; ensure `hosts/nixerator/vm.nix` is imported.
- **Slow performance** -- ensure 4GB+ RAM, SSD, verify `ps aux | grep virtiofsd` on host.
