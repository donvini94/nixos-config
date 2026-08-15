#!/usr/bin/env python3
"""Run paired coding-harness evaluations in disposable git worktrees."""

import argparse
import datetime as dt
import hashlib
import json
import os
import random
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path


def find_repo_root():
    override = os.environ.get("AI_EVAL_REPO")
    if override:
        return Path(override).resolve()
    completed = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if completed.returncode == 0:
        return Path(completed.stdout.strip()).resolve()
    return Path(__file__).resolve().parents[1]


REPO_ROOT = find_repo_root()
DEFAULT_LOG = Path("/var/lib/llama/logs/requests.jsonl")
MODEL_PROVIDER = "dracula-local"
HARNESS_CALLERS = {"omp": "omp", "opencode": "opencode"}


def run_process(command, *, cwd, env=None, timeout=None, stdout=None, stderr=None):
    return subprocess.run(
        command,
        cwd=cwd,
        env=env,
        timeout=timeout,
        stdout=stdout,
        stderr=stderr,
        text=True,
        check=False,
    )


def command_output(command, *, cwd=REPO_ROOT):
    completed = run_process(
        command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    if completed.returncode != 0:
        return None
    return completed.stdout.strip()


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_task(path):
    with path.open(encoding="utf-8") as handle:
        task = json.load(handle)
    required = {"id", "prompt", "revision", "oracles"}
    missing = sorted(required - task.keys())
    if missing:
        raise ValueError(f"{path}: missing required fields: {', '.join(missing)}")
    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]*", task["id"]):
        raise ValueError(f"{path}: id must contain only lowercase letters, digits, _ or -")
    if not isinstance(task["prompt"], str) or not task["prompt"].strip():
        raise ValueError(f"{path}: prompt must be a non-empty string")
    if not isinstance(task["oracles"], list) or not task["oracles"]:
        raise ValueError(f"{path}: at least one oracle is required")
    for oracle in task["oracles"]:
        if oracle.get("type") == "command":
            command = oracle.get("command")
            if not isinstance(command, list) or not all(
                isinstance(part, str) and part for part in command
            ):
                raise ValueError(f"{path}: command oracle requires a string argv array")
        elif oracle.get("type") != "human":
            raise ValueError(f"{path}: oracle type must be command or human")
    return task


def model_selector(model):
    return model if "/" in model else f"{MODEL_PROVIDER}/{model}"


def prepare_omp_environment(run_dir, run_id, model):
    source_dir = Path.home() / ".omp" / "agent"
    target_dir = run_dir / "omp-agent"
    target_dir.mkdir()
    config = (source_dir / "config.yml").read_text(encoding="utf-8")
    models = (source_dir / "models.yml").read_text(encoding="utf-8")
    selected = model_selector(model)
    for role in ("advisor", "commit", "default", "plan", "slow", "smol", "task", "tiny"):
        config = re.sub(
            rf"(?m)^(  {role}: ).*$", rf"\g<1>{selected}", config
        )
    marker = "      X-AI-Caller: omp\n"
    if marker not in models:
        raise RuntimeError("OMP model configuration has no attributed local provider")
    models = models.replace(
        marker, marker + f"      X-AI-Eval-Run: {run_id}\n", 1
    )
    (target_dir / "config.yml").write_text(config, encoding="utf-8")
    (target_dir / "models.yml").write_text(models, encoding="utf-8")
    environment = os.environ.copy()
    environment["PI_CODING_AGENT_DIR"] = str(target_dir)
    return environment


def prepare_opencode_environment(run_id):
    environment = os.environ.copy()
    try:
        overlay = json.loads(environment.get("OPENCODE_CONFIG_CONTENT", "{}"))
    except json.JSONDecodeError as error:
        raise RuntimeError("OPENCODE_CONFIG_CONTENT is not valid JSON") from error
    provider = overlay.setdefault("provider", {}).setdefault(MODEL_PROVIDER, {})
    options = provider.setdefault("options", {})
    headers = options.setdefault("headers", {})
    headers["X-AI-Eval-Run"] = run_id
    environment["OPENCODE_CONFIG_CONTENT"] = json.dumps(overlay, separators=(",", ":"))
    return environment


