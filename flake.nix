{
  description = "NixOS configuration with flakes and home-manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprflake = {
      url = "github:bashfulrobot/hyprflake";
      # Only share nixpkgs to avoid version conflicts
      # Let hyprflake manage its own home-manager, hyprland, and stylix
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      # Import configuration data
      globals = import ./settings/globals.nix;

      # Import library functions
      lib = import ./lib { inherit inputs; };
    in
    {
      # NixOS configurations
      nixosConfigurations = {
        nixerator = lib.mkHost {
          inherit globals;
          hostname = "nixerator";
          system = "x86_64-linux";
          # username and stateVersion are automatically pulled from globals
          extraModules = [
            # Hyprland desktop environment
            inputs.hyprflake.nixosModules.default
          ];
        };
      };

      # Expose lib and globals for use in other flakes
      inherit lib globals;
    };
}
