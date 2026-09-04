-- SbarLua arrives through the wrapped lua5_5 interpreter on the launchd agent's PATH
-- (hosts/ac-0137/ui.nix), so `require("sketchybar")` resolves from LUA_CPATH and the old
-- package.cpath hack pointing at ~/.local/share/sketchybar_lua is gone.

-- The C event providers (cpu_load, network_load, menus) are compiled here, locally, by
-- Xcode CLT clang into the gitignored helpers/**/bin directories — which is why this tree
-- is an out-of-store symlink into the repo and must stay writable. `make` and `clang`
-- come from /usr/bin via environment.systemPath.
os.execute("(cd helpers && make)")
