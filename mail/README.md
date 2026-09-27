# mail/

notmuch-based email pipeline. Source of truth for all email-related
configuration on both macOS and NixOS (see *Deploy* below).

The Emacs-side configuration (notmuch UI, dashboard, agenda integration)
lives in `../doom/config.org` under the `Email (notmuch)` section. The
tag taxonomy and query syntax live in the org-roam reference note
`~/org/roam/reference/20260604093000-notmuch.org`.

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
│   ├── mbsyncrc                          # Bereit Mailcow IMAP; add channels for future accounts
│   └── msmtprc                           # Bereit Mailcow SMTP; add sending identities alongside channels
└── mac/                                  # macOS-only launchd assets
    └── launchd/
        ├── de.istbereit.mail-sync.plist          # 5-min mail-sync trigger
        └── de.istbereit.notmuch-daily.plist      # 03:00 daily dump+snapshot
```

## Pipeline

```
launchd/timer → mail-sync
    ├── mbsync -a                # IMAP fetch (Bereit; future business accounts)
    ├── notmuch new              # index; tags everything +new
    ├── tag rules (top→bottom)   # reading allowlist + bulk + sent + inbox
    ├── notmuch-compute-state    # owed/reply + age buckets (clear+recompute)
    └── notmuch-emit-followups   # regenerate ~/org/mail-followups.org
```

Only `vincenzo@istbereit.de` is active. The Maildir and index contain business
mail only. For each future business mailbox add an mbsync
IMAPAccount/Store/Channel, msmtp account, and Emacs identity/Fcc mapping;
then turn `notmuch-always-prompt-for-sender` back on for new messages.

## Deploy

### macOS

Repo files are referenced via symlinks:

| Location                                                | → repo path                       |
|---------------------------------------------------------|-----------------------------------|
| `~/.local/bin/mail-sync` (+ 3 siblings)                 | `mail/bin/`                       |
| `~/.notmuch-config`                                     | `mail/config/notmuch-config`      |
| `~/.mbsyncrc`                                           | `mail/config/mbsyncrc`            |
| `~/.msmtprc`                                            | `mail/config/msmtprc`             |
| `~/Library/LaunchAgents/de.istbereit.mail-sync.plist` | `mail/mac/launchd/...` |
| `~/Library/LaunchAgents/de.istbereit.notmuch-daily.plist` | `mail/mac/launchd/...` |

Before enabling the timer, edit the existing `~/.authinfo.gpg` in Emacs
(EasyPG decrypts it on open and re-encrypts on save). Remove the iCloud
`imap.mail.me.com` and `smtp.mail.me.com` entries, preserving unrelated
credentials, and add:

```text
machine mail.istbereit.de login vincenzo@istbereit.de password YOUR_MAILBOX_PASSWORD
```

Use the Mailcow **mailbox password**, or a mailbox app password if one is
configured for IMAP and SMTP. This is not a Mailcow API token. Both mbsync
and msmtp read the same entry; keep the password on one line without spaces.
Never put it in this repo or send it in chat. The old sync agents have been
unloaded and their symlinks removed on this Mac. After saving the credential,
run `mbsync bereit` to fetch the mailbox and inspect its Sent folder name
(Fcc currently expects `Sent`). Run `~/.local/bin/mail-sync` to index and tag
the messages; then load `~/Library/LaunchAgents/de.istbereit.mail-sync.plist`
with `launchctl load`. The daily maintenance agent is already loaded.

If a clean Mac ever needs setting up:

```sh
REPO=$HOME/nixos-config
ln -sf $REPO/mail/bin/mail-sync             $HOME/.local/bin/mail-sync
ln -sf $REPO/mail/bin/notmuch-compute-state $HOME/.local/bin/notmuch-compute-state
ln -sf $REPO/mail/bin/notmuch-emit-followups $HOME/.local/bin/notmuch-emit-followups
ln -sf $REPO/mail/bin/notmuch-snapshot-counts $HOME/.local/bin/notmuch-snapshot-counts

