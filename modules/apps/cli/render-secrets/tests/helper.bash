# Shared bats helper for render-secrets' Forgejo tea-config generation.
# Sources render-secrets.sh for its functions only (RENDER_SECRETS_SOURCE_ONLY)
# in a fresh subshell rooted at a per-test temp HOME, so tests never touch the
# real ~/.config/tea and the script's `set -euo pipefail` can't leak into bats.
TESTS_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
SCRIPT="$(cd "${TESTS_DIR}/.." && pwd)/render-secrets.sh"

setup_home() { THOME="$(mktemp -d)"; }
rm_home() { [ -n "${THOME:-}" ] && rm -rf "${THOME}"; }

# tea_gen SECRETS_FILE — run render_forgejo_tea_config against SECRETS_FILE with
# HOME pointed at the test dir. Returns the function's status; writes config to
# ${THOME}/.config/tea/config.yml when the token is present.
tea_gen() {
  HOME="${THOME}" RENDER_SECRETS_SOURCE_ONLY=1 bash -c '
    source "'"${SCRIPT}"'"
    render_forgejo_tea_config "$1"
  ' _ "$1"
}
