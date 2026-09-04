# Everything that was hand-written in ~/.config/fish/config.fish and the non-fisher
# conf.d files on this machine.
#
# Dropped from the copied config on purpose, because a shared module already does it:
#   * `zoxide init fish | source` and `alias cd z` — hm-modules/shell.nix sets
#     programs.zoxide.enableFishIntegration and hm-modules/fish.nix has the `cd = "z"` abbr.
#   * `source ~/.cargo/env.fish` (conf.d/rustup.fish) — hm-modules/fish.nix puts
#     ~/.cargo/bin on home.sessionPath, which is all that file did.
#   * `fish_add_path ~/.nix-profile/bin` — that existed only to reach an imperatively
#     installed nixd. hm-modules/lsp.nix now owns nixd and home-manager routes it through
#     /etc/profiles/per-user/$USER via home-manager.useUserPackages.
#   * the abbreviations already in hm-modules/fish.nix (vim, e, nano, bereit, arr, dr,
#     py, lg, cheat, c, ccs, cct) and `y`, which programs.yazi's shellWrapperName provides.
#
# Still stateful and NOT declared here: conf.d/leafcloud.fish holds a plaintext OpenStack
# password and must never enter the repo, and conf.d/{_tide_init,autopair,done,fzf,z}.fish
# belong to fisher.
{ ... }:

{
  home.sessionPath = [
    "$HOME/.bun/bin"
    "$HOME/.lmstudio/bin"
    "$HOME/Library/Python/3.9/bin"
    "$HOME/.antigravity/antigravity/bin"
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "zed";
    ANI_CLI_PLAYER = "mpv";
    BUN_INSTALL = "$HOME/.bun";
    SOPS_AGE_KEY_FILE = "$HOME/.config/sops/age/keys.txt";
  };

  programs.fish.shellAbbrs = {
    acgpt-up = "openstack server unshelve d94fd33f-6907-4d47-9929-ea785a78676d";
    acgpt-down = "openstack server shelve d94fd33f-6907-4d47-9929-ea785a78676d";
    # Typo catcher kept from conf.d/aliases.fish.
    zayi = "yazi";
  };

  programs.fish.interactiveShellInit = ''
    # OrbStack CLI integration (installed by the app, not by nix).
    test -r ~/.orbstack/shell/init2.fish; and source ~/.orbstack/shell/init2.fish

    # emacs-libgccjit-fix
    #
    # Help emacs-plus's bundled libgccjit find Homebrew gcc's runtime libs.
    #
    # `emacs-plus-app' (a prebuilt Homebrew *cask*) bundles libgccjit v15. When
    # Homebrew's gcc rolls to a new major (e.g. 15 -> 16) and removes the old keg,
    # the bundled libgccjit can no longer find gcc's runtime libs (libemutls_w.a,
    # libgcc, crt*) and native compilation fails with:
    #   ld: library 'emutls_w' not found  /  error invoking gcc driver
    #
    # gcc's driver folds LIBRARY_PATH into the linker's -L search. Crucially, this
    # env var is INHERITED by the child `emacs --batch' processes that compile subr
    # trampolines during Doom startup / `doom sync' -- they run before any Doom Lisp
    # loads, so this must be set in the shell, not in Doom config.
    #
    # We anchor on libemutls_w.a itself (the lib that goes missing): its directory
    # is exactly the -L we need. `find -L' follows Homebrew's symlinked gcc subdirs.
    # Version-robust (self-heals across gcc major bumps).
    if test -d /opt/homebrew/lib/gcc
        set -l _gccdirs
        # dir holding libemutls_w.a / libgcc.a / crt*.o (the triplet dir)
        for f in (find -L /opt/homebrew/lib/gcc -name libemutls_w.a 2>/dev/null)
            set -a _gccdirs (dirname $f)
        end
        # top-level versioned dir (libgcc_s, libgomp, ...)
        set -a _gccdirs (find -L /opt/homebrew/lib/gcc -maxdepth 1 -type d -name '[0-9]*' 2>/dev/null)
        if set -q _gccdirs[1]
            set --global --export --path LIBRARY_PATH $_gccdirs $LIBRARY_PATH
        end
        set -e _gccdirs
    end
  '';
}
