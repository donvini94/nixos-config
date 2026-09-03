# The `omp` command as an account actually installs it: upstream's pinned
# binary plus this repository's managed configuration overlay.
#
# Managed settings reach OMP only through its supported `PI_CONFIG_FILES`
# overlay, so everything OMP owns under `~/.omp/agent` stays writable and
# application-owned — OAuth credentials in `agent.db`, model-role assignments
# in `config.yml`. A rebuild therefore never invalidates a login.
#
# `enabledModels` is a selection scope, not a provider declaration. The two
# wildcard scopes below expose OMP's bundled Anthropic and OpenAI Codex
# catalogs without pinning a model list; each account authenticates them
# interactively against its own Claude and ChatGPT subscription, and a provider
# holding no credentials stays hidden. A login taken mid-session only shows up
# after OMP restarts: the picker's model list is built once at startup.
#
# `extraEnabledModels` is how a custom-provider profile (the local llama.cpp
# ingress, the Requesty ingress) is added on top. An account that passes
# nothing gets a harness scoped to its own subscription logins.
{
  callPackage,
  formats,
  lib,
  writeShellApplication,
  extraEnabledModels ? [ ],
}:

let
  yaml = formats.yaml { };
  ompPackage = callPackage ./omp.nix { };
  managedConfig = yaml.generate "omp-nixos-config.yml" {
    cycleOrder = [ "default" ];
    enabledModels = extraEnabledModels ++ [
      "anthropic/*"
      "openai-codex/*"
    ];
    # OMP's bundled llama.cpp provider probes loopback port 8080, which on both
    # hosts is the logging ingress, not a bare llama-server. The ingress is
    # reached through its declared profile or not at all.
    disabledProviders = [ "llama.cpp" ];
    advisor.enabled = false;
    tools.approvalMode = "always-ask";
    startup.checkUpdate = false;
    marketplace.autoUpdate = "off";
  };
in
writeShellApplication {
  name = "omp";
  text = ''
    managed_config=${lib.escapeShellArg (toString managedConfig)}
    if [[ -n "''${PI_CONFIG_FILES-}" ]]; then
      export PI_CONFIG_FILES="$PI_CONFIG_FILES:$managed_config"
    else
      export PI_CONFIG_FILES="$managed_config"
    fi

    # The model endpoint and policy are already configured. Upstream's
    # explicit `omp setup` command remains available when deliberately run.
    export OMP_SKIP_SETUP="''${OMP_SKIP_SETUP:-1}"
    exec ${lib.getExe ompPackage} "$@"
  '';
}
