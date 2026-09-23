# R0.10 Results — deltaEOK

## Status

PASS

R0.10 validates the semantics and implementation direction for an Oklab
Euclidean color-difference primitive.

The preferred research candidate is a guarded three-dimensional Phobos
`hypot` implementation.

This result does not yet freeze the public production API.

## Scope

The experiment evaluates:

- direct Oklab-to-Oklab deltaEOK only;
- `float` and `double`;
- runtime and CTFE use;
- UFCS-compatible call shape;
- finite extended Oklab values;
- NaN and infinity propagation;
- analytical reference cases;
- generated metric properties;
- numerical behavior near floating-point range limits;
- DMD and LDC debug/release behavior.

No hidden color-space conversion, clipping, gamut mapping, alpha resolution or
JND classification is part of `deltaEOK`.

## Toolchain

- DMD: `DMD64 D Compiler v2.111.0`
- LDC: `LDC - the LLVM D compiler (1.41.0):`

The final validation matrix covered:

| Compiler | Build | Result |
|---|---|---|
| DMD | debug | PASS |
| DMD | release | PASS |
| LDC | debug | PASS |
| LDC | release | PASS |

## Mathematical semantics

deltaEOK is the Euclidean distance between two Oklab triples.

For component differences `dL`, `da`, and `db`, the mathematical operation is
the three-dimensional Euclidean norm.

The public operation accepts only two `Oklab!T` values with the same supported
scalar type.

No implicit conversion from encoded RGB, linear RGB, XYZ, OKLCH or another
color space is performed.

## Analytical validation

The experiment validates exact/simple analytical cases including:

- identity -> 0;
- L-axis distance 0.25 -> 0.25;
- a-axis distance -0.5 -> 0.5;
- b-axis distance 1.75 -> 1.75;
- vector (3, 4, 12) -> 13.

These cases pass for both `float` and `double`.

CTFE evaluation also passes, including the 3-4-12 case.

## Generated property validation

Each final build executes 4096 generated cases per scalar type.

Validated properties:

- identity;
- non-negativity;
- symmetry;
- agreement with a wider-precision `real` reference route;
- triangle inequality.

All final compiler/build/scalar combinations report zero property failures.

The largest observed normalized reference deviation in the final matrix is
approximately 1.256 times

`T.epsilon * max(1, abs(reference))`.

The experiment uses an operation-specific acceptance bound of

`8 * T.epsilon * max(1, abs(reference))`.

This is an R0.10 test tolerance, not a library-wide numerical-tolerance policy.

## Extended finite range

The direct implementation

`sqrt(dL*dL + da*da + db*db)`

is not accepted as the production candidate.

With finite one-axis inputs near the representable range, debug DMD and both
tested LDC builds demonstrated intermediate overflow and underflow:

- a large finite component produced infinity;
- `T.min_normal` produced zero.

DMD release happened to preserve these particular one-axis values, showing
that the behavior can depend on optimization/code generation. That does not
provide a portable source-level robustness guarantee.

Therefore the direct squared-sum implementation is rejected for the declared
finite extended Oklab domain.

## Scaled norm candidate

A custom scaled three-dimensional norm was tested as a robust alternative.

It:

- preserves the tested large finite values;
- preserves `T.min_normal`;
- produces 13 for the normal 3-4-12 case;
- provides the intended NaN/infinity behavior.

It remains a viable fallback/reference implementation.

However, maintaining a custom numerical norm is unnecessary if the finite
calculation can be delegated safely to Phobos.

## Raw Phobos hypot

The three-argument Phobos `hypot` is numerically robust for the tested finite
range:

- large finite values remain finite;
- `T.min_normal` remains nonzero;
- normal cases agree with the expected Euclidean norm;
- CTFE use is supported by the tested baseline.

However, raw `hypot` does not provide the special-value semantics required by
this experiment on the tested toolchains.

For the simple one-component probes, all four final builds observed:

- raw `hypot(NaN, 0, 0)` did not produce NaN;
- raw `hypot(+Inf, 0, 0)` produced NaN rather than +Inf;
- raw `hypot(-Inf, 0, 0)` produced NaN rather than +Inf.

Raw three-argument Phobos `hypot` is therefore rejected as the complete
`deltaEOK` implementation.

## Preferred candidate

The preferred R0.10 candidate computes the component differences first and
then applies explicit special-value handling:

1. if any component difference is NaN, return NaN;
2. otherwise, if any component difference is infinite, return +Inf;
3. otherwise, return the three-argument Phobos `hypot`.

In schematic D:

    T deltaEOK(T)(Oklab!T lhs, Oklab!T rhs)
    @safe pure nothrow @nogc
    {
        const T dL = lhs.l - rhs.l;
        const T da = lhs.a - rhs.a;
        const T db = lhs.b - rhs.b;

        if (isNaN(dL) || isNaN(da) || isNaN(db))
            return T.nan;

        if (fabs(dL) == T.infinity ||
            fabs(da) == T.infinity ||
            fabs(db) == T.infinity)
            return T.infinity;

        return hypot(dL, da, db);
    }

The final matrix validates this candidate for both `float` and `double`.

## Special-value policy

R0.10 establishes the following research semantics:

- finite Oklab coordinates are accepted without an artificial [0, 1] domain;
- finite extended values are not clipped or gamut-mapped;
- NaN is not repaired and propagates to the result;
- an infinite component difference produces positive infinity unless a NaN
  component difference is also present;
- when NaN and infinity are both present, NaN takes precedence.

These semantics are implemented explicitly rather than inherited accidentally
from compiler- or standard-library-specific behavior.

## API implications

The research supports a future production operation shaped like:

    deltaEOK(Oklab!T lhs, Oklab!T rhs)

with:

- same-scalar operands;
- `float` and `double` support;
- `@safe`;
- `pure`;
- `nothrow`;
- `@nogc`;
- CTFE compatibility;
- UFCS compatibility.

Alpha-bearing colors are not accepted directly. Alpha resolution or
compositing must occur before color-difference measurement.

No `deltaEOKSquared` API is justified by this research.

## JND policy

A just-noticeable-difference threshold is policy layered on top of the
distance primitive.

R0.10 does not embed a JND threshold into `deltaEOK`.

Likewise, the distinct CSS deltaEOK2 algorithm is outside this experiment and
must not be conflated with deltaEOK.

## Conclusion

R0.10 passes.

The recommended production direction is:

**guarded Phobos three-argument `hypot` over direct same-type Oklab component
differences.**

The direct squared-sum formulation is rejected because its finite-range
behavior is not robust across the tested compiler/build configurations.

Raw Phobos `hypot` is rejected as the complete implementation because its
observed simple NaN/infinity behavior does not match the required semantics.

The custom scaled norm remains a validated fallback/reference candidate but is
not preferred while guarded Phobos `hypot` satisfies the requirements.

Public API promotion remains an R1 task.
