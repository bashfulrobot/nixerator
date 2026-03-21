{
  pkgs,
  versions,
  homeDir,
  ...
}:

let
  reap = pkgs.callPackage ../build/reap { inherit versions; };
in
{
  packages = [ reap ];

  # Deploy slash commands from reap's dist/templates/commands/ to ~/.reap/commands/
  activation = ''
    reap_commands="${reap}/lib/node_modules/@c-d-cc/reap/dist/templates/commands"
    reap_target="${homeDir}/.reap/commands"
    if [ -d "$reap_commands" ]; then
      $DRY_RUN_CMD mkdir -p "$reap_target"
      for cmd in "$reap_commands"/*.md; do
        [ -f "$cmd" ] || continue
        $DRY_RUN_CMD cp --no-preserve=mode "$cmd" "$reap_target/$(basename "$cmd")"
      done
    fi
  '';
}
