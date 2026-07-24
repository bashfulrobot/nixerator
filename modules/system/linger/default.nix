{
  lib,
  config,
  globals,
  ...
}:

{
  # Lingering keeps the primary user's systemd manager running with no login
  # session, so `systemd.user` timers are scheduled from boot rather than from
  # first login.
  #
  # No enable option and no suite gate: this is a property of the primary user,
  # true on every host that has one. Gating it behind a suite is how it went
  # missing before. The declaration lived in whichever module happened to want
  # it (claude-remote until 66ceaa0a, then noclaw until eb735f82), and each
  # retirement took it away with no failure, because NixOS only runs
  # `disable-linger` for a user set explicitly to false, never for null.
  # Already-lingering hosts kept working while a fresh install would not have
  # reproduced it.
  #
  # Workstations reach this by module auto-import. srv imports by hand, so it
  # also carries the path in hosts/srv/modules.nix.
  #
  # mkDefault so a host that schedules nothing can opt out with `linger = false`.
  #
  # Background, and the headless audit of the units this affects, is in
  # .claude/docs/user-lingering.md.
  users.users.${globals.user.name}.linger = lib.mkDefault true;

  # Do not start the user manager before home-manager has written
  # ~/.config/systemd/user, or a fresh first boot reaches timers.target with
  # nothing installed into it. sd-switch would reconcile on the next activation,
  # but first boot is the case this module exists for, so order it explicitly
  # rather than leaning on an upstream default.
  #
  # Guarded on manageLingering because that option is what defines
  # linger-users.service upstream. Without the guard, turning it off would leave
  # behind a unit built from nothing but this ordering line, with no ExecStart.
  systemd.services.linger-users = lib.mkIf config.users.manageLingering {
    after = [ "home-manager-${globals.user.name}.service" ];
  };
}
