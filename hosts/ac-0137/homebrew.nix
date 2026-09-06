# nixpkgs provides every tool this repo already declares (hm-modules/, packages/) and
# wins wherever both could supply one; Homebrew keeps toolchains, macOS-integrated tools,
# GUI casks and anything with no nixpkgs equivalent.
#
# cleanup = "uninstall" makes this file the truth: an imperative `brew install` is
# reverted on the next `darwin-rebuild switch`. Deliberately not "zap", which deletes
# application data and configuration along with the app.
#
# The lists are `brew leaves`, not `brew list`: a kept formula's own dependencies stay
# with Homebrew's resolver, so cleanup never removes something still needed.
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

    # Hand-downloaded apps in /Applications (Ghostty, Zed, Chrome, Slack, Firefox
    # Developer Edition, …) are not adopted: `brew install --cask` fails against a
    # pre-existing unmanaged app bundle.
    #
    # aerospace stays a cask: the locked nixpkgs has 0.20.3-Beta against the installed
    # 0.21.3-Beta, and an /Applications path keeps its Accessibility grant stable.
    # emacs-plus-app likewise — Emacs on this host is not the nixpkgs build. font-iosevka
    # is the plain `Iosevka` family (not `Iosevka Nerd Font`) and Doom's font stack may
    # reference it.
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
