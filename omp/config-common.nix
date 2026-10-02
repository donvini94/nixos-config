# Shared OMP defaults; provider models, approvals and update policy are host-specific.
{
  # Disable automatic discovery; configured local models use the managed providers.
  disabledProviders = [
    "llama.cpp"
    "lm-studio"
    "ollama"
    "claude"
  ];

  # Client tenant credentials pass through these sessions.
  secrets.enabled = true;
  advisor.enabled = false;
  marketplace.autoUpdate = "auto";

  # Mnemopi provides recall and explicit retention in per-device SQLite banks.
  # Do not file-sync these databases; project identities contain absolute paths.
  memory.backend = "mnemopi";
  mnemopi = {
    scoping = "per-project-tagged";
    llmMode = "smol";
    # Save only deliberately retained facts, not raw conversation chunks.
    autoRetain = false;
  };
  autolearn.enabled = true;

  theme.dark = "titanium";
  symbolPreset = "unicode";
  statusLine = {
    preset = "default";
    separator = "powerline";
  };
  composer.shape = "box";
  edit.mode = "hashline";
  startup.showSplash = false;
  hideThinkingBlock = false;
}
