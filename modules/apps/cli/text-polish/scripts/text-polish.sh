#!/usr/bin/env bash
set -euo pipefail

# Tool paths are substituted by Nix
WL_PASTE="@wl_paste@"
WL_COPY="@wl_copy@"
NOTIFY="@notify_send@"

NOTIFY_TAG="text-polish"

notify() {
  "$NOTIFY" "Text Polish" "$1" --icon=accessories-text-editor \
    --hint=string:x-dunst-stack-tag:"$NOTIFY_TAG" 2>/dev/null || true
}

notify_error() {
  "$NOTIFY" "Text Polish" "$1" --icon=dialog-error \
    --hint=string:x-dunst-stack-tag:"$NOTIFY_TAG" 2>/dev/null || true
}

# 1. Grab text: primary selection first, then clipboard
input=""
input=$("$WL_PASTE" --primary --no-newline 2>/dev/null) || true
if [ -z "$input" ]; then
  input=$("$WL_PASTE" --no-newline 2>/dev/null) || true
fi

if [ -z "$input" ]; then
  notify_error "No text selected or on clipboard"
  exit 1
fi

# Guard against huge text
char_count=${#input}
if [ "$char_count" -gt 10000 ]; then
  notify_error "Text too long (${char_count} chars, max 10000)"
  exit 1
fi

notify "Polishing ${char_count} characters..."

# 2. Build prompt and send to Claude
read -r -d '' PROMPT <<'PROMPT_END' || true
Rewrite the following text. Say the same thing in as few words as possible. Output ONLY the rewritten text, nothing else — no preamble, no explanation, no quotes around it.

Rules:
- Be ruthlessly concise — cut every unnecessary word, merge redundant sentences, eliminate fluff
- Fix grammar and spelling errors
- Preserve the original tone (casual stays casual, formal stays formal, technical stays technical)
- Preserve the original meaning, but use fewer words to express it
- Preserve the original language (do not translate)
- If the input is casual or short (like a chat message), keep the output casual and short
- When the text contains multiple questions or action items (especially technical or business ones), extract them into bullet points
- Preserve any existing formatting: markdown headings, bold, italic, code blocks, links. Do not add or remove formatting unless restructuring into bullet points
- Never modify URLs or links — pass them through exactly as-is
- Never modify code blocks, inline code, or code snippets — pass them through exactly as-is
- Never alter names, product names, or technical terms
- Never modify quoted text — pass quotations through verbatim

Conciseness rules:
- Delete filler words and hedging: really, very, just, quite, rather, somewhat, basically, actually, literally, I think, I believe (keep hedging only when expressing genuine uncertainty)
- Replace adverbs with stronger verbs ("walked quickly" -> "hurried")
- Replace wordy phrases with single words ("due to the fact that" -> "because", "in the event that" -> "if", "it is necessary that" -> "must", "for the purpose of" -> "to", "to be able to" -> "can")
- Cut redundancy — pairs ("full and complete" -> "complete"), implied modifiers ("completely revolutionize" -> "revolutionize"), and repeated points across sentences
- Reduce prepositional phrases ("the behavior of the system" -> "the system's behavior")
- Convert negatives to affirmatives ("did not remember" -> "forgot")
- Use active voice ("the report was written by me" -> "I wrote the report")
- Prefer short common words ("utilize" -> "use", "commence" -> "start")
- Start with the point — delete weak introductions and throat-clearing
- Vary sentence length but average 14-18 words. No sentence over two clauses. Prefer periods over semicolons for distinct thoughts
- Use parallel structure in lists and comparisons. Fix dangling modifiers and misplaced "only"

Anti-slop rules (apply to prose paragraphs only, not to bullet points or lists):
- Never use: additionally, crucial, delve, enhance, foster, landscape, pivotal, showcase, testament, underscore, vibrant, tapestry, intricate, garner, enduring, groundbreaking, nestled, renowned, seamless
- Use simple verbs: "is" not "serves as", "has" not "boasts"
- Never use em dashes (—) or en dashes (–) — replace with commas, periods, or colons
- No rule-of-three patterns, no negative parallelisms ("not just X, but Y"), no significance inflation
- No promotional or sycophantic language

Text to rewrite:
PROMPT_END

output=$(printf '%s\n\n%s' "$PROMPT" "$input" | claude -p 2>/dev/null) || {
  notify_error "Claude failed — check API key or network"
  exit 1
}

if [ -z "$output" ]; then
  notify_error "Claude returned empty output"
  exit 1
fi

# 3. Put result on clipboard
printf '%s' "$output" | "$WL_COPY"

# 4. Notify success with preview
preview="${output:0:120}"
if [ ${#output} -gt 120 ]; then
  preview="${preview}..."
fi
notify "Copied to clipboard
${preview}"
