{
  config,
  inputs,
  pkgs,
  site,
  username,
  ...
}:

let
  secretFile = ../../secrets/alucard-ai.yaml;
in
{
  imports = [
    inputs.ai-stack.nixosModules.default
    inputs.ai-stack.nixosModules.monitoringServer
    ../../coding-agents/nixos/requesty.nix
  ];

  # nixos-rebuild evaluates as root, which fetches the private ai-stack and ai-library
  # with read-only deploy keys; users keep their own GitHub keys. GitHub accepts any valid
  # deploy key before it knows the repository, so each repository gets its own host
  # name: git rewrites ai-library's URL to an alias whose only key is its own.
  sops.secrets = {
    "github/ai_stack_deploy_key".mode = "0400";
    "github/ai_library_deploy_key".mode = "0400";
    # Alucard is the fleet's deploy host; the fleet's helpers read these API credentials.
    "fleet/tailscale_oauth" = {
      owner = username;
      mode = "0400";
    };
    "fleet/hetzner_token" = {
      owner = username;
      mode = "0400";
    };
    "fleet/github_release_token" = {
      owner = username;
      mode = "0400";
    };
    # The alert bot, also used by the release gate to report.
    "fleet/telegram_bot_token" = {
      sopsFile = secretFile;
      key = "alertmanager/telegram_bot_token";
      owner = username;
      mode = "0400";
    };
  };
  programs.git = {
    enable = true;
    config.url."ssh://git@github-ai-library/donvini94/ai-library".insteadOf =
      "ssh://git@github.com/donvini94/ai-library";
  };
  programs.ssh = {
    knownHosts.github = {
      hostNames = [
        "github.com"
        "github-ai-library"
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    };
    extraConfig = ''
      Host github-ai-library
        HostName github.com
        HostKeyAlias github-ai-library
      Match localuser root originalhost github-ai-library
        IdentityFile ${config.sops.secrets."github/ai_library_deploy_key".path}
        IdentitiesOnly yes
      Match localuser root originalhost github.com
        IdentityFile ${config.sops.secrets."github/ai_stack_deploy_key".path}
        IdentitiesOnly yes
    '';
  };

  sops.secrets."alertmanager/telegram_bot_token" = {
    sopsFile = secretFile;
    mode = "0400";
    restartUnits = [ "alertmanager.service" ];
  };

  sops.secrets."monitoring/heartbeat_curl_config" = {
    sopsFile = secretFile;
    mode = "0400";
    restartUnits = [ "monitoring-heartbeat.service" ];
  };

  # Weekly release gate for the fleet (Sunday evening, before Monday's Release updates
  # PR): tags the canary's revisions when they pass. It runs as the operator, whose
  # checkout, SSH key and age key it uses.
  systemd.services.release-gate = {
    description = "Release gate for ai-stack and ai-library";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [
      config.nix.package
      pkgs.git
      pkgs.openssh
    ];
    serviceConfig = {
      Type = "oneshot";
      User = username;
      WorkingDirectory = "/home/${username}/code/fleet";
      ExecStartPre = "${pkgs.git}/bin/git pull --ff-only -q";
      ExecStart = "${config.nix.package}/bin/nix develop --command bin/release-gate";
      TimeoutStartSec = "3h";
    };
  };
  systemd.timers.release-gate = {
    enable = false;
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun 20:00";
      Persistent = true;
    };
  };

  # This host's interactive clients (Pi, OMP) use their own key, not the stack's.
  sops.secrets."requesty/operator_api_key" = {
    sopsFile = secretFile;
    owner = username;
    mode = "0400";
  };
  services.requesty.apiKeyFile = config.sops.secrets."requesty/operator_api_key".path;

  services.aiStack = {
    enable = true;
    secretsFile = secretFile;
    public = {
      domain = "agent.${site.domains.secondary}";
      acmeEmail = site.owner.mail;
    };
    features.onyx = {
      enable = true;
      domain = "chat.${site.domains.primary}";
    };
    hermes = {
      dashboardUser = "demo";
      telegram = true;
    };
    # The canary runs the library's items that every customer gets.
    library = {
      revision = inputs.ai-library.rev or "unknown";
      workflows = map (id: "${inputs.ai-library}/workflows/${id}.json") [
        "smoke-test"
        "aiStackTriage001"
        "aiStackIntake001"
        "aiStackLeads0001"
        "aiStackErrors001"
      ];
      # The test mailbox and the operator's chat stand in for a customer's.
      settings = {
        approvalChatId = "935728023";
        mailboxAddress = "agent-test@istbereit.de";
        senderName = site.owner.fullName;
        companyName = "Bereit";
        paperlessUrl = "http://127.0.0.1:${toString config.services.aiStack.features.paperless.port}";
      };
      hermesSkills = [ "${inputs.ai-library}/skills/human-approval" ];
    };
    sharedDirectory = {
      path = "/home/${username}/org";
      mountPoint = "/org";
      owner = username;
    };
  };

  # Alucard is the central monitoring server and the canary customer host.
  services.observability = {
    exporters.enable = true;
    server = {
      enable = true;
      secretsFile = secretFile;
      localTargets.n8n = 5678;
      hosts.staging.address = "staging.tailf117a1.ts.net";
      heartbeat.curlConfigFile = config.sops.secrets."monitoring/heartbeat_curl_config".path;
      alerting.telegram = {
        botTokenFile = config.sops.secrets."alertmanager/telegram_bot_token".path;
        # The operator's private chat with @bereit_alert_bot.
        chatId = 935728023;
      };
    };
  };

  # Keep the identity existing files and the Org ACL already use.
  services.hermesAgent = {
    uid = 985;
    gid = 981;
  };
}
