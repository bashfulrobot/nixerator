{
  lib,
  pkgs,
  config,
  globals,
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
      gum
      gh
      jq
      coreutils
      gnused
      findutils
      llm-agents.claude-code
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
      gum
      gh
      jq
      coreutils
      gnused
      findutils
    ];
    text = ''
      ${libSh}
      ${builtins.readFile ./scripts/hack.sh}
    '';
  };
in
{
  options.apps.cli.worktree-flow.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable worktree-flow: AI-powered isolated worktree workflows for GitHub issues and quick tasks.";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      github-issue-cmd
      hack-cmd
    ];

    home-manager.users.${globals.user.name} = {
      home.file.".claude/skills/github-issue/SKILL.md".text =
        builtins.readFile ./skills/github-issue/SKILL.md;
    };
  };
}
