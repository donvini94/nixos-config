{
  config,
  lib,
  osConfig ? null,
  pkgs,
  ...
}:

let
  home = config.home.homeDirectory;
  agentDir = "${home}/.pi/agent";
  repo = "${home}/nixos-config";
  link = config.lib.file.mkOutOfStoreSymlink;
  requesty = import ../lib/requesty-models.nix;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  isDracula = !isDarwin && osConfig.networking.hostName == "dracula";
  requestyEndpoint =
    if isDracula then "http://alucard.tailf117a1.ts.net:28080/v1" else "http://127.0.0.1:8080/v1";

  # The Pi binary is an npm global in ~/.local, not a nix package. Pinning the version here keeps
  # the three hosts on one release; `agent-update` bumps it. See docs/PI.md for the nix cutover.
  piVersion = "1.0.0";

  upstreamRevision = "f82da563ab05d66729492d64c7ed4e96db3663f3";
  upstream = path: hash:
    pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/amosblomqvist/pi-config/${upstreamRevision}/${path}";
      inherit hash;
    };
  amosAskUserQuestion = upstream "extensions/ask-user-question.ts" "sha256-Yrw+3fkZtAtguaVdKyYu6513thVYrGmlidvE3r92hkU=";
  amosWebFetchIndex = upstream "extensions/web-fetch/index.ts" "sha256-XkbGHMRtYJjG2Fb5FzJxHadl6Xd1nOxKYAZNl/5aiLE=";
  amosWebFetchPackage = upstream "extensions/web-fetch/package.json" "sha256-4lYfuZ56pzSpuDexodOa4ZiADnreQ/fhNab+0INNhC4=";
  amosWebFetchLock = upstream "extensions/web-fetch/package-lock.json" "sha256-3/ofJOqI8pLzHQjEgMoaMA4sw1WFljpGVUQ/hPyI7qo=";

  toPiModel = id: model: {
    inherit id;
    name = model.name;
    reasoning = model.reasoning;
    input = [ "text" ];
    contextWindow = model.context;
    maxTokens = model.output;
    cost = model.cost // {
      cacheRead = 0;
      cacheWrite = 0;
    };
  };
  requestyProvider = {
    name = "Alucard Requesty";
    baseUrl = requestyEndpoint;
    api = "openai-completions";
    # Pi hides a provider with no key; the ingress ignores this placeholder (authHeader is off).
    apiKey = "unused";
    # The ingress authenticates this host; Pi must not invent an Authorization header.
    authHeader = false;
    headers.X-AI-Caller = "pi";
    models = lib.mapAttrsToList toPiModel requesty.models;
  };
  localProvider = {
    name = "Dracula local llama.cpp";
    baseUrl = "http://127.0.0.1:8080/v1";
    api = "openai-completions";
    authHeader = false;
    apiKey = "unused";
    headers.X-AI-Caller = "pi";
    models = lib.mapAttrsToList (
      id: model: {
        inherit id;
        name = model.displayName;
        reasoning = model.reasoning;
        input = [ "text" ];
        contextWindow = model.contextSize;
        maxTokens = model.output;
        cost = model.cost // {
          cacheRead = 0;
          cacheWrite = 0;
        };
        compat = {
          supportsStore = false;
          supportsDeveloperRole = false;
          supportsReasoningEffort = false;
          maxTokensField = "max_tokens";
        };
      }
    ) osConfig.services.localLlama.models;
  };
  piModels = {
    providers =
      if isDarwin then
        { }
      else
        {
          alucard-requesty = requestyProvider;
        }
        // lib.optionalAttrs isDracula {
          dracula-local = localProvider;
        };
  };

  piSettings = {
    # Pi owns this file after the first activation. Do not make it a Home Manager link:
    # /settings, pi config and Pi package management update it in place.
    defaultProjectTrust = "ask";
    defaultProvider = "claude-bridge";
    defaultModel = "claude-sonnet-5-5";
    defaultTools = [ "read" "bash" "edit" "write" ];
    externalEditor = "emacsclient -c -a emacs";
    packages = [
      "${home}/code/omp-mentor"
      "${home}/code/omp-prompt-snippets"
      "${home}/code/omp-learn"
      "git:github.com/HazAT/pi-interactive-subagents@c100577ebf7393a11d098ad9810ec6c269dcfc30"
      "npm:pi-claude-bridge"
    ];
    extensions = [
      "${agentDir}/upstream/amos-ask-user-question.ts"
      "${agentDir}/upstream/amos-web-fetch"
    ];
    # Keep Pi-owned and package skills, without the shared harness policy skills.
    # Pi discovers ~/.agents/skills automatically; exclude that tree explicitly.
    skills = [ "!${home}/.agents/skills/**" ];
  };
