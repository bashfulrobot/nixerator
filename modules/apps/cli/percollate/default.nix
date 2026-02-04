{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.cli.percollate;
  username = globals.user.name;
in
{
  options.apps.cli.percollate.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable percollate web-to-PDF converter with sitemap support.";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      percollate
      wget # For spider fallback when no sitemap
    ];

    home-manager.users.${username} = {
      programs.fish.functions = {
        web2pdf = ''
          # Convert website to PDF using sitemap or wget spider
          # Usage: web2pdf <url> [output.pdf] [--no-limit]

          if test (count $argv) -eq 0
            echo "Usage: web2pdf <url> [output.pdf] [--no-limit]"
            echo "  Fetches sitemap.xml (or crawls with wget) and converts all pages to PDF with TOC"
            echo "  Default limit: 1000 URLs. Use --no-limit to override."
            return 1
          end

          set -l url $argv[1]
          set -l no_limit false
          set -l output ""

          # Parse arguments
          for arg in $argv[2..-1]
            if test "$arg" = "--no-limit"
              set no_limit true
            else
              set output "$arg"
            end
          end

          # Extract base URL and protocol
          set -l base_url (string replace -r '/.*' "" (string replace -r '^https?://' "" "$url"))
          set -l protocol (string match -r '^https?' "$url")
          test -z "$protocol"; and set protocol "https"
          set -l root_url "$protocol://$base_url"

          test -z "$output"; and set output "$base_url.pdf"

          set -l sitemap_url "$root_url/sitemap.xml"
          set -l urls

          echo "Attempting sitemap at $sitemap_url..."
          set -l sitemap_content (curl -sL --fail "$sitemap_url" 2>/dev/null)

          if test -n "$sitemap_content"
            # Extract URLs from sitemap <loc> tags
            set urls (echo "$sitemap_content" | grep -oP '(?<=<loc>)[^<]+')
            if test (count $urls) -gt 0
              echo "Found "(count $urls)" URLs in sitemap"
            end
          end

          # Fallback to wget spider if no sitemap or empty
          if test (count $urls) -eq 0
            echo "No sitemap found. Crawling with wget spider..."
            set -l tmpfile (mktemp)
            wget --spider --recursive --level=inf --no-verbose "$root_url" 2>&1 | \
              grep -oP '(?<=URL: )[^ ]+' | sort -u > "$tmpfile"
            set urls (cat "$tmpfile")
            rm -f "$tmpfile"

            if test (count $urls) -eq 0
              echo "No URLs found via crawl. Converting single URL..."
              set urls $url
            else
              echo "Found "(count $urls)" URLs via crawl"
            end
          end

          # Apply URL limit
          set -l url_limit 1000
          if test (count $urls) -gt $url_limit; and test "$no_limit" = "false"
            echo "Warning: Found "(count $urls)" URLs, limiting to $url_limit"
            echo "Use --no-limit to process all URLs"
            set urls $urls[1..$url_limit]
          end

          echo "Converting "(count $urls)" pages to $output with TOC..."
          percollate pdf --toc --toc-level=3 --title="$base_url" $urls -o "$output"

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
