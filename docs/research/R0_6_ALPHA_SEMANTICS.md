# R0.6 Research — Alpha and Premultiplied Alpha Semantics

**Project:** `color-d`  
**Status:** Research / pre-experiment design  
**Date:** 2026-09-22  
**Branch:** `research/r0_6-alpha-semantics`

## 1. Purpose

R0.6 investigates the alpha representation and compositing model required by
`color-d`.

The immediate consumers are:

- `imagery-d`;
- renderer and overlay code;
- the planned OSM/geospatial editor.

The central questions are:

- how straight alpha attaches to typed color spaces;
- how premultiplied alpha is represented;
- which color spaces may be premultiplied for compositing;
- how source-over compositing behaves;
- how zero alpha is handled;
- whether alpha outside `[0, 1]` is representable;
- how extended-range RGB interacts with premultiplication;
- how CTFE, D value initialization and compact layout affect the design.

The experiment must distinguish three concepts that are often conflated:

1. attaching an alpha component to a color;
2. premultiplication for alpha compositing;
3. premultiplication used during color interpolation.

These need not have identical type or operation semantics.

---

# 2. Existing color-d direction

The current technical specification already establishes:

```text
Alpha!Color
```

as the preferred orthogonal model for straight alpha.

It also requires a distinct strongly typed representation for premultiplied
alpha.

The reference compositing behavior is defined to operate in linear-light RGB,
with a preferred working representation conceptually equivalent to:

```text
Premultiplied!(LinearSRgb!T)
```

R0.6 does not begin from scratch.

Its purpose is to test and refine those hypotheses before implementation.

---

# 3. Straight alpha

Straight alpha, also called unassociated or unpremultiplied alpha, stores color
and alpha independently.

Conceptually:

```d
struct Alpha(Color)
{
    Color color;
    Color.Scalar alpha;
}
```

Examples:

```text
Alpha!(SRgb!float)
Alpha!(LinearSRgb!float)
Alpha!(Oklab!float)
Alpha!(Oklch!float)
```

The stored color components have not been multiplied by alpha.

Thus:

```text
color = (1, 0, 0)
alpha = 0
```

is representable.

The color is fully transparent for compositing purposes, but the hidden red
color remains present in the straight representation.

This information may matter for:

- editing;
- serialization;
- interpolation;
- later alpha changes;
- round-tripping external data.

---

# 4. Generic Alpha wrapper

A generic alpha wrapper remains the preferred design.

This avoids defining separate computational types such as:

```text
SRgba
LinearSRgba
Oklaba
Oklcha
...
```

as structurally independent implementations.

Convenience aliases may still exist.

For example:

```d
alias SRgbaf = Alpha!(SRgb!float);
alias LinearSRgbaf = Alpha!(LinearSRgb!float);
```

Exact names remain provisional.

## 4.1 Expected advantages

The wrapper model provides:

- one alpha semantic model;
- no duplicated color-space implementations;
- straightforward separation of color and alpha;
- explicit composition with existing color-space types;
- expected compact layout;
- easy conversion where alpha remains unchanged.

Rust `palette` uses the same general architecture.

R0.6 should verify that this approach is equally practical in D.

---

# 5. Computational versus packed alpha types

The generic `Alpha!Color` model should initially apply to computational
floating-point color values.

For example:

```text
Alpha!(SRgb!float)
Alpha!(LinearSRgb!double)
```

Packed storage remains a separate concern.

Possible future storage types include:

```text
SRgba8
PremultipliedRgba8
```

if concrete consumers require them.

R0.6 should not force packed-storage semantics into the generic computational
wrapper.

---

# 6. Alpha semantic range

Standard alpha represents coverage or opacity in the interval:

```text
0 <= alpha <= 1
```

with:

```text
alpha = 0
```

meaning fully transparent and:

```text
alpha = 1
```

meaning fully opaque.

Unlike extended RGB, alpha values outside this interval do not represent
ordinary opacity or coverage.

