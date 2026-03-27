;;; init.el -*- lexical-binding: t; -*-

(doom!
 :completion
 (corfu +icons +orderless)  ; Modern code completion
 (vertico +icons)           ; Modern minibuffer completion

 :ui
 doom              ; what makes DOOM look the way it does
 doom-dashboard    ; a nifty splash screen for Emacs
 (emoji +unicode)  ; 🙂
 hl-todo           ; highlight TODO/FIXME/NOTE/DEPRECATED/HACK/REVIEW
 (ligatures +extra); ligatures and symbols to make your code pretty again
 modeline          ; snazzy, Atom-inspired modeline, plus API
 nav-flash         ; blink cursor line after big motions
 ophints           ; highlight the region an operation acts on
 (popup +defaults) ; tame sudden yet inevitable temporary windows
 vc-gutter         ; vcs diff in the fringe
 vi-tilde-fringe   ; fringe tildes to mark beyond EOB
 (window-select +numbers) ; visually switch windows
 workspaces        ; tab emulation, persistence & separate workspaces
 zen               ; distraction-free coding or writing

 :editor
 (evil +everywhere); come to the dark side, we have cookies
 file-templates    ; auto-snippets for empty files
 fold              ; (nigh) universal code folding
 (format +onsave)  ; automated prettiness
 snippets          ; my elves. They type so I don't have to
 word-wrap         ; soft wrapping with language-aware indent
 rotate-text

 :emacs
 (dired +dirvish +icons)             ; making dired pretty [functional]
 electric          ; smarter, keyword-based electric-indent
 (ibuffer +icons)         ; interactive buffer management
 (undo +tree)              ; persistent, smarter undo for your inevitable mistakes
 vc                ; version-control and Emacs, sitting in a tree

 :term
 eshell            ; the elisp shell that works everywhere
 vterm

 :checkers
 syntax              ; tasing you for every semicolon you forget
 ;;spell             ; replaced by jinx (faster, async, enchant-based)

 :tools
 (debugger +lsp)          ; FIXME stepping through code, to help you add bugs
 direnv
 (docker +lsp)
 editorconfig      ; let someone else argue about tabs vs spaces
 ;;ein               ; tame Jupyter notebooks with emacs
 (eval +overlay)     ; run code, run (also, repls)
 (lookup +dictionary + offline +docsets)              ; navigate your code and its documentation
 (lsp +peek)               ; M-x vscode
 magit              ; a git porcelain for Emacs
 (pass +auth)              ; password manager for nerds
 ;;pdf             ; replaced by emacs-reader (supports PDF, EPUB, MOBI, etc.)
 tree-sitter
 llm               ; AI chat with Claude, GPT, Gemini (gptel)

 :os
 (:if IS-MAC macos)  ; improve compatibility with macOS
 tty               ; improve the terminal Emacs experience

 :lang
 emacs-lisp        ; drown in parentheses
 (go +lsp +tree-sitter)                ; Go with gopls
 ;; haskell
 (java +lsp +tree-sitter)              ; Java with jdtls
 json
 (latex +cdlatex)                      ; fast math/environment input with cdlatex
 markdown
 (nix +lsp +tree-sitter)                  ; Nix with nixd LSP and tree-sitter
 (org +dragndrop +pomodoro +roam)      ; organize your plain life in plain text
 (python +lsp +tree-sitter)            ; Python with ty (Astral's Rust-based LSP)
 (rust +lsp +tree-sitter)              ; Fe2O3.unwrap().unwrap().unwrap().unwrap()
 (sh +lsp +tree-sitter)                ; she sells {ba,z,fi}sh shells on the C xor
 web                                   ; the tubes
 (yaml +lsp)                           ; JSON, but readable

 :config
 literate
 (default +bindings +smartparens)
 )
