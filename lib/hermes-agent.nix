# Hermes agent deployment data shared by both hosts.
#
# Plain data, like lib/requesty-models.nix — consumed by the upstream
# `services.hermes-agent` module. Only the inference target differs per host:
# Dracula talks to its local llama-swap ingress, Alucard to the Requesty-backed
# one. Agent policy (toolsets, approvals, terminal shape) is deliberately
# identical so both agents behave the same way.
{
  # Base image for the upstream module's OCI mode. Container mode is what gives
  # the agent a persistent writable layer (apt/pip/npm/uv installs survive
  # restarts); native mode would take that capability away. Pinned by digest so
  # no activation ever silently adopts a new base — Renovate proposes bumps.
  image = "ubuntu:24.04@sha256:561618e2c15bf2397621dd04f96926663a3b5616c189cf7e38db7e82f5c538ea";

  # Passed to `docker create`. Part of the module's container identity hash, so
  # changing any of these recreates the container.
  containerOptions = [
    "--security-opt=no-new-privileges:true"
    "--pids-limit=512"
    "--memory=8g"
  ];

  # Non-secret half of $HERMES_HOME/.env. Secrets (API key, dashboard auth,
  # Telegram, webhook token) arrive through sops templates in environmentFiles.
  # Paths are container paths: the module mounts stateDir at /data.
  runtimeEnv = {
    HERMES_DASHBOARD = "1";
    HERMES_DASHBOARD_HOST = "127.0.0.1";
    HERMES_DASHBOARD_PORT = "9119";
    HERMES_DASHBOARD_TUI = "1";

    API_SERVER_ENABLED = "true";
    API_SERVER_HOST = "127.0.0.1";
    API_SERVER_PORT = "8642";

    HERMES_WRITE_SAFE_ROOT = "/data/workspace:/data/.hermes:/org";
  };

  # terminal.cwd is intentionally absent: the upstream module derives it from
  # workingDirectory, and anything set here would override that.
  mkSettings =
    {
      providerName,
      defaultModel,
      ingressUrl,
      contextLength,
    }:
    {
      database.journal_mode = "wal";

      providers.${providerName} = {
        api = ingressUrl;
        default_model = defaultModel;
        transport = "chat_completions";
        discover_models = true;
        extra_headers.X-AI-Caller = "hermes";
        models.${defaultModel}.context_length = contextLength;
      };

      model = {
        default = defaultModel;
        provider = "custom:${providerName}";
        base_url = ingressUrl;
        context_length = contextLength;
        default_headers.X-AI-Caller = "hermes";
      };

      terminal = {
        backend = "local";
        home_mode = "profile";
        timeout = 300;
      };

      platform_toolsets.cli = [
        "terminal"
        "file"
        "skills"
        "todo"
        "memory"
        "session_search"
        "cronjob"
      ];

      # Inference reaches the network through the ingress; the agent itself has
      # no business browsing, and the multimodal toolsets have no backing model.
      agent.disabled_toolsets = [
        "web"
        "browser"
        "vision"
        "image_gen"
        "tts"
      ];

      approvals = {
        mode = "manual";
        timeout = 300;
        cron_mode = "deny";
        mcp_reload_confirm = true;
        destructive_slash_confirm = true;
        deny = [
          "git push*"
          "*curl*|*sh*"
          "*wget*|*sh*"
        ];
      };

      onboarding.profile_build = "off";
      dashboard.show_token_analytics = true;
    };
}