## 6.1 Proposed distinction

The computational representation should distinguish:

```text
representable value
```

from:

```text
semantically valid alpha
```

Therefore a floating-point `Alpha!Color` should not necessarily clamp during
construction.

For example:

```text
alpha = -0.1
alpha = 1.2
```

may remain representable raw computational values while failing:

```d
isValidAlpha
```

This follows the existing `color-d` principle:

> Do not silently repair or clamp mathematical values during ordinary
> construction.

## 6.2 Current hypothesis

Provide explicit diagnostics such as:

```d
isValidAlpha
```

with approximately:

```text
0 <= alpha <= 1
```

No automatic clamp should occur in R0.6.

A later explicit operation may provide alpha clamping if a consumer requires
it.

---

# 7. NaN and infinity

NaN and infinity should not be silently repaired.

A validity check should naturally reject them.

For example:

```text
NaN       -> invalid alpha
+Infinity -> invalid alpha
-Infinity -> invalid alpha
```

R0.6 does not need to define application policy for such values.

It should confirm that:

- the type can diagnose them;
- ordinary arithmetic does not silently canonicalize them;
- valid finite inputs remain deterministic.

---

# 8. D default initialization

D floating-point values have NaN as their default `.init` value.

Therefore a computational value such as:

```d
Alpha!(LinearSRgb!float).init
```

should not be assumed to represent transparent black.

Its floating-point fields will naturally begin in an invalid state unless
explicit field initializers are introduced.

## 8.1 Current direction

Do not redefine the fields to initialize themselves to zero merely to make
`.init` useful.

An invalid `.init` state is beneficial because it exposes accidental use of an
uninitialized color.

If useful, explicit constants may later provide:

```text
transparentBlack
opaqueBlack
opaqueWhite
```

with intentional values.

This follows D's default-initialization philosophy rather than working against
it.

---

# 9. Premultiplied alpha

For a straight linear-light RGB color:

```text
C = (r, g, b)
alpha = a
```

premultiplication produces:

```text
C' = (r*a, g*a, b*a)
alpha = a
```

The alpha itself is not multiplied.

A premultiplied representation therefore stores the color contribution
directly.

Conceptually:

```d
Premultiplied!(LinearSRgb!T)
```

must remain a distinct type from:

```d
Alpha!(LinearSRgb!T)
```

Straight and premultiplied values must never be silently interchangeable.

---

# 10. Premultiplication is not universally identical

A critical R0.6 finding is that the phrase "premultiplied color" has different
operational meanings depending on the task.

## 10.1 Rectangular RGB compositing

For linear RGB compositing:

```text
r' = r * alpha
g' = g * alpha
b' = b * alpha
```

This is the conventional Porter-Duff representation.

## 10.2 Polar interpolation

For interpolation in a cylindrical color space such as OKLCH, multiplying the
hue angle by alpha would be semantically incorrect.

CSS Color 4 premultiplies the non-hue coordinates while leaving hue
unmodified.

Therefore:

```text
Premultiplied!(Oklch!T)
```

cannot simply mean:

> multiply every numeric member by alpha.

## 10.3 Architectural consequence

R0.6 should not yet define arbitrary generic premultiplication for every color
space.

Instead:

- generic straight `Alpha!Color` is supported as a design direction;
- compositing premultiplication is initially tested for `LinearSRgb!T`;
- alpha-aware Oklab/OKLCH interpolation is deferred to the interpolation
  research stage.

This prevents compositing semantics and interpolation semantics from being
accidentally conflated.

---

# 11. Encoded sRGB must not be the compositing reference space

Encoded sRGB is nonlinear.

The `color-d` reference compositor should therefore not perform source-over
arithmetic directly on encoded sRGB channel values.

The preferred pipeline is:

```text
encoded straight sRGB
        ↓
linearize RGB
        ↓
straight LinearSRgb
        ↓
premultiply
        ↓
source-over composition
```

