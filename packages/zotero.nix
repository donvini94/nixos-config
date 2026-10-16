{ pkgs }:
let
  # Zotero's XULRunner modifications require ESR 140, not nixpkgs' ESR 153.
  firefox =
    (pkgs.firefox-bin-unwrapped.override {
      generated = {
        version = "140.17.0esr";
        sources = [
          {
            arch = "linux-x86_64";
            locale = "en-US";
            url = "https://archive.mozilla.org/pub/firefox/releases/140.17.0esr/linux-x86_64/en-US/firefox-140.17.0esr.tar.xz";
            sha256 = "sha256-htBJBwrYC3TY5nR5PiLSiSO0p6HaBrTWVAL5HGehAxQ=";
          }
        ];
      };
    }).overrideAttrs
      (old: {
        installPhase = pkgs.lib.replaceStrings [ "firefox-bin-140.17.0esr" ] [ "firefox" ] old.installPhase;
      });
in
pkgs.zotero.override { firefox-esr-153-unwrapped = firefox; }
