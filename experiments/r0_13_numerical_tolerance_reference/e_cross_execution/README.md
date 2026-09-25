# R0.13-E — Cross-execution characterization

**Status:** CHARACTERIZATION
**Parent:** R0.13
**Document revision:** 0.1
**Date:** 2026-09-25

This harness characterizes numerical behavior across execution contexts after
R0.13-B/C/D established the property-specific comparison taxonomy.

It reuses the validated R0.8 gamut fixture as the shared scalar mathematical
implementation for the first phase. It does not copy those algorithms.

## Staged plan

```text
E1  selected scalar pipeline: runtime <-> CTFE
E2  Debug <-> Release on the same compiler
E3  compiler family/version matrix
E4  cross-execution policy synthesis
```

The controlled target matrix from the R0.13 contract remains:

```text
DMD 2.111.0
DMD 2.112.0
DMD 2.112.1
DMD 2.113.0

LDC 1.41.0
LDC 1.42.0
LDC 1.43.0
```

E1 begins with the installed baseline pair rather than assuming the full matrix
will behave identically.

## E1 selected pipeline

For both `float` and `double`, one function builds the same snapshot in two
execution contexts:

```text
enum CTFE evaluation
runtime evaluation
```

The snapshot includes:

- sRGB decode at an ordinary value and the rounded branch boundary;
- sRGB encode at an ordinary value and the rounded branch boundary;
- linear-sRGB -> XYZ D65;
- XYZ D65 -> Oklab;
- Oklab -> OKLCH;
- deltaEOK;
- Local MINDE mapping of the published-yellow research vector;
- Ray Trace mapping of the same vector;
- the D3 fixed compiler-sensitive Ray Trace probe;
- encoded sRGB after Ray Trace;
- structurally copied alpha through both mapping wrappers.

For numeric coordinates E1 records exact equality and absolute difference.
For mapping metadata it records iteration, success and strict-gamut
classification independently.

This is characterization only. An observed maximum is not an acceptance
threshold.

## Cross-execution rule

E must preserve the distinction established in D:

```text
semantic exactness
    !=
bit identity of derived coordinates
    !=
internal algorithm-path metadata
```

In particular, D3 already proved that a Ray Trace `success` result may differ
between DMD and LDC for the same `float` input while the returned mapped RGB
is identical and in gamut.

Therefore E does not treat compiler- or CTFE-sensitive internal control flow as
a color-correctness failure unless the semantic result being tested requires
that metadata to be portable.

## Relationship to R0.12

R0.12-C observed exact raw palette values and selected metadata agreement
between runtime and CTFE, while mapped and encoded components differed by small
amounts.

Those observations remain evidence, not a frozen contract. R0.13-E re-evaluates
cross-execution policy in light of the more precise B/C/D comparison taxonomy.

No generic runtime/CTFE or compiler-cross epsilon is introduced by this
harness.
