# Mac handoff — replicate the Linux (dracula) Claude Code cleanup

Goal: bring the Mac (`bereitbook-pro-m4`) to the same state we set up on dracula —
**ECC removed, learning-opportunities installed, only `memory/` synced, harness owned
in `nixos-config/claude/`, and the ccstatusline statusline**. Written 2026-08-08.

You can hand this whole file to Claude Code on the Mac and work through it, or run the
commands yourself. All paths use `$HOME`, so they work despite `/Users/vincenzopace`
vs `/home/vincenzo`.

---

## ✅ STATUS: executed on the Mac 2026-08-08 — read the corrections below first

This ran successfully, but **five steps were wrong as written**. Corrections are recorded
here because this file is the template for any future machine.

1. **🐛 Step 2's strip script deletes the RTK hook.** The predicate
   `keep = ("rtk-rewrite.sh" in c) or ("block-no-verify" in c)` matches neither of the
   Mac's real hooks — it uses rtk's native subcommand `rtk hook claude` (rtk ≥ 0.24), plus
   `dippy`. Running it as written leaves only `block-no-verify` and silently kills RTK.
   **Match on intent, print what you dropped:**
   ```python
   MINE = ("rtk hook", "rtk-rewrite.sh", "dippy", "block-no-verify")
   keep = lambda c: any(m in c for m in MINE)
   ```
   Also strip only the `ECC_*` keys from `env`, not the whole `env` block.
2. **Step 6's Syncthing order is backwards.** Narrow `.stignore` to `!/memory` **first**,
   force a rescan, verify via `/rest/db/ignores`, *then* delete locally. Ignored paths are
   neither sent nor received, so the delete can never reach the peer. The order as written
   deliberately fires a cross-machine delete for no benefit.
3. **Step 0's backup path is wrong.** `~/.claude` is not a symlink on the Mac — it *is* the
   Syncthing folder root (`.stfolder/` lives inside). Back up `.claude` itself and exclude
   `plugins/`, `projects/`, `.stversions/` or you get a >1.2 GB tarball (7.2 MB with them
   excluded).
4. **Step 1 (`git pull`) was a no-op** — the harness tree was local, staged, and never
   committed. It needed a *commit*, not a pull.
5. **Step 7 over-deletes.** `sessions/`, `file-history/`, `ide/`, `shell-snapshots/`,
   `paste-cache/`, `debug/`, `downloads/`, `mcp-configs/`, `cache/` and `history.jsonl` are
   Claude Code's own state, not ECC's — deleting them costs prompt history and edit-undo
   history for no disk gain. It also **misses** real ECC debris: `~/.claude/README.md`
   ("Plugin Manifest Gotchas"), `plugins/marketplaces/everything-claude-code`, and
   `plugins/cache/ecc` — which together were ~456 MB, the actual disk win.

Also worth knowing: **Step 4 was a no-op** (official plugins already loaded), the
`learning-opportunities` marketplace was already registered, and `settings.local.json`
should be *edited* to drop its one `mcp__plugin_ecc_*` permission rather than deleted —
its other entries are real.

**Divergence to keep:** the Mac uses `rtk hook claude`; dracula still uses
`hooks/rtk-rewrite.sh`. Don't delete the script from the repo until dracula's
`settings.json` is switched over, or dracula's hook breaks.

## Guiding principle
- **Machine-independent → shared/owned:** `memory/` syncs via Syncthing; authored config
  (`CLAUDE.md`, `RTK.md`, `rules/`, `skills/`, `agents/`, statusline) lives in
  `nixos-config/claude/` (git).
- **Machine-dependent → local & disposable:** `settings.json`, `plugins/`, credentials,
  transcripts, caches. These are **not synced** — the Mac has its own, and its
  `settings.json` still contains all the ECC hooks. That's why this handoff is needed.

## Context you'll want
- `~/.claude` is a symlink into the Syncthing folder (same as dracula). Confirm with
  `ls -ld ~/.claude`.
