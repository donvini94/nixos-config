#!/usr/bin/env python3
"""Reconcile Paperless from public taxonomy and a SOPS-decrypted private overlay.

Upsert by name; never delete unmanaged objects or change unspecified fields.
Write-only passwords are updated on create or with --sync-passwords. Nested
workflow/view sets must be sent complete because PATCH replaces them wholesale.

Exit codes: 0 converged, 1 dry-run found changes, errors exit nonzero.
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

try:
    import yaml
except ImportError:  # pragma: no cover - packaging error, not a runtime path
    sys.exit("provision.py requires PyYAML")

API_VERSION = "10"
DEFAULT_BASE_URL = "http://127.0.0.1:58080"
DEFAULT_USERNAME = "admin"

# Marker for a credential the operator has not filled in yet.
PLACEHOLDER = "REPLACE_ME"

# --------------------------------------------------------------------------
# Symbolic enum names -> the integer codes the API actually wants.
# Paperless encodes every enum as a bare integer. Writing those into a config
# file by hand is unreadable and fails silently if upstream ever renumbers, so
# the config speaks names and this table is the single place that knows codes.
# --------------------------------------------------------------------------

MATCHING_ALGORITHMS = {
    "none": 0,
    "any": 1,
    "all": 2,
    "literal": 3,
    "regex": 4,
    "fuzzy": 5,
    "auto": 6,
}

IMAP_SECURITY = {"none": 1, "ssl": 2, "starttls": 3}

MAIL_ACCOUNT_TYPES = {"imap": 1, "gmail_oauth": 2, "outlook_oauth": 3}

MAIL_ACTIONS = {"delete": 1, "move": 2, "mark_read": 3, "flag": 4, "tag": 5}

MAIL_TITLE_FROM = {"subject": 1, "filename": 2, "none": 3}

MAIL_CORRESPONDENT_FROM = {"nothing": 1, "from_email": 2, "from_name": 3, "custom": 4}

MAIL_ATTACHMENT_TYPE = {"attachments_only": 1, "everything": 2}

MAIL_CONSUMPTION_SCOPE = {"attachments_only": 1, "eml_only": 2, "everything": 3}

WORKFLOW_TRIGGER_TYPES = {
    "consumption_started": 1,
    "document_added": 2,
    "document_updated": 3,
    "scheduled": 4,
}

WORKFLOW_SOURCES = {
    "consume_folder": 1,
    "api_upload": 2,
    "mail_fetch": 3,
    "web_ui": 4,
}

WORKFLOW_ACTION_TYPES = {
    "assignment": 1,
    "removal": 2,
    "email": 3,
    "webhook": 4,
    "password_removal": 5,
    "trash": 6,
}

# Saved-view filter rule types (src/documents/models.py, SavedView RULE_TYPES).
# Only the useful subset is exposed; add more as needed.
FILTER_RULES = {
    "title_contains": 0,
    "content_contains": 1,
    "correspondent_is": 3,
    "document_type_is": 4,
    "is_in_inbox": 5,
    "has_tag": 6,
    "has_any_tag": 7,
    "created_before": 8,
    "created_after": 9,
    "created_year_is": 10,
    "added_before": 13,
    "added_after": 14,
    "does_not_have_tag": 17,
    "title_or_content_contains": 19,
    "fulltext_query": 20,
    "has_tags_in": 22,
    "storage_path_is": 25,
    "created_to": 43,
    "created_from": 44,
    "added_to": 45,
    "added_from": 46,
}

# Rules whose value is a reference to another object rather than a literal.
FILTER_RULE_REFERENCES = {
    "correspondent_is": "correspondents",
    "document_type_is": "document_types",
    "storage_path_is": "storage_paths",
    "has_tag": "tags",
    "does_not_have_tag": "tags",
    "has_tags_in": "tags",
    "has_any_tag": "tags",
}


class ProvisionError(Exception):
    pass


def enum(table: dict[str, int], value, field: str) -> int:
    """Resolve a symbolic enum name, failing loudly on a typo.

    Integers pass through so an escape hatch exists for codes this table does
    not know about yet.
    """
    if isinstance(value, int):
        return value
    try:
        return table[str(value)]
    except KeyError:
        raise ProvisionError(
            f"unknown {field} {value!r}; expected one of {sorted(table)}",
        ) from None


# --------------------------------------------------------------------------
# API client
# --------------------------------------------------------------------------


class Paperless:
    def __init__(self, base_url: str, token: str, *, timeout: int = 30):
        self.base_url = base_url.rstrip("/")
        self.token = token
        self.timeout = timeout

    @classmethod
    def authenticate(
        cls,
        base_url: str,
        username: str,
        password: str,
        *,
        timeout: int = 30,
    ) -> Paperless:
        """Trade the admin password for an API token.

        Deliberately not a long-lived token in the Nix store: the admin
        password already exists as a sops secret, and DRF's ObtainAuthToken
        returns the same token on every call, so this is cheap.
        """
        body = json.dumps({"username": username, "password": password}).encode()
        request = urllib.request.Request(
            f"{base_url.rstrip('/')}/api/token/",
            data=body,
            method="POST",
            headers={"Content-Type": "application/json", "Accept": "application/json"},
        )
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                payload = json.loads(response.read())
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode(errors="replace")[:400]
            raise ProvisionError(
                f"authentication failed ({exc.code}): {detail}",
            ) from None
        except urllib.error.URLError as exc:
            raise ProvisionError(f"cannot reach {base_url}: {exc.reason}") from None
        return cls(base_url, payload["token"], timeout=timeout)

    def _request(self, method: str, path: str, payload=None):
        url = path if path.startswith("http") else f"{self.base_url}{path}"
        data = json.dumps(payload).encode() if payload is not None else None
        request = urllib.request.Request(
            url,
            data=data,
            method=method,
            headers={
                "Authorization": f"Token {self.token}",
                "Accept": f"application/json; version={API_VERSION}",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                raw = response.read()
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode(errors="replace")[:800]
            raise ProvisionError(f"{method} {url} -> {exc.code}: {detail}") from None
        except urllib.error.URLError as exc:
            raise ProvisionError(f"{method} {url} failed: {exc.reason}") from None

    def list_all(self, kind: str) -> list[dict]:
        """Fetch every object of a kind, following pagination.

        Fetching the whole collection and indexing locally beats per-object
        `?name__iexact=` probes: it is one round trip per kind, and it does not
        depend on which endpoints happen to expose the name filter.
        """
        results: list[dict] = []
        url = f"{self.base_url}/api/{kind}/?page_size=250"
        while url:
            page = self._request("GET", url)
            results.extend(page.get("results", []))
            url = page.get("next")
        return results

    def create(self, kind: str, payload: dict) -> dict:
        return self._request("POST", f"/api/{kind}/", payload)

    def update(self, kind: str, obj_id: int, payload: dict) -> dict:
        return self._request("PATCH", f"/api/{kind}/{obj_id}/", payload)


def wait_for_service(base_url: str, attempts: int = 90, delay: float = 2.0) -> None:
    """Block until the app actually serves.

    systemd considering paperless-web *started* is not the same as it accepting
    connections: the scheduler runs database migrations in its ExecStartPre, and
    on a rebuild all the paperless units are started in the same transaction. So
    this must run before authenticating, not after -- otherwise the very first
    request loses the race with a connection refused.
    """
    last = "no attempt made"
    for _ in range(attempts):
        try:
            urllib.request.urlopen(f"{base_url.rstrip('/')}/api/", timeout=5)
            return
        except urllib.error.HTTPError:
            return  # 401/403 still proves the app is up and routing
        except urllib.error.URLError as exc:
            last = str(exc.reason)
            time.sleep(delay)
    raise ProvisionError(
        f"paperless did not start serving at {base_url} after "
        f"{int(attempts * delay)}s: {last}",
    )


# --------------------------------------------------------------------------
# Comparison helpers
# --------------------------------------------------------------------------


def normalise(value):
    if isinstance(value, list):
        return sorted(normalise(item) for item in value)
    if isinstance(value, dict):
        return json.dumps({k: normalise(v) for k, v in sorted(value.items())})
    if isinstance(value, str):
        return value
    return value


def values_equal(current, desired) -> bool:
    if isinstance(desired, list) or isinstance(current, list):
        return normalise(current or []) == normalise(desired or [])
    if isinstance(desired, dict) and isinstance(current, dict):
        # Compare only the keys we manage; Paperless adds its own (e.g. the
        # auto-generated ids inside select_options).
        return all(values_equal(current.get(k), v) for k, v in desired.items())
    if isinstance(desired, str) and isinstance(current, str):
        return current == desired
    if current is None and desired == "":
        return True
    return current == desired


class Reconciler:
    """Tracks planned changes so --dry-run and apply share one code path."""

    def __init__(self, client: Paperless, *, dry_run: bool):
        self.client = client
        self.dry_run = dry_run
        self.changes: list[str] = []
        self.unmanaged: list[str] = []
        self._cache: dict[str, dict[str, dict]] = {}
        # Dry-run needs ids for objects it only *plans* to create, otherwise
        # resolving a reference to one ("mail rule X assigns tag Y") would fail
        # on an empty instance -- which is exactly when a dry run is most
        # useful. Negative so a placeholder can never be mistaken for real.
        self._placeholder_id = 0

    def index(self, kind: str) -> dict[str, dict]:
        """Name -> object, keyed case-insensitively.

        Paperless' own API exposes `?name__iexact=`, and the DB constraint is a
        plain unique index, so `leonardo` and `Leonardo` are two separate rows.
        Folding case here means the config adopts a tag you already created by
        hand -- keeping every document already filed under it -- instead of
        silently creating a near-duplicate beside it.
        """
        if kind not in self._cache:
            self._cache[kind] = {
                obj["name"].casefold(): obj
                for obj in self.client.list_all(kind)
                if "name" in obj
            }
        return self._cache[kind]

    def find(self, kind: str, name: str) -> dict | None:
        """Look up by name. Always go through this, never index()[name] --
        the index is casefolded and a raw lookup silently misses, which
        creates duplicates instead of updating."""
        return self.index(kind).get(name.casefold())

    def remember(self, kind: str, name: str, obj: dict) -> None:
        self.index(kind)[name.casefold()] = obj

    def resolve(self, kind: str, name: str) -> int:
        obj = self.find(kind, name)
        if obj is None:
            raise ProvisionError(
                f"{kind[:-1]} {name!r} is referenced but not defined in the config",
            )
        return obj["id"]

    def resolve_many(self, kind: str, names) -> list[int]:
        return [self.resolve(kind, n) for n in (names or [])]

    def upsert(
        self,
        kind: str,
        name: str,
        desired: dict,
        *,
        create_only: dict | None = None,
    ) -> int | None:
        """Create or patch one object. Returns its id, or None in dry-run."""
        index = self.index(kind)
        key = name.casefold()
        existing = index.get(key)
        create_only = create_only or {}

        if existing is None:
            payload = {"name": name, **desired, **create_only}
            self.changes.append(f"create {kind[:-1]} {name!r}")
            if self.dry_run:
                self._placeholder_id -= 1
                index[key] = {"id": self._placeholder_id, "name": name, **desired}
                return self._placeholder_id
            created = self.client.create(kind, payload)
            index[key] = created
            return created["id"]

        # Adopting a hand-made object whose casing differs: normalise it rather
        # than leave two spellings of the same concept in the UI.
        if existing.get("name") != name:
            desired = {"name": name, **desired}

        diff = {
            key_: value
            for key_, value in desired.items()
            if not values_equal(existing.get(key_), value)
        }
        if diff:
            fields = ", ".join(sorted(diff))
            self.changes.append(f"update {kind[:-1]} {existing['name']!r} ({fields})")
            if not self.dry_run:
                index[key] = self.client.update(kind, existing["id"], diff)
        return existing["id"]

    def report_unmanaged(self, kind: str, managed: set[str]) -> None:
        folded = {name.casefold() for name in managed}
        for key, obj in sorted(self.index(kind).items()):
            if key not in folded:
                self.unmanaged.append(f"{kind[:-1]} {obj['name']!r}")


# --------------------------------------------------------------------------
# Config loading
# --------------------------------------------------------------------------


def load_yaml(path: str) -> dict:
    try:
        with open(path, encoding="utf-8") as handle:
            return yaml.safe_load(handle) or {}
    except FileNotFoundError:
        raise ProvisionError(f"config file not found: {path}") from None
    except yaml.YAMLError as exc:
        raise ProvisionError(f"cannot parse {path}: {exc}") from None


def matching_fields(spec: dict) -> dict:
    """The four fields every MatchingModel shares."""
    algorithm = enum(
        MATCHING_ALGORITHMS,
        spec.get("matching_algorithm", "none"),
        "matching_algorithm",
    )
    return {
        "matching_algorithm": algorithm,
        "match": spec.get("match", "") or "",
        "is_insensitive": bool(spec.get("is_insensitive", True)),
    }


# --------------------------------------------------------------------------
# Collection reconcilers
# --------------------------------------------------------------------------


def sort_tags_by_depth(tags: list[dict]) -> list[dict]:
    """Parents before children, so a parent id always exists when referenced."""
    by_name = {tag["name"]: tag for tag in tags}

    def depth(tag: dict, seen: frozenset = frozenset()) -> int:
        parent = tag.get("parent")
        if not parent:
            return 0
        if parent in seen:
            raise ProvisionError(f"tag parent cycle involving {tag['name']!r}")
        if parent not in by_name:
            raise ProvisionError(
                f"tag {tag['name']!r} has parent {parent!r} which is not defined",
            )
        return 1 + depth(by_name[parent], seen | {tag["name"]})

    return sorted(tags, key=lambda tag: (depth(tag), tag["name"]))


def reconcile_tags(rec: Reconciler, tags: list[dict], overrides: dict) -> None:
    for spec in sort_tags_by_depth(tags):
        name = spec["name"]
        spec = {**spec, **overrides.get(name, {})}
        desired = {
            "color": str(spec.get("color", "#a6cee3")).lower(),
            "is_inbox_tag": bool(spec.get("is_inbox_tag", False)),
            **matching_fields(spec),
        }
        if spec.get("parent"):
            desired["parent"] = rec.resolve("tags", spec["parent"])
        rec.upsert("tags", name, desired)
    rec.report_unmanaged("tags", {tag["name"] for tag in tags})


def reconcile_simple(rec: Reconciler, kind: str, specs: list[dict]) -> None:
    for spec in specs:
        rec.upsert(kind, spec["name"], matching_fields(spec))
    rec.report_unmanaged(kind, {spec["name"] for spec in specs})


def reconcile_storage_paths(rec: Reconciler, specs: list[dict]) -> None:
    for spec in specs:
        rec.upsert(
            "storage_paths",
            spec["name"],
            {"path": spec["path"], **matching_fields(spec)},
        )
    rec.report_unmanaged("storage_paths", {spec["name"] for spec in specs})


def reconcile_custom_fields(rec: Reconciler, specs: list[dict]) -> None:
    for spec in specs:
        desired = {"data_type": spec["data_type"]}
        if spec.get("extra_data"):
            desired["extra_data"] = spec["extra_data"]
        # data_type is immutable once documents reference the field, so treat a
        # type change as an error rather than silently PATCHing it.
        existing = rec.index("custom_fields").get(spec["name"])
        if existing and existing.get("data_type") != spec["data_type"]:
            raise ProvisionError(
                f"custom field {spec['name']!r} already exists as "
                f"{existing['data_type']!r}; refusing to change it to "
                f"{spec['data_type']!r}. Rename the field instead.",
            )
        rec.upsert("custom_fields", spec["name"], desired)
    rec.report_unmanaged("custom_fields", {spec["name"] for spec in specs})


def reconcile_correspondents(rec: Reconciler, specs: list[dict]) -> None:
    for spec in specs:
        rec.upsert("correspondents", spec["name"], matching_fields(spec))
    # Correspondents are routinely created by hand, so do not report extras.


def reconcile_mail_accounts(
    rec: Reconciler,
    specs: list[dict],
    *,
    sync_passwords: bool,
) -> dict[str, int]:
    """Returns a map of symbolic account id -> Paperless account id."""
    mapping: dict[str, int] = {}
    for spec in specs:
        name = spec.get("name") or spec["id"]
        # Same idiom as modules/remote-openai.nix: an untouched placeholder is
        # skipped rather than pushed. This lets the encrypted file ship with all
        # three mailboxes pre-written so only the credentials need editing, and
        # lets you enable them one at a time without IMAP errors from the rest.
        unfilled = [
            field
            for field in ("username", "password")
            if PLACEHOLDER in str(spec.get(field, ""))
        ]
        if unfilled:
            print(
                f"  skipping mail account {name!r}: "
                f"{' and '.join(unfilled)} still {PLACEHOLDER}",
            )
            continue
        desired = {
            "imap_server": spec["imap_server"],
            "imap_port": int(spec.get("imap_port", 993)),
            "imap_security": enum(
                IMAP_SECURITY,
                spec.get("imap_security", "ssl"),
                "imap_security",
            ),
            "username": spec["username"],
            "character_set": spec.get("character_set", "UTF-8"),
            "account_type": enum(
                MAIL_ACCOUNT_TYPES,
                spec.get("account_type", "imap"),
                "account_type",
            ),
        }
        # A GET returns the password as asterisks, so it can never be diffed.
        # Send it on create; afterwards only when explicitly asked, otherwise
        # every single run would claim a change and --dry-run would be useless.
        if sync_passwords:
            desired["password"] = spec["password"]
        obj_id = rec.upsert(
            "mail_accounts",
            name,
            desired,
            create_only={"password": spec["password"]},
        )
        if obj_id is not None:
            mapping[spec["id"]] = obj_id
    return mapping


def reconcile_mail_rules(
    rec: Reconciler,
    specs: list[dict],
    accounts: dict[str, int],
    taxonomy: dict,
) -> list[str]:
    """Returns the names of rules that were actually configured."""
    configured: list[str] = []
    for spec in specs:
        account_key = spec["account"]
        if account_key not in accounts:
            print(
                f"  skipping mail rule {spec['name']!r}: "
                f"no mail account {account_key!r} in the private config",
            )
            continue
        desired = {
            "account": accounts[account_key],
            "order": int(spec.get("order", 0)),
            "enabled": bool(spec.get("enabled", True)),
            "folder": spec.get("folder", "INBOX"),
            "maximum_age": int(spec.get("maximum_age", 0)),
            "attachment_type": enum(
                MAIL_ATTACHMENT_TYPE,
                spec.get("attachment_type", "attachments_only"),
                "attachment_type",
            ),
            "consumption_scope": enum(
                MAIL_CONSUMPTION_SCOPE,
                spec.get("consumption_scope", "attachments_only"),
                "consumption_scope",
            ),
            "action": enum(MAIL_ACTIONS, spec.get("action", "mark_read"), "action"),
            "action_parameter": spec.get("action_parameter"),
            "assign_title_from": enum(
                MAIL_TITLE_FROM,
                spec.get("assign_title_from", "subject"),
                "assign_title_from",
            ),
            "assign_correspondent_from": enum(
                MAIL_CORRESPONDENT_FROM,
                spec.get("assign_correspondent_from", "nothing"),
                "assign_correspondent_from",
            ),
            "assign_tags": rec.resolve_many("tags", spec.get("assign_tags")),
            "stop_processing": bool(spec.get("stop_processing", False)),
        }
        # Single source of truth: a mail rule can point at a filename_rules
        # entry instead of repeating its globs. What we refuse to import and
        # what we tag as junk must never drift apart.
        if spec.get("exclude_filename_rule"):
            wanted = spec["exclude_filename_rule"]
            rule_entry = next(
                (r for r in taxonomy.get("filename_rules", []) if r["tag"] == wanted),
                None,
            )
            patterns = rule_entry["patterns"] if rule_entry else None
            if patterns is None:
                raise ProvisionError(
                    f"mail rule {spec['name']!r} references filename_rules "
                    f"entry {wanted!r}, which does not exist",
                )
            joined = ",".join(rule_entry.get("ingest_patterns") or patterns)
            # Paperless caps this column at 256 characters and rejects the
            # whole PATCH with a 400 if it is longer, so fail here with a
            # message that says which rule and by how much.
            if len(joined) > 256:
                raise ProvisionError(
                    f"mail rule {spec['name']!r}: the ingest exclude list for "
                    f"{wanted!r} is {len(joined)} characters, over Paperless' "
                    "256 limit. Trim `ingest_patterns` in taxonomy.yaml — the "
                    "full `patterns` list still applies after import.",
                )
            desired["filter_attachment_filename_exclude"] = joined

        for optional in (
            "filter_from",
            "filter_to",
            "filter_subject",
            "filter_body",
            "filter_attachment_filename_include",
            "filter_attachment_filename_exclude",
        ):
            if spec.get(optional) is not None:
                desired[optional] = spec[optional]
        if spec.get("assign_document_type"):
            desired["assign_document_type"] = rec.resolve(
                "document_types",
                spec["assign_document_type"],
            )
        rec.upsert("mail_rules", spec["name"], desired)
        configured.append(spec["name"])
    return configured


def build_trigger(rec: Reconciler, spec: dict, workflow: str) -> dict:
    trigger = {
        "type": enum(WORKFLOW_TRIGGER_TYPES, spec["type"], "trigger type"),
        "sources": [
            enum(WORKFLOW_SOURCES, source, "source") for source in spec.get("sources", [])
        ],
        "filter_path": spec.get("filter_path"),
        "filter_filename": spec.get("filter_filename"),
        **matching_fields(spec),
    }
    if spec.get("filter_mailrule"):
        trigger["filter_mailrule"] = rec.resolve("mail_rules", spec["filter_mailrule"])
    for key, kind in (
        ("filter_has_tags", "tags"),
        ("filter_has_all_tags", "tags"),
        ("filter_has_not_tags", "tags"),
        ("filter_has_any_correspondents", "correspondents"),
        ("filter_has_not_correspondents", "correspondents"),
        ("filter_has_any_document_types", "document_types"),
    ):
        if spec.get(key):
            trigger[key] = rec.resolve_many(kind, spec[key])
    for key in (
        "schedule_offset_days",
        "schedule_is_recurring",
        "schedule_recurring_interval_days",
        "schedule_date_field",
    ):
        if spec.get(key) is not None:
            trigger[key] = spec[key]

    # Paperless rejects an unfiltered consumption trigger. Catching it here
    # names the offending workflow; the server-side 400 does not, and it aborts
    # the run partway through.
    if trigger["type"] == WORKFLOW_TRIGGER_TYPES["consumption_started"] and not any(
        trigger.get(f) for f in ("filter_filename", "filter_path", "filter_mailrule")
    ):
        raise ProvisionError(
            f"workflow {workflow!r} has a consumption_started trigger with no "
            "filter_filename, filter_path or filter_mailrule. Paperless requires "
            'one of these; use filter_filename: "*" for a catch-all. (To tag '
            "everything on consumption, set is_inbox_tag on a tag instead — "
            "Paperless applies those natively.)",
        )
    return trigger


def build_action(rec: Reconciler, spec: dict) -> dict:
    action = {
        "type": enum(WORKFLOW_ACTION_TYPES, spec.get("type", "assignment"), "action type"),
    }
    if spec.get("assign_title"):
        action["assign_title"] = spec["assign_title"]
    if spec.get("assign_tags"):
        action["assign_tags"] = rec.resolve_many("tags", spec["assign_tags"])
    if spec.get("remove_tags"):
        action["remove_tags"] = rec.resolve_many("tags", spec["remove_tags"])
    for key, kind in (
        ("assign_correspondent", "correspondents"),
        ("assign_document_type", "document_types"),
        ("assign_storage_path", "storage_paths"),
    ):
        if spec.get(key):
            action[key] = rec.resolve(kind, spec[key])
    return action


def reconcile_workflows(rec: Reconciler, specs: list[dict]) -> None:
    """Workflows are nested; PATCH replaces triggers/actions wholesale."""
    for spec in specs:
        name = spec["name"]
        triggers = [build_trigger(rec, t, name) for t in spec.get("triggers", [])]
        actions = [build_action(rec, a) for a in spec.get("actions", [])]
        desired = {
            "order": int(spec.get("order", 0)),
            "enabled": bool(spec.get("enabled", True)),
            "triggers": triggers,
            "actions": actions,
        }
        existing = rec.find("workflows", name)
        if existing is None:
            rec.changes.append(f"create workflow {name!r}")
            if not rec.dry_run:
                rec.remember(
                    "workflows", name,
                    rec.client.create("workflows", {"name": name, **desired}),
                )
            continue

        if not nested_equal(existing, desired):
            rec.changes.append(f"update workflow {name!r}")
            if not rec.dry_run:
                rec.remember(
                    "workflows", name,
                    rec.client.update("workflows", existing["id"], desired),
                )
    rec.report_unmanaged("workflows", {spec["name"] for spec in specs})


def nested_equal(existing: dict, desired: dict) -> bool:
    """Compare a workflow, projecting the server object onto managed keys only.

    The server returns every nullable field on nested triggers and actions;
    comparing those directly would report a change on every run.
    """
    for key in ("order", "enabled"):
        if not values_equal(existing.get(key), desired[key]):
            return False
    for key in ("triggers", "actions"):
        current = existing.get(key) or []
        wanted = desired[key]
        if len(current) != len(wanted):
            return False
        for current_item, wanted_item in zip(current, wanted):
            for field, value in wanted_item.items():
                if not values_equal(current_item.get(field), value):
                    return False
    return True


def reconcile_saved_views(rec: Reconciler, specs: list[dict]) -> None:
    year = str(datetime.date.today().year)

    for spec in specs:
        name = spec["name"]
        rules = []
        for rule in spec.get("filter_rules", []):
            rule_name = rule["rule"]
            rule_type = enum(FILTER_RULES, rule_name, "filter rule")
            value = rule.get("value")
            reference = FILTER_RULE_REFERENCES.get(rule_name)
            if value is None:
                rules.append({"rule_type": rule_type, "value": None})
            elif reference and rule_name == "has_tags_in":
                # A multi-valued rule is stored as one row per referenced id.
                for tag in value:
                    rules.append(
                        {
                            "rule_type": rule_type,
                            "value": str(rec.resolve(reference, tag)),
                        },
                    )
            elif reference:
                rules.append(
                    {"rule_type": rule_type, "value": str(rec.resolve(reference, value))},
                )
            else:
                rules.append(
                    {"rule_type": rule_type, "value": str(value).replace("{{year}}", year)},
                )

        desired = {
            "sort_field": spec.get("sort_field", "created"),
            "sort_reverse": bool(spec.get("sort_reverse", True)),
            "filter_rules": rules,
        }
        if spec.get("page_size"):
            desired["page_size"] = int(spec["page_size"])
        if spec.get("display_mode"):
            desired["display_mode"] = spec["display_mode"]

        existing = rec.find("saved_views", name)
        if existing is None:
            rec.changes.append(f"create saved view {name!r}")
            if not rec.dry_run:
                rec.remember(
                    "saved_views", name,
                    rec.client.create("saved_views", {"name": name, **desired}),
                )
            continue

        current_rules = [
            {"rule_type": r["rule_type"], "value": r.get("value")}
            for r in existing.get("filter_rules", [])
        ]
        same = values_equal(current_rules, rules) and all(
            values_equal(existing.get(k), v)
            for k, v in desired.items()
            if k != "filter_rules"
        )
        if not same:
            rec.changes.append(f"update saved view {name!r}")
            if not rec.dry_run:
                rec.remember(
                    "saved_views", name,
                    rec.client.update("saved_views", existing["id"], desired),
                )
    rec.report_unmanaged("saved_views", {spec["name"] for spec in specs})


# GET /api/ui_settings/ injects server-side values into the same dict it
# returns. POST does update_or_create on the whole dict, so these must be
# stripped or they would be persisted as if they were user preferences.
UI_SERVER_KEYS = (
    "version",
    "app_title",
    "app_logo",
    "auditlog_enabled",
    "trash_delay",
    "gmail_oauth_url",
    "outlook_oauth_url",
)


def reconcile_view_visibility(rec: Reconciler, specs: list[dict]) -> None:
    """Put saved views in the sidebar / on the dashboard.

    Under API v10 these are no longer fields on the saved view -- they moved to
    per-user UI settings, and `show_in_sidebar` sent to /api/saved_views/ is
    silently ignored. They therefore have to be written to the admin user's
    ui_settings instead.
    """
    wanted_sidebar, wanted_dashboard = [], []
    for spec in specs:
        obj = rec.find("saved_views", spec["name"])
        if obj is None or obj["id"] < 0:  # not created yet (dry run)
            continue
        if spec.get("sidebar", True):
            wanted_sidebar.append(obj["id"])
        if spec.get("dashboard", False):
            wanted_dashboard.append(obj["id"])

    current = rec.client._request("GET", "/api/ui_settings/") or {}
    settings = dict(current.get("settings") or {})
    saved = dict(settings.get("saved_views") or {})

    if sorted(saved.get("sidebar_views_visible_ids", [])) == sorted(wanted_sidebar) and sorted(
        saved.get("dashboard_views_visible_ids", []),
    ) == sorted(wanted_dashboard):
        return

    rec.changes.append(
        f"update saved-view visibility (sidebar: {len(wanted_sidebar)}, "
        f"dashboard: {len(wanted_dashboard)})",
    )
    if rec.dry_run:
        return

    for key in UI_SERVER_KEYS:
        settings.pop(key, None)
    if isinstance(settings.get("update_checking"), dict):
        settings["update_checking"] = {
            k: v for k, v in settings["update_checking"].items() if k != "backend_setting"
        }
    saved["sidebar_views_visible_ids"] = sorted(wanted_sidebar)
    saved["dashboard_views_visible_ids"] = sorted(wanted_dashboard)
    settings["saved_views"] = saved
    rec.client._request("POST", "/api/ui_settings/", {"settings": settings})


def synthesise_correspondent_workflows(correspondents: list[dict]) -> list[dict]:
    """Turn `correspondents[].tags` into one workflow per tag.

    Paperless correspondents have no "default tags" field, so "everything from
    my insurer is a Versicherung document" has to be expressed as a workflow
    that fires once the correspondent has been matched -- i.e. on
    document_added, not on consumption, when the correspondent is not yet known.

    Grouping by tag rather than by correspondent keeps the workflow count at
    one per domain instead of one per company.
    """
    by_tag: dict[str, list[str]] = {}
    for spec in correspondents:
        for tag in spec.get("tags", []):
            by_tag.setdefault(tag, []).append(spec["name"])

    workflows = []
    for order, (tag, names) in enumerate(sorted(by_tag.items()), start=50):
        workflows.append(
            {
                "name": f"Auto-Zuordnung: {tag}",
                "order": order,
                "triggers": [
                    {
                        "type": "document_added",
                        "sources": ["consume_folder", "api_upload", "mail_fetch", "web_ui"],
                        "filter_has_any_correspondents": sorted(names),
                    },
                ],
                "actions": [{"type": "assignment", "assign_tags": [tag]}],
            },
        )
    return workflows


def read_password(args) -> str:
    if args.password_file:
        path = args.password_file
    elif os.environ.get("CREDENTIALS_DIRECTORY"):
        path = os.path.join(os.environ["CREDENTIALS_DIRECTORY"], "admin-password")
    else:
        raise ProvisionError(
            "no admin password available: pass --password-file or run under "
            "systemd with LoadCredential=admin-password",
        )
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read().strip()
    except OSError as exc:
        raise ProvisionError(f"cannot read password file {path}: {exc}") from None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--base-url", default=os.environ.get("PAPERLESS_BASE_URL", DEFAULT_BASE_URL))
    parser.add_argument("--username", default=os.environ.get("PAPERLESS_ADMIN_USER", DEFAULT_USERNAME))
    parser.add_argument("--password-file")
    parser.add_argument(
        "--taxonomy",
        default=os.environ.get("PAPERLESS_TAXONOMY"),
        help="public taxonomy YAML",
    )
    parser.add_argument(
        "--private",
        default=os.environ.get("PAPERLESS_PRIVATE"),
        help="sops-decrypted YAML with correspondents and mail credentials",
    )
    parser.add_argument("--dry-run", action="store_true", help="report changes, write nothing")
    parser.add_argument(
        "--sync-passwords",
        action="store_true",
        help="also push mail account passwords (they cannot be diffed, so this "
        "always reports a change)",
    )
    parser.add_argument("--wait", action="store_true", help="poll until paperless is serving")
    args = parser.parse_args(argv)

    # Order matters: wait for the socket before trying to authenticate.
    if args.wait:
        wait_for_service(args.base_url)
    client = Paperless.authenticate(args.base_url, args.username, read_password(args))

    if not args.taxonomy:
        raise ProvisionError("--taxonomy is required")

    taxonomy = load_yaml(args.taxonomy)
    private = load_yaml(args.private) if args.private else {}

    rec = Reconciler(client, dry_run=args.dry_run)

    overrides = {o["name"]: o for o in private.get("tag_overrides", [])}

    # Private tags are appended, not merged by name: they exist so that tags
    # which ARE the PII (family members, employers) can be defined without
    # naming them in the public repo. They may parent onto a public tag.
    all_tags = taxonomy.get("tags", []) + private.get("tags", [])

    reconcile_custom_fields(rec, taxonomy.get("custom_fields", []))
    reconcile_tags(rec, all_tags, overrides)
    reconcile_correspondents(rec, private.get("correspondents", []))
    reconcile_simple(rec, "document_types", taxonomy.get("document_types", []))
    reconcile_storage_paths(rec, taxonomy.get("storage_paths", []))

    accounts = reconcile_mail_accounts(
        rec,
        private.get("mail_accounts", []),
        sync_passwords=args.sync_passwords,
    )
    configured_rules = reconcile_mail_rules(
        rec,
        taxonomy.get("mail_rules", []),
        accounts,
        taxonomy,
    )

    workflows = [
        wf
        for wf in taxonomy.get("workflows", [])
        if all(
            trigger.get("filter_mailrule") in (None, *configured_rules)
            for trigger in wf.get("triggers", [])
        )
    ]
    workflows += synthesise_correspondent_workflows(private.get("correspondents", []))
    reconcile_workflows(rec, workflows)
    reconcile_saved_views(rec, taxonomy.get("saved_views", []))
    reconcile_view_visibility(rec, taxonomy.get("saved_views", []))

    verb = "would change" if args.dry_run else "changed"
    if rec.changes:
        print(f"\n{len(rec.changes)} {verb}:")
        for change in rec.changes:
            print(f"  {change}")
    else:
        print("\nalready in sync")

    if rec.unmanaged:
        print(
            f"\n{len(rec.unmanaged)} object(s) exist in Paperless but not in the "
            "config (left untouched):",
        )
        for name in rec.unmanaged:
            print(f"  {name}")

    return 1 if (args.dry_run and rec.changes) else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except ProvisionError as error:
        sys.exit(f"error: {error}")
    except KeyboardInterrupt:
        sys.exit(130)
