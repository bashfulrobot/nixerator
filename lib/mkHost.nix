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
      useDeterminate ? false,
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

          # Discord (and discord-ptb) ship proprietary blobs linked
          # against libssl.so.1.1; nixpkgs requires opt-in.
          nixpkgs.config.permittedInsecurePackages = [
            "openssl-1.1.1w"
          ];

          # Apply custom package overlays
          nixpkgs.overlays = [
            # llm-agents packages (exposes pkgs.llm-agents.<name>)
            inputs.llm-agents.overlays.default

            # TODO(2026-04-28): Remove once nixpkgs ships a cli-helpers/Pygments
            # fix. cli-helpers 2.10.0 has 3 ANSI-escape assertions in
            # tests/tabular_output/test_preprocessors.py that broke when
            # Pygments changed how it emits 256-color SGR resets. Only
            # consumer in our closure is `litecli` (modules/suites/dev).
            # Verify removal: drop this overlay and run `just qr`; if
            # cli-helpers builds clean, delete.
            (
              _final: prev:
              let
                cliHelpersPatch = _pySelf: pySuper: {
                  cli-helpers = pySuper.cli-helpers.overridePythonAttrs (old: {
                    disabledTests = (old.disabledTests or [ ]) ++ [
                      "test_style_output"
                      "test_style_output_with_newlines"
                      "test_style_output_custom_tokens"
                    ];
                  });
                };
              in
              {
                python3 = prev.python3.override (old: {
                  packageOverrides = prev.lib.composeExtensions (old.packageOverrides or (_: _: { })) cliHelpersPatch;
                });
                python313 = prev.python313.override (old: {
                  packageOverrides = prev.lib.composeExtensions (old.packageOverrides or (_: _: { })) cliHelpersPatch;
                });
              }
            )
          ];

          # Nix settings - Determinate Nix manages these automatically when enabled
          nix =
            if useDeterminate then
              {
                # Determinate Nix handles flakes, GC, and optimization automatically
              }
            else
              {
                # Standard Nix configuration for non-Determinate hosts
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
              # Disable Home Manager manual/manpages generation to avoid
              # Determinate Nix warning about options.json referencing the source store path
              manual.manpages.enable = false;
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
