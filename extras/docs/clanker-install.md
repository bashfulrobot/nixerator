# Installing clanker

How to bring up `clanker`, the headless Claude Code VM, from scratch.

clanker is a desktop-less VM whose only graphical job is to give Claude (over
SSH) a live Wayland session to launch apps in and screenshot. It boots straight
into an autologin, never-locking Sway session. There is no VNC; visuals come
back as screenshots pushed to the phone.

The whole install is one script run from a stock NixOS installer ISO. The script
itself is documented in [`helpers.md`](helpers.md#clanker-installsh); this page is
the start-to-finish walkthrough.

## Prerequisites

- A VM configured for **legacy BIOS** with a single **virtio disk at `/dev/vda`**
  (the disko layout in `hosts/clanker/disko.nix` targets that device). For a UEFI
  VM instead, swap the `EF02` partition in `disko.nix` for an `EF00` ESP mounted
  at `/boot` and switch `hosts/clanker/boot.nix` to systemd-boot.
- A stock **NixOS minimal ISO** booted in the VM, with networking.
- Your 1Password **service-account token** (`ops_...`) to hand to the installer
  when it prompts. Nothing else needs pre-installing.

## Install

On the booted ISO, as root:

```bash
nix-shell -p git --run 'git clone https://github.com/bashfulrobot/nixerator /tmp/nixerator'
sudo bash /tmp/nixerator/extras/helpers/clanker-install.sh
```

The script will:

1. Ask you to confirm the destructive wipe of `/dev/vda` (type `yes`).
2. Prompt once (hidden) for the service-account token.
3. Render secrets, build clanker, partition and format the disk, install the
   system, and seed the dustin user's home with the repo clone, the op token,
   the rendered secrets, and a fresh SSH key.

When it finishes it prints an `ed25519` public key.

## After install

1. Add the printed public key to GitHub as **both** an authentication key and a
   signing key (it is used for `git push` and SSH commit signing).
2. `reboot` (the script does not reboot for you).

On the next boot clanker logs in automatically and starts the headless Sway
session. From another host you can `ssh clanker` (or reach it through the `work`
launcher), and:

- `op whoami` works with no prompt (service-account token).
- The repo is at `~/git/nixerator`, so `just rebuild` works with no further setup.
- Claude can launch a GUI app and screenshot it, for example:

  ```bash
  foot &
  grim /tmp/shot.png
  sudo tailscale file cp /tmp/shot.png maximus:
  ```

  An interactive SSH shell auto-exports `WAYLAND_DISPLAY` / `XDG_RUNTIME_DIR`, so
  `grim` and app launches target the running session without any manual setup.

## Notes

- The flake reads `~/.config/nixos-secrets/secrets.json` at eval time, so the
  installer renders it before building. After install, rotate or re-render
  secrets the normal way (`just render-secrets` / `just push-secrets clanker`).
- The token is never echoed, written into the repo, or placed on a command line.
- See [`adding-hosts.md`](adding-hosts.md) for how a host is wired into the flake,
  and [`secrets.md`](secrets.md) for the full 1Password flow.
