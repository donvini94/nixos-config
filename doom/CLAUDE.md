# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Personal Doom Emacs configuration for Vincenzo Pace. This is a **literate config** — `config.org` is the source of truth, and `config.el` is auto-tangled from it.

## Critical: Edit config.org, NOT config.el

`config.el` is generated automatically by `org-auto-tangle` whenever `config.org` is saved. Any direct edits to `config.el` will be silently overwritten. Always edit the corresponding `#+begin_src emacs-lisp` block in `config.org`.

The tangling is controlled by the file-level header:
```
#+property: header-args:emacs-lisp :tangle yes :comments link
```

## File Roles

- **`config.org`** — Literate source of all configuration. Organized by topic headings. Edit this file.
- **`config.el`** — Auto-generated output. Never edit directly.
- **`init.el`** — Doom module selection (`doom!` block). Defines which Doom modules are active.
- **`packages.el`** — Extra packages beyond what Doom modules provide.
- **`custom.el`** — Emacs customize-generated settings (safe to leave alone).

## Commands

```bash
# Sync after changing init.el or packages.el (installs/removes packages, rebuilds autoloads)
doom sync

# Full rebuild (also recompiles bytecode)
doom sync -u

# Check config for errors without starting Emacs
doom doctor

# Refresh packages only
doom build
```

After editing `config.org`: just save the file in Emacs — `org-auto-tangle` handles the rest. No manual tangle step needed.

## Architecture Decisions

**Literate config with `org-auto-tangle`**: The `config.org` → `config.el` pipeline runs on every save via `org-auto-tangle-mode`. Each code block gets a `link` comment pointing back to its source heading.

**LSP Booster**: An `emacs-lsp-booster` wrapper is applied via advice on `lsp-resolve-final-command`. It accelerates JSON parsing for all LSP servers *except* jdtls (Java), which is excluded because its large indexing payloads overflow the booster's buffer.

**Completion stack**: Corfu + Cape (not company-mode). LSP completion provider is set to `:none` so corfu handles it directly.

**Document reader**: `pdf-tools` is disabled and replaced by `emacs-reader` (supports PDF, EPUB, MOBI, DOCX, etc.). Old `pdf-view` bookmarks are redirected via a custom jump handler.

**macOS / Linux cross-compat**: Several settings are gated on `(eq system-type 'darwin)` — git path for magit, Java home resolution, screenshot commands, mac key modifiers, trash handling. The Java config assumes macOS `/usr/libexec/java_home`; this will need adjustment on Linux if Java/jdtls is used there.

**AI integrations**: gptel (Claude via Anthropic API, key from env or auth-sources) and claude-code-ide (`SPC C` to open menu).

## Key Custom Bindings

| Binding | Action |
|---------|--------|
| `SPC l` | LLM/gptel prefix (chat, send, menu, add file/buffer) |
| `SPC C` | Claude Code IDE menu |
| `SPC d` | DAP debugger prefix |
| `SPC j` | Avy goto char 2 |
| `SPC m a p` | Anki push notes |
| `SPC m a c` | Org download clipboard |
| `F5` | Toggle modus-themes (light/dark) |

## Org Setup

- Org directory: `~/org/`
- GTD workflow: TODO → NEXT → HOLD → DONE
- Org-roam templates: main, reference, people, paper, meeting, book notes
- Dailies include structured review templates (daily/weekly/monthly/1on1)
- Anki integration via `anki-editor` with capture templates for basic and cloze cards
