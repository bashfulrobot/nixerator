# VM Development Environment

Guide for setting up VM development with the reusable `hosts/nixerator/vm.nix` profile.

## Overview

The `hosts/nixerator/vm.nix` module configures a development VM to use virtiofs for sharing the repository from the host machine. This allows you to:

- Edit nixerator configuration on your host machine
- Test changes in an isolated VM environment
- Rebuild the VM profile without affecting your host system

## Prerequisites

- libvirt/KVM installed on host machine
- NixOS ISO or existing NixOS VM
- virtiofs support in libvirt (qemu 5.0+, libvirt 6.2+)

## Variables (Set Once)

Set these once in your shell before running the commands below:
After this setup, the remaining command samples work in both shells.

```bash
# bash/zsh
export VM_NAME="<your-vm-name>"
export REPO_PATH="$HOME/dev/nix/nixerator"
export SHARE_TAG="mount_nixerator"
export CURRENT_HOST="$(hostname)"
export CURRENT_USER="$(id -un)"
export CURRENT_GROUP="$(id -gn)"
```

```fish
# fish
set -gx VM_NAME "<your-vm-name>"
set -gx REPO_PATH "$HOME/dev/nix/nixerator"
set -gx SHARE_TAG "mount_nixerator"
set -gx CURRENT_HOST (hostname)
set -gx CURRENT_USER (id -un)
set -gx CURRENT_GROUP (id -gn)
```

## Host Machine Setup

### 1. Configure virtiofs Share

Add this to your VM's libvirt XML configuration:

```xml
<filesystem type="mount" accessmode="passthrough">
  <driver type="virtiofs"/>
  <source dir="/path/on/host/to/nixerator"/>
  <target dir="mount_nixerator"/>
</filesystem>
```

**Note**: Replace `/path/on/host/to/nixerator` with the actual path to your nixerator repository.

### 2. Edit VM Configuration

Using `virt-manager`:

1. Open VM settings
2. Add Hardware → Filesystem
3. Driver: virtiofs
4. Source path: `/path/on/host/to/nixerator`
5. Target path: `mount_nixerator`

Or edit XML directly:

```bash
virsh edit "$VM_NAME"
```

Add the filesystem block above inside `<devices>...</devices>`.

### 3. Start the VM

```bash
virsh start "$VM_NAME"
```

## VM Initial Setup

### 1. Mount the Shared Directory

After booting the VM:

```bash
# Create mount point
sudo mkdir -p "$REPO_PATH"

# Mount the virtiofs share
sudo mount -t virtiofs "$SHARE_TAG" "$REPO_PATH"

# Verify
ls -la "$REPO_PATH"
```

### 2. Set Ownership

```bash
# Ensure correct ownership
sudo chown -R "$CURRENT_USER:$CURRENT_GROUP" "$REPO_PATH"
```

### 3. Initial Rebuild

```bash
cd "$REPO_PATH"
sudo nixos-rebuild switch --flake ".#$CURRENT_HOST"
```

After the first rebuild, the mount configuration is permanent and will automatically mount on boot.

## Persistent Mount

The VM profile includes automatic virtiofs mounting:

```nix
# hosts/nixerator/vm.nix
fileSystems.${globals.paths.nixerator} = {
  device = "mount_nixerator";
  fsType = "virtiofs";
  options = [ "rw" ];
};
```

This ensures the share is mounted automatically on every boot.

## Development Workflow

### 1. Edit on Host

Make changes to nixerator configuration on your host machine using your preferred editor:

```bash
# On host machine
cd "$REPO_PATH"
hx modules/apps/cli/mynewapp/default.nix
```

### 2. Test in VM

Changes are immediately visible in the VM:

```bash
# In VM
cd "$REPO_PATH"

# Test syntax
nix flake check --show-trace

# Build without activating
sudo nixos-rebuild build --flake ".#$CURRENT_HOST"

# Apply changes
sudo nixos-rebuild switch --flake ".#$CURRENT_HOST"
```

### 3. Commit from Either Side

Since it's the same repository, you can commit from either host or VM:

```bash
# Works from host or VM
git add .
git commit -m "Add new module"
git push
```

## Troubleshooting

### Mount Not Working

**Error**: `mount: no such device`

**Solution**: Ensure virtiofs is configured in VM XML and VM is fully shut down before adding the filesystem.

```bash
# Fully shut down VM
virsh shutdown "$VM_NAME"

# Force off if needed
virsh destroy "$VM_NAME"

# Edit configuration
virsh edit "$VM_NAME"

# Start again
virsh start "$VM_NAME"
```

### Permission Denied

**Error**: Permission denied accessing files

**Solution**: Check ownership in VM:

```bash
sudo chown -R "$CURRENT_USER:$CURRENT_GROUP" "$REPO_PATH"
```

### Mount Disappears After Reboot

**Issue**: Mount not persistent

**Solution**: Ensure you've run `nixos-rebuild switch` at least once with your VM host flake target and that `hosts/nixerator/vm.nix` is imported.

### Slow Performance

**Issue**: virtiofs operations are slow

**Solutions**:
- Ensure VM has enough RAM (4GB minimum)
- Check host disk I/O (SSD recommended)
- Verify virtiofsd process is running on host

```bash
# On host, check virtiofsd
ps aux | grep virtiofsd
```

## VM Snapshots

Create snapshots before major changes:

```bash
# Create snapshot
virsh snapshot-create-as "$VM_NAME" \
  --name "before-major-change" \
  --description "Snapshot before testing X"

# List snapshots
virsh snapshot-list "$VM_NAME"

# Revert to snapshot
virsh snapshot-revert "$VM_NAME" before-major-change

# Delete snapshot
virsh snapshot-delete "$VM_NAME" before-major-change
```

## Alternative: NFS Mount

If virtiofs is not available, use NFS:

### Host Setup

```bash
# Install NFS server
sudo systemctl enable nfs-server
sudo systemctl start nfs-server

# Export directory
echo "/path/to/nixerator 192.168.122.0/24(rw,sync,no_subtree_check,no_root_squash)" \
  | sudo tee -a /etc/exports

sudo exportfs -ra
```

### VM Setup

```nix
# hosts/nixerator/vm.nix
fileSystems.${globals.paths.nixerator} = {
  device = "192.168.122.1:/path/to/nixerator";
  fsType = "nfs";
  options = [ "nofail" ];
};
```

## Benefits of VM Development

- **Isolation**: Test changes without affecting your main system
- **Snapshots**: Quick rollback if something breaks
- **Clean state**: Easy to rebuild from scratch
- **Safe experimentation**: Try experimental features safely
- **Multi-host testing**: Test configurations for different machines