def harness_command(harness, model, prompt, worktree, timeout_seconds, auto_approve):
    selected = model_selector(model)
    if harness == "omp":
        command = [
            "omp",
            "-p",
            "--no-session",
            "--no-title",
            "--no-extensions",
            "--no-skills",
            "--no-rules",
            "--no-pty",
            "--max-time",
            str(timeout_seconds),
            "--cwd",
            str(worktree),
            "--model",
            selected,
            "--smol",
            selected,
            "--slow",
            selected,
            "--plan",
            selected,
        ]
        command += ["--approval-mode", "yolo" if auto_approve else "always-ask"]
        command.append(prompt)
        return command
    command = [
        "opencode",
        "run",
        "--pure",
        "--format",
        "json",
        "--dir",
        str(worktree),
        "--title",
        "evaluation",
        "--model",
        selected,
    ]
    if auto_approve:
        command.append("--auto")
    command.append(prompt)
    return command


def wait_for_log_flush(path, previous_size):
    if not path.exists():
        return
    stable = 0
    last_size = previous_size
    for _ in range(20):
        size = path.stat().st_size
        if size == last_size:
            stable += 1
            if stable >= 3:
                return
        else:
            stable = 0
            last_size = size
        time.sleep(0.1)


def read_run_records(path, offset, run_id, caller, model):
    if not path.exists():
        return []
    with path.open("rb") as handle:
        handle.seek(offset)
        lines = handle.read().splitlines()
    parsed = []
    for line in lines:
        try:
            record = json.loads(line)
        except (UnicodeDecodeError, json.JSONDecodeError):
            continue
        parsed.append(record)
    attributed = [record for record in parsed if record.get("eval_run") == run_id]
    if attributed:
        return attributed
    return [
        record
        for record in parsed
        if record.get("caller") == caller and record.get("model") == model
    ]


def summarize_records(records):
    totals = {
        "requests": len(records),
        "http_errors": 0,
        "incomplete_streams": 0,
        "missing_usage": 0,
        "prompt_tokens": 0,
        "completion_tokens": 0,
        "total_tokens": 0,
        "cached_prompt_tokens": 0,
        "latency_ms": 0.0,
        "ttft_ms": [],
    }
    for record in records:
        if isinstance(record.get("status"), int) and record["status"] >= 400:
            totals["http_errors"] += 1
        if record.get("stream_completed") is False:
            totals["incomplete_streams"] += 1
        usage = record.get("usage")
        if not isinstance(usage, dict):
            totals["missing_usage"] += 1
        else:
            prompt = usage.get("prompt_tokens", usage.get("input_tokens", 0)) or 0
            completion = usage.get(
                "completion_tokens", usage.get("output_tokens", 0)
            ) or 0
            totals["prompt_tokens"] += prompt
            totals["completion_tokens"] += completion
            totals["total_tokens"] += usage.get("total_tokens", prompt + completion) or 0
            details = usage.get("prompt_tokens_details") or {}
            totals["cached_prompt_tokens"] += details.get("cached_tokens", 0) or 0
        totals["latency_ms"] += record.get("latency_ms") or 0
        if record.get("ttft_ms") is not None:
            totals["ttft_ms"].append(record["ttft_ms"])
    totals["latency_ms"] = round(totals["latency_ms"], 3)
    totals["ttft_ms"] = (
        round(sum(totals["ttft_ms"]) / len(totals["ttft_ms"]), 3)
        if totals["ttft_ms"]
        else None
    )
    return totals


def run_oracles(task, worktree, run_dir):
    results = []
    for index, oracle in enumerate(task["oracles"], start=1):
        if oracle["type"] == "human":
            results.append(
                {
                    "type": "human",
                    "name": oracle.get("name", f"human-{index}"),
                    "status": "pending",
                    "rubric": oracle.get("rubric"),
                }
            )
            continue
        output_path = run_dir / f"oracle-{index}.log"
        started = time.monotonic()
        timed_out = False
        with output_path.open("w", encoding="utf-8") as output:
            try:
                completed = run_process(
                    oracle["command"],
                    cwd=worktree,
                    timeout=oracle.get("timeout_seconds", 1800),
                    stdout=output,
                    stderr=subprocess.STDOUT,
                )
                exit_code = completed.returncode
            except subprocess.TimeoutExpired:
                timed_out = True
                exit_code = None
        results.append(
            {
                "type": "command",
                "name": oracle.get("name", f"command-{index}"),
                "command": oracle["command"],
                "exit_code": exit_code,
                "timed_out": timed_out,
                "elapsed_seconds": round(time.monotonic() - started, 3),
                "status": "pass" if exit_code == 0 else "fail",
                "output": output_path.name,
            }
        )
    return results


