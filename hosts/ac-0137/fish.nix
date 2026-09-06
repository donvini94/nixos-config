# Handled by a shared module, so deliberately absent here:
#   * `zoxide init fish | source` and `alias cd z` — hm-modules/shell.nix sets
#     programs.zoxide.enableFishIntegration and hm-modules/fish.nix has the `cd = "z"` abbr.
#   * `source ~/.cargo/env.fish` — hm-modules/fish.nix puts ~/.cargo/bin on
#     home.sessionPath.
#   * `fish_add_path ~/.nix-profile/bin` — hm-modules/lsp.nix owns nixd and
#     home-manager routes it through /etc/profiles/per-user/$USER via useUserPackages.
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
    zayi = "yazi";
  };

  programs.fish.interactiveShellInit = ''
    # OrbStack CLI integration (installed by the app, not by nix).
    test -r ~/.orbstack/shell/init2.fish; and source ~/.orbstack/shell/init2.fish

    # emacs-plus-app bundles libgccjit v15, which stops finding gcc's runtime libs
    # (ld: library 'emutls_w' not found) once Homebrew's gcc rolls to a new major and
    # removes the old keg. gcc's driver folds LIBRARY_PATH into the linker's -L search,
    # and it must be exported from the shell because the `emacs --batch' processes that
    # compile subr trampolines during `doom sync' inherit it and run before any Doom Lisp
    # loads. Anchoring on libemutls_w.a keeps this correct across gcc major bumps.
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
