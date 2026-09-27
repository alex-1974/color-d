# Repository Engineering Context

This repository is part of the d-geospatial workspace.

Before changing architecture, public API, numerical behavior, tests, CI,
release configuration, repository structure, performance-sensitive code, or
toolchain work, read the relevant canonical workspace documents under
`.workspace/`.

Canonical workspace documents:

- `.workspace/README.md`
- `.workspace/ROADMAP.md`
- `.workspace/DESIGN_PRINCIPLES.md`
- `.workspace/DLANG_PRACTICES.md`
- `.workspace/RESEARCH.md`
- `.workspace/QUALITY_GATES.md`
- `.workspace/GIT_GITHUB_WORKFLOW.md`
- `.workspace/REPOSITORY_STANDARD.md`
- `.workspace/TOOLCHAIN_ISSUES.md`

Treat those documents as the current shared engineering contract.

Repository-specific documentation may specialize workspace rules where this
repository requires it, but it must not silently contradict workspace-wide
rules. If a necessary exception exists, document the exception and its
rationale explicitly.

Preserve active pre-migration work according to the grandfathering and
transition rules in `.workspace/GIT_GITHUB_WORKFLOW.md`.

Do not assume remembered workspace rules are current when the repository's
`.workspace/` files can be checked.

When a workspace rule and the actual repository state appear inconsistent,
inspect the repository first and explicitly identify the discrepancy before
changing anything.

Preserve this repository's existing domain knowledge, tests, research evidence,
active branches, and documented contracts. Do not mechanically copy
implementation or CI details from another workspace repository.

When `.workspace/` is unavailable, for example in a standalone clone, do not
invent workspace policy. Follow the tracked repository documentation and note
that workspace context was unavailable.
