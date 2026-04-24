{
  lib,
  pkgs,
  config,
  globals,
  versions,
  ...
}:

let
  cfg = config.apps.cli.agentos;
  agentos-pkg = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.agentos.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Agent OS (buildermethods/agent-os) -- a declarative workflow
        tool for AI coding agents. The pinned upstream tree is provisioned
        to ~/agent-os/ as writable real files (so user edits to profiles/
        survive), re-synced on version bumps. Per-project installs are done
        via the native `agent-os-project-install` wrapper, which runs the
        upstream project-install.sh against the current project directory.
        The agentos-init Claude Code skill wraps this for AI-driven project
        setup.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} =
      { lib, ... }:
      {
        home.packages = [ agentos-pkg ];

        # Deploy the agentos-init skill as a Nix-managed symlink. Because
        # every leaf is a store symlink, claude-capture's "skip
        # plugin-managed skills" heuristic already ignores it -- no
        # .capture-ignore entry needed.
        home.file.".claude/skills/agentos-init" = {
          source = ./skills/agentos-init;
          recursive = true;
        };

        # Bootstrap ~/agent-os/ from the pinned Nix store tree. Copy-based
        # (not symlink) so upstream's project-install.sh can operate on a
        # writable base, and so users can customize profiles/ in place.
        # Stamp-gated on the package's store path -- any derivation change
        # (version bump OR build patch) forces a re-sync, but idempotent
        # rebuilds are free. User edits to profiles/ are clobbered on
        # re-sync by design; run `agentos-capture` before upgrading to
        # preserve them in the repo.
        home.activation.agentosSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          set -eu
          target="${globals.user.homeDirectory}/agent-os"
          source="${agentos-pkg}/share/agent-os"
          stamp="$target/.nix-version"
          want="${agentos-pkg}"

          if [ ! -f "$stamp" ] || [ "$(cat "$stamp" 2>/dev/null)" != "$want" ]; then
            $DRY_RUN_CMD mkdir -p "$target"
            $DRY_RUN_CMD ${pkgs.rsync}/bin/rsync -a --chmod=u+w \
              "$source/" "$target/"
            echo "$want" > "$stamp"
          fi
        '';

        programs.fish.functions = {
          # Capture runtime Agent OS config back to the Nix source tree.
          # Mirrors the claude-capture pattern: only captures the GLOBAL
          # installation at ~/agent-os/profiles/, never per-project state.
          # Per-project artifacts (./agent-os/, ./.claude/commands/agent-os/)
          # live in each project's own git repo and are out of scope.
          #
          # Uses --compare-dest against the upstream pinned tree so ONLY
          # user-modified or user-added files land in the repo -- upstream
          # content stays out of git history. When the pinned upstream
          # bumps (new release), anything the user had edited shows up as
          # a diff they can reconcile or drop.
          agentos-capture = {
            description = "Capture ~/agent-os/profiles/ changes back to Nix source tree";
            body = ''
              set -l config_dir "${globals.paths.nixerator}/modules/apps/cli/agentos/config"
              set -l agentos_dir "$HOME/agent-os"
              set -l upstream_dir "${agentos-pkg}/share/agent-os"

              if not test -d "$agentos_dir"
                echo "Agent OS not installed at $agentos_dir; nothing to capture."
                return 0
              end

              if not test -d "$agentos_dir/profiles"
                echo "No profiles/ dir at $agentos_dir/profiles; nothing to capture."
                return 0
              end

              mkdir -p "$config_dir/profiles"

              echo "Capturing Agent OS profile changes vs upstream..."
              # --checksum compares by content (not mtime+size), and
              # --no-{perms,owner,group} ignores Nix-store-vs-home
              # metadata differences -- only actual CONTENT diffs land
              # in the repo.
              ${pkgs.rsync}/bin/rsync -a --delete \
                --checksum --no-perms --no-owner --no-group \
                --compare-dest="$upstream_dir/profiles/" \
                --exclude='.nix-version' \
                "$agentos_dir/profiles/" "$config_dir/profiles/"
              # --compare-dest leaves empty dir scaffolds from identical
              # subtrees; prune them so the repo only shows real diffs.
              ${pkgs.findutils}/bin/find "$config_dir/profiles" \
                -mindepth 1 -type d -empty -delete 2>/dev/null
              echo "  profiles/ (diffs only)"
              echo ""
              echo "Done. Review changes with: git diff $config_dir"
            '';
          };
        };
      };
  };
}
