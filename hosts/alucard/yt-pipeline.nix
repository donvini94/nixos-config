# Kampfmaschine video pipeline (donvini94/yt-pipeline): worker, review bot, timers, artifact
# server and metrics. Listeners stay on localhost; the artifact server is published on the
# tailnet next to the other admin ports. Final YouTube upload stays manual.
{
  config,
  inputs,
  site,
  username,
  ...
}:
let
  secretFile = ../../secrets/alucard-ai.yaml;
  artifactPort = 8088;
  tailnetPort = 18088;
in
{
  imports = [ inputs.yt-pipeline.nixosModules.default ];

  # The operator runs `ytp` (status, topic-add, enqueue) against the service database.
  users.users.${username}.extraGroups = [ "yt-pipeline" ];

  sops.secrets = {
    "github/yt_pipeline_deploy_key".mode = "0400";
    "yt_pipeline/requesty_api_key".sopsFile = secretFile;
    "yt_pipeline/elevenlabs_api_key".sopsFile = secretFile;
    "yt_pipeline/telegram_token".sopsFile = secretFile;
    "yt_pipeline/telegram_chat_id".sopsFile = secretFile;
    "yt_pipeline/higgsfield_api_key".sopsFile = secretFile;
    # cookies.txt of a throwaway Google account: YouTube refuses downloads from netcup IPs.
    "yt_pipeline/youtube_cookies".sopsFile = secretFile;
  };

  # root fetches the private flake input with its own read-only deploy key (see ai.nix).
  programs.git.config.url."ssh://git@github-yt-pipeline/donvini94/yt-pipeline".insteadOf =
    "ssh://git@github.com/donvini94/yt-pipeline";
  programs.ssh = {
    knownHosts.github.hostNames = [ "github-yt-pipeline" ];
    extraConfig = ''
      Host github-yt-pipeline
        HostName github.com
        HostKeyAlias github-yt-pipeline
      Match localuser root originalhost github-yt-pipeline
        IdentityFile ${config.sops.secrets."github/yt_pipeline_deploy_key".path}
        IdentitiesOnly yes
    '';
  };

  services.yt-pipeline = {
    enable = true;
    # Code and resources from a git checkout: deploy with scripts/deploy.sh in the repo (seconds).
    source = "/var/lib/yt-pipeline/src";
    wikimediaContact = "vincenzo@istbereit.de";
    maxUsdPerJob = 3;
    linksBaseUrl = "http://${site.server}.${site.tailnet}:${toString tailnetPort}";
    serve.bind = "127.0.0.1";
    serve.port = artifactPort;
    metrics.bind = "127.0.0.1";
    secrets = {
      llmApiKeyFile = config.sops.secrets."yt_pipeline/requesty_api_key".path;
      elevenlabsApiKeyFile = config.sops.secrets."yt_pipeline/elevenlabs_api_key".path;
      telegramTokenFile = config.sops.secrets."yt_pipeline/telegram_token".path;
      telegramChatIdFile = config.sops.secrets."yt_pipeline/telegram_chat_id".path;
      higgsfieldApiKeyFile = config.sops.secrets."yt_pipeline/higgsfield_api_key".path;
      youtubeCookiesFile = config.sops.secrets."yt_pipeline/youtube_cookies".path;
    };
  };

  services.aiStack.tailnet.tcp.yt-pipeline = {
    listen = tailnetPort;
    target = artifactPort;
  };

  services.prometheus.scrapeConfigs = [
    {
      job_name = "yt-pipeline";
      static_configs = [
        { targets = [ "127.0.0.1:${toString config.services.yt-pipeline.metrics.port}" ]; }
      ];
    }
  ];
}
