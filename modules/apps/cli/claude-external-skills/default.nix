{
  lib,
  pkgs,
  config,
  globals,
  versions,
  ...
}:
let
  cfg = config.apps.cli.claude-external-skills;

  # Upstream repos are fetched with pinned rev + hash. A drive-by repo
  # compromise cannot change what ends up in ~/.claude/skills/ without the
  # hash also being updated here, which is a conscious act.
  generate-images-src = pkgs.fetchFromGitHub {
    owner = "ericblue";
    repo = "my-claude";
    inherit (versions.cli.generate-images-skill) rev hash;
  };

  visual-explainer-src = pkgs.fetchFromGitHub {
    owner = "ericblue";
    repo = "visual-explainer-skill";
    inherit (versions.cli.visual-explainer-skill) rev hash;
  };
in
{
  options = {
    apps.cli.claude-external-skills.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Deploy upstream Claude Code skills (generate-images, visual-explainer)
        from pinned commits in versions.nix. Replaces the ad-hoc curl fetch
        that previously lived in `just update-skills`, giving each skill the
        same supply-chain guarantees (commit pin + hash verification) as any
        other Nix-managed package.

        Each skill is deployed as store symlinks under ~/.claude/skills/, so
        claude-capture correctly skips them (no real content in the live
        directory to mirror back into the repo).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      home.file = {
        # ericblue/my-claude keeps the skill in a subdirectory, so point
        # home.file at that subpath rather than the repo root.
        ".claude/skills/generate-images" = {
          source = "${generate-images-src}/skills/generate-images";
          recursive = true;
        };

        # ericblue/visual-explainer-skill ships the skill body as
        # skill/visual-explainer.md (not SKILL.md at the root). Place a
        # single file with the correct filename.
        ".claude/skills/visual-explainer/SKILL.md".source =
          "${visual-explainer-src}/skill/visual-explainer.md";
      };
    };
  };
}
