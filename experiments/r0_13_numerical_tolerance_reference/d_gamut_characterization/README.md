# R0.13-D — Gamut boundary and mapping characterization

**Status:** CHARACTERIZATION
**Parent:** R0.13
**Document revision:** 0.2
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
