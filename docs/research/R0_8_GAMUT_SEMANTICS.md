# R0.8 Research — Gamut Detection, Clipping and Mapping Semantics

**Project:** `color-d`
**Status:** Research / pre-experiment design
**Date:** 2026-09-22
**Branch:** `research/r0_8-gamut-semantics`

## 1. Purpose

R0.8 investigates gamut semantics for `color-d`.

It addresses two remaining R0 promotion-gate items:

- gamut detection and clipping contract;
- perceptual gamut-mapping policy/prototype.

R0.8 must establish a strict architectural separation between:

```text
gamut detection
clipping
gamut mapping
color-space conversion
```

These operations solve different problems and must not become implicit aliases for one another.

No public API is frozen by R0.8.

---

## 2. Existing color-d principles

Previous research established several rules that directly constrain gamut design.

R0.2 through R0.7 validated that computational colors may contain extended values such as:

```text
RGB < 0
RGB > 1
```

These values are not automatically invalid.

Conversions, interpolation and compositing must therefore not silently clamp or gamut-map ordinary intermediate colors.

The existing architectural direction is:

```text
mathematical color value
        ↓
explicit conversion
        ↓
extended mathematical result
        ↓
optional explicit gamut operation
```

not:

```text
conversion
        ↓
implicit clipping/mapping
```

---

## 3. Gamut is target-dependent

A color is not simply:

```text
in gamut
```

or:

```text
out of gamut
```

without identifying the destination gamut.

For example, one color may simultaneously be:

```text
inside Display-P3
outside sRGB
```

Therefore gamut membership is a relation between:

```text
color
+
target gamut
```

not an intrinsic Boolean property of an arbitrary mathematical color.

Conceptually:

```d
inGamut(color, target)
```

is more precise than a universal:

```d
color.inGamut
```

unless the type itself has an unambiguous bounded native gamut.

---

## 4. Bounded and unbounded spaces

RGB display spaces have explicit bounded SDR gamuts.

For sRGB:

```text
0 <= R <= 1
0 <= G <= 1
0 <= B <= 1
```

The same geometric gamut applies to:

```text
SRgb
LinearSRgb
```

because transfer-function encoding changes coordinates but not the physical primaries or white point.

By contrast, spaces such as:

```text
XYZ D65
Oklab
OKLCH
```

are mathematical working spaces rather than bounded RGB device gamuts.

They should not be treated as if their individual component reference ranges directly define an sRGB-like display gamut.

For example:

```text
Oklab.l within [0,1]
```

does not imply that the represented color is inside sRGB.

Likewise:

```text
Oklch.c >= 0
```

does not imply display-gamut membership.

---

## 5. Initial destination gamut

The first production `color-d` scope currently contains only sRGB as a concrete bounded RGB target.

Therefore R0.8 should primarily validate:

```text
sRGB gamut
```

without inventing an unnecessary generic gamut framework before Display-P3 or another second RGB gamut is admitted.

However, the semantics should not make future extension impossible.

The experiment may therefore use an experiment-local target abstraction if useful, but no public generic target API is required yet.

---

## 6. Gamut detection

Gamut detection is a diagnostic query.

It must not modify the color.

Conceptually:

```d
bool inSrgbGamut(color)
```

or eventually:

```d
bool inGamut(color, target)
```

The operation should:

1. convert the color mathematically to the target RGB space if required;
2. inspect the target RGB coordinates;
3. return whether all bounded color coordinates lie inside the target reference range.

For sRGB:

```text
R,G,B ∈ [0,1]
```

Alpha should not affect gamut membership.

---

## 7. Encoded versus linear sRGB detection

Because encoded and linear sRGB describe the same RGB primaries and white point:

```text
SRgb
LinearSRgb
```

have the same physical gamut.

A valid in-gamut encoded color corresponds to an in-gamut linear color.

Therefore:

```text
inSrgbGamut(SRgb)
```

