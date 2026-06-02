{
  lib,
  config,
  secrets,
  ...
}:
let
  cfg = config.server.harmonia;

  # The signing key is rendered into the secrets blob via render-secrets.
  # On a fresh host (or before the 1Password entry exists) the field will
  # be absent — guard so a missing key gives a useful eval-time message
  # instead of a cryptic builtins.fromJSON failure downstream.
  havePrivateKey = (secrets.harmonia.privateKey or null) != null;
in
{
  options.server.harmonia = {
    enable = lib.mkEnableOption "harmonia Nix binary cache server";

    port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
      description = "TCP port harmonia binds to.";
    };

    interfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "tailscale0" ];
      example = [
        "tailscale0"
        "enp34s0"
      ];
      description = ''
        Network interfaces on which to expose the cache port. Restricts
        firewall exposure so the cache is not accessible from arbitrary
        upstream networks.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = havePrivateKey;
            message = ''
              server.harmonia.enable = true but secrets.harmonia.privateKey is unset.
              Generate a key:
                nix-store --generate-binary-cache-key qbert-cache-1 /tmp/cache.sec /tmp/cache.pub
              Store the private key in 1Password under
                nixerator / harmonia-signing-key / credential
              then re-run `render-secrets --push <hosts>` before rebuilding.
            '';
          }
        ];
      }

      (lib.mkIf havePrivateKey {
        # Materialise the signing key on disk so the harmonia systemd unit can
        # load it via LoadCredential. The plaintext copy in /nix/store is the
        # documented threat-model trade-off for inline secrets (see project
        # threat_model memory).
        environment.etc."harmonia/signing-key" = {
          # Relabel the signing key NAME from the malformed "qbert-cache:1"
          # (colon in the name breaks Nix 2.34's "<name>:<base64>" parser) to
          # the colon-free "qbert-cache-1" at build time. Same key BYTES, so
          # the public key in modules/system/qbert-cache stays valid. The
          # 1Password source still stores the old name; once that credential is
          # corrected this transform becomes a harmless no-op.
          text = lib.replaceStrings [ "qbert-cache:1:" ] [ "qbert-cache-1:" ] secrets.harmonia.privateKey;
          mode = "0400";
        };

        services.harmonia = {
          enable = true;
          signKeyPaths = [ "/etc/harmonia/signing-key" ];
          settings = {
            bind = "[::]:${toString cfg.port}";
            workers = 4;
          };
        };

        networking.firewall.interfaces = lib.genAttrs cfg.interfaces (_: {
          allowedTCPPorts = [ cfg.port ];
        });
      })
    ]
  );
}
