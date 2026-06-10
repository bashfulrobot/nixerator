#!/usr/bin/env bats
load helper

setup() { setup_xdg; }
teardown() { rm_xdg; }

@test "put then get round-trips an identity value" {
  sc put todoist projects "Road Map" '{"id":"123"}'
  run sc get todoist projects "road map"
  [ "$status" -eq 0 ]
  [ "$output" = '{"id":"123"}' ]
}

@test "get on a missing key exits 3" {
  run sc get todoist projects nope
  [ "$status" -eq 3 ]
}

@test "lookup is case- and whitespace-insensitive" {
  sc put aha customers "Acme Corp" '{"portal":"PROD"}'
  run sc get aha customers "  acme   corp "
  [ "$status" -eq 0 ]
  [ "$output" = '{"portal":"PROD"}' ]
}

@test "alias resolves to the same entry" {
  sc put aha customers acme-corp '{"portal":"PROD"}' --alias "Acme" --alias "ACME Corporation"
  run sc get aha customers "acme corporation"
  [ "$status" -eq 0 ]
  [ "$output" = '{"portal":"PROD"}' ]
}

@test "identity entry is stored with null expiry (listed as identity)" {
  sc put aha customers acme '{"portal":"PROD"}'
  run sc list aha customers
  [ "$status" -eq 0 ]
  [[ "$output" == *"acme"* ]]
  [[ "$output" == *"identity"* ]]
}

@test "expired metadata entry exits 4; --allow-stale returns it" {
  sc put aha customers acme '{"portal":"PROD"}' --ttl 1d
  f="$(sc path aha)"
  tmp="$(mktemp)"
  jq '.tables.customers.acme.expires_at = "2000-01-01T00:00:00Z"' "$f" > "$tmp"
  mv "$tmp" "$f"
  run sc get aha customers acme
  [ "$status" -eq 4 ]
  run sc get aha customers acme --allow-stale
  [ "$status" -eq 0 ]
  [ "$output" = '{"portal":"PROD"}' ]
}

@test "metadata entry within TTL is fresh" {
  sc put aha customers acme '{"portal":"PROD"}' --ttl 30d
  run sc get aha customers acme
  [ "$status" -eq 0 ]
  [ "$output" = '{"portal":"PROD"}' ]
}

@test "forget a key removes it" {
  sc put todoist projects work '{"id":"1"}'
  sc forget todoist projects work
  run sc get todoist projects work
  [ "$status" -eq 3 ]
}

@test "forget a whole table removes all its keys" {
  sc put todoist projects work '{"id":"1"}'
  sc put todoist projects home '{"id":"2"}'
  sc forget todoist projects
  run sc get todoist projects work
  [ "$status" -eq 3 ]
  run sc get todoist projects home
  [ "$status" -eq 3 ]
}

@test "put rejects an invalid JSON value" {
  run sc put todoist projects work 'not-json'
  [ "$status" -eq 2 ]
}

@test "a corrupt cache file is treated as a miss, not an error" {
  mkdir -p "${XDG}/claude-skills"
  printf 'garbage{' > "${XDG}/claude-skills/aha.json"
  run sc get aha customers acme
  [ "$status" -eq 3 ]
}

@test "path prints the per-skill cache file location" {
  run sc path aha
  [ "$status" -eq 0 ]
  [ "$output" = "${XDG}/claude-skills/aha.json" ]
}

@test "bad --ttl is rejected" {
  run sc put aha customers acme '{"x":1}' --ttl 5x
  [ "$status" -eq 2 ]
}
