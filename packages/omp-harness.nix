# Managed overlays leave OAuth state and user-selected default/slow roles writable.
# Custom model scopes and infrastructure roles are supplied per account.
{
  callPackage,
  formats,
  lib,
  symlinkJoin,
  writeShellApplication,
  writeText,
  extraEnabledModels ? [ ],
  modelRoles ? { },
  cycleOrder ? [ "default" ],
  localModel ? null,
}:

let
  yaml = formats.yaml { };
  ompPackage = callPackage ./omp.nix { };
  # Universal policy — disabled sources, secrets redaction, advisor, memory.
  # omp/config-common.nix also marks what deliberately stays host-specific.
  common = import ../omp/config-common.nix;
  managedConfig = yaml.generate "omp-nixos-config.yml" (
    lib.recursiveUpdate common {
      inherit cycleOrder modelRoles;
      enabledModels = extraEnabledModels ++ [
        "anthropic/*"
        "openai-codex/*"
      ];
      # Host-specific: nix owns this binary, so OMP must not offer to replace it.
      startup.checkUpdate = false;
      tools.approvalMode = "always-ask";
    }
  );

  ompLauncher = writeShellApplication {
    name = "omp";
    text = ''
      managed_config=${lib.escapeShellArg (toString managedConfig)}
      if [[ -n "''${PI_CONFIG_FILES-}" ]]; then
        export PI_CONFIG_FILES="$PI_CONFIG_FILES:$managed_config"
      else
        export PI_CONFIG_FILES="$managed_config"
      fi

      # Endpoint and policy are already configured; `omp setup` stays available when run
      # deliberately.
      export OMP_SKIP_SETUP="''${OMP_SKIP_SETUP:-1}"
      exec ${lib.getExe ompPackage} "$@"
    '';
  };

  # Local sessions use a separate profile: model selection alone does not isolate
  # memory, discovery or background calls. Disable both remote model providers and
  # foreign config sources; native still loads AGENTS.md.
  localConfig = yaml.generate "omp-local-config.yml" {
    disabledProviders = [
      "agent-plugins"
      "agents"
      "alucard-requesty"
      "anthropic"
      "claude"
      "claude-md"
      "claude-plugins"
      "cline"
      "codex"
      "cursor"
      "gemini"
      "github"
      "google"
      "groq"
      "llama.cpp"
      "lm-studio"
      "mcp-json"
      "ollama"
      "omp-plugins"
      "opencode"
      "openai"
      "openai-codex"
      "openrouter"
      "ssh-json"
      "vscode"
      "windsurf"
    ];
    enabledModels = [ localModel ];
    modelRoles = {
      default = localModel;
      slow = localModel;
      smol = localModel;
    };
    cycleOrder = [ "default" ];
    memory.backend = "off";
    autolearn.enabled = false;
    advisor.enabled = false;
    secrets.enabled = true;
    mcp.enableProjectConfig = false;
    startup.checkUpdate = false;
    tools.approvalMode = "always-ask";
    compaction = {
      asyncEnabled = false;
      methodOrder = [
        "shake"
        "soft"
      ];
      reserveTokens = 8192;
      keepRecentTokens = 12000;
    };
  };

  # A smaller prompt/tools set leaves context for code; AGENTS.md still loads.
  localSystemPrompt = writeText "omp-local-system-prompt.md" ''
    You are a repository coding agent. Complete the user's requested work with the smallest maintainable change.

    Inspect relevant code before editing and follow loaded AGENTS.md instructions. Use read, grep, and glob for discovery; never substitute shell text-search commands. Use edit for existing files and write for new files. Fix causes rather than suppressing symptoms. Do not add unrelated features, abstractions, documentation, or tests. Verify changed behavior with the narrowest real command or scenario before finishing.

    Use the lsp tool for symbol definitions, references, implementations, type information, diagnostics, renames, and code actions. Before changing an exported symbol, inspect every reference through LSP. Prefer LSP over text search whenever language-aware results are available.
  '';

  # PI_CONFIG_FILES is cleared, not appended to: the managed overlay names Requesty and
  # subscription model scopes, and inheriting it from a parent `omp` shell would put remote
  # models back in reach. NULL_PROMPT likewise must not leak in from an `omp-chat` shell.
  localLauncher = writeShellApplication {
    name = "omp-local";
    text = ''
      unset PI_CONFIG_FILES
      unset NULL_PROMPT
      export OMP_SKIP_SETUP=1
      exec ${lib.getExe ompPackage} \
        --profile local \
        --config ${localConfig} \
        --model ${lib.escapeShellArg localModel} \
        --thinking low \
        --tools read,grep,glob,bash,edit,write,lsp \
        --system-prompt ${localSystemPrompt} \
        --no-title \
        --no-skills \
        --no-rules \
        --no-extensions \
        "$@"
    '';
  };

  # /tmp avoids loading repository context into tool-free chat.
  chatLauncher = writeShellApplication {
    name = "omp-chat";
    text = ''
      unset PI_CONFIG_FILES
      export NULL_PROMPT=true
      export OMP_SKIP_SETUP=1
      exec ${lib.getExe ompPackage} \
        --profile local \
        --config ${localConfig} \
        --cwd /tmp \
        --model ${lib.escapeShellArg localModel} \
        --thinking off \
        --no-tools \
        --no-lsp \
        --no-title \
        --no-skills \
        --no-rules \
        --no-extensions \
        "$@"
    '';
  };
  localLaunchers = lib.optionals (localModel != null) [
    localLauncher
    chatLauncher
  ];
in
symlinkJoin {
  name = "omp-harness";
  paths = [ ompLauncher ] ++ localLaunchers;
  meta.mainProgram = "omp";
}
