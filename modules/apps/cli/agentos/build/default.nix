{
  lib,
  pkgs,
  versions,
  ...
}:

let
  v = versions.cli.agentos;
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "agent-os";
  inherit (v) version;

  src = pkgs.fetchFromGitHub {
    owner = "buildermethods";
    repo = "agent-os";
    rev = "v${v.version}";
    inherit (v) hash;
  };

  dontBuild = true;

  # Upstream v3.0.0 fixes -- drop individual fixes as upstream lands them.
  #
  # 1. `set -e` + `((counter++))` when counter starts at 0: post-increment
  #    returns the old value (0), which `((...))` treats as arithmetic-
  #    false -> exit 1 -> set -e kills the script. All 13 occurrences are
  #    pure counters never used as conditions, so rewriting to
  #    `counter=$((counter+1))` is semantically identical and set-e-safe.
  #
  # 2. config.yml ships `default_profile: test-profile`, but only the
  #    `default` profile ships. Running project-install.sh without an
  #    explicit `--profile` errors with "Profile not found: test-profile".
  #    Rewrite to `default_profile: default` so the default works out of
  #    the box. User edits to ~/agent-os/config.yml persist within a
  #    version generation; a version bump re-syncs from upstream.
  postPatch = ''
    # Guard #1: bail if upstream has fixed the ((counter++)) bug -- the
    # sed below would then be a no-op that silently drifts out of date.
    # When this assertion fires, verify the fix and delete the guarded
    # block.
    if ! ${pkgs.gnugrep}/bin/grep -rq -E '\(\([a-zA-Z_][a-zA-Z0-9_]*\+\+\)\)' scripts; then
      echo "agent-os: upstream appears to have fixed the ((counter++)) bug." >&2
      echo "  Drop the counter-postPatch block in modules/apps/cli/agentos/build/default.nix." >&2
      exit 1
    fi
    find scripts -type f -name '*.sh' -exec \
      ${pkgs.gnused}/bin/sed -i -E \
        's/\(\(([a-zA-Z_][a-zA-Z0-9_]*)\+\+\)\)/\1=$((\1+1))/g' {} +

    # Guard #2: bail if upstream has fixed the default_profile bug.
    if ! ${pkgs.gnugrep}/bin/grep -q '^default_profile: test-profile$' config.yml; then
      echo "agent-os: upstream config.yml no longer defaults to test-profile." >&2
      echo "  Verify the new default is sensible, then drop the config.yml" >&2
      echo "  postPatch block in modules/apps/cli/agentos/build/default.nix." >&2
      exit 1
    fi
    ${pkgs.gnused}/bin/sed -i \
      's/^default_profile:.*/default_profile: default/' config.yml
  '';

  # Upstream is a pure shell-script repo. We stage the tree under
  # $out/share/agent-os/ for the activation script to rsync into
  # $HOME/agent-os/, and expose a thin wrapper that invokes the
  # HOME-dir copy (so user edits to ~/agent-os/profiles/ take effect
  # at runtime -- the store path is only the provisioning source).
  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/agent-os" "$out/bin"
    cp -r profiles scripts commands config.yml "$out/share/agent-os/"
    find "$out/share/agent-os/scripts" -type f -name '*.sh' -exec chmod +x {} \;

    cat > "$out/bin/agent-os-project-install" <<'WRAPPER'
    #!${pkgs.bash}/bin/bash
    set -e
    base="$HOME/agent-os"
    if [ ! -x "$base/scripts/project-install.sh" ]; then
      echo "Agent OS base installation not found at $base" >&2
      echo "Rebuild your NixOS configuration to provision it." >&2
      exit 1
    fi
    exec "$base/scripts/project-install.sh" "$@"
    WRAPPER
    chmod +x "$out/bin/agent-os-project-install"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Agent OS - buildermethods workflow tool for AI coding agents";
    homepage = "https://github.com/buildermethods/agent-os";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.unix;
    mainProgram = "agent-os-project-install";
  };
}
