{ lib, config, ... }:

let
  cfg = config.archetypes.workstation;
in
{
  options = {
    archetypes.workstation.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable workstation archetype with core system infrastructure, browsers, security, development, infrastructure, and k8s suites.";
    };

    archetypes.workstation.desktop = lib.mkOption {
      type = lib.types.enum [
        "hyprland"
        "cosmic"
      ];
      default = "cosmic";
      description = ''
        Which desktop environment the workstation runs.

        - "hyprland": the hyprflake Hyprland desktop (suites.desktop), GDM login.
        - "cosmic": the COSMIC desktop (system.cosmic). cosmic-greeter owns
          login and hyprflake's GDM is forced off. hyprflake itself stays
          imported (in flake.nix), so Hyprland remains a selectable session at
          the greeter and theming/voxtype keep working.

        Reverting COSMIC is intentionally cheap: set this back to "hyprland" and
        rebuild, or just pick Hyprland at the greeter for a one-off session
        without rebuilding at all.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Kernel sysctl tweaks for desktop responsiveness
    boot.kernel.sysctl = {
      "vm.swappiness" = 10; # Prefer RAM over swap
      "vm.vfs_cache_pressure" = 50; # Keep directory/inode caches longer
      "kernel.sched_autogroup_enabled" = 1; # Better desktop responsiveness
    };

    # Compressed in-RAM swap — faster than disk, extends usable RAM
    zramSwap = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = 50;
    };

    # FHS compatibility
    system.compat.enable = true;

    # Enable workstation suites
    suites = {
      core.enable = true; # Core system infrastructure
      desktop.enable = cfg.desktop == "hyprland"; # Hyprland (hyprflake); COSMIC handled below
      terminal.enable = true; # Terminal suite
      browsers.enable = true; # Browser suite
      security.enable = true; # Security suite
      dev.enable = true; # Development suite
      offcomms.enable = true; # Communications suite
      infrastructure.enable = true; # Infrastructure and cloud tools
      k8s.enable = true; # Kubernetes tooling
      kong.enable = true; # Kong API Gateway suite
      av.enable = true; # Audio/visual creative suite
      ai.enable = true; # AI tooling suite
    };

    # COSMIC desktop, the alternative to the Hyprland suite above. Selected by
    # archetypes.workstation.desktop = "cosmic".
    system.cosmic.enable = cfg.desktop == "cosmic";

    # In COSMIC mode, force hyprflake's desktop fully down so the two never run
    # side by side: no GDM (cosmic-greeter is the sole display manager) and no
    # Hyprland session (cosmic-session is the only selectable session at the
    # greeter). hyprflake stays imported in flake.nix only so voxtype and
    # theming keep working and reverting stays a one-line change; with both of
    # these forced off it no longer presents a usable desktop.
    hyprflake.desktop.displayManager.enable = lib.mkIf (cfg.desktop == "cosmic") (lib.mkForce false);
    programs.hyprland.enable = lib.mkIf (cfg.desktop == "cosmic") (lib.mkForce false);
  };
}
