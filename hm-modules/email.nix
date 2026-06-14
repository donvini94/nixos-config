{ config, lib, pkgs, ... }:

# NixOS home-manager deployment for the notmuch email pipeline.
#
# Files-of-truth live in ../mail/. This module installs them under $HOME,
# rewrites the notmuch DB path for Linux, and replicates the macOS launchd
# jobs as systemd user timers.
#
# Work / amiconsult account: the `Work` block in ~/.mbsyncrc and ~/.msmtprc
# stays commented out on NixOS. The customer/leadership tag rules in
# mail-sync are gated on `[ -d ~/Maildir/work ]`, so they're inert on this
# machine without any conditional in the nix.

let
  mailDir  = ../mail;
  scripts  = "${mailDir}/bin";
  configs  = "${mailDir}/config";
in
{
  # CLI dependencies. If already pulled in by another module nix dedupes.
  home.packages = with pkgs; [
    notmuch
    isync       # provides `mbsync`
    msmtp
    jq          # used by notmuch-compute-state + notmuch-emit-followups
    gnupg       # mbsync PassCmd shells out to gpg to decrypt ~/.authinfo.gpg
  ];

  # ─── Scripts ──────────────────────────────────────────────────────────
  # Placed under $HOME/.local/bin/ so the same PATH that works on macOS
  # works here. They're symlinked into the nix store, but the scripts
  # themselves only use $HOME paths internally — fully relocatable.
  home.file.".local/bin/mail-sync"             = { source = "${scripts}/mail-sync";             executable = true; };
  home.file.".local/bin/notmuch-compute-state" = { source = "${scripts}/notmuch-compute-state"; executable = true; };
  home.file.".local/bin/notmuch-emit-followups"= { source = "${scripts}/notmuch-emit-followups";executable = true; };
  home.file.".local/bin/notmuch-snapshot-counts"={ source = "${scripts}/notmuch-snapshot-counts";executable = true; };

  # ─── Dotfiles ─────────────────────────────────────────────────────────
  # mbsyncrc and msmtprc are checked in verbatim; both reference
  # ~/.authinfo.gpg via PassCmd / passwordeval so no secrets are in-repo.
  home.file.".mbsyncrc".source = "${configs}/mbsyncrc";

  # msmtprc ships with macOS paths (CA bundle + log file). Substitute the
  # Linux equivalents before placing. The /nix/store file ends up mode 444,
  # which msmtp accepts when using passwordeval (no in-file credentials).
  home.file.".msmtprc".text = builtins.replaceStrings
    [ "/etc/ssl/cert.pem"            "~/Library/Logs/msmtp.log" ]
    [ "/etc/ssl/certs/ca-bundle.crt" "~/.local/state/msmtp.log" ]
    (builtins.readFile "${configs}/msmtprc");

  # notmuch refuses $HOME expansion in its config, so it has to be an
  # absolute path. The repo file ships the macOS path; we substitute the
  # Linux home before placing it.
  home.file.".notmuch-config".text = builtins.replaceStrings
    [ "/Users/vincenzopace/Maildir" ]
    [ "${config.home.homeDirectory}/Maildir" ]
    (builtins.readFile "${configs}/notmuch-config");

  # ─── Periodic pipeline ────────────────────────────────────────────────
  # Replaces macOS de.amiconsult.mbsync.plist: run mail-sync every 5 min.
  systemd.user.services.mail-sync = {
    Unit.Description = "notmuch pipeline: mbsync + indexing + tagging + dashboard";
    Service = {
      Type        = "oneshot";
      ExecStart   = "%h/.local/bin/mail-sync";
      # Match the macOS plist's Nice / IO priority so a sync doesn't fight
      # Emacs or a browser.
      Nice        = 10;
      IOSchedulingClass = "idle";
    };
  };

  systemd.user.timers.mail-sync = {
    Unit.Description = "Trigger mail-sync every 5 minutes";
    Timer = {
      # Fire 1 min after login, then every 5 min.
      OnBootSec       = "1min";
      OnUnitActiveSec = "5min";
      Unit            = "mail-sync.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # ─── Daily maintenance ────────────────────────────────────────────────
  # Replaces macOS de.amiconsult.notmuch-tag-dump.plist: at 03:00 local,
  # dump the full tag state and snapshot per-tag counts for the dashboard
  # delta widget.
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
      Persistent = true;        # run on resume if the system was asleep at 03:00
      Unit       = "notmuch-daily.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
