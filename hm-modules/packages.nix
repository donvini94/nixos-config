# Linux-desktop package set: Wayland/GTK-bound, GUI-only, or deliberately Linux-only.
# Cross-platform CLI tooling lives in cli-tools.nix, which the Mac imports too.
{ pkgs, lib, ... }:

let
  # Bundled koffi.node lacks a libstdc++ runpath. Remove this wrapper when nixpkgs fixes it.
  mattermost-desktop = pkgs.mattermost-desktop.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
    postFixup = ''
      ${old.postFixup or ""}
      wrapProgram $out/bin/mattermost-desktop \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}
    '';
  });

  # The unmodified Deno binary needs nix-ld; see packages/linear-cli.nix.
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
