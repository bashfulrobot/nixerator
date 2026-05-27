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
  lanAddress = "192.168.168.1";                          # bind TFTP listener here
  adminAddresses = [ "192.168.168.1" "100.64.187.14" ];  # admin UI on LAN + Tailscale
  blockBridges = [ "virbr+" ];                            # keep libvirt guests out
};
```

Defined in `modules/server/netboot-xyz/default.nix`. All ports,
interfaces, and addresses are options on `server.netbootXyz.*` -- see
the module for the full list.

## Exposure model

| Service             | Host port | Bound to                                | Reachable from                |
| ------------------- | --------- | --------------------------------------- | ----------------------------- |
| TFTP (PXE)          | 69/udp    | `192.168.168.1`                         | main LAN only                 |
| Web admin UI        | 3000/tcp  | `192.168.168.1` + `100.64.187.14`       | main LAN + Tailscale          |
| HTTP boot files     | 8080/tcp  | not published (`localMirror` off)       | nowhere -- listener is in-container only |

Three layers stack:

1. **Listener-binding (primary).** The container is published only on
   specific host IPs (`lanAddress` for TFTP, each of `adminAddresses`
   for the admin UI). The unauthenticated admin UI cannot be reached
   from any interface whose IP is not in `adminAddresses`.

2. **`blockBridges` PREROUTING bypass.** Docker's published-port DNAT
   lives in `nat/PREROUTING` with no input-interface predicate, so a
   libvirt guest routing through srv toward `192.168.168.1` would
   *otherwise* hit the admin UI before any INPUT/FORWARD ACL runs.
   `blockBridges = [ "virbr+" ]` installs explicit
   `nat/PREROUTING -i virbr+ ... -j RETURN` rules that bypass Docker's
   DNAT for traffic arriving on any libvirt bridge. The kernel then
   has no listener on `192.168.168.1` and the packet is dropped.

3. **Per-interface firewall (defense-in-depth).** TFTP and the admin
   UI are also opened in `networking.firewall.interfaces.*`. This
   scoping is decorative on srv because the kvm module installs an
   `iptables -A INPUT -j ACCEPT` for routing, but it's correct on
   hosts without that override and harmless otherwise.

State lives in `/srv/netboot.xyz/{config,assets}` at mode `0750`
(non-`puid` host users need `sudo` to read menus or cached assets).

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

By default, iPXE boot files served via TFTP chain-load menus from
`https://boot.netboot.xyz` over the LAN's internet connection. The
container also runs a local nginx that can serve mirrored menus and
downloaded ISOs from `<lanAddress>:<httpPort>`, but **upstream menus
do not use it out of the box** and exposing the listener for no reason
is unused attack surface. The HTTP port is therefore **not** published
or opened in the firewall by default.

To enable local-mirror booting:

1. Set `server.netbootXyz.localMirror.enable = true;` in
   `hosts/srv/modules.nix`, rebuild.
2. Open the admin UI (`http://srv:3000`).
3. Edit `boot.cfg` (under "Boot Configuration"), set:
   - `live_endpoint = http://192.168.168.1:8080`
4. Save and re-deploy the menu. Subsequent PXE boots will pull from
   the local mirror.

## Verify

From a host on the LAN:

```bash
# TFTP smoke test (single-port mode)
tftp 192.168.168.1
> get netboot.xyz.efi /tmp/netboot.xyz.efi
> quit
ls -l /tmp/netboot.xyz.efi    # expect ~1MB

# Admin UI (LAN or Tailscale)
xdg-open http://srv:3000
```

End-to-end test: configure a libvirt VM with `<boot dev='network'/>`
first and watch TFTP -> iPXE chainload -> netboot.xyz menu. Note that
libvirt guests are explicitly blocked by the `blockBridges` rules, so
PXE booting an in-host VM through srv's netboot service will not work
-- if you need that, add an exception or PXE-boot the VM from a host
on the main LAN instead.

## Upgrades

The container is digest-pinned in
`modules/server/netboot-xyz/default.nix`. To pull a newer build, look
up the new digest and update the module:

```bash
# 1. Look up the current digest for the moving :latest tag
TOKEN=$(curl -fsS "https://ghcr.io/token?scope=repository:netbootxyz/netbootxyz:pull" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')
curl -fsSI -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.oci.image.index.v1+json" \
  "https://ghcr.io/v2/netbootxyz/netbootxyz/manifests/latest" \
  | grep -i 'docker-content-digest'
# -> docker-content-digest: sha256:<new digest>

# 2. Update server.netbootXyz.image in modules/server/netboot-xyz/default.nix
#    to the new sha256:... reference

# 3. Rebuild srv. `just rebuild` (or wherever this flake is consumed).
```

Or override per host without touching the module default:

```nix
server.netbootXyz.image = "ghcr.io/netbootxyz/netbootxyz@sha256:<new digest>";
```

Pinning by digest (rather than `:latest`) means a compromise of the
upstream registry cannot silently push code into the container without
this file changing in git.
