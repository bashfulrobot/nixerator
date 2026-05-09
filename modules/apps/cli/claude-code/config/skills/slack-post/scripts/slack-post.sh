#!/usr/bin/env bash
# Post a Slack message via the Web API using the user's xoxc/xoxd session
# token. Messages appear as the user with no third-party app attribution
# footer (unlike the Slack MCP, which posts via an OAuth-authorized app and
# Slack appends "Sent using @Claude" underneath every message).
#
# SAFETY: The default mode is PREVIEW. The script never transmits unless
# `--send` is passed explicitly. This is intentional -- never bypass it
# without the user's in-conversation approval of the rendered preview.
#
# Reads creds from $SLACK_CREDENTIALS_FILE (default:
# $XDG_CONFIG_HOME/slack/credentials.json) -- the file written by
# `slack-token-refresh`.
#
# Usage:
#   slack-post.sh --channel <id> [--workspace <name>] [--thread-ts <ts>]
#                 [--send] (--stdin | "message text")
#   slack-post.sh --self [--workspace <name>] [--send]
#                 (--stdin | "message text")
#
#   --self        DM yourself (resolves your user_id via auth.test).
#   --channel     Channel ID (C..., D..., G...) or user ID (U...) for DM.
#   --workspace   Workspace key in credentials.json (default: first one).
#   --thread-ts   Reply to a thread by parent message ts.
#   --stdin       Read message body from stdin (use for multi-line content).
#   --send        Actually transmit. Without it, the script only previews.

set -euo pipefail

CREDS_FILE="${SLACK_CREDENTIALS_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/slack/credentials.json}"
SLACK_API="https://slack.com/api"

die() {
  echo "ERROR: $*" >&2
  exit 1
}
usage() { sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; }

[[ -f "$CREDS_FILE" ]] || die "no slack credentials at $CREDS_FILE -- run 'slack-token-refresh'"

channel=""
workspace=""
thread_ts=""
self=""
read_stdin=""
send=""
message=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --channel)
      channel="$2"
      shift 2
      ;;
    --workspace)
      workspace="$2"
      shift 2
      ;;
    --thread-ts)
      thread_ts="$2"
      shift 2
      ;;
    --self)
      self=1
      shift
      ;;
    --stdin)
      read_stdin=1
      shift
      ;;
    --send)
      send=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*) die "unknown flag: $1" ;;
    *)
      message="$1"
      shift
      break
      ;;
  esac
done

if [[ -z "$workspace" ]]; then
  workspace=$(jq -r '.workspaces | keys[0] // empty' "$CREDS_FILE")
  [[ -n "$workspace" ]] || die "no workspaces in $CREDS_FILE"
fi
xoxc=$(jq -r --arg ws "$workspace" '.workspaces[$ws].xoxc // empty' "$CREDS_FILE")
xoxd=$(jq -r --arg ws "$workspace" '.workspaces[$ws].xoxd // empty' "$CREDS_FILE")
[[ -n "$xoxc" && -n "$xoxd" ]] || die "no xoxc/xoxd for workspace '$workspace' -- run 'slack-token-refresh'"

auth=$(curl -sS "$SLACK_API/auth.test" \
  -H "Authorization: Bearer $xoxc" \
  -H "Cookie: d=$xoxd")
ok=$(echo "$auth" | jq -r '.ok')
if [[ "$ok" != "true" ]]; then
  err=$(echo "$auth" | jq -r '.error // "unknown_error"')
  die "auth.test failed: $err -- token may be expired (run 'slack-token-refresh')"
fi
auth_user=$(echo "$auth" | jq -r '.user')
auth_user_id=$(echo "$auth" | jq -r '.user_id')
auth_team=$(echo "$auth" | jq -r '.team')

if [[ -n "$self" ]]; then
  channel="$auth_user_id"
fi

[[ -n "$channel" ]] || die "missing --channel <id> (or --self)"

if [[ -n "$read_stdin" ]]; then
  message=$(cat)
fi
[[ -n "$message" ]] || die "no message body -- pass as positional arg or use --stdin"

# Always render the preview, regardless of --send.
{
  echo "============================================================"
  echo "Slack post preview"
  echo "============================================================"
  echo "Workspace : $workspace ($auth_team)"
  echo "Author    : $auth_user ($auth_user_id)"
  echo "Channel   : $channel"
  [[ -n "$thread_ts" ]] && echo "Thread ts : $thread_ts"
  echo "------------------------------------------------------------"
  echo "$message"
  echo "------------------------------------------------------------"
} >&2

if [[ -z "$send" ]]; then
  echo "PREVIEW ONLY -- pass --send to transmit." >&2
  exit 0
fi

payload=$(jq -n \
  --arg channel "$channel" \
  --arg text "$message" \
  --arg thread_ts "$thread_ts" \
  '{channel: $channel, text: $text}
   + (if $thread_ts == "" then {} else {thread_ts: $thread_ts} end)')

resp=$(curl -sS "$SLACK_API/chat.postMessage" \
  -H "Authorization: Bearer $xoxc" \
  -H "Cookie: d=$xoxd" \
  -H "Content-Type: application/json; charset=utf-8" \
  --data "$payload")

ok=$(echo "$resp" | jq -r '.ok')
if [[ "$ok" != "true" ]]; then
  err=$(echo "$resp" | jq -r '.error // "unknown_error"')
  die "Slack API error: $err"
fi

ts=$(echo "$resp" | jq -r '.ts')
ch=$(echo "$resp" | jq -r '.channel')

permalink=$(curl -sS "$SLACK_API/chat.getPermalink?channel=$ch&message_ts=$ts" \
  -H "Authorization: Bearer $xoxc" \
  -H "Cookie: d=$xoxd" |
  jq -r '.permalink // empty')

if [[ -n "$permalink" ]]; then
  echo "$permalink"
else
  echo "posted: channel=$ch ts=$ts"
fi
