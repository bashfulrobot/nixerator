# agenix recipients (read by the `agenix` CLI only, never imported into a
# NixOS evaluation). Scope: srv's server.nanoclaw. Everything else in this repo
# stays on 1Password; see extras/docs/nanoclaw/README.md.
#
# The .age payloads are NOT in git until you create them. Until both exist,
# hosts/srv/modules.nix leaves server.nanoclaw disabled and prints a warning,
# so srv keeps building.
#
# Fill in the two keys below (public keys, not secret):
#   srv:    ssh srv cat /etc/ssh/ssh_host_ed25519_key.pub
#           (agenix decrypts at activation with this host key)
#   dustin: an age or ssh-ed25519 public key whose private half you hold on a
#           workstation, so you can re-edit the files with `agenix -e`.
#           Optional: plain `age -R` encryption to srv alone also works
#           (the README shows both).
let
  srv = "ssh-ed25519 AAAA_REPLACE_WITH_SRV_HOST_KEY root@srv";
  dustin = "ssh-ed25519 AAAA_REPLACE_WITH_YOUR_KEY dustin@workstation";
in
{
  # `claude setup-token` output: one line, sk-ant-oat01-...
  "nanoclaw-claude-token.age".publicKeys = [
    srv
    dustin
  ];
  # OneCLI PostgreSQL password: `openssl rand -hex 32`
  "nanoclaw-onecli-db-password.age".publicKeys = [
    srv
    dustin
  ];
}
