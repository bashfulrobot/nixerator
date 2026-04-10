{
  globals,
  pkgs,
  config,
  lib,
  versions,
  ...
}:

let
  cfg = config.apps.cli.crawl4ai;
  crawl4ai = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.crawl4ai.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable crawl4ai - LLM-friendly web crawling CLI.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ crawl4ai ];

    home-manager.users.${globals.user.name} =
      { lib, ... }:
      {
        home.activation.crawl4aiSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD mkdir -p "${globals.user.homeDirectory}/.crawl4ai"
        '';

        programs.fish.functions = {
          # Crawl a URL and output markdown to stdout
          web2md = ''
            if test (count $argv) -eq 0
              echo "Usage: web2md <url> [output-file]"
              echo "  Crawl a page and output clean markdown"
              return 1
            end
            if test (count $argv) -ge 2
              crwl crawl $argv[1] --output markdown -O $argv[2]
              echo "Saved to $argv[2]"
            else
              crwl crawl $argv[1] --output markdown
            end
          '';

          # Deep-crawl an entire site to markdown files
          web2md-deep = ''
            if test (count $argv) -eq 0
              echo "Usage: web2md-deep <url> [max-pages] [output-dir]"
              echo "  Deep-crawl a site (BFS) and save markdown per page"
              echo "  Default: 50 pages, output to ./crawl-output/"
              return 1
            end
            set -l url $argv[1]
            set -l max_pages 50
            set -l output_dir ./crawl-output
            if test (count $argv) -ge 2
              set max_pages $argv[2]
            end
            if test (count $argv) -ge 3
              set output_dir $argv[3]
            end
            mkdir -p $output_dir
            crwl crawl $url --deep-crawl bfs --max-pages $max_pages --output markdown -O $output_dir/crawl.md
            echo "Crawled $url (max $max_pages pages) → $output_dir/"
          '';

          # Crawl a URL and copy markdown to clipboard
          web2clip = ''
            if test (count $argv) -eq 0
              echo "Usage: web2clip <url>"
              echo "  Crawl a page and copy markdown to clipboard"
              return 1
            end
            crwl crawl $argv[1] --output markdown | wl-copy
            echo "Copied to clipboard"
          '';
        };
      };
  };
}
