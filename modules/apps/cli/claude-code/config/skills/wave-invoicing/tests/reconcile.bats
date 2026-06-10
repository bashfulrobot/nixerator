#!/usr/bin/env bats
load helper

setup() {
  make_tmpdir
  # Synthetic invoice tree: Jan + Mar billed, Feb skipped.
  mkdir -p "${TMP}/2026/01" "${TMP}/2026/02" "${TMP}/2026/03"
  : > "${TMP}/2026/01/BrMfg-Invoice_2026-01-001.pdf"
  : > "${TMP}/2026/03/BrMfg-Invoice_2026-03-001.pdf"
}
teardown() { rm_tmpdir; }

@test "reports the last billed period and sequence" {
  run "${SCRIPTS}/reconcile.sh" "${TMP}" BrMfg 2026-06
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.lastPeriod')" = "2026-03" ]
  [ "$(echo "$output" | jq -r '.lastSeq')" = "1" ]
}

@test "lists billed periods" {
  run "${SCRIPTS}/reconcile.sh" "${TMP}" BrMfg 2026-06
  [ "$(echo "$output" | jq -rc '.billedPeriods')" = '["2026-01","2026-03"]' ]
}

@test "reports unbilled month gaps up to (not including) the target period" {
  run "${SCRIPTS}/reconcile.sh" "${TMP}" BrMfg 2026-06
  # After last billed 2026-03, the gaps before 2026-06 are 04 and 05.
  [ "$(echo "$output" | jq -rc '.gaps')" = '["2026-04","2026-05"]' ]
}

@test "flags duplicate when the target period is already billed" {
  run "${SCRIPTS}/reconcile.sh" "${TMP}" BrMfg 2026-03
  [ "$(echo "$output" | jq -r '.targetAlreadyBilled')" = "true" ]
}

@test "empty tree yields null last period and seq 0" {
  run "${SCRIPTS}/reconcile.sh" "${TMP}/empty" BrMfg 2026-06
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.lastPeriod')" = "null" ]
  [ "$(echo "$output" | jq -r '.lastSeq')" = "0" ]
}

@test "lastSeq is the highest sequence in the latest period (money path)" {
  # Latest period 2026-05 has seqs 001 and 002; an earlier month has a higher
  # global seq (099) that must NOT win — lastSeq belongs to the latest period.
  mkdir -p "${TMP}/2026/04" "${TMP}/2026/05"
  : > "${TMP}/2026/04/BrMfg-Invoice_2026-04-099.pdf"
  : > "${TMP}/2026/05/BrMfg-Invoice_2026-05-001.pdf"
  : > "${TMP}/2026/05/BrMfg-Invoice_2026-05-002.pdf"
  run "${SCRIPTS}/reconcile.sh" "${TMP}" BrMfg 2026-07
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.lastPeriod')" = "2026-05" ]
  [ "$(echo "$output" | jq -r '.lastSeq')" = "2" ]
}
