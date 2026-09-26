# Research document conventions

This document defines metadata and provenance conventions for standalone
research, experiment and design documents in `color-d`.

Git remains the authoritative version history. Document metadata complements
Git by making copied or detached Markdown files identifiable and by recording
their research context and maturity without requiring repository access.

## 1. Scope

This convention applies to standalone research and design artifacts such as:

- documents under `docs/research/`;
- research and design documents under `experiments/`;
- comparable standalone research artifacts elsewhere in the repository.

It does not need to be applied mechanically to `README.md`, `CHANGELOG.md`,
`LICENSE`, ordinary user documentation or API documentation.

## 2. Metadata contract

A standalone research document should normally record:

- `Status`;
- `Document revision`;
- `Date`;
- at least one of `Parent` or `Research baseline`, when applicable.

Use `GitHub` when an issue tracks the work. Context-specific fields such as
`Primary target` may be added when they materially improve provenance.

Not every document needs exactly the same metadata fields. Fields should
describe real relationships rather than satisfy a fixed header shape.

## 3. Field semantics

`Status` describes the document's research or design maturity. It does not
describe Git state merely because a file has been committed.

`Parent` identifies the enclosing research block, experiment or decision when
the document is subordinate to one.

`Research baseline` identifies the already established research state on which
the document builds when a parent relationship would be misleading.

`Document revision` identifies the content revision of the document. It is not
a software, library or API semantic version.

`Date` records the date of the latest revision-worthy content change. It need
not change for purely typographical, formatting or whitespace corrections.

`GitHub` identifies the tracking issue when one exists.

## 4. Revision policy

Use `0.x` revisions for research or design work that is still evolving.
Increase the revision when the document changes substantively. Purely
typographical, formatting and whitespace corrections do not require a revision
change.

`1.0` may be used when the document itself reaches an accepted or validated
state. Later substantive revisions may use `1.1`, `1.2` and so on.

These numbers describe document evolution only. They make no compatibility
promise and do not replace project or library versioning.

## 5. Git provenance

Do not record the document's supposed current commit hash inside the same
document. Editing that hash creates a new commit and makes the value
self-referential or immediately stale.

Git is authoritative for repository history. The last commit affecting a file
can be obtained from its path in repository history.

An optional `Validated at` field may refer to an already existing commit when a
specific validated repository state is materially relevant. It must not be
used as a substitute for normal Git history.

## 6. Validation metadata

`Validated` and `Validated at` are optional. Use them only when the underlying
research or design has actually been validated. A document becoming committed
does not by itself make it validated.

When used, `Validated` records the validation date. `Validated at` records the
already existing commit that identifies the relevant validated repository
state.

## 7. Header examples

A document subordinate to a research block may use metadata such as:

    **Status:** WORKING INVENTORY
    **Parent:** R0.13 — Numerical tolerance and reference policy
    **Document revision:** 0.1
    **Date:** 2026-09-24
    **GitHub:** #9

A standalone design document may instead identify its research baseline:

    **Status:** DESIGN INPUT / CONSUMER RESEARCH


## R0.14 — v0.1 scope and R0→R1 promotion gate

- `docs/research/R0_14_PROMOTION_GATE.md`
- Synthesizes the validated R0 evidence into the accepted v0.1 production
  scope, explicit deferrals, public module/import boundary, compiler policy and
  real-consumer stabilization gate.