- `settings.json` is NOT synced → the Mac's copy is still full of ECC hooks + `ECC_*` env.
- The Mac's plugin paths are the *native* `/Users/vincenzopace/...` ones, so official
  plugins may still load there (unlike dracula, where they were broken Mac paths).
- On the Mac, the old `ccline` statusline binary is the *correct* arch and works — but we're
  switching to `ccstatusline` for parity with dracula.

---

## Step 0 — Back up first (full rollback)
```bash
tar czf "$HOME/claude-config-backup-mac-$(date +%Y%m%d-%H%M%S).tar.gz" -C "$HOME" Claude
```
(Adjust `Claude` if `readlink ~/.claude` points elsewhere.)

## Step 1 — Get the repo (authored harness is already committed there)
On the Mac, in your nixos-config checkout:
```bash
git pull        # brings in claude/ (CLAUDE.md, RTK.md, rules, skills, agents, statusline)
                # and hm-modules/claude.nix
```

## Step 2 — Remove ECC (plugin, marketplace, files, hooks)
```bash
claude plugin uninstall ecc@ecc
claude plugin marketplace remove ecc

cd "$HOME/.claude"
# loose ECC installs + state (these were symlinks/copies from the ecc marketplace)
rm -rf agents commands skills homunculus .agents ecc scripts \
       plugins/marketplaces/ecc plugins/marketplaces/everything-claude-code
# ECC-dropped top-level files (verify first: they start with "Everything Claude Code")
rm -f AGENTS.md the-security-guide.md gsd-file-manifest.json \
      plugin.json marketplace.json PLUGIN_SCHEMA_NOTES.md \
      hooks/hooks.json hooks/README.md
```

Strip ECC hooks + `ECC_*` env from `settings.json` (keeps only the RTK hook +
block-no-verify):
```bash
python3 - <<'PY'
import json, os
p = os.path.expanduser("~/.claude/settings.json")
d = json.load(open(p))
d.pop("env", None)  # ECC_GATEGUARD / ECC_DISABLED_HOOKS
keep = lambda c: ("rtk-rewrite.sh" in c) or ("block-no-verify" in c)
pre = []
for g in d.get("hooks", {}).get("PreToolUse", []):
    hk = [h for h in g.get("hooks", []) if keep(h.get("command",""))]
    if hk: pre.append({**g, "hooks": hk})
d["hooks"] = {"PreToolUse": pre} if pre else {}
json.dump(d, open(p,"w"), indent=2); open(p,"a").write("\n")
print("stripped ECC hooks; kept:", [h["hooks"][0]["command"] for h in pre])
PY
```

## Step 3 — Install the learning skill (the one third-party tool we kept)
```bash
claude plugin marketplace add https://github.com/DrCatHicks/learning-opportunities.git
claude plugin install learning-opportunities@learning-opportunities
claude plugin install learning-opportunities-auto@learning-opportunities
claude plugin install orient@learning-opportunities
```

## Step 4 — Official plugins (docs + LSPs)
On the Mac these may already load. Verify, and (re)install if needed:
```bash
claude plugin list        # look for cache-miss / failed to load
# if the official marketplace is broken or missing:
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin install context7@claude-plugins-official
claude plugin install rust-analyzer-lsp@claude-plugins-official
claude plugin install pyright-lsp@claude-plugins-official
```

## Step 5 — Statusline (ccstatusline, same as dracula)
```bash
# point Claude Code at ccstatusline (Mac has node)
python3 - <<'PY'
import json, os
p=os.path.expanduser("~/.claude/settings.json"); d=json.load(open(p))
d.pop("statusLine", None)   # drop the old ccline entry
d["statusLine"]={"type":"command","command":"npx -y ccstatusline@latest",
                 "padding":0,"refreshInterval":10}
json.dump(d,open(p,"w"),indent=2); open(p,"a").write("\n"); print("statusLine set")
PY
# use the SAME widget config we built (context% / tokens / session-cost / git,
# and line 2: session-usage / weekly-usage / weekly-reset)
mkdir -p "$HOME/.config/ccstatusline"
cp "$HOME/nixos-config/claude/ccstatusline-settings.json" \
   "$HOME/.config/ccstatusline/settings.json"
# optional: remove the old mac ccline binary
rm -rf "$HOME/.claude/ccline"
```

