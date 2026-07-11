# Okular PDF viewer with signature/initials stamps.
#
# Signature and initials PNGs are NOT managed by Nix anymore — they live in
# the nixerator 1Password vault as Document items (`okular-signature`,
# `okular-initials`) and are fetched on demand by:
#
#     just fetch-signatures
#
# That writes them to ~/.kde/share/icons/{signature,initials}.png where
# Okular's signature-stamp picker can find them.
#
# To add a signature stamp inside Okular:
#   Settings → Configure Okular → Annotations → Add → Type: Stamp →
#   pick ~/.kde/share/icons/signature.png (or initials.png) via the file
#   picker.

{
  lib,
  pkgs,
  config,
  globals,
  ...
}:

let
  cfg = config.apps.gui.okular;

in
{
  options = {
    apps.gui.okular.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Okular PDF viewer with signature stamps.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [

      # keep-sorted start case=no numeric=yes
      kdePackages.okular # pdf viewer - can add sig stamps
      # keep-sorted end
    ];

    # Set Okular as default PDF viewer. Signature PNGs are out-of-band
    # (see header comment + `just fetch-signatures`).
    home-manager.users.${globals.user.name} = {
      xdg.mimeApps = {
        associations = {
          added = {
            "application/pdf" = [ "okular.desktop" ];
          };
        };
        defaultApplications = {
          "application/pdf" = [ "okular.desktop" ];
        };
      };
    };
  };
}