The resulting linear color may later be unpremultiplied and encoded as
required by the consumer.

---

# 12. Premultiplied color-space conversion

Premultiplied values require care during color-space conversion.

A nonlinear color-space transform must not generally be applied directly to
already-premultiplied components.

The safe conceptual process is:

```text
premultiplied source
        ↓
unpremultiply
        ↓
color-space conversion
        ↓
premultiply in destination representation
```

Skia follows this pattern during color management.

## 12.1 Initial color-d direction

Do not initially expose arbitrary:

```text
Premultiplied!(SRgb)
    ->
Premultiplied!(LinearSRgb)
```

as though this were an ordinary component transform.

For v0.1 research, prefer:

```text
Alpha!(SRgb)
    ->
Alpha!(LinearSRgb)
    ->
Premultiplied!(LinearSRgb)
```

This makes the nonlinear/linear boundary explicit.

---

# 13. Source-over compositing

The initial compositing operation should be Porter-Duff source-over.

For straight source and destination colors:

```text
Cs, As
Cb, Ab
```

the premultiplied source and backdrop contributions are:

```text
cs = Cs * As
cb = Cb * Ab
```

Source-over then becomes:

```text
co = cs + cb * (1 - As)

Ao = As + Ab * (1 - As)
```

where:

```text
co
```

is already premultiplied by the resulting alpha.

This is a natural primitive for:

```text
Premultiplied!(LinearSRgb!T)
```

because no division is required during composition.

---

# 14. Why premultiplied source-over is the primitive

Using premultiplied values provides several useful properties.

The compositor becomes:

```text
out.rgb =
    source.rgb +
    destination.rgb * (1 - source.alpha)

out.alpha =
    source.alpha +
    destination.alpha * (1 - source.alpha)
```

Benefits include:

- simple arithmetic;
- no repeated source RGB multiplication;
- natural representation of accumulated coverage;
- stable transparent-edge behavior;
- direct correspondence to Porter-Duff algebra.

A straight-alpha convenience function may later be built by composing:

```text
premultiply
sourceOver
unpremultiply
```

but the premultiplied operation should remain the reference primitive.

---

# 15. Source-over is ordered

Source-over is not commutative.

Generally:

```text
source over destination
```

does not equal:

```text
destination over source
```

The API should therefore make source and destination roles unambiguous.

A name such as:

```d
sourceOver(source, destination)
```

is preferable to an ambiguous generic `blend(a, b)` for the Porter-Duff
primitive.

Final naming remains provisional.

---

# 16. Associativity

Porter-Duff source-over is associative in its premultiplied algebra under exact
arithmetic:

```text
(A over B) over C
```

represents the same composition as:

```text
A over (B over C)
```

Floating-point evaluation may introduce small rounding differences.

R0.6 should therefore include an approximate associativity regression test.

This property is useful for:

- layer stacks;
- renderer batching;
- tiled processing;
- parallel image composition.

---

# 17. Alpha equal to one

For:

```text
alpha = 1
```

premultiplication leaves RGB unchanged:

```text
C' = C
```

and source-over becomes:

```text
opaque source over destination = source
```

This should be tested exactly where practical.

---

# 18. Alpha equal to zero

Zero alpha requires explicit semantic treatment.

## 18.1 Straight representation

Straight alpha may preserve hidden RGB:

```text
Alpha(
    color = red,
    alpha = 0
)
```

and:

```text
Alpha(
    color = blue,
    alpha = 0
)
```

are distinct stored straight values.

They produce the same visible contribution while alpha remains zero.

## 18.2 Premultiplication

For finite RGB:

```text
C * 0 = 0
```

so all such straight transparent colors become:

```text
Premultiplied(
    color = zero,
    alpha = 0
)
```

The hidden RGB information is lost.

This loss is inherent to premultiplication.

It must be documented rather than hidden.

---

# 19. Unpremultiplication at zero alpha

Ordinary unpremultiplication uses:

```text
C = C' / alpha
```

which is undefined for:

