# R4 — README and repository release-readiness audit

**Status:** VALIDATED WITH ONE MANUAL RELEASE-GATE FOLLOW-UP  
**Date:** 2026-09-28  
**GitHub:** #46

## 1. Purpose

This audit closes the remaining R4 documentation/release-readiness questions:

1. whether README installation and DUB-consumer guidance matches the package's
   actual current publication state;
2. whether repository settings, templates and dependency automation are
   adequate for the first public release without adding irrelevant boilerplate.

## 2. README / DUB consumer guidance

Before this audit the README showed a validated API quick start and supported
compiler matrix, but did not explain how a separate DUB project should consume
the package.

That omission mattered because color-d is still pre-v0.1.0:

- no GitHub Release exists yet;
- no released DUB-registry version is part of the current support contract;
- the public API remains consumer-correctable during R4.

The README now distinguishes three states explicitly.

### Current local/workspace development

Use a DUB path dependency:

```sdl
dependency "color-d" path="../color-d"
```

This dependency shape is exercised by Fast CI against an extracted clean
`git archive` package, not only against the repository checkout.

### Current external pre-release consumption

Use a repository dependency pinned to an exact reviewed commit:

```sdl
dependency "color-d" \
    repository="git+https://github.com/alex-1974/color-d.git" \
    version="<commit-sha>"
```

A moving development branch is deliberately not presented as the reproducible
consumer contract.

### After deliberate v0.1.0 publication

Only after the release tag and DUB-registry publication have been verified
should the README's released form become operative:

```sdl
dependency "color-d" version="~>0.1.0"
```

and consumers may use `dub add color-d`.

This keeps documentation truthful before publication rather than describing a
future registry state as if it already existed.

## 3. Repository settings audit

Observed GitHub repository state:

- public repository;
- default branch: `develop`;
- `delete_branch_on_merge = true`;
- squash merges enabled and used for normal topic -> develop integration;
- `develop` is protected and visibly requires:
  - `Fast / dmd-2.113.0`;
  - `Fast / ldc-1.43.0`;
- `main` is reported as protected;
- repository Pages are enabled and development DDox publication is active;
- Issues and Projects are enabled;
- GitHub Releases currently contain no public release.

The GitHub App used for this audit does not have administration permission to
read the complete branch-protection/ruleset configuration. Direct protection
reads return HTTP 403. The branch summary exposes the required Fast checks for
`develop`, but the visible `main` branch summary exposes no required status
check contexts.

The repository already contains a release workflow triggered for pull requests
to `main`, with matrix job names:

- `Release / dmd-2.113.0`;
- `Release / ldc-1.43.0`.

Therefore the remaining settings question is not a code/workflow gap. It is a
manual hosting-policy verification before the v0.1.0 promotion:

> confirm that main is PR-only, force-push/deletion are disabled, and the two
> Release jobs are required before merge.

This is tracked separately as a release-gate follow-up because the current
GitHub integration cannot truthfully verify or modify those administrative
settings.

## 4. Templates

The repository already has the shared baseline without unnecessary extra
forms:

- pull-request template;
- Bug issue form;
- Feature issue form;
- Design decision issue form;
- Research issue form;
- Performance issue form;
- Toolchain problem issue form.

The PR checklist covers the workspace-required concerns:

- target branch;
- issue linkage;
- semantic/regression tests;
- evidence for factual documentation claims;
- Ddoc/examples;
- performance evidence;
- `@trusted` justification;
- CHANGELOG;
- toolchain register;
- package/release metadata.

No extra generic task/docs/security form is added merely for symmetry.
Blank issues remain enabled, so uncommon maintenance/release/security reports
are not blocked by the curated forms.

A dedicated SECURITY policy is not required by the current release scope:
color-d is a pure mathematics library with no parser, network protocol, native
resource ownership or secret-handling surface. This should be revisited if the
library later acquires a materially different attack surface.

## 5. Dependabot

`.github/dependabot.yml` already monitors the repository's actual managed
external dependency surface relevant here:

```yaml
package-ecosystem: "github-actions"
schedule:
  interval: "weekly"
```

color-d currently has no DUB library dependencies in its package recipe, so no
additional package dependency updater is justified.

The existing configuration is intentionally minimal and sufficient.

## 6. Other repository settings

The repository currently has GitHub Wiki enabled while authoritative
documentation lives in the repository and published DDox/pages.

This is not a v0.1 release blocker. No content depends on the Wiki and no
duplicate Wiki documentation is introduced. Disabling the unused Wiki can be a
hosting cleanup choice, but it is not forced as release engineering.

Likewise, enabling auto-merge or branch-update buttons is optional convenience
policy and is not required by the workspace contract.

## 7. Decision

- **README install/DUB guidance:** fixed and aligned with actual pre-release
  state.
- **PR/issue templates:** already sufficient; no boilerplate expansion.
- **Dependabot:** already sufficient for the current dependency surface.
- **develop settings:** observed baseline is consistent with the workspace
  contract.
- **main settings:** full administrative rules cannot be read by the current
  integration; one explicit manual v0.1 release-gate verification remains.
- **production API/code:** no change required.

This audit therefore closes the R4 repository-readiness review while preserving
the hosting-policy uncertainty as a separate concrete release-gate item rather
than pretending it was verified.
