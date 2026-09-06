{
  lib,
  pkgs,
  ...
}:

let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  # mpv's wrapper loads $out/share/mpv/scripts/<passthru.scriptName>. A fresh derivation
  # rather than a mutation of a nixpkgs package, which check-no-package-patches.sh forbids
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

    # macOS only. mpv defeats the screensaver with IOPMAssertionDeclareUserActivity, which
    # re-activates mpv as the frontmost app; under AeroSpace that forces a workspace switch
    # for every window on a hidden workspace, so a backgrounded video causes a switch storm.
    # stop-screensaver=false stops it and this script holds `caffeinate -d -w <mpv pid>`.
    scripts = lib.optionals isDarwin [ keepawake ];

    config = {
      hwdec = "auto";
      profile = "gpu-hq";
    }
    # vo and gpu-context are Linux-only and BOTH are hostile on macOS: gpu-context=wayland
    # is fatal, and vo=gpu makes gpu-context default to `auto`, which picks the Vulkan/macvk
    # backend. The standalone /Applications/mpv.app that LaunchServices opens files with has
    # no such backend, so it dies with "Error opening/initializing the selected video_out
    # (--vo) device" and no window appears. Unset, each mpv picks its own macOS default.
    // lib.optionalAttrs (!isDarwin) {
      vo = "gpu";
      gpu-context = "wayland";
    }
    // lib.optionalAttrs isDarwin { stop-screensaver = false; };
  };
}
