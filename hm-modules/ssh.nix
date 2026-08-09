{ lib, ... }:

{
  home.activation.ensureSshControlDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p $HOME/.ssh/sockets
    chmod 700 $HOME/.ssh/sockets
  '';

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        ControlMaster = "auto";
        ControlPath = "~/.ssh/sockets/%r@%h-%p";
        ControlPersist = "600";
      };
      "github.com" = {
        HostName = "ssh.github.com";
        Port = 443;
      };
      Bereitserver = {
        HostName = "dumusstbereitsein.de";
        User = "vincenzo";
      };
      # Private AI administration tunnel. The local ports deliberately differ
      # from Dracula's own AI stack so both machines can be inspected at once.
      # Start it with `ssh -N ai-admin` and stop it with Ctrl-C.
      ai-admin = {
        HostName = "dumusstbereitsein.de";
        User = "vincenzo";
        ExitOnForwardFailure = "yes";
        ServerAliveInterval = 30;
        ServerAliveCountMax = 3;
        LocalForward = [
          {
            bind.port = 25678;
            host.address = "localhost";
            host.port = 5678;
          }
          {
            bind.port = 28080;
            host.address = "localhost";
            host.port = 8080;
          }
          {
            bind.port = 29119;
            host.address = "localhost";
            host.port = 9119;
          }
          {
            bind.port = 23000;
            host.address = "localhost";
            host.port = 13000;
          }
          {
            bind.port = 23001;
            host.address = "localhost";
            host.port = 13001;
          }
          {
            bind.port = 28790;
            host.address = "localhost";
            host.port = 18790;
          }
          {
            bind.port = 29091;
            host.address = "localhost";
            host.port = 19091;
          }
        ];
      };
      # Same host as Bereitserver, but carries the *arr-stack admin port-forwards.
      # The `bereit` zellij layout routes its lazydocker pane through this alias
      # so opening that session also binds the arr ports (one forwarding
      # connection; the other panes use plain Bereitserver over the shared
      # ControlMaster). TERM=xterm is conservative; the layout overrides it to
      # xterm-256color per-command where colour matters.
      media-admin = {
        HostName = "dumusstbereitsein.de";
        User = "vincenzo";
        LocalForward = [
          {
            bind.port = 18989;
            host.address = "localhost";
            host.port = 18989;
          }
          {
            bind.port = 18080;
            host.address = "localhost";
            host.port = 18080;
          }
          {
            bind.port = 19696;
            host.address = "localhost";
            host.port = 19696;
          }
          {
            bind.port = 17878;
            host.address = "localhost";
            host.port = 17878;
          }
          {
            bind.port = 16767;
            host.address = "localhost";
            host.port = 16767;
          }
          {
            bind.port = 19090;
            host.address = "localhost";
            host.port = 19090;
          }
        ];
        SetEnv = {
          TERM = "xterm";
        };
      };

      # Work host — used by the `work` zellij layout (zellij -l work). Currently
      # only reached from the Mac; fill in HostName/User (mirror the Mac's
      # ~/.ssh) and uncomment to enable acGPT sessions from NixOS.
      # acGPT = {
      #   HostName = "...";
      #   User = "...";
      # };
    };
  };
}