```text
alpha = 0
```

Therefore `color-d` needs explicit semantics for this case.

## 19.1 Proposed canonical behavior

For a valid canonical premultiplied transparent value:

```text
color = zero
alpha = 0
```

unpremultiplication should return:

```text
color = zero
alpha = 0
```

without division.

This provides deterministic transparent black.

It does not recover hidden straight color because that information no longer
exists.

## 19.2 Non-canonical zero-alpha premultiplied values

A raw representation such as:

```text
premultiplied RGB != 0
alpha = 0
```

cannot result from ordinary finite straight-color premultiplication.

Such values should be considered non-canonical.

R0.6 should investigate whether the eventual type:

- prevents them through construction;
- permits an explicit raw/interoperability constructor;
- diagnoses them through an invariant check.

No final public construction policy is required yet.

---

# 20. Canonical premultiplied values

For bounded normalized RGB, some graphics APIs use relations such as:

```text
0 <= premultipliedChannel <= alpha
```

as an invariant.

That relation cannot be a general `color-d` invariant because the library
deliberately supports extended linear RGB values.

For example:

```text
LinearSRgb(
    -0.2,
     1.3,
     0.5
)
```

is a valid computational color.

After premultiplication by `0.5`:

```text
(-0.1, 0.65, 0.25)
```

contains:

- a negative channel;
- a channel greater than alpha.

This is valid extended-range linear color mathematics.

Therefore `color-d` must not use:

```text
RGB <= alpha
```

as a universal validity test for premultiplied computational colors.

---

# 21. Extended RGB and alpha are different domains

The library should explicitly distinguish:

```text
extended RGB
```

from:

```text
extended alpha
```

Extended RGB is an intentional part of the computational model.

Values below zero or above one may be meaningful intermediates.

Alpha, however, represents coverage/opacity and normally has the semantic
range:

```text
[0, 1]
```

Thus:

```text
RGB = 1.3
```

may be a valid computational value while:

```text
alpha = 1.3
```

is diagnostically outside the normal alpha domain.

These policies should not be coupled.

---

# 22. No automatic clamp during composition

The reference compositor should not silently clamp RGB.

This is particularly important for extended linear RGB.

For valid alpha values, source-over should perform the specified arithmetic
and preserve extended RGB results.

Clipping belongs at an explicit later boundary.

Likewise, R0.6 should not silently clamp invalid alpha values merely because a
composition operation is invoked.

Diagnostics and policy enforcement should remain explicit.

---

# 23. Straight color-space conversion

For straight alpha values, ordinary color-space conversion should leave alpha
unchanged.

Conceptually:

```text
Alpha!(SRgb!T)
    ↓
Alpha!(LinearSRgb!T)
```

means:

```text
convert color
preserve alpha exactly
```

Alpha is not a color-space coordinate.

This is a strong candidate for the eventual conversion architecture.

---

# 24. Candidate type model

R0.6 should test approximately:

```d
struct Alpha(Color)
{
    alias Scalar = Color.Scalar;

    Color color;
    Scalar alpha;
}
```

and a distinct representation:

```d
struct Premultiplied(Color)
{
    alias Scalar = Color.Scalar;

    Color color;
    Scalar alpha;
}
```

For R0.6, `Premultiplied!Color` should only be exercised where its semantics
are explicitly defined.

The first supported color should be:

```text
LinearSRgb!T
```

The spike should not imply that arbitrary polar or nonlinear color types are
already valid compositing representations.

---

# 25. Expected layout

Given the already validated color layouts, expected values are:

```text
Alpha!(LinearSRgb!float)          16 bytes
Premultiplied!(LinearSRgb!float) 16 bytes

Alpha!(LinearSRgb!double)         32 bytes
Premultiplied!(LinearSRgb!double) 32 bytes
```

The same generic straight-alpha wrapper should also remain compact for other
three-component float/double spaces.

R0.6 must measure rather than assume these layouts.

---

# 26. Candidate operations

