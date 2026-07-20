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
          nixpkgs = {
            config = {
              # Allow unfree packages (e.g., Google Chrome)
              allowUnfree = true;
            };

            # Apply custom package overlays
            overlays = [
              # llm-agents packages (exposes pkgs.llm-agents.<name>).
              # Upstream dropped its `overlays` flake output (as of rev
              # eacaf2df, 2026-07-12) in favor of exposing packages.<system>
              # directly, so we wire it back into an overlay ourselves rather
              # than touching every pkgs.llm-agents.<name> call site.
              (final: _prev: {
                # `stdenv.hostPlatform.system`, not `final.system`: nixpkgs turned
                # the top-level `pkgs.system` alias into an eval-time warning
                # (aliases.nix, 2025-10-28).
                llm-agents = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system};
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

              # Work around a broken pytest check in python3.14Packages.click-threading.
              #
              # click-threading's own test suite collects docs/conf.py as a test
              # module (a stray sphinx config picked up by pytest's default
              # collection), which imports pkg_resources. This nixpkgs revision's
              # python3.14 doesn't propagate setuptools' pkg_resources by default,
              # so collection errors out with ModuleNotFoundError and the whole
              # build fails -- even though click-threading itself works fine.
              # vdirsyncer depends on it (pulled in transitively by hyprflake's
              # desktop.dank.calendar module on the workstations), so this broke
              # every donkeykong/qbert rebuild.
              #
              # Remove once nixpkgs fixes click-threading's pytest collection (or
              # adds setuptools as a checkInput upstream).
              #
              # Uses `pythonPackagesExtensions` (folded into every interpreter's
              # package set, e.g. python314Packages) rather than overriding the
              # `python3` alias directly -- vdirsyncer/khal may resolve
              # click-threading through the version-numbered set, which a
              # `python3.override` wouldn't reach.
              (_final: prev: {
                pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
                  (_pyFinal: pyPrev: {
                    click-threading = pyPrev.click-threading.overridePythonAttrs (_old: {
                      doCheck = false;
                    });
                  })
                ];
              })
            ];
          };

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