and:

```text
inSrgbGamut(LinearSRgb)
```

should agree for equivalent colors.

The experiment should explicitly verify this.

---

## 8. Exact versus tolerant gamut tests

Floating-point conversion can produce tiny excursions such as:

```text
-1e-15
1 + 2e-15
```

for colors that are mathematically on the gamut boundary.

This creates two distinct concepts:

```text
strict mathematical membership
```

and:

```text
numerically tolerant membership
```

These should not be silently conflated.

Possible semantics:

```d
inGamut(color)
inGamut(color, epsilon)
```

or separate internal helpers.

The experiment should test both.

No universal tolerance should be frozen before evidence is collected.

---

## 9. Epsilon is policy, not gamut geometry

An epsilon does not enlarge the physical gamut.

It only changes how floating-point error near the boundary is classified.

Therefore:

```text
epsilon
```

belongs to numerical policy.

The underlying target RGB gamut remains:

```text
[0,1]^3
```

for SDR sRGB.

---

## 10. Non-finite coordinates

NaN and infinity require explicit treatment.

A target-space coordinate that is:

```text
NaN
+Inf
-Inf
```

should not be classified as in gamut.

The operation should not silently replace or clamp non-finite values.

This follows previous `color-d` research principles.

---

## 11. Clipping

Clipping is a lossy operation distinct from detection.

For an sRGB target it means:

```text
convert to target RGB
then clamp each bounded RGB coordinate to [0,1]
```

Conceptually:

```text
R = clamp(R, 0, 1)
G = clamp(G, 0, 1)
B = clamp(B, 0, 1)
```

Alpha remains unchanged.

---

## 12. Clipping is target-space specific

A generic operation such as:

```d
clip(Oklab)
```

would be ambiguous.

Clamping Oklab component reference ranges does not mean clipping to sRGB.

Therefore the useful semantic operation is:

```text
clip to a bounded destination gamut
```

not:

```text
clamp every color struct according to arbitrary coordinate ranges
```

Component-range clamping and gamut clipping are related but not universally identical concepts.

---

## 13. Clipping is not gamut mapping

Clipping can produce large changes in:

```text
hue
chroma
lightness
```

because RGB channels independently hit cube boundaries.

This may be acceptable when:

- speed is critical;
- the excursion is tiny;
- the caller explicitly chooses clipping.

But clipping should not be named or described as perceptual gamut mapping.

The operations must remain visibly different.

---

## 14. Conversion is not clipping

This must remain valid:

```d
auto rgb = color.toSRgb;
```

even when the result contains:

```text
R < 0
G > 1
```

Ordinary conversion should preserve the mathematical color.

Explicit operations may then be applied:

```d
rgb.inGamut
rgb.clip
```

or equivalent target-oriented APIs.

This preserves round-tripping and intermediate precision.

---

## 15. Gamut mapping

Gamut mapping finds an in-gamut replacement for an out-of-gamut color while attempting to preserve visual appearance.

Unlike clipping, it is explicitly perceptual and policy-driven.

A mapping operation therefore requires:

```text
origin color
destination gamut
mapping algorithm
```

Conceptually:

```d
gamutMap(color, target, method)
```

No mapping algorithm should become hidden inside ordinary conversion.

---

## 16. Current CSS Color 4 model

The current CSS Color Module Level 4 defines three allowed SDR RGB gamut-mapping algorithms:

```text
Binary Search Gamut Mapping with Local MINDE
EdgeSeeker Gamut Mapping
Ray Trace Gamut Mapping
```

Implementations may choose among them based on:

```text
quality
runtime
memory
```

All three implement a relative-colorimetric style policy for individual colors:

```text
in-gamut colors remain unchanged
out-of-gamut colors are mapped
```

They aim to reduce chroma while approximately preserving:

```text
OKLCH lightness
OKLCH hue
```

---

## 17. Lightness extremes

