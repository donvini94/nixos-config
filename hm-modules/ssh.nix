{ lib, ... }:

{
  home.activation.ensureSshControlDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p $HOME/.ssh/sockets
    chmod 700 $HOME/.ssh/sockets
  '';

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        controlMaster = "auto";
        controlPath = "~/.ssh/sockets/%r@%h-%p";
        controlPersist = "600";
      };
      "github.com" = {
        hostname = "ssh.github.com";
        port = 443;
      };
      "Bereitserver" = {
        hostname = "dumusstbereitsein.de";
        user = "vincenzo";
      };
      "media-admin" = {
        hostname = "dumusstbereitsein.de";
        user = "vincenzo";
        localForwards = [
          { bind.port = 18989; host.address = "localhost"; host.port = 18989; }
          { bind.port = 18080; host.address = "localhost"; host.port = 18080; }
          { bind.port = 19696; host.address = "localhost"; host.port = 19696; }
          { bind.port = 17878; host.address = "localhost"; host.port = 17878; }
          { bind.port = 16767; host.address = "localhost"; host.port = 16767; }
          { bind.port = 19090; host.address = "localhost"; host.port = 19090; }
        ];
        extraOptions = {
          SetEnv = "TERM=xterm";
        };
      };
    };
  };
}
