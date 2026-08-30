"""Aggregate local AI JSONL logs without exposing request or response payloads."""

import argparse
import datetime as dt
import glob
import gzip
import json
import os
import re
import sys

UTC = dt.timezone.utc


def parse_since(value):
    if value == "all":
        return None
    match = re.fullmatch(r"(\d+)([mhdw])", value)
    if match:
        amount = int(match.group(1))
        seconds = amount * {"m": 60, "h": 3600, "d": 86400, "w": 604800}[match.group(2)]
        return dt.datetime.now(UTC) - dt.timedelta(seconds=seconds)
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise argparse.ArgumentTypeError(
            "expected 'all', a duration such as 7d, or an ISO-8601 timestamp"
        ) from error
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def parse_timestamp(value):
    if not isinstance(value, str):
        return None
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def log_paths(base_path):
    paths = [path for path in glob.glob(f"{base_path}.*") if os.path.isfile(path)]
    if os.path.isfile(base_path):
        paths.append(base_path)
    return sorted(set(paths))


def number(value):
    return (
        value
        if isinstance(value, (int, float)) and not isinstance(value, bool)
        else None
    )


def stream_is_incomplete(record):
    content_type = str(record.get("response_content_type") or "").lower()
    if not content_type.startswith("text/event-stream"):
        return False
    completed = record.get("stream_completed")
    if isinstance(completed, bool):
        return not completed
    response = record.get("response")
    return not (
        isinstance(response, str) and response.rstrip().endswith("data: [DONE]")
    )


def new_group(caller, model):
    return {
        "caller": caller,
        "model": model,
        "requests": 0,
        "http_errors": 0,
        "incomplete_streams": 0,
        "client_disconnects": 0,
        "usage_records": 0,
        "missing_usage": 0,
        "prompt_tokens": 0,
        "completion_tokens": 0,
        "total_tokens": 0,
        "actual_cost_usd": 0.0,
        "estimated_cost_usd": 0.0,
        "latency_sum_ms": 0.0,
        "latency_records": 0,
        "ttft_sum_ms": 0.0,
        "ttft_records": 0,
        "first_request": None,
        "last_request": None,
    }


def record_cost(record, usage):
    """Provider-billed and list-price-estimated spend, kept apart on purpose."""
    cost = record.get("cost")
    if isinstance(cost, dict):
        return number(cost.get("actual_usd")), number(cost.get("estimated_usd"))
    # Records predating cost accounting only ever carried provider billing.
    if isinstance(usage, dict):
        actual = number(usage.get("cost"))
        if actual is None:
            actual = number(usage.get("total_cost"))
        return actual, None
    return None, None


def add_record(group, record, timestamp):
    group["requests"] += 1
    status = number(record.get("status"))
    if status is not None and status >= 400:
        group["http_errors"] += 1
    if stream_is_incomplete(record):
        group["incomplete_streams"] += 1
    if record.get("client_disconnected") is True:
        group["client_disconnects"] += 1

    usage = record.get("usage")
    prompt = completion = total = None
    if isinstance(usage, dict):
        prompt = number(usage.get("prompt_tokens"))
        if prompt is None:
            prompt = number(usage.get("input_tokens"))
        completion = number(usage.get("completion_tokens"))
        if completion is None:
            completion = number(usage.get("output_tokens"))
        total = number(usage.get("total_tokens"))
        if total is None and (prompt is not None or completion is not None):
            total = (prompt or 0) + (completion or 0)
    if prompt is None and completion is None and total is None:
        group["missing_usage"] += 1
    else:
        group["usage_records"] += 1
        group["prompt_tokens"] += int(prompt or 0)
        group["completion_tokens"] += int(completion or 0)
        group["total_tokens"] += int(total or 0)

    actual, estimated = record_cost(record, usage)
    group["actual_cost_usd"] += actual or 0.0
    group["estimated_cost_usd"] += estimated or 0.0

    latency = number(record.get("latency_ms"))
    if latency is not None:
        group["latency_sum_ms"] += latency
        group["latency_records"] += 1
    ttft = number(record.get("ttft_ms"))
    if ttft is not None:
        group["ttft_sum_ms"] += ttft
        group["ttft_records"] += 1

    timestamp_text = timestamp.isoformat() if timestamp else None
    if timestamp_text is not None:
        if group["first_request"] is None or timestamp_text < group["first_request"]:
            group["first_request"] = timestamp_text
        if group["last_request"] is None or timestamp_text > group["last_request"]:
            group["last_request"] = timestamp_text


