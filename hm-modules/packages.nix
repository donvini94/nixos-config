# Linux-desktop package set: Wayland/GTK-bound, GUI-only, or deliberately Linux-only.
# Cross-platform CLI tooling lives in cli-tools.nix, which the Mac imports too.
{ pkgs, lib, ... }:

let
  # mattermost-desktop's bundled koffi.node (native tray/badge FFI, under
  # app.asar.unpacked/node_modules/@koromix) links against libstdc++.so.6 with
  # no runpath to it: nixpkgs' fixup only autoPatchelfs paths outside the
  # asar, so this native module is missed and the app dies on load with
  # "libstdc++.so.6: cannot open shared object file". Wrap the launcher with
  # LD_LIBRARY_PATH instead of patching the store output by hand.
  mattermost-desktop = pkgs.mattermost-desktop.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
    postFixup = ''
      ${old.postFixup or ""}
      wrapProgram $out/bin/mattermost-desktop \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}
    '';
  });

  # linear-cli's binary is a `deno compile` standalone executable: it locates its own
  # bundled JS via /proc/self/exe plus a trailer appended past the ELF image, so it
  # can't be patchelf'd (see packages/linear-cli.nix for what that breaks and why).
  # hosts/dracula/services.nix enables nix-ld so the raw, untouched binary below runs as
  # a normal kernel-exec'd ELF with no wrapper needed here.
  linear-cli = pkgs.callPackage ../packages/linear-cli.nix { };
in
{
  home.packages = with pkgs; [
    mupdf

    # The hledger closure is Haskell-heavy (~900 MiB download, ~6 GiB unpacked);
    # deliberately not on the Mac.
    hledger
    hledger-ui
    hledger-utils
    hledger-interest
    hledger-web

    zed-editor
    zeal
    bruno
    aider-chat
    warp-terminal
    claude-agent-acp
    chromium
    linear-cli

    texliveMedium

    nsxiv

    anki
    zotero
    zoom-us

    qolibri

    discord
    telegram-desktop
    thunderbird
    slack
    signal-desktop
    teams-for-linux
    mattermost-desktop
  ];
}
