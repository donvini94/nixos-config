;;; $DOOMDIR/cli.el -*- lexical-binding: t; no-byte-compile: t; -*-
;;
;; Loaded by `bin/doom' for every CLI command (`doom sync', `doom upgrade', …), never by
;; an interactive session. Keep this to things that must hold while packages are built.

;; Emacs 31.1 regression: `loaddefs-generate--make-autoload' only expands a macro carrying
;; `(declare (autoload-macro expand))' when that macro is already `fboundp'. When it isn't,
;; it tries to load the defining file first — but passes the *relative* path it was handed,
;; so the load fails ("Cannot open load file ../home/…"), the macro form is copied verbatim
;; into <pkg>-autoloads.el, and loading that file later dies with a void-function error.
;;
;; typst-ts-compile.el autoloads a `define-compilation-mode' form, which is exactly this
;; case: the macro lives in compile.el, which a bare `doom sync' process has not loaded.
;; The generated autoloads then abort `doom sync' before it writes the profile init files,
;; leaving Emacs with "Doom hasn't been initialized yet".
;;
;; Pre-loading compile.el keeps the macro `fboundp', so the buggy load path is never taken
;; and the autoload stub is generated correctly. Drop this once Emacs ships the fix.
(require 'compile)

;; `doom sync --env' snapshots the calling shell into the profile's envvar file, which
;; GUI Emacs loads at startup (the Dock gives Emacs.app only /usr/bin:/bin:…). Keep
;; the snapshot to paths and locale: the shell also exports credentials (OS_PASSWORD)
;; and agent session state, which must not land in a plaintext file.
(setq doom-env-deny '(".")
      doom-env-allow '("^PATH$" "^MANPATH$" "^LANG$" "^LC_" "^NIX_SSL_CERT_FILE$"
                       "^SSL_CERT_FILE$" "^NIX_PROFILES$" "^XDG_DATA_DIRS$"
                       "^TERMINFO_DIRS$" "^SOPS_AGE_KEY_FILE$" "^EDITOR$" "^VISUAL$"))