The spike should investigate operations equivalent to:

```d
withAlpha(color, alpha)

isValidAlpha(value)

premultiply(value)

unpremultiply(value)

sourceOver(source, destination)
```

Exact names remain provisional.

The desired attributes remain:

```text
@safe
pure
nothrow
@nogc
```

and CTFE where technically possible.

---

# 27. Conversion direction

The type system should make these transitions visible:

```text
LinearSRgb!T
    ↓ withAlpha
Alpha!(LinearSRgb!T)
    ↓ premultiply
Premultiplied!(LinearSRgb!T)
```

and:

```text
Premultiplied!(LinearSRgb!T)
    ↓ unpremultiply
Alpha!(LinearSRgb!T)
```

There should be no implicit conversion between the straight and premultiplied
representations.

---

# 28. Transparent-color information loss

R0.6 should explicitly test:

```text
straight red, alpha 0
straight blue, alpha 0
```

Both should premultiply to the same value:

```text
premultiplied zero RGB, alpha 0
```

This demonstrates that:

```text
straight -> premultiplied
```

is not injective when alpha is zero.

The API documentation should eventually make this loss explicit.

---

# 29. Reference source-over vectors

R0.6 should include independent reference vectors.

## 29.1 Transparent source

```text
source alpha = 0
```

Expected:

```text
source over destination = destination
```

for canonical premultiplied source.

## 29.2 Opaque source

```text
source alpha = 1
```

Expected:

```text
source over destination = source
```

## 29.3 Transparent destination

For a canonical transparent destination:

```text
destination alpha = 0
```

Expected:

```text
source over destination = source
```

## 29.4 Opaque red backdrop, half-transparent blue source

Straight values:

```text
source:
    RGB   = (0, 0, 1)
    alpha = 0.5

destination:
    RGB   = (1, 0, 0)
    alpha = 1
```

Expected premultiplied output:

```text
RGB   = (0.5, 0, 0.5)
alpha = 1
```

The unpremultiplied output is the same RGB because output alpha is one.

## 29.5 Two half-transparent colors

Straight values:

```text
source:
    RGB   = (0, 0, 1)
    alpha = 0.5

destination:
    RGB   = (1, 0, 0)
    alpha = 0.5
```

Expected premultiplied output:

```text
RGB   = (0.25, 0, 0.5)
alpha = 0.75
```

Expected straight output:

```text
RGB   = (1/3, 0, 2/3)
alpha = 0.75
```

This corresponds directly to the W3C simple-alpha-compositing reference
example.

---

# 30. Extended-range source-over vector

R0.6 should also test a non-display-bounded linear RGB case.

Source:

```text
RGB   = (-0.2, 1.3, 0.5)
alpha = 0.25
```

Destination:

```text
RGB   = (1.2, -0.1, 0.3)
alpha = 0.5
```

Premultiplied source:

```text
(-0.05, 0.325, 0.125)
```

Premultiplied destination:

```text
(0.6, -0.05, 0.15)
```

Expected source-over premultiplied result:

```text
RGB   = (0.4, 0.2875, 0.2375)
alpha = 0.625
```

Expected straight result after unpremultiplication:

```text
RGB   = (0.64, 0.46, 0.38)
alpha = 0.625
```

No clipping should occur.

---

# 31. Alpha validity invariant

For valid inputs:

```text
0 <= As <= 1
0 <= Ab <= 1
```

source-over should produce:

```text
0 <= Ao <= 1
```

R0.6 should test this property.

RGB bounds should not be tested because extended RGB is deliberately allowed.

---

# 32. Raw invalid-alpha experiment

R0.6 should also construct examples such as:

```text
alpha = -0.25
alpha = 1.25
```

to verify:

- raw storage does not silently clamp;
- validity diagnostics reject them;
- construction remains deterministic.

These values should not be used as normative Porter-Duff reference vectors.

The experiment distinguishes representation policy from valid compositing
semantics.

---

