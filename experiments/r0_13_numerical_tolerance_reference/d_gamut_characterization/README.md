# R0.13-D — Gamut boundary and mapping characterization

**Status:** CHARACTERIZED
**Parent:** R0.13
**Document revision:** 0.8
**Date:** 2026-09-25

This harness carries the validated R0.8 gamut semantics into the R0.13
comparison taxonomy.

It imports the mechanically extracted and already validated R0.8 fixture
directly. The gamut algorithms are not copied into this experiment.

D is intentionally staged:

```text
D1  strict gamut classification / explicit epsilon policy / clipping
D2  Local MINDE numerical and algorithm-threshold characterization
D3  Ray Trace numerical and algorithm-threshold characterization
D4  mapping identity, idempotence, metadata and cross-method observations
```

## D2 observed results

D2 has been run in debug builds on the same x86_64 Linux research host with:

- DMD 2.111.0;
- LDC 1.41.0 using DMD frontend 2.111.0 and LLVM 19.1.7.

The complete D2 runtime output was byte-identical between the two tested
compilers.

For both `float` and `double` and both compilers:

- `L >= 1` mapped exactly to linear-sRGB white with zero iterations and
  success;
- `L <= 0` mapped exactly to linear-sRGB black with zero iterations and
  success;
- the selected in-gamut fast-path case returned the expected linear-sRGB value
  exactly with zero iterations and success;
- negative-chroma canonicalization produced exactly the same mapped color,
  iteration count and success flag as the equivalent positive-chroma /
  hue-plus-180-degree representation;
- non-finite input returned failure with zero iterations and did not yield a
  strict in-gamut result;
- all six selected R0.8 regression cases returned success and strict in-gamut
  output;
- the selected regression-case iteration counts matched between scalar types:
  11, 10, 10, 12, 9 and 8 respectively.

The algorithm constants observed by the harness remain:

```text
JND                     0.02
chroma-search epsilon   0.0001
defensive bound         128 iterations
```

These are algorithm semantics, not comparison tolerances.

### Paired float/double generated characterization

Across 4096 deterministic conceptual out-of-gamut inputs accepted in both
scalar representations:

```text
float success failures        0
double success failures       0
float gamut failures          0
double gamut failures         0
iteration-count differences   2
max float iterations          13
max double iterations         13
max RGB absolute difference   3.231754e-04
max deltaEOK                  6.194942e-05
```

The two iteration-count differences are therefore a scalar-precision effect in
this sample rather than a DMD-versus-LDC effect: both tested compilers produced
the same two differences and the same generated maxima.

This is an important metadata distinction. Local MINDE iteration count is exact
for one execution of one scalar implementation, but D2 does not support
treating the count as invariant across `float` and `double` for the same
conceptual input.

Likewise, the observed `3.231754e-04` RGB maximum and `6.194942e-05`
deltaEOK maximum are descriptive measurements. They are not promoted into a
float/double acceptance tolerance.

The observed paired deltaEOK maximum is far below the Local MINDE
`JND = 0.02`, but that comparison is only useful for scale context. The JND
is part of the mapping algorithm and must not be reused as a generic numerical
comparison rule.

D2 therefore strengthens the R0.13 taxonomy:

```text
algorithm threshold
    !=
test tolerance
    !=
scalar-cross comparison rule
    !=
exact per-execution metadata
```

Cross-execution behavior remains R0.13-E.

## D1 comparison classes

```text
CLASSIFY
    finite target-space components in the closed [0,1] interval
    nextDown(0) and nextUp(1) remain strictly outside
    NaN and infinities remain outside

POLICY
    epsilon-aware gamut membership is an explicit caller-selected expansion
    negative epsilon is normalized by magnitude
    epsilon == 0 is compared with strict membership

EXACT
    clipping of selected finite values
    preservation of selected already-in-range values
    clipping idempotence
    observed signed-zero preservation

CLASSIFY / SPECIAL
    clipping does not repair NaN or infinities
    non-finite clipped values remain outside strict gamut

DERIVED
    OKLCH membership after conversion to linear sRGB
```

The D1 policy probe uses `8 * T.epsilon` only as an explicit sample policy
value. It is not a proposed color-d gamut tolerance.

## Boundary rule

Strict gamut membership is geometric/domain classification:

```text
finite
and
0 <= r,g,b <= 1
```

A tolerant query answers a different caller-policy question. R0.13-D must not
replace strict membership with an approximate comparator.

## Clipping rule

For finite target-space values, clipping is coordinate saturation to [0,1].
Non-finite values are deliberately not repaired by the validated R0.8 fixture.

