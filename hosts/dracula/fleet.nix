# Dracula is the fleet's deploy host: it installs and deploys customer servers, signs
# their Tailnet Lock join keys and runs the release gate. Alucard serves the internet,
# so it holds none of these credentials. The fleet's helpers read them from here.
{
  config,
  pkgs,
  username,
  ...
}:
{
  sops.secrets = builtins.listToAttrs (
    map
      (name: {
        name = "fleet/${name}";
        value = {
          sopsFile = ../../secrets/fleet.yaml;
          owner = username;
          mode = "0400";
        };
      })
      [
        "tailscale_oauth"
        "hetzner_token"
        "github_release_token"
        "telegram_bot_token"
      ]
  );

  # `tailscale lock sign` for customer join keys runs without root.
  services.tailscale.extraSetFlags = [ "--operator=${username}" ];

  # Weekly release gate (Sunday evening, before Monday's Release updates PR): tags the
  # canary's revisions when they pass. Persistent, because the desktop may be off.
  systemd.services.release-gate = {
    description = "Release gate for ai-stack and ai-library";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [
      config.nix.package
      pkgs.git
      pkgs.openssh
      # The staging run signs its join key with this node's Tailnet Lock key.
      config.services.tailscale.package
    ];
    serviceConfig = {
      Type = "oneshot";
      User = username;
      WorkingDirectory = "/home/${username}/code/fleet";
      ExecStartPre = "${pkgs.git}/bin/git pull --ff-only -q";
      ExecStart = "${config.nix.package}/bin/nix develop --command bin/release-gate";
      TimeoutStartSec = "3h";
    };
  };
  systemd.timers.release-gate = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun 20:00";
      Persistent = true;
    };
  };
}
