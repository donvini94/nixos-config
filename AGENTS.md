# AGENTS.md

Project context for every coding agent working in this repository. OMP loads this file
natively; the root `CLAUDE.md` is only a pointer to it.

## Overview

This is a Nix configuration repository managing three systems: a NixOS desktop (dracula), a NixOS home server (alucard), and a nix-darwin Mac (AC-0137). The desktop uses Hyprland with caelestia-shell for the desktop shell (bar, notifications, wallpaper, lock screen, launcher). The server runs multiple services behind nginx reverse proxies. The Mac is a laptop daily driver — see "The Mac is nix-darwin managed" below.

## Build and Deployment Commands

### Building Configurations
```bash
# Desktop (AMD + NVIDIA)
sudo nixos-rebuild switch --flake .#dracula

# Server (Hetzner QEMU)
sudo nixos-rebuild switch --flake .#alucard

# Mac (nix-darwin + home-manager)
sudo darwin-rebuild switch --flake .#AC-0137
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

`flake.nix` provides two host-builder functions plus one inline darwin host:
- `mkDesktopHost "hostname"` — full desktop with Hyprland, home-manager, sops, hosts blocking
- `mkServerHost "hostname"` — minimal server (host imports what it needs)
- `darwinConfigurations."AC-0137"` — inline, not a factory, because there is exactly one Mac

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
- `services/default.nix` — Service import manifest + shared off-site backup enable
- `services/reverse-proxy.nix` — Public nginx vhosts, ACME, backend firewall guard
- `services/identity.nix` — PostgreSQL, Keycloak, realm export and backup
- `services/media-services.nix` — Jellyfin, Navidrome, Calibre-Web
- `services/hosted-applications.nix` — Paperless, mailcow TLS, registry, n8n backup
- `media.nix` — Docker, media automation stack, mining watchdog
- `users.nix` — User accounts and SSH keys
- `syncthing.nix` — Syncthing devices and folders

**Mac (`hosts/ac-0137/`):**
- `default.nix` — Darwin system layer: platform, stateVersion, primaryUser, `nix.enable = false`, fonts, `/etc/shells`, `system.defaults`
- `homebrew.nix` — Declarative Brewfile (`cleanup = "uninstall"`)
- `ui.nix` — SketchyBar + JankyBorders as launchd agents
- `home.nix` — Home-manager import manifest for the Mac
- `fish.nix`, `apps.nix`, `omp.nix` — Darwin-only home config
- `sketchybar/`, `ghostty/`, `zed/`, `aerospace.toml` — Managed dotfile assets

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
- `shell.nix` — Bash, zoxide, direnv (cross-platform)
- `atuin.nix` — Synced shell history; NixOS hosts only (Ctrl-R conflict on the Mac)
- `hyprland.nix` — Hyprland WM config (keybinds, input, window rules)
- `caelestia.nix` — Desktop shell config + runtime dependencies
- `services.nix` — User services (udiskie, syncthing, mpd, gammastep)
- `cli-tools.nix` — User-level CLI tooling that builds on Linux *and* darwin; imported by every host
- `packages.nix` — Linux-desktop-only packages (GUI apps, hledger, texlive)
- `lsp.nix` — Language servers for the OMP `lsp` tool
- `omp.nix` — OMP harness context (`~/.omp/agent` links, derived `mcp.json`)
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
- Package placement rule: system packages = needs system-level integration (root, hardware, PAM, build toolchain). Everything else = `hm-modules/cli-tools.nix` if it builds on both Linux and darwin, `hm-modules/packages.nix` if it is Linux-desktop-only
- Darwin host config goes in `hosts/ac-0137/`; darwin-only home modules live alongside it (`fish.nix`, `apps.nix`, `omp.nix`), not in `hm-modules/`
- A shared `hm-modules/` file that has to differ per platform branches on `pkgs.stdenv.hostPlatform.isDarwin` inside the module — it never gets a second copy

## The Mac is nix-darwin managed

The Mac daily driver (`scutil --get LocalHostName` = `AC-0137`, user `vincenzopace`,
aarch64) is `darwinConfigurations."AC-0137"` in this flake. Rebuild it with:

```
sudo darwin-rebuild switch --flake ~/nixos-config#AC-0137
```

Layering on that host:

- **Determinate Nix** owns `/etc/nix`, `nix.custom.conf` and the daemon. `nix.enable =
  false` in `hosts/ac-0137/default.nix`, so nix-darwin never writes Nix configuration and
  home-manager forwards the same flag. Do not add `nix.settings` there.
- **nix-darwin** owns fonts, `/etc/shells`, `system.defaults`, and the launchd agents for
  SketchyBar and JankyBorders (`hosts/ac-0137/ui.nix`, labels `org.nixos.sketchybar` and
  `org.nixos.jankyborders`).
- **home-manager** is wired as a nix-darwin module with `useUserPackages = true`, so the
  per-user package set lands in `/etc/profiles/per-user/vincenzopace` rather than
  `~/.nix-profile`. `hosts/ac-0137/home.nix` is the import manifest.
- **Homebrew** is declarative in `hosts/ac-0137/homebrew.nix` with `cleanup = "uninstall"`.
  That file is the truth: an imperative `brew install` is reverted on the next switch. To
  keep a formula, add it to the list. Homebrew's remit is toolchains
  (rustup/openjdk/maven/cmake), macOS-integrated tools, GUI casks, and anything nixpkgs
  cannot supply — AeroSpace and emacs-plus stay casks on purpose (version and
  Accessibility-grant stability).

There are no "Mac twins" any more. A tool configured in `hm-modules/` reaches the Mac by
being imported in `hosts/ac-0137/home.nix`; if it needs platform-specific values, branch
on `pkgs.stdenv.hostPlatform.isDarwin` in the shared module.

Still deliberately stateful on that host, each for a stated reason:

- **fisher fish plugins** (tide, fzf.fish, z, autopair, done) — `fishPlugins.fzf-fish` is
  `broken = true` at the locked nixpkgs, so declaring the set would silently drop
  `fzf.fish`. tide's own configuration lives in fish universal variables either way.
  Because fisher's `fzf.fish` owns Ctrl-R, `hm-modules/atuin.nix` is NOT imported there.
- **`~/.config/fish/conf.d/leafcloud.fish`** — holds a plaintext OpenStack password; must
  never enter the repo.
- **`~/.gnupg` and the `pass` store** — `pass` and `pinentry-mac` stay Homebrew formulae;
  moving them pulls a second gnupg into agent-socket territory and `hm-modules/git.nix`
  signs with `signing.format = "openpgp"`.
- **The mail stack** (`isync`/`msmtp`/`mu`/`notmuch` + `mail/mac/`) and Doom's
  `~/.config/emacs` checkout.

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
