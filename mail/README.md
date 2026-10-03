# mail/

notmuch-based email for `vincenzo@istbereit.de` (Bereit Mailcow). Source of truth for
the mail configuration on all three hosts.

The Emacs side (notmuch UI, dashboard, agenda integration) lives in
`../doom/config.org`, section `Email (notmuch)`. Tag taxonomy and query syntax live in
the org-roam note `~/org/roam/reference/20260604093000-notmuch.org`.

## Architecture: one hub, two replicas

Invariant: exactly one host talks IMAP and writes mail-derived files; every other host
is an identical copy of its notmuch database.

```
            Mailcow (IMAP / SMTP)
                  ▲ mbsync (two-way)
                  │
   alucard — mail hub (mail/home/mail-hub.nix, systemd user timers)
     mail-sync every 5 min: mbsync → notmuch new → tag rules → compute-state
                            → emit-followups (~/org/mail-followups.org)
     notmuch-daily 03:00:   ~/org/notmuch-tags.dump, ~/org/notmuch-counts/
                  ▲ muchsync over SSH (mail + tags, both directions)
        ┌─────────┴─────────┐
       Mac                dracula
  launchd agent       mail/home/email.nix
  mail-replica-sync every 5 min; msmtp sends directly to Mailcow SMTP
```

- **Tags are identical everywhere.** muchsync replicates notmuch tags, including manual
  ones (`s/waiting`, `f/partner`, …). On a conflict (both sides changed one message
  between syncs) `new`/`unread` survive only if both sides have them, every other tag
  survives if either side has it — reading a message anywhere marks it read everywhere.
- **Read/flagged/replied reach IMAP** only through the hub: its notmuch config has
  `maildir.synchronize_flags=true`, so tags become maildir flags there and mbsync pushes
  them. Replicas have it off (muchsync(1) recommends that).
- **Sent mail:** Emacs sends through msmtp on the replica and writes the Fcc copy with
  `notmuch insert` into `bereit/Sent` (tagged `+sent`). muchsync carries it to the hub,
  whose mbsync uploads it to the IMAP Sent folder.
- **One writer on the hub database.** `mail-sync` holds `~/.local/state/mail-hub.lock` for
  its whole run; replicas start the hub side as `flock … muchsync --server`, so a sync
  waits out a tagging pass instead of failing on the Xapian lock.
- **Syncthing carries only what the hub writes** into `~/org`. The Mac's `.stignore` for
  `~/org` must not exclude `mail-followups.org`, `notmuch-tags.dump` or `notmuch-counts/`.
- **muchsync never deletes mail files.** Messages removed on one host are moved to
  `~/Maildir/.notmuch/muchsync/trash` on the others; empty it by hand to reclaim space.

If Alucard is down, replicas can still send and read existing mail, but receive no new
mail until the hub returns. To relocate the hub, stop the old hub before starting the new one.

## Layout

```
mail/
├── bin/
│   ├── mail-sync                 # hub pipeline (alucard)
│   ├── mail-replica-sync         # `muchsync alucard` (Mac, dracula)
│   ├── notmuch-compute-state     # hub: owed/reply + age/* tags
│   ├── notmuch-emit-followups    # hub: writes ~/org/mail-followups.org
│   └── notmuch-snapshot-counts   # hub: daily count baseline for the dashboard
├── config/
│   ├── notmuch-config            # shared; the hub flips synchronize_flags on
│   ├── mbsyncrc                  # hub only; add a Channel per future mailbox
│   └── msmtprc                   # replicas; add an account per future mailbox
└── mac/launchd/
    └── de.istbereit.mail-sync.plist   # 5-min mail-replica-sync on the Mac
```

## Credentials

The same Mailcow app password, in authinfo format, in two places:

- **NixOS (alucard, dracula):** sops secret `secrets/mail.yaml` → key `bereit_authinfo`,
  installed by `mail/nixos/credentials.nix` at `/run/secrets/mail/bereit_authinfo`
  (owner vincenzo, 0400). Read by the hub's mbsync, dracula's msmtp and dracula's
  org-caldav. No GPG unlock involved, so timers never block on a prompt.
- **Mac:** `~/.authinfo.gpg` (GPG key `F40515934D278A5E`) with
  `machine mail.istbereit.de login vincenzo@istbereit.de password …` and the Emacs 30 form
  `machine mail.istbereit.de:443 port https login … password …` (for org-caldav).

Rotating the password: `SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops secrets/mail.yaml`,
edit `~/.authinfo.gpg` in Emacs, rebuild alucard and dracula.

## Deploy

### alucard (hub)

Deploy with the passwordless command in the root `README.org`. Checks:

```sh
systemctl --user list-timers | grep -E 'mail-sync|notmuch-daily'
journalctl --user -u mail-sync -n 30      # mbsync … compute-state … done
notmuch count '*'
```

A fresh hub fills itself: `mail-sync` creates `~/Maildir/bereit` and mbsync downloads the
mailbox. To keep manual tags when rebuilding a hub, `notmuch dump` on a replica first and
`notmuch restore` on the new hub before any replica syncs.

### dracula (replica)

Deploy with the passwordless command in the root `README.org`, then `doom sync` if
`packages.el` changed.
A replica must start from an **empty** `~/Maildir` (muchsync treats every pre-existing
file as a conflict, and a leftover Maildir would be uploaded to the hub):

```sh
systemctl --user stop mail-replica-sync.timer
rm -rf ~/Maildir && mkdir ~/Maildir
systemctl --user start mail-replica-sync.service && systemctl --user start mail-replica-sync.timer
journalctl --user -u mail-replica-sync -n 10   # "received N messages … done"
```

### Mac (replica)

Stateful symlinks (the mail stack stays outside nix-darwin on this host):

```sh
REPO=$HOME/nixos-config
ln -sf $REPO/mail/bin/mail-replica-sync  $HOME/.local/bin/mail-replica-sync
ln -sf $REPO/mail/config/notmuch-config  $HOME/.notmuch-config
ln -sf $REPO/mail/config/msmtprc         $HOME/.msmtprc
ln -sf $REPO/mail/mac/launchd/de.istbereit.mail-sync.plist $HOME/Library/LaunchAgents/
# ~/Maildir must be empty before the first sync, as on dracula.
launchctl load $HOME/Library/LaunchAgents/de.istbereit.mail-sync.plist
```

`muchsync` comes from nix (`hosts/ac-0137/home.nix`); `notmuch` and `msmtp` from Homebrew
(`hosts/ac-0137/homebrew.nix`). Check the installed versions before a database-format upgrade.

## Where things live

- Maildir + notmuch DB: `~/Maildir/` and `~/Maildir/.notmuch/` on every host
- Hub logs: `journalctl --user -u mail-sync` on alucard
- Replica logs: `~/Library/Logs/mail-sync.log` (Mac), `journalctl --user -u mail-replica-sync` (dracula)
- Last successful replica sync: `~/.local/state/mail-sync.stamp` (shown in the notmuch dashboard)
- Send logs: `~/Library/Logs/msmtp.log` (Mac), `~/.local/state/msmtp.log` (dracula)
- Hub-written, Syncthing-shared: `~/org/mail-followups.org`, `~/org/notmuch-tags.dump`,
  `~/org/notmuch-counts/YYYY-MM-DD.csv`
