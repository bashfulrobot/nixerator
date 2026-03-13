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
      util-linux
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
      util-linux
      gnused
      findutils
      llm-agents.claude-code
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
      gum
      gh
      jq
      coreutils
      util-linux
      gnused
      findutils
      llm-agents.claude-code
    ];
    text = ''
      ${libSh}
      ${builtins.readFile ./scripts/dependabot.sh}
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
      dependabot-cmd
    ];

    home-manager.users.${globals.user.name} = {
      home.file.".claude/skills/github-issue/SKILL.md".text =
        builtins.readFile ./skills/github-issue/SKILL.md;
      home.file.".claude/skills/hack/SKILL.md".text = builtins.readFile ./skills/hack/SKILL.md;
      home.file.".claude/skills/dependabot/SKILL.md".text =
        builtins.readFile ./skills/dependabot/SKILL.md;
    };
  };
}
