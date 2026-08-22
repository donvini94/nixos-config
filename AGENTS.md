# AGENTS.md

Project context for every coding agent working in this repository. OMP loads this file
natively; the root `CLAUDE.md` is only a pointer to it.

## Overview

This is a NixOS configuration repository managing two systems: a desktop (dracula) and a home server (alucard). The desktop uses Hyprland with caelestia-shell for the desktop shell (bar, notifications, wallpaper, lock screen, launcher). The server runs multiple services behind nginx reverse proxies.

## Build and Deployment Commands

### Building Configurations
```bash
# Desktop (AMD + NVIDIA)
sudo nixos-rebuild switch --flake .#dracula

# Server (Hetzner QEMU)
sudo nixos-rebuild switch --flake .#alucard
```

### Development Commands
```bash
nix flake update          # Update flake inputs
nix flake check           # Check configuration
nix flake show            # Show flake outputs
sudo nixos-rebuild build --flake .#dracula    # Test build without switching
sudo nixos-rebuild dry-run --flake .#dracula  # Dry run
```

### Secret Management
```bash
sops secrets/dmbs.yaml    # Edit encrypted secrets
```

## Architecture

### Flake Structure

`flake.nix` provides two host-builder functions:
- `mkDesktopHost "hostname"` — full desktop with Hyprland, home-manager, sops, hosts blocking
- `mkServerHost "hostname"` — minimal server (host imports what it needs)

Adding a new desktop host:
```nix
newhost = mkDesktopHost "newhost";
```
Then create `hosts/newhost/` with `default.nix` (imports shared modules), `hardware.nix`, and optionally `services.nix`.

### Core Structure
- `flake.nix` — Host-builder functions + flake inputs
- `configuration.nix` — Shared base config (shells, locale, gnupg, nix settings)
- `home.nix` — Home-manager import manifest (pure imports + home identity)

### Host Configurations

**Desktop (`hosts/dracula/`):**
- `default.nix` — Import manifest + hostname + user + stateVersion. Imports shared modules: `desktop.nix`, `nvidia.nix`, `gaming.nix`
- `hardware.nix` — Boot, filesystems, CPU (AMD), peripherals (bluetooth, v4l2loopback)
- `services.nix` — Host-specific: Jellyfin, Docker, OBS, ausweisapp, host-specific packages

**Server (`hosts/alucard/`):**
- `default.nix` — Base system, boot, nix settings, Hetzner mount, scheduled tasks
- `networking.nix` — Firewall, SSH, fail2ban, mining pool blocks
- `services.nix` — Nginx vhosts, Keycloak, Jellyfin, Navidrome, Calibre-Web, Paperless
- `media.nix` — Docker, media automation stack, mining watchdog
- `users.nix` — User accounts and SSH keys
- `syncthing.nix` — Syncthing devices and folders

### Shared Modules (`modules/`)
- `desktop.nix` — Meta-module importing all desktop sub-modules + security/PAM + stevenBlackHosts
- `nvidia.nix` — Opt-in NVIDIA module (driver, graphics, env vars, container toolkit)
- `hyprland/default.nix` — System-level Hyprland setup (GDM, portals, packages)
- `packages.nix` — System-level packages shared by ALL hosts (desktop + server)
- `programming.nix` — Dev tools needing system integration (Python+CUDA, Rust, Emacs, JDK)
- `services.nix` — Desktop services (pipewire, rtkit, emacs, printing, mullvad)
- `fonts.nix` — Font definitions
- `gaming.nix` — Opt-in: Steam, Proton, Wine, lossless scaling

### Home-Manager Modules (`hm-modules/`)
- `git.nix` — Git identity
- `ssh.nix` — SSH config + control master sockets
- `fish.nix` — Fish shell + abbreviations
- `shell.nix` — Bash, zoxide, direnv, atuin
- `hyprland.nix` — Hyprland WM config (keybinds, input, window rules)
- `caelestia.nix` — Desktop shell config + runtime dependencies
- `services.nix` — User services (udiskie, syncthing, mpd, gammastep)
- `packages.nix` — User-level packages (dev tools, writing, communication, Japanese)
- `helix.nix`, `kitty.nix`, `mpv.nix`, `starship.nix`, `yazi.nix`, `zathura.nix`, `zellij.nix`, `doom.nix` — Per-tool configs

### Desktop Shell
Caelestia-shell (Quickshell-based) provides: bar, notifications, lock screen, wallpaper, launcher, OSD, session management. It starts as a systemd service on `graphical-session.target`. The Hyprland config in `hm-modules/hyprland.nix` only handles core WM behavior (keybinds, layouts, window rules) — all shell/theming is delegated to caelestia.

### Secret Management
Uses sops-nix with age encryption. `secrets/secrets.nix` imports sops-nix internally and defines all secrets. Keys in `.sops.yaml`, secrets in `secrets/dmbs.yaml`.

## Key Configuration Patterns

