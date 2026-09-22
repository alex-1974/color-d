# R0.6 Results — Alpha and Premultiplied Alpha Semantics

## Status

PASS

The experiment compiled and executed successfully with:

- DMD, debug build
- LDC, release build

Both compiler runs produced the same observed results.

All compile-time assertions passed.

## Scope

R0.6 tested the alpha architecture proposed in:

- `docs/research/R0_6_ALPHA_SEMANTICS.md`

The experiment focused on:

- generic straight-alpha representation;
- statically distinct premultiplied representation;
- linear-light source-over compositing;
- zero-alpha semantics;
- extended-range linear RGB;
- compile-time evaluation;
- compile-negative type restrictions.

No production API was introduced.

---

## 1. Generic `Alpha!Color`

The experiment validated a generic straight-alpha wrapper:

```d
Alpha!Color
```

It was successfully instantiated with:

```text
SRgb!T
LinearSRgb!T
Oklab!T
Oklch!T
```

This supports the architectural direction that alpha is orthogonal to the
underlying color space and does not require separate independently implemented
RGBA forms for every computational color type.

### Observed layout

For `float`:

```text
Alpha!SRgbf.sizeof               = 16
Alpha!LinearSRgbf.sizeof         = 16
Alpha!Oklabf.sizeof              = 16
Alpha!Oklchf.sizeof              = 16
```

For `double`:

```text
Alpha!SRgbd.sizeof               = 32
Alpha!LinearSRgbd.sizeof         = 32
Alpha!Oklabd.sizeof              = 32
Alpha!Oklchd.sizeof              = 32
```

The generic wrapper therefore introduces no unexpected layout overhead beyond
the fourth scalar component and normal alignment.

---

## 2. Premultiplied representation

A distinct type:

```d
Premultiplied!Color
```

was validated structurally.

For the R0.6 compositing experiment, semantics were intentionally defined only
for:

```text
Premultiplied!(LinearSRgb!T)
```

### Observed layout

```text
Premultiplied!LinearSRgbf.sizeof = 16
Premultiplied!LinearSRgbd.sizeof = 32
```

Straight and premultiplied alpha therefore remain compact while also remaining
statically distinct.

---

## 3. Static separation of straight and premultiplied alpha

The following type distinction was validated:

```text
Alpha!(LinearSRgb!T)
```

is not the same type as:

```text
Premultiplied!(LinearSRgb!T)
```

No implicit substitution is required or desirable.

This supports the design rule:

> Straight and premultiplied alpha must not be silently interchangeable.

---

## 4. Compile-negative compositing boundaries

R0.6 deliberately restricted the low-level compositor.

The experiment confirmed at compile time that `sourceOver` does not accept:

```text
Alpha!(LinearSRgb!T)
```

directly.

It also does not accept:

```text
Premultiplied!(SRgb!T)
```

or:

```text
Premultiplied!(Oklch!T)
```

The valid low-level operation is:

```text
sourceOver(
    Premultiplied!(LinearSRgb!T),
    Premultiplied!(LinearSRgb!T)
)
```

This is an important architectural result.

The type system can make accidental gamma-space compositing and accidental
polar-space compositing unavailable rather than merely documenting them as
incorrect.

---

## 5. Default initialization

D default initialization produced:

```text
Alpha!(LinearSRgb!float)(
    LinearSRgb!float(nan, nan, nan),
    nan
)
```

The value correctly failed alpha validity testing.

This validates the proposed policy that computational color values should not
artificially redefine `.init` as transparent black.

An accidentally default-initialized floating-point color remains visibly
invalid.

Explicit constants may later provide intentional values such as transparent
black.

---

## 6. Alpha validity

The tested alpha validity policy was:

```text
0 <= alpha <= 1
```

Observed:

```text
0.0   -> valid
0.5   -> valid
1.0   -> valid
-0.1  -> invalid
1.1   -> invalid
NaN   -> invalid
```

Compile-time assertions additionally verified rejection of positive and
negative infinity.

Raw construction did not silently clamp invalid values.

For example:

```text
alpha = -0.1
alpha = 1.1
```

remained representable as raw computational values while failing the validity
predicate.

This matches the existing `color-d` distinction between representation and
semantic validity.

---

## 7. Premultiplication

For:

```text
straight RGB = (0.2, 0.4, 0.8)
alpha        = 0.5
```

the experiment produced:

```text
premultiplied RGB = (0.1, 0.2, 0.4)
alpha             = 0.5
```

Unpremultiplication recovered:

```text
RGB   = (0.2, 0.4, 0.8)
alpha = 0.5
```

The round trip was also evaluated during CTFE.

Opaque alpha behaved as expected:

```text
alpha = 1
```

leaves RGB unchanged during premultiplication.

---

