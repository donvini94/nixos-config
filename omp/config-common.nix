# Host-independent OMP settings — the single source of truth for every device.
#
# This file exists because the Mac is deliberately not nix-managed, and "set it by hand on
# each box" is what produced the drift this replaced: dracula and alucard got a generated
# overlay, the Mac got hand-typed values, and the two silently diverged.
#
# It is consumed twice:
#   * dracula, alucard — packages/omp-harness.nix imports this attrset and merges it into
#     the generated `PI_CONFIG_FILES` overlay.
#   * the Mac — scripts/omp-link-unmanaged.sh renders it to JSON with `nix eval --json`
#     and points `PI_CONFIG_FILES` at the result. OMP's generic config loader accepts
#     .json as well as .yml, so no YAML dependency is needed on an unmanaged host.
#
# Nix, not YAML, is the authored form: nix is the only reader that cannot be taught a new
# format, and rendering nix -> JSON is a one-liner while parsing YAML in nix needs IFD.
#
# ONLY genuinely universal settings belong here. Anything that names a provider-scoped
# model id, or that legitimately differs per host, stays out:
#   * `modelRoles`  — model ids differ per host (Requesty ingress vs Anthropic direct)
#   * `cycleOrder`  — depends on which roles that account actually has
#   * `tools.approvalMode`   — dracula/alucard run `always-ask`, the Mac runs `yolo`
#   * `startup.checkUpdate`  — false where nix owns the binary, true on the Mac where
#                              `omp update` does
{
  # Retired or unreachable discovery/model sources. `claude` is a discovery source, not
  # the Anthropic model provider; see packages/omp-harness.nix for why it is off.
  disabledProviders = [
    "llama.cpp"
    "lm-studio"
    "ollama"
    "claude"
  ];

  # Client tenant credentials pass through these sessions.
  secrets.enabled = true;

  # A second model reviewing every turn is a cost decision, not a default.
  advisor.enabled = false;

  # No marketplace plugins are installed on any host; startup checks are noise.
  marketplace.autoUpdate = "off";

  # Memory. `mnemopi` is the only backend that exposes the full tool set — `recall`,
  # `retain`, `reflect` and `memory_edit` — without standing up a server; the `local`
  # backend offers `learn` alone. Storage is a local SQLite bank per device under the
  # agent memories directory, so memory accumulates per host and is NOT synced: SQLite
  # under a file-sync tool corrupts, and per-project banks are keyed by a hash of the
  # absolute working directory, which differs between /Users/vincenzopace and
  # /home/vincenzo anyway. Shared cross-device memory needs the `hindsight` backend
  # against a server, which is a separate decision.
  memory.backend = "mnemopi";

  mnemopi = {
    # Project work writes to its own bank; recall additionally sees the shared global
    # bank, so durable general lessons surface everywhere without leaking client
    # specifics between projects.
    scoping = "per-project-tagged";
    # Resolve the `tiny` role then `smol` for Mnemopi's own LLM work, rather than
    # billing consolidation at the session model.
    llmMode = "smol";
  };

  # Makes the `learn` tool available so a lesson can be captured deliberately instead of
  # only being inferred from the transcript.
  autolearn.enabled = true;
}