- Host-specific config (hardware, boot) goes in `hosts/<hostname>/`
- Reusable desktop functionality goes in `modules/` (imported by host's `default.nix`)
- User tool configs go in `hm-modules/` (one file per tool)
- `home.nix` is a pure import manifest — all config lives in hm-modules
- Both systems share `configuration.nix` for base settings
- Server imports `modules/packages.nix` directly (no desktop modules, no home-manager)
- NVIDIA config is opt-in via `modules/nvidia.nix` — non-NVIDIA hosts omit the import
- Package placement rule: system packages = needs system-level integration (root, hardware, PAM, build toolchain). Everything else = `hm-modules/packages.nix`

## The Mac is not nix-managed

The Mac daily driver runs Determinate Nix (CLI/daemon, v3.x) so the flake in this repo can
be worked on, but the machine itself is **not** managed by nix-darwin or home-manager —
there is no `darwin-rebuild` and no `home-manager` binary. Userland CLI tools (fish, emacs,
ghostty, zellij) come from Homebrew under `/opt/homebrew`. `hm-modules/` and `modules/`
target the NixOS hosts (dracula desktop, alucard server) **only**.

To configure a tool on the Mac: install via `brew` and hand-write its config under
`~/.config`. The Mac will not pick up anything from `hm-modules/`. Never attempt
`nixos-rebuild` or `darwin-rebuild` there.

Consequence: anything declared in `hm-modules/` has a hand-maintained Mac twin that must be
kept in sync **by hand**. Known twins:

- `hm-modules/zellij.nix` → `~/.config/zellij/config.kdl` + `layouts/{code,bereit,work}.kdl`.
  Ported 2026-06-28 (zellij 0.44.3 via brew). Mac adaptation: `copy_command "pbcopy"` where
  NixOS uses `wl-copy`. The Mac terminal is **Ghostty**, not kitty, and needs no
  terminal-side changes — its keybinds are cmd-based and don't collide with zellij's ctrl
  modes. The `bereit`/`work` SSH layouts work because `~/.ssh/config` already has
  `Bereitserver`, `media-admin`, `acGPT`.
- `hm-modules/fish.nix` → `~/.config/fish/conf.d/zellij.fish` (standalone, deliberately not
  in `fish.nix`): abbr `zj` = `zellij attach -c`, `zjl` = `zellij ls`.

## Working practices for this repo

**Answer questions; don't edit unasked.** When Vincenzo asks "how do I…", "what's the right
way to…", "should I…", "why does X…", answer in prose with trade-offs and then **stop**.
Wait for an explicit "do it" / "change it" / "apply that". This holds even when the answer
is obvious. Precedent: "how to properly view HTML emails?" was read as "fix it", which
changed `mu4e-view-show-images` and uncommented mu4e-views in `config.org`, broke his email
entirely, and had to be reverted. The cost of an unsolicited edit far exceeds one saved
round-trip. Exception: a typo or obviously-broken state he just demonstrated — and even
then, prefer asking.

**Never patch third-party source as a workaround.** Do not edit upstream files inside a
venv or `site-packages` to route around an environment incompatibility. Such patches leave
no audit trail, are invisible in the dotfiles, get wiped on reinstall, hide the real
problem, and resurface as mystery breakage months later. His words: "thats not a solution."
Fix the environment instead — reinstall against a supported interpreter
(`uv tool install --python 3.11 <pkg>`, or pipx `--python`), or install the missing system
library and configure paths persistently (shell config, launchd plist). The fix must be
reproducible from the dotfiles alone.

**Don't theorize from config without logs.** Read `journalctl` on the box first. Doing
otherwise wasted two full cycles on the GDM issue below.

## dracula GDM black screen — historical, status unverified

Kept for the elimination work, which was expensive and is still valid. **Verify current
state before acting on any of it**: `flake.lock` has since moved to a 2026-06-08 nixpkgs,
and the referenced `HANDOFF-gdm-black-screen.md` is no longer in the repo.

Symptom (as of 2026-06-13): dracula black-screened at boot — single `_` cursor, no GDM
greeter — on every build from the then-current June nixpkgs; he booted the older NixOS
26.05 generation to work.

**Root cause was narrowed decisively to the June nixpkgs *userspace*** (mesa / GDM / GNOME /
mutter / wayland / libdrm) — **not** the kernel and **not** the nvidia driver. Proof: kernels
7.0.3-zen, 7.0.10-zen and 6.12 LTS were all tried, drivers 595.71.05 and 610 were all tried;
everything on June nixpkgs black-screened, and the only working configuration was on the
May-5 nixpkgs. The same driver 595.71.05 works on 7.0.3 and fails on 7.0.10.

Bisected to commit `bf1fa4a` (2026-06-01), a `flake.lock` bump of nixpkgs from `549bd84`
(May-5, works) to `277ddb23` (May-31, breaks). The display manager is GDM/Wayland, not
sddm. If it recurs, the untried next step was
`services.xserver.displayManager.gdm.wayland = false`.
