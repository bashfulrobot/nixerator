# OneCLI gateway container environment (server.nanoclaw).
#
# TEMPLATE, checked into git with placeholders only. nanoclaw-onecli-env.service
# renders it at runtime with envsubst, restricted to the one ONECLI_DB_PASSWORD
# placeholder, into /run/nanoclaw-onecli/onecli.env (0600, root), reading the
# value from the agenix-decrypted file via LoadCredential. It is never rendered
# at eval or build time, so the real value never reaches /nix/store.
#
# Comments here deliberately avoid the placeholder's dollar syntax: envsubst
# would fill it in inside comments too.
DATABASE_URL=postgresql://onecli:${ONECLI_DB_PASSWORD}@onecli-postgres:5432/onecli
