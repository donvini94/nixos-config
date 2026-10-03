# Container and policy defaults for the startup's internal agent.
{
  image = "ubuntu:24.04@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517";
  containerOptions = [
    "--security-opt=no-new-privileges:true"
    "--pids-limit=512"
    "--memory=8g"
  ];

  runtimeEnv = {
    HERMES_DASHBOARD = "1";
    HERMES_DASHBOARD_HOST = "127.0.0.1";
    HERMES_DASHBOARD_PORT = "9119";
    HERMES_DASHBOARD_TUI = "1";
    API_SERVER_ENABLED = "true";
    API_SERVER_HOST = "127.0.0.1";
    API_SERVER_PORT = "8642";
    HERMES_WRITE_SAFE_ROOT = "/data/workspace:/data/.hermes:/org";
    # Upstream supports granular managed scope separately from its all-settings write lock.
    HERMES_MANAGED = "false";
    HERMES_MANAGED_DIR = "/data/policy";
  };

  mkDefaults =
    {
      providerName,
      defaultModel,
    }:
    {
      model = {
        default = defaultModel;
        provider = "custom:${providerName}";
      };
      terminal = {
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
      onboarding.profile_build = "off";
      dashboard.show_token_analytics = true;
    };

  mkPolicy = { providerName, ingressUrl }: {
    database.journal_mode = "wal";
    providers.${providerName} = {
      api = ingressUrl;
      transport = "chat_completions";
      discover_models = true;
      extra_headers.X-AI-Caller = "hermes";
    };
    model = {
      base_url = ingressUrl;
      default_headers.X-AI-Caller = "hermes";
    };
    terminal.backend = "local";
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
  };
}