def finish_group(group):
    result = dict(group)
    latency_count = result.pop("latency_records")
    latency_sum = result.pop("latency_sum_ms")
    ttft_count = result.pop("ttft_records")
    ttft_sum = result.pop("ttft_sum_ms")
    result["avg_latency_ms"] = (
        round(latency_sum / latency_count, 3) if latency_count else None
    )
    result["avg_ttft_ms"] = round(ttft_sum / ttft_count, 3) if ttft_count else None
    # Summing many six-decimal prices accumulates float noise worth trimming.
    result["actual_cost_usd"] = round(result["actual_cost_usd"], 6)
    result["estimated_cost_usd"] = round(result["estimated_cost_usd"], 6)
    return result


def print_table(groups):
    columns = [
        ("caller", "CALLER"),
        ("model", "MODEL"),
        ("requests", "REQ"),
        ("http_errors", "ERR"),
        ("incomplete_streams", "INCOMP"),
        ("missing_usage", "NO_USAGE"),
        ("prompt_tokens", "PROMPT"),
        ("completion_tokens", "OUTPUT"),
        ("total_tokens", "TOTAL"),
        ("actual_cost_usd", "USD_ACTUAL"),
        ("estimated_cost_usd", "USD_EST"),
        ("avg_latency_ms", "AVG_LAT_MS"),
        ("avg_ttft_ms", "AVG_TTFT_MS"),
    ]
    rows = [
        [str(group[key] if group[key] is not None else "-") for key, _ in columns]
        for group in groups
    ]
    widths = [len(label) for _, label in columns]
    for row in rows:
        widths = [max(width, len(value)) for width, value in zip(widths, row)]
    print("  ".join(label.ljust(width) for (_, label), width in zip(columns, widths)))
    for row in rows:
        print("  ".join(value.ljust(width) for value, width in zip(row, widths)))
    actual = sum(group["actual_cost_usd"] for group in groups)
    estimated = sum(group["estimated_cost_usd"] for group in groups)
    print(f"totals: billed ${actual:.6f} USD, estimated ${estimated:.6f} USD")


def main():
    parser = argparse.ArgumentParser(
        description="Summarize local AI usage without printing logged payloads."
    )
    parser.add_argument(
        "--log",
        default=os.environ.get(
            "LLAMA_REQUEST_LOG", "/var/lib/llama/logs/requests.jsonl"
        ),
        help="base JSONL path; rotated .N and .N.gz files are included",
    )
    parser.add_argument(
        "--since",
        default="7d",
        help="window start: all, a duration such as 7d, or an ISO-8601 timestamp",
    )
    parser.add_argument(
        "--caller", action="append", help="caller to include; repeatable"
    )
    parser.add_argument(
        "--json", action="store_true", help="emit machine-readable JSON"
    )
    args = parser.parse_args()

    try:
        since = parse_since(args.since)
    except argparse.ArgumentTypeError as error:
        parser.error(str(error))

    paths = log_paths(args.log)
    if not paths:
        parser.error(f"no log files found for {args.log}")

    grouped = {}
    corrupt_lines = 0
    for path in paths:
        opener = gzip.open if path.endswith(".gz") else open
        try:
            with opener(path, "rt", encoding="utf-8") as handle:
                for line in handle:
                    try:
                        record = json.loads(line)
                    except (json.JSONDecodeError, UnicodeDecodeError):
                        corrupt_lines += 1
                        continue
                    timestamp = parse_timestamp(record.get("timestamp"))
                    if since is not None and (timestamp is None or timestamp < since):
                        continue
                    caller = str(record.get("caller") or "unattributed")
                    if args.caller and caller not in args.caller:
                        continue
                    model = str(record.get("model") or "-")
                    key = (caller, model)
                    if key not in grouped:
                        grouped[key] = new_group(caller, model)
                    add_record(grouped[key], record, timestamp)
        except OSError as error:
            print(f"warning: cannot read {path}: {error}", file=sys.stderr)

    groups = [finish_group(grouped[key]) for key in sorted(grouped)]
    report = {
        "generated_at": dt.datetime.now(UTC).isoformat(),
        "since": since.isoformat() if since else None,
        "log_files": paths,
        "corrupt_lines": corrupt_lines,
        "totals": {
            "actual_cost_usd": round(
                sum(group["actual_cost_usd"] for group in groups), 6
            ),
            "estimated_cost_usd": round(
                sum(group["estimated_cost_usd"] for group in groups), 6
            ),
        },
        "groups": groups,
    }
    if args.json:
        json.dump(report, sys.stdout, indent=2)
        print()
    elif groups:
        print_table(groups)
        if corrupt_lines:
            print(
                f"warning: skipped {corrupt_lines} corrupt log line(s)", file=sys.stderr
            )
    else:
        print("No matching requests.")


if __name__ == "__main__":
    main()
