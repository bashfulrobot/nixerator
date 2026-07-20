---
name: slack-post
description: >-
  Post a Slack message via the Web API using the user's xoxc/xoxd session
  token, so the message appears as the user with NO third-party app
  attribution footer (the Slack MCP, by contrast, posts via OAuth and Slack
  appends "Sent using @Claude" under every message).

  Use when the user wants a clean, hand-authored-looking Slack post: triggers
  on `/slack-post`, "post a clean slack message", "send slack as me", "send
  slack without attribution", "DM <user> directly", "no claude footer", or
  similar. Also use whenever a customer-visible Slack message would be
  awkward with the "Sent using @Claude" tag (replies in a customer thread,
  delicate updates, anything you'd otherwise paste-and-send by hand).

  Do NOT trigger for routine internal pings where attribution is fine: the
  Slack MCP is faster for that. Channel and user lookups can still go
  through the MCP (`slack_search_channels`, `slack_search_users`); only the
  send needs to bypass it.
compatibility: >-
  Requires `slack-token-refresh` to have been run at least once on this
  machine (writes credentials to ~/.config/slack/credentials.json). Requires
  curl and jq on PATH.
---

# Slack Post (direct API, no app attribution)

Sends Slack messages via `chat.postMessage` using the same xoxc/xoxd token
the official Slack desktop client uses. From Slack's perspective the post
comes from the user's logged-in client, not a third-party app, so there is
no "Sent using @Claude" footer underneath.

## Hard rules (no exceptions)

Every outbound message MUST satisfy all four before `--send` is added.
Skipping any of these breaks the user's voice or risks an unwanted post.

### 1. Run the body through the `text-polish` skill first

Treat draft text as not-yet-ready. Invoke the `text-polish` skill on the
body to strip AI-writing tells (rule of three, vague attributions, "this
isn't just X, it's Y" parallelisms, promotional adjectives, em dashes,
etc.) and tighten it before doing anything else. text-polish runs the
humanizer de-slop pass internally, so don't also call humanizer. If the
user wrote the draft themselves and asked you to send it verbatim, still
scrub for em dashes (rule 2) but skip the rest of text-polish.

If a `writing-style` skill is also present, use it instead of `text-polish`
to match the user's voice (Dustin's casual/professional registers): it
already folds in text-polish, so running both would double-process.

### 2. Never use em dashes

The em dash character (Unicode codepoint `U+2014`) is banned in Slack
output, full stop. Replace it with one of:

- A period plus a new sentence (preferred for most cases).
- A comma, when the clauses are tightly linked.
- A colon, when introducing a list, quote, or explanation.
- Parentheses, when the content is a true aside.
- Two ASCII hyphens `--` only if the user explicitly says they want that
  style; otherwise prefer one of the above.

This applies to message bodies, code-block contents, and link labels.
Before adding `--send`, grep the rendered preview for `U+2014` and
rewrite any hits. From the shell:

```bash
grep -nP '\x{2014}' <<< "$body" && echo "REWRITE: em dashes present"
```

### 3. Convert CommonMark / GFM to Slack mrkdwn

Slack does NOT use standard markdown. The Markdown Reference section
below lists every conversion. Common gotchas:

- `**bold**` does NOT bold. Use `*bold*` (single asterisks).
- `[label](url)` does NOT link. Use `<url|label>`.
- `# Heading` does NOT render as a heading. Bold the line instead, or
  use Block Kit (out of scope for this skill).
- `~~strike~~` does NOT strike. Use `~strike~`.
- Tables and nested lists do NOT render. Restructure as plain prose or
  flat bullet lists.

### 4. Preview, then get explicit approval, then `--send`

The script defaults to PREVIEW mode. It will refuse to transmit unless
`--send` is on the command line. The workflow is:

1. Compose the draft.
2. Text-polish + scrub em dashes + convert to Slack mrkdwn.
3. Run the script WITHOUT `--send`. Show the user the rendered preview
   block (channel, workspace, author, body) verbatim in your reply.
4. Wait for the user to approve in conversation. Acceptable approvals
   are explicit: "send", "ship it", "yes send", "post it". A bare "ok",
   "sure", "looks good" is NOT enough; ask once more for explicit
   "send" before adding the flag.
5. Re-run the same command with `--send` appended.
6. The script prints the message permalink (from `chat.getPermalink`)
   on stdout. Surface that URL to the user verbatim in your reply, on
   its own line so it's clickable. If for some reason `chat.getPermalink`
   fails and the script falls back to `posted: channel=... ts=...`,
   relay that line as-is so the user has the IDs to find the post.

Exception: when DMing the user themselves with `--self` for testing
purposes (verifying the skill works, debugging mrkdwn rendering), step 4
is optional: the user is the only recipient and the message is private.
For ANY other channel or DM target, step 4 is mandatory.

## When to use this skill vs. the Slack MCP

| Goal | Use |
|---|---|
| Internal status ping, casual note, anywhere attribution is fine | Slack MCP (`slack_send_message`) |
| Customer-facing reply, delicate message, anywhere "Sent using @Claude" would be awkward | This skill (`scripts/slack-post.sh`) |
| Look up a channel or user ID | Slack MCP (`slack_search_channels`, `slack_search_users`); reads only, no message goes out |
| Read messages, threads, canvases | Slack MCP; read-only, irrelevant to attribution |

Lookups via the MCP are fine; only the **send** has to bypass the MCP to
shed the footer. Compose-then-send pattern: search via MCP, then call
this script with the resolved IDs.

## Prerequisites

Reads credentials from `~/.config/slack/credentials.json`, written by the
`slack-token-refresh` system command (Playwright-based extractor for
xoxc + xoxd from a persistent Chrome profile).

