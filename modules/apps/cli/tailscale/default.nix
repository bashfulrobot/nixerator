{
  lib,
  pkgs,
  config,
  globals,
  secrets,
  ...
}:

let
  cfg = config.apps.cli.tailscale;

  # The rendered Nix-eval secrets file on the target host (0600). Read at
  # runtime by tailscale-node-authkey.service below -- NOT interpolated at
  # eval time -- so the tailnet auth key never lands in the world-readable
  # Nix store. See extras/docs/secrets.md.
  secretsFile = "${globals.user.homeDirectory}/.config/nixos-secrets/secrets.json";

  # Eval-time gate: only wire up tailnet auto-join once a node auth key has
  # been rendered. This derives a boolean from the secret (existence /
  # non-emptiness) and keeps the value itself out of the config. Until the
  # `tailscale-node-authkey` 1Password item is wired (issue #107), this is
  # false and auto-join stays inert -- disabling Tailscale SSH (below) still
  # applies.
  hasNodeAuthKey = (secrets.tailscale.nodeAuthKey or "") != "";

  # Runtime location of the materialized bare auth key (root-only).
  nodeAuthKeyFile = "/run/tailscale/node-authkey";
in
{
  options = {
    apps.cli.tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable tailscale mesh VPN.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;

      # Auto-join the tailnet with a reusable auth key (issue #107). The bare
      # key is materialized to a 0600 runtime file by
      # tailscale-node-authkey.service; the module's tailscaled-autoconnect
      # service only runs `tailscale up` when the node is NOT already logged
      # in, so nodes already on the tailnet are left undisturbed.
      authKeyFile = if hasNodeAuthKey then nodeAuthKeyFile else null;

      # Use the regular OpenSSH daemon (system.ssh) for SSH access, NOT the
      # Tailscale SSH server (issue #107). `tailscale set --ssh=false` runs on
      # every activation via the module's tailscaled-set service, so any node
      # that previously had Tailscale SSH enabled gets it switched off. We also
      # never pass `--ssh` to `tailscale up`, so fresh joins never enable it.
      extraSetFlags = [ "--ssh=false" ];
    };

    environment.systemPackages = with pkgs; [
      tailscale # zero-config VPN
    ];

    # Materialize the bare node auth key from the rendered secrets file into a
    # root-only runtime file, ordered before tailscaled-autoconnect consumes
    # it. Extracting at runtime (rather than interpolating the eval-time
    # secret) keeps the tailnet auth key out of the world-readable Nix store.
    systemd.services.tailscale-node-authkey = lib.mkIf hasNodeAuthKey {
      description = "Materialize Tailscale node auth key for autoconnect";
      after = [ "tailscaled.service" ];
      before = [ "tailscaled-autoconnect.service" ];
      wantedBy = [ "tailscaled-autoconnect.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        umask 077
        install -d -m 0700 /run/tailscale
        ${pkgs.jq}/bin/jq -r '.tailscale.nodeAuthKey // empty' ${secretsFile} \
          > ${nodeAuthKeyFile}
        chmod 0600 ${nodeAuthKeyFile}
      '';
    };

    # Run the `--ssh=false` set after any auto-join completes, so the node is
    # logged in by the time `tailscale set` runs (avoids a spurious failed
    # unit on first boot). Harmless no-op ordering when autoconnect is absent.
    systemd.services.tailscaled-set.after = [ "tailscaled-autoconnect.service" ];

    # https://github.com/NixOS/nixpkgs/issues/180175#issuecomment-2372305193
    systemd.services.tailscaled.after = [
      "NetworkManager-wait-online.service"
    ];
  };
}
