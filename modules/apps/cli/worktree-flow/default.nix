{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.worktree-flow;
  libSh = builtins.readFile ./scripts/lib.sh;

  github-issue-cmd = pkgs.writeShellApplication {
    name = "github-issue";
    runtimeInputs = with pkgs; [
      git
      git-crypt
      gh
      jq
      coreutils
      util-linux
      gnused
      findutils
    ];
    text = ''
      ${libSh}
      ${builtins.readFile ./scripts/github-issue.sh}
    '';
  };

  hack-cmd = pkgs.writeShellApplication {
    name = "hack";
    runtimeInputs = with pkgs; [
      git
      git-crypt
      gh
      jq
      coreutils
      util-linux
      gnused
      findutils
    ];
    text = ''
      ${libSh}
      ${builtins.readFile ./scripts/hack.sh}
    '';
  };

  dependabot-cmd = pkgs.writeShellApplication {
    name = "dependabot";
    runtimeInputs = with pkgs; [
      git
      git-crypt
      gh
      jq
      coreutils
      util-linux
      gnused
      findutils
    ];
    text = ''
      ${libSh}
      ${builtins.readFile ./scripts/dependabot.sh}
    '';
  };
in
{
  options.apps.cli.worktree-flow.enable =
    lib.mkEnableOption "worktree-flow: AI-powered isolated worktree workflows for GitHub issues and quick tasks";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      github-issue-cmd
      hack-cmd
      dependabot-cmd
    ];

    # 2026-10-26: this module no longer writes ~/.claude/skills/{github-issue,
    # hack,dependabot}. The dk plugin in claude-skills ships all three under
    # the same names, and the copies here had drifted behind it (215 vs 218,
    # 297 vs 300, 779 vs 799 lines), so a session loaded whichever of the two
    # it happened to resolve first. The three CLIs above are the part this
    # module owns and they stay. Decision recorded as A8 in claude-skills
    # docs/plans/personal-vs-upstream-assessment.md.
    #
    # ./skills/ is kept on disk, unreferenced, as the record of what the dk
    # copies were forked from. The stale ~/.claude/skills directories are
    # removed by hand on qbert; home-manager drops its own managed files on
    # the next rebuild, but the directories it created are left behind.
  };
}
