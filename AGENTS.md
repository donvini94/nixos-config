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
- The agent deploys affected hosts after committing, pushing and synchronizing;
  do not leave switching to the user unless explicitly asked not to deploy.
  Passwordless sudo requires these exact commands (tested on both hosts):
  `ssh dracula 'sudo -n /run/current-system/sw/bin/nixos-rebuild switch --flake /home/vincenzo/nixos-config#dracula'`
  `ssh alucard 'sudo -n /run/current-system/sw/bin/nixos-rebuild switch --flake /home/vincenzo/nixos-config#alucard'`
  `sudo -n /run/current-system/sw/bin/darwin-rebuild switch --flake /Users/vincenzopace/nixos-config#AC-0137`
  (the Mac, run locally). Relative flake paths are not authorized. No PTY or sudo password is needed.
- Read runtime logs before diagnosing configuration. A successful evaluation does not
  prove a service works. Do not expose secrets while collecting evidence.
- Questions are not authorization to edit. Answer "how/why/should" questions and stop;
  wait for an explicit request to apply the change.
- Do not retire live services or delete application data without approval.

## Placement

- Host-specific wiring: `hosts/<host>/`. Shared system functionality: `modules/`.
  Features spanning NixOS, home-manager and packages get one folder: `ai/` (the customer-deployable stack, self-contained; it will become its own flake),
  `coding-agents/` (personal OMP/Pi tooling), `transcription/` and `mail/`.
- User configuration: `hm-modules/`; home files are import manifests plus identity.
- Cross-platform CLI packages: `hm-modules/cli-tools.nix`. Linux GUI packages:
  `hm-modules/packages.nix`. System packages are for integration/toolchains.
- Darwin-only configuration stays in `hosts/ac-0137/`; shared modules branch on
  `pkgs.stdenv.hostPlatform.isDarwin`, rather than acquiring a Mac copy.
- OMP and Pi are independently enabled with `programs.ompClient.enable` and
  `programs.piClient.enable`. Client modules own their settings and state; shared
  source packages live in `coding-agents/home/agent-content.nix`, guidance in `coding-agents/guidance/`.
- Hash-pinned packages must be exposed under `packages.<system>` for CI builds.
  Renovate does not update `packages/` or `coding-agents/packages/`; the package-update workflow owns hashes too.
- Keep comments for non-obvious constraints and deliberate exceptions. No AI audit
  labels, historical incident reports, repeated inventories or line-by-line narration.
- Keep substantial shell/Python programs in source files, not Nix strings. Nix wires
  packages, arguments and services; short wrappers and genuinely generated code stay inline.
  Use `writeShellApplication` with explicit runtime dependencies for owned shell tools.

## Boundaries

- Never patch installed third-party files in venvs/site-packages. Fix the environment
  reproducibly. Use conventional Nix overrides when needed; test the resulting package.
- Mac Homebrew is declarative (`cleanup = "uninstall"`); imperative installs disappear
  on rebuild. Existing GnuPG/pass and the mail setup remain stateful.
- Determinate owns the Mac Nix runtime; configure its supported module, not `nix.settings`.
- `doom/config.org` is the source; `doom/config.el` is tangled output. Read
  `doom/CLAUDE.md` before changing Emacs configuration.
- Keep AI/admin listeners private. Docker publishing is not secured just by the
  NixOS firewall; inspect actual bindings. Do not enable Tailscale Funnel.
- Backup encryption keys and application data are not disposable configuration.
