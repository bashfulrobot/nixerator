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

    hyprflake = {
      url = "github:bashfulrobot/hyprflake";
      # Follow all inputs to ensure version consistency and avoid conflicts
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
        stylix.follows = "stylix";
        waybar-auto-hide.follows = "waybar-auto-hide";
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
      url = "github:Lyndeno/apple-fonts.nix";
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
      url = "github:bashfulrobot/upsight/v0.9.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    paseo = {
      url = "github:getpaseo/paseo";
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
