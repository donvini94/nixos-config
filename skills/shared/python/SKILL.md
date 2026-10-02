---
name: python
description: "Python and pyproject work; load the shared Python engineering and silent-failure rules before editing Python."
---

Read and follow the current authored rules before working:

- `~/nixos-config/omp/rules/python.md`
- `~/nixos-config/omp/rules/python-silent-failure.md`

These files are shared with OMP; do not copy or rewrite them for Codex. Translate `rule://NAME` references to `~/nixos-config/omp/rules/NAME.md`. Resolve `omp/templates/` and `omp/research/` beneath `~/nixos-config/`. OMP-native TTSR/glob enforcement is not installed in Codex; apply the domain restrictions explicitly. Use available Codex tools for any OMP tool references.
