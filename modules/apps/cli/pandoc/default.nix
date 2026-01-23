{ globals, lib, config, pkgs, ... }:

let
  cfg = config.apps.cli.pandoc;
  username = globals.user.name;
in
{
  options = {
    apps.cli.pandoc.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable pandoc document converter with PDF support.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      pandoc
      (texliveSmall.withPackages (ps: with ps; [
        # Core LaTeX packages for pandoc PDF generation
        collection-fontsrecommended
        collection-latexrecommended
        fancyvrb
        booktabs
        etoolbox
        mdwtools
        footmisc
        xcolor
      ]))
    ];

    # Fish function for markdown to PDF conversion
    home-manager.users.${username} = {
      programs.fish.functions = {
        md2pdf = ''
          if test (count $argv) -eq 0
            echo "Usage: md2pdf <input.md>"
            return 1
          end

          set -l input $argv[1]

          if not test -f "$input"
            echo "Error: File '$input' not found"
            return 1
          end

          set -l output (string replace -r '\.md$' '.pdf' "$input")

          pandoc "$input" -o "$output" \
            -V fontfamily=helvet \
            -V geometry:margin=1in

          if test $status -eq 0
            echo "Created: $output"
          else
            echo "Error: PDF generation failed"
            return 1
          end
        '';
      };
    };
  };
}
