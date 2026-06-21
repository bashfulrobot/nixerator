{
  globals,
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.system.ssh;
in
{
  options = {
    system.ssh.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable OpenSSH server and client with predefined host configurations.";
    };
  };

  config = lib.mkIf cfg.enable {

    # Enable OpenSSH server
    services.openssh.enable = true;

    # Mosh: a roaming remote shell offered ALONGSIDE SSH, not replacing it. It
    # does the initial handshake over OpenSSH (above) and then runs the session
    # over UDP, so it survives IP changes, suspend/resume, and flaky links.
    # programs.mosh installs the package and opens UDP 60000-61000 by default.
    programs.mosh.enable = true;

    # Authorize key-based login for the primary user. With Tailscale SSH
    # retired (issue #107), regular OpenSSH is the only SSH path, so the login
    # key must be declared here -- otherwise the only way in is password auth.
    # Password auth stays enabled as a fallback; disable it once key login is
    # verified on every host.
    users.users.${globals.user.name}.openssh.authorizedKeys.keys = globals.user.sshAuthorizedKeys;

    # Remote-agent interpreter for SSH-driven tools. `fresh` (and similar
    # python-over-ssh agents) pipe a bootstrap script into `python3` on the
    # remote side and fail with "python3 was not found on the remote host"
    # if the interpreter is absent. Lives here rather than in suites.core so
    # it reaches every SSH-enabled host -- including srv, which uses the
    # claudeWorkHost archetype and never enables suites.core.
    environment.systemPackages = [ pkgs.python3 ];

    # Add non-ETM MACs so iOS swift-nio-ssh clients (Echo) can negotiate; AEAD ciphers ignore the MAC anyway.
    services.openssh.settings.Macs = [
      "hmac-sha2-512-etm@openssh.com"
      "hmac-sha2-256-etm@openssh.com"
      "umac-128-etm@openssh.com"
      "hmac-sha2-512"
      "hmac-sha2-256"
      "umac-128@openssh.com"
    ];

    # Home Manager SSH client configuration
    home-manager.users.${globals.user.name} = {

      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;

        settings = {
          # Global defaults
          "*" = {
            ForwardAgent = false;
            AddKeysToAgent = "yes";
            Compression = false;
            ServerAliveInterval = 60;
            ServerAliveCountMax = 3;
            HashKnownHosts = false;
            UserKnownHostsFile = "~/.ssh/known_hosts";
            ControlMaster = "auto";
            ControlPath = "~/.ssh/master-%r@%n:%p";
            ControlPersist = "600";
            IdentitiesOnly = true;
            IgnoreUnknown = "UseKeychain";
            UseKeychain = "yes";
          };

          # Camino Config
          "camino" = {
            HostName = "64.225.50.102";
            User = "root";
          };

          # Ubuntu Budgie Config
          "budgie" = {
            HostName = "ubuntubudgie.org";
            User = globals.user.name;
          };

          # Feral Config
          "feral" = {
            HostName = "prometheus.feralhosting.com";
            User = "msgedme";
          };

          # Git Config
          "github.com" = {
            HostName = "github.com";
            IdentityFile = "~/.ssh/id_ed25519";
            User = "git";
          };

          "bitbucket.org" = {
            HostName = "bitbucket.org";
            IdentityFile = "~/.ssh/id_ed25519";
            User = "git";
          };

          "git.srvrs.co" = {
            HostName = "git.srvrs.co";
            IdentityFile = "~/.ssh/id_ed25519";
            User = "git";
          };

          # Home Config
          # ForwardAgent is enabled on these LAN-only NixOS hosts so the
          # `just remote-rebuild <host>` workflow can `git pull` using
          # the SSH agent loaded on the calling host (e.g. srv's
          # keychain). Risk is scoped: agent is only proxied during an
          # active SSH session to these specific hosts; root on the
          # remote could use the agent during that window. Acceptable
          # for personal home-network boxes; revisit if any of these
          # ever host less-trusted workloads.
          "qbert" = {
            HostName = "192.168.169.2";
            User = globals.user.name;
            IdentityFile = "~/.ssh/id_ed25519";
            ForwardAgent = true;
          };

          "srv" = {
            HostName = "192.168.168.1";
            User = globals.user.name;
            IdentityFile = "~/.ssh/id_ed25519";
            ForwardAgent = true;
          };

          "dk" = {
            HostName = "192.168.169.3";
            User = globals.user.name;
            IdentityFile = "~/.ssh/id_ed25519";
            ForwardAgent = true;
          };

          # TF/KVM Config
          "192.168.168.1" = {
            HostName = "192.168.168.1";
            User = globals.user.name;
            Port = 22;
            CheckHostIP = false;
            StrictHostKeyChecking = "no";
            UserKnownHostsFile = "/dev/null";
          };
        };
      };
    };
  };
}
