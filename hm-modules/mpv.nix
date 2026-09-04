{
  lib,
  pkgs,
  ...
}:

let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  # mpv's wrapper takes derivations carrying passthru.scriptName and loads
  # $out/share/mpv/scripts/<scriptName> (nixpkgs pkgs/by-name/mp/mpv/package.nix:13-20,
  # 79-86). This is a fresh runCommandLocal derivation rather than a mutation of an
  # existing nixpkgs package, which scripts/check-no-package-patches.sh forbids
  # repository-wide.
  keepawake =
    pkgs.runCommandLocal "mpv-keepawake-caffeinate"
      {
        passthru.scriptName = "keepawake-caffeinate.lua";
      }
      ''
        install -Dm444 ${./mpv/keepawake-caffeinate.lua} \
          "$out/share/mpv/scripts/keepawake-caffeinate.lua"
      '';
in
{
  programs.mpv = {
    enable = true;
    bindings = {
      l = "seek 5";
      h = "seek -5";
      j = "seek -60";
      k = "seek 60";
      S = "cycle sub";
      f = "cycle fullscreen";
      "[" = "multiply speed 1/1.1";
      "]" = "multiply speed 1.1";
      I = "cycle-values vf 'sub,lavfi=negate' ''";
    };

    # macOS only. mpv defeats the screensaver with IOPMAssertionDeclareUserActivity,
    # which periodically re-activates mpv as the frontmost app; under AeroSpace a window
    # on a hidden workspace becoming frontmost forces a workspace switch, so playing a
    # backgrounded video produces a switch storm. stop-screensaver=false kills the storm
    # and this script holds a passive `caffeinate -d -w <mpv pid>` assertion instead, so
    # the display still stays awake. Neither is needed under Hyprland.
    scripts = lib.optionals isDarwin [ keepawake ];

    config = {
      hwdec = "auto";
      vo = "gpu";
      profile = "gpu-hq";
    }
    # gpu-context=wayland is fatal on macOS; unset, mpv picks the platform context.
    // lib.optionalAttrs (!isDarwin) { gpu-context = "wayland"; }
    // lib.optionalAttrs isDarwin { stop-screensaver = false; };
  };
}
