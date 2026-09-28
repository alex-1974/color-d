# R4 — v0.1.0 feature freeze

**Status:** ACTIVE RELEASE POLICY  
**Research baseline:** R1–R3 production closeout and pre-R4 hardening #46  
**Document revision:** 1.0  
**Date:** 2026-09-28  
**Effective:** when this policy is integrated into `develop`  
**Release target:** `v0.1.0`  
**GitHub:** #14

## 1. Decision

The accepted `color-d` feature scope for v0.1.0 is frozen.

The freeze applies to **feature scope**, not to all code changes.

R1–R3 define the accepted production functionality for v0.1.0. R4 exists to
exercise that surface through real consumers and to correct defects or API
friction before the first public release. Release hardening may continue, but
it must not become a second feature-development phase.

## 2. Frozen v0.1 scope

The frozen scope is the functionality already promoted through R1–R3:

- typed computational sRGB and linear-light sRGB;
- XYZ D65;
- Oklab and OKLCH;
- `float` and `double` scalar families;
- explicit color-space conversions;
- alpha and premultiplied-alpha representation and transitions;
- linear-light source-over compositing;
- same-space and OKLCH interpolation with explicit hue-path control;
- gamut testing and explicit clipping;
- explicit Local MINDE and Ray Trace sRGB gamut mapping;
- WCAG-2 relative luminance and contrast measurement;
- Oklab `deltaEOK`;
- low-level OKLCH component and tone-family primitives;
- the accepted root and direct-module import surface.

Detailed semantics remain those documented by the production API, ADRs,
R1–R3 closeouts, and validated numerical policy.

## 3. Allowed during the freeze

The following remain valid v0.1 work:

- reproduced defect fixes with regression evidence where practical;
- real-consumer-driven corrections to the existing v0.1 API/contract;
- tests, compile probes, canaries, and reference validation;
- README, Ddoc, tutorials, CHANGELOG, release notes, and support statements;
- CI, packaging, documentation publication, and release engineering;
- security or confirmed compiler/runtime adaptations;
- performance fixes only when current measurement identifies a material
  problem in an accepted v0.1 operation.

Pre-1.0 breaking corrections remain allowed when real consumer evidence shows
that the existing accepted contract is ambiguous or materially impractical.
Consumer friction does **not** automatically authorize a new feature family.

## 4. Not allowed during the freeze

Do not add new feature scope merely because it is useful or convenient:

- new color spaces;
- new packed/storage color families;
- new palette/theme abstractions;
- parsing/serialization families;
- accessibility/tooling feature families;
- generic convenience APIs that duplicate explicit operations;
- a default gamut mapper;
- policy-heavy application abstractions;
- speculative aliases or shortcuts;
- broad refactors without a concrete correctness/release/consumer reason;
- speculative compiler-specific optimization.

Already deferred candidates remain deferred unless the freeze is explicitly
reopened: `SRgb8` / `SRgba8`, HSL / HSV, Display-P3, Rec.2020, CIELAB / LCh,
CIEDE2000, Okhsl / Okhsv, CSS parsing/serialization, palette systems,
color-vision-deficiency tooling, HDR, and ICC / CMYK.

## 5. Consumer validation during the freeze

R4 remains active. The freeze must not make consumer validation ceremonial.
A real consumer may reveal that an accepted operation is unusable or
mis-specified.

Decision order:

```text
consumer evidence
    ↓
defect/API correction within accepted scope?
    ├─ yes -> fix under the freeze
    └─ no
        ↓
does v0.1 genuinely require new feature scope?
        ├─ no -> defer
        └─ yes -> explicit freeze-reopen decision
```

The default is to defer new capability rather than silently expand v0.1.

## 6. Reopening the freeze

The freeze may be reopened only through an explicit color-d release-scope
decision. That decision must record:

1. concrete blocking evidence;
2. why the need cannot be satisfied by the existing accepted surface;
3. why deferral beyond v0.1 is unacceptable;
4. the exact additional scope;
5. required tests/documentation/performance evidence;
6. impact on release timing and public API;
7. whether renewed consumer validation is required.

After the narrowly approved addition is complete, the freeze resumes.

## 7. Engineering implication

`develop` is not immutable. Normal topic branches, PR review, and CI continue.

The admission question changes from:

> Is this useful functionality?

to:

> Is this necessary to correct, validate, harden, or release the already
> accepted v0.1 scope?

If the answer is no, the work belongs after v0.1.

## 8. End of freeze

The feature freeze remains active until v0.1.0 is published.

Publication still requires the remaining release gates, including real
consumer validation (#4 and #13), resolution or deliberate deferral of
consumer-discovered friction, hosting/release checks, one exact qualified
release commit, and deliberate tag/release publication.

The freeze is release discipline, not a permanent statement that color-d
will never grow.
