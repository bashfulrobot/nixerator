#!/usr/bin/env bash
# Regression tests for text-polish.sh's sanitize_output(), the last line of
# defence that stops model chatter from being pasted into a live field.
# Run directly: bash text-polish.test.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the filter as a library (defines functions, does not run main).
TEXT_POLISH_LIB=1 source "$here/text-polish.sh"
set +eo pipefail # the sourced script enables errexit; disable for negative cases

pass=0
fail=0
check() { # name expected_rc expected_out actual_rc actual_out
  if [ "$4" = "$2" ] && [ "$5" = "$3" ]; then
    echo "PASS: $1"
    pass=$((pass + 1))
  else
    echo "FAIL: $1 (rc want=$2 got=$4 | out want=[$3] got=[$5])"
    fail=$((fail + 1))
  fi
}

# 1. The real incident: the model's deliberation about the humanizer skill
# landed before the markers. It must be stripped, leaving only the rewrite.
raw1='Rerun the humanizer skill? No, that is for prose I am presenting. This is a text-rewriting filter task with strict output rules. I output only the rewrite.
%%%TEXTPOLISH_BEGIN%%%
Hi Bryan, hope you are well. I wanted your take on where we store secrets.
%%%TEXTPOLISH_END%%%'
out1=$(printf '%s' "$raw1" | sanitize_output)
check "leak before markers is stripped" 0 \
  "Hi Bryan, hope you are well. I wanted your take on where we store secrets." \
  "$?" "$out1"

# 2. No markers at all (an older-style bare response): fail closed, paste nothing.
raw2='Hi Bryan. This is a text-rewriting filter task. Would you be open to a meeting?'
out2=$(printf '%s' "$raw2" | sanitize_output)
check "no markers fails closed" 1 "" "$?" "$out2"

# 3. Self-referential leak inside the markers: the tripwire drops it.
raw3='%%%TEXTPOLISH_BEGIN%%%
As an AI, I cannot rewrite this.
%%%TEXTPOLISH_END%%%'
out3=$(printf '%s' "$raw3" | sanitize_output)
check "leak inside markers trips wire" 2 "" "$?" "$out3"

# 4. A clean, well-formed response passes through unchanged.
raw4='%%%TEXTPOLISH_BEGIN%%%
Can you meet next week?
%%%TEXTPOLISH_END%%%'
out4=$(printf '%s' "$raw4" | sanitize_output)
check "clean response passes" 0 "Can you meet next week?" "$?" "$out4"

# 5. A legitimate email that happens to mention "humanizer skill" and "system
# prompt" must NOT be rejected: the tripwire only catches first-person process
# narration, not the topic.
raw5='%%%TEXTPOLISH_BEGIN%%%
We should discuss the humanizer skill and the system prompt in our next review.
%%%TEXTPOLISH_END%%%'
out5=$(printf '%s' "$raw5" | sanitize_output)
check "legit topic mention is not rejected" 0 \
  "We should discuss the humanizer skill and the system prompt in our next review." \
  "$?" "$out5"

echo "---"
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