in
{
  home.file = {
    # AGENTS.md and MEMORY.md are agent-owned writable files, not Nix resources.
    ".pi/agent/skills/mentor".source = link "${home}/code/omp-mentor/skills/mentor";
    ".pi/agent/skills/meeting-minutes".source = link "${repo}/pi/skills/meeting-minutes";
    ".pi/agent/agents/researcher.md".source = link "${home}/code/omp-learn/agents/researcher.md";
    ".pi/agent/agents/mermaid-maker.md".source = link "${home}/code/omp-learn/agents/mermaid-maker.md";
    ".pi/agent/agents/svg-maker.md".source = link "${home}/code/omp-learn/agents/svg-maker.md";
    ".pi/agent/upstream/amos-ask-user-question.ts".source = amosAskUserQuestion;
  };

  # Scope HazAT's multiplexer choice to Pi invocations.
  programs.fish.functions.pi = {
    body = ''
      set -lx PI_SUBAGENT_MUX zellij
      command pi $argv
    '';
  };

  home.activation.piAgentBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    agent_dir=${lib.escapeShellArg agentDir}

    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$agent_dir/upstream/amos-web-fetch"
    # Remove the retired global MCP configuration; instructions and memory are agent-owned.
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f "$agent_dir/mcp.json"
    # Pi rewrites these files itself (changelog marker, /settings, `pi install`), so Home Manager
    # cannot own them. Declared keys are re-applied on every activation and win over the file;
    # keys Pi added that this module does not declare are kept. Arrays (packages, extensions,
    # skills) are replaced wholesale, which is the point: a package installed by hand on one
    # host disappears at the next switch unless it is declared here, so hosts cannot drift.
    reconcile() {
      target="$1"
      declared="$2"
      if [ ! -e "$target" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 600 "$declared" "$target"
      elif [ -z "''${DRY_RUN:-}" ]; then
        merged="$(${pkgs.coreutils}/bin/mktemp "$target.XXXXXX")"
        ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$target" "$declared" > "$merged"
        ${pkgs.coreutils}/bin/chmod 600 "$merged"
        ${pkgs.coreutils}/bin/mv "$merged" "$target"
      fi
    }
    reconcile "$agent_dir/settings.json" ${pkgs.writeText "pi-settings.json" (builtins.toJSON piSettings)}
    reconcile "$agent_dir/models.json" ${pkgs.writeText "pi-models.json" (builtins.toJSON piModels)}
    if [ ! -e "$agent_dir/upstream/amos-web-fetch/package.json" ]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 600 ${amosWebFetchIndex} "$agent_dir/upstream/amos-web-fetch/index.ts"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 600 ${amosWebFetchPackage} "$agent_dir/upstream/amos-web-fetch/package.json"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 600 ${amosWebFetchLock} "$agent_dir/upstream/amos-web-fetch/package-lock.json"
      if [ -z "''${DRY_RUN:-}" ]; then
        (
          cd "$agent_dir/upstream/amos-web-fetch"
          ${pkgs.nodejs}/bin/npm ci --ignore-scripts
        )
      fi
    fi
  '';

  # The three personal content repositories are plain git checkouts, so git is the sync
  # mechanism: every switch fast-forwards them from GitHub over HTTPS (no key
  # needed, remotes untouched). A dirty or diverged checkout is reported, never overwritten.
  home.activation.piBinary = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH=${lib.makeBinPath [ pkgs.nodejs pkgs.coreutils ]}:$HOME/.local/bin:$PATH
    if [ -z "''${DRY_RUN:-}" ] && [ "$(pi --version 2>/dev/null)" != "${piVersion}" ]; then
      npm install -g --prefix "$HOME/.local" --ignore-scripts "@earendil-works/pi-coding-agent@${piVersion}" \
        || echo "piBinary: installing pi ${piVersion} failed (offline?)" >&2
    fi
  '';

  home.activation.agentContentRepos = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH=${lib.makeBinPath [ pkgs.git pkgs.bun pkgs.coreutils ]}:$PATH
    code_dir=${lib.escapeShellArg "${home}/code"}
    $DRY_RUN_CMD mkdir -p "$code_dir"
    for repo in omp-learn omp-mentor omp-prompt-snippets; do
      dir="$code_dir/$repo"
      url="https://github.com/donvini94/$repo.git"
      if [ ! -d "$dir/.git" ]; then
        $DRY_RUN_CMD git clone --quiet "$url" "$dir" || echo "agentContentRepos: cloning $repo failed (offline?)" >&2
        continue
      fi
      if [ -n "$(git -C "$dir" status --porcelain)" ]; then
        echo "agentContentRepos: $repo has local changes, not updating" >&2
        continue
      fi
      branch="$(git -C "$dir" symbolic-ref --short HEAD)"
      $DRY_RUN_CMD git -C "$dir" pull --quiet --ff-only "$url" "$branch" \
        || echo "agentContentRepos: updating $repo failed (offline or diverged)" >&2
    done
    # omp-learn imports zod at runtime for both harnesses.
    if [ -z "''${DRY_RUN:-}" ] && [ -f "$code_dir/omp-learn/bun.lock" ]; then
      (cd "$code_dir/omp-learn" && bun install --frozen-lockfile --silent) \
        || echo "agentContentRepos: bun install failed in omp-learn" >&2
    fi
  '';
}
