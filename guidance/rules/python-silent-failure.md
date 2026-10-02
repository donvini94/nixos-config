---
name: python-silent-failure
description: Python patterns that fail silently in production — missing timeout, unpaginated collection, secret reaching a log
condition:
  - "(requests|httpx|session|client)\\.(get|post|put|patch|delete|head|request)\\((?![^)]*timeout)[^)]*\\)"
  - "['\"][^'\"]*/(users|groups|members|roles|entitlements|accounts|applications|assignments|permissions)(\\?[^'\"]*)?['\"]"
  - "(logger|logging|log)\\.(debug|info|warning|error|critical|exception)\\([^)]*(token|secret|password|credential|api_key|apikey|authorization|headers|\\.json\\(\\))"
  - "print\\([^)]*(token|secret|password|credential|api_key|apikey|authorization)"
scope:
  - "tool:edit(**/*.py)"
  - "tool:write(**/*.py)"
---
Stop and check which of these you just wrote. Each one ships without an error and is found
later by an audit rather than by a test.

**HTTP call with no timeout.** `requests` has no default timeout and will hang for minutes;
a scheduled job then holds its slot until someone notices. Add `timeout=` — a
`(connect, read)` tuple if the two differ. If the timeout is already set on the `Session`
or `httpx.Client` this call goes through, say so and continue.

**A collection endpoint.** It returns page one with no error and no indication that more
exists — GitHub returns 30 issues from a repo with 1600 open. Consume the server's own
cursor to exhaustion (`Link: rel="next"`, `nextPageToken`, `@odata.nextLink`). A
deprovisioning or entitlement-diff script that reads page one reports "no orphaned
accounts" because it never looked. If this URL addresses a single resource, continue.

**An object that could carry a secret, going into a log or `print`.** Tokens, session
identifiers, passwords, connection strings and keys must not be written — they land in the
client's log aggregator, retained and searchable by people who were never in scope for that
credential. Log a stable identifier or a hash of the value. `resp.json()` and `headers` are
the usual carriers. Nothing downstream catches this.
