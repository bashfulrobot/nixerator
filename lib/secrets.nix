# Runtime-materialization helper. The single mechanism every module uses to
# consume a secret value WITHOUT that value entering Nix eval or the
# world-readable /nix/store. Values are read at runtime from the off-store JSON
# written by `just render-secrets`. See extras/docs/secrets.md and issue #265.
#
# Two shapes, mirroring what the repo already did by hand in two places:
#   - restic/default.nix reads the file at service runtime.
#   - claude-code/cfg/activation.nix substitutes values at activation.
#
#   readExpr     -> a `jq` command substitution to embed in a shell script,
#                   e.g. `set -gx FOO (readExpr ...)`. The value is read when the
#                   script runs, never at build time.
#   installValue -> an activation/preStart snippet that writes ONE secret to a
#                   mode-restricted file, only when the key is present. jq reads
#                   straight from the file, so the value never hits argv.
#
# Value-free by construction: no function here takes or returns a secret value,
# only the off-store path and a caller-supplied jq binary. That is what keeps
# the helper (and everything importing it) out of the leak surface.
{
  # Canonical off-store secrets path for a host.
  file = globals: "${globals.user.homeDirectory}/.config/nixos-secrets/secrets.json";

  # jq         : absolute path to a jq binary (e.g. "${pkgs.jq}/bin/jq")
  # secretsFile: path to the rendered secrets JSON
  # path       : a jq filter selecting the value, e.g. ".gemini.apiKey"
  readExpr =
    {
      jq,
      secretsFile,
      path,
    }:
    "(${jq} -r '${path}' ${secretsFile})";

  # Writes the value at `path` to `dest` with `mode`, wrapped so the plaintext
  # never hits argv (jq reads the file, output is redirected). No-op when the
  # key is absent or the secrets file is missing, so hosts without the secret
  # activate cleanly. `prefix`/`suffix` wrap the value, e.g. to emit
  # `access-tokens = github.com=<value>` for a nix.conf `!include` fragment.
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
      if [ -f ${secretsFile} ] && ${jq} -e '${path} // empty' ${secretsFile} >/dev/null 2>&1; then
        (
          umask 077
          { printf '%s' '${prefix}'
            ${jq} -j '${path}' ${secretsFile}
            printf '%s' '${suffix}'
          } > ${dest}.tmp
          chmod ${mode} ${dest}.tmp
          mv ${dest}.tmp ${dest}
        )
      fi
    '';
}
