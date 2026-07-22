{
  globals,
  lib,
  pkgs,
  config,
  secrets,
  secretsLib,
  ...
}:

let
  cfg = config.apps.cli.syncthing;

  # Versioning configurations
  simpleVersioning = {
    type = "simple";
    params = {
      keep = "10";
    };
  };

  staggeredVersioning = {
    type = "staggered";
    params = {
      cleanInterval = "3600"; # 1 hour in seconds
      maxAge = "7776000"; # 90 days in seconds
    };
  };

in
{
  options = {
    apps.cli.syncthing = {
      enable = lib.mkEnableOption "Syncthing file synchronization";

      host = {
        donkeykong = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Syncthing configuration for donkeykong host.";
        };

        qbert = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Syncthing configuration for qbert host.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      syncthing
    ];

    services.syncthing = lib.mkMerge [
      # Base configuration shared across all hosts
      {
        enable = true;
        systemService = true;
        user = globals.user.name;
        group = "users";
        dataDir = globals.user.homeDirectory;
        # GUI bound on all interfaces so it is reachable over the tailnet, as
        # before. On a *fresh* config there is a short window at first start
        # where syncthing is up but syncthing-gui-auth has not applied
        # credentials yet, so the GUI is briefly unauthenticated. This is not a
        # regression (the previous settings.gui path also applied credentials
        # only after the service came up), and openDefaultPorts opens the sync
        # ports (22000/21027), not the GUI port (8384). Narrowing this further
        # means binding to 127.0.0.1, which would drop remote GUI access, so it
        # is left as a deliberate host-owned choice rather than changed here.
        guiAddress = "0.0.0.0:8384";
        openDefaultPorts = true;
        overrideDevices = true;
        overrideFolders = true;

        # GUI credentials are deliberately NOT set here. settings.gui.user /
        # password bake the plaintext into the module's store PATCH script.
        # They are applied at runtime by the syncthing-gui-auth service below,
        # read from the off-store secrets file (issue #265).
      }

      # donkeykong host configuration
      (lib.mkIf cfg.host.donkeykong {
        configDir = "${globals.user.homeDirectory}/.config/syncthing/donkeykong";

        settings = {
          devices = {
            "qbert" = {
              addresses = [ "tcp://${globals.hosts.qbert.tailscale_ip}:22000" ];
              id = globals.hosts.qbert.syncthing_id;
            };
          };

          folders = {
            "Desktop" = {
              path = "${globals.user.homeDirectory}/Desktop";
              devices = [ "qbert" ];
              versioning = simpleVersioning;
            };

            "Documents" = {
              path = "${globals.user.homeDirectory}/Documents";
              devices = [ "qbert" ];
              versioning = staggeredVersioning;
            };

            "Downloads" = {
              path = "${globals.user.homeDirectory}/Downloads";
              devices = [ "qbert" ];
              versioning = simpleVersioning;
            };

            "Music" = {
              path = "${globals.user.homeDirectory}/Music";
              devices = [ "qbert" ];
              versioning = simpleVersioning;
            };

            "Pictures" = {
              path = "${globals.user.homeDirectory}/Pictures";
              devices = [ "qbert" ];
              versioning = simpleVersioning;
            };

            "Videos" = {
              path = "${globals.user.homeDirectory}/Videos";
              devices = [ "qbert" ];
              versioning = simpleVersioning;
            };

            "dev" = {
              path = globals.paths.devRoot;
              devices = [ "qbert" ];
              versioning = staggeredVersioning;
            };

            ".gnupg" = {
              path = "${globals.user.homeDirectory}/.gnupg";
              devices = [ "qbert" ];
              ignorePerms = false;
              versioning = staggeredVersioning;
            };

            ".ssh" = {
              path = "${globals.user.homeDirectory}/.ssh";
              devices = [ "qbert" ];
              ignorePerms = false;
              versioning = staggeredVersioning;
            };

            ".kube" = {
              path = "${globals.user.homeDirectory}/.kube";
              devices = [ "qbert" ];
              versioning = staggeredVersioning;
            };

            ".talos" = {
              path = "${globals.user.homeDirectory}/.talos";
              devices = [ "qbert" ];
              versioning = staggeredVersioning;
            };

            "upsight-data" = {
              path = "${globals.user.homeDirectory}/.local/share/upsight";
              devices = [ "qbert" ];
              versioning = staggeredVersioning;
            };

            "upsight-config" = {
              path = "${globals.user.homeDirectory}/.config/upsight";
              devices = [ "qbert" ];
              versioning = simpleVersioning;
            };

          };
        };
      })

      # qbert host configuration
      (lib.mkIf cfg.host.qbert {
        configDir = "${globals.user.homeDirectory}/.config/syncthing/qbert";

        settings = {
          devices = {
            "donkey-kong" = {
              addresses = [ "tcp://${globals.hosts.donkeykong.tailscale_ip}:22000" ];
              id = globals.hosts.donkeykong.syncthing_id;
            };
          };

          folders = {
            "Desktop" = {
              path = "${globals.user.homeDirectory}/Desktop";
              devices = [ "donkey-kong" ];
              versioning = simpleVersioning;
            };

            "Documents" = {
              path = "${globals.user.homeDirectory}/Documents";
              devices = [ "donkey-kong" ];
              versioning = staggeredVersioning;
            };

            "Downloads" = {
              path = "${globals.user.homeDirectory}/Downloads";
              devices = [ "donkey-kong" ];
              versioning = simpleVersioning;
            };

            "Music" = {
              path = "${globals.user.homeDirectory}/Music";
              devices = [ "donkey-kong" ];
              versioning = simpleVersioning;
            };

            "Pictures" = {
              path = "${globals.user.homeDirectory}/Pictures";
              devices = [ "donkey-kong" ];
              versioning = simpleVersioning;
            };

            "Videos" = {
              path = "${globals.user.homeDirectory}/Videos";
              devices = [ "donkey-kong" ];
              versioning = simpleVersioning;
            };

            "dev" = {
              path = globals.paths.devRoot;
              devices = [ "donkey-kong" ];
              versioning = staggeredVersioning;
            };

            ".gnupg" = {
              path = "${globals.user.homeDirectory}/.gnupg";
              devices = [ "donkey-kong" ];
              ignorePerms = false;
              versioning = staggeredVersioning;
            };

            ".ssh" = {
              path = "${globals.user.homeDirectory}/.ssh";
              devices = [ "donkey-kong" ];
              ignorePerms = false;
              versioning = staggeredVersioning;
            };

            ".kube" = {
              path = "${globals.user.homeDirectory}/.kube";
              devices = [ "donkey-kong" ];
              versioning = staggeredVersioning;
            };

            ".talos" = {
              path = "${globals.user.homeDirectory}/.talos";
              devices = [ "donkey-kong" ];
              versioning = staggeredVersioning;
            };

            "upsight-data" = {
              path = "${globals.user.homeDirectory}/.local/share/upsight";
              devices = [ "donkey-kong" ];
              versioning = staggeredVersioning;
            };

            "upsight-config" = {
              path = "${globals.user.homeDirectory}/.config/upsight";
              devices = [ "donkey-kong" ];
              versioning = simpleVersioning;
            };

          };
        };
      })
    ];

    # GUI credentials applied at runtime from the off-store secrets file
    # (issue #265). Keeping them out of services.syncthing.settings.gui keeps the
    # plaintext out of the module's store PATCH script and out of /nix/store.
    # After syncthing is up, this reads the user + password from secrets.json,
    # bcrypt-hashes the password (syncthing stores the hash, exactly as the
    # module's own guiPasswordFile path does), and PATCHes /rest/config/gui with
    # the API key from syncthing's config.xml. Every value is read from a file,
    # never passed on argv (so it never shows in `ps`). Idempotent: it re-applies
    # on each start and the module never touches gui auth (settings.gui unset).
    systemd.services.syncthing-gui-auth = lib.mkIf (secrets ? syncthing) {
      description = "Apply syncthing GUI credentials from off-store secrets (#265)";
      after = [ "syncthing.service" ];
      wants = [ "syncthing.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.jq
        pkgs.mkpasswd
        pkgs.libxml2
        pkgs.curl
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        User = globals.user.name;
        Group = "users";
        RuntimeDirectory = "syncthing-gui-auth";
        RuntimeDirectoryMode = "0700";
      };
      script = ''
        set -euo pipefail
        secrets=${secretsLib.file globals}
        [ -f "$secrets" ] || { echo "syncthing-gui-auth: no secrets file, skipping"; exit 0; }
        jq -e '.syncthing.gui.user // empty' "$secrets" >/dev/null 2>&1 \
          || { echo "syncthing-gui-auth: no gui.user, skipping"; exit 0; }
        jq -e '.syncthing.gui.password // empty' "$secrets" >/dev/null 2>&1 \
          || { echo "syncthing-gui-auth: no gui.password, skipping"; exit 0; }

        cfg="${config.services.syncthing.configDir}/config.xml"
        # Wait for syncthing to write its config + API key on first start.
        apikey=""
        for _ in $(seq 1 60); do
          if [ -f "$cfg" ]; then
            apikey=$(xmllint --xpath 'string(configuration/gui/apikey)' "$cfg" 2>/dev/null || true)
            [ -n "$apikey" ] && break
          fi
          sleep 1
        done
        [ -n "$apikey" ] || { echo "syncthing-gui-auth: no API key after wait, giving up"; exit 1; }

        addr=$(xmllint --xpath 'string(configuration/gui/address)' "$cfg" 2>/dev/null || true)
        case "$addr" in
          "" | 0.0.0.0:* | "[::]:"*)
            port="''${addr##*:}"
            addr="127.0.0.1:''${port:-8384}"
            ;;
        esac

        # bcrypt-hash the password; syncthing stores the hash. Read from a file,
        # not argv.
        jq -j '.syncthing.gui.password' "$secrets" > "$RUNTIME_DIRECTORY/pw"
        pwhash=$(mkpasswd -m bcrypt --stdin < "$RUNTIME_DIRECTORY/pw" | tr -d '\n')
        rm -f "$RUNTIME_DIRECTORY/pw"
        # A failed hash would PATCH an empty password and lock the GUI; bail
        # instead (pipefail alone is not enough, since `tr` masks mkpasswd).
        [ -n "$pwhash" ] || { echo "syncthing-gui-auth: empty password hash, refusing to PATCH"; exit 1; }
        user=$(jq -r '.syncthing.gui.user' "$secrets")

        # Body in a file so the hash never hits argv.
        jq -n --arg u "$user" --arg p "$pwhash" '{user:$u, password:$p}' \
          > "$RUNTIME_DIRECTORY/gui.json"
        curl -sS -X PATCH \
          -H "X-API-Key: $apikey" \
          -H "Content-Type: application/json" \
          --data @"$RUNTIME_DIRECTORY/gui.json" \
          "http://$addr/rest/config/gui"
        rm -f "$RUNTIME_DIRECTORY/gui.json"
      '';
    };

    # Home Manager configuration for desktop file and stignore files
    home-manager.users.${globals.user.name} = {
      home.file = {
        # Override package desktop file since we use custom configDir
        "syncthing-ui.desktop" = {
          text = ''
            [Desktop Entry]
            Name=Syncthing Web UI
            Exec=xdg-open http://localhost:8384
            Icon=syncthing
            Type=Application
            Categories=Network;FileTransfer;
          '';
          target = ".local/share/applications/syncthing-ui.desktop";
        };

        "dev/.stignore" = {
          text = ''
            .git
          '';
          target = "dev/.stignore";
        };

        "upsight-data/.stignore" = {
          text = ''
            upsight.db-wal
            upsight.db-shm
            upsight.db.lock
            *.db.backup-v*
            *.pre-restore
            config.toml.tmp
            config.toml.bak
            upsight.session.tmp
            *.sync-conflict-*
          '';
          target = ".local/share/upsight/.stignore";
        };

        "upsight-config/.stignore" = {
          text = ''
            upsight.db-wal
            upsight.db-shm
            upsight.db.lock
            *.db.backup-v*
            *.pre-restore
            config.toml.tmp
            config.toml.bak
            upsight.session.tmp
            *.sync-conflict-*
          '';
          target = ".config/upsight/.stignore";
        };
      };
    };
  };
}