The CSS model gives special treatment to OKLCH lightness outside the normal SDR range.

If:

```text
L >= 1
```

mapping returns destination white.

If:

```text
L <= 0
```

mapping returns destination black.

This should be explicitly tested rather than emerging accidentally from RGB clipping.

---

## 18. Binary Search with Local MINDE

The Local-MINDE algorithm operates through OKLCH chroma reduction.

Conceptually:

```text
preserve L
preserve h
reduce C
```

while repeatedly checking the destination RGB gamut.

The algorithm also compares the current candidate against a channel-clipped version using:

```text
deltaEOK
```

A sufficiently small difference permits returning the clipped candidate before chroma reduction reaches the exact geometric gamut boundary.

Current CSS parameters include approximately:

```text
JND     = 0.02 deltaEOK
epsilon = 0.0001
```

for the standardized algorithm.

---

## 19. Why Local MINDE exists

Pure constant-L/H chroma reduction can over-desaturate some colors near irregular or concave gamut boundaries.

The clipped candidate may already be visually indistinguishable from an exactly in-gamut chroma-reduced value.

Local MINDE therefore combines:

```text
perceptual chroma reduction
+
small clipped correction
```

to avoid unnecessary chroma loss.

---

## 20. Local MINDE advantages

Potential advantages:

```text
well documented
simple conceptual model
reference implementations available
good perceptual behavior
natural deltaEOK integration
no lookup table
```

It is also a useful reference oracle because the binary search is straightforward to implement and reason about.

---

## 21. Local MINDE disadvantages

Potential disadvantages:

```text
iterative search
variable execution count
multiple color-space conversions
repeated deltaEOK calculations
less predictable runtime
```

This matters for:

- interactive editor use;
- generated palettes;
- large batches of colors.

For single theme colors it may be irrelevant.

---

## 22. EdgeSeeker

EdgeSeeker models each hue slice of the RGB gamut boundary.

It uses a lookup table containing high-chroma boundary information and interpolates between table entries.

Potential advantages:

```text
fast mapping after initialization
good perceptual behavior
explicit gamut-boundary model
```

Potential costs:

```text
LUT memory
LUT construction
additional retained data
more complex implementation
```

---

## 23. EdgeSeeker and color-d

EdgeSeeker should be documented because it is now one of the CSS Color 4 algorithms.

However it is not the preferred first R0.8 implementation.

Reasons:

- `color-d` currently has no demonstrated need for a retained gamut LUT;
- the first target is only sRGB;
- the initial experiment should isolate algorithmic semantics before introducing table-generation architecture;
- CTFE LUT generation would itself become a separate performance/design question.

EdgeSeeker should therefore remain deferred unless later benchmarking demonstrates a compelling need.

---

## 24. Ray Trace gamut mapping

Ray Trace converts the constant-lightness/hue chroma-reduction problem into geometry in linear target RGB.

The target RGB gamut becomes an axis-aligned cube:

```text
[0,1]^3
```

The algorithm constructs an achromatic anchor at the original OKLCH lightness and casts a ray toward the out-of-gamut color.

The first cube intersection approximates the gamut boundary.

Because a constant-L/H path in perceptual space is curved in RGB coordinates, the result is projected back to the original OKLCH lightness/hue path and iterated.

Current CSS pseudocode uses a bounded number of iterations.

---

## 25. Ray Trace advantages

Potential advantages:

```text
bounded iteration count
predictable runtime
no persistent LUT
geometric target-space test
good perceptual results
```

The current CSS description states that quality is comparable to Local MINDE at a low JND while resolving faster and in more predictable time.

These characteristics remain attractive for `color-d`.

---

## 26. Ray Trace disadvantages

Potential disadvantages:

```text
more geometric implementation complexity
requires careful ray/cube intersection
multiple target RGB <-> OKLCH conversions
final clipping still needed for FP correction
more opportunities for subtle implementation error
```

