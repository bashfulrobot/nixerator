# Runtime-materialization helper. The single mechanism every module uses to
# consume a secret value WITHOUT that value entering Nix eval or the
# world-readable /nix/store. Values are read at runtime from the off-store JSON
# written by `just render-secrets`. See extras/docs/secrets.md and issue #265.
#
# The shape it covers is the activation/preStart write. A runtime *read* (a
# value consumed live inside a service or shell script) stays a one-line jq
# idiom, as restic and the fish module already express it inline; wrapping that
# in a helper adds indirection without removing real boilerplate, and a
# shell-substitution string would have to bake in fish-vs-POSIX syntax. The
# write path is where the boilerplate lives (presence guard, mkdir, umask, temp
# file, chmod, atomic move), so that is what `installValue` centralizes.
#
# Value-free by construction: nothing here takes or returns a secret value,
# only the off-store path and a caller-supplied jq binary. That is what keeps
# the helper (and everything importing it) out of the leak surface.
{
  # Canonical off-store secrets path for a host.
  file = globals: "${globals.user.homeDirectory}/.config/nixos-secrets/secrets.json";

  # Writes the value at `path` to `dest` with `mode`, wrapped so the plaintext
  # never hits argv (jq reads the file, output is redirected). No-op when the
  # key is absent or the secrets file is missing, so hosts without the secret
  # activate cleanly. The parent directory is created here (0755, outside the
  # umask subshell) so no caller has to remember it, and so a dir shared with a
  # non-root reader (e.g. a container mount) stays traversable. `prefix`/`suffix`
  # wrap the value, e.g. to emit `access-tokens = github.com=<value>` for a
  # nix.conf `!include` fragment.
  #
  # jq         : absolute path to a jq binary (e.g. "${pkgs.jq}/bin/jq")
  # secretsFile: path to the rendered secrets JSON
  # path       : a jq filter selecting the value, e.g. ".gemini.apiKey"
  installValue =
    {
      jq,
      secretsFile,
      path,
      dest,
      mode ? "0600",
      prefix ? "",
      suffix ? "",
    }:
    ''
      if [ -f "${secretsFile}" ] && ${jq} -e '${path} // empty' "${secretsFile}" >/dev/null 2>&1; then
        mkdir -p "$(dirname "${dest}")"
        (
          umask 077
          { printf '%s' '${prefix}'
            ${jq} -j '${path}' "${secretsFile}"
            printf '%s' '${suffix}'
          } > "${dest}.tmp"
          chmod ${mode} "${dest}.tmp"
          mv "${dest}.tmp" "${dest}"
        )
      fi
    '';
}
