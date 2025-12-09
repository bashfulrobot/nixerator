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

    hyprflake = {
      url = "github:bashfulrobot/hyprflake";
      # Follow all inputs to ensure version consistency and avoid conflicts
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
      inputs.stylix.follows = "stylix";
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
