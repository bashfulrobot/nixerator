{
  config,
  lib,
  globals,
  inputs,
  ...
}:

# COSMIC Desktop Environment Module
# System76's Rust/Wayland desktop, packaged in nixpkgs and still marked beta
# upstream (tracking issue NixOS/nixpkgs#259641).
#
# This is an opt-in alternative to the Hyprland desktop in suites.desktop —
# enable it per host in hosts/<host>/modules.nix. Running it alongside the
# Hyprland suite is fine: cosmic-greeter lets you pick a session at login.
#
# Usage:
#   system.cosmic.enable = true;
# Then select "COSMIC" (or "COSMIC on X11") at the greeter.
#
# Terminal: under COSMIC the terminal is cosmic-term, not Ghostty. Enabling
# this module forces apps.gui.ghostty off, makes cosmic-term the default
# ($TERMINAL), and configures it to mirror the Ghostty module's settings.
#
# Declarative config: COSMIC apps store settings as cosmic-config RON files.
# We manage them through cosmic-manager's home-manager modules (typed options
# + a Nix->RON generator) rather than hand-writing RON. The HM module is
# imported unconditionally below but is inert until
# wayland.desktopManager.cosmic.enable is set (here, gated on system.cosmic).
#
# Caveats:
# - Beta upstream; expect rough edges and frequent churn in nixpkgs.
# - cosmic-term's schema cannot express several Ghostty settings (window
#   padding, scrollback-limit, copy-on-select, confirm-close, cursor-style,
#   mouse-hide-while-typing) — there are no equivalent fields.

let
  cfg = config.system.cosmic;
in
{
  options = {
    system.cosmic = {
      enable = lib.mkEnableOption "the COSMIC desktop environment (System76)";

      greeter.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Use cosmic-greeter as the display manager. Disable to keep an
          existing display manager (e.g. when COSMIC coexists with another DE
          that already owns the login screen).
        '';
      };

      xwayland.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Run XWayland so X11-only applications work under COSMIC.";
      };

      dataControl.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Export COSMIC_DATA_CONTROL_ENABLED=1 so clipboard managers and tools
          using the wlr-data-control protocol (zwlr_data_control_manager_v1)
          work under COSMIC.
        '';
      };

      excludePackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        example = lib.literalExpression "with pkgs; [ cosmic-edit cosmic-store ]";
        description = "COSMIC default applications to leave out of the install.";
      };
    };
  };

  config = lib.mkMerge [
    # Make cosmic-manager's typed COSMIC/RON options available to home-manager.
    # The module gates all of its own config behind
    # wayland.desktopManager.cosmic.enable, so importing it on every host
    # (including headless ones) is inert until that switch is flipped below.
    {
      home-manager.sharedModules = [ inputs.cosmic-manager.homeManagerModules.default ];
    }

    (lib.mkIf cfg.enable {
      services.desktopManager.cosmic = {
        enable = true;
        xwayland.enable = cfg.xwayland.enable;
      };

      services.displayManager.cosmic-greeter.enable = cfg.greeter.enable;

      # Under COSMIC the terminal is cosmic-term, not Ghostty. suites.terminal
      # enables Ghostty unconditionally, so force it off here.
      apps.gui.ghostty.enable = lib.mkForce false;

      # Guarantee the monospace font cosmic-term references is present even
      # without the Hyprland desktop suite (which normally pulls it in).
      system.apple-fonts.enable = true;

      environment = {
        cosmic.excludePackages = cfg.excludePackages;

        sessionVariables = lib.mkMerge [
          # Make cosmic-term the default terminal for $TERMINAL-aware tooling
          # (nautilus-open-any-terminal, xdg-terminal-exec, etc.). COSMIC's own
          # super+T keybind already launches cosmic-term.
          { TERMINAL = "cosmic-term"; }
          (lib.mkIf cfg.dataControl.enable { COSMIC_DATA_CONTROL_ENABLED = "1"; })
        ];
      };

      home-manager.users.${globals.user.name} = {
        # Turn on cosmic-manager's declarative COSMIC config management. It
        # serialises settings to RON (lib.cosmic.ron.toRON) and writes them with
        # `cosmic-ext-ctl apply` at home-manager activation.
        wayland.desktopManager.cosmic.enable = true;

        # cosmic-term, configured to mirror the Ghostty module as closely as
        # cosmic-term's v1 schema allows. cosmic-manager installs the package
        # (home.packages) and renders the RON config.
        #
        # Defining a profile is also what makes the typed module usable here: at
        # the pinned rev its `profiles` option runs `filter` in its apply, which
        # aborts on the null default — supplying a profile (with exactly one
        # default) satisfies it.
        programs.cosmic-term = {
          enable = true;

          settings = {
            # Ghostty `window-decoration = false` → hide cosmic-term's in-app
            # header bar (menu + tab strip). Faithful to the Ghostty+zellij
            # workflow, where zellij owns multiplexing.
            show_headerbar = false;
            # Match Ghostty's effective monospace font (Stylix sets SFMono Nerd
            # Font; apple-fonts above provides it).
            font_name = "SFMono Nerd Font";
            # Mirrors Stylix's terminal size (also cosmic-term's own default).
            font_size = 14;
            # Dark, matching the desktop suite's polarity. RON enum variant.
            app_theme = {
              __type = "enum";
              variant = "Dark";
            };
          };

          profiles = [
            {
              name = "dustin";
              is_default = true;
              # Don't keep the pane open after the shell exits.
              hold = false;
              # cosmic-term's built-in colour schemes.
              syntax_theme_dark = "COSMIC Dark";
              syntax_theme_light = "COSMIC Light";
              # command/working_directory left unset → launch the login shell
              # (fish) in the current working directory.
            }
          ];
        };
      };
    })
  ];
}
