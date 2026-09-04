# The `omp` command as an account actually installs it: upstream's pinned
# binary plus this repository's managed configuration overlay.
#
# Managed settings reach OMP only through its supported `PI_CONFIG_FILES`
# overlay, so everything OMP owns under `~/.omp/agent` stays writable and
# application-owned — OAuth credentials in `agent.db`, and the `default` and
# `slow` model roles in `config.yml`. A rebuild therefore never invalidates a
# login and never overwrites the model the operator last chose.
#
# `modelRoles` here carries only the roles that are infrastructure rather than
# preference. `smol` is the one that matters: the bundled `scout`, `sonic` and
# `librarian` agents all declare `model: "@smol"`, and OMP also spends it on
# prewalk, session titles and memory consolidation. Left unset it falls back to
# `@default`, which bills every cheap background call at the session model's
# reasoning effort and leaves subagent titles ungenerated. `task` is
# deliberately NOT set: the general-purpose worker does real implementation
# work, so it keeps the session model rather than being quietly downgraded.
# The overlay deep-merges per key, so naming `smol` here leaves an operator's
# `default`/`slow` in `config.yml` untouched — verified with
# `PI_CONFIG_FILES=<overlay> omp config get modelRoles`.
#
# Roles are a parameter, not a constant, because they name provider-scoped
# model ids. An account that is not given the Requesty profile must not be
# handed a role pointing into it; see `hosts/alucard/home-kyrill.nix`.
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
  modelRoles ? { },
  cycleOrder ? [ "default" ],
}:

let
  yaml = formats.yaml { };
  ompPackage = callPackage ./omp.nix { };
  # Universal policy — disabled sources, secrets redaction, advisor, memory. Authored
  # once in omp/config-common.nix so AC-0137 reads the same values instead of
  # a hand-typed copy of them. See that file for what deliberately stays host-specific.
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
