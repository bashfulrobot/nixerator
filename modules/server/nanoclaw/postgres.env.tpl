# OneCLI's PostgreSQL container environment (server.nanoclaw).
#
# TEMPLATE, placeholders only. Rendered at runtime by
# nanoclaw-onecli-env.service into /run/nanoclaw-onecli/postgres.env (0600,
# root) from the agenix-decrypted password file. See onecli.env.tpl.
#
# The password only seeds a FRESH data volume. Rotating it later needs an
# ALTER USER inside the running database first (extras/docs/nanoclaw/README.md).
POSTGRES_PASSWORD=${ONECLI_DB_PASSWORD}
