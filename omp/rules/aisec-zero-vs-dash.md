---
name: aisec-zero-vs-dash
description: A score of 0 is a finding about the vendor; absence of the key is an admission about us
condition:
  - "\"score\":\\s*\"0\""
scope:
  - "tool:edit(**/vendors.json)"
  - "tool:write(**/vendors.json)"
---
You are writing a `0`. Confirm it is the right symbol before continuing.

- `0` means you CHECKED a canonical source and the capability is absent, or it is
  explicitly outside the vendor's stated scope. It is a finding ABOUT THE VENDOR.
- Omitting the cell entirely means NOT ASSESSED. It is an admission ABOUT US.

Absence from one page establishes nothing. This exact confusion produced 57 wrong
zeros in a single pass; 21 had to be corrected to unassessed. If you did not read a
canonical source for this specific control, leave the key out.