If the file is missing or `auth.test` fails, surface the error and tell
the user to run:

```bash
slack-token-refresh
# unattended re-extraction after first interactive login:
slack-token-refresh --headless
```

The token usually lives for the lifetime of the Slack browser/desktop
session. Re-running `slack-token-refresh` is cheap and idempotent.

## Usage

The bundled helper is `scripts/slack-post.sh`. From the skill directory
(`~/.claude/skills/slack-post/`), run:

```bash
# DM yourself (preview only)
bash scripts/slack-post.sh --self "test"

# DM yourself and actually send
bash scripts/slack-post.sh --self --send "test"

# Post to a channel by ID (preview only by default)
bash scripts/slack-post.sh --channel C0123456789 "release v1.2.3 is live"

# Same, but actually send
bash scripts/slack-post.sh --channel C0123456789 --send "release v1.2.3 is live"

# DM a specific user by user_id
bash scripts/slack-post.sh --channel U0123456789 --send "ping"

# Multi-line message from stdin
bash scripts/slack-post.sh --channel C0123456789 --stdin --send <<'EOF'
First line.
Second line, with *bold* and _italic_.
EOF

# Reply to a thread
bash scripts/slack-post.sh --channel C0123456789 --thread-ts 1234567890.123456 --send "follow-up"

# Specific workspace (default: first key in credentials.json)
bash scripts/slack-post.sh --workspace kongstrong --self --send "hi"
```

The script always prints a preview block to stderr. Without `--send` it
exits after the preview. With `--send` it transmits and prints the
message permalink to stdout on success.

## Resolving channel and user IDs

The script accepts only IDs:

- `C...` channels (public)
- `G...` private channels
- `D...` existing DM channels
- `U...` user IDs (Slack auto-resolves to that user's DM channel)

Use the Slack MCP to map names to IDs. These calls are reads, so they
post nothing and never trigger attribution:

- `slack_search_channels`: find a channel by name or topic
- `slack_search_users`: find a user by name or email
- `slack_read_user_profile`: detail for a known user_id

## Slack mrkdwn reference

Slack's `text` field uses `mrkdwn`, a small flavor that overlaps with but
is not the same as CommonMark or GitHub-flavored markdown. The script
posts the body as `text`, so mrkdwn rules apply.

### Inline formatting

| Effect | Slack mrkdwn | NOT this |
|---|---|---|
| Bold | `*bold*` | `**bold**` |
| Italic | `_italic_` | `*italic*` or `__italic__` |
| Strikethrough | `~strike~` | `~~strike~~` |
| Inline code | `` `code` `` | same |
| Link with label | `<https://example.com|label>` | `[label](https://example.com)` |
| Bare URL | `https://example.com` | same (auto-linked) |
| Email | `<mailto:foo@bar.com|foo>` | `[foo](mailto:foo@bar.com)` |

Bold and italic markers must be flush to the word with no internal
whitespace: `*bold*` works, `* bold *` does not. They cannot span line
breaks.

### Code blocks

Triple-backtick fenced blocks render as monospace blocks. Language hints
are accepted but ignored (no syntax highlighting in mrkdwn).

````
```
multi-line
code block
```
````

### Block quotes

`>` at the start of a line quotes that line. `>>>` on a line by itself
quotes everything that follows until the end of the message.

```
> single quoted line
normal line
```

### Lists

Bullets work with `-` or `*` at the start of a line. Numbered lists are
NOT auto-rendered: type the numbers literally. Nested lists do not
render the way they do in CommonMark; flatten or accept that nesting
just shows extra indentation as plain text.

```
- first bullet
- second bullet
- third bullet

1. typed number, not auto-numbered
2. typed number, not auto-numbered
```

### Mentions and broadcasts

| Target | Syntax |
|---|---|
| User | `<@U0123456>` |
| Channel link | `<#C0123456>` |
| Channel link with custom label | `<#C0123456|label>` |
| Everyone in channel (active and away) | `<!channel>` |
| Active members in channel | `<!here>` |
| Whole workspace (admin only in some setups) | `<!everyone>` |
| User group | `<!subteam^S0123456>` |

Resolve `U...` and `C...` IDs via the Slack MCP first; never paste a
display name and hope.

### Newlines and whitespace

Literal `\n` characters in the JSON `text` field render as line breaks.
Two consecutive newlines render as a paragraph break. Tabs render as a
single space. Trailing whitespace is trimmed.

### Special character escaping

Slack interprets `<`, `>`, and `&` as control characters when forming
`<url|label>`, `<@user>`, etc. If a message body contains literal
characters that look like one of these patterns, escape:

- `&` becomes `&amp;`
- `<` becomes `&lt;`
- `>` becomes `&gt;`

Only escape when the literal characters would otherwise be parsed as
mrkdwn control sequences. In normal prose, leave them alone; the Slack
parser handles bare punctuation correctly.

### Things that DO NOT render

- `# Heading`, `## Heading` (no headings in mrkdwn; bold the line instead)
- HTML tags
- Tables (Markdown pipe tables show as raw text; restructure as prose
  or as paired bullet lines)
- Footnotes
- Task lists `- [ ]` (renders as literal text including the brackets)
- Image embeds `![alt](url)` (use a bare URL and Slack unfurls it)
- Reference-style links `[text][1]`
- Horizontal rules `---`

For any of these, rewrite the content as prose or use Block Kit. Block
Kit is out of scope for this skill: if the user needs structured layout,
escalate by asking whether plain prose is acceptable.

## Files

```
slack-post/
|-- SKILL.md           -- this file
|-- scripts/
|   `-- slack-post.sh  -- curl wrapper around chat.postMessage
```
