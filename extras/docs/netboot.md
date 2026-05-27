# netboot.xyz on srv

iPXE-based network boot menu running as a LinuxServer Docker container on
`srv`. Lets any machine on the main LAN PXE-boot installers and rescue
ISOs (NixOS, Talos, SystemRescue, GParted, Memtest86+, Clonezilla,
Ubuntu LTS, and the rest of the upstream netboot.xyz catalog) without
maintaining local ISOs.

## Enable

```nix
server.netbootXyz.enable = true;
```

Defined in `modules/server/netboot-xyz/default.nix`. All ports and
interface scopes are options on `server.netbootXyz.*` -- see the module
for the full list.

## Ports

| Service             | Host port | Interfaces                | Notes                             |
| ------------------- | --------- | ------------------------- | --------------------------------- |
| TFTP (PXE bootstrap)| 69/udp    | `enp3s0`                  | Stage-1 iPXE loader               |
| HTTP boot files     | 8080/tcp  | `enp3s0`                  | Avoids Caddy on 80                |
| Web admin UI        | 3000/tcp  | `enp3s0` + `tailscale0`   | No auth -- keep off public nets   |

State: `/srv/netboot.xyz/{config,assets}`, owned `1000:100` to match the
existing NFS export convention.

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

### Verify

From a host on the LAN:

```bash
# TFTP smoke test
tftp 192.168.168.1
> get netboot.xyz.efi /tmp/netboot.xyz.efi
> quit
ls -l /tmp/netboot.xyz.efi    # expect ~1MB

# HTTP boot file server
curl -fsSI http://192.168.168.1:8080/menu.ipxe | head

# Admin UI (LAN or Tailscale)
xdg-open http://srv:3000
```

PXE a real client by setting boot priority to network in firmware, or
spin up a libvirt VM with `network` first in `<os><boot>` and watch
TFTP -> iPXE chainload -> netboot.xyz menu.

## Upgrades

The container tracks `lscr.io/linuxserver/netbootxyz:latest`. To pull a
newer image:

```bash
sudo docker pull lscr.io/linuxserver/netbootxyz:latest
sudo systemctl restart docker-netboot-xyz
```

Pin to a specific tag in `hosts/srv/modules.nix` via
`server.netbootXyz.image = "lscr.io/linuxserver/netbootxyz:0.7.5";` if
reproducibility matters more than fresh menu data.
