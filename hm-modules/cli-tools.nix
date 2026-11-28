# CLI tools shared by Linux and Darwin.
{
  lib,
  pkgs,
  site,
  ...
}:

let
  # The host's machine identity (Universal Auth): the Keychain on the Mac, sops-nix on
  # Linux (hosts/dracula). Hosts without one fall back to the CLI's own `infisical login`.
  credential =
    name:
    if pkgs.stdenv.hostPlatform.isDarwin then
      "/usr/bin/security find-generic-password -s infisical-universal-auth -a ${name} -w 2>/dev/null"
    else
      "cat /run/secrets/infisical/${name} 2>/dev/null";
  infisical = pkgs.writeShellApplication {
    name = "infisical";
    text = ''
      export INFISICAL_DOMAIN="''${INFISICAL_DOMAIN:-https://${site.server}.${site.tailnet}:28200}"
      export INFISICAL_DISABLE_TELEMETRY=1
      if [ -z "''${INFISICAL_TOKEN:-}" ] && id=$(${credential "client_id"}) && secret=$(${credential "client_secret"}); then
        INFISICAL_TOKEN=$(${lib.getExe pkgs.infisical} login --method=universal-auth \
          --client-id="$id" --client-secret="$secret" --silent --plain)
        export INFISICAL_TOKEN
      fi
      exec ${lib.getExe pkgs.infisical} "$@"
    '';
  };
in
{
  home.packages = with pkgs; [
    infisical
    ripgrep-all
    television
    entr
    lnav

    csvlens
    graphviz
    pandoc

    aria2

    cht-sh
    tldr

    bun
    # Doom :term ghostel compiles its native module with zig (M-x ghostel-module-compile).
    zig
    # lazygit backs the `lg` abbreviation in hm-modules/fish.nix.
    lazygit
    delta
    difftastic
    gh
    leetcode-cli
    wakatime-cli
    codecrafters-cli
    devbox
    devenv

    # The nil language server lives in lsp.nix.
    nix-output-monitor
    nixfmt

    (tree-sitter.withPlugins (g: [
      g.tree-sitter-rust
      g.tree-sitter-haskell
      g.tree-sitter-python
      g.tree-sitter-bash
      g.tree-sitter-typst
    ]))

    typst
    tinymist
    hunspell
    hunspellDicts.en_US
    hunspellDicts.de_DE
    vale
    proselint

    dockfmt
    dockerfile-language-server

    html-tidy
    js-beautify
    stylelint

    exercism
    ranger
    jq
    yq-go
    yt-dlp
    poppler-utils
    glow

    mecab
    kakasi
    cmigemo
    ani-cli
  ];
}
