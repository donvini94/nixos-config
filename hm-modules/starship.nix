{ ... }:
{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
      # Spawning a JVM/node per prompt exceeds starship's 500ms command timeout under load.
      java.disabled = true;
      nodejs.disabled = true;
    };
  };
}
