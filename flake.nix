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

    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprflake = {
      url = "github:bashfulrobot/hyprflake";
      # Follow all inputs to ensure version consistency and avoid conflicts
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
        stylix.follows = "stylix";
        hyprland.follows = "hyprland";
      };
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak = {
      url = "github:gmodena/nix-flatpak";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
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
        nixerator = lib.mkHost {
          inherit globals versions;
          hostname = "nixerator";
          system = "x86_64-linux";
          # username and stateVersion are automatically pulled from globals
          extraModules = [
            # Hyprland desktop environment
            inputs.hyprflake.nixosModules.default
          ];
        };

        donkeykong = lib.mkHost {
          inherit globals versions;
          hostname = "donkeykong";
          system = "x86_64-linux";
          extraModules = [
            # Disko declarative disk partitioning
            inputs.disko.nixosModules.disko
            # Hyprland desktop environment
            inputs.hyprflake.nixosModules.default
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
        };
      };

      # Expose lib, globals, and versions for use in other flakes
      inherit lib globals versions;
    };
}
