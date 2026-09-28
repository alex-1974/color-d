# Research repository split

**Status:** COMPLETE — verified split performed 2026-09-28  
**Tracking:** #107  
**Reference model:** `quantities-d` / `quantities-d-research`

## Goal

Keep three products separate:

1. the consumer package;
2. the production/release repository;
3. the detailed research/evidence repository.

The consumer package should contain only what a package user needs. The
production repository should contain source, production tests, CI/release
machinery, user documentation, accepted compact architecture decisions, and
active maintainer contracts. Detailed experiments, compiler probes, rejected
approaches, long-form evidence, and historical research belong in
`color-d-research`.

## Why export-ignore is not sufficient

The verified color-d release archive already uses `.gitattributes
export-ignore`, but normal DUB registry downloads of GitHub-hosted packages
are served from the GitHub repository tag archive.

Therefore tracked research in the production repository still increases what a
normal registry consumer downloads. The research corpus must leave the current
production tree before v0.1.0 is tagged.

## Planned migration set

Preserve the current paths unchanged in the research repository:

```text
experiments/**
docs/research/**
docs/spec/**
docs/RESEARCH_DOCUMENTS.md
```

Measured on `color-d/develop` before this preparation branch:

- complete tree: 219 files / 2,111,675 tracked bytes;
- planned research move: 132 files / 1,577,331 tracked bytes;
- projected production tree after the split: about 87 files / 534,344 tracked
  bytes.

The verified migration used:

- source commit:
  `f5ff3dab97c65e6f45e4c0ed192c3143a946c6bc`;
- exact destination research snapshot:
  `5296ffb16d1a619b658c1296f9d8bd0d1d597c83`;
- files: 132;
- bytes: 1,577,331.

The source and exact destination snapshot matched on relative path, file mode,
byte size, and Git blob identity with zero mismatches. The independent
SHA-256 workflow in `color-d-research` also passed before production deletion.

## Production material that remains

The production repository retains:

- `source/**`;
- production `tests/**`, including promoted compatibility, toolchain,
  performance, and real-consumer gates;
- `.github/**` CI and release machinery;
- README, CHANGELOG, ROADMAP, CONTRIBUTING, LICENSE, DUB metadata, and repository
  policy;
- concise user documentation;
- accepted compact ADRs;
- compact architecture/design principles;
- active maintainer/release contracts;
- a short `RESEARCH.md` pointing to the verified research repository.

Historical R1-R4 closeout documents, exploratory technical specifications,
compiler experiments, benchmark drivers/results, and raw research notes do not
remain merely because they once informed production.

## Verification contract

Use `.github/scripts/verify-research-migration.py` against the exact source
checkout and imported research checkout.

The verifier compares, for every selected path:

- relative path;
- byte size;
- SHA-256 content hash.

It also compares file count and aggregate byte size.

Deletion from color-d is allowed only after:

1. the destination repository exists;
2. all selected files are imported under the same relative paths;
3. source and destination manifests match exactly;
4. source color-d commit and destination color-d-research commit are recorded;
5. production documentation no longer depends on local research paths;
6. production CI/release machinery no longer executes code from the migrating
   tree;
7. any still-active contract has been promoted to a compact production
   document;
8. important provenance links remain understandable.

## History model

Follow the proven quantities-d approach:

- do not rewrite color-d Git history merely to shrink old commits;
- import the research corpus into a separate repository as preserved evidence;
- remove the duplicate research paths only from the current production tree
  after verification.

The old color-d history therefore remains available, while new release tags and
normal DUB downloads use the lean production tree.

## Completed state

The external copy/provenance gate passed before the production deletion branch
was created.

Detailed research now lives at:

https://github.com/alex-1974/color-d-research

The production repository retains only the compact contracts described above.
Historical `color-d` commits remain unchanged and continue to preserve the
original pre-split tree.
