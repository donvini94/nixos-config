# SketchyBar + JankyBorders as nix-darwin launchd agents (labels org.nixos.sketchybar and
# org.nixos.jankyborders), replacing `brew services`.
#
# Both are byte-identical versions to what Homebrew had installed — sketchybar 2.24.0 and
# jankyborders 1.9.0 at the locked nixpkgs — so this is a supervision change, not an
# upgrade.
#
# AeroSpace deliberately stays a cask (see ./homebrew.nix): nixpkgs is at 0.20.3-Beta
# against the installed 0.21.3-Beta, and a stable /Applications path keeps its
# Accessibility grant. That is why the Lua in ./sketchybar/ calls
# /opt/homebrew/bin/aerospace by absolute path — the agent's PATH is
# [package] ++ extraPackages ++ environment.systemPath
# (nix-darwin/modules/services/sketchybar/default.nix:50), which has no brew prefix.
# Everything else the bar shells out to — pmset, osascript, networksetup, ipconfig, awk,
# pbcopy, open, killall, make, clang — resolves from environment.systemPath, which ends in
# /usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin.
{ pkgs, ... }:

let
  # sketchybarrc is Lua and SbarLua must be importable as `require("sketchybar")`.
  # nixpkgs' sbarlua is a lua55Packages.buildLuaPackage installing into
  # $out/lib/lua/5.5, so a wrapped interpreter carries it on LUA_CPATH — no
  # ~/.local/share/sketchybar_lua, no package.cpath hack in helpers/init.lua.
  luaEnv = pkgs.lua5_5.withPackages (_: [ pkgs.sbarlua ]);
in
{
  services.sketchybar = {
    enable = true;
    # `config` left empty on purpose. Set, the module passes --config <store path>, and
    # sketchybar would then resolve $CONFIG_DIR to /nix/store — breaking both
    # `require("helpers")` and helpers/init.lua's `(cd helpers && make)`, which needs a
    # writable tree. Empty, sketchybar reads ~/.config/sketchybar/sketchybarrc, which
    # home-manager points at the repo via mkOutOfStoreSymlink (./apps.nix).
    extraPackages = [
      luaEnv
      pkgs.nowplaying-cli # items/media.lua click scripts
      pkgs.switchaudio-osx # items/widgets/volume.lua
    ];
  };

  # Values are exactly the retired ~/.config/borders/bordersrc options block.
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
