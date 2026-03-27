;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el

;; Org enhancements
(package! anki-editor
  :recipe (:host github :repo "anki-editor/anki-editor"))
(package! org-auto-tangle)
(package! org-modern
  :recipe (:host github :repo "minad/org-modern"))
(package! org-super-agenda)

;; Themes
(package! modus-themes)

;; Utilities
(package! csv-mode)
(package! ultra-scroll)  ; ~40% faster than pixel-scroll-precision-mode
(package! claude-code-ide
  :recipe (:host github :repo "manzaltu/claude-code-ide.el"))
(package! devcontainer
  :recipe (:host github :repo "johannes-mueller/devcontainer.el"))
;; TOML support (Cargo.toml, pyproject.toml, etc.)
(package! toml-mode)

;; Terraform/HCL support
(package! terraform-mode)
(package! hcl-mode)

;; HTTP client (lives inside org-mode buffers)
(package! verb)

;; Case conversion (camelCase ↔ snake_case ↔ kebab-case)
(package! string-inflection)

;; Ansible support
(package! ansible)
(package! ansible-doc)

;; Git: delta integration for magit
(package! magit-delta)

;; Evil: tree-sitter text objects (vaf = select function, vic = select class)
(package! evil-textobj-tree-sitter
  :recipe (:host github :repo "meain/evil-textobj-tree-sitter"
           :files ("*.el" "queries" "treesit-queries")))

;;; NOTE: jinx disabled — needs enchant2 dev headers for native module compilation.
;;; On NixOS, headers aren't in /usr/include/. Needs a proper nix-shell build env
;;; or a pre-compiled emacs-jinx package. Re-enable once resolved.
;; (package! jinx)

;; Document reader (replaces pdf-tools, also handles EPUB, MOBI, etc.)
(package! reader
  :recipe `(:host nil
            :type git
            :repo "https://codeberg.org/divyaranjan/emacs-reader"
            :files ("*.el" "render-core.dylib" "render-core.so")
            :pre-build ,(when (eq system-type 'darwin)
                          '(("make" "clean" "all")))))

;; Typst: tree-sitter major mode + tinymist LSP
(package! typst-ts-mode
  :recipe (:host codeberg :repo "meow_king/typst-ts-mode"))

;; Disable pdf-tools and related packages since reader replaces them
(package! pdf-tools :disable t)
(package! org-pdftools :disable t)
(package! saveplace-pdf-view :disable t)

