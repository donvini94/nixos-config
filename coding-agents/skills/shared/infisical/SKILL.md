---
name: infisical
description: Infisical project secrets. Use when a command needs credentials or API keys, when a project has a .env file or .infisical.json, or when adding or rotating a secret.
---

# Infisical

Project secrets live in the self-hosted Infisical on the tailnet. The `infisical` on PATH already targets that instance and signs in as this machine's identity; there is no login step.

## Running a command with secrets

```bash
infisical run --projectId <id> --env dev -- <command>
```

- The project ID is in the repository's `.infisical.yaml` (or legacy `.infisical.json`, key `workspaceId`); with a machine identity the CLI ignores those files, so pass it as `--projectId` (or export `INFISICAL_PROJECT_ID`). `infisical secrets-manager projects get` lists the projects this machine can reach.
- Environments are `dev`, `staging` and `prod` unless the project defines others (`infisical secrets --projectId <id> --env <env>` fails on an unknown slug).
- Use `--path /sub/folder` for secrets kept below the root folder.
- A `403` or "project not found" means this machine's identity has no access to that project: tell the user which project, and they add the identity in Infisical.

Secrets reach the process as environment variables only. Keep values out of the transcript: pass them through `infisical run`, and when one value must go to a file, pipe it (`infisical secrets get NAME --projectId <id> --env dev --plain > path`) rather than printing it.

## Replacing a .env file

Move each key into Infisical, delete the `.env`, and change the project's run instructions to `infisical run ... -- <command>`. Leave `.env.example` with names only.

## Adding or rotating a secret

```bash
infisical secrets set NAME=@/path/to/value-file --projectId <id> --env dev
```

Write generated values to a file the transcript never shows (`openssl rand -hex 32 > "$tmp"`), set from it, then delete the file. Restart whatever consumes the secret; `infisical run` reads values at process start.