## 8. Zero-alpha hidden-color loss

Straight alpha can preserve hidden RGB at zero alpha.

The experiment constructed:

```text
red:
    RGB   = (1, 0, 0)
    alpha = 0

blue:
    RGB   = (0, 0, 1)
    alpha = 0
```

These are distinct straight values.

After premultiplication, both became:

```text
RGB   = (0, 0, 0)
alpha = 0
```

This confirms that straight-to-premultiplied conversion is not injective at
zero alpha.

Hidden RGB information is inherently lost.

The behavior must be documented but should not be treated as an implementation
error.

---

## 9. Zero-alpha unpremultiplication

Ordinary unpremultiplication requires division by alpha and is undefined at
zero.

The experiment therefore used an explicit zero-alpha branch.

Canonical transparent premultiplied black:

```text
RGB   = (0, 0, 0)
alpha = 0
```

unpremultiplied to:

```text
RGB   = (0, 0, 0)
alpha = 0
```

without division.

This provides deterministic transparent black.

It does not attempt to reconstruct hidden straight RGB because that
information no longer exists.

---

## 10. Porter-Duff source-over

The low-level reference compositor operated on:

```text
Premultiplied!(LinearSRgb!T)
```

using:

```text
out.rgb =
    source.rgb +
    destination.rgb * (1 - source.alpha)

out.alpha =
    source.alpha +
    destination.alpha * (1 - source.alpha)
```

The equations were exercised during CTFE and runtime execution.

---

## 11. Transparent source

For a canonical source with:

```text
alpha = 0
```

the result was exactly the destination.

This validates the source-over identity:

```text
transparent source over destination = destination
```

---

## 12. Opaque source

For:

```text
source.alpha = 1
```

the result was exactly the source.

This validates:

```text
opaque source over destination = source
```

---

## 13. Transparent destination

For a canonical transparent destination:

```text
RGB   = (0, 0, 0)
alpha = 0
```

the result was exactly the source.

This validates:

```text
source over transparent destination = source
```

---

## 14. Half-transparent blue over opaque red

Input straight colors:

```text
source:
    RGB   = (0, 0, 1)
    alpha = 0.5

destination:
    RGB   = (1, 0, 0)
    alpha = 1
```

Observed premultiplied result:

```text
RGB   = (0.5, 0, 0.5)
alpha = 1
```

This matches the expected source-over result.

---

## 15. Half-transparent blue over half-transparent red

Input straight colors:

```text
source:
    RGB   = (0, 0, 1)
    alpha = 0.5

destination:
    RGB   = (1, 0, 0)
    alpha = 0.5
```

Observed premultiplied output:

```text
RGB   = (0.25, 0, 0.5)
alpha = 0.75
```

Observed straight output after unpremultiplication:

```text
RGB   = (0.333333..., 0, 0.666667...)
alpha = 0.75
```

This matches the expected reference values.

---

## 16. Extended-range linear RGB

R0.6 deliberately tested values outside display-bounded RGB.

Source straight color:

```text
RGB   = (-0.2, 1.3, 0.5)
alpha = 0.25
```

Destination straight color:

```text
RGB   = (1.2, -0.1, 0.3)
alpha = 0.5
```

Observed premultiplied source:

```text
(-0.05, 0.325, 0.125)
```

Observed premultiplied destination:

```text
(0.6, -0.05, 0.15)
```

Observed source-over result:

```text
RGB   = (0.4, 0.2875, 0.2375)
alpha = 0.625
```

Observed straight result after unpremultiplication:

```text
RGB   = (0.64, 0.46, 0.38)
alpha = 0.625
```

No clipping occurred.

This validates a critical `color-d` distinction:

> Extended RGB and extended alpha are different concepts.

RGB channels may legitimately leave `[0, 1]` during computation.

Alpha validity remains `[0, 1]`.

---

## 17. No `RGB <= alpha` invariant

Because `color-d` permits extended linear RGB, premultiplied computational
colors cannot universally require:

```text
0 <= channel <= alpha
```

For example, premultiplication can preserve:

- negative channels;
- channels numerically greater than alpha.

This is not an error for extended-range linear color mathematics.

The experiment therefore validates that `RGB <= alpha` must not become a
generic `Premultiplied!Color` invariant.

---

## 18. Source-over alpha bounds

For valid input alpha values, the tested source-over outputs remained inside:

```text
0 <= alpha <= 1
```

This held for the ordinary and extended-RGB test vectors.

RGB itself was intentionally not range-restricted.

---

## 19. Associativity

Three premultiplied linear-light layers were composed using both groupings:

```text
(A over B) over C
```

and:

```text
A over (B over C)
```

Observed output for both:

```text
RGB   = (0.2616, 0.4744, 0.5204)
alpha = 0.832
```

