# The `omp` command as an account actually installs it: upstream's pinned binary plus
# this repository's managed configuration overlay.
#
# Managed settings reach OMP only through its supported `PI_CONFIG_FILES` overlay, so
# everything OMP owns under `~/.omp/agent` stays writable and application-owned — OAuth
# credentials in `agent.db`, and the `default` and `slow` model roles in `config.yml`. A
# rebuild therefore never invalidates a login and never overwrites the model the operator
# last chose.
#
# `modelRoles` here carries only the roles that are infrastructure rather than
# preference. `smol` is the one that matters: the bundled `scout`, `sonic` and
# `librarian` agents all declare `model: "@smol"`, and OMP also spends it on prewalk,
# session titles and memory consolidation. Left unset it falls back to `@default`, which
# bills every cheap background call at the session model's reasoning effort and leaves
# subagent titles ungenerated. `task` is deliberately NOT set: the general-purpose worker
# does real implementation work, so it keeps the session model. The overlay deep-merges
# per key, so naming `smol` here leaves an operator's `default`/`slow` in `config.yml`
# untouched.
#
# Roles are a parameter, not a constant, because they name provider-scoped model ids. An
# account that is not given the Requesty profile must not be handed a role pointing into
# it; see `hosts/alucard/home-kyrill.nix`.
#
# `enabledModels` is a selection scope, not a provider declaration. The two wildcard
# scopes below expose OMP's bundled Anthropic and OpenAI Codex catalogs without pinning a
# model list; each account authenticates them interactively against its own Claude and
# ChatGPT subscription, and a provider holding no credentials stays hidden. A login taken
# mid-session only shows up after OMP restarts: the picker's model list is built once at
# startup.
#
# `extraEnabledModels` adds a custom-provider profile (the local llama.cpp ingress, the
# Requesty ingress) on top. An account that passes nothing gets a harness scoped to its
# own subscription logins.
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

  # `omp-local` / `omp-chat`: the responsive local-model modes, given as separate commands
  # rather than an in-session `/local`. A running session can be handed a different model,
  # tool set and system prompt, but not a different privacy boundary: memory backend, MCP
  # discovery, title generation and compaction routing are resolved per process. A named
  # profile relocates every one of those to ~/.omp/profiles/local, so "no prompt leaves the
  # machine" is a property of the process rather than of an extension catching every path.
  #
  # The full harness starts a 32k-context local model at ~24k tokens — above OMP's default
  # 16k-reserve compaction threshold — so its first successful turn is already eligible for
  # compaction and its handoff/summarization requests overflow TabbyAPI's single slot. This
  # config trades tools for headroom: ~11k tokens of prompt, a 24,576-token threshold
  # (32768 - 8192), deterministic `shake` before any summarization model, and no
  # speculative compaction competing for the one inference slot.
  #
  # `disabledProviders` carries two id namespaces at once: model backends (anthropic,
  # openai, google, groq, openrouter, ollama, and the custom `alucard-requesty` profile) and
  # config-discovery sources (claude, codex, gemini, cursor, ... ). Both are named here, so
  # neither a remote model nor another harness's context file can enter these sessions.
  # `native` stays enabled: it is what carries AGENTS.md into `omp-local`.
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

  # `--system-prompt` swaps OMP's default instruction template (~6.5k tokens of tool
  # policy, internal-URL catalog, delegation and workflow rules) for this text while the
  # custom template still renders discovered context files, so AGENTS.md survives. Tool
  # schemas dominate what is left: the six core tools plus lsp cost ~4k tokens, against
  # ~15k for the full set. Everything the prompt no longer explains — subagents, hub, eval,
  # xd:// devices — is also absent from `--tools`, so nothing is described that is missing
  # or missing that is described.
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

  # Bare chat: NULL_PROMPT empties the system prompt entirely (no personality, workstation
  # block, memory or MCP guidance), `--cwd /tmp` keeps repository context files out of a
  # conversation that has no tools to use them with, and `--thinking off` reaches the Qwen
  # template's `enable_thinking: false`. Measured shape: 17 prompt tokens, no tools.
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
