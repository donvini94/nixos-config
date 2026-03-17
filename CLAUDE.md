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

### Core Structure
- `flake.nix` - Flake with two systems: dracula (desktop) and alucard (server)
- `configuration.nix` - Shared base config (shells, locale, gnupg)
- `home.nix` - Home-manager root config with caelestia-shell integration

### Host Configurations
- `hosts/dracula/default.nix` - Desktop: hardware, boot, nvidia, docker, gaming, DroidCam
- `hosts/alucard/` - Server, split into:
  - `default.nix` - Base system, boot, nix settings, Hetzner mount, scheduled tasks
  - `networking.nix` - Firewall, SSH, fail2ban, mining pool blocks
  - `services.nix` - Nginx vhosts, Keycloak, Jellyfin, Navidrome, Calibre-Web, Paperless
  - `media.nix` - Docker, media automation stack, mining watchdog
  - `users.nix` - User accounts and SSH keys
  - `syncthing.nix` - Syncthing devices and folders

### Desktop Modules (`modules/`)
- `desktop.nix` - Meta-module importing all desktop sub-modules
- `hyprland/default.nix` - System-level Hyprland setup (GDM, portals, non-caelestia packages)
- `packages.nix` - System-wide packages (shared by desktop and server)
- `fonts.nix` - Font definitions
- `programming.nix` - Dev tools (Python, Rust, Node, Nix tooling)
- `services.nix` - Desktop services (pipewire, emacs, printing, mullvad)
- `gaming.nix` - Steam, Proton, Wine, lossless scaling

### Home-Manager Modules (`hm-modules/`)
- `hyprland.nix` - Hyprland WM config (keybinds, input, window rules) — works alongside caelestia
- `nushell.nix` - Shell config with aliases, direnv, atuin
- `helix.nix`, `starship.nix`, `mpv.nix`, `yazi.nix`, `zathura.nix` - Tool configs
- `packages.nix` - User-level packages (communication, productivity, media)

### Desktop Shell
Caelestia-shell (Quickshell-based) provides: bar, notifications, lock screen, wallpaper, launcher, OSD, session management. It starts as a systemd service on `graphical-session.target`. The Hyprland config in `hm-modules/hyprland.nix` only handles core WM behavior (keybinds, layouts, window rules) — all shell/theming is delegated to caelestia.

### Secret Management
Uses sops-nix with age encryption. Keys in `.sops.yaml`, secrets in `secrets/dmbs.yaml`.

## Key Configuration Patterns

- Host-specific config (hardware, boot, networking) goes in `hosts/<hostname>/`
- Reusable desktop functionality goes in `modules/`
- User-specific tool configs go in `hm-modules/`
- Both systems share `configuration.nix` for base settings
- Server imports `modules/packages.nix` directly (no desktop modules)