Therefore it should be experimentally compared with the simpler Local-MINDE reference rather than adopted based only on theoretical appeal.

---

## 27. Revised R0.8 algorithm direction

The previous technical specification described Ray Trace as the preferred research candidate.

R0.8 revises that into a comparison hypothesis:

```text
Local MINDE:
    reference / correctness-oriented candidate

Ray Trace:
    bounded-runtime candidate

EdgeSeeker:
    documented but deferred
```

The experiment should determine whether Ray Trace offers sufficiently close perceptual results with materially more predictable work.

No algorithm is selected before measurement.

---

## 28. deltaEOK dependency

Local MINDE requires:

```text
deltaEOK
```

R0 currently lists `deltaEOK` as a separate remaining research item.

R0.8 therefore creates a dependency.

For Oklab:

```text
deltaEOK =
sqrt(
    ΔL² +
    Δa² +
    Δb²
)
```

The experiment may implement an experiment-local `deltaEOK` primitive.

If validated against trusted vectors, R0.8 may provide evidence toward the later `deltaEOK` gate.

However R0.8 should not automatically claim that the full public delta-E API is finalized.

---

## 29. Gamut mapping target

The first experiment should map:

```text
OKLCH / Oklab / extended sRGB
        ↓
sRGB gamut
```

There is no need to introduce Display-P3 production types solely to test gamut semantics.

Known wide-gamut examples may still be represented as their equivalent OKLCH values.

---

## 30. Useful reference case

CSS documentation gives a saturated yellow example approximately equivalent to:

```text
Oklch(
    L = 0.96476,
    C = 0.24503,
    h = 110.23°
)
```

which lies outside sRGB.

A chroma-reduced mapped form is approximately:

```text
L = 0.96476
C ≈ 0.21094
h = 110.23°
```

for the illustrated mapping path.

R0.8 should include this or an equivalent standardized reference case.

Exact outputs may differ among the three allowed CSS algorithms.

Therefore comparison should include both:

```text
numerical result
perceptual difference
```

rather than assuming all methods are bit-identical.

---

## 31. Mapping invariants

All candidate mapping algorithms should satisfy core invariants.

For an in-gamut input:

```text
map(color) == color
```

within conversion tolerance.

For an out-of-gamut input:

```text
inGamut(map(color)) == true
```

The mapping should not silently modify alpha.

For normal chroma-reduction cases:

```text
mapped chroma <= original chroma
```

should generally hold.

---

## 32. Hue and lightness preservation

The candidate CSS methods aim at constant:

```text
OKLCH L
OKLCH h
```

during chroma reduction.

However the final clipped correction can produce small deviations.

Therefore tests should distinguish:

```text
algorithmic target
```

from:

```text
exact bit-level invariance
```

The experiment should report actual:

```text
ΔL
Δh
deltaEOK
```

rather than simply asserting exact equality after the full mapping process.

---

## 33. Mapping already in-gamut colors

Relative-colorimetric mapping for individual colors should leave in-gamut colors unchanged.

This is important for generated themes and gradients because unnecessary modification would make mapping non-idempotent or distort already-valid colors.

Test:

```text
gamutMap(inGamutColor)
```

should return the original color modulo ordinary numerical round-trip tolerance.

---

## 34. Idempotence

A desirable property is:

```text
map(map(color)) ≈ map(color)
```

Once a color has been mapped into the target gamut, mapping it again should not materially change it.

R0.8 should test this property.

---

## 35. Clipping idempotence

Clipping should satisfy:

```text
clip(clip(color)) == clip(color)
```

for finite target RGB values.

This can normally be tested exactly.

---

## 36. Detection after clipping

For finite target RGB values:

```text
inGamut(clip(color)) == true
```

should always hold.

This is a basic correctness invariant.

---

## 37. Detection after mapping

Likewise:

```text
inGamut(gamutMap(color)) == true
```

