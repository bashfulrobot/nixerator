{
  lib,
  config,
  ...
}:
let
  cfg = config.system.qbert-cache;
in
{
  options.system.qbert-cache = {
    enable = lib.mkEnableOption "use qbert as a binary cache (LAN first, then tailscale)";
  };

  config = lib.mkIf cfg.enable {
    nix.settings = {
      # Order matters: Nix tries substituters in list order. LAN comes first
      # so we get LAN-speed hits at home, tailscale catches the off-LAN case,
      # and the existing upstream caches (declared in modules/system/nix)
      # remain as final fallbacks.
      substituters = lib.mkBefore [
        "http://192.168.169.2:5000"
        "http://100.74.137.95:5000"
      ];

      trusted-public-keys = [
        "qbert-cache:1:/kDPYnbq9hwIi3nFvABkPF7p+qLDmBQgWDcU095oAGI="
      ];

      # Without a timeout, an offline qbert can stall the rebuild for tens of
      # seconds per substituter probe while Nix waits on the TCP connect.
      connect-timeout = 5;
    };
  };
}
