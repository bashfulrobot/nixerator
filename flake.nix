{
  description = "NixOS configuration with flakes and home-manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # voxtype follows nixerator's nixpkgs to align its runtime ALSA/PipeWire
    # deps with the rest of the system. Without this, voxtype's own pinned
    # nixpkgs builds against a stale PipeWire and the binary hardcodes an
    # ALSA-plugin path to a /nix/store entry that doesn't exist on the live
    # system, so voxtype starts but silently fails to open audio with
    # `snd_pcm_open` ENXIO.
    #
    # The old pre-0.7.0 version pin (for a glib-sys/gdk-pixbuf build break)
    # was dropped: voxtype 0.7.1 moved the GTK crates into macOS-only deps,
    # so the vulkan variant builds on Linux again.
    voxtype = {
      url = "github:peteonrails/voxtype";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprflake = {
      url = "github:bashfulrobot/hyprflake";
      # Follow all inputs to ensure version consistency and avoid conflicts
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
        stylix.follows = "stylix";
        # Share the one nixpkgs-aligned voxtype defined above.
        voxtype.follows = "voxtype";
      };
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Snowflake data-access CLI (github.com/bashfulrobot/snowstorm). Exposes
    # packages.<system>.default; consumed via apps.cli.snowstorm.
    snowstorm = {
      url = "github:bashfulrobot/snowstorm";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # No nixpkgs.follows: nix-flatpak's flake declares no nixpkgs input of its
    # own to follow (verified via `nix flake lock` — an override here errors
    # as "non-existent input 'nixpkgs'").
    nix-flatpak = {
      url = "github:gmodena/nix-flatpak";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    apple-fonts = {
      # Pinned to ce044f6 (2026-06-27), matching the rev hyprflake already
      # locks. The old ecb8430 (2026-04-10) pin carried its own stale
      # Apple-font hashes: Apple re-published SF-Pro.dmg / SF-Compact.dmg in
      # place, so ecb8430's baked-in narHashes stopped matching and every
      # rebuild failed. ce044f6 carries current hashes and rebuilds
      # sf-mono-nerd via nerd-font-patcher (fontPackage.nix), so the
      # empty-derivation glyph loss that originally forced the ecb8430 pin
      # (upstream 6f4eed8) is fixed. Verified sf-mono-nerd ships glyphs.
      #
      # This still resolves to a separate lock node from hyprflake's copy
      # (they follow different nixpkgs), but both now sit at ce044f6.
      url = "github:Lyndeno/apple-fonts.nix/ce044f6829c6b3ccde9624116577ba2c173ca49d";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    browser-previews = {
      url = "github:nix-community/browser-previews";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # zed-editor = {
    #   url = "github:zed-industries/zed";
    # };

    # Go + Wails v3 + Svelte 5 rewrite of the original Kotlin app. Pins its own
    # nixpkgs (nixos-26.05), where its CGO/WebKitGTK build is verified, so it is
    # intentionally NOT following nixpkgs here.
    #
    # Fetched over git+ssh, not github:, because the repo is private: the github:
    # scheme resolves HEAD through the GitHub API, which 404s without a valid PAT
    # and then silently falls back to the stale cached commit (so every bump
    # rebuilt an ancient version). SSH uses the existing key and always resolves
    # real HEAD. Hosts that rebuild upsight need SSH read access to the repo.
    # Nothing in CI bumps this lock: `just qu` (or `just update upsight`) does
    # it by hand on a host that already holds that SSH access.
    upsight = {
      url = "git+ssh://git@github.com/bashfulrobot/upsight?ref=main";
    };

    # claudoist, the Todoist task-level UI Extension receiver deployed by
    # server.claudoist (modules/server/claudoist). Private repo, same
    # git+ssh rationale as upsight above -- srv needs SSH read access.
    # Unlike upsight, claudoist's own flake.nix has no reproducibility
    # constraint pinning it to a specific nixpkgs (just plain
    # nixos-unstable), so follow this flake's own pin rather than carrying
    # a second nixpkgs into srv's closure.
    claudoist = {
      url = "git+ssh://git@github.com/bashfulrobot/claudoist?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Walkr, the topic-walkthrough renderer. Ships its own flake (packages.walkr,
    # own nixpkgs pin), a self-contained Go binary. Also
    # the source of the walkr-author / walkr-tutorial-author Claude Code skills
    # (skills/), symlinked into ~/.claude/skills by the claude-code module so the
    # binary and the skills that author its content stay pinned together.
    walkr = {
      url = "github:bashfulrobot/walkr";
    };

    # claudio, the phone-friendly Claude Code session manager (spawn/list/
    # delete `claude --bg --remote-control` sessions). Own flake, own
    # nixpkgs pin followed so its buildGoModule output stays aligned with
    # the rest of the system. Exposes nixosModules.default (services.claudio),
    # wired into srv below.
    claudio = {
      url = "github:bashfulrobot/claudio";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Janus, the secrets broker (github.com/bashfulrobot/janus, private).
    # Pinned to an explicit rev: the host must never run a working tree an
    # agent can edit, so `nix flake update` does not move this input. Bump it
    # by changing `rev` after reviewing the new commits. Exposes
    # nixosModules.default (services.janus), wired into qbert below.
    janus = {
      url = "git+ssh://git@github.com/bashfulrobot/janus?ref=main&rev=f91db1c203b99dd9522177ea44a8181a6820585a";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pinned upstream for the `humanizer` skill (claude-code + antigravity).
    # Tracks blader/humanizer; bump via `nix flake update humanizer-skill`
    # or `just upgrade`. `flake = false` because the repo ships a SKILL.md,
    # not a flake.
    humanizer-skill = {
      url = "github:blader/humanizer";
      flake = false;
    };

    # `crafter-station-skills` (the `intent-layer` skill) and
    # `vibecurb-skills` (the seven VibeCurb design skills) were removed on
    # 2026-10-26. Both existed only to feed symlink loops in
    # modules/apps/cli/claude-code/cfg/activation.nix. The VibeCurb seven now
    # come from the `vibecurb` plugin in claude-skills, and intent-layer is
    # gone from every source. Re-adding either means re-reading the upstream
    # at the rev being pinned, not just restoring these lines:
    # .claude/docs/vendored-skills.md holds the review bar.

    # bashfulrobot/claude-skills: the source of truth for the Claude Code
    # config. It carries the claude-stack manifest, the resolved per-host files
    # (claude-stack/resolved/<host>.json), the one shared CLAUDE.md and
    # statusline.sh, and `scripts/claude_stack.py apply`, which merges the
    # declared settings keys into ~/.claude/settings.json.
    #
    # Consumed only when `apps.cli.claude-code.stackApply.enable` is true
    # (default false). With it false the module keeps reading the hand-copied
    # snapshot under modules/apps/cli/claude-code/cfg/claude-stack/ and the jq
    # merge in cfg/activation.nix, so declaring this input changes no deployed
    # byte. See .claude/docs/claude-stack-apply.md for the switch-on steps.
    #
    # `flake = false` because the repo is a plugin marketplace, not a flake.
    #
    # `git+ssh`, not `github:`. The repo is PRIVATE, and the `github:` fetcher
    # authenticates with the nix `access-tokens` setting, which comes from
    # /run/nixos-secrets/nix-access-tokens.conf -- mode 0600 root, so only a
    # root nix can read it. Rebuilds run as root and would work; every
    # user-level nix would not, and that includes `nix fmt` (the .githooks
    # pre-commit formatter), `just build-host` and `nix flake check`, all of
    # which lock the flake. The git+ssh fetcher shells out to git instead and
    # uses the SSH agent, which the user has and which `sudo
    # --preserve-env=SSH_AUTH_SOCK nixos-rebuild` (every rebuild recipe in the
    # justfile) hands to root. One URL that works for both.
    #
    # Bump with `just update claude-skills`.
    claude-skills = {
      url = "git+ssh://git@github.com/bashfulrobot/claude-skills";
      flake = false;
    };

    # Recursive Nix module importer. Replaces the hand-rolled
    # `lib/autoimport.nix`; consumed by `modules/default.nix` and
    # `modules/apps/webapps/default.nix` via `inputs.import-tree`.
    #
    # Pinned to a release tag (not `main`) so `just upgrade` can't silently
    # follow upstream HEAD. The denful GitHub org was created 2026-04-20;
    # an org takeover or hostile push to main would otherwise land at the
    # next `nix flake update`. Bump this tag explicitly when re-auditing
    # upstream.
    import-tree.url = "github:denful/import-tree/v0.2.0";
  };

  outputs =
    inputs:
    let
      # Import configuration data
      globals = import ./settings/globals.nix;
      versions = import ./settings/versions.nix;

      # Nix-eval secrets, rendered from the gopass snapshot via `just render-secrets`
      # to a path outside the repo. String path (not Nix path literal) so the
      # file is read at eval time without being copied into the Nix store as
      # a flake input. See extras/docs/secrets.md.
      secretsFile = "${globals.user.homeDirectory}/.config/nixos-secrets/secrets.json";
      secrets = builtins.fromJSON (builtins.readFile secretsFile);

      # Import library functions
      lib = import ./lib { inherit inputs secrets; };
    in
    {
      # NixOS configurations
      nixosConfigurations = {
        qbert = lib.mkHost {
          inherit globals versions;
          hostname = "qbert";
          system = "x86_64-linux";
          extraModules = [
            # Disko declarative disk partitioning
            inputs.disko.nixosModules.disko
            # Hyprland desktop environment
            inputs.hyprflake.nixosModules.default
            inputs.claudio.nixosModules.default
            inputs.janus.nixosModules.default
            (
              { pkgs, ... }:
              {
                # Janus starts locked after every boot: run `janus unlock` and
                # type the passphrase. It runs as its own `janus` user, so the
                # admin uid must be explicit (checked on every socket connection).
                users.users.${globals.user.name}.uid = 1000;
                services.janus = {
                  enable = true;
                  adminUser = globals.user.name;
                  projectRoots = [ "/home/${globals.user.name}/git" ];
                  actionPackages = [ pkgs.kubectl ];
                  # Agents run as the separate `agent` user (janus-agent), never as you.
                  agent = {
                    enable = true;
                    command = "/etc/profiles/per-user/${globals.user.name}/bin/claude";
                  };
                };
              }
            )
            (
              { config, pkgs, ... }:
              {
                services.claudio = {
                  enable = true;
                  user = globals.user.name;
                  listenAddr = "127.0.0.1:8787";
                  # The module's default reads `pkgs.system`, which now warns
                  # at eval time. Set the package here to bypass that default.
                  package = inputs.claudio.packages.${pkgs.stdenv.hostPlatform.system}.default;
                  # systemd services don't inherit the user's shell PATH, so
                  # "claude" alone isn't found -- point at the stable
                  # per-user profile symlink instead of a /nix/store path
                  # that changes every generation.
                  claudeBinary = "/etc/profiles/per-user/${globals.user.name}/bin/claude";
                  roots = [
                    "/home/${globals.user.name}/git"
                    "/home/${globals.user.name}/dev"
                  ];
                };

                # Publish claudio on the tailnet only, via `tailscale serve`
                # -- never a raw firewall port. Mirrors the publish pattern
                # in modules/server/incident-investigator/default.nix.
                systemd.services.claudio-serve = {
                  description = "Publish claudio on the tailnet (tailscale serve)";
                  after = [
                    "tailscaled.service"
                    "network-online.target"
                    "claudio.service"
                  ];
                  wants = [
                    "tailscaled.service"
                    "network-online.target"
                  ];
                  wantedBy = [ "multi-user.target" ];
                  # `after = tailscaled.service` orders unit start only, and
                  # tailscaled is "active" well before its ipn backend leaves
                  # NoState. `tailscale serve` against a NoState backend exits
                  # 1 ("unexpected state: NoState"), so any rebuild that
                  # restarts tailscaled -- most nixpkgs/systemd bumps -- loses
                  # this race. Restart= does not save activation: it schedules
                  # a retry 10s later, while switch-to-configuration has
                  # already seen the first start fail and exits status 4, so
                  # `just qr` fails even though the serve lands seconds later.
                  # The retry therefore happens inside ExecStart, where the
                  # first start blocks until the serve command itself succeeds
                  # (30 tries, 2s apart, 60s ceiling). Restart= stays as the
                  # boot-time backstop: `on-failure` is the only Restart=
                  # systemd permits for Type=oneshot, the unit is never
                  # restarted on a clean exit, and StartLimitBurst bounds a
                  # genuinely broken serve config rather than looping forever.
                  startLimitBurst = 5;
                  startLimitIntervalSec = 300;
                  serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    Restart = "on-failure";
                    RestartSec = 10;
                    ExecStart = pkgs.writeShellScript "claudio-serve-start" ''
                      set -u
                      tries=30
                      i=1
                      while [ "$i" -le "$tries" ]; do
                        if ${config.services.tailscale.package}/bin/tailscale serve \
                          --bg --yes --https=443 --set-path=/claudio 127.0.0.1:8787; then
                          exit 0
                        fi
                        echo "tailscale serve attempt $i/$tries failed (backend likely still NoState); retrying in 2s" >&2
                        sleep 2
                        i=$((i + 1))
                      done
                      echo "tailscale serve did not succeed within 60s" >&2
                      exit 1
                    '';
                    # `-` prefix: don't fail the stop if the toggle syntax is
                    # rejected. Targets only this path, so any unrelated
                    # serve config on qbert is left untouched.
                    ExecStop = "-${config.services.tailscale.package}/bin/tailscale serve --https=443 --set-path=/claudio off";
                  };
                };

                # Launcher entry for Claudio's local web UI. Plain browser
                # window rather than the mkWebApp PWA wrapper -- this is a
                # loopback-only admin console for the local claudio.service,
                # not a cloud service needing its own persistent profile/
                # extensions (same rationale as modules/system/streaming's
                # sunshine-webui entry).
                home-manager.users.${globals.user.name}.xdg.desktopEntries.claudio = {
                  name = "Claudio";
                  comment = "Open the Claudio session manager";
                  exec = "${globals.preferences.browser} --new-window http://127.0.0.1:8787/";
                  icon = "utilities-terminal";
                  categories = [
                    "Development"
                    "Utility"
                  ];
                  terminal = false;
                };
              }
            )
          ];
          homeManagerModules = [
            # Spicetify for customized Spotify
            inputs.spicetify-nix.homeManagerModules.default
          ];
        };

        srv = lib.mkHost {
          inherit globals versions;
          hostname = "srv";
          system = "x86_64-linux";
          homeManagerModules = [ ];
        };
      };

      # Formatter for `nix fmt`
      formatter.x86_64-linux = inputs.nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;

      # Expose lib, globals, and versions for use in other flakes
      inherit lib globals versions;
    };
}