must hold.

If floating-point error produces tiny excursions, the mapping implementation may use final explicit clipping as part of its documented algorithm.

---

## 38. Alpha semantics

Alpha is not part of RGB gamut membership.

Therefore:

```text
Alpha!Color
```

should preserve alpha unchanged through:

```text
clip
gamutMap
```

provided alpha itself is finite/valid according to the separate alpha policy.

Gamut operations act on color coordinates, not coverage.

---

## 39. Straight versus premultiplied alpha

Color management and gamut mapping should conceptually operate on unassociated color.

A premultiplied compositing representation must therefore not be interpreted directly as ordinary RGB coordinates for gamut mapping.

The conceptual pipeline is:

```text
premultiplied input
        ↓
unpremultiply
        ↓
color conversion / gamut operation
        ↓
premultiply if required
```

This agrees with the boundary established in R0.6.

---

## 40. color-d versus imagery-d boundary

This distinction becomes especially important for `imagery-d`.

`color-d` should own general per-color mathematics such as:

```text
target-gamut detection
channel clipping
individual-color gamut mapping
Local MINDE
Ray Trace
deltaEOK support
```

`imagery-d` should own image-domain behavior such as:

```text
applying those operations over raster regions
pixel/channel binding
image metadata
streaming and tiling
image-wide rendering intent
preservation of relationships between neighboring pixels
```

---

## 41. Individual colors versus photographic imagery

CSS Color 4 explicitly distinguishes its individual-color gamut mapping from perceptual rendering of photographic images.

For photographs and imagery, preserving:

```text
detail
texture
relationships between neighboring pixels
```

may require changing even colors that were individually in gamut.

That is not the same problem as:

```text
map this one color into sRGB
```

Therefore R0.8 must not claim that a per-color CSS gamut mapper is a complete photographic gamut-mapping solution for `imagery-d`.

---

## 42. Consequence for dependency boundary

The shared boundary should therefore be:

```text
color-d:
    scalar color mathematics

imagery-d:
    image-domain application and image-global rendering intent
```

`imagery-d` should not reimplement scalar Local-MINDE or Ray Trace math.

`color-d` should not acquire tile/image-neighborhood semantics merely because perceptual image gamut compression exists.

---

## 43. CTFE

R0.8 should test compile-time execution where feasible.

This matters for:

```text
built-in themes
static palettes
tone scales
compile-time validation
```

Detection and clipping should clearly be CTFE-friendly.

Local MINDE should also be tested under CTFE.

Ray Trace should be tested if all required mathematical operations remain compatible with current D CTFE.

---

## 44. Function attributes

Core candidates should target:

```d
@safe
pure
nothrow
@nogc
```

where feasible.

No gamut operation should allocate merely to map one scalar color.

EdgeSeeker is different because a LUT introduces retained data, but that method is deferred from the first experiment.

---

## 45. float and double

R0.8 should test:

```text
float
double
```

The algorithms may need different numerical tolerances.

One universal epsilon should not automatically be imposed across:

```text
in-gamut detection
binary-search termination
ray intersection
deltaEOK comparison
```

Each tolerance should have a documented purpose.

---

## 46. Performance questions

R0.8 should measure at least rough operation counts or benchmark representative batches.

Important comparisons:

```text
clip
Local MINDE
Ray Trace
```

Expected ordering:

```text
clip:
    cheapest

Local MINDE:
    iterative / variable

Ray Trace:
    bounded iterative
```

The experiment should verify rather than assume the magnitude of these differences.

---

## 47. No premature SIMD design

Gamut mapping may eventually be used over large color arrays or imagery.

However R0.8 should first establish scalar correctness.

SIMD/batch APIs should only be considered after:

```text
algorithm selected
scalar semantics stable
consumer hot path demonstrated
```

---

## 48. Candidate API concepts

Names remain provisional.

Detection:

