# Reduce the repo's captured plugins/installed_plugins.json to the plugins this
# host's claude-stack manifest declares, so activation seeds a per-host install
# record instead of the workstation's whole set.
#
# Why this exists. config/plugins/installed_plugins.json is captured on qbert
# (cfg/fish.nix), and cfg/activation.nix used to copy it onto every host
# verbatim. On srv that re-seeded every plugin qbert has, so the six the
# claude-skills `headless` profile declares absent and the eight nobody declares
# at all came back on the next `just remote-rebuild srv`, and drift reported
# PLUGIN_SHOULD_BE_ABSENT x6 plus PLUGIN_UNDECLARED x8 again.
#
# Arguments the caller passes:
#
#   --slurpfile keep <json array>   plugin ids this host declares with a state
#                                   other than "absent", so $keep[0] is the
#                                   array. cfg/plugin-config.nix's
#                                   overlay.enabledPlugins keys are exactly
#                                   that: enabled and disabled are both kept,
#                                   absent is already dropped by the overlay.
#
# Only runs with apps.cli.claude-code.stackApply.enable on, where the resolved
# host file comes from the locked claude-skills input. With it off activation
# keeps the plain `sed` copy, byte for byte.
#
# Fails closed. A malformed file never parses, and a file that parses to
# anything but an object raises below, so jq exits nonzero either way and the
# caller leaves whatever is already deployed in place. Seeding `{}` over a
# corrupt record would make Claude Code re-install every plugin from scratch.
#
# Lives in its own file rather than inline in cfg/activation.nix so bats runs
# the real filter instead of a copy that drifts from it. Covered by
# cfg/scripts/tests/filter-installed-plugins.bats.

# An object lookup, not `index`, so 35 declared ids do not cost a linear scan
# per record.
(($keep[0] // []) | map({ key: ., value: true }) | from_entries) as $declared
| if type != "object" then
    error("installed_plugins.json is not a JSON object")
  else
    # A record whose id this host does not declare is dropped whole. An absent
    # or null .plugins becomes {}, which is what an empty install record is.
    .plugins = ((.plugins // {}) | with_entries(select($declared[.key] // false)))
  end
