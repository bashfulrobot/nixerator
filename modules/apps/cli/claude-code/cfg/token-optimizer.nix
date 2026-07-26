# NixOS plumbing for the token-optimizer plugin (alexgreensh/token-optimizer).
#
# The plugin itself is installed the normal declarative way -- its marketplace
# is SHA-pinned in cfg/plugin-config.nix and the id lands in the per-host
# `plugins` list, so Claude Code fetches and enables it. Two things about it do
# not work out of the box on NixOS, and both are fixed here.
#
# 1. Interpreter discovery. Every one of the plugin's 24 hooks runs through
#    hooks/python-launcher.sh, which refuses any interpreter outside a
#    hardcoded allow-list:
#
#      _SAFE_PREFIXES="/usr/bin /usr/local/bin /opt/homebrew/bin \
#                      /opt/homebrew/opt /home/linuxbrew/.linuxbrew/bin"
#
#    There is no env override -- the cached-interpreter fast path re-applies
#    the same check, so TOKEN_OPTIMIZER_PY_CACHE cannot be used to smuggle one
#    in. On NixOS python3 lives at /run/current-system/sw/bin/python3 and
#    /usr/bin holds only `env`, so every hook exits 127. `tmpfilesRules` below
#    plants a root-owned /usr/local/bin/python3 symlink: the launcher matches on
#    the literal path string (it does not resolve the link), so the store path
#    behind it is irrelevant and the anti-PATH-hijack intent of the allow-list
#    is preserved -- /usr/local/bin is root-owned and unmanaged on NixOS, so
#    nothing else claims it.
#
# 2. Runtime writes into Nix-owned state. Left alone the plugin claims the
#    settings.json `statusLine` slot with an absolute path into its own
#    versioned plugin cache (self-healed on every upgrade), and silently
#    installs + enables ~/.config/systemd/user/token-optimizer-dashboard.service
#    at SessionStart. Both fight this module: the statusline is ours
#    (statusline.sh) and the unit is imperative state no one declared. Three
#    config flags turn that off at the source, and `activation` merges them into
#    the plugin's live config.json on every rebuild so a runtime toggle cannot
#    drift them back.
{ pkgs, homeDir }:

let
  marketplace = "alexgreensh-token-optimizer";
  pluginName = "token-optimizer";

  # plugin_env.resolve_plugin_data_dir() builds this as
  # <plugins>/data/<plugin>-<marketplace>, and both the consent gate
  # (hooks/run.py, via $CLAUDE_PLUGIN_DATA) and every _read_config_flag caller
  # (scripts/measure.py) land on config/config.json underneath it.
  dataDir = "${homeDir}/.claude/plugins/data/${pluginName}-${marketplace}";
  configDir = "${dataDir}/config";
  configFile = "${configDir}/config.json";

  # Nix-owned subset of config.json. Everything else in that file (consent
  # timestamps, last_* bookkeeping, feature toggles) stays untouched.
  nixOwnedFlags = {
    # Hooks no-op entirely until consent is recorded (hooks/run.py
    # _check_consent). Granting it here is what makes a fresh install actually
    # do anything without an interactive /token-optimizer round-trip.
    enterprise_consent_shown = true;
    # Keep our statusline. Suppresses the statusLine write and its
    # stale-path self-heal.
    quality_bar_disabled = true;
    # No self-installed systemd user unit, no loopback dashboard listener on
    # 127.0.0.1:24842. The hook-level optimization is unaffected. Flip this to
    # false (and rebuild) to opt into the dashboard.
    daemon_disabled = true;
  };
  flagsFile = pkgs.writeText "token-optimizer-flags.json" (builtins.toJSON nixOwnedFlags);
in
{
  pluginId = "${pluginName}@${marketplace}";

  tmpfilesRules = [
    "d /usr/local 0755 root root -"
    "d /usr/local/bin 0755 root root -"
    "L+ /usr/local/bin/python3 - - - - ${pkgs.python3}/bin/python3"
  ];

  activation = ''
    to_config_dir="${configDir}"
    to_config="${configFile}"
    $DRY_RUN_CMD mkdir -p "$to_config_dir"
    if [ -z "$DRY_RUN_CMD" ]; then
      # Never a store symlink: plugin_env._is_safe_subdir rejects symlinked
      # paths outright, and run.py's consent check treats a symlinked
      # config.json as "no config" and fails open -- which would silently undo
      # every flag below.
      [ -L "$to_config" ] && rm -f "$to_config"
      if [ ! -s "$to_config" ] || ! ${pkgs.jq}/bin/jq -e . "$to_config" >/dev/null 2>&1; then
        printf '{}\n' > "$to_config"
      fi
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$to_config" "${flagsFile}" > "$to_config.tmp"
      mv "$to_config.tmp" "$to_config"
      chmod 644 "$to_config"
    fi
  '';
}