```d
inSrgbGamut(color)
```

or later:

```d
inGamut(color, target)
```

Clipping:

```d
clipToSrgb(color)
```

or later:

```d
clip(color, target)
```

Mapping:

```d
gamutMapToSrgb(color, method)
```

or later:

```d
gamutMap(color, target, method)
```

Possible policy:

```d
enum GamutMapMethod
{
    localMinde,
    rayTrace
}
```

`clip` should probably remain a separate operation rather than an enum variant of perceptual gamut mapping.

---

## 49. Why clip should probably not be a GamutMapMethod

Treating:

```text
clip
```

as just another perceptual mapping algorithm hides an important semantic distinction.

Clipping is:

```text
coordinate saturation
```

while Local MINDE and Ray Trace are:

```text
perceptual gamut mapping
```

A clearer API likely keeps:

```d
clip(...)
```

separate from:

```d
gamutMap(...)
```

R0.8 should test ergonomics before freezing this.

---

## 50. Experiment scope

Create:

```text
experiments/r0_8_gamut_semantics/
```

The initial spike should contain:

```text
dub.sdl
README.md
source/app.d
```

`RESULTS.md` is written only after observed DMD and LDC runs.

---

## 51. Experiment components

The experiment should implement enough local structure to test:

```text
SRgb
LinearSRgb
Oklab
Oklch
conversion chain
deltaEOK
```

Then:

```text
strict sRGB gamut test
epsilon-aware sRGB gamut test
sRGB clipping
Local-MINDE mapping
Ray Trace mapping
```

EdgeSeeker should not be implemented in the first spike.

---

## 52. Detection vectors

Test at minimum:

```text
(0,0,0)
(1,1,1)
(1,0,0)
(-0.01,0.5,0.5)
(1.01,0.5,0.5)
(-1e-15,0.5,0.5)
(1+1e-15,0.5,0.5)
NaN
+Inf
-Inf
```

Compare strict and epsilon-aware classification.

---

## 53. Encoded/linear equivalence tests

Take equivalent sRGB colors and verify that:

```text
inSrgbGamut(encoded)
==
inSrgbGamut(linearized)
```

for finite values around:

```text
black
white
primaries
ordinary colors
boundary cases
```

---

## 54. Clipping vectors

Test:

```text
(-0.2, 0.4, 1.3)
```

Expected target-space clipping:

```text
(0, 0.4, 1)
```

Verify:

```text
idempotence
in-gamut result
alpha unchanged
```

---

## 55. Mapping vectors

Use several classes:

```text
slightly out of gamut
strongly out of gamut
high-chroma yellow
high-chroma red
high-chroma green
high-chroma blue
near black
near white
already in gamut
```

Include at least one published CSS/Color.js reference vector.

---

## 56. Compare Local MINDE and Ray Trace

For every mapping vector record:

```text
input OKLCH
input target RGB
mapped target RGB
mapped OKLCH
deltaEOK from origin
ΔL
ΔC
Δh
iterations / conversion count where practical
```

The two algorithms need not produce identical outputs.

The experiment should instead establish:

```text
both in gamut
both stable
both perceptually reasonable
runtime characteristics understood
```

---

## 57. Mapping properties

Test:

```text
in-gamut identity
output in target gamut
idempotence
alpha preservation
finite output for finite input
black/white lightness rules
```

Test both algorithms independently.

---

## 58. Numerical failure policy

R0.8 must deliberately test difficult inputs.

Questions include:

- what if conversion yields NaN?
- what if the ray intersection cannot be found?
- what if Local MINDE hits an iteration bound?
- what if floating-point rounding leaves a tiny target RGB excursion?

The experiment should avoid silently inventing a production error policy.

Instead it should record what cases arise and what explicit handling appears necessary.

---

## 59. Strong hypotheses entering the spike

R0.8 should test these hypotheses:

