# Dracula local AI evaluation

This evaluator compares the complete coding loop, not isolated chat completions. Each cell
starts from the task's pinned git revision in a disposable worktree, runs OMP or OpenCode
against an explicitly selected model, executes task-specific oracles, and joins the result
to ingress measurements by `X-AI-Eval-Run`.

Langfuse is not the evaluator. The JSON task/result formats and JSONL ingress records stay
the source of truth so an experiment remains reproducible without a dashboard service.
The local Langfuse service is the visualization, annotation, dataset, and experiment sink;
use it to inspect and score traces, while keeping task definitions and oracle results here.

## Curate real tasks

Candidate listing never prints payloads:

```bash
ai-eval-harvest list --caller omp --caller opencode --limit 20
```

Extraction copies only the last user message into the ignored `eval/drafts/` directory:

```bash
ai-eval-harvest extract \
  --timestamp 2026-08-08T20:34:10.188547+00:00 \
  --id example-task \
  --output example-task.json \
  --revision FULL_STARTING_COMMIT
```

Inspect the draft for secrets, reconstruct and verify the actual starting revision, add an
automated command oracle wherever possible, and only then move it to `eval/tasks/`.
Responses are never copied by the harvester. A task without a trustworthy starting state
is not replayable and must not enter the comparison.

## Run one cell

```bash
ai-eval run eval/tasks/TASK.json \
  --harness omp \
  --model dirk-qwen3.8-27b-local \
  --auto-approve \
  --experiment phase2-pilot
```

`--auto-approve` is explicit because both harnesses may execute shell commands. The git
worktree is disposable, but this is not a security sandbox: use it only with trusted tasks
and repositories. Without that flag, normal harness approval policy remains active.

## Run a paired randomized matrix

```bash
ai-eval matrix eval/tasks/*.json \
  --harness omp --harness opencode \
  --model dirk-qwen3.8-27b-local --model qwen3.6-35b-a3b \
  --seed 20260808 \
  --auto-approve \
  --experiment phase2-2x2
```

Cells execute sequentially because the 3090 can hold only one model at a time. The seeded
order prevents every second harness/model from receiving the same cache-order advantage.
Raw harness output, patches, oracle logs, and machine-readable results are written below
ignored `eval/.runs/`. Review the manual fields for tool retries, interventions, and
surprising actions before committing a curated result table to `eval/results/`.

`eval/smoke/write-file.json` validates infrastructure only. It is synthetic and must never
be included in model-quality conclusions.
