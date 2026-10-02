# Repository rules

Three hosts: personal desktop `dracula`, personal Mac `AC-0137`, and media/startup
server `alucard`. See `README.org` for operations; inspect module definitions for
current packages, services, ports and paths. Do not duplicate those inventories in docs.

## Workflow

- Pull with `git pull --rebase` before editing. Check for dirty work first; preserve it.
- Commit all intended changes (including pending user changes unless told otherwise),
  push, then fast-forward the other two checkouts. Mac: `~/nixos-config`;
  Linux: `/home/vincenzo/nixos-config`.
- Evaluate all three hosts after shared changes. Build affected configurations before
  deployment; `--dry-run` only evaluates the build plan.
- Deploy Alucard with a PTY: `ssh -t alucard 'cd /home/vincenzo/nixos-config &&
  sudo nixos-rebuild switch --flake .#alucard'`.
- Read runtime logs before diagnosing configuration. A successful evaluation does not
  prove a service works. Do not expose secrets while collecting evidence.
- Questions are not authorization to edit. Answer "how/why/should" questions and stop;
  wait for an explicit request to apply the change.
- Do not retire live services or delete application data without approval.

## Placement

- Host-specific wiring: `hosts/<host>/`. Shared system functionality: `modules/`.
- User configuration: `hm-modules/`; home files are import manifests plus identity.
- Cross-platform CLI packages: `hm-modules/cli-tools.nix`. Linux GUI packages:
  `hm-modules/packages.nix`. System packages are for integration/toolchains.
- Darwin-only configuration stays in `hosts/ac-0137/`; shared modules branch on
  `pkgs.stdenv.hostPlatform.isDarwin`, rather than acquiring a Mac copy.
- Hash-pinned packages must be exposed under `packages.<system>` for CI builds.
  Renovate does not update `packages/`; the package-update workflow owns hashes too.
- Avoid instructions, historical incident reports and repeated inventories in comments.
  Keep only non-obvious constraints and the reason for deliberate exceptions.

## Boundaries

- Never patch installed third-party files in venvs/site-packages. Fix the environment
  reproducibly. Package overrides need a concrete defect and removal condition;
  `scripts/check-no-package-patches.sh` enforces reviewed exceptions.
- Mac Homebrew is declarative (`cleanup = "uninstall"`); imperative installs disappear
  on rebuild. Existing GnuPG/pass and the mail setup remain stateful.
- Determinate owns the Mac Nix runtime; configure its supported module, not `nix.settings`.
- `doom/config.org` is the source; `doom/config.el` is tangled output. Read
  `doom/CLAUDE.md` before changing Emacs configuration.
- Keep AI/admin listeners private. Docker publishing is not secured just by the
  NixOS firewall; inspect actual bindings. Do not enable Tailscale Funnel.
- Backup encryption keys and application data are not disposable configuration.
