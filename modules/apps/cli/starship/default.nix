{
  globals,
  lib,
  config,
  ...
}:

let
  cfg = config.apps.cli.starship;
in
{
  options = {
    apps.cli.starship.enable = lib.mkEnableOption "starship prompt";
  };

  config = lib.mkIf cfg.enable {

    # Home Manager user configuration
    home-manager.users.${globals.user.name} = {

      programs.starship = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        enableFishIntegration = true;
        enableNushellIntegration = true;
        enableIonIntegration = true;
        enableInteractive = true;
        enableTransience = true;
        settings = {
          command_timeout = 300;
          add_newline = false;
          format = "$custom$character";
          right_format = "$directory$git_branch$git_status$kubernetes$hostname";

          character = {
            success_symbol = "[❯](bold)";
            error_symbol = "[❯](bold red)";
          };

          line_break.disabled = true;
          package.disabled = true;
          container.disabled = true;
          git_status = {
            format = "[$all_status]($style)";
            ahead = "⇡\${count} ";
            behind = "⇣\${count} ";
            diverged = "⇕⇡\${ahead_count}⇣\${behind_count} ";
            conflicted = " ";
            up_to_date = " ";
            untracked = "? ";
            modified = " ";
            staged = "+ ";
            renamed = "» ";
            deleted = "✘ ";
          };
          terraform.symbol = " ";
          git_branch = {
            symbol = " ";
            style = "italic";
            format = "[$symbol$branch]($style) ";
          };
          directory = {
            read_only = " ";
            truncation_length = 2;
            truncation_symbol = "…/";
            repo_root_style = "bold";
            format = "[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) ";
          };
          custom.env = {
            command = "cat /etc/prompt";
            format = "$output ";
            when = "test -f /etc/prompt";
            shell = "fish";
            ignore_timeout = true;
          };
          rust.disabled = true;
          scala.disabled = true;
          nix_shell.disabled = true;
          nodejs.disabled = true;
          golang.disabled = true;
          java.disabled = true;
          deno.disabled = true;
          lua.disabled = true;
          docker_context.disabled = true;
          python.disabled = true;
          cmd_duration.disabled = true;
          kubernetes = {
            disabled = false;
            format = "[$symbol$context( \\($namespace\\))]($style) ";
            symbol = "⎈ ";
            style = "bold blue";
          };
          hostname = {
            ssh_only = true;
            format = "[@$hostname]($style) ";
            style = "bold dimmed white";
          };
          gcloud.disabled = true;
          aws.disabled = true;
        };
      };

    };

  };
}
