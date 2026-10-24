{
  pkgs,
  config,
  lib,
  globals,
  ...
}:
let
  cfg = config.apps.cli.secauto-pull;

  # GitHub's published SSH host keys (ed25519, ecdsa, rsa), each verified against
  # the fingerprints api.github.com/meta publishes. Public data, safe in the store.
  # Refresh with: gh api meta --jq '.ssh_keys[] | "github.com " + .'
  knownHosts = ./github-known-hosts;

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
      # lib.escapeShellArg: the option values are spliced into shell source, so a
      # path with a space, quote or $ must stay one inert word.
      store=${lib.escapeShellArg cfg.storePath}
      key=${lib.escapeShellArg cfg.deployKey}
      repo=${lib.escapeShellArg cfg.repo}
      known_hosts=${knownHosts}

      # Exit 2 is a configuration error. The unit does not retry it, since
      # retrying a missing clone or key changes nothing.
      if [[ ! -d "$store/.git" ]]; then
        echo "secauto-pull: $store is not a git clone. Run: gopass clone $repo" >&2
        exit 2
      fi
      if [[ ! -r "$key" ]]; then
        echo "secauto-pull: deploy key $key is missing or unreadable." >&2
        exit 2
      fi

      # The server is checked against GitHub's published host keys, pinned in the
      # Nix store. Trusting the first key that answers (accept-new) would let
      # anyone on the network path impersonate GitHub on the first run and serve a
      # store this host would then decrypt. The global known_hosts is ignored so
      # the pin cannot be widened. -F /dev/null and no connection sharing keep the
      # user's ssh config out of it: a ControlMaster there reuses an open
      # connection and skips host-key verification entirely, and a ProxyCommand or
      # IdentityAgent would change who is contacted and with which key.
      # IdentitiesOnly makes the read-only deploy key the only identity offered.
      # BatchMode forbids any prompt. printf %q quotes the key path because git
      # runs GIT_SSH_COMMAND through a shell.
      q_key="$(printf '%q' "$key")"
      export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -F /dev/null -i $q_key -o IdentitiesOnly=yes -o BatchMode=yes -o ControlMaster=no -o ControlPath=none -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$known_hosts -o GlobalKnownHostsFile=/dev/null"
      # The user's gitconfig stays out of it as well: an url.<x>.insteadOf there
      # would send the fetch to another host without touching the ssh pin above.
      export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
      # The store must still point at the configured repo. insteadOf is ignored
      # now, so a changed origin URL means someone edited the clone's own config.
      origin="$(git -C "$store" remote get-url origin)"
      if [[ "$origin" != "$repo" ]]; then
        echo "secauto-pull: origin is $origin, expected $repo. Refusing to pull." >&2
        exit 2
      fi
      ${
        if cfg.allowedSignersFile == null then
          ''git -C "$store" pull --ff-only --quiet''
        else
          ''
            # Only commits signed by a key listed in the allowed-signers file are
            # merged. An unsigned or foreign-signed commit fails the pull, so a
            # planted entry never reaches the working copy.
            git -C "$store" -c gpg.format=ssh \
              -c gpg.ssh.allowedSignersFile=${lib.escapeShellArg cfg.allowedSignersFile} \
              pull --ff-only --verify-signatures --quiet''
      }
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
      description = "Remote of the encrypted store. secauto-pull refuses to pull when the clone's origin differs.";
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

    allowedSignersFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to an SSH allowed-signers file. When set, secauto-pull merges only
        commits signed by one of its keys (`git pull --verify-signatures`), so a
        write to the secauto repo by anyone but the signer is refused. Null keeps
        the unsigned behaviour. Turning it on needs the writer (qbert) to sign its
        commits first, or the next pull fails. See "What the pull trusts" in
        extras/docs/secrets.md.
      '';
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