# 33. Signed zero

IEEE signed zero may appear in floating-point alpha and color channels.

For alpha:

```text
-0.0 == 0.0
```

for ordinary numeric comparisons.

R0.6 does not need to canonicalize `-0.0` automatically.

It should avoid accidentally making sign-of-zero part of the public alpha
semantic contract unless a concrete need appears.

---

# 34. Special values during premultiplication

Expressions such as:

```text
0 * infinity
```

produce NaN under IEEE floating-point arithmetic.

Therefore transparent premultiplication cannot guarantee zero RGB for
non-finite straight color components.

R0.6 should define the transparent-collapse guarantee only for finite color
inputs.

NaN/infinity behavior should remain explicit and diagnostic rather than
silently repaired.

---

# 35. Interpolation remains a separate research area

Premultiplication is also useful for alpha-aware interpolation.

However, interpolation introduces additional semantics:

- interpolation color space;
- rectangular versus polar coordinates;
- hue handling;
- hue path;
- missing components.

CSS Color 4 specifically treats polar hue differently from other components.

Therefore R0.6 should not attempt to solve general alpha-aware interpolation.

A later interpolation experiment should build on the alpha representation
validated here.

---

# 36. Blending versus compositing

The term "blending" is often used broadly.

For `color-d`, R0.6 should use precise terminology.

## Composition

Porter-Duff operations determine how source and destination coverage
contribute.

Example:

```text
source-over
```

## Blend mode

A blend mode defines how overlapping source and destination colors are mixed
before or during composition.

Examples include:

```text
multiply
screen
overlay
```

R0.6 should implement only ordinary source-over composition.

General blend modes are outside this experiment.

---

# 37. Linear-light reference behavior

`color-d` deliberately chooses linear-light RGB as its reference compositing
space.

This is a library architecture decision motivated by mathematically correct
light arithmetic and the requirements of imagery/rendering consumers.

It should not be misrepresented as meaning that every external graphics
standard or renderer necessarily composites every operation in linear sRGB.

The library contract is narrower:

> `color-d` reference source-over composition is performed on
> `LinearSRgb!T`.

This makes gamma-space composition difficult to invoke accidentally.

---

# 38. Candidate API boundary

A desirable compile-time property is:

```text
sourceOver(
    Premultiplied!(LinearSRgb!T),
    Premultiplied!(LinearSRgb!T)
)
```

is valid, while:

```text
sourceOver(
    Alpha!(SRgb!T),
    Alpha!(SRgb!T)
)
```

is not the low-level compositing primitive.

A higher-level convenience operation may later perform explicit conversion.

This is an example of using D's type system to make the correct path easier
than the incorrect path.

---

# 39. Potential convenience pipeline

A future convenience API may conceptually provide:

```text
straight encoded source
straight encoded destination
        ↓
explicit conversion to linear
        ↓
premultiply
        ↓
sourceOver
        ↓
unpremultiply if required
        ↓
explicit conversion to destination encoding
```

Whether this becomes one helper or remains several explicit steps should be
decided only after consumer experiments.

The reference primitives should stay orthogonal.

---

# 40. Candidate R0.6 experiment matrix

The implementation spike should verify at least:

## Type distinction

```text
Alpha!(LinearSRgb!T)
Premultiplied!(LinearSRgb!T)
```

must remain distinct.

Compile-negative checks should eventually verify they cannot be substituted
implicitly.

## Layout

Test:

```text
float
double
```

for:

```text
Alpha!(SRgb)
Alpha!(LinearSRgb)
Alpha!(Oklab)
Alpha!(Oklch)
Premultiplied!(LinearSRgb)
```

## Default initialization

Verify that `.init` remains diagnostically invalid because its floating-point
members are NaN.

## Alpha validity

Test:

```text
0
0.5
1
-0.1
1.1
NaN
+Infinity
-Infinity
```

## Premultiplication

Test:

```text
alpha = 0
alpha = 0.5
alpha = 1
extended RGB
```

