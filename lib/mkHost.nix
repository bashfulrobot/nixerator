{ inputs, secrets }:

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
      inherit inputs hostname username globals secrets;
    };

    modules = [
      # Host-specific configuration
      ../hosts/${hostname}/configuration.nix

      # Home Manager integration
      inputs.home-manager.nixosModules.home-manager
      {
        # Allow unfree packages (e.g., Google Chrome)
        nixpkgs.config.allowUnfree = true;

        # Enable Nix flakes for all hosts
        nix.settings.experimental-features = [ "nix-command" "flakes" ];

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = {
            inherit inputs hostname username globals secrets;
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
