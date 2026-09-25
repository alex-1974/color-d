# R0.13-E — Cross-execution characterization

**Status:** CHARACTERIZED
**Parent:** R0.13
**Document revision:** 0.6
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

## E1 baseline observations

E1 has been run in debug builds with DMD 2.111.0 and LDC 1.41.0
(using the DMD 2.111 frontend).

For the selected snapshot, both compilers produced the same numerical
runtime-versus-CTFE differences.

Observed float examples include:

```text
decode ordinary       1.490116e-08
encode ordinary       2.980232e-08
XYZ max component     2.980232e-08
Oklab max component   5.960464e-08
OKLCH max component   4.577637e-05   (hue in degrees)
deltaEOK              7.450581e-08
Local MINDE RGB       1.788139e-07
Ray Trace RGB         5.960464e-07
encoded Ray RGB       2.980232e-07
```

Selected double runtime-versus-CTFE differences were generally in the
1e-16 range, with the OKLCH hue probe reaching approximately
8.526513e-14 degrees.

The rounded transfer-boundary probes were exact in the selected cases.
Ordinary derived coordinates generally were not.

The fixed D3 Ray Trace float probe is the important metadata case:

```text
DMD runtime:  iterations=4 success=false in-gamut=true
DMD CTFE:     iterations=4 success=true  in-gamut=true

LDC runtime:  iterations=4 success=true  in-gamut=true
LDC CTFE:     iterations=4 success=true  in-gamut=true
```

The DMD and LDC CTFE mapped coordinates for this probe were the same in the
observed runs, and the runtime mapped coordinates were also the same. The
compiler-sensitive difference is the DMD runtime control-flow outcome recorded
by the experimental success flag.

This strengthens the D3 conclusion:

```text
cross-execution internal metadata
    !=
portable mapped-color semantics
```

Selected alpha preservation remains exact structural semantics. E1 reports
typed equality and does not use promoted decimal formatting as evidence for
stored scalar identity.

No E1 observation is promoted into a tolerance.

## E2 Debug versus Release observations

E2 reused the exact E1 snapshot under debug and release builds of the baseline
compilers.

### DMD 2.111.0

The debug and release outputs differed in exactly one selected value:

```text
double decode ordinary

debug:
    runtime = 0.147318999244498011203
    CTFE    = 0.147318999244498011203
    exact   = true

release:
    runtime = 0.147318999244498038959
    CTFE    = 0.147318999244498011203
    exact   = false
    abs     = 2.775558e-17
```

At this magnitude the observed difference is one binary64 ULP.

Every other selected E1 output line, including the compiler-sensitive Ray Trace
probe metadata, was identical between DMD debug and release.

Therefore DMD 2.111 already demonstrates that:

```text
same compiler
+
same source
+
same scalar type
+
different optimization mode
    can produce
different derived floating-point coordinates
```

This does not imply a semantic failure. It means Debug/Release bit identity is
not a general portable correctness contract for derived numerical operations.

### LDC 1.41.0

For the complete selected E1 snapshot, LDC debug and release output was
byte-identical. No numeric coordinate, classification, mapping metadata or
selected exact property changed.

This is useful evidence but not a universal LDC guarantee; it is the observed
result for the current snapshot, compiler version, target and host.

### E2 conclusion

The baseline pair therefore differs in optimization sensitivity:

```text
DMD 2.111:
    selected Debug/Release numeric difference observed

LDC 1.41:
    selected Debug/Release output identical
```

R0.13 must not derive one generic Debug/Release identity rule from either
compiler.

No E2 observation is promoted into a tolerance. The next phase extends the same
deterministic snapshot across the controlled compiler-version matrix.

## E3 compiler-version matrix observations

E3 reused the E1 snapshot in debug mode across the controlled compiler matrix:

```text
DMD 2.111.0
DMD 2.112.0
DMD 2.112.1
DMD 2.113.0

LDC 1.41.0
LDC 1.42.0
LDC 1.43.0
```

Environment-identification lines were excluded before hashing so that the
hashes represented only the selected numerical/semantic output.

Observed SHA-256 groups:

```text
all DMD versions:
    b61fc8f1b2a4258efea09478d7cfaee4b22b847f7618c66b4b1697995419a23e

all LDC versions:
    cf18f8dcc21c331350677fa9a46482a4ea4498f0b37235144d7eebb158af5e2a
```

Therefore no numerical-version drift was observed within either compiler family
for this deterministic debug snapshot.

A direct diff between DMD 2.111.0 and LDC 1.41.0 contained exactly one changed
line:

```text
float Ray Trace fixed probe metadata

DMD runtime:
    iterations=4
    success=false
    in-gamut=true

LDC runtime:
    iterations=4
    success=true
    in-gamut=true

both CTFE paths:
    iterations=4
    success=true
    in-gamut=true
```

The mapped RGB coordinates for the fixed probe were byte-identical in the
printed snapshot across the compiler families. The difference was confined to
the experimental runtime success metadata already isolated in D3/E1.

The tested compiler-version matrix therefore supports three separate statements:

```text
within-family numerical snapshot stability
    observed across the tested versions

cross-family mapped-coordinate stability
    observed for the selected snapshot

cross-family internal Ray success metadata stability
    disproved by the fixed float probe
```