The CTFE regression check used an explicit floating-point tolerance.

This supports the expected associativity of premultiplied Porter-Duff
source-over subject to ordinary floating-point rounding.

---

## 20. `float` and `double`

Essential operations were exercised with both:

```text
float
double
```

The `float` reference composition produced:

```text
premultiplied:
    RGB   = (0.25, 0, 0.5)
    alpha = 0.75
```

and straight:

```text
RGB   = (0.333333..., 0, 0.666667...)
alpha = 0.75
```

Both scalar paths passed their compile-time checks.

---

## 21. CTFE

The experiment successfully evaluated at compile time:

- type/layout assertions;
- `.init` behavior;
- alpha validity;
- premultiplication;
- unpremultiplication;
- transparent hidden-color collapse;
- zero-alpha handling;
- source-over reference vectors;
- extended-range composition;
- associativity;
- `float` and `double` paths.

This strengthens the project-wide design goal that deterministic core color
mathematics remain usable during CTFE.

---

## 22. Function attributes

The tested mathematical helpers were implemented with:

```text
@safe
pure
nothrow
@nogc
```

and successfully participated in the CTFE test chain.

No allocation was required by the alpha/compositing mathematics.

Runtime `writeln` calls were confined to experiment reporting.

---

## 23. DMD / LDC agreement

The experiment was built and executed with:

```text
DMD debug
LDC release
```

Both runs displayed the same results for:

- layouts;
- default initialization;
- alpha validity;
- premultiplication;
- hidden-color collapse;
- source-over reference cases;
- extended-range composition;
- associativity;
- `float` behavior.

No compiler-specific semantic difference was observed in R0.6.

---

## 24. Validated architecture

R0.6 provides strong experimental support for the following model:

```text
                         generic alpha attachment

SRgb!T ────────────────> Alpha!(SRgb!T)

Oklab!T ───────────────> Alpha!(Oklab!T)

Oklch!T ───────────────> Alpha!(Oklch!T)


LinearSRgb!T
      │
      │ with alpha
      ▼
Alpha!(LinearSRgb!T)
      │
      │ premultiply
      ▼
Premultiplied!(LinearSRgb!T)
      │
      │ sourceOver
      ▼
Premultiplied!(LinearSRgb!T)
```

The low-level compositor does not accept encoded sRGB, polar OKLCH or straight
alpha directly.

---

## 25. Strong conclusions

R0.6 strengthens the following design directions:

1. `Alpha!Color` should be the generic computational straight-alpha model.
2. Straight alpha may be attached generically to the supported computational
   color spaces.
3. Straight and premultiplied alpha should remain distinct static types.
4. The initial low-level source-over compositor should operate on
   `Premultiplied!(LinearSRgb!T)`.
5. Encoded sRGB should not be accepted by that compositor.
6. Polar color spaces should not automatically gain generic compositing
   premultiplication semantics.
7. Alpha validity should be diagnosed explicitly as `[0, 1]`.
8. Raw invalid alpha values need not be silently clamped during construction.
9. Default `.init` should remain invalid rather than implicitly becoming
   transparent black.
10. Zero-alpha premultiplication inherently destroys hidden straight RGB.
11. Zero-alpha unpremultiplication can deterministically return transparent
    black.
12. Extended RGB values must survive premultiplication and composition without
    automatic clipping.
13. `RGB <= alpha` is not a valid universal invariant for `color-d`
    premultiplied computational values.
14. Porter-Duff source-over works naturally as the premultiplied primitive.
15. The tested alpha/compositing core is compatible with CTFE and
    `@safe pure nothrow @nogc`.

---

## 26. Still deliberately unresolved

R0.6 does not yet freeze:

- final public type names;
- field visibility;
- constructors;
- checked versus unchecked alpha construction;
- whether a dedicated alpha scalar type is useful;
- packed `RGBA8` representation;
- premultiplied packed storage;
- encoded-premultiplied external interop;
- arbitrary premultiplied color-space conversion;
- additional Porter-Duff operators;
- blend modes;
- alpha-aware interpolation;
- OKLCH interpolation with alpha;
- GPU-specific layout guarantees;
- SIMD/batch compositing.

These remain future architecture or consumer-driven questions.

---

## Conclusion

R0.6 validates the core alpha architecture strongly enough to proceed with it
as the current design direction.

The preferred model is:

```text
generic straight alpha:
    Alpha!Color

reference compositing representation:
    Premultiplied!(LinearSRgb!T)

reference compositing primitive:
    sourceOver(source, destination)
```

This model is compact, statically difficult to misuse, compatible with
extended-range linear RGB, allocation-free, CTFE-capable, and behaved
identically under the tested DMD and LDC builds.

No public API is frozen by this experiment.