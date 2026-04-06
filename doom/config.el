;; [[file:config.org::*Performance Optimizations][Performance Optimizations:1]]
;; === Garbage Collection (works with Doom's gcmh) ===
;; Doom uses gcmh which sets high threshold during activity, low when idle.
;; We increase the high threshold and tune gc-cons-percentage.
(after! gcmh
  (setq gcmh-high-cons-threshold (* 128 1024 1024)  ; 128MB during activity
        gcmh-idle-delay 'auto                        ; Auto-tune idle delay
        gc-cons-percentage 0.2))                     ; 20% (research suggests this helps)

;; === Process Communication ===
(setq read-process-output-max (* 4 1024 1024))       ; 4MB for LSP/subprocess

;; === Display & Redisplay Performance ===
(setq fast-but-imprecise-scrolling t                 ; Faster scrolling, may be slightly imprecise
      redisplay-skip-fontification-on-input t        ; Skip fontification when typing
      jit-lock-defer-time 0                          ; Fontify immediately when idle
      idle-update-delay 1.0)                         ; Reduce UI update frequency

;; === Scrolling ===
;;; NOTE: scroll-conservatively and scroll-margin are set by ultra-scroll below.
(setq scroll-preserve-screen-position t              ; Keep point position on scroll
      auto-window-vscroll nil)                       ; Disable auto vertical scroll for tall lines

;; === Bidirectional Text (most users don't need RTL) ===
(setq-default bidi-paragraph-direction 'left-to-right)
(setq bidi-inhibit-bpa t)                            ; Disable bidirectional parenthesis algorithm

;; === Font & Display Caching ===
(setq inhibit-compacting-font-caches t)              ; Don't compact fonts (uses more memory)

;; === Native Compilation ===
(when (native-comp-available-p)
  (setq native-comp-async-report-warnings-errors nil ; Silence async compilation warnings
        native-comp-jit-compilation t                ; Compile in background (renamed from native-comp-deferred-compilation in Emacs 29)
        native-comp-speed 2))                        ; Optimization level (2 = max safe)

;; === File Handling ===
(setq vc-handled-backends '(Git)                     ; Only check for Git (faster than checking all VCS)
      vc-follow-symlinks t)                          ; Don't prompt about symlinks

;; === macOS Specific ===
(when (eq system-type 'darwin)
  (setq process-connection-type nil                  ; Use pipe for subprocess communication
        ns-use-native-fullscreen nil                 ; Faster fullscreen
        frame-resize-pixelwise t))                   ; Smooth frame resizing

;; === So-long Mode (handles minified/long-line files) ===
(global-so-long-mode 1)

;; === Auto-revert (reduce polling) ===
(setq auto-revert-interval 3                         ; Check every 3 seconds instead of 5
      auto-revert-check-vc-info nil                  ; Don't check VC info on revert
      global-auto-revert-non-file-buffers nil)       ; Only revert file buffers
;; Performance Optimizations:1 ends here

;; [[file:config.org::*Defaults][Defaults:1]]
(setq user-full-name "Vincenzo Pace"
      user-mail-address "pace@amiconsult.de")

(when (or (eq system-type 'darwin)
          (file-directory-p "/sys/class/power_supply/BAT0"))
  (display-battery-mode 1))
(display-time-mode 1)

(setq-default
 delete-by-moving-to-trash t
 window-combination-resize t
 major-mode 'org-mode
 history-length 1000)

(setq undo-limit 80000000                              ; ~76MB (was 762MB — excessively high)
      evil-want-fine-undo t
      truncate-string-ellipsis "…"
      password-cache-expiry nil
      confirm-kill-emacs nil)

;; Split windows to the right and below
(setq evil-vsplit-window-right t
      evil-split-window-below t)

;; After splitting, prompt for buffer selection
(defadvice! prompt-for-buffer (&rest _)
  :after '(evil-window-split evil-window-vsplit)
  (consult-buffer))

;; macOS key modifiers
(when (eq system-type 'darwin)
  (setq mac-command-modifier 'control
        mac-control-modifier 'super))

;; Frameless window
(add-to-list 'default-frame-alist '(undecorated . t))
;; Defaults:1 ends here

;; [[file:config.org::*Which-key (faster popup)][Which-key (faster popup):1]]
(after! which-key
  (setq which-key-idle-delay 0.3           ; Show faster
        which-key-idle-secondary-delay 0.05))
;; Which-key (faster popup):1 ends here

;; [[file:config.org::*Keybindings][Keybindings:1]]
(map! "C-c s" #'org-save-all-org-buffers)

(map! :leader
      :prefix "m a"
      :desc "Org download clipboard" "c" #'org-download-clipboard)

;; Avy for quick jumping (use s in normal mode)
(map! :leader
      :desc "Avy goto char 2" "j" #'avy-goto-char-2)
;; Keybindings:1 ends here

;; [[file:config.org::*Keybindings within ibuffer mode][Keybindings within ibuffer mode:1]]
(evil-define-key 'normal ibuffer-mode-map
  (kbd "f c") 'ibuffer-filter-by-content
  (kbd "f d") 'ibuffer-filter-by-directory
  (kbd "f f") 'ibuffer-filter-by-filename
  (kbd "f m") 'ibuffer-filter-by-mode
  (kbd "f n") 'ibuffer-filter-by-name
  (kbd "f x") 'ibuffer-filter-disable
  (kbd "g h") 'ibuffer-do-kill-lines
  (kbd "g H") 'ibuffer-update)
;; Keybindings within ibuffer mode:1 ends here

;; [[file:config.org::*LSP Booster][LSP Booster:1]]
(defun lsp-booster--advice-json-parse (old-fn &rest args)
  "Try to parse bytecode instead of json."
  (or
   (when (equal (following-char) ?#)
     (let ((bytecode (read (current-buffer))))
       (when (byte-code-function-p bytecode)
         (funcall bytecode))))
   (apply old-fn args)))
(advice-add (if (progn (require 'json)
                       (fboundp 'json-parse-buffer))
                'json-parse-buffer
              'json-read)
            :around
            #'lsp-booster--advice-json-parse)

(defun lsp-booster--advice-final-command (old-fn cmd &optional test?)
  "Prepend emacs-lsp-booster command to lsp CMD."
  (let ((orig-result (funcall old-fn cmd test?)))
    (if (and (not test?)
             (not (file-remote-p default-directory))
             lsp-use-plists
             (not (functionp 'json-rpc-connection))
             (executable-find "emacs-lsp-booster")
             ;; jdtls sends large indexing payloads that overflow lsp-booster's buffer
             (not (member "-Declipse.application=org.eclipse.jdt.ls.core.id1" orig-result)))
        (progn
          (when-let ((command-from-exec-path (executable-find (car orig-result))))
            (setcar orig-result command-from-exec-path))
          (message "Using emacs-lsp-booster for %s!" orig-result)
          (cons "emacs-lsp-booster" orig-result))
      orig-result)))
(advice-add 'lsp-resolve-final-command :around #'lsp-booster--advice-final-command)
;; LSP Booster:1 ends here

;; [[file:config.org::*LSP Configuration][LSP Configuration:1]]
(after! lsp-mode
  ;; Performance settings
  (setq lsp-idle-delay 0.5                              ; 0.1 was too aggressive, causes excessive LSP traffic
        lsp-log-io nil
        lsp-enable-file-watchers nil
        lsp-enable-folding nil
        lsp-enable-text-document-color nil
        lsp-enable-on-type-formatting nil

        ;; Completion settings (use corfu)
        lsp-completion-provider :none
        lsp-completion-show-detail t
        lsp-completion-show-kind t

        ;; Code lenses (inline clickable annotations)
        lsp-lens-enable t

        ;; Breadcrumb (shows class > method hierarchy)
        lsp-headerline-breadcrumb-enable t
        lsp-headerline-breadcrumb-segments '(symbols)

        ;; Code actions in modeline (lightbulb indicator)
        lsp-modeline-code-actions-enable t

        ;; Don't auto-execute — show menu first
        lsp-auto-execute-action nil)

  ;; Sideline UI
  (setq lsp-ui-sideline-show-code-actions t
        lsp-ui-sideline-show-hover nil))               ; hover in sideline is expensive — use K instead
;; LSP Configuration:1 ends here

;; [[file:config.org::*Corfu Configuration][Corfu Configuration:1]]
(after! corfu
  (setq corfu-auto t
        corfu-auto-delay 0.1
        corfu-auto-prefix 2
        corfu-cycle t
        corfu-preselect 'prompt
        corfu-scroll-margin 5))

;; Cape for additional completion backends
(after! cape
  (add-to-list 'completion-at-point-functions #'cape-file)
  (add-to-list 'completion-at-point-functions #'cape-dabbrev))
;; Corfu Configuration:1 ends here

;; [[file:config.org::*Vertico Enhancements][Vertico Enhancements:1]]
(after! vertico
  (setq vertico-cycle t
        vertico-resize nil))

;; Save minibuffer history
(after! savehist
  (setq savehist-additional-variables
        '(search-ring regexp-search-ring)))
;; Vertico Enhancements:1 ends here

;; [[file:config.org::*Python Configuration (ty)][Python Configuration (ty):1]]
;; Register ty as the Python LSP server
(after! lsp-mode
  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection '("ty" "server"))
    :activation-fn (lsp-activate-on "python")
    :server-id 'ty
    :priority 10                                 ; higher than pyright (1) so ty wins
    :add-on? nil)))

(after! python
  (setq python-shell-interpreter "python3"))
;; Python Configuration (ty):1 ends here

;; [[file:config.org::*Java Configuration (JDTLS)][Java Configuration (JDTLS):1]]
;; Always use system JDK for jdtls — immune to direnv/devbox overrides.
;; jdtls 1.48+ requires Java 21+; devbox may provide an older JDK for the project.
(cond
 ((eq system-type 'darwin)
  (setq lsp-java-java-path
        (concat (string-trim (shell-command-to-string "/usr/libexec/java_home")) "/bin/java"))
  (setenv "JAVA_HOME" (string-trim (shell-command-to-string "/usr/libexec/java_home"))))
 ((eq system-type 'gnu/linux)
  ;;; NOTE: NixOS — jdk21 installed system-wide in programming.nix.
  ;;; lsp-java-java-path tells jdtls which JDK to run itself with (needs 21+).
  ;;; JAVA_HOME for project build tools (maven/gradle) comes from devbox/direnv.
  (when-let ((java-bin (executable-find "java")))
    (setq lsp-java-java-path java-bin))))

(after! lsp-java
  (setq lsp-java-vmargs
        '("-XX:+UseG1GC"
          "-XX:+UseStringDeduplication"
          "-Xmx2G"
          "-Xms512m"))

  (setq lsp-java-completion-import-order '["java" "javax" "org" "com"]
        lsp-java-save-actions-organize-imports t
        lsp-java-format-on-type-enabled t)

  ;; Map project source levels to actual JDK installations.
  ;; jdtls resolves standard library types from the matching runtime,
  ;; so the project gets java.lang.Object from JDK 17 — not JDK 25.
  (when (eq system-type 'darwin)
    (setq lsp-java-configuration-runtimes
          '[(:name "JavaSE-17"
             :path "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
             :default t)
            (:name "JavaSE-25"
             :path "/Library/Java/JavaVirtualMachines/jdk-25.jdk/Contents/Home")])))
;; Java Configuration (JDTLS):1 ends here

;; [[file:config.org::*Go Configuration (gopls)][Go Configuration (gopls):1]]
(after! go-mode
  (setq gofmt-command "gofumpt"))

(after! lsp-go
  (setq lsp-go-analyses '((shadow . t)
                          (unusedvariable . t)
                          (unusedwrite . t)
                          (useany . t))))
;; Go Configuration (gopls):1 ends here

;; [[file:config.org::*Rust Configuration][Rust Configuration:1]]
(after! rustic
  (setq rustic-format-on-save t
        rustic-lsp-client 'lsp-mode))

(after! lsp-rust
  (setq lsp-rust-analyzer-cargo-watch-command "clippy"
        lsp-rust-analyzer-display-chaining-hints t
        lsp-rust-analyzer-display-parameter-hints t))

;;; NOTE: dap-gdb-lldb-setup downloads binaries on first call — run M-x dap-gdb-lldb-setup manually when needed
(after! dap-mode
  (require 'dap-gdb-lldb))
;; Rust Configuration:1 ends here

;; [[file:config.org::*Typst Configuration (tinymist)][Typst Configuration (tinymist):1]]
;;; lsp-mode ships lsp-typst.el with full tinymist client registration.
(use-package! typst-ts-mode
  :mode "\\.typ\\'"
  :config
  (after! lsp-mode
    (add-to-list 'lsp-language-id-configuration '(typst-ts-mode . "typst")))

  (add-hook 'typst-ts-mode-hook #'lsp!)

  ;; Format via LSP (typstyle) on save
  (add-hook 'typst-ts-mode-hook
            (lambda ()
              (add-hook 'before-save-hook #'lsp-format-buffer nil t)))

  ;; Live preview via tinymist's built-in web server (hot-reloads on save)
  (defun my/typst-preview ()
    "Start tinymist live preview in browser."
    (interactive)
    (let ((file (buffer-file-name)))
      (unless file (user-error "Buffer is not visiting a file"))
      (start-process "tinymist-preview" "*tinymist-preview*" "tinymist" "preview" file)
      (message "tinymist preview started — opening browser")))

  (map! :map typst-ts-mode-map
        :localleader
        "p" #'my/typst-preview))
;; Typst Configuration (tinymist):1 ends here

;; [[file:config.org::*Magit][Magit:1]]
;; Set before magit loads — version check runs during loading, after! fires too late
(when (eq system-type 'darwin)
  (setq magit-git-executable "/opt/homebrew/bin/git"))

(after! magit
  ;; Reduce startup overhead
  (setq magit-refresh-status-buffer t          ; Keep enabled but optimize below
        magit-diff-refine-hunk nil             ; Disable word-granularity diff
        magit-diff-highlight-indentation nil
        magit-diff-highlight-trailing nil
        magit-diff-paint-whitespace nil)

  ;; Show less data initially
  (setq magit-log-section-commit-count 20)     ; Fewer commits in status

  ;; Faster remotes
  (setq magit-clone-default-directory "~/code/")
  (setq auto-revert-buffer-list-filter 'magit-auto-revert-repository-buffer-p))
;; Magit:1 ends here

;; [[file:config.org::*Debugger][Debugger:1]]
(use-package dap-mode
  :after lsp-mode
  :commands dap-debug
  :hook ((python-mode . dap-ui-mode) (python-mode . dap-mode))
  :config
  (require 'dap-python)
  (setq dap-python-debugger 'debugpy)
  (defun dap-python--pyenv-executable-find (command)
    (if (bound-and-true-p pyvenv-virtual-env)
        (executable-find "python")
      (executable-find command)))

  (add-hook 'dap-stopped-hook
            (lambda (arg) (call-interactively #'dap-hydra))))

(map! :map dap-mode-map
      :leader
      :prefix ("d" . "dap")
      :desc "dap next"          "n" #'dap-next
      :desc "dap step in"       "i" #'dap-step-in
      :desc "dap step out"      "o" #'dap-step-out
      :desc "dap continue"      "c" #'dap-continue
      :desc "dap hydra"         "h" #'dap-hydra
      :desc "dap debug restart" "r" #'dap-debug-restart
      :desc "dap debug"         "s" #'dap-debug)
;; Debugger:1 ends here

;; [[file:config.org::*Theming][Theming:1]]
(setq doom-theme 'modus-vivendi-tinted)
(setq doom-font (font-spec :family "Iosevka" :weight 'normal :size 24)
      doom-variable-pitch-font (font-spec :family "Iosevka" :size 28)
      doom-big-font (font-spec :family "Iosevka" :size 32))

(setq display-line-numbers-type 'relative)

;; Modus themes configuration — set before theme loads
(setq modus-themes-italic-constructs t
      modus-themes-bold-constructs t
      modus-themes-mixed-fonts t
      modus-themes-org-blocks 'gray-background
      modus-themes-headings '((1 . (variable-pitch 1.5))
                              (2 . (variable-pitch 1.3))
                              (3 . (variable-pitch 1.1))
                              (t . (variable-pitch 1.0)))
      modus-themes-completions '((matches . (extrabold))
                                 (selection . (semibold italic))))

;; Frame transparency
;; alpha-background (bg-only) works on PGTK/X11; NS lacks it, fall back to whole-frame alpha
(if (eq window-system 'ns)
    (add-to-list 'default-frame-alist '(alpha . (90 . 90)))
  (add-to-list 'default-frame-alist '(alpha-background . 90)))

(setq modus-themes-to-toggle '(modus-operandi-tinted modus-vivendi-tinted))
(map! "<f5>" #'modus-themes-toggle)
;; Theming:1 ends here

;; [[file:config.org::*Modeline][Modeline:1]]
(set-face-attribute 'mode-line nil :font "Iosevka")
(setq doom-modeline-height 30
      doom-modeline-bar-width 5
      doom-modeline-persp-name t
      doom-modeline-persp-icon t)
;; Modeline:1 ends here

;; [[file:config.org::*General Settings][General Settings:1]]
(setq org-directory "~/org/")

;; Agenda files — GTD always, roam only if modified in last 90 days (performance)
(after! org
  (defun my/recent-org-files (dir &optional days)
    "Return .org files in DIR modified within DAYS (default 90)."
    (let ((cutoff (time-subtract (current-time) (days-to-time (or days 90)))))
      (cl-remove-if-not
       (lambda (f) (time-less-p cutoff (file-attribute-modification-time (file-attributes f))))
       (directory-files-recursively dir "\\.org$"))))

  (setq org-agenda-files
        (append (directory-files-recursively (concat org-directory "gtd/") "\\.org$")
                (my/recent-org-files (concat org-directory "roam/daily/") 90)
                (my/recent-org-files (concat org-directory "roam/main/") 90)
                (my/recent-org-files (concat org-directory "roam/people/") 90)
                (my/recent-org-files (concat org-directory "roam/meetings/") 90))))

(after! org-download
  (setq org-download-method 'directory
        org-download-image-org-width 600
        org-download-link-format "[[file:%s]]\n"
        org-download-abbreviate-filename-function #'file-relative-name
        org-download-link-format-function #'org-download-link-format-function-default
        org-download-screenshot-method
        (if (eq system-type 'darwin)
            "screencapture -i %s"
          "grim -g \"$(slurp)\" %s"))
  ;;; NOTE: org-download-image-dir expects a string, not a lambda.
  ;;; Use a hook to set it dynamically per-buffer instead.
  (setq org-download-image-dir "~/org/images")
  (add-hook 'org-mode-hook
            (lambda ()
              (when buffer-file-name
                (setq-local org-download-image-dir
                            (concat (file-name-sans-extension buffer-file-name) "-img"))))))

(with-eval-after-load 'org (global-org-modern-mode))

(after! org
  (setq org-startup-folded t
        org-preview-latex-directory (expand-file-name "ltximg/" org-directory)
        org-habit-show-habits nil                        ; habits tracked separately, not in agenda
        org-default-notes-file (concat org-directory "/gtd/notes.org")
        org-ellipsis " ▼ "
        org-my-anki-file (expand-file-name "anki.org" org-directory)
        org-log-done 'time
        org-hide-emphasis-markers t
        org-clock-display-default-range 'untilnow
        org-pomodoro-length 25
        org-pomodoro-short-break-length 5
        org-pomodoro-long-break-length 20
        org-pomodoro-manual-break t
        org-pomodoro-play-sounds nil
        org-pretty-entities t))

(setq org-todo-keywords
      '((sequence "TODO(t)" "NEXT(n)" "HOLD(h)" "|" "DONE(d)")))
;; General Settings:1 ends here

;; [[file:config.org::*Org Roam][Org Roam:1]]
(use-package! org-roam
  :after org
  :config
  (advice-remove 'org-roam-db-query '+org-roam-try-init-db-a)

  (setq org-roam-capture-templates
        '(("m" "main" plain
           "%?"
           :if-new (file+head "main/${slug}.org"
                              "#+title: ${title}\n#+filetags:\n")
           :immediate-finish t
           :unnarrowed t)

          ("r" "reference" plain "%?"
           :if-new
           (file+head "reference/${slug}.org" "#+title: ${title}\n#+filetags: \n- source :: \n\n ")
           :immediate-finish t
           :unnarrowed t)

          ("P" "people" plain "%?"
           :if-new
           (file+head "people/${slug}.org" "#+title: ${title}\n#+filetags: \n* Company\n* Contact Info\n* Job title\n ")
           :immediate-finish t
           :unnarrowed t)

          ("p" "paper" plain "%?"
           :if-new
           (file+head "papers/${slug}.org" "${title}\n#+filetags: :paper:\n- source ::  \n \n* TLDR \n* Research Gap \n* Limitations \n* Contribution \n* Open Questions\n* Evidence\n* Other")
           :immediate-finish t
           :unnarrowed t)

          ("M" "meeting" plain "%?"
           :if-new
           (file+head "meetings/%<%Y%m%d%S>-${slug}.org" "Meeting of : %t\n#+filetags: :meeting:\n")
           :immediate-finish t
           :unnarrowed t)

          ("b" "book notes" plain
           "\n* Source\n\nAuthor: %^{Author}\nTitle: ${title}\nYear: %^{Year}\n\n* Summary\n\n%?"
           :if-new (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "#+title: ${title}\n")
           :unnarrowed t)))

  (setq org-roam-dailies-capture-templates
        '(("d" "daily" entry
           "* %?"
           :target (file+head "%<%Y-%m-%d>.org"
                              "#+title: %<%Y-%m-%d %a>\n#+filetags:\n\n#+BEGIN: clocktable\n#+END:\n\n* The one thing\n* Today\n* Process\n- [ ] Anything from yesterday to refile?\n- [ ] Any links to add to [[id:faa54565-d82d-49c5-aa6f-6089cbb8bf53][Reading List]]?\n* Daily Review\n** What did I accomplish today?\n** What's tomorrow's priority?"))
          ("w" "weekly" entry
           "* Weekly Review: Week %<%U>"
           :target (file+head "weekly/W%<%V_%Y>.org"
                              "#+title: Weekly Review: %<%Y-W%V>\n#+filetags: :reference:\n\n* What happened this week?\n(3-5 bullet points — scan your dailies)\n%?\n\n* What's still open?\n- [ ] Inbox items to refile or delete\n- [ ] Stale TODOs to move to someday or kill\n- [ ] Any roam notes to update with new links?\n\n* Next week's focus\n1. \n2. \n3."))
          ("m" "monthly" entry
           "* Monthly Review: %<%B %Y>"
           :target (file+head "monthly/M%<%m_%Y>.org"
                              "#+title: Monthly Review: %<%B %Y>\n#+filetags: :reference:\n\n* Month Overview\n%?\n** Key wins:\n- \n** Challenges:\n- \n** Surprises:\n- \n\n* Goal Progress\n** Career & Work\n- Key accomplishments:\n- Next month's focus:\n\n** Learning\n- What did I learn?\n- What do I want to learn next?\n\n** Health\n- How am I doing?\n- What needs attention?\n\n** Finance\n- On track? [Yes/No]\n- Action needed:\n\n* Vision 2028 Check\nAm I still moving toward my vision? [Yes/No]\nWhat needs to change?\n\n* Next Month's Top 3 Priorities\n1. \n2. \n3."))
          ("1" "1on1" entry
           "* 1on1 with %^{Name} %<%U>"
           :target (file+head "1on1s/%<%Y-%m-%d>.org"
                              "#+title: 1on1 with %^{Name} on %<%Y-%m-%d>\n#+filetags: :1on1:\n\n* Check-In\n- Mood today: \n- Energy level: \n\n* Wins Since Last Time\n- \n\n* Challenges\n- \n\n* Support Needed\n- \n\n* Learning & Growth\n- What did you learn recently?\n- What do you want to focus on?\n\n* Feedback Exchange\n- My feedback for you:\n- Your feedback for me:\n\n* Next Steps / Commitments\n- [ ] \n- [ ] \n- [ ] \n")))))
;; Org Roam:1 ends here

;; [[file:config.org::*Org Habits][Org Habits:1]]
;;; NOTE: org-habit is loaded by Doom's org module. We just configure it here.
(after! org-habit
  (setq org-habit-graph-column 60
        org-habit-preceding-days 14
        org-habit-following-days 3
        org-habit-show-habits-only-for-today nil))
;; Org Habits:1 ends here

;; [[file:config.org::*Org-auto-tangle][Org-auto-tangle:1]]
(use-package! org-auto-tangle
  :hook (org-mode . org-auto-tangle-mode)
  :config
  (setq org-auto-tangle-default t))
;; Org-auto-tangle:1 ends here

;; [[file:config.org::*Org Capture][Org Capture:1]]
(use-package! anki-editor
  :commands (anki-editor-mode)
  :init
  (map! :leader
        :desc "Anki Push tree"
        "m a p" #'anki-editor-push-new-notes)
  :hook (org-capture-after-finalize . anki-editor-reset-cloze-number))

(defun my-anki-editor-mode-hook ()
  (when (string-equal (buffer-file-name) (expand-file-name "~/org/anki.org"))
    (anki-editor-mode)))
(add-hook 'find-file-hook 'my-anki-editor-mode-hook)

(after! org
  (add-to-list 'org-capture-templates
               '("a" "Anki basic"
                 entry
                 (file+headline org-my-anki-file "Dispatch Shelf")
                 "* %<%H:%M>   %^g\n:PROPERTIES:\n:ANKI_NOTE_TYPE: Basic\n:ANKI_DECK: Mega\n:END:\n** Front\n%?\n** Back\n"))
  (add-to-list 'org-capture-templates
               '("A" "Anki cloze"
                 entry
                 (file+headline org-my-anki-file "Dispatch Shelf")
                 "* %<%H:%M>   %^g\n:PROPERTIES:\n:ANKI_NOTE_TYPE: Cloze\n:ANKI_DECK: Mega\n:END:\n** Text\n%x\n** Extra\n"))
  (add-to-list 'org-capture-templates
               '("g" "Game Dev Notes"
                 entry
                 (file+headline "~/org/my_rpg.org" "Capture")
                 "* %?\nEntered on %U\n  %i\n  %a"))
  (add-to-list 'org-capture-templates
               '("r" "Reading List"
                 entry
                 (file+headline "~/org/reading_list.org" "Capture")
                 "* %?Title\nby Author \n\nEntered on %U\n  %i\n  %a \n "))
  (add-to-list 'org-capture-templates
               '("n" "Notes"
                 entry
                 (file+headline "~/org/gtd/notes.org" "Capture")
                 "* %?\n  %i\n  %a"))
  (add-to-list 'org-capture-templates
               '("t" "ToDo"
                 entry
                 (file+headline "~/org/gtd/inbox.org" "Capture")
                 "* TODO %?\n  %i\n  %a")))

;; Close org-capture frame when done
(defun my/delete-capture-frame (&rest _)
  "Close the org-capture frame if we're in one."
  (when (equal "org-capture" (frame-parameter nil 'name))
    (delete-frame)))

(advice-add 'org-capture-finalize :after #'my/delete-capture-frame)
(advice-add 'org-capture-destroy :after #'my/delete-capture-frame)

(defun make-orgcapture-frame ()
  "Create a new frame and run org-capture."
  (interactive)
  (make-frame '((name . "org-capture")))
  (select-frame-by-name "org-capture")
  (org-capture))
;; Org Capture:1 ends here

;; [[file:config.org::*Org agenda][Org agenda:1]]
(use-package! org-super-agenda
  :after org-agenda
  :config
  (org-super-agenda-mode 1)

  ;; Fix evil navigation on super-agenda header lines.
  ;; Without this, j=calendar, k=capture, h=holidays, l=log on headers.
  (setq org-super-agenda-header-map (make-sparse-keymap)))

(after! org
  ;; === Agenda display ===
  (setq org-agenda-skip-timestamp-if-done t
        org-agenda-skip-deadline-if-done t
        org-agenda-skip-scheduled-if-done t
        org-agenda-skip-scheduled-if-deadline-is-shown t
        org-agenda-skip-timestamp-if-deadline-is-shown t)

  ;; Use full frame for agenda (more horizontal space)
  (setq org-agenda-window-setup 'only-window)

  ;; Tags at right edge of window, not a fixed column
  (setq org-agenda-tags-column 'auto)

  ;; Clean time grid — no "now" marker, no grid labels
  (setq org-agenda-current-time-string "")
  (setq org-agenda-time-grid '((daily) () "" ""))

  ;; Compact prefix — time + category, use available width
  (setq org-agenda-prefix-format
        '((agenda . "  %?-2i %t ")
          (todo   . "  %i %-12:c")
          (tags   . "  %i %-12:c")
          (search . "  %i %-12:c")))

  ;; Thinner block separator between agenda sections
  (setq org-agenda-block-separator ?─)

  ;; Show deadlines 10 days in advance
  (setq org-deadline-warning-days 10)

  ;; No tag inheritance — only tags directly on the heading are used.
  ;; Filetags from org-roam and parent heading tags are excluded.
  ;;; NOTE: If a sub-task needs a tag, put it directly on that heading.
  (setq org-agenda-use-tag-inheritance nil)

  ;; Don't show habits in agenda (tracked separately via org-habit)
  (setq org-habit-show-habits nil)

  ;; === Category icons (deferred until nerd-icons loads) ===
  (after! nerd-icons
    (setq org-agenda-category-icon-alist
          `(("gtd"       ,(list (nerd-icons-faicon "nf-fa-check_square_o")) nil nil :ascent center)
            ("inbox"      ,(list (nerd-icons-faicon "nf-fa-inbox")) nil nil :ascent center)
            ("roam"       ,(list (nerd-icons-faicon "nf-fa-brain")) nil nil :ascent center)
            ("anki"       ,(list (nerd-icons-faicon "nf-fa-graduation_cap")) nil nil :ascent center)
            ("reading"    ,(list (nerd-icons-faicon "nf-fa-book")) nil nil :ascent center)
            ("meeting"    ,(list (nerd-icons-faicon "nf-fa-users")) nil nil :ascent center)
            ("daily"      ,(list (nerd-icons-faicon "nf-fa-calendar")) nil nil :ascent center))))

  ;; === Dashboard — single unified view ===
  (setq org-agenda-custom-commands
        '(("o" "Dashboard"
           ;; Block 1: Today (span 1) — schedule, overdue, today's dated tasks
           ((agenda "" ((org-agenda-span 1)
                        (org-agenda-start-day "+0d")
                        (org-agenda-overriding-header "")
                        (org-deadline-warning-days 0)
                        (org-super-agenda-groups
                         '((:name " Schedule "
                            :time-grid t
                            :order 0)
                           (:name " Overdue "
                            :deadline past
                            :scheduled past
                            :face error
                            :order 1)
                           (:name " Today "
                            :date today
                            :scheduled today
                            :order 2)
                           (:discard (:anything t))))))

            ;; Block 2: This week (days +1 to +7)
            (agenda "" ((org-agenda-span 7)
                        (org-agenda-start-day "+1d")
                        (org-agenda-overriding-header "")
                        (org-deadline-warning-days 0)
                        (org-super-agenda-groups
                         '((:auto-tags t)))))

            ;; Block 3: All open tasks (including unscheduled from dailies) — grouped by tag
            (alltodo "" ((org-agenda-overriding-header "")
                         (org-super-agenda-groups
                          '((:name " Inbox "
                             :file-path "inbox"
                             :order 0)
                            (:name " Next Actions "
                             :todo "NEXT"
                             :order 1)
                            (:auto-tags t
                             :order 3)
                            (:name " On Hold "
                             :todo "HOLD"
                             :order 9)
                            (:discard (:anything t))))))))

          ;; Quick views
          ("n" "Next Actions"
           ((alltodo "" ((org-agenda-overriding-header "")
                         (org-super-agenda-groups
                          '((:name " Next Actions "
                             :todo "NEXT"
                             :order 1)
                            (:discard (:anything t))))))))

          ("d" "Completed today"
           agenda ""
           ((org-agenda-start-day "+0d")
            (org-agenda-span 1)
            (org-agenda-entry-types '(:closed)))))))

;; === Post-render: clean "Tags: " prefix and apply box styling ===
(defun my/org-agenda-prettify-headers ()
  "Clean auto-group headers and re-apply box face in the agenda buffer."
  (let ((inhibit-read-only t))
    (save-excursion
      (goto-char (point-min))
      ;; Strip "Tags: " prefix and re-apply the super-agenda-header face
      (while (re-search-forward "^ Tags: \\(.+\\)$" nil t)
        (let* ((tag-name (match-string 1))
               (new-text (concat " " (capitalize tag-name) " "))
               (beg (match-beginning 0))
               (end (match-end 0)))
          (replace-match new-text)
          (put-text-property beg (+ beg (length new-text))
                             'face 'org-super-agenda-header))))))
(add-hook 'org-agenda-finalize-hook #'my/org-agenda-prettify-headers)

;; Box styling via background color + padding — works reliably on PGTK/Wayland
;; (`:style flat-button` doesn't render on PGTK, so we fake it with bg + box color)
(defun my/org-agenda-style-super-agenda-headers ()
  "Apply box styling to org-super-agenda group headers after theme loads."
  (modus-themes-with-colors
    (set-face-attribute 'org-super-agenda-header nil
                        :inherit nil
                        :weight 'bold
                        :foreground fg-main
                        :background bg-dim
                        :box `(:line-width (2 . 6) :color ,bg-dim)
                        :overline nil
                        :underline nil)))
;; Apply on theme load/toggle (modus themes reset faces)
(add-hook 'modus-themes-after-load-theme-hook #'my/org-agenda-style-super-agenda-headers)
;; Also apply now if theme is already loaded
(with-eval-after-load 'org-super-agenda
  (when (facep 'org-super-agenda-header)
    (my/org-agenda-style-super-agenda-headers)))

;; Agenda buffer styling — clean and focused
(defun my/org-agenda-open-hook ()
  "Style the agenda buffer for focused reading."
  (setq-local line-spacing 4)
  (display-line-numbers-mode -1))
(add-hook 'org-agenda-mode-hook #'my/org-agenda-open-hook)

;; Quick access: SPC A opens the dashboard directly
(map! :leader
      :desc "Agenda dashboard" "A" (lambda () (interactive) (org-agenda nil "o")))
;; Org agenda:1 ends here

;; [[file:config.org::*Dired with Dirvish][Dired with Dirvish:1]]
;;; NOTE: Removed SPC d d / SPC d j — they conflicted with SPC d (DAP debugger prefix).
;;; Use SPC . (find-file) or SPC o - (dirvish side panel) instead.

;; Trash handling on macOS
(when (eq system-type 'darwin)
  (setq trash-directory nil))  ; Use system default
;; Dired with Dirvish:1 ends here

;; [[file:config.org::*Claude Code IDE][Claude Code IDE:1]]
(use-package! claude-code-ide
  :config
  (claude-code-ide-emacs-tools-setup))

(map! :leader
      "C" #'claude-code-ide-menu)
;; Claude Code IDE:1 ends here

;; [[file:config.org::*Agent Shell][Agent Shell:1]]
(use-package! agent-shell
  :config
  (setq agent-shell-anthropic-authentication
        (agent-shell-anthropic-make-authentication :login t)))

(map! :leader
      (:prefix ("l" . "LLM")
       :desc "Agent shell" "l" #'agent-shell
       :desc "Send region" "RET" #'agent-shell-send-region
       :desc "Send file" "f" #'agent-shell-send-file
       :desc "Interrupt" "x" #'agent-shell-interrupt))
;; Agent Shell:1 ends here

;; [[file:config.org::*Document Reader (emacs-reader)][Document Reader (emacs-reader):1]]
(use-package! reader
  :mode (("\\.pdf\\'" . reader-mode)
         ("\\.epub\\'" . reader-mode)
         ("\\.mobi\\'" . reader-mode)
         ("\\.fb2\\'" . reader-mode)
         ("\\.xps\\'" . reader-mode)
         ("\\.cbz\\'" . reader-mode)
         ("\\.odt\\'" . reader-mode)
         ("\\.docx\\'" . reader-mode)
         ("\\.pptx\\'" . reader-mode)
         ("\\.xlsx\\'" . reader-mode))
  :config
  ;; Suppress the EmacsWinState warning on startup
  (advice-add 'reader-current-doc-pagenumber :around
              (lambda (fn &rest args)
                (ignore-errors (apply fn args))))

  ;; Fix page counter not updating - use post-command-hook for reliable updates
  (defun my/reader-update-modeline ()
    "Update modeline in reader-mode after commands."
    (when (eq major-mode 'reader-mode)
      (force-mode-line-update t)))

  (add-hook 'reader-mode-hook
            (lambda ()
              (add-hook 'post-command-hook #'my/reader-update-modeline nil t)))

  ;; NOTE: reader-dark-mode works but toggling back to light crashes Emacs (native code bug)

  ;; Use evil keybindings in reader-mode
  (evil-set-initial-state 'reader-mode 'normal)

  ;; Evil-friendly navigation (package defaults: n/p for pages, H/W for fit)
  (map! :map reader-mode-map
        :n "j" #'reader-scroll-down-or-next-page
        :n "k" #'reader-scroll-up-or-prev-page
        :n "h" #'reader-scroll-left
        :n "l" #'reader-scroll-right
        :n "gg" #'reader-first-page
        :n "G" #'reader-last-page
        :n "+" #'reader-enlarge-size
        :n "-" #'reader-shrink-size
        :n "0" #'reader-reset-size
        :n "W" #'reader-fit-to-width
        :n "H" #'reader-fit-to-height
        :n ":" #'reader-goto-page
        :n "q" #'kill-current-buffer))

;; Handle old pdf-view bookmarks - redirect to reader
(defun my/pdf-view-bookmark-jump-handler (bookmark)
  "Handle old pdf-view bookmarks by opening in reader-mode."
  (let ((file (bookmark-get-filename bookmark)))
    (when (and file (file-exists-p file))
      (find-file file))))

(with-eval-after-load 'bookmark
  (fset 'pdf-view-bookmark-jump-handler #'my/pdf-view-bookmark-jump-handler))
;; Document Reader (emacs-reader):1 ends here

;; [[file:config.org::*Terraform/HCL][Terraform/HCL:1]]
(use-package! terraform-mode
  :mode ("\\.tf\\'" "\\.tfvars\\'")
  :config
  (add-hook 'terraform-mode-hook #'terraform-format-on-save-mode))

(use-package! hcl-mode
  :mode ("\\.hcl\\'" "\\.nomad\\'"))
;; Terraform/HCL:1 ends here

;; [[file:config.org::*String Inflection (case conversion)][String Inflection (case conversion):1]]
(use-package! string-inflection
  :commands (string-inflection-all-cycle
             string-inflection-camelcase
             string-inflection-lower-camelcase
             string-inflection-underscore
             string-inflection-kebab-case)
  :init
  (map! :leader
        (:prefix ("i" . "inflect")
         :desc "Cycle case" "i" #'string-inflection-all-cycle
         :desc "CamelCase" "c" #'string-inflection-camelcase
         :desc "camelCase" "l" #'string-inflection-lower-camelcase
         :desc "snake_case" "s" #'string-inflection-underscore
         :desc "kebab-case" "k" #'string-inflection-kebab-case
         :desc "UPPER_CASE" "u" #'string-inflection-upcase)))
;; String Inflection (case conversion):1 ends here

;; [[file:config.org::*Verb (HTTP client in org-mode)][Verb (HTTP client in org-mode):1]]
(use-package! verb
  :after org
  :config
  (define-key org-mode-map (kbd "C-c C-r") verb-command-map))

;;; NOTE: Usage — create org headings with HTTP specs:
;;;   * Get all identities                     :verb:
;;;   GET https://tenant.api.identitynow.com/v3/identities
;;;   Accept: application/json
;;;   Authorization: Bearer {{(getenv "ISC_TOKEN")}}
;;; Then C-c C-r C-r to send, C-c C-r C-s to send and show response.
;;; Verb inherits headers from parent headings — put auth at the top level.
;; Verb (HTTP client in org-mode):1 ends here

;; [[file:config.org::*Ansible][Ansible:1]]
(use-package! ansible
  :commands ansible
  :hook (yaml-mode . (lambda ()
                       (when (and buffer-file-name
                                  (or (string-match-p "/\\(roles\\|tasks\\|handlers\\|playbooks\\|ansible\\)/" buffer-file-name)
                                      (string-match-p "\\(playbook\\|site\\|main\\)\\.ya?ml\\'" buffer-file-name)))
                         (ansible 1)))))

(use-package! ansible-doc
  :after ansible
  :hook (ansible-mode . ansible-doc-mode)
  :config
  (map! :map ansible-doc-mode-map
        :leader
        :desc "Ansible doc" "h a" #'ansible-doc))
;; Ansible:1 ends here

;; [[file:config.org::*Nix LSP][Nix LSP:1]]
;;; NOTE: Requires nixd installed. On NixOS add to environment.systemPackages or devShell.
;;; nixd provides completions, diagnostics, goto-def, and flake option evaluation.
(after! lsp-mode
  (setq lsp-nix-nixd-server-path "nixd"))
;; Nix LSP:1 ends here

;; [[file:config.org::*Ruff (Python linting + formatting)][Ruff (Python linting + formatting):1]]
;;; NOTE: Ruff replaces black + isort + pyflakes — single Rust binary, same Astral ecosystem as ty.
;;; format-on-save uses ruff format (via apheleia or format +onsave).
(after! lsp-mode
  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection '("ruff" "server"))
    :activation-fn (lsp-activate-on "python")
    :server-id 'ruff
    :priority 5                                  ; lower than ty (10), acts as add-on linter
    :add-on? t)))                                ; runs alongside ty, doesn't replace it

(setq-hook! 'python-mode-hook
  +format-with-lsp nil)                          ; let ruff handle formatting, not ty

(after! apheleia
  (setf (alist-get 'python-mode apheleia-mode-alist) '(ruff))
  (setf (alist-get 'python-ts-mode apheleia-mode-alist) '(ruff))
  (setf (alist-get 'ruff apheleia-formatters) '("ruff" "format" "-")))
;; Ruff (Python linting + formatting):1 ends here

;; [[file:config.org::*Magit-delta][Magit-delta:1]]
;;; NOTE: Requires delta binary in PATH (already installed in NixOS config).
(use-package! magit-delta
  :hook (magit-mode . magit-delta-mode))
;; Magit-delta:1 ends here

;; [[file:config.org::*Evil Tree-sitter Text Objects][Evil Tree-sitter Text Objects:1]]
;;; Adds tree-sitter powered text objects to Evil:
;;;   vaf / daf — select/delete a function
;;;   vac / dac — select/delete a class
;;;   vaa / daa — select/delete a parameter/argument
;;;   vai / dai — select/delete a conditional (if)
;;;   val / dal — select/delete a loop
(use-package! evil-textobj-tree-sitter
  :after evil
  :config
  ;; "a" (outer) and "i" (inner) text objects for functions
  (define-key evil-outer-text-objects-map "f"
    (cons "a-function" (evil-textobj-tree-sitter-get-textobj "function.outer")))
  (define-key evil-inner-text-objects-map "f"
    (cons "inner-function" (evil-textobj-tree-sitter-get-textobj "function.inner")))

  ;; Classes
  (define-key evil-outer-text-objects-map "c"
    (cons "a-class" (evil-textobj-tree-sitter-get-textobj "class.outer")))
  (define-key evil-inner-text-objects-map "c"
    (cons "inner-class" (evil-textobj-tree-sitter-get-textobj "class.inner")))

  ;; Arguments/parameters
  (define-key evil-outer-text-objects-map "a"
    (cons "a-argument" (evil-textobj-tree-sitter-get-textobj "parameter.outer")))
  (define-key evil-inner-text-objects-map "a"
    (cons "inner-argument" (evil-textobj-tree-sitter-get-textobj "parameter.inner")))

  ;; Conditionals
  (define-key evil-outer-text-objects-map "i"
    (cons "a-conditional" (evil-textobj-tree-sitter-get-textobj "conditional.outer")))
  (define-key evil-inner-text-objects-map "i"
    (cons "inner-conditional" (evil-textobj-tree-sitter-get-textobj "conditional.inner")))

  ;; Loops
  (define-key evil-outer-text-objects-map "l"
    (cons "a-loop" (evil-textobj-tree-sitter-get-textobj "loop.outer")))
  (define-key evil-inner-text-objects-map "l"
    (cons "inner-loop" (evil-textobj-tree-sitter-get-textobj "loop.inner"))))
;; Evil Tree-sitter Text Objects:1 ends here

;; [[file:config.org::*TRAMP (remote editing)][TRAMP (remote editing):1]]
;;; Strategy: treat remote buffers as "dumb" — syntax highlighting + editing only.
;;; Whitelist things back as needed (e.g. LSP for future remote dev).

;; Use ssh method (not scp) — avoids extra connection per file operation.
(setq tramp-default-method "ssh")

;; Reduce TRAMP logging noise (default 3 is very chatty).
(setq tramp-verbose 1)

;; Increase chunk size for better throughput on fast connections.
(setq tramp-chunksize 2000)

;; Don't stat remote files in recentf — causes hangs on startup.
(after! recentf
  (add-to-list 'recentf-exclude tramp-file-name-regexp))

;; Kill heavy modes on remote buffers.
(defun vp/tramp-disable-heavy-modes ()
  "Disable expensive minor modes for remote (TRAMP) buffers."
  (when (file-remote-p default-directory)
    ;; Version control — no git round-trips over SSH
    (setq-local vc-handled-backends nil)
    ;; Flycheck/flymake — no remote linter invocations
    (when (bound-and-true-p flycheck-mode) (flycheck-mode -1))
    (when (bound-and-true-p flymake-mode) (flymake-mode -1))
    ;; Auto-revert — no periodic remote stat calls
    (when (bound-and-true-p auto-revert-mode) (auto-revert-mode -1))
    (when (bound-and-true-p global-auto-revert-mode)
      (setq-local auto-revert-mode nil))
    ;; LSP — don't start a language server on the remote host
    (setq-local lsp-inhibit-lsp-hooks t)
    (when (bound-and-true-p lsp-mode) (lsp-disconnect))
    ;; Treemacs file watcher — no remote inotify
    (when (bound-and-true-p treemacs-filewatch-mode)
      (treemacs-filewatch-mode -1))
    ;; Git gutter — no remote git diff per line
    (when (bound-and-true-p git-gutter-mode) (git-gutter-mode -1))
    (when (bound-and-true-p diff-hl-mode) (diff-hl-mode -1))))

(add-hook 'find-file-hook #'vp/tramp-disable-heavy-modes)

;; Also suppress projectile indexing for remote projects — it tries to
;; enumerate every file over SSH which is the main cause of directory freezes.
(defadvice! vp/tramp-skip-projectile-remote (fn &rest args)
  :around #'projectile-project-root
  (unless (file-remote-p default-directory)
    (apply fn args)))
;; TRAMP (remote editing):1 ends here

;; [[file:config.org::*Ultra-scroll][Ultra-scroll:1]]
;;; NOTE: ultra-scroll replaces pixel-scroll-precision-mode with ~40% faster scrolling.
;;; Requires Emacs 29+ with pixel-scroll support.
(use-package! ultra-scroll
  :init
  (setq scroll-conservatively 101
        scroll-margin 0)             ; ultra-scroll handles margins itself
  :config
  (ultra-scroll-mode 1))
;; Ultra-scroll:1 ends here
