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
  postFixup = ''
    wrapProgram $out/bin/gws \
      --set GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND file
  '';

  meta = with lib; {
    description = "Google Workspace CLI — one command-line tool for Drive, Gmail, Calendar, Sheets, Docs, Chat, Admin, and more - https://github.com/googleworkspace/cli";
    maintainers = [ ];
  };
}
