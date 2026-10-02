# Doom configuration

- `config.org` is the literate source; `config.el` is generated. Edit Org source
  blocks, never the generated file. Prose-only edits need no tangle.
- Saving in Emacs runs `org-auto-tangle`. Outside Emacs, run Org Babel tangling
  explicitly after changing code blocks, then review the generated diff.
- `init.el` selects modules; `packages.el` declares additional packages;
  `custom.el` is Emacs-generated state.
- Run `doom sync` after changing modules or packages. `doom doctor` checks the
  environment; it is not a substitute for loading the configuration.
- Shared configuration must work on macOS and Linux. Keep platform-specific
  paths and tools behind `system-type` checks.
- Mail and calendar configuration can change remote data. Preserve sync state,
  credentials, tagging rules and deletion behavior unless explicitly requested.
