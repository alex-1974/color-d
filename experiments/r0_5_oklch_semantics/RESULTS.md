# R0.5 Results — Oklab / OKLCH and Hue Semantics

## Status

PASS

Tested on x86_64 with:

- DMD 2.111.0, debug build
- LDC 1.41.0, release build
  - DMD frontend 2.111.0
  - LLVM 19.1.7

Both compilers compiled and executed the experiment successfully.

All compile-time assertions passed.

## Validated

R0.5 confirmed that:

1. `OklabHue!T` is practical as a dedicated hue wrapper;
2. the hue wrapper adds no storage overhead beyond its scalar;
3. `Oklch!T` remains a compact three-scalar value type;
4. hue can be stored as raw, unbounded degrees;
5. positive and signed hue normalization can remain explicit operations;
6. degrees are practical as the public/default hue unit;
7. radians can remain internal to trigonometric operations;
8. Oklab <-> OKLCH works with `float` and `double`;
9. the complete conversion works during CTFE;
10. `sqrt`, `atan2`, `sin`, and `cos` work in the tested
    `@safe pure nothrow @nogc` conversion chain;
11. exact achromatic Oklab can use numeric hue `0°` deterministically;
12. raw hue revolutions can be preserved while the value remains in polar form;
13. extra hue revolutions are necessarily lost after conversion through
    Cartesian Oklab;
14. negative chroma is representable as a non-canonical computational value;
15. negative chroma can be canonicalized without changing the represented
    Cartesian color;
16. near-achromatic classification can remain an explicit policy separate from
    exact achromaticity;
17. DMD and LDC produced the same displayed results for all tested cases.

## Layout

Observed on both tested builds:

| Type | sizeof | alignof |
|---|---:|---:|
| `OklabHue!float` | 4 | 4 |
| `OklabHue!double` | 8 | 8 |
| `Oklab!float` | 12 | 4 |
| `Oklch!float` | 12 | 4 |
| `Oklab!double` | 24 | 8 |
| `Oklch!double` | 24 | 8 |

A dedicated hue wrapper therefore introduced no layout penalty in the tested
model.

## Hue representation

The experiment preserved raw hue values exactly.

Example:

    390° -> raw:      390°
    390° -> positive: 30°
    390° -> signed:   30°

and:

    -30° -> positive: 330°

This validates the distinction between:

- stored/raw hue;
- normalized positive hue;
- normalized signed hue.

The experiment does not normalize hue automatically during construction.

## Hue units

The candidate public/default unit was degrees.

Trigonometric operations converted to radians internally.

This model worked cleanly for:

- construction;
- normalization;
- conversion;
- CTFE;
- round trips.

R0.5 therefore supports degrees as a strong candidate for the public hue unit.

## Primary axes

The following Oklab directions produced the expected canonical positive hue:

    +a axis ->   0°
    +b axis ->  90°
    -a axis -> 180°
    -b axis -> 270°

This confirms the intended OKLCH orientation.

## Exact achromatic behavior

The exact achromatic input:

    Oklab(0.42, 0, 0)

produced:

    Oklch(0.42, 0, 0°)

The experiment deliberately handled this case explicitly instead of allowing
`atan2(0,0)` to define public semantics.

The `0°` value is a deterministic numeric fallback.

It does not imply that the achromatic color has a perceptually meaningful hue.

Exact achromaticity remains detectable through:

    C == 0

## Near-achromatic behavior

The experiment distinguished exact achromaticity from policy-driven
near-achromaticity.

Example:

    C = 1e-10

is not exactly achromatic.

It may still be classified as near-achromatic for a caller-supplied epsilon.

This supports keeping numerical tolerance policy separate from the core value
representation.

## R0.4 reference colors

The R0.4 Oklab reference colors produced:

    red:
        Oklch(
            0.627955,
            0.257683,
            29.2339°
        )

    green:
        Oklch(
            0.866440,
            0.294827,
            142.495°
        )

    blue:
        Oklch(
            0.452014,
            0.313214,
            264.052°
        )

    ordinary:
        Oklch(
            0.499568,
            0.175168,
            14.8034°
        )

    extended:
        Oklch(
            0.943018,
            0.253775,
            163.592°
        )

The ordinary and extended values round-tripped back to Oklab within the
selected tolerances.

## Raw hue revolutions

The experiment compared:

    Oklch(0.6, 0.2, 30°)

and:

    Oklch(0.6, 0.2, 390°)

The two values retain different raw hue representations.

After conversion to Oklab they produce the same Cartesian coordinates:

    Oklab(
        0.6,
        0.173205,
        0.1
    )

Converting back from Oklab produces:

    30°

rather than `390°`.

This is expected.

Cartesian Oklab contains direction but no information about how many complete
hue revolutions existed in the originating polar representation.

This validates an important semantic distinction:

- raw hue revolutions can be preserved inside `Oklch`;
- they cannot survive a Cartesian round trip.

## Negative chroma

The raw value:

    Oklch(
        0.6,
        -0.2,
        30°
    )

was accepted as a computational value.

Its explicit canonicalization produced:

    Oklch(
        0.6,
         0.2,
        210°
    )

Both converted to the same Cartesian Oklab value:

    Oklab(
         0.6,
        -0.173205,
        -0.1
    )

