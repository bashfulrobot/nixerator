# Secret half of the NanoClaw host's .env (server.nanoclaw.slack).
#
# TEMPLATE, checked into git with placeholders only. The nanoclaw unit's
# ExecStartPre renders it at runtime with envsubst, restricted to the two
# Slack placeholders, reading the values from the agenix-decrypted files via
# LoadCredential. The result is appended to the non-secret settings and
# written to /run/nanoclaw/nanoclaw.env (tmpfs, 0600, nanoclaw); dataDir/.env
# is a symlink to it. Never rendered at eval or build time.
#
# NanoClaw reads these from .env only (readEnvFile), never from the process
# environment, so they are not inherited by child processes or passed to
# agent containers. Comments here avoid the placeholder dollar syntax on
# purpose: envsubst would fill it in inside comments too.
SLACK_BOT_TOKEN=${SLACK_BOT_TOKEN}
SLACK_APP_TOKEN=${SLACK_APP_TOKEN}
