# n8n workflow source

`workflows/*.json` is the reviewed source of truth for the local n8n instance. Credential
values never belong here; create credentials in the browser UI and keep infrastructure
secrets in sops.

The helper commands call n8n's official CLI inside the running official container:

```bash
# Export to a new timestamped directory. From this checkout it uses the
# ignored `n8n/exports/`; the installed command uses XDG state storage.
n8n-workflows-export

# Export somewhere explicit for review. The destination must be empty.
n8n-workflows-export /tmp/n8n-review

# Import the workflows from this checkout and publish those with `active: true`.
n8n-workflows-import ./n8n/workflows
```

Imports update the SQLite database but a running n8n process may retain old trigger state.
After an import, use `ai-stack-stop && ai-stack-start` before testing production webhooks.
Review exported JSON before moving it into `workflows/`: workflow definitions can contain
addresses, prompts, file paths, and credential names/IDs even though encrypted credential
values are stored separately.

`dracula-provisioning-smoke.json` is an infrastructure acceptance workflow. It is safe to
leave active and verifies the local-model relay plus both external Code-node runners. It
is not an evaluation task and its results must not enter model-quality comparisons.

Business workflows, including mail ingestion, are deliberately separate from this
infrastructure definition. Build and review them in their own session, then export their
credential-free JSON here.

## Shared Org tree and Hermes

File nodes are restricted to `/org`, backed by `/home/vincenzo/org` on the host. Use focused
subdirectories such as `/org/ai-inbox` for workflow handoffs. Hermes mounts the same tree and
may call explicitly reviewed production webhooks on `http://127.0.0.1:5678/webhook/...`.

n8n reaches Hermes at `http://host.docker.internal:8642/v1`. Create an n8n Header Auth
credential with `Authorization: Bearer <hermes/api_server_key>`; retrieve the value from SOPS
only while entering the credential and never embed it in workflow JSON. The route exists only
on n8n's private bridge and is not a user-facing or tailnet port.