This confirms:

    (L, -C, h)
        ≡
    (L,  C, h + 180°)

for Cartesian conversion.

Negative chroma is therefore mathematically representable as a non-canonical
polar form.

R0.5 does not yet decide whether final public API should permit such values.

## Canonicalization

The tested canonicalization rule was:

    if C < 0:
        C = -C
        h = h + 180°

Hue was deliberately not normalized during this operation.

This preserves raw hue semantics while establishing non-negative chroma.

Example:

    (-0.2, 30°)
        ->
    ( 0.2, 210°)

A later explicit hue-normalization operation may then normalize the angle if
desired.

## Float behavior

The `float` path also passed.

Example:

    Oklab!float(
        0.499568,
        0.169354,
        0.0447558
    )

converted to:

    Oklch!float(
        0.499568,
        0.175168,
        14.8034°
    )

and round-tripped successfully within the selected float tolerance.

## CTFE

The following behaviors were successfully evaluated during compilation:

- hue construction;
- raw hue access;
- positive hue normalization;
- signed hue normalization;
- degrees -> radians;
- radians -> degrees;
- `sqrt`;
- `atan2`;
- `sin`;
- `cos`;
- primary-axis conversion;
- exact achromatic conversion;
- ordinary Oklab <-> OKLCH conversion;
- extended-range conversion;
- raw revolution equivalence;
- negative chroma conversion;
- negative chroma canonicalization;
- near-achromatic classification;
- float round trip.

This confirms that the polar Oklab layer remains compatible with the
CTFE-oriented architecture established in R0.1 through R0.4.

## D qualifier finding

The first R0.5 implementation exposed an important D template issue.

A helper shaped approximately as:

    T normalize(T)(T value)

was instantiated with:

    T == const(double)

when called from a `const T` intermediate.

A local:

    T result

therefore also became const and could not be modified.

The corrected implementation used:

    Unqual!T

for mutable arithmetic and the return scalar.

This suggests a general implementation rule for `color-d`:

> Generic mathematical helpers should accept qualified scalar inputs but
> usually perform arithmetic and return values using the corresponding
> unqualified scalar type.

This finding is independent of OKLCH and may apply throughout the library.

## Candidate type model

R0.5 provides strong experimental support for a representation equivalent to:

    struct OklabHue(T)
    {
        T degrees;
    }

    struct Oklch(T)
    {
        T l;
        T c;
        OklabHue!T h;
    }

Advantages demonstrated by the spike:

- explicit angle semantics;
- no layout overhead;
- raw hue preservation;
- natural location for hue-specific operations;
- clean degree/radian boundary;
- CTFE compatibility.

The exact public names remain provisional.

## Current semantic direction

R0.5 strengthens the following design direction:

### Hue

- public/default unit: degrees;
- raw storage: unbounded;
- normalization: explicit;
- dedicated hue type: strong candidate.

### Oklab -> OKLCH

- chroma derived from Cartesian coordinates;
- exact achromatic input receives `h = 0°`;
- non-achromatic conversion outputs canonical positive hue `[0°, 360°)`.

### OKLCH -> Oklab

- raw hue is accepted directly;
- no normalization is required before trigonometric evaluation.

### Chroma

- conversion from Oklab naturally produces `C >= 0`;
- negative manually constructed chroma is mathematically meaningful but
  non-canonical;
- explicit canonicalization preserves the represented color.

### Near-achromatic values

- no implicit epsilon;
- exact and approximate classification remain separate.

## What remains provisional

R0.5 does not freeze:

- final type names;
- final method/property names;
- whether `OklabHue!T` becomes the exact public spelling;
- whether HSL and HSV use separate hue wrapper types;
- whether negative chroma is officially supported by the public API;
- near-achromatic default thresholds;
- NaN behavior;
- infinity behavior;
- CSS missing-component representation;
- polar interpolation API;
- serialization format.

## Architectural consequence

The validated computational chain now extends to:

    SRgb!T
        ⇅
    LinearSRgb!T
        ⇅
    XyzD65!T
        ⇅
    Oklab!T
        ⇅
    Oklch!T

All tested stages remain compatible with:

    @safe
    pure
    nothrow
    @nogc

and CTFE on the tested DMD/LDC toolchains, subject to the specific `cbrt`
workaround established in R0.4.

## Overall conclusion

R0.5 PASS.

The dedicated-hue model is practical and adds no observed storage overhead.

The strongest current model is:

- degrees as public hue unit;
- raw/unbounded hue storage;
- explicit normalization;
- deterministic `0°` fallback for exact achromatic conversion;
- no CSS missing-hue state in the base mathematical type;
- negative chroma treated, if retained, as non-canonical rather than silently
  clamped.

The experiment provides enough evidence to continue using this model in later
research.

A final API freeze remains premature.

## Next research direction

The next useful step should probably not be another color-space conversion.

The core computational chain is now broad enough to exercise higher-level
behavior.

Good candidates are:

1. polar hue interpolation;
2. alpha and premultiplied alpha;
3. linear-light compositing;
4. perceptual interpolation comparison;
5. first concrete consumer spike from theme/style generation.

The next step should be chosen according to the most immediate consumer need
rather than continuing to add color spaces speculatively.