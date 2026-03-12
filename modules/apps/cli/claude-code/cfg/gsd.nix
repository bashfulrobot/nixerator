{
  pkgs,
  versions,
  ...
}:

let
  gsd = pkgs.callPackage ../build/gsd { inherit versions; };

  gsdInstall = pkgs.writeShellApplication {
    name = "gsd-install";
    runtimeInputs = [
      pkgs.nodejs
      pkgs.jq
      gsd
    ];
    text = ''
      # settings.json is now a writable copy (not a Nix store symlink),
      # so GSD can write to it directly.
      get-shit-done-cc --claude --global "$@"
      echo "[gsd-install] Done. Run claude-capture to persist changes to Nix source tree."
    '';
  };
in
{
  packages = [
    gsd
    gsdInstall
  ];
  # GSD hooks (PostToolUse, SessionStart) are baked into config/settings.json.
  # They reference runtime JS files at ~/.claude/hooks/ installed by gsd-install.
}