def execute(task_path, harness, model, args, experiment_dir):
    task = load_task(task_path)
    timeout_seconds = task.get("timeout_seconds", args.timeout)
    run_id = f"{task['id']}-{harness}-{model.split('/')[-1]}-{uuid.uuid4().hex[:8]}"
    run_dir = experiment_dir / run_id
    run_dir.mkdir(parents=True)
    temp_parent = Path(tempfile.mkdtemp(prefix=f"ai-eval-{task['id']}-"))
    worktree = temp_parent / "worktree"
    log_path = Path(args.log)
    log_offset = log_path.stat().st_size if log_path.exists() else 0
    started_at = dt.datetime.now(dt.timezone.utc)
    worktree_added = False
    harness_exit = None
    timed_out = False
    oracle_results = []
    changed_files = []
    patch_file = run_dir / "changes.patch"
    try:
        added = run_process(
            ["git", "worktree", "add", "--detach", str(worktree), task["revision"]],
            cwd=REPO_ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if added.returncode != 0:
            raise RuntimeError(added.stderr.strip())
        worktree_added = True
        environment = (
            prepare_omp_environment(run_dir, run_id, model)
            if harness == "omp"
            else prepare_opencode_environment(run_id)
        )
        command = harness_command(
            harness,
            model,
            task["prompt"],
            worktree,
            timeout_seconds,
            args.auto_approve,
        )
        (run_dir / "command.json").write_text(
            json.dumps(command, indent=2) + "\n", encoding="utf-8"
        )
        harness_started = time.monotonic()
        with (run_dir / "harness.stdout.log").open("w", encoding="utf-8") as stdout, (
            run_dir / "harness.stderr.log"
        ).open("w", encoding="utf-8") as stderr:
            try:
                completed = run_process(
                    command,
                    cwd=worktree,
                    env=environment,
                    timeout=timeout_seconds + 30,
                    stdout=stdout,
                    stderr=stderr,
                )
                harness_exit = completed.returncode
            except subprocess.TimeoutExpired:
                timed_out = True
        harness_elapsed = round(time.monotonic() - harness_started, 3)
        oracle_results = run_oracles(task, worktree, run_dir)
        status = command_output(["git", "status", "--short"], cwd=worktree) or ""
        changed_files = status.splitlines()
        untracked = command_output(
            ["git", "ls-files", "--others", "--exclude-standard"], cwd=worktree
        )
        if untracked:
            run_process(
                ["git", "add", "--intent-to-add", "--", *untracked.splitlines()],
                cwd=worktree,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        with patch_file.open("w", encoding="utf-8") as patch:
            run_process(
                ["git", "diff", "--binary", "--no-ext-diff", "HEAD"],
                cwd=worktree,
                stdout=patch,
                stderr=subprocess.STDOUT,
            )
    finally:
        wait_for_log_flush(log_path, log_offset)
        records = read_run_records(
            log_path,
            log_offset,
            run_id,
            HARNESS_CALLERS[harness],
            model.split("/")[-1],
        )
        if worktree_added and not args.keep_worktree:
            run_process(
                ["git", "worktree", "remove", "--force", str(worktree)],
                cwd=REPO_ROOT,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        if not args.keep_worktree:
            shutil.rmtree(temp_parent, ignore_errors=True)
    command_oracles_pass = all(
        item["status"] == "pass"
        for item in oracle_results
        if item["type"] == "command"
    )
    human_pending = any(item["type"] == "human" for item in oracle_results)
    if harness_exit == 0 and not timed_out and command_oracles_pass:
        result_status = "needs_review" if human_pending else "pass"
    else:
        result_status = "fail"
    configs = {
        "omp_config_sha256": sha256(Path.home() / ".omp" / "agent" / "config.yml"),
        "omp_models_sha256": sha256(Path.home() / ".omp" / "agent" / "models.yml"),
        "opencode_config_sha256": sha256(
            Path.home() / ".config" / "opencode" / "opencode.json"
        ),
    }
    result = {
        "schema_version": 1,
        "run_id": run_id,
        "experiment": experiment_dir.name,
        "task": task["id"],
        "task_file": str(task_path),
        "source": task.get("source"),
        "revision": task["revision"],
        "harness": harness,
        "harness_version": command_output([harness, "--version"]),
        "model": model.split("/")[-1],
        "started_at": started_at.isoformat(),
        "elapsed_seconds": round(
            (dt.datetime.now(dt.timezone.utc) - started_at).total_seconds(), 3
        ),
        "harness_elapsed_seconds": harness_elapsed,
        "harness_exit_code": harness_exit,
        "timed_out": timed_out,
        "auto_approved": args.auto_approve,
        "status": result_status,
        "requests": summarize_records(records),
        "oracles": oracle_results,
        "changed_files": changed_files,
        "configuration": configs,
        "task_sha256": sha256(task_path),
        "evaluator_sha256": sha256(Path(__file__)),
        "artifacts": {
            "stdout": "harness.stdout.log",
            "stderr": "harness.stderr.log",
            "patch": patch_file.name,
            "worktree": str(worktree) if args.keep_worktree else None,
        },
        "manual_review": {
            "tool_retries": None,
            "operator_interventions": None,
            "surprising_actions": None,
        },
    }
    (run_dir / "result.json").write_text(
        json.dumps(result, indent=2) + "\n", encoding="utf-8"
    )
    print(
        f"{result_status:12} {task['id']:24} {harness:8} "
        f"{model.split('/')[-1]:22} {run_dir}"
    )
    return result


def common_options(parser):
    parser.add_argument("--log", default=str(DEFAULT_LOG))
    parser.add_argument("--timeout", type=int, default=1800)
    parser.add_argument(
        "--auto-approve",
        action="store_true",
        help="allow the harness to execute tools without prompts inside the disposable worktree",
    )
    parser.add_argument("--keep-worktree", action="store_true")
    parser.add_argument("--experiment")


def experiment_directory(name):
    if name is None:
        name = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", name):
        raise ValueError("experiment name contains unsupported characters")
    path = REPO_ROOT / "eval" / ".runs" / name
    path.mkdir(parents=True, exist_ok=True)
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="subcommand", required=True)
    run_parser = subparsers.add_parser("run", help="run one task/harness/model cell")
    run_parser.add_argument("task", type=Path)
    run_parser.add_argument("--harness", choices=sorted(HARNESS_CALLERS), required=True)
    run_parser.add_argument("--model", required=True)
    common_options(run_parser)
    matrix_parser = subparsers.add_parser("matrix", help="run a randomized paired matrix")
    matrix_parser.add_argument("tasks", nargs="+", type=Path)
    matrix_parser.add_argument(
        "--harness", action="append", choices=sorted(HARNESS_CALLERS), required=True
    )
    matrix_parser.add_argument("--model", action="append", required=True)
    matrix_parser.add_argument("--seed", type=int, required=True)
    matrix_parser.add_argument("--repeat", type=int, default=1)
    common_options(matrix_parser)
    report_parser = subparsers.add_parser(
        "report", help="render result.json artifacts as a Markdown table"
    )
    report_parser.add_argument("paths", nargs="+", type=Path)
    args = parser.parse_args()
    if args.subcommand == "report":
        result_paths = []
        for path in args.paths:
            if path.is_dir():
                result_paths.extend(path.rglob("result.json"))
            elif path.name == "result.json":
                result_paths.append(path)
        rows = []
        for path in sorted(set(result_paths)):
            with path.open(encoding="utf-8") as handle:
                result = json.load(handle)
            requests = result.get("requests", {})
            rows.append(
                [
                    result.get("task"),
                    result.get("harness"),
                    result.get("model"),
                    result.get("status"),
                    result.get("harness_elapsed_seconds"),
                    requests.get("requests"),
                    requests.get("total_tokens"),
                    requests.get("cached_prompt_tokens"),
                    requests.get("ttft_ms"),
                ]
            )
        headers = [
            "Task",
            "Harness",
            "Model",
            "Status",
            "Harness s",
            "Requests",
            "Tokens",
            "Cached",
            "Avg TTFT ms",
        ]
        print("| " + " | ".join(headers) + " |")
        print("|" + "|".join("---" for _ in headers) + "|")
        for row in rows:
            print("| " + " | ".join(str(value) for value in row) + " |")
        return 0
    experiment_dir = experiment_directory(args.experiment)
    if args.subcommand == "run":
        result = execute(args.task, args.harness, args.model, args, experiment_dir)
        return 0 if result["status"] != "fail" else 1
    cells = [
        (task, harness, model, repetition)
        for task in args.tasks
        for harness in args.harness
        for model in args.model
        for repetition in range(args.repeat)
    ]
    random.Random(args.seed).shuffle(cells)
    manifest = {
        "schema_version": 1,
        "seed": args.seed,
        "repeat": args.repeat,
        "order": [
            {
                "task": str(task),
                "harness": harness,
                "model": model,
                "repetition": repetition,
            }
            for task, harness, model, repetition in cells
        ],
    }
    (experiment_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    results = [
        execute(task, harness, model, args, experiment_dir)
        for task, harness, model, _repetition in cells
    ]
    summary = {
        "pass": sum(result["status"] == "pass" for result in results),
        "needs_review": sum(result["status"] == "needs_review" for result in results),
        "fail": sum(result["status"] == "fail" for result in results),
        "runs": [result["run_id"] for result in results],
    }
    (experiment_dir / "summary.json").write_text(
        json.dumps(summary, indent=2) + "\n", encoding="utf-8"
    )
    return 1 if summary["fail"] else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        sys.exit(2)