ln -sf $REPO/mail/config/notmuch-config $HOME/.notmuch-config
ln -sf $REPO/mail/config/mbsyncrc       $HOME/.mbsyncrc
ln -sf $REPO/mail/config/msmtprc        $HOME/.msmtprc

ln -sf $REPO/mail/mac/launchd/de.istbereit.mail-sync.plist $HOME/Library/LaunchAgents/
ln -sf $REPO/mail/mac/launchd/de.istbereit.notmuch-daily.plist $HOME/Library/LaunchAgents/

launchctl load $HOME/Library/LaunchAgents/de.istbereit.mail-sync.plist
launchctl load $HOME/Library/LaunchAgents/de.istbereit.notmuch-daily.plist
```

### NixOS — routine deploy

Once the machine is set up (see *First-time setup* below), iteration is
just:

```sh
sudo nixos-rebuild switch --flake .#<host>      # applies module changes
systemctl --user restart mail-sync.timer        # only if timer config changed
```

`hm-modules/email.nix` handles the rest: scripts under `~/.local/bin/`,
dotfiles with the notmuch DB path rewritten to `/home/<user>/Maildir`,
`notmuch isync msmtp jq gnupg` via `home.packages`, and two systemd
user timers — `mail-sync.timer` (5 min) + `notmuch-daily.timer` (03:00) —
replacing the macOS launchd jobs. Home-manager auto-enables units listed
in `Install.WantedBy`, so no manual `systemctl enable` is needed.

### NixOS — first-time setup

For a clean machine. Steps are in order; each one's *Why* explains what
breaks if you skip it.

#### 0. Get the repo onto the box

```sh
git clone <repo-url> ~/nixos-config
```

**Why:** `hm-modules/doom.nix` symlinks `~/.config/doom` →
`~/nixos-config/doom` via `mkOutOfStoreSymlink`. The symlink is created
unconditionally — if the target path doesn't exist, you get a dangling
link and Doom won't load. Same for `hm-modules/email.nix` which reads
files from `../mail/` relative to the module.

#### 1. GPG keypair

If migrating from the existing Mac (recommended — keeps the same key
identity across machines so `~/.authinfo.gpg` doesn't have to be
re-encrypted):

```sh
# On the Mac:
gpg --list-secret-keys --keyid-format=long      # find your <keyid>
gpg --export-secret-keys --armor <keyid> > /tmp/sec.asc
gpg --export             --armor <keyid> > /tmp/pub.asc
gpg --export-ownertrust > /tmp/trust.txt
scp /tmp/{sec,pub,trust}* <nixos-host>:/tmp/

