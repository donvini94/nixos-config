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

Generate an iCloud **app-specific password** at
[appleid.apple.com](https://appleid.apple.com/) →
*Sign-in and Security → App-Specific Passwords → Generate* (label it
e.g. `notmuch on <host>`). Apple will only show it once.

Then encrypt it:

```sh
cat > /tmp/authinfo <<'EOF'
machine imap.mail.me.com login vincenzo.pace94@icloud.com password xxxx-xxxx-xxxx-xxxx
EOF
gpg --encrypt --recipient <your-keyid> --output ~/.authinfo.gpg /tmp/authinfo
shred -u /tmp/authinfo

# Verify:
gpg --decrypt ~/.authinfo.gpg
```

**Why:** Apple ID passwords don't work over IMAP since 2017 — you must
use an app-specific password. Encrypting it means no plaintext
credential on disk, and the `PassCmd` in `mbsyncrc` pulls it through
gpg-agent on every sync.

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
mkdir -p ~/Maildir/personal ~/org
```

**Why:** mbsync's `Create Both` creates folders *inside* a maildir
account dir, but won't create the account dir or its parent. Same for
the org dir — the daily-snapshot script does `mkdir -p $DIR/notmuch-counts`
but doesn't create `~/org/` itself. Doing it once up front avoids two
classes of silent first-run failures.

#### 6. First mbsync (interactive)

```sh
mbsync personal
```

First invocation triggers gpg-agent which will prompt (via pinentry)
for your GPG key passphrase. The passphrase is then cached for the
session, so subsequent syncs are silent.

**Verify:**

```sh
ls ~/Maildir/personal/INBOX/cur/ | head -5      # message files present
```

If it hangs on pinentry: `gpg --decrypt ~/.authinfo.gpg` directly to
unstick the prompt and prime the cache.

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

- Maildir root: `~/Maildir/` (subdirs `personal/`, optionally `work/`)
- Notmuch xapian DB: `~/Maildir/.notmuch/`
- Daily tag backup: `~/org/notmuch-tags.dump` (syncthing-replicated)
- Daily count snapshots: `~/org/notmuch-counts/YYYY-MM-DD.csv`
- Mail-sync logs: `~/Library/Logs/mbsync.log` (macOS) / `journalctl --user -u mail-sync` (NixOS)
- Send logs: `~/Library/Logs/msmtp.log` / msmtprc `logfile` directive
- Org agenda follow-ups: `~/org/mail-followups.org` (autogenerated, do not edit)
