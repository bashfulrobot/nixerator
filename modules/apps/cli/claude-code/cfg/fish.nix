{
  functions = {
    # Wrapper that offers to clean up project .mcp.json on exit
    claude = {
      wraps = "claude";
      body = ''
        command claude $argv
        set -l exit_code $status
        if test -f .mcp.json
            read -P "Remove .mcp.json from this project? [y/N] " confirm
            if string match -qi 'y*' -- $confirm
                rm .mcp.json
                echo "Removed .mcp.json"
            end
        end
        return $exit_code
      '';
    };

    # Read-only Q&A — pipe-friendly headless helper
    ask = {
      description = "Ask Claude a question (read-only tools, pipe-friendly)";
      body = ''
        set -l prompt (string join " " $argv)
        if not isatty stdin
          set input (cat)
          claude -p "$prompt\n\n$input" --allowedTools "Read,Bash,Glob,Grep"
        else
          claude -p $prompt --allowedTools "Read,Bash,Glob,Grep"
        end
      '';
    };
  };

  # Fish abbreviations
  shellAbbrs = {
    cc = {
      position = "command";
      setCursor = true;
      expansion = "claude -p \"%\"";
    };
  };
}
