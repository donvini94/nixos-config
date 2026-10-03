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
Review the matched code in context; a regex match is a reminder, not proof of a defect.

- **HTTP:** is an appropriate timeout set on this call or its actual client?
- **Collection:** does this operation need all results, and if so does it handle every page
  and report incomplete retrieval? A single-resource lookup needs no pagination.
- **Diagnostics:** can this value contain a credential or sensitive payload? Log only safe
  identifiers and context. Headers and response bodies need particular care.

The full requirements live in `python.md`. Do not add redundant timeouts, pagination or
logging machinery merely to satisfy this trigger.
