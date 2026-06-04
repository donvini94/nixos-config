# mail/

notmuch-based email pipeline. Source of truth for all email-related
configuration on both macOS and NixOS (see *Deploy* below).

The Emacs-side configuration (notmuch UI, dashboard, agenda integration)
lives in `../doom/config.org` under the `Email (notmuch)` section. The
tag taxonomy, query syntax, keybindings, and work-account activation
checklist live in the org-roam reference doc at
`~/org/roam/reference/<date>-notmuch.org`.

## Layout

```
mail/
├── bin/                                  # scripts on $PATH ($HOME/.local/bin)
│   ├── mail-sync                         # orchestrator (every 5 min)
│   ├── notmuch-compute-state             # derives owed/reply + age/* tags
│   ├── notmuch-emit-followups            # writes ~/org/mail-followups.org
│   └── notmuch-snapshot-counts           # daily count baseline for the dashboard
├── config/                               # dotfiles ($HOME)
│   ├── notmuch-config                    # notmuch DB + LISTUNSUB index
│   ├── mbsyncrc                          # iCloud + (commented) M365
│   └── msmtprc                           # iCloud + (commented) M365
└── mac/                                  # macOS-only assets
    ├── launchd/                          # ~/Library/LaunchAgents/
    │   ├── de.amiconsult.mbsync.plist             # 5-min mail-sync trigger
    │   └── de.amiconsult.notmuch-tag-dump.plist   # 03:00 daily dump+snapshot
    └── IT-CONSENT-REQUEST.md             # M365 admin-consent request template
```

## Pipeline

```
launchd/timer → mail-sync
    ├── mbsync -a                # IMAP fetch (both accounts when active)
    ├── notmuch new              # index; tags everything +new
    ├── tag rules (top→bottom)   # customer/leadership (if ~/Maildir/work)
    │                              + reading allowlist + personal noise
    │                              + bulk killer + sent + inbox catch-all
    ├── notmuch-compute-state    # owed/reply + age buckets (clear+recompute)
    └── notmuch-emit-followups   # regenerate ~/org/mail-followups.org
```

Work-specific tag rules (customers, leadership) are gated on the
existence of `~/Maildir/work/`. They're inert on NixOS and on any Mac
that hasn't yet activated the work account. See the activation
checklist in the org-roam doc.

## Deploy

### macOS

Already deployed. Repo files are referenced via symlinks:

| Location                                                | → repo path                       |
|---------------------------------------------------------|-----------------------------------|
| `~/.local/bin/mail-sync` (+ 3 siblings)                 | `mail/bin/`                       |
| `~/.notmuch-config`                                     | `mail/config/notmuch-config`      |
| `~/.mbsyncrc`                                           | `mail/config/mbsyncrc`            |
| `~/.msmtprc`                                            | `mail/config/msmtprc`             |
| `~/Library/LaunchAgents/de.amiconsult.mbsync.plist`     | `mail/mac/launchd/...`            |
| `~/Library/LaunchAgents/de.amiconsult.notmuch-tag-dump.plist` | `mail/mac/launchd/...`      |

If a clean Mac ever needs setting up:

```sh
REPO=$HOME/nixos-config
ln -sf $REPO/mail/bin/mail-sync             $HOME/.local/bin/mail-sync
ln -sf $REPO/mail/bin/notmuch-compute-state $HOME/.local/bin/notmuch-compute-state
ln -sf $REPO/mail/bin/notmuch-emit-followups$HOME/.local/bin/notmuch-emit-followups
ln -sf $REPO/mail/bin/notmuch-snapshot-counts $HOME/.local/bin/notmuch-snapshot-counts

ln -sf $REPO/mail/config/notmuch-config $HOME/.notmuch-config
ln -sf $REPO/mail/config/mbsyncrc       $HOME/.mbsyncrc
ln -sf $REPO/mail/config/msmtprc        $HOME/.msmtprc

ln -sf $REPO/mail/mac/launchd/de.amiconsult.mbsync.plist           $HOME/Library/LaunchAgents/
ln -sf $REPO/mail/mac/launchd/de.amiconsult.notmuch-tag-dump.plist $HOME/Library/LaunchAgents/

launchctl load $HOME/Library/LaunchAgents/de.amiconsult.mbsync.plist
launchctl load $HOME/Library/LaunchAgents/de.amiconsult.notmuch-tag-dump.plist
```

### NixOS

`hm-modules/email.nix` (imported by `home.nix`) handles everything:
installs the four scripts under `~/.local/bin/`, places the dotfiles
(rewriting the notmuch DB path to `/home/<user>/Maildir`), pulls
`notmuch isync msmtp jq gnupg` via `home.packages`, and replaces the
launchd jobs with two systemd user timers — `mail-sync.timer` (5 min)
and `notmuch-daily.timer` (03:00).

Apply:

```sh
sudo nixos-rebuild switch --flake .#<host>
systemctl --user enable --now mail-sync.timer notmuch-daily.timer
systemctl --user start mail-sync.service      # immediate first run
```

You still need to provision `~/.authinfo.gpg` (mbsync's `PassCmd`
shells out to gpg to decrypt it) and run the first interactive
`mbsync personal` to set up the maildir tree.

## Where things live operationally

- Maildir root: `~/Maildir/` (subdirs `personal/`, optionally `work/`)
- Notmuch xapian DB: `~/Maildir/.notmuch/`
- Daily tag backup: `~/org/notmuch-tags.dump` (syncthing-replicated)
- Daily count snapshots: `~/org/notmuch-counts/YYYY-MM-DD.csv`
- Mail-sync logs: `~/Library/Logs/mbsync.log` (macOS) / `journalctl --user -u mail-sync` (NixOS)
- Send logs: `~/Library/Logs/msmtp.log` / msmtprc `logfile` directive
- Org agenda follow-ups: `~/org/mail-followups.org` (autogenerated, do not edit)
