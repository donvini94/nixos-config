# Pi alongside OMP

Pi is configured beside OMP on AC-0137, dracula and alucard. It owns `~/.pi/agent`; OMP
continues to own `~/.omp` and its existing environment and credentials.

## Initial provisioning and upgrades

`hm-modules/pi.nix` creates `settings.json`, `models.json`, and `mcp.json` only when absent.
They stay writable because Pi changes settings, package declarations, and MCP exposure in place.
Remove one deliberately before a rebuild only when resetting that particular Pi-owned file.

The installed Pi binary remains the existing npm 1.0.0 installation under `~/.local`; this
configuration does not replace it. A future Nix cutover should use a fixed npm tarball plus a
fixed `npmDepsHash` through `pkgs.buildNpmPackage`, expose the resulting wrapper in the user
profile, and switch all three hosts together. Do not mix that wrapper with an imperative npm
installation or copy Pi's package directory into the Nix store.

The bootstrap pins:

- HazAT `pi-interactive-subagents` v3.7.2 at commit `c100577ebf7393a11d098ad9810ec6c269dcfc30`;
- Amos Blomqvist's `ask-user-question.ts` and `web-fetch` at
  `f82da563ab05d66729492d64c7ed4e96db3663f3`.

Amos's web-fetch source is copied once into Pi's private upstream directory and dependencies
are installed with `npm ci --ignore-scripts`. Its original files are never patched. Pi's own
package manager installs the pinned HazAT package after the initial configuration exists:

```sh
pi update --extensions
pi list
```

Run Pi through the normal `pi` shell function. It sets `PI_SUBAGENT_MUX=zellij` only for Pi,
leaving OMP's environment alone. The external editor is `emacsclient -c -a emacs`.

## Credentials and providers

Pi's provider login (`/login`) and Linear MCP login (`pi mcp login linear`) create Pi-owned
credentials. Do not copy OMP auth, refresh tokens, `auth.json`, or `mcp-auth.json`.

On Linux, Pi has the same Requesty/local model endpoints as OMP but sends `X-AI-Caller: pi`.
The configuration sets `authHeader: false`; it contains no credential. AC-0137 uses Pi's
subscription providers through its own login rather than a copied custom endpoint.

Pi's native MCP servers are:

- `nixos` — local `mcp-nixos`;
- `linear` — `https://mcp.linear.app/mcp`, authenticated through Pi OAuth;
- `exa` — `https://mcp.exa.ai/mcp`, unauthenticated fallback already used by OMP.

The Exa server tool is exposed directly as `mcp__exa__web_search_exa`. No Google Custom Search
Engine or new search credential is configured.

## Shared context and resources

`~/.pi/agent/AGENTS.md` is an out-of-store bridge to `pi/AGENTS.md`. It directs Pi to the
existing authoritative OMP AGENTS/RULES and loads topic and `.omp` project context only when
applicable. Pi native MCP and agent terminology replace OMP-internal URIs.

The mentor, prompt snippets and learning repositories are local Pi packages under `~/code`.
Their source remains editable and visible to both harnesses. Pi's mentor skill is additionally
linked at `~/.pi/agent/skills/mentor/SKILL.md`. Managed calendar/meeting skills and Zotero CLI
are added explicitly; `~/.agents/skills` already supplies the shared Lathe and language skills,
so they are not duplicated.

## Curated memory

Pi receives exactly the 15 curated global records from
`~/.codex/omp-memory-snapshot/global.md` once, as
`~/.pi/agent/memory/curated-global.md` with mode `0600`. The manifest records its provenance.
Pi reads it on demand and writes only its own Markdown notes below `~/.pi/agent/memory/notes/`.
No OMP memory bank, project memory, database or transcript is imported.

On a host where the Codex snapshot does not exist, transfer only the already-created Pi-owned
`curated-global.md` from an existing host, then set mode `0600`; do not transfer OMP databases.

## Deployment checks

After applying the host configuration, use:

```sh
pi --version
pi list
pi mcp list
pi --list-models
```

Use `/mcp login linear` for the independent OAuth login. Check the active direct Exa tool with
`/mcp`; its name is `mcp__exa__web_search_exa`.

## Keeping the hosts identical

Skills, plugins and interface settings are declared once and reach every host on its next
switch (`darwin-rebuild` on AC-0137, `nixos-rebuild` on dracula and alucard):

| What | Source of truth | Mechanism |
|---|---|---|
| Authored and vendored skills | `skills/shared/` | `hm-modules/agent-skills.nix` links each into `~/.agents/skills/`, which OMP, Pi and Codex all read |
| Skills OMP's `manage_skill` maintains | `skills/managed/` | linked into `~/.omp/agent/managed-skills/`; Pi's `skills` setting reads the same directory |
| Lathe skills | `packages/lathe.nix` | linked into `~/.agents/skills/` from the pinned binary |
| Pi settings, MCP servers, models | `hm-modules/pi.nix` | merged into the live JSON on every activation; declared keys win, arrays are replaced |
| OMP interface (theme, status line, composer, edit mode, splash) | `omp/config-common.nix` | overlay on every host |
| OMP learning plugin | marketplace `donvini94/omp-learn` | idempotent install in `hm-modules/omp.nix` |
| `omp-learn`, `omp-mentor`, `omp-prompt-snippets` | their GitHub repos | `git pull --ff-only` over HTTPS on every switch; dirty checkouts are reported, not touched |

To change a skill, edit it under `skills/` and commit; hosts get it by pulling this repository and
switching. Do not use `npx skills` or `pi install` for anything that should exist on all hosts;
declare it here, because the next switch replaces hand-installed Pi packages.

Zotero: the `zotero-cli` skill is vendored for every host, but the CLI itself (`zotero-mcp-server`,
pinned in `hm-modules/zotero-cli.nix`) is installed on the hosts that run the Zotero app, AC-0137 and
dracula. Approve it once per host with `zotero-mcp authorize-local` while Zotero is open; the key
stays on that host.

## Updating everything with one command

`agent-update` (installed on every host by `hm-modules/agent-skills.nix`) refreshes everything in
this repository that has an upstream:

```sh
agent-update check     # what is out of date; changes nothing
agent-update apply     # refresh vendored skills and pins, upgrade OMP plugins here
agent-update all       # apply, commit, push, then roll out to every host
```

Areas can be named (`agent-update apply skills pins`): `skills` (vendored skills from
`skills/sources.json`), `plugins` (OMP marketplace plugins), `pins` (Pi binary, HazAT subagents,
Amos extensions, with their hashes) and `omp` (the OMP release pinned for the Linux hosts). Roll-out
pushes to origin, then fast-forwards `~/nixos-config` on dracula and alucard over ssh and runs the
passwordless switch, and finally switches this Mac, which asks for your password. A host with
uncommitted changes is reported and skipped. Only the update-owned paths are committed, so unrelated
work in the repository is left alone. Run it from the Mac, which holds the pins and the git remote.

Authored skills (`aisec`, `isc-rules`, `python`, `rust`, `debt-ledger`, `delete-list`) have no
upstream and are never touched. To vendor a new third-party skill, add it to `skills/sources.json`
and run `agent-update apply skills`.

OMP's own binary is pinned in `packages/omp.nix`; AC-0137 self-updates. `agent-update` moves the
pin to the latest release, so run it when the Mac updates or the interface will differ between
machines.