D1 records whether selected identities and idempotence are exact. It does not
infer a general approximate tolerance from clipping.

## Mapping threshold rule

D2 and D3 will separately record algorithm-internal constants such as Local
MINDE JND/convergence thresholds and Ray Trace intersection epsilon.

Those values are `ALGORITHM` semantics. They must not be reused as generic
test tolerances, gamut-membership epsilons or cross-execution tolerances.

## D1 observed results

D1 has been run in debug builds on the same x86_64 Linux research host with:

- DMD 2.111.0;
- LDC 1.41.0 using DMD frontend 2.111.0 and LLVM 19.1.7.

The complete D1 numerical output was byte-identical between the two tested
compilers.

For both `float` and `double`:

- strict linear-sRGB membership accepted black, white and the selected interior
  color exactly;
- `nextDown(0)` and `nextUp(1)` were strictly outside the target gamut;
- NaN and both infinities were strictly outside;
- encoded-sRGB strict membership showed the same selected boundary behavior;
- the explicit sample policy `8 * T.epsilon` admitted the immediately adjacent
  outside representable values but rejected the selected values at twice that
  expansion;
- negative policy epsilon was normalized by magnitude;
- zero policy epsilon matched strict membership for the selected boundary case;
- clipping preserved the selected interior value exactly, saturated the selected
  low/high values exactly to 0/1, and was exactly idempotent;
- clipping preserved the sign bit of selected negative zero;
- clipping did not repair NaN or infinities, and the resulting values remained
  outside strict gamut;
- the selected neutral OKLCH value classified in gamut after conversion while
  the selected high-chroma value classified out of gamut.

The sample `8 * T.epsilon` remains an explicit probe value only. It is not a
candidate default gamut tolerance and is not promoted into production policy.

The D1 result strengthens the R0.13 distinction:

```text
strict target-space membership
    !=
caller-selected numerical boundary policy
```

No approximate comparator is needed to express strict sRGB gamut membership.

No public API or production numerical threshold is frozen by this harness.

## D2 Local MINDE plan

D2 characterizes the validated R0.8 Local MINDE implementation without copying
or replacing the mapping algorithm.

The comparison roles are:

```text
EXACT
    L >= 1 -> white, zero iterations, success
    L <= 0 -> black, zero iterations, success
    selected in-gamut fast-path result and metadata
    negative-chroma canonicalization equivalence

CLASSIFY
    non-finite input fails rather than being silently repaired
    mapped finite outputs must classify in strict sRGB gamut

ALGORITHM
    JND = 0.02
    chroma-search epsilon = 0.0001
    defensive iteration bound = 128

INTERNAL_REGRESSION
    selected R0.8 mapping cases including the published-yellow input

DERIVED
    paired float/double 4096-sample characterization
    success/gamut failures
    iteration-count differences
    maximum observed iterations
    maximum RGB absolute difference
    maximum deltaEOK between paired mapped outputs
```

The Local MINDE `JND` and search `epsilon` are algorithm semantics inherited
from the pinned CSS-facing implementation. They are not:

- generic test tolerances;
- strict-gamut boundary epsilons;
- runtime/CTFE tolerances;
- DMD/LDC tolerances.

The generated float/double maxima are observations only. They do not become
acceptance thresholds merely because they are the largest values seen in this
sample.

The previously validated R0.8 cached-hue implementation remains useful
`INTERNAL_REGRESSION` evidence: it matched the baseline numerically over the
R0.8 4096-case validation set. D2 does not duplicate that optimized
implementation merely to repeat the comparison.

Cross-execution behavior remains R0.13-E.

## D3 Ray Trace plan

D3 characterizes the validated R0.8 Ray Trace implementation without copying
or replacing the mapping algorithm.

The comparison roles are:

```text
EXACT
    L >= 1 -> white, zero iterations, success
    L <= 0 -> black, zero iterations, success
    selected in-gamut fast-path result and metadata
    negative-chroma canonicalization equivalence

CLASSIFY
    non-finite input fails rather than being silently repaired
    mapped finite outputs must classify in strict sRGB gamut

ALGORITHM
    ray intersection epsilon is scalar-specific:
        float  -> 1e-6
        double -> 1e-12
    out-of-gamut iteration budget = 4

INTERNAL_REGRESSION
    selected R0.8 mapping cases including the published-yellow input

DERIVED
    paired float/double 4096-sample characterization
    success/gamut failures
    fixed-budget violations
    iteration-count differences
    maximum observed iterations
    maximum RGB absolute difference
    maximum deltaEOK between paired mapped outputs
```