This evidence does not justify a blanket compiler-independence guarantee for
all future operations or targets. It does show that the current observed
cross-compiler difference is narrower than a generic numerical-output drift.

No E3 observation is promoted into a tolerance.

### E3 release matrix

The same controlled compiler-version matrix was repeated in release mode.

Observed SHA-256 groups after removing environment-identification lines:

```text
DMD 2.111.0
DMD 2.112.0
DMD 2.112.1
DMD 2.113.0
    -> a27373701a6afc5ef46ac57262460c4dad8bd80d94589f635e8bb6abff705b2c

LDC 1.41.0
LDC 1.42.0
LDC 1.43.0
    -> cf18f8dcc21c331350677fa9a46482a4ea4498f0b37235144d7eebb158af5e2a
```

Thus release output was also version-stable within each compiler family.

Compared with the debug hashes:

```text
DMD debug    b61fc8f1...
DMD release  a2737370...   different

LDC debug    cf18f8dc...
LDC release  cf18f8dc...   identical
```

A direct DMD 2.111 versus LDC 1.41 release diff contained exactly two changed
lines:

1. the already isolated fixed `float` Ray Trace runtime `success` metadata;
2. ordinary `double` sRGB decoding of `0.42`.

For the latter:

```text
DMD release runtime = 0.147318999244498038959
LDC release runtime = 0.147318999244498011203
CTFE                = 0.147318999244498011203
absolute difference = 2.775558e-17
```

At this magnitude the observed runtime difference is one binary64 ULP.

No other selected numeric coordinate, classification, mapping metadata or exact
property differed in the release family comparison.

### E3 conclusion

Across the tested matrix:

```text
DMD 2.111-2.113
    version-stable in debug
    version-stable in release
    debug != release because of selected double decode behavior

LDC 1.41-1.43
    version-stable in debug
    version-stable in release
    debug == release for the selected snapshot

DMD vs LDC
    debug:
        one Ray Trace runtime success-metadata difference
    release:
        same Ray success-metadata difference
        plus one-ULP ordinary double sRGB decode difference
```

E3 therefore closes as **CHARACTERIZED**.

The evidence rules out a general bit-identity requirement across build modes or
compiler families while also showing that the observed portability differences
are narrow and property-specific rather than broad numerical instability.

No compiler-cross tolerance is frozen by E3.

## E4 cross-execution policy synthesis

E1-E3 show that cross-execution comparison is not a new numerical operation
class with one tolerance. It is a portability dimension applied to the
property-specific contracts established by R0.13-A-D.

The resulting rule is:

```text
do not ask:
    "are all executions numerically equal within one cross-execution epsilon?"

ask:
    "does each execution satisfy the same semantic/reference contract for
     this property?"
```

Exact semantic properties remain exact in every execution context. Derived
coordinates are not generally required to be bit-identical across runtime
and CTFE, Debug and Release, DMD and LDC, or compiler versions unless the
specific operation contract independently establishes exactness.

Strict predicates keep their strict mathematical semantics. For derived
values later classified by such a predicate, each execution must satisfy
the semantic postcondition; no hidden epsilon is added merely to force
cross-execution agreement.

Algorithm metadata must be split by meaning. Structural contracts such as a
fixed work budget may remain exact. Path-dependent metadata such as the
experimental Ray Trace `success` flag is not automatically portable: D3/E1/E3
show the same conceptual input can return different internal path status
while yielding an acceptable strict in-gamut mapped color.

CTFE and runtime therefore share the same public mathematical semantics, not
a blanket bit-identity requirement for every derived floating-point result.
Debug and Release likewise must satisfy the same property-specific contracts
without requiring general bit identity.

The tested compiler matrix provides no evidence for a DMD epsilon, an LDC
epsilon, a compiler-version epsilon, a Debug epsilon or a Release epsilon.
If a future compiler needs a distinct workaround or envelope, that requires
direct evidence for the affected operation.

Cross-execution tests should therefore remain layered:

```text
1. exact semantic assertions
2. strict classifications / semantic postconditions
3. independent or analytical reference comparisons
4. derived / round-trip comparisons
5. cross-execution diagnostics
6. algorithm-metadata diagnostics where relevant
```

The cross-execution layer records portability drift. It does not replace the
lower property-specific layers with a generic approximate-equality helper.

R0.13-E provides no evidence for a production-facing cross-execution
tolerance or compiler-specific numerical policy object.

## E exit conclusion

R0.13-E satisfies its exit criteria:

```text
runtime <-> CTFE:
    semantic agreement required; generic bit identity not required

Debug <-> Release:
    same semantic/reference contract; generic bit identity not required

compiler <-> compiler:
    same semantic/reference contract; generic bit identity not required

compiler version <-> compiler version:
    same semantic/reference contract; no version-specific tolerance justified

exact semantic properties:
    remain exact

strict classifications:
    remain strict

derived numerical values:
    use operation-specific comparison rules

path-dependent algorithm metadata:
    diagnostic unless independently promoted
```

R0.13-E therefore closes as **CHARACTERIZED**.

No universal cross-execution epsilon, compiler-specific tolerance or
build-mode tolerance is promoted.

The remaining work belongs to R0.13-F: consolidate A-E into the
production-test and API numerical policy.
