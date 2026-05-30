{ inputs, secrets }:

{
  # Function to create a host configuration with home-manager integration
  mkHost =
    {
      globals,
      versions,
      hostname,
      system,
      stateVersion ? globals.defaults.stateVersion,
      extraModules ? [ ],
      homeManagerModules ? [ ],
    }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;

      specialArgs = {
        inherit
          inputs
          hostname
          globals
          versions
          secrets
          ;
      };

      modules = [
        # Host-specific configuration
        ../hosts/${hostname}/configuration.nix

        # Home Manager integration
        inputs.home-manager.nixosModules.home-manager
        {
          # Allow unfree packages (e.g., Google Chrome)
          nixpkgs.config.allowUnfree = true;

          # Apply custom package overlays
          nixpkgs.overlays = [
            # llm-agents packages (exposes pkgs.llm-agents.<name>)
            inputs.llm-agents.overlays.default

            # Stub nautilus-open-any-terminal: hyprflake adds it to systemPackages
            # unconditionally, but Ghostty ships its own Nautilus extension so the
            # upstream one creates a duplicate "Open in Ghostty" menu entry. Replacing
            # the package with an empty derivation removes its share/nautilus-python
            # extension from the system profile while leaving hyprflake's reference intact.
            (_final: _prev: {
              nautilus-open-any-terminal =
                _prev.runCommand "nautilus-open-any-terminal-disabled" { }
                  "mkdir -p $out";
            })
          ];

          nix = {
            settings.experimental-features = [
              "nix-command"
              "flakes"
            ];

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
          boot.loader.systemd-boot.configurationLimit = inputs.nixpkgs.lib.mkDefault 5;

          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = {
              inherit
                inputs
                hostname
                globals
                versions
                secrets
                ;
            };
            users.${globals.user.name} = {
              imports = [ ../hosts/${hostname}/home.nix ] ++ homeManagerModules;
            };
            # Use a backup command that creates timestamped backups and keeps only the last 5
            backupCommand = "${
              inputs.nixpkgs.legacyPackages.${system}.bash
            }/bin/bash -c 'if [ -e \"$1\" ]; then mv -f \"$1\" \"$1.backup-$(date +%Y%m%d-%H%M%S)\"; ls -t \"$1\".backup-* 2>/dev/null | tail -n +6 | xargs -r rm -f; fi' --";
          };

          # System state version
          system.stateVersion = stateVersion;
        }
      ]
      ++ extraModules;
    };
}
