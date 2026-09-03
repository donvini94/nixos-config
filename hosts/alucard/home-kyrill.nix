# Kyrill's account on Alucard: the OMP harness, scoped to his own logins.
#
# Deliberately narrower than the vincenzo home, and neither omission is an
# oversight:
#
#   * No authored agent context. `omp/AGENTS.md`, `omp/RULES.md` and
#     `omp/rules/*.md` are written in Vincenzo's first person and reference his
#     memory store at `~/.claude/memory`; handing them to another operator's
#     agent would state preferences he never gave. `~/.omp/agent/AGENTS.md`
#     stays an unmanaged writable file he can author himself.
#
#   * No Requesty ingress profile. The ingress binds loopback and performs no
#     per-user authorization, so which accounts receive the profile *is* the
#     spend boundary on Vincenzo's single upstream key. Kyrill reaches
#     Anthropic and OpenAI Codex through his own Claude and ChatGPT
#     subscription logins (`/providers`, then restart OMP), which the harness
#     package already scopes in.
{ pkgs, ... }:

{
  home = {
    username = "kyrill";
    homeDirectory = "/home/kyrill";
    stateVersion = "25.11";
    packages = [ (pkgs.callPackage ../../packages/omp-harness.nix { }) ];
  };
}
