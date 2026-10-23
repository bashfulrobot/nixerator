#!/bin/bash
# Raycast Script Command: find a note and open it in Typora.
# Install: Raycast > Settings > Extensions > Script Commands > Add Directory,
# and pick the directory holding this file.
#
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Find Note
# @raycast.mode silent
#
# Optional parameters:
# @raycast.icon 📝
# @raycast.packageName Notes
# @raycast.argument1 { "type": "text", "placeholder": "Search text (optional)", "optional": true }
#
# Needs: zk, choose (brew install zk choose-gui), the notes scripts on PATH
# (see the macOS checklist in extras/docs/notes.md).

# Raycast starts scripts with a minimal PATH.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

exec notes -l "$1"
