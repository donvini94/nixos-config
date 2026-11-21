;; nixd reads these per buffer via workspace/configuration; only this repo pays for
;; evaluating the flake (devenv projects keep nixd's lightweight defaults).
((nil
  . ((eval . (when (derived-mode-p 'nix-mode 'nix-ts-mode)
             (let ((flake (format "(builtins.getFlake %S)"
                                  (directory-file-name
                                   (locate-dominating-file default-directory ".dir-locals.el")))))
               (setq-local lsp-nix-nixd-nixos-options-expr
                           (concat flake ".nixosConfigurations.dracula.options")
                           lsp-nix-nixd-home-manager-options-expr
                           (concat flake ".nixosConfigurations.dracula.options"
                                   ".home-manager.users.type.getSubOptions []"))))))))
