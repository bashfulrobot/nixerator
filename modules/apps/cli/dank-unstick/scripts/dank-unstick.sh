# dank-unstick: recover from Hyprland's "lockscreen died" black-screen fallback.
#
# Symptom: after unlocking, the screen stays solid black -- the monitor wakes
# on input (backlight/DPMS is fine), but nothing renders, or Hyprland shows
# literal on-screen text saying the lockscreen app died and suggesting
# `hyprctl keyword misc:allow_session_lock_restore 1`.
#
# Two distinct things can be stuck at once:
#
# 1. A stale DRM/KMS scanout: the compositor is rendering fine internally,
#    but the last frame that actually reached the physical display predates
#    the crash, so nothing new gets presented. A DPMS off/on toggle alone
#    does not clear this; a VT switch away and back forces the DRM master to
#    release and reacquire, which forces a fresh modeset.
# 2. DMS's quickshell-based lock client crashed/died while the session was
#    locked. Hyprland's ext-session-lock-v1 implementation deliberately
#    keeps compositing blocked until a live client completes a proper
#    lock -> unlock handshake -- it will not resume just because the old
#    client is gone. `systemctl --user restart dms.service` alone does NOT
#    fix this: the fresh DMS process comes back believing nothing is locked
#    (`dms ipc call lock status` already reports false) and never re-issues
#    the protocol call Hyprland is actually waiting on.
#
# Fix: kick the scanout with a VT switch, then force the handshake directly
# via DMS's own IPC surface.

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  echo "Usage: dank-unstick"
  echo
  echo "Recovers from Hyprland's black-screen lockscreen-crash fallback."
  echo "Run this over SSH when your screen stays black after unlocking."
  echo "No arguments; safe to re-run."
  exit 0
fi

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

echo "==> Kicking the DRM scanout with a VT switch (best-effort)..."
current_vt="$(cat /sys/class/tty/tty0/active 2>/dev/null | grep -o '[0-9]*' || true)"
if [[ -n "$current_vt" ]] && sudo -n true 2>/dev/null; then
  other_vt=2
  [[ "$current_vt" == "2" ]] && other_vt=1
  sudo -n chvt "$other_vt"
  sleep 1
  sudo -n chvt "$current_vt"
else
  echo "    skipped (no passwordless sudo, or couldn't detect the active VT)"
fi

echo "==> Current DMS lock status:"
dms ipc call lock status

echo "==> Forcing a lock -> unlock cycle to release Hyprland's session lock..."
dms ipc call lock lock
sleep 1
dms ipc call lock unlock
sleep 1

status_after="$(dms ipc call lock status)"
echo "==> Status after recovery attempt:"
echo "$status_after"

if echo "$status_after" | jq -e '.sessionLockLocked == false and .loginctlLocked == false' >/dev/null; then
  echo "==> Unlocked. If the screen is still black, also try: systemctl --user restart dms.service"
else
  echo "==> Still reports locked -- restarting dms.service and retrying once..."
  systemctl --user restart dms.service
  sleep 2
  dms ipc call lock lock
  sleep 1
  dms ipc call lock unlock
  sleep 1
  dms ipc call lock status
fi
