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

            # Work around a nixpkgs bug that breaks `google-cloud-sdk.withExtraComponents`.
            #
            # Background: `package.nix` builds gcloud against Python 3.14, and the
            # Google-shipped `bundled-python3-unix-linux-x86_64` component ships a
            # `_tkinter` extension linked against tcl/tk *9.0*
            # (`libtcl9.0.so` / `libtcl9tk9.0.so`). But `components.nix` `mkComponent`
            # hardcodes `buildInputs = [ libxcrypt-legacy tcl-8_6 tclPackages.tk ]`,
            # i.e. only tcl/tk *8.6*. This nixpkgs revision has no tk built against
            # tcl 9, so auto-patchelf cannot satisfy the tcl9 sonames and the
            # component build fails. (`libpython3.14.so.1.0` resolves at runtime via
            # `$ORIGIN` and is a benign secondary failure.) Plain `google-cloud-sdk`
            # substitutes from cache.nixos.org and is unaffected; only the local
            # component build triggered by `withExtraComponents` (used in
            # modules/suites/infrastructure for the gke-gcloud-auth-plugin) hits this.
            #
            # gcloud never invokes tkinter, so we tell auto-patchelf to ignore exactly
            # the three missing libraries rather than packaging tk9 ourselves. We
            # rebuild the entire component fixed-point so that every component — and
            # every transitive `passthru.dependencies` edge walked by
            # `findDepsRecursive` in withExtraComponents.nix — points at the patched
            # derivations, then re-expose the fixed `components` set and a
            # `withExtraComponents` that closes over it.
            #
            # Remove this overlay once nixpkgs gives gcloud components a tcl9-linked tk
            # (or otherwise fixes the tcl 8.6 vs Python 3.14 tkinter mismatch).
            (_final: prev: {
              google-cloud-sdk =
                let
                  gcloudDir = "${prev.path}/pkgs/by-name/go/google-cloud-sdk";

                  # auto-patchelf cannot satisfy these for the bundled python 3.14
                  # component; none are used by gcloud at runtime.
                  ignoreLibs = [
                    "libtcl9.0.so"
                    "libtcl9tk9.0.so"
                    "libpython3.14.so.1.0"
                  ];

                  # Re-derive the raw component set from this nixpkgs revision.
                  rawComponents = prev.callPackage "${gcloudDir}/components.nix" {
                    snapshotPath = "${gcloudDir}/components.json";
                  };

                  # Rebuild the fixed-point so each component ignores the missing libs
                  # AND its dependency edges reference the patched components (matched
                  # by pname, which equals the component id / attr name).
                  fixedComponents = prev.lib.fix (
                    self:
                    prev.lib.mapAttrs (
                      _name: drv:
                      drv.overrideAttrs (old: {
                        autoPatchelfIgnoreMissingDeps = (old.autoPatchelfIgnoreMissingDeps or [ ]) ++ ignoreLibs;
                        passthru = (old.passthru or { }) // {
                          dependencies = map (d: self.${d.pname}) (old.passthru.dependencies or [ ]);
                        };
                      })
                    ) rawComponents
                  );

                  fixedWithExtraComponents = prev.callPackage "${gcloudDir}/withExtraComponents.nix" {
                    components = fixedComponents;
                  };
                in
                prev.google-cloud-sdk.overrideAttrs (old: {
                  passthru = (old.passthru or { }) // {
                    components = fixedComponents;
                    withExtraComponents = fixedWithExtraComponents;
                  };
                });
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
