{ inputs }:

{
  # Function to create a host configuration with home-manager integration
  mkHost = {
    globals,
    hostname,
    system,
    username ? globals.user.name,
    stateVersion ? globals.defaults.stateVersion,
    extraModules ? [],
    homeManagerModules ? [],
  }: inputs.nixpkgs.lib.nixosSystem {
    inherit system;

    specialArgs = {
      inherit inputs hostname username globals;
    };

    modules = [
      # Host-specific configuration
      ../hosts/${hostname}/configuration.nix

      # Home Manager integration
      inputs.home-manager.nixosModules.home-manager
      {
        # Allow unfree packages (e.g., Google Chrome)
        nixpkgs.config.allowUnfree = true;

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = {
            inherit inputs hostname username globals;
          };
          users.${username} = import ../hosts/${hostname}/home.nix;
          backupFileExtension = "backup";
        };

        # System state version
        system.stateVersion = stateVersion;
      }
    ] ++ extraModules;
  };
}
