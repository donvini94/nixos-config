# Declarative Homebrew for AC-0137.
#
# The split rule, applied literally: nixpkgs provides every tool this repo already
# declares (hm-modules/, packages/), Homebrew keeps toolchains, macOS-integrated tools,
# GUI casks, and anything with no nixpkgs equivalent. Where both could supply a tool, the
# nix one wins because it is the one that is version-locked and shared with dracula.
#
# The lists are `brew leaves` output, not `brew list`: computed dependencies of a retained
# formula (lua for nmap, for instance) are left to Homebrew's resolver, so
# cleanup = "uninstall" never removes something a kept formula needs.
#
# cleanup = "uninstall" makes this file the truth: an imperative `brew install` is
# reverted on the next `darwin-rebuild switch`. That is the point. It is deliberately not
# "zap" — zap deletes application data and configuration as well as the app.
{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "uninstall";
    };
    global = {
      brewfile = true;
      autoUpdate = false;
    };

    taps = [
      "nikitabobko/tap" # aerospace cask
      "d12frosted/emacs-plus" # emacs-plus-app cask
      "sailpoint-oss/tap" # sailpoint-cli
      "dhth/tap" # hours
      "ldayton/dippy" # dippy
    ];

    # Toolchains (rustup, openjdk, maven, cmake, automake, clang-format), macOS-integrated
    # tools (pinentry-mac, pngpaste, mole), the mail stack (isync/msmtp/mu/notmuch —
    # explicitly out of scope), the gnupg/pass stack, and the client/work CLIs.
    #
    # pass and pinentry-mac stay on Homebrew on purpose: moving them pulls a second gnupg
    # into ~/.gnupg and agent-socket territory, and hm-modules/git.nix signs commits with
    # signing.format = "openpgp".
    brews = [
      "ansible"
      "autojump"
      "automake"
      "azure-cli"
      "clang-format"
      "cloudflared"
      "cmake"
      "cmake-docs"
      "coreutils"
      "curl"
      "dockerfmt"
      "feh"
      "ffmpegthumbnailer"
      "ghostscript"
      "gomodifytags"
      "gopls"
      "gotests"
      "grep"
      "grip"
      "hf"
      "imagemagick"
      "isort"
      "isync"
      "libxft"
      "maven"
      "media-info"
      "mole"
      "msmtp"
      "mu"
      "mupdf"
      "nmap"
      "nnn"
      "notmuch"
      "nushell"
      "opencode"
      "openjdk@17"
      "openstackclient"
      "pass"
      "pigz"
      "pinentry-mac"
      "pipenv"
      "pipx"
      "pngpaste"
      "pytest"
      "rtk"
      "rustup"
      "sevenzip"
      "sqlcmd"
      "wget"
      "wordnet"
      "wtf"
      "dhth/tap/hours"
      "ldayton/dippy/dippy"
      "sailpoint-oss/tap/sailpoint-cli"
    ];

    # Only casks Homebrew already installed are declared. Hand-downloaded apps in
    # /Applications (Ghostty, Zed, Chrome, Slack, Firefox Developer Edition, …) are NOT
    # adopted: `brew install --cask` fails against a pre-existing unmanaged app bundle,
    # and their configuration is managed in ./apps.nix anyway.
    #
    # aerospace stays a cask by decision — the locked nixpkgs has 0.20.3-Beta against the
    # installed 0.21.3-Beta, and an /Applications path keeps its Accessibility grant
    # stable. emacs-plus-app likewise: Emacs on this host is not the nixpkgs build.
    # font-iosevka is the plain `Iosevka` family (not `Iosevka Nerd Font`) and stays
    # because Doom's font stack may reference it.
    casks = [
      "aerospace"
      "copilot-cli"
      "emacs-plus-app"
      "iina"
      "libreoffice"
      "music-decoy"
      "musiver"
      "sf-symbols"
      "submariner"
      "wave"
      "font-iosevka"
      "font-sf-mono"
      "font-sf-pro"
    ];
  };
}