# On NixOS:
gpg --import /tmp/pub.asc
gpg --import /tmp/sec.asc
gpg --import-ownertrust < /tmp/trust.txt
shred -u /tmp/{sec,pub,trust}*
gpg --list-secret-keys                          # verify
```

If starting fresh: `gpg --full-generate-key` (RSA 4096, no expiry, your
real email). Then you'll generate a new `~/.authinfo.gpg` in step 3.

**Why:** mbsync's `PassCmd` shells out to `gpg --decrypt
~/.authinfo.gpg`. No key, no password, no IMAP login.

#### 2. Pinentry

Add to `configuration.nix` (or wherever `programs.gnupg.agent` is set):

```nix
programs.gnupg.agent = {
  enable = true;
  pinentryPackage = pkgs.pinentry-curses;   # for TTY-friendly first run
  # Switch to pkgs.pinentry-rofi later if you want graphical prompts
  # under Hyprland.
};
```

Then `sudo nixos-rebuild switch`.

**Why:** Without an explicit pinentry, gpg-agent picks a default that
may not work in your environment. `pinentry-curses` always works in any
terminal; `pinentry-rofi` is nicer once Hyprland is up but blocks
headless first runs.

#### 3. `~/.authinfo.gpg`

Follow the macOS credential instructions above on each host. Edit
`~/.authinfo.gpg` with Emacs EasyPG; keep only credentials you still use,
including the `mail.istbereit.de` mailbox entry. The `PassCmd` and
`passwordeval` read that entry without saving a plaintext copy to disk.

#### 4. Apply the email module

```sh
cd ~/nixos-config
sudo nixos-rebuild switch --flake .#<host>
```

**Verify:**

```sh
ls -la ~/.local/bin/mail-sync ~/.notmuch-config ~/.mbsyncrc ~/.msmtprc
systemctl --user list-timers | grep -E 'mail-sync|notmuch-daily'
which notmuch mbsync msmtp jq
```

#### 5. Create the maildir + org parents

```sh
mkdir -p ~/Maildir/bereit ~/org
```

**Why:** mbsync's `Create Both` creates folders *inside* a maildir
account dir, but won't create the account dir or its parent. Same for
the org dir — the daily-snapshot script does `mkdir -p $DIR/notmuch-counts`
but doesn't create `~/org/` itself. Doing it once up front avoids two
classes of silent first-run failures.

#### 6. First mbsync (interactive)

```sh
mbsync bereit
```

First invocation triggers gpg-agent which will prompt (via pinentry)
for your GPG key passphrase. The passphrase is then cached for the
session, so subsequent syncs are silent.

**Verify:** Check `~/Maildir/bereit/INBOX/cur/` or `new/` for fetched messages.
If pinentry blocks, unlock the GPG key in Emacs and retry; do not print the
decrypted credentials in the terminal.

#### 7. Initialize notmuch

```sh
notmuch new                                     # first full index
notmuch count '*'                               # should equal mail volume
```

**Why:** The `mail-sync` script does `notmuch new` every run, but the
first index over a fresh maildir takes longer than the 5-min timer
window — better to run it once manually and confirm before the timer
fires.

#### 8. Doom packages

```sh
cd ~/nixos-config/doom
doom sync                                       # installs consult-notmuch etc.
```

**Why:** `nixos-rebuild` installs Doom itself (via `hm-modules/doom.nix`)
but doesn't run `doom sync`. `consult-notmuch` and the other entries in
`packages.el` aren't fetched until you do.

#### 9. Trigger the pipeline manually once

```sh
systemctl --user start mail-sync.service
journalctl --user -u mail-sync -n 50            # confirm clean run
```

Expect to see: mbsync, notmuch new, tagging steps, compute-state,
emit-followups, done. Errors here usually mean a missing dependency
or a `~/.notmuch-config` path that didn't get rewritten — check
`grep path= ~/.notmuch-config` shows `/home/<you>/Maildir`.

#### 10. Verify in Emacs

Open Doom, hit `SPC o m`. You should see the same dashboard as on macOS
— header line, action queues, today's flow, saved searches. `SPC a M`
opens the org-agenda mail follow-ups view.

#### Optional: syncthing for `~/org/`

If you want `~/org/notmuch-tags.dump` and `~/org/notmuch-counts/*.csv`
replicated to your other devices, accept the org folder in syncthing's
web UI. The daily backup job writes there; without syncthing the dump
is local-only (and can't help if this machine's notmuch DB is wiped).

## Where things live operationally

- Maildir root: `~/Maildir/` (`bereit/` initially; one directory per future business account)
- Notmuch xapian DB: `~/Maildir/.notmuch/`
- Daily tag backup: `~/org/notmuch-tags.dump` (syncthing-replicated)
- Daily count snapshots: `~/org/notmuch-counts/YYYY-MM-DD.csv`
- Mail-sync logs: `~/Library/Logs/mbsync.log` (macOS) / `journalctl --user -u mail-sync` (NixOS)
- Send logs: `~/Library/Logs/msmtp.log` / msmtprc `logfile` directive
- Org agenda follow-ups: `~/org/mail-followups.org` (autogenerated, do not edit)
