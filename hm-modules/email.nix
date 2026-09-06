{ config, lib, pkgs, ... }:

# NixOS deployment of the notmuch email pipeline. The files of truth live in ../mail/;
# this module installs them under $HOME, rewrites macOS paths for Linux, and replicates
# the macOS launchd jobs as systemd user timers.
#
# The `Work` block in ~/.mbsyncrc and ~/.msmtprc stays commented out here, and mail-sync's
# customer/leadership tag rules are gated on `[ -d ~/Maildir/work ]`, so no conditional is
# needed in the nix.

let
  mailDir  = ../mail;
  scripts  = "${mailDir}/bin";
  configs  = "${mailDir}/config";
in
{
  home.packages = with pkgs; [
    notmuch
    isync       # provides `mbsync`
    msmtp
    jq          # used by notmuch-compute-state + notmuch-emit-followups
    gnupg       # mbsync PassCmd shells out to gpg to decrypt ~/.authinfo.gpg
  ];

  # Symlinked into the nix store, but the scripts use only $HOME paths internally, so the
  # same ~/.local/bin PATH that works on macOS works here.
  home.file.".local/bin/mail-sync"             = { source = "${scripts}/mail-sync";             executable = true; };
  home.file.".local/bin/notmuch-compute-state" = { source = "${scripts}/notmuch-compute-state"; executable = true; };
  home.file.".local/bin/notmuch-emit-followups"= { source = "${scripts}/notmuch-emit-followups";executable = true; };
  home.file.".local/bin/notmuch-snapshot-counts"={ source = "${scripts}/notmuch-snapshot-counts";executable = true; };

  # mbsyncrc and msmtprc reference ~/.authinfo.gpg via PassCmd / passwordeval, so no
  # secrets are in-repo.
  home.file.".mbsyncrc".source = "${configs}/mbsyncrc";

  # The repo file ships macOS paths (CA bundle + log file). The /nix/store result is mode
  # 444, which msmtp accepts because passwordeval keeps credentials out of the file.
  home.file.".msmtprc".text = builtins.replaceStrings
    [ "/etc/ssl/cert.pem"            "~/Library/Logs/msmtp.log" ]
    [ "/etc/ssl/certs/ca-bundle.crt" "~/.local/state/msmtp.log" ]
    (builtins.readFile "${configs}/msmtprc");

  # notmuch refuses $HOME expansion in its config, so the path has to be absolute; the repo
  # file ships the macOS one.
  home.file.".notmuch-config".text = builtins.replaceStrings
    [ "/Users/vincenzopace/Maildir" ]
    [ "${config.home.homeDirectory}/Maildir" ]
    (builtins.readFile "${configs}/notmuch-config");

  systemd.user.services.mail-sync = {
    Unit.Description = "notmuch pipeline: mbsync + indexing + tagging + dashboard";
    Service = {
      Type        = "oneshot";
      ExecStart   = "%h/.local/bin/mail-sync";
      # Keep a sync from fighting Emacs or a browser.
      Nice        = 10;
      IOSchedulingClass = "idle";
    };
  };

  systemd.user.timers.mail-sync = {
    Unit.Description = "Trigger mail-sync every 5 minutes";
    Timer = {
      OnBootSec       = "1min";
      OnUnitActiveSec = "5min";
      Unit            = "mail-sync.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.notmuch-daily = {
    Unit.Description = "Daily notmuch tag dump + counts snapshot";
    Service = {
      Type      = "oneshot";
      ExecStart = pkgs.writeShellScript "notmuch-daily" ''
        ${pkgs.notmuch}/bin/notmuch dump --output="$HOME/org/notmuch-tags.dump"
        "$HOME/.local/bin/notmuch-snapshot-counts"
      '';
    };
  };

  systemd.user.timers.notmuch-daily = {
    Unit.Description = "Daily notmuch maintenance at 03:00";
    Timer = {
      OnCalendar = "*-*-* 03:00:00";
      Persistent = true;
      Unit       = "notmuch-daily.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
