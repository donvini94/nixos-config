#!/usr/bin/env python3
"""List request-log candidates and export one prompt into an ignored draft task."""

import argparse
import gzip
import json
import os
import subprocess
import sys
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
DRAFT_ROOT = (REPO_ROOT / "eval" / "drafts").resolve()


def log_paths(base):
    paths = sorted(base.parent.glob(f"{base.name}.*"))
    if base.exists():
        paths.append(base)
    return [path for path in paths if path.is_file()]


def records(base):
    for path in log_paths(base):
        opener = gzip.open if path.suffix == ".gz" else open
        with opener(path, "rt", encoding="utf-8") as handle:
            for line in handle:
                try:
                    yield json.loads(line)
                except json.JSONDecodeError:
                    continue


def usage_total(record):
    usage = record.get("usage")
    return usage.get("total_tokens") if isinstance(usage, dict) else None


def user_prompt(record):
    request = record.get("request")
    messages = request.get("messages") if isinstance(request, dict) else None
    if not isinstance(messages, list):
        return None
    for message in reversed(messages):
        if not isinstance(message, dict) or message.get("role") != "user":
            continue
        content = message.get("content")
        if isinstance(content, str):
            return content
        if isinstance(content, list):
            text = [
                block.get("text", "")
                for block in content
                if isinstance(block, dict) and block.get("type") == "text"
            ]
            return "\n".join(part for part in text if part)
    return None


def filtered(args):
    selected = []
    for record in records(Path(args.log)):
        if args.caller and record.get("caller") not in args.caller:
            continue
        if args.model and record.get("model") not in args.model:
            continue
        selected.append(record)
    return selected


def list_candidates(args):
    selected = filtered(args)[-args.limit :]
    for record in selected:
        print(
            "\t".join(
                [
                    str(record.get("timestamp") or "-"),
                    str(record.get("caller") or "-"),
                    str(record.get("model") or "-"),
                    str(usage_total(record) or "-"),
                    str(record.get("status") or "-"),
                ]
            )
        )


def extract(args):
    matches = [
        record for record in filtered(args) if record.get("timestamp") == args.timestamp
    ]
    if len(matches) != 1:
        raise ValueError(f"timestamp matched {len(matches)} records; expected exactly one")
    prompt = user_prompt(matches[0])
    if not prompt:
        raise ValueError("selected record has no extractable user prompt")
    output = (DRAFT_ROOT / args.output).resolve()
    if DRAFT_ROOT not in output.parents:
        raise ValueError("draft output must remain below eval/drafts")
    output.parent.mkdir(parents=True, exist_ok=True)
    draft = {
        "$schema": "../task.schema.json",
        "id": args.id,
        "description": "DRAFT: inspect for secrets, reconstruct the true starting revision, and add deterministic oracles before moving to eval/tasks.",
        "prompt": prompt,
        "revision": args.revision,
        "tags": ["harvested", "uncurated"],
        "source": {
            "log_timestamp": matches[0]["timestamp"],
            "caller": matches[0].get("caller"),
            "model": matches[0].get("model"),
            "notes": "Raw responses were deliberately not copied. Verify that the supplied revision recreates the original starting state."
        },
        "oracles": [
            {
                "type": "human",
                "name": "curation-required",
                "rubric": "Replace this placeholder with task-specific command or human oracles."
            }
        ]
    }
    output.write_text(json.dumps(draft, indent=2) + "\n", encoding="utf-8")
    os.chmod(output, 0o600)
    print(output)


def current_revision():
    completed = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=REPO_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    return completed.stdout.strip() if completed.returncode == 0 else "UNKNOWN"


def add_filters(parser):
    parser.add_argument("--log", default=str(DEFAULT_LOG))
    parser.add_argument("--caller", action="append")
    parser.add_argument("--model", action="append")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="subcommand", required=True)
    list_parser = subparsers.add_parser("list")
    add_filters(list_parser)
    list_parser.add_argument("--limit", type=int, default=20)
    extract_parser = subparsers.add_parser("extract")
    add_filters(extract_parser)
    extract_parser.add_argument("--timestamp", required=True)
    extract_parser.add_argument("--id", required=True)
    extract_parser.add_argument("--output", required=True)
    extract_parser.add_argument(
        "--revision",
        default=current_revision(),
        help="candidate starting revision; it must be verified during curation",
    )
    args = parser.parse_args()
    if args.subcommand == "list":
        list_candidates(args)
    else:
        extract(args)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        sys.exit(2)
