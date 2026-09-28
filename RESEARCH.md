# color-d research and evidence

`color-d` separates three different products:

1. the **consumer release**, which should contain only the library and useful
   consumer documentation;
2. the **production GitHub repository**, which contains maintained source,
   tests, CI, release engineering, compact architecture decisions, and
   contribution material;
3. the **research/evidence repository**, which is intended to hold experiments,
   compiler reproducers, detailed numerical studies, rejected approaches,
   benchmark drivers/results, and long-form research history.

This is the same separation principle used by `quantities-d`.

## Current transition state

The consumer-release boundary is already enforced by `.gitattributes` and CI:
research/evidence paths are not exported into release archives.

The production-repository split is still in transition. Historical research is
currently retained under:

- `docs/research/`;
- `experiments/`.

Issue #107 tracks the safe migration of that material to a separate
`color-d-research` repository.

Until that migration is independently verified, the historical material stays
here. Do not delete or rewrite it merely to make the repository smaller.

## What remains in color-d after the split

The production repository should retain the durable decisions a maintainer or
consumer needs without requiring the research repository:

- public source and Ddoc;
- user tutorials, how-to guides, concepts, glossary, accuracy notes, and
  architecture overview;
- accepted ADRs and compact decision summaries where they remain useful for
  maintenance;
- production tests and compatibility probes;
- CI and release machinery;
- README, CHANGELOG, ROADMAP, CONTRIBUTING, LICENSE, and DUB metadata.

Detailed evidence may be cited from the research repository, but it must not be
required to understand or use the public API.

## Promotion rule

Research does not become public API merely because an experiment exists.

A research result reaches production only through an explicit production
change: source/API, tests, public documentation, an ADR or compact maintained
decision record, and normal review gates as applicable.

This file will be updated with the verified research-repository URL after the
migration tracked by #107 is complete.