The Ray Trace epsilon is an intersection/algorithm threshold. It is not a
strict-gamut epsilon, a generic test tolerance or a cross-execution tolerance.

The fixed iteration budget is a different kind of algorithm contract again:
it bounds dynamic work. D3 therefore records budget violations independently
from numerical output differences.

The previously validated R0.8 no-atan2 implementation remains
`INTERNAL_REGRESSION` evidence: it matched the baseline numerically over the
R0.8 4096-case validation set. D3 does not copy that optimized implementation.

## D3 observed results

D3 has been run in debug builds on the same x86_64 Linux research host with:

- DMD 2.111.0;
- LDC 1.41.0 using DMD frontend 2.111.0 and LLVM 19.1.7.

The selected exact semantic cases held for both scalar types in the observed
runs:

- lightness above/below the SDR interval returned exact white/black with zero
  iterations and success;
- the selected in-gamut fast path returned the expected linear-sRGB value
  exactly with zero iterations and success;
- negative-chroma canonicalization matched the equivalent positive-chroma /
  hue-plus-180-degree representation;
- non-finite input returned failure with zero iterations and did not produce a
  strict in-gamut result.

The Ray Trace algorithm parameters remain scalar-specific:

```text
float ray epsilon    1e-6
double ray epsilon   1e-12
iteration budget     4
```

These are algorithm parameters, not comparison tolerances.

### Paired float/double generated characterization

Across the deterministic 4096-case paired out-of-gamut sample:

```text
                                  DMD 2.111      LDC 1.41
float success failures                 3              2
double success failures                0              0
float gamut failures                   0              0
double gamut failures                  0              0
float budget violations                0              0
double budget violations               0              0
iteration-count differences            0              0
max float iterations                   4              4
max double iterations                  4              4
max RGB absolute difference      1.798316e-06   1.798316e-06
max deltaEOK                     8.532310e-07   8.532310e-07
```

Thus the returned mapped colors remained strict in-gamut and the fixed work
budget held in every sampled case, while the experimental Ray Trace
`success` metadata was not compiler-invariant for `float`.

### Fixed compiler-sensitive probe

One DMD-only failure from the generated sample was promoted to a fixed
`float` OKLCH probe:

```text
L = 0.88228511810302734375
C = 0.343281686305999755859
h = 19.4710636138916015625 degrees
```

For that identical target-type input:

```text
DMD 2.111:
    success    false
    iterations 4
    mapped     (1, 0.5812702178955078125, 0.575607419013977050781)

LDC 1.41:
    success    true
    iterations 4
    mapped     (1, 0.5812702178955078125, 0.575607419013977050781)
```

The final mapped `float` components were identical, but the intermediate
OKLCH -> linear-sRGB values differed between compilers.

The trace locates the control-flow divergence at the interior-anchor decision.
Under DMD, the third reconstructed point was approximately:

```text
(0.999998808, 0.581270635, 0.575607836)
```

and classified inside the Ray Trace interior, so it became the new anchor.
The fourth reconstructed point was then only about one float epsilon-scale Ray
step away. Every direction component was smaller than the algorithm's absolute
`1e-6` ray epsilon, so the slab intersection treated all axes as parallel,
left no finite intersection parameter, and triggered the fallback path.

Under LDC, the corresponding third reconstructed point was approximately:

```text
(1.00000143, 0.581269383, 0.575607479)
```

and therefore did not become the interior anchor. The fourth iteration retained
the earlier achromatic anchor and completed successfully.

This behavior is consistent with the pinned CSS Ray Trace design: the
32-bit ray epsilon is `1e-6`, the algorithm performs at most four
intersections, and a failed intersection falls back to the previous result as
a defensive catastrophic-failure path.

For R0.13 the important numerical-policy conclusion is not that the fallback
must be removed. It is that the experimental `success` flag describes
internal algorithm-path completion and is not a portable color-result
equivalence criterion.

Therefore:

```text
same input
    can produce
different internal success metadata
    while producing
the same valid mapped color
```

D3 does not support treating Ray Trace `success` as exact across compilers.
The iteration budget remains exact as an algorithm bound, while observed
iteration counts and internal status require separate cross-execution
characterization.

No D3 observation is promoted into a generic tolerance.

Cross-execution behavior remains R0.13-E.

## D4 mapping-semantics plan

D4 closes the R0.13-D characterization by testing relationships that span the
individual mapping algorithms.

The comparison roles are:

