;;; native-comp-driver-fix.el -*- lexical-binding: t; -*-
;;
;; Why this exists:
;;   This Emacs is the `emacs-plus-app' Homebrew *cask* (a prebuilt binary) that
;;   bundles its own libgccjit (v15).  A later `brew upgrade' rolled Homebrew's
;;   gcc/libgccjit to v16 and removed the v15 keg.  The bundled libgccjit still
;;   searches the v15 paths for gcc's runtime libs (libemutls_w.a, libgcc, crt*),
;;   which no longer exist -> native compilation fails with:
;;     ld: library 'emutls_w' not found / error invoking gcc driver
;;
;; Fix:
;;   Point the linker at the *current* Homebrew gcc runtime lib dirs.  Globbed
;;   (not hard-coded) so it self-heals across gcc major bumps (16 -> 17) and works
;;   on Apple Silicon (/opt/homebrew) + Intel (/usr/local).
;;
;;   The PRIMARY lever is the LIBRARY_PATH *environment variable*, not the
;;   `native-comp-driver-options' Lisp var.  Reason: subr trampolines (and async
;;   workers) are compiled in a freshly forked `emacs --batch' child that
;;   inherits our process ENVIRONMENT but NOT our Lisp variables.  gcc's driver
;;   folds LIBRARY_PATH into the linker's -L search, so the env reaches the child;
;;   the Lisp var would not.  `native-comp-driver-options' is set too, as a
;;   belt-and-suspenders for in-process links.
;;
;; PRIMARY fix lives at the SHELL level, not here:
;;   ~/.config/fish/conf.d/emacs-libgccjit-fix.fish exports LIBRARY_PATH before
;;   `doom'/Emacs launch.  That's required because subr trampolines compile in
;;   child processes DURING Doom core boot, before any user Lisp (this file,
;;   config.el, cli.el) loads -- too early for a Lisp hook to help.
;;
;; This file is loaded from config.el purely as a safety net for a *Dock-launched*
;; GUI Emacs (which never inherited a shell env): its `setenv' lets *post-startup*
;; lazy/async native compiles inherit LIBRARY_PATH.  On Linux/non-Homebrew hosts
;; the glob matches nothing and this is a no-op.

(when (eq system-type 'darwin)
  (let (dirs)
    (dolist (prefix '("/opt/homebrew/lib/gcc" "/usr/local/lib/gcc"))
      (setq dirs (append dirs
                         ;; top level: libgcc_s, libgomp, ...
                         (file-expand-wildcards (concat prefix "/[0-9]*"))
                         ;; target-triplet dir: libemutls_w.a, libgcc.a, crt*.o
                         (file-expand-wildcards (concat prefix "/[0-9]*/gcc/*/[0-9]*")))))
    (setq dirs (delete-dups
                (seq-filter #'file-directory-p
                            (mapcar #'directory-file-name dirs))))
    (when dirs
      ;; (1) PRIMARY: LIBRARY_PATH is inherited by child compiler subprocesses
      ;;     (subr trampolines, async workers) and honored by gcc's driver.
      (let ((existing (getenv "LIBRARY_PATH")))
        (setenv "LIBRARY_PATH"
                (mapconcat #'identity
                           (if (and existing (not (string-empty-p existing)))
                               (append dirs (list existing))
                             dirs)
                           ":")))
      ;; (2) Secondary: explicit -L for in-process libgccjit links.
      (setq native-comp-driver-options
            (mapcar (lambda (d) (concat "-L" d)) dirs)))))

(provide 'native-comp-driver-fix)
;;; native-comp-driver-fix.el ends here
