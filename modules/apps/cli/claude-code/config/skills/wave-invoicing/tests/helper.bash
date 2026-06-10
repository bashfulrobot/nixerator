# Shared bats helper. Resolves the skill dir and provides a tmp-fixture maker.
SKILL_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
SCRIPTS="${SKILL_DIR}/scripts"

# make_tmpdir — create a per-test temp dir, exported as $TMP, removed on teardown.
make_tmpdir() { TMP="$(mktemp -d)"; }
rm_tmpdir() { [ -n "${TMP:-}" ] && rm -rf "${TMP}"; }
