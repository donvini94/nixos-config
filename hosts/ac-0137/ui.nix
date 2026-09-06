{ pkgs, ... }:

let
  # sketchybarrc is Lua and SbarLua must be importable as `require("sketchybar")`.
  # nixpkgs' sbarlua installs into $out/lib/lua/5.5, so a wrapped interpreter carries it
  # on LUA_CPATH — no ~/.local/share/sketchybar_lua, no package.cpath hack in
  # helpers/init.lua.
  luaEnv = pkgs.lua5_5.withPackages (_: [ pkgs.sbarlua ]);
in
{
  # The agent's PATH is [package] ++ extraPackages ++ environment.systemPath
  # (nix-darwin/modules/services/sketchybar/default.nix:50) and has no Homebrew prefix, so
  # the Lua in ./sketchybar/ calls /opt/homebrew/bin/aerospace by absolute path.
  # Everything else the bar shells out to (pmset, osascript, networksetup, ipconfig, awk,
  # pbcopy, open, killall, make, clang) resolves from environment.systemPath.
  services.sketchybar = {
    enable = true;
    # `config` left empty on purpose. Set, the module passes --config <store path> and
    # sketchybar resolves $CONFIG_DIR to /nix/store, breaking both `require("helpers")`
    # and helpers/init.lua's `(cd helpers && make)`, which needs a writable tree. Empty,
    # sketchybar reads ~/.config/sketchybar/sketchybarrc, which home-manager points at the
    # repo via mkOutOfStoreSymlink (./apps.nix).
    extraPackages = [
      luaEnv
      pkgs.nowplaying-cli # items/media.lua click scripts
      pkgs.switchaudio-osx # items/widgets/volume.lua
    ];
  };

  services.jankyborders = {
    enable = true;
    style = "round";
    width = 6.0;
    hidpi = true;
    active_color = "0xff2fafff";
    inactive_color = "0x40646464";
    background_color = "0x20000000";
  };
}