## Step 6 — Own the harness + memory-only sync (Nix path vs manual)

**If the Mac uses this repo via nix-darwin / home-manager:**
1. Ensure `home.nix` imports `./hm-modules/claude.nix` (it symlinks CLAUDE.md, RTK.md,
   rules, skills, agents, hooks/rtk-rewrite.sh via `mkOutOfStoreSymlink`, and writes the
   memory-only `.stignore`).
2. Confirm `mkOutOfStoreSymlink` targets resolve on macOS — the module uses
   `${config.home.homeDirectory}/nixos-config/claude`, so the checkout must live at
   `$HOME/nixos-config`. Adjust the path in `claude.nix` if your Mac checkout differs.
3. `darwin-rebuild switch --flake .#<machine>` (or `home-manager switch`).
   Existing real files get backed up to `*.hm-backup`.

**If the Mac does NOT nix-manage `~/.claude`:** do it manually:
```bash
cd "$HOME/.claude"
for f in CLAUDE.md RTK.md rules skills agents; do rm -rf "$f"; \
  ln -s "$HOME/nixos-config/claude/$f" "$f"; done
ln -sf "$HOME/nixos-config/claude/hooks/rtk-rewrite.sh" hooks/rtk-rewrite.sh
# memory-only Syncthing whitelist
printf '!/memory\n*\n' > "$HOME/.claude/.stignore"
```

> ⚠️ Order matters for Syncthing: the OLD `.stignore` still syncs `agents/ commands/
> skills/ CLAUDE.md rules/`. Deleting those on the Mac will propagate to dracula. That's
> fine — dracula already re-derives them from the repo — but do the deletions, let
> Syncthing settle, *then* switch `.stignore` to memory-only.

## Step 7 — Fresh-start cleanup (keep only memory + working config)
```bash
cd "$HOME/.claude"
rm -rf cache backups metrics file-history session-data shell-snapshots session-env \
       sessions paste-cache debug ide downloads mcp-configs
rm -f  cost-tracker.log bash-commands.log hook-approvals.log history.jsonl \
       settings.local.json settings.json.bak settings.json.bak-* *.hm-backup
rm -rf rules.hm-backup
find . -maxdepth 1 -name '*sync-conflict*' -delete
# transcripts of the OTHER machine (dracula-encoded) are foreign here:
rm -rf -- ./projects/-home-vincenzo ./projects/-home-vincenzo-nixos-config 2>/dev/null
```
Do NOT delete: `memory/`, `settings.json`, `.credentials.json`, `plugins/`, `.stfolder/`,
the symlinks, and any `projects/*/memory/` you want to keep.

## Step 8 — Verify, then restart Claude Code
```bash
claude plugin list | grep -E "@|Status"     # ecc gone; learning + official enabled
python3 -c "import json;d=json.load(open('$HOME/.claude/settings.json'));\
print('hooks:',[h['hooks'][0]['command'] for h in d['hooks'].get('PreToolUse',[])]);\
print('statusLine:',d.get('statusLine',{}).get('command'))"
ls -l ~/.claude/CLAUDE.md ~/.claude/rules     # should be symlinks into nixos-config/claude
```
Restart Claude Code. The statusline (with session/weekly usage) and the learning skill
should be active.

## Notes
- **opencode** (for the local-LLM work): ccstatusline is Claude-Code-only. Use its
  counterpart `ocstatusline` (https://github.com/amirlehmam/ocstatusline) inside opencode
  for a matching look.
- Commit any Mac-specific `claude.nix` path tweaks back to the repo.
- Rollback anytime from the Step-0 tarball.
