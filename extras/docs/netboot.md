# netboot.xyz on srv

iPXE-based network boot menu running as the official netboot.xyz Docker
container (`ghcr.io/netbootxyz/netbootxyz`) on `srv`. Lets any machine
on the main LAN PXE-boot installers and rescue ISOs (NixOS, Talos,
SystemRescue, GParted, Memtest86+, Clonezilla, Ubuntu LTS, and the rest
of the upstream catalog) without maintaining local images.

## Enable

```nix
server.netbootXyz = {
  enable = true;
  lanAddress = "192.168.168.1";                          # bind TFTP + HTTP boot files here
  adminAddresses = [ "192.168.168.1" "100.64.187.14" ];  # admin UI on LAN + Tailscale
};
```

Defined in `modules/server/netboot-xyz/default.nix`. All ports,
interfaces, and addresses are options on `server.netbootXyz.*` -- see
the module for the full list.

## Exposure model

| Service             | Host port | Bound to                                | Defense-in-depth firewall |
| ------------------- | --------- | --------------------------------------- | ------------------------- |
| TFTP (PXE)          | 69/udp    | `192.168.168.1`                         | `enp3s0` only             |
| HTTP boot files     | 8080/tcp  | `192.168.168.1`                         | `enp3s0` only             |
| Web admin UI        | 3000/tcp  | `192.168.168.1` + `100.64.187.14` (TS)  | `enp3s0` + `tailscale0`   |

**Listener-binding is the primary control.** srv's kvm module installs
an `iptables -A INPUT -j ACCEPT` rule (needed for inter-bridge routing)
that bypasses per-interface firewall scoping. Binding container ports
to specific host IPs means the unauthenticated admin UI is not reachable
from libvirt guests on `virbr1..virbr7` -- only from clients that can
hit `192.168.168.1` (main LAN) or the Tailscale address.

State lives in `/srv/netboot.xyz/{config,assets}` owned `1000:1000` (the
upstream container's default uid/gid). The host user can read files
under that tree without `sudo`; edits to menus over SSH need either
`sudo` or aligning `server.netbootXyz.pgid` with your primary group.

## TFTP through Docker NAT

The module sets `TFTPD_OPTS=--tftp-single-port` so dnsmasq inside the
container uses port 69 for both the initial request and the data
transfer. Without this flag, TFTP fails silently behind Docker NAT
because modern kernels do not auto-attach the `nf_conntrack_tftp`
helper, and the ephemeral data ports get dropped on the way back.

Disable via `server.netbootXyz.tftpSinglePort = false;` only if you
have set up a conntrack helper or run the container on host networking.

## UniFi DHCP configuration

UniFi is external to Nix, so configure it via the UniFi controller UI.
Settings panel locations vary by controller version; check the upstream
[UniFi DHCP options docs](https://help.ui.com/hc/en-us/articles/204909754)
if a control isn't where this guide says it is.

### Single-architecture (simple) setup

In **Settings -> Networks -> [your LAN] -> DHCP Service**, set:

- **Network Boot**: enabled
- **TFTP Server (DHCP option 66)**: `192.168.168.1`
- **Boot File (DHCP option 67)**:
  - UEFI x86_64 clients: `netboot.xyz.efi`
  - Legacy BIOS clients:  `netboot.xyz.kpxe`

Pick the boot file matching the majority of your fleet. Mixed fleets
need the arch-aware setup below.

### Arch-aware setup (mixed BIOS + UEFI)

UniFi 8.x exposes per-client-architecture boot file selection through
DHCP option 93 (`client-architecture`). Configurable via the **Advanced
DHCP Options** panel or via the `config.gateway.json` override on
self-hosted controllers:

```json
{
  "service": {
    "dhcp-server": {
      "shared-network-name": {
        "LAN": {
          "subnet": {
            "192.168.168.0/23": {
              "subnet-parameters": [
                "next-server 192.168.168.1;",
                "if option arch = 00:07 { filename \"netboot.xyz.efi\"; } else if option arch = 00:09 { filename \"netboot.xyz.efi\"; } else { filename \"netboot.xyz.kpxe\"; }"
              ]
            }
          }
        }
      }
    }
  }
}
```

Place at `/srv/unifi/data/sites/default/config.gateway.json` on the
controller, then **force-provision** the gateway.

## Local mirror (optional)

By default, the iPXE boot files served via TFTP chain-load menus from
`https://boot.netboot.xyz` over the LAN's internet connection. The
container also runs a local nginx on port 8080 that can serve the
mirrored menus + downloaded ISOs, but **upstream menus do not use it
out of the box** -- you have to redirect them.

To enable local-mirror booting:

1. Open the admin UI (`http://srv:3000`).
2. Edit `boot.cfg` (under "Boot Configuration"), set:
   - `live_endpoint = http://192.168.168.1:8080`
3. Save and re-deploy the menu. Subsequent PXE boots will pull from
   the local mirror.

Without that override, port 8080 in the firewall is opened but unused.
Leave it as-is for future flexibility.

## Verify

From a host on the LAN:

```bash
# TFTP smoke test (single-port mode)
tftp 192.168.168.1
> get netboot.xyz.efi /tmp/netboot.xyz.efi
> quit
ls -l /tmp/netboot.xyz.efi    # expect ~1MB

# HTTP boot file server (returns 200 once menus are deployed)
curl -fsSI http://192.168.168.1:8080/menu.ipxe

# Admin UI (LAN or Tailscale)
xdg-open http://srv:3000
```

End-to-end test: configure a libvirt VM with `<boot dev='network'/>`
first and watch TFTP -> iPXE chainload -> netboot.xyz menu in the
viewer.

## Upgrades

The container tracks `ghcr.io/netbootxyz/netbootxyz:latest`. To pull a
newer image:

```bash
sudo docker pull ghcr.io/netbootxyz/netbootxyz:latest
sudo systemctl restart docker-netboot-xyz
```

Pin to a specific tag in `hosts/srv/modules.nix` via
`server.netbootXyz.image = "ghcr.io/netbootxyz/netbootxyz:0.7.5";` if
reproducibility matters more than fresh menu data.
