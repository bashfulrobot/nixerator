#!/usr/bin/env bats
load helper

@test "number formats YYYY-MM-NNN with zero-padded sequence" {
  run "${SCRIPTS}/naming.sh" number 2026-03 1
  [ "$status" -eq 0 ]
  [ "$output" = "2026-03-001" ]
}

@test "files emits invoice pdf, zip, and folder derived from issuer+number" {
  run "${SCRIPTS}/naming.sh" files BrMfg 2026-03 1
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.invoicePdf')" = "BrMfg-Invoice_2026-03-001.pdf" ]
  [ "$(echo "$output" | jq -r '.zip')" = "2026-03-BrMfg.zip" ]
  [ "$(echo "$output" | jq -r '.folder')" = "2026/03" ]
  [ "$(echo "$output" | jq -r '.number')" = "2026-03-001" ]
}

@test "files maps vendor codes to renamed evidence filenames" {
  run "${SCRIPTS}/naming.sh" files BrMfg 2026-03 1 DO GH
  [ "$(echo "$output" | jq -rc '.evidence')" = '["2026-03-DO","2026-03-GH"]' ]
}

@test "number rejects a non-numeric sequence" {
  run "${SCRIPTS}/naming.sh" number 2026-03 x
  [ "$status" -ne 0 ]
}