```text
EXACT
    alpha is copied unchanged by per-color mapping
    fast-path output equals the direct target conversion used by that same path

DERIVED
    original in-gamut RGB -> OKLCH -> mapped RGB round-trip distance
    map(map(color)) versus map(color)
    second-map iteration behavior
    Local MINDE versus Ray Trace mapped-color distance

CLASSIFY
    second mapping remains in strict sRGB gamut

POLICY
    Local MINDE and Ray Trace remain distinct explicit mapping choices
```

D4 deliberately does not require Local MINDE and Ray Trace to agree. They are
different gamut-mapping algorithms and R0.8 already established that numerical
differences between them are expected.

Likewise, idempotence after converting the first mapped linear-sRGB result back
through OKLCH is characterized rather than assumed to be bit-exact. That route
contains ordinary floating-point color-space conversions.

The generated maxima in D4 are descriptive evidence only. No idempotence or
cross-method tolerance is frozen in this phase.

Alpha preservation is different: the validated mapping wrappers copy alpha
structurally without transforming it, so selected alpha values are tested as an
exact semantic contract.

Cross-execution equivalence remains R0.13-E.

## D4 observed results

D4 has been run in debug builds on the same x86_64 Linux research host with:

- DMD 2.111.0;
- LDC 1.41.0 using DMD frontend 2.111.0 and LLVM 19.1.7.

### Exact alpha preservation

For both `float` and `double`, both Local MINDE and Ray Trace preserved the
selected alpha values exactly:

```text
0
0.37
1
```

This is structural copy semantics and remains an exact candidate.

### In-gamut identity / fast path

For 4096 accepted in-gamut samples per scalar type, both compilers observed:

```text
local exact-fast-path failures     0
ray exact-fast-path failures       0
local success failures             0
ray success failures               0
local non-zero iterations          0
ray non-zero iterations            0
```

The mapped result was exact relative to the direct `OKLCH -> linear-sRGB`
value used by the fast path.

Relative to the original linear-sRGB value before the
`RGB -> OKLCH -> RGB` round trip, the largest observed deltaEOK was:

```text
float   4.951133e-07
double  1.300668e-15
```

These are conversion-round-trip observations, not mapping tolerances.

### Idempotence after mapped RGB -> OKLCH -> mapped RGB

Across 4096 common out-of-gamut conceptual inputs:

```text
                                  DMD 2.111      LDC 1.41
Local float second non-zero             0              0
Ray float second non-zero            1976           1979
Local double second non-zero            0              0
Ray double second non-zero           2021           2023

Local float exact idempotent            30             30
Ray float exact idempotent              72             71
Local double exact idempotent             8              8
Ray double exact idempotent               3              3

second-map gamut failures                 0              0
```

The maximum observed idempotence distances were identical between the tested
compilers:

```text
Local float   4.097142e-07
Ray float     9.410174e-07
Local double  1.029578e-15
Ray double    1.864381e-15
```

Therefore idempotence of the complete
`mapped RGB -> OKLCH -> mapping` route is a derived numerical property rather
than an exact component-equality property.

Local MINDE entered no second mapping iteration in this sample. Its rare
bit-identical second results still reflect ordinary conversion-round-trip
rounding on the fast path.

Ray Trace frequently entered the mapping path again after the same round trip.
The first mapped result was strict in-gamut, but conversion through OKLCH can
place the reconstructed value on the other side of the strict target-space
boundary. The exact number of such second-pass iterations is compiler-sensitive
in this sample.

This does not justify widening strict gamut membership. It confirms that strict
classification and derived idempotence answer different questions.

### Local MINDE versus Ray Trace

No Local MINDE / Ray Trace result pair was bit-identical in the 4096-case
out-of-gamut sample for either scalar type.

The largest observed cross-method deltaEOK was:

```text
float   7.997055e-02
double  7.997047e-02
```

The values were identical between the tested compiler runs.

This is algorithm-policy divergence, not ordinary floating-point error.
Local MINDE and Ray Trace therefore must not be compared using a generic
"same mapping result" tolerance merely because both map into the same target
gamut.

### D exit conclusion

R0.13-D satisfies its exit criteria:

```text
strict geometry
    !=
boundary-proximity policy

algorithm threshold
    !=
comparison tolerance

per-execution metadata
    !=
cross-scalar / cross-compiler invariant

mapped-color validity
    !=
diagnostic success metadata

idempotence
    == derived numerical property after conversion

Local MINDE result
    !=
Ray Trace result by definition
```

R0.13-D therefore closes as **CHARACTERIZED**. No generic gamut epsilon,
mapping tolerance or cross-method tolerance is promoted.

The remaining runtime/CTFE, Debug/Release and compiler-version portability
questions belong to R0.13-E.
