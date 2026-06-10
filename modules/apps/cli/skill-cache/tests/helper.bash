# Shared bats helper for skill-cache. Resolves the script and runs it against a
# per-test temp XDG_CACHE_HOME so tests never touch the real cache.
TESTS_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
SCRIPT="$(cd "${TESTS_DIR}/.." && pwd)/scripts/skill-cache.sh"

setup_xdg() { XDG="$(mktemp -d)"; }
rm_xdg() { [ -n "${XDG:-}" ] && rm -rf "${XDG}"; }

# sc — run the script with the test's isolated cache home.
sc() { XDG_CACHE_HOME="${XDG}" bash "${SCRIPT}" "$@"; }
