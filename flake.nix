{
  description = "NixOS configuration with flakes and home-manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # TODO(workaround): pin voxtype to pre-0.7.0 (adf0ea6, 2026-04-20).
    # voxtype 0.7.0 (rev 184006c) added a Cargo dep that pulls in `glib-sys`
    # and `gdk-pixbuf-sys` without feature-gating, so the `vulkan` variant
    # fails to build on NixOS — its derivation only declares vulkan + alsa
    # + openssl deps. Re-evaluate this pin when peteonrails/voxtype either
    # feature-gates the GTK crate or adds the missing native deps to the
    # vulkan derivation. Drop both this input and the `follows` line below
    # once that lands; let hyprflake's own pin take over again.
    voxtype = {
      url = "github:peteonrails/voxtype/adf0ea62c2310b90c55febdc6515cca9f264e25a";
      # Force voxtype to follow nixerator's nixpkgs. Without this, voxtype's
      # own pinned nixpkgs (from 2026-01) builds against a stale PipeWire and
      # the resulting binary hardcodes ALSA-plugin paths to a /nix/store
      # entry that doesn't exist on the live system — voxtype starts but
      # silently fails to open audio with `snd_pcm_open` ENXIO. Following
      # nixerator's nixpkgs aligns voxtype's runtime ALSA/PipeWire deps with
      # everything else on the system.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprflake = {
      url = "github:bashfulrobot/hyprflake";
      # Follow all inputs to ensure version consistency and avoid conflicts
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
        stylix.follows = "stylix";
        waybar-auto-hide.follows = "waybar-auto-hide";
        # See TODO above the `voxtype` input.
        voxtype.follows = "voxtype";
      };
    };

    waybar-auto-hide = {
      url = "github:bashfulrobot/nixpkg-waybar-auto-hide";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak = {
      url = "github:gmodena/nix-flatpak";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    apple-fonts = {
      # Pinned: upstream rev 6f4eed8 (2026-04-23) ships an empty sf-mono-nerd
      # derivation (no font files), which strips all Nerd Font glyphs from
      # waybar/etc. ecb8430 (2026-04-10) is the last known-working commit.
      # Unpin once upstream fixes the sf-mono-nerd build.
      url = "github:Lyndeno/apple-fonts.nix/ecb843051893bdf34fd4f9c0ec664e356e2251a6";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    browser-previews = {
      url = "github:nix-community/browser-previews";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # zed-editor = {
    #   url = "github:zed-industries/zed";
    # };

    upsight = {
      url = "github:bashfulrobot/upsight/v0.21.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wayscriber = {
      url = "github:devmobasa/wayscriber";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, ... }@inputs:
    let
      # Import configuration data
      globals = import ./settings/globals.nix;
      versions = import ./settings/versions.nix;

      # Load secrets from encrypted JSON file
      secretsFile = "${self}/secrets/secrets.json";
      secrets = builtins.fromJSON (builtins.readFile secretsFile);

      # Import library functions
      lib = import ./lib { inherit inputs secrets; };
    in
    {
      # NixOS configurations
      nixosConfigurations = {
        donkeykong = lib.mkHost {
          inherit globals versions;
          hostname = "donkeykong";
          system = "x86_64-linux";
          useDeterminate = true;
          extraModules = [
            # Determinate Nix distribution
            inputs.determinate.nixosModules.default
            # Disko declarative disk partitioning
            inputs.disko.nixosModules.disko
            # Hyprland desktop environment
            inputs.hyprflake.nixosModules.default
            # Hardware-specific configuration for Lenovo ThinkPad T14 Intel Gen 6
            inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14-intel-gen6
          ];
          homeManagerModules = [
            # Spicetify for customized Spotify
            inputs.spicetify-nix.homeManagerModules.default
          ];
        };

        qbert = lib.mkHost {
          inherit globals versions;
          hostname = "qbert";
          system = "x86_64-linux";
          useDeterminate = true;
          extraModules = [
            # Determinate Nix distribution
            inputs.determinate.nixosModules.default
            # Disko declarative disk partitioning
            inputs.disko.nixosModules.disko
            # Hyprland desktop environment
            inputs.hyprflake.nixosModules.default
          ];
          homeManagerModules = [
            # Spicetify for customized Spotify
            inputs.spicetify-nix.homeManagerModules.default
          ];
        };

        srv = lib.mkHost {
          inherit globals versions;
          hostname = "srv";
          system = "x86_64-linux";
          extraModules = [ ];
          homeManagerModules = [ ];
        };
      };

      # Formatter for `nix fmt`
      formatter.x86_64-linux = inputs.nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;

      # Expose lib, globals, and versions for use in other flakes
      inherit lib globals versions;
    };
}
