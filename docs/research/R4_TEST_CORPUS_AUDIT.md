# R4 — Test corpus, package-consumer and toolchain-canary audit

**Status:** VALIDATED AUDIT
**Research baseline:** R1–R3 production API and R4 pre-release hardening
**Document revision:** 1.0
**Date:** 2026-09-28
**GitHub:** #46

## 1. Purpose

This audit reviews four remaining R4 test/CI questions:

1. whether production property/reference corpora are large and reproducible
   enough for their regression role;
2. whether larger numerical corpora should move out of module-local unittest
   blocks;
3. whether the exported consumer package is actually usable as a DUB
   dependency rather than merely having the expected file list;
4. whether current stable compilers should be exercised separately from the
   declared supported matrix.

The goal is not to increase sample counts mechanically. A corpus is useful only
when its domain, seed, acceptance property and CI role are explicit.

## 2. Production regression corpora

The retained production-module property corpora are deterministic and compact.

| Area | Production gate | Size | Seed/domain | Why retained |
| --- | --- | ---: | --- | --- |
| Gamut mapping | paired Local MINDE / Ray Trace reference equivalence | 4096 accepted out-of-gamut cases | `0xC010_D008_2026_0020`; L 0.05–0.95, C 0.22–0.46, hue 0–360°; paired float/double inputs | protects optimized production against retained R0.8 reference implementations and verifies strict target-gamut output |
| Gamut mapping | already-in-gamut identity/fast path | 4096 accepted cases | `0xC010_D008_2026_0010`; interior linear-sRGB components 0.05–0.95 | protects exact identity semantics after explicit conversion without cube-boundary noise |
| WCAG | generated luminance/contrast properties | 4096 cases per scalar | `0xC01D_0009`; encoded sRGB unit-cube values | independent reference luminance, contrast symmetry/domain properties and float/double coverage |
| `deltaEOK` | generated metric/reference properties | 4096 cases per scalar | `0x4f4b4c41425f5230`; extended Oklab coordinates approximately [-4,+4] | identity, non-negativity, symmetry, triangle inequality and wider-`real` reference comparison |
| Tone schedule | finite endpoint grid | 11 × 11 endpoint pairs per scalar | explicit deterministic endpoint set from ±0.75·T.max through signed zero/min-normal and ordinary values | exact endpoint/order/finite/interior invariants; executed both at CTFE and runtime |

The 4096-sample gates were inherited from the validated R0/R0.13 evidence where
applicable. Their seeds are fixed source constants, so a regression can be
reproduced exactly.

Changing a production regression seed or sample count is an engineering-gate
change. It is not a public API change, but the change should state why the new
corpus is stronger or more representative rather than silently replacing
historical evidence.

## 3. Larger retained corpora

Large numerical and performance corpora are already separated from production
modules under `experiments/`.

Representative retained evidence includes:

- R0.13 gamut characterization: multiple deterministic 4096-case corpora with
  distinct seeds for Local MINDE, Ray Trace and mapping semantics;
- sRGB power-path audits: up to 1,000,000 deterministic scalar samples;
- XYZ/linear-sRGB production audits: up to 2,000,000 ordinary samples plus
  dedicated extreme/subnormal sets;
- Oklab/OKLCH production-performance audits: dedicated generated corpora such
  as the 262,144-case OKLCH chroma probe;
- release-performance probes with their own corpus generators, validation
  preflight and runner/compiler records.

These are Tier-2 repository evidence, not ordinary library unittests and not
consumer-package content.

## 4. Module-local versus dedicated fixtures

No production-module corpus should be moved merely because it has thousands of
generated cases.

The current module-local gates remain appropriate because:

- they contain no large checked-in data files;
- the generators are small and deterministic;
- they protect private/reference helpers that should not be made package-public
  just to move tests elsewhere;
- they run inside the normal DMD/LDC debug and release test matrix;
- their sample counts remain modest relative to the dedicated audit corpora.

The larger numerical/benchmark corpora already live in dedicated experiment
drivers. This is the desired split.

A future corpus should move to a dedicated fixture/driver when one or more of
these become true:

- runtime is large enough to make normal Fast CI materially slower;
- the corpus requires bulky non-regenerable data;
- the oracle/reference implementation is independent of private module state;
- multiple modules or repositories need the same fixture;
- raw outputs/distributions need release-archive retention.

Prefer deterministic generation plus a recorded seed over large generated data
files when equivalent.

## 5. Clean consumer-package contract

The existing archive-boundary smoke verifies `.gitattributes export-ignore`
and checks that repository-only material is absent from the consumer archive.

R4 adds the stronger requirement:

> extract the actual `git archive` consumer package, reference that extracted
> package from a separate DUB executable, and build/run the consumer under each
> supported compiler.

This checks the combined package boundary:

- required source and DUB metadata survive export;
- excluded tests/research/CI files are not accidentally required to build;
- `import color` resolves from the clean package;
- the package works as an external DUB dependency rather than only through
  repository-local `-I source` compilation.

The release workflow's existing external DUB smoke remains useful, but its path
dependency points at the repository checkout. The clean-package smoke closes
the stricter packaging question.

## 6. Current-compiler canary

The declared supported matrix remains:

- DMD 2.113.0;
- LDC 1.43.0 / frontend 2.113.0;
- Ubuntu 24.04 x86-64.

A separate scheduled/manual canary uses the dynamically resolved latest stable
DMD and LDC. It is informational and does not redefine the supported matrix or
block ordinary `develop` integration.

The canary exists to reveal:

- future compiler/frontend source incompatibility;
- Phobos/druntime behavior changes;
- obsolete toolchain workarounds;
- new warnings or code-generation/test failures before a deliberate matrix
  update.

Canary failure is evidence to investigate, not automatic evidence that the
declared supported matrix is broken.

## 7. Audit decision

- **Corpus size/seeds:** accepted; deterministic seeds and purposes are now
  centrally recorded.
- **Fixture placement:** accepted; keep compact generated regression corpora
  module-local, retain large numerical/performance corpora in dedicated
  experiment drivers.
- **Clean-package consumer:** strengthen CI with a DUB consumer built from the
  exported archive.
- **Current compiler:** add a separate non-blocking scheduled/manual latest
  stable DMD/LDC canary.

No production numerical algorithm or public API change is required by this
audit.
