{
  allow = [
    # Non-Bash tools (auto-approve all local/reversible tools)
    "Read"
    "Edit"
    "Write"
    "Glob"
    "Grep"
    "WebSearch"
    "Agent"
    "Skill"

    # Nix operations (broad)
    "Bash(nix *)"
    "Bash(nix-*)"
    "Bash(statix check *)"
    "Bash(statix fix *)"
    "Bash(deadnix *)"
    "Bash(nixfmt *)"
    "Bash(nixos-option *)"
    "Bash(nixos-rebuild dry-build *)"
    "Bash(nixos-rebuild dry-activate *)"

    # Git operations
    "Bash(git *)"

    # Shell utilities
    "Bash(echo *)"
    "Bash(printf *)"
    "Bash(mkdir *)"
    "Bash(cp *)"
    "Bash(mv *)"
    "Bash(touch *)"
    "Bash(chmod *)"

    # File reading & viewing
    "Bash(cat *)"
    "Bash(bat *)"
    "Bash(head *)"
    "Bash(tail *)"
    "Bash(less *)"
    "Bash(wc *)"

    # File & directory discovery
    "Bash(ls)"
    "Bash(ls *)"
    "Bash(tree *)"
    "Bash(find *)"
    "Bash(fd *)"
    "Bash(file *)"
    "Bash(stat *)"
    "Bash(realpath *)"
    "Bash(readlink *)"
    "Bash(du *)"
    "Bash(df *)"

    # Content searching & text processing
    "Bash(grep *)"
    "Bash(rg *)"
    "Bash(ag *)"
    "Bash(sort *)"
    "Bash(uniq *)"
    "Bash(awk *)"
    "Bash(sed *)"
    "Bash(tr *)"
    "Bash(cut *)"
    "Bash(diff *)"
    "Bash(jq *)"
    "Bash(yq *)"
    "Bash(xargs *)"

    # Environment & system info
    "Bash(which *)"
    "Bash(command *)"
    "Bash(type *)"
    "Bash(env)"
    "Bash(env *)"
    "Bash(uname *)"
    "Bash(whoami)"
    "Bash(pwd)"
    "Bash(date *)"
    "Bash(id)"
    "Bash(id *)"
    "Bash(hostname)"
    "Bash(test *)"
    "Bash([ *)"

    # GitHub & Salesforce CLI
    "Bash(gh *)"
    "Bash(sf *)"

    # Dev toolchains
    "Bash(go *)"
    "Bash(cargo *)"
    "Bash(rustc *)"
    "Bash(npm *)"
    "Bash(npx *)"
    "Bash(node *)"
    "Bash(python *)"
    "Bash(python3 *)"
    "Bash(pip *)"

    # Code search & linting
    "Bash(amber *)"
    "Bash(shellcheck *)"

    # Task runner
    "Bash(just)"
    "Bash(just *)"

    # Shell subprocesses
    "Bash(fish *)"
    "Bash(bash *)"

    # Desktop & system tools
    "Bash(xdg-open *)"
    "Bash(notify-send *)"
    "Bash(ghostty *)"
    "Bash(tmux *)"
    "Bash(hyprctl *)"
    "Bash(clay-server *)"

    # System inspection
    "Bash(systemctl *)"
    "Bash(journalctl *)"
    "Bash(pgrep *)"
    "Bash(lsblk *)"
    "Bash(lspci)"
    "Bash(lscpu)"
    "Bash(dmesg *)"
    "Bash(zramctl *)"

    # Safe elevated
    "Bash(sudo tailscale file cp *)"
    "Bash(sudo dmidecode *)"

    # Process & networking (research)
    "Bash(curl *)"
    "Bash(wget *)"
    "Bash(ping *)"
    "Bash(dig *)"
    "Bash(nslookup *)"
    "Bash(ss *)"
    "Bash(ip *)"

    # Archives & compression
    "Bash(tar *)"
    "Bash(unzip *)"
    "Bash(gzip *)"

    # Web fetching — all domains
    "WebFetch"
  ];

  deny = [
    # Must use just qr / just qu — hooks also block these
    "Bash(nixos-rebuild switch *)"
    "Bash(nixos-rebuild boot *)"
    "Bash(nixos-rebuild test *)"
    "Bash(nix-collect-garbage *)"
  ];

  ask = [
    # Destructive actions require confirmation
    "Bash(rm *)"
    "Bash(sudo *)"
    "Bash(kill *)"
    "Bash(pkill *)"
  ];
}
