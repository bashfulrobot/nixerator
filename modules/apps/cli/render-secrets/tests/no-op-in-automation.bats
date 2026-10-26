#!/usr/bin/env bats
# Automation never depends on 1Password. Unattended code (server modules, the
# secauto-pull timer, the srv host config) may read secrets only from the gopass
# snapshot. This test fails if that code reaches for the `op` CLI, installs it, or
# touches the service-account token. Comment lines are ignored, so prose may still
# say what was replaced. `op://` strings are allowed: gopassRun maps each one to a
# gopass entry and never calls `op`.

REPO="$(cd "${BATS_TEST_DIRNAME}/../../../../.." && pwd)"

# Files that run unattended or configure an automation-only host.
automation_files() {
  {
    find "${REPO}/modules/server" -name '*.nix'
    echo "${REPO}/modules/apps/cli/secauto-pull/default.nix"
    echo "${REPO}/hosts/srv/modules.nix"
  } | sort -u
}

FORBIDDEN='_1password|1password-cli|(^|[^[:alnum:]_/-])op (run|read|inject|item|document|whoami|signin|vault)([^[:alnum:]_-]|$)|--from op|OP_SERVICE_ACCOUNT_TOKEN|service-account-token'

@test "automation files exist (the scan is not vacuous)" {
  run automation_files
  [ "${status}" -eq 0 ]
  [ "$(wc -l <<<"${output}")" -ge 3 ]
}

@test "no automation code calls op, installs it, or reads the service-account token" {
  hits=""
  while IFS= read -r f; do
    [[ -r "${f}" ]] || continue
    # Drop whole-line comments, keep the line numbers for the report.
    out="$(grep -nE "${FORBIDDEN}" "${f}" | grep -vE '^[0-9]+:[[:space:]]*#' || true)"
    [[ -z "${out}" ]] || hits+="${f#"${REPO}"/}:"$'\n'"${out}"$'\n'
  done < <(automation_files)
  if [[ -n "${hits}" ]]; then
    echo "automation code depends on 1Password (use gopass instead):"
    echo "${hits}"
    return 1
  fi
}

@test "secauto-pull renders from gopass explicitly" {
  grep -q 'render-secrets --from gopass' "${REPO}/modules/apps/cli/secauto-pull/default.nix"
}
