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

    # voxtype follows nixerator's nixpkgs to align its runtime ALSA/PipeWire
    # deps with the rest of the system. Without this, voxtype's own pinned
    # nixpkgs builds against a stale PipeWire and the binary hardcodes an
    # ALSA-plugin path to a /nix/store entry that doesn't exist on the live
    # system, so voxtype starts but silently fails to open audio with
    # `snd_pcm_open` ENXIO.
    #
    # The old pre-0.7.0 version pin (for a glib-sys/gdk-pixbuf build break)
    # was dropped: voxtype 0.7.1 moved the GTK crates into macOS-only deps,
    # so the vulkan variant builds on Linux again.
    voxtype = {
      url = "github:peteonrails/voxtype";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprflake = {
      url = "github:bashfulrobot/hyprflake";
      # Follow all inputs to ensure version consistency and avoid conflicts
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
        stylix.follows = "stylix";
        # Share the one nixpkgs-aligned voxtype defined above.
        voxtype.follows = "voxtype";
      };
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
      # Pinned to ce044f6 (2026-06-27), matching the rev hyprflake already
      # locks. The old ecb8430 (2026-04-10) pin carried its own stale
      # Apple-font hashes: Apple re-published SF-Pro.dmg / SF-Compact.dmg in
      # place, so ecb8430's baked-in narHashes stopped matching and every
      # rebuild failed. ce044f6 carries current hashes and rebuilds
      # sf-mono-nerd via nerd-font-patcher (fontPackage.nix), so the
      # empty-derivation glyph loss that originally forced the ecb8430 pin
      # (upstream 6f4eed8) is fixed. Verified sf-mono-nerd ships glyphs.
      #
      # This still resolves to a separate lock node from hyprflake's copy
      # (they follow different nixpkgs), but both now sit at ce044f6.
      url = "github:Lyndeno/apple-fonts.nix/ce044f6829c6b3ccde9624116577ba2c173ca49d";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    browser-previews = {
      url = "github:nix-community/browser-previews";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # zed-editor = {
    #   url = "github:zed-industries/zed";
    # };

    # Go + Wails v3 + Svelte 5 rewrite of the original Kotlin app. Pins its own
    # nixpkgs (nixos-26.05), where its CGO/WebKitGTK build is verified, so it is
    # intentionally NOT following nixpkgs here.
    upsight = {
      url = "github:bashfulrobot/upsight";
    };

    # Ballpoint, a local Todoist triage tool (walk / probe / dispatch). Keeps
    # its own nixpkgs pin (no follows), like upsight: a self-contained Go
    # binary whose Go vendorHash is verified against its own nixpkgs.
    ballpoint = {
      url = "github:bashfulrobot/ballpoint";
    };

    # Pinned upstream for the `humanizer` skill (claude-code + gemini-cli).
    # Tracks blader/humanizer; bump via `nix flake update humanizer-skill`
    # or `just upgrade`. `flake = false` because the repo ships a SKILL.md,
    # not a flake.
    humanizer-skill = {
      url = "github:blader/humanizer";
      flake = false;
    };

    # Recursive Nix module importer. Replaces the hand-rolled
    # `lib/autoimport.nix`; consumed by `modules/default.nix` and
    # `modules/apps/webapps/default.nix` via `inputs.import-tree`.
    #
    # Pinned to a release tag (not `main`) so `just upgrade` can't silently
    # follow upstream HEAD. The denful GitHub org was created 2026-04-20;
    # an org takeover or hostile push to main would otherwise land at the
    # next `nix flake update`. Bump this tag explicitly when re-auditing
    # upstream.
    import-tree.url = "github:denful/import-tree/v0.2.0";
  };

  outputs =
    inputs:
    let
      # Import configuration data
      globals = import ./settings/globals.nix;
      versions = import ./settings/versions.nix;

      # Nix-eval secrets, rendered from 1Password via `just render-secrets`
      # to a path outside the repo. String path (not Nix path literal) so the
      # file is read at eval time without being copied into the Nix store as
      # a flake input. See extras/docs/secrets.md.
      secretsFile = "${globals.user.homeDirectory}/.config/nixos-secrets/secrets.json";
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
          extraModules = [
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
            # Ballpoint Todoist triage tool (programs.ballpoint)
            inputs.ballpoint.homeManagerModules.default
          ];
        };

        qbert = lib.mkHost {
          inherit globals versions;
          hostname = "qbert";
          system = "x86_64-linux";
          extraModules = [
            # Disko declarative disk partitioning
            inputs.disko.nixosModules.disko
            # Hyprland desktop environment
            inputs.hyprflake.nixosModules.default
          ];
          homeManagerModules = [
            # Spicetify for customized Spotify
            inputs.spicetify-nix.homeManagerModules.default
            # Ballpoint Todoist triage tool (programs.ballpoint)
            inputs.ballpoint.homeManagerModules.default
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
