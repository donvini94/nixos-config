# Fleet: customer servers

Each file in `customers/` is one customer's server; `common.nix` holds what all share.
Operate them only by the procedures in the ai-stack's `OPERATIONS.org` and under its
`AGENTS.md` rules. Secrets live in `secrets/`, encrypted for the operator and the one
server that needs them (`.sops.yaml`).
