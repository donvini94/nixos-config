# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