1. Gamut membership is target-dependent.
2. Ordinary conversion remains unclipped and unmapped.
3. sRGB and linear-sRGB have the same bounded gamut.
4. sRGB gamut membership is determined in target RGB coordinates.
5. Alpha does not affect gamut membership.
6. Non-finite target coordinates are not in gamut.
7. Strict and epsilon-aware membership are distinct useful concepts.
8. Clipping is component-wise in the bounded target RGB space.
9. Clipping is distinct from perceptual gamut mapping.
10. `clip` should probably remain a separate API from `gamutMap`.
11. Perceptual mapping should leave already in-gamut colors unchanged.
12. CSS-style mapping should preserve lightness/hue as closely as its algorithm permits while reducing chroma.
13. Local MINDE is a useful reference implementation.
14. Ray Trace is a strong bounded-runtime candidate.
15. EdgeSeeker is not needed in the first experiment.
16. Local MINDE requires an experiment-local `deltaEOK`.
17. Mapped output must be in gamut.
18. Mapping should be approximately idempotent.
19. Alpha should be preserved.
20. Per-color CSS gamut mapping is not a complete photographic-image rendering intent.
21. Image-global perceptual mapping remains an `imagery-d` concern.
22. Core scalar gamut math should target CTFE and `@safe pure nothrow @nogc`.

---

## 60. Questions deliberately deferred

R0.8 does not yet decide:

```text
Display-P3 public types
Rec.2020
HDR gamut mapping
ICC intents
printer gamut mapping
black-point compensation
image-global perceptual rendering intent
EdgeSeeker LUT architecture
GPU mapping
SIMD batch mapping
3D LUT generation
tone mapping
HDR -> SDR rendering
```

These require concrete later consumers or separate research.

---

## 61. Source register

Primary research references:

1. **W3C CSS Color Module Level 4**
   - Candidate Recommendation Draft, September 2026;
   - gamut terminology;
   - bounded RGB gamut behavior;
   - Local-MINDE;
   - EdgeSeeker;
   - Ray Trace;
   - relative-colorimetric individual-color behavior;
   - image/perceptual rendering-intent distinction.

2. **Color.js**
   - `inGamut`;
   - `toGamut`;
   - clipping versus CSS mapping;
   - current Ray Trace implementation;
   - epsilon support;
   - practical gamut-boundary research.

3. **Rust palette**
   - distinction between component clamping and true display-gamut membership;
   - unclamped conversion;
   - expensive perceptual mapping versus cheap clipping.

4. **palette-gamut-mapping**
   - independent Rust implementation of CSS Local-MINDE-style gamut mapping.

5. **Skia color management**
   - unpremultiply before color transformation;
   - color transforms independent of alpha;
   - repremultiply afterward when required.

6. Existing `color-d` research:
   - R0.1 through R0.7;
   - `docs/spec/TECHNICAL_SPEC.md`;
   - alpha/compositing boundary;
   - interpolation boundary;
   - extended-range policy.

---

## 62. Conclusion

R0.8 should formalize a three-layer model:

```text
inGamut
    diagnostic, non-mutating

clip
    explicit target-RGB coordinate clipping

gamutMap
    explicit perceptual target-gamut mapping
```

Ordinary conversion remains separate from all three.

For the first bounded target:

```text
sRGB
```

the experiment should compare:

```text
Local MINDE
vs
Ray Trace
```

while treating:

```text
EdgeSeeker
```

as a documented deferred alternative.

The current architectural preference is not yet an algorithm choice.

The experiment must determine whether Ray Trace's bounded runtime and lack of LUT justify selecting it over Local MINDE for the initial `color-d` gamut mapper.

Finally, R0.8 establishes an important workspace boundary:

> `color-d` owns scalar color gamut mathematics; `imagery-d` owns image-domain application and any image-global perceptual rendering intent that depends on relationships between pixels.

No public API is frozen until the experiment validates these hypotheses.