## Unpremultiplication

Test:

```text
alpha = 0
alpha = 0.5
alpha = 1
```

## Information loss

Verify that different finite hidden colors at zero straight alpha collapse to
the same premultiplied representation.

## Source-over

Test:

- transparent source;
- opaque source;
- transparent destination;
- W3C half-blue over opaque-red vector;
- W3C half-blue over half-red vector;
- extended-range vector;
- three-layer associativity.

## Scalar types

Run all essential paths with:

```text
float
double
```

## CTFE

Evaluate:

- construction;
- validity;
- premultiply;
- unpremultiply;
- source-over;
- extended-range vector;
- associativity test

during compilation where practical.

---

# 41. Strong hypotheses entering the spike

R0.6 currently has enough research support to test the following as strong
hypotheses:

1. Straight alpha should use an orthogonal `Alpha!Color` wrapper.
2. The wrapper should remain generic across computational color spaces.
3. Straight and premultiplied alpha must be statically distinct.
4. Premultiplied source-over should use `LinearSRgb!T`.
5. Encoded sRGB should not be the low-level compositing space.
6. Alpha is semantically valid in `[0, 1]`.
7. Raw floating-point construction should not silently clamp invalid alpha.
8. Extended RGB remains valid during composition.
9. `RGB <= alpha` is not a valid universal invariant for extended RGB.
10. Exact zero-alpha premultiplication loses hidden straight RGB.
11. Unpremultiplication at zero alpha requires explicit deterministic
    handling.
12. Premultiplied color-space conversion must respect the
    unpremultiply/transform/premultiply sequence.
13. Generic premultiplication for polar spaces should be deferred until
    interpolation semantics are studied.
14. `.init` should remain invalid rather than becoming implicit transparent
    black.
15. Core operations should remain allocation-free and target
    `@safe pure nothrow @nogc` plus CTFE.

---

# 42. Decisions deliberately deferred

R0.6 does not yet decide:

- final public type names;
- final field visibility;
- exact constructor API;
- whether invalid alpha can be created through ordinary public constructors;
- whether a checked alpha scalar type is warranted;
- packed RGBA storage API;
- premultiplied encoded-RGB interop;
- general Porter-Duff operator set beyond source-over;
- blend modes;
- alpha-aware OKLCH interpolation;
- missing-component semantics;
- GPU-specific layouts;
- SIMD/batch composition;
- final NaN/infinity policy.

These should be decided from implementation evidence and concrete consumers.

---

# 43. Source register

Research basis:

1. **W3C Compositing and Blending Level 1**
   - simple alpha compositing;
   - premultiplied representation;
   - source-over Porter-Duff equations;
   - distinction between blending and compositing.

2. **W3C CSS Color Module Level 4**
   - alpha-aware interpolation;
   - premultiplication before interpolation;
   - hue exclusion from premultiplication in cylindrical polar spaces.

3. **Rust `palette`**
   - generic `Alpha<C, T>` wrapper;
   - `PreAlpha`;
   - modular attachment of transparency;
   - explicit premultiplication support.

4. **Rust `color` crate**
   - distinction between straight `AlphaColor` and `PremulColor`;
   - polar-space hue treatment.

5. **Skia**
   - premultiplied rendering pipeline;
   - distinction between unpremultiplied and premultiplied colors;
   - color-management sequence involving unpremultiply, color transform and
     premultiply.

6. **D Language Specification**
   - floating-point `.init` is NaN;
   - struct default initialization follows field default initialization.

7. Existing `color-d` specification and research:
   - `docs/spec/TECHNICAL_SPEC.md`;
   - R0.1 through R0.5 executable research.

---

# 44. Next step

After this research note is committed, create:

```text
experiments/r0_6_alpha_semantics/
```

The executable spike should validate the hypotheses above before production
modules such as:

```text
alpha.d
composite.d
```

are introduced.

R0.6 should remain a research experiment.

No public API should be frozen from the research note alone.