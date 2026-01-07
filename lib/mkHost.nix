{ inputs, secrets }:

{
  # Function to create a host configuration with home-manager integration
  mkHost = {
    globals,
    versions,
    hostname,
    system,
    username ? globals.user.name,
    stateVersion ? globals.defaults.stateVersion,
    extraModules ? [],
    homeManagerModules ? [],
  }: inputs.nixpkgs.lib.nixosSystem {
    inherit system;

    specialArgs = {
      inherit inputs hostname username globals versions secrets;
    };

    modules = [
      # Host-specific configuration
      ../hosts/${hostname}/configuration.nix

      # Home Manager integration
      inputs.home-manager.nixosModules.home-manager
      {
        # Allow unfree packages (e.g., Google Chrome)
        nixpkgs.config.allowUnfree = true;

        nix = {
          # Enable Nix flakes for all hosts
          settings.experimental-features = [ "nix-command" "flakes" ];

          # Automatic garbage collection
          gc = {
            automatic = true;
            dates = "weekly";
            options = "--delete-older-than 14d";
          };

          # Optimize store automatically
          optimise = {
            automatic = true;
            dates = [ "weekly" ];
          };
        };

        # Keep system generations manageable
        boot.loader.systemd-boot.configurationLimit = inputs.nixpkgs.lib.mkDefault 10;

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = {
            inherit inputs hostname username globals versions secrets;
          };
          users.${username} = {
            imports = [ ../hosts/${hostname}/home.nix ] ++ homeManagerModules;
          };
          backupFileExtension = "backup";
        };

        # System state version
        system.stateVersion = stateVersion;
      }
    ] ++ extraModules;
  };
}
