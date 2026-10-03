# ai-stack: rules for agents operating customer servers

This flake runs one customer's AI infrastructure on a dedicated server. Read
`REQUIREMENTS.org` for the decisions and their reasons, `OPERATIONS.org` for the
procedures. Follow the procedures; do not improvise around a failing step.

- The operator runs every customer server; customers never log in. Never act on a
  customer's behalf outside the procedure you were given.
- Nothing personal to the operator (accounts, notes, hostnames, paths) goes into this
  flake. Customer specifics live in the fleet repository.
- Secrets live only in sops files. Never print, log or commit a decrypted value; compare
  values by hash when you must.
- Admin interfaces stay on the tailnet. Never enable Tailscale Funnel; never open admin
  or backend ports on the public firewall.
- Read runtime logs before diagnosing configuration. A successful evaluation proves
  nothing about a running service.
- Do not delete application data or backups, and do not retire a running service,
  without the operator's approval.
