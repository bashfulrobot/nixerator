{
  lib,
  pkgs,
  versions,
  ...
}:
pkgs.stdenv.mkDerivation {
  name = "gws";
  src = pkgs.fetchurl {
    url = "https://github.com/googleworkspace/cli/releases/download/v${versions.cli.gws.version}/google-workspace-cli-x86_64-unknown-linux-gnu.tar.gz";
    inherit (versions.cli.gws) hash;
  };

  nativeBuildInputs = [
    pkgs.autoPatchelfHook
    pkgs.makeWrapper
  ];
  buildInputs = [
    pkgs.stdenv.cc.cc.lib
  ];

  dontBuild = true;

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    cp gws $out/bin/gws
    chmod +x $out/bin/gws
  '';

  # Pin the credential backend for every caller, interactive and scheduled
  # alike. gws defaults to the `keyring` backend, which reaches the OS keyring
  # when a session bus is available and silently falls back to
  # ~/.config/gws/.encryption_key when one is not.
  #
  # That split is the hazard. `gws auth login` from a desktop terminal has a
  # session bus, so it would write the new key to the OS keyring, while a
  # scheduled run with no session would keep reading the stale file. gws
  # answers a store it cannot decrypt by deleting it ("removing undecryptable
  # credentials file"), so the divergence costs the credentials rather than one
  # failed run, and takes interactive gws down with it.
  #
  # Wrapping the binary is the only place that covers `gws` itself. Setting the
  # variable on a unit would pin the units we happen to write and leave every
  # other caller on the default. `--set` rather than `--set-default` because a
  # scheduled unit never inherits the shell environment, so a shell-level
  # override would reintroduce exactly the split this closes.
  #
  # The pin alone still has one destructive edge. A credential store that was
  # written while the key lived in the OS keyring leaves credentials.enc on disk
  # with no .encryption_key beside it. Handing that to the file backend is the
  # case gws answers by deleting the store and exiting 0, so the first run after
  # the pin lands would silently destroy credentials that a `gws auth login`
  # under the old backend could still decrypt. The guard below refuses that one
  # state and says what to do instead. An unwrapped `.gws-wrapped` is still
  # there for anyone who needs to get at the old backend.
  guard = ''
    gws_cfg="''${XDG_CONFIG_HOME:-$HOME/.config}/gws"
    if [ -f "$gws_cfg/credentials.enc" ] && [ ! -f "$gws_cfg/.encryption_key" ]; then
      echo "gws: refusing to run." >&2
      echo "  $gws_cfg/credentials.enc exists but $gws_cfg/.encryption_key does not." >&2
      echo "  This build pins the credential backend to 'file', and gws answers a store" >&2
      echo "  it cannot decrypt by deleting it. Those credentials were almost certainly" >&2
      echo "  encrypted with a key still held in the OS keyring." >&2
      echo "  Re-authenticate to rebuild the store under the file backend:" >&2
      echo "    mv \"$gws_cfg/credentials.enc\" \"$gws_cfg/credentials.enc.keyring-backup\"" >&2
      echo "    gws auth login" >&2
      exit 78
    fi
  '';

  postFixup = ''
    wrapProgram $out/bin/gws \
      --set GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND file \
      --run "$guard"
  '';

  meta = with lib; {
    description = "Google Workspace CLI — one command-line tool for Drive, Gmail, Calendar, Sheets, Docs, Chat, Admin, and more - https://github.com/googleworkspace/cli";
    maintainers = [ ];
  };
}
