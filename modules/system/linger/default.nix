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
  # mkDefault so a host that schedules nothing can opt out with
  # `linger = false`. Note that `false` is not the same as unmanaged: it runs
  # `loginctl disable-linger`, stripping the on-disk flag even if something
  # else set it. To leave the user alone entirely, force it back to null.
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
  # linger-users.service upstream. Without the guard, a host with lingering
  # unmanaged would be left a unit built from nothing but this ordering line,
  # with no ExecStart.
  #
  # Reaching that state takes two steps, not one. users-groups.nix asserts
  # `user.linger != null -> cfg.manageLingering`, so setting
  # `users.manageLingering = false` on its own is now a hard eval failure while
  # this module is imported. Turning lingering off means
  # `users.users.<name>.linger = lib.mkForce null` alongside it, and that pair
  # is the case this guard covers. lib/mkHost.nix's reachability assertion is
  # gated on the same option, so the pair evaluates rather than tripping the
  # assertion that exists to catch a *missing* import.
  systemd.services.linger-users = lib.mkIf config.users.manageLingering {
    after = [ "home-manager-${globals.user.name}.service" ];
  };
}
