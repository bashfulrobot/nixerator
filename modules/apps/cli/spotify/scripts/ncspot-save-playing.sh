#!/usr/bin/env bash

NCSPOT_SOCK="/run/user/1000/ncspot/ncspot.sock"

# Get track info before saving (the save command doesn't return track data)
response=$(nc -W 1 -U "$NCSPOT_SOCK")
title=$(echo "$response" | jq -r '.playable.title // empty')
artist=$(echo "$response" | jq -r '.playable.artists[0] // empty')
cover_url=$(echo "$response" | jq -r '.playable.cover_url // empty')

# Save the currently playing song
echo "save" | nc -W 1 -U "$NCSPOT_SOCK"

# Download album art if available
cover_path="/tmp/ncspot_album_cover.jpg"
if [[ -n "$cover_url" ]]; then
  curl -s -o "$cover_path" "$cover_url"
  notify-send --app-name="NCSPOT" -i "$cover_path" "Song Saved" "$title - $artist"
else
  notify-send --app-name="NCSPOT" "Song Saved" "$title - $artist"
fi
