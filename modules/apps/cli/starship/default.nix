{ globals, lib, config, ... }:

let
  cfg = config.apps.cli.starship;
  username = globals.user.name;
in
{
  options = {
    apps.cli.starship.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable starship prompt.";
    };
  };

  config = lib.mkIf cfg.enable {

    # Home Manager user configuration
    home-manager.users.${username} = {

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
          right_format = "$all";

          character = {
            success_symbol = "[⦿](bold)";
            error_symbol = "[⦿](bold red)";
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
          rust = {
            format = "[$symbol]($style)";
            symbol = " ";
          };
          scala = {
            format = "[$symbol]($style)";
            symbol = " ";
          };
          nix_shell = {
            format = "[$symbol$name ]($style)";
            symbol = " ";
          };
          nodejs = {
            format = "[$symbol]($style)";
            symbol = " ";
          };
          golang = {
            format = "[$symbol]($style)";
            symbol = " ";
          };
          java = {
            format = "[$symbol]($style)";
            symbol = " ";
          };
          deno = {
            format = "[$symbol]($style)";
            symbol = " ";
          };
          lua = {
            format = "[$symbol]($style)";
            symbol = " ";
          };
          docker_context = {
            format = "[$symbol]($style)";
            symbol = " ";
          };
          python = {
            format = "[$symbol]($style)";
            symbol = " ";
          };
          cmd_duration = {
            min_time = 500;
            format = "took [$duration]($style) ";
          };
          gcloud.disabled = true;
          aws.disabled = true;
        };
      };

    };

  };
}
