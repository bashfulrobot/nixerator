# Nixerator

Use GrayMatter for all project context. Search agent `nixerator` before reading files. Store new learnings via `memory_add` or `memory_reflect`. Reference docs live under `extras/docs/` if you need to verify anything.

## Rebuild Mode Selection

Three quiet rebuild recipes; pick by activation safety, not by habit:

- `just qr` (quiet-rebuild) -- default for development. Builds and live-switches the generation. Safe when changes don't touch PID 1, dbus, init, or the running kernel.
- `just qu` (quiet-upgrade) -- only when the user asks for an upgrade. Updates flake inputs first, then live-switches. Same activation constraints as `qr`.
- `just qb` (quiet-boot) -- builds the new generation and sets it as next-boot default WITHOUT live-switching. Use when `qr`/`qu` fails activation with `switchInhibitors` / `Switching into this system is not recommended` (dbus-broker swap, init system change, kernel-ABI-affecting change, systemd major version bumps). After `qb` succeeds, surface the reboot requirement to the user; do not reboot on their behalf.

If `qr` or `qu` fails at the activation step (build succeeded, switch refused), retry with `qb` rather than forcing the switch.

## TODO Review

When asked to review TODOs, or when starting a maintenance pass, run `rg -n 'TODO\(' --hidden -g '!flake.lock'` and walk each hit. For each one: read the surrounding comment, check if the documented removal/verification condition is met (e.g. "remove once upstream ships X"), and report findings as a punch list — keep / act now / superseded. Never silently delete a TODO; surface it to the user with the suggested action.
