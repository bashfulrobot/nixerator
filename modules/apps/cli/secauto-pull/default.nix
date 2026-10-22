{
  pkgs,
  config,
  lib,
  globals,
  ...
}:
let
  cfg = config.apps.cli.secauto-pull;

  # Fast-forward pull of the secauto repo (encrypted gopass store) over a
  # read-only deploy key. The decrypting GPG key is never in git; it is placed
  # on the host separately, see extras/docs/secrets.md.
  pull = pkgs.writeShellApplication {
    name = "secauto-pull";
    runtimeInputs = [
      pkgs.git
      pkgs.openssh
    ];
    text = ''
      store="${cfg.storePath}"
      key="${cfg.deployKey}"

      # Exit 2 is a configuration error. The unit does not retry it, since
      # retrying a missing clone or key changes nothing.
      if [[ ! -d "$store/.git" ]]; then
        echo "secauto-pull: $store is not a git clone. Run: gopass clone ${cfg.repo}" >&2
        exit 2
      fi
      if [[ ! -r "$key" ]]; then
        echo "secauto-pull: deploy key $key is missing or unreadable." >&2
        exit 2
      fi

      # IdentitiesOnly keeps ssh from offering other keys, so the read-only
      # deploy key is the only identity this unit can use. BatchMode forbids
      # any prompt. accept-new records github.com's host key on first contact.
      export GIT_SSH_COMMAND="ssh -i $key -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new"
      git -C "$store" pull --ff-only --quiet
    '';
  };
in
{
  options.apps.cli.secauto-pull = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Pull the secauto repo (encrypted gopass store of automation secrets) on
        a systemd user timer, so unattended jobs read current values with
        `gopass show` and no 1Password session. Enable on reader hosts only.
        The writer host (qbert) commits and pushes from its own clone.

        One-time setup per host: clone the store (`gopass clone <repo>`),
        import the secauto GPG key, and create a read-only deploy key:
          ssh-keygen -t ed25519 -N "" -f ~/.ssh/secauto_deploy
          gh repo deploy-key add ~/.ssh/secauto_deploy.pub -R bashfulrobot/secauto -t <host>
      '';
    };

    repo = lib.mkOption {
      type = lib.types.str;
      default = "git@github.com:bashfulrobot/secauto.git";
      description = "Remote of the encrypted store. Used only in the setup hint.";
    };

    storePath = lib.mkOption {
      type = lib.types.str;
      default = "${globals.user.homeDirectory}/.local/share/gopass/stores/root";
      description = "Local clone of the secauto repo (gopass's default root store).";
    };

    deployKey = lib.mkOption {
      type = lib.types.str;
      default = "${globals.user.homeDirectory}/.ssh/secauto_deploy";
      description = "Private half of the read-only deploy key, generated on the host.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "15min";
      description = "Time between pulls, counted from the previous run.";
    };

    renderAfterPull = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        After each pull, run `render-secrets --from gopass` so the host's
        rendered secrets file follows the store with no 1Password and no human.
        Needs apps.cli.render-secrets.enable on the same host. The rendered file
        leaves out the 1Password service-account token, which is deliberately not
        in gopass.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.renderAfterPull || config.apps.cli.render-secrets.enable;
        message = "apps.cli.secauto-pull.renderAfterPull needs apps.cli.render-secrets.enable = true on this host.";
      }
    ];

    environment.systemPackages = [ pull ];

    # A user timer, so the pull runs as the user whose gopass store it updates.
    # The primary user lingers (modules/system/linger), so the user manager is
    # up from boot and this fires with nobody logged in. Nothing here needs a
    # graphical session.
    home-manager.users.${globals.user.name} = {
      systemd.user.timers.secauto-pull = {
        Unit.Description = "secauto-pull timer";
        Timer = {
          OnBootSec = "2min";
          OnUnitActiveSec = cfg.interval;
          RandomizedDelaySec = "30s";
        };
        Install.WantedBy = [ "timers.target" ];
      };

      systemd.user.services.secauto-pull = {
        # The user manager starts early and has no network-online.target to
        # order against, so a first pull right after boot can hit a dead link.
        # Retry 5 times, 1 minute apart, before giving up until the next timer.
        Unit = {
          Description = "Pull the secauto encrypted secret store";
          StartLimitBurst = 5;
          StartLimitIntervalSec = "15min";
        };
        Service = {
          Type = "oneshot";
          Restart = "on-failure";
          RestartPreventExitStatus = 2;
          RestartSec = "1min";
          ExecStart = "${pull}/bin/secauto-pull";
        }
        // lib.optionalAttrs cfg.renderAfterPull {
          # A render failure fails the unit and shows up in the journal. The pull
          # above has already succeeded, so the store itself stays current.
          ExecStartPost = "/run/current-system/sw/bin/render-secrets --from gopass";
        };
      };
    };
  };
}
