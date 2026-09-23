# R0.8 — Gamut Semantics Results

Date: 2026-09-23

Status: **PASS**

## Research question

R0.8 investigated how `color-d` should represent and separate:

- gamut membership;
- numerical tolerance around gamut boundaries;
- target-space clipping;
- perceptual gamut mapping;
- mapping method selection;
- scalar and performance implications.

The first concrete target gamut is sRGB.

This experiment does not freeze the public API.

## Result summary

R0.8 validates a three-way semantic separation:

```text
inGamut
    diagnostic membership query

clip
    target-coordinate saturation

gamutMap
    explicit perceptual transformation
```

These operations are not interchangeable and should not be hidden inside
ordinary color-space conversion.

## Gamut membership

For the initial sRGB target:

```text
0 <= r <= 1
0 <= g <= 1
0 <= b <= 1
```

defines strict target membership in both encoded sRGB and linear-sRGB
coordinates.

Observed tests confirm:

```text
black:             in gamut
white:             in gamut
negative channel:  out of gamut
channel > 1:       out of gamut
NaN:               out of gamut
+Inf:              out of gamut
-Inf:              out of gamut
```

Strict membership and epsilon-aware numerical membership remain distinct
operations.

An epsilon is a numerical-policy tool; it does not redefine gamut geometry.

## Clipping

Target-space clipping is explicitly separate from both conversion and
perceptual mapping.

Observed example:

```text
(-0.2, 0.4, 1.3)
    ->
(0.0, 0.4, 1.0)
```

Clipping is idempotent in the experiment.

Ordinary color conversion must not silently clip or gamut-map extended values.

## Non-finite values

NaN and infinity are not repaired silently.

They are outside the target gamut for membership queries.

This preserves the broader `color-d` rule that invalid numerical state is not
silently converted into apparently valid color data.

## Perceptual mapping candidates

R0.8 implemented and exercised two current SDR sRGB mapping candidates:

- Local MINDE;
- Ray Trace.

EdgeSeeker remains deferred.

Both tested algorithms:

- leave already-in-gamut colors on the fast path;
- produce in-gamut mapped output for the tested out-of-gamut cases;
- preserve alpha in the experiment;
- support both `float` and `double`.

## Reference mapping cases

Representative observed `double` results:

| Input | Local iterations | Ray iterations | Local deltaEOK | Ray deltaEOK |
| --- | ---: | ---: | ---: | ---: |
| published yellow | 11 | 4 | 0.0340909 | 0.0340899 |
| high-chroma red | 10 | 4 | 0.0980344 | 0.114125 |
| high-chroma green | 10 | 4 | 0.0930892 | 0.114112 |
| high-chroma blue | 12 | 4 | 0.0944179 | 0.101787 |
| near white | 9 | 4 | 0.127061 | 0.134637 |
| near black | 8 | 4 | 0.0702545 | 0.0772967 |

The experiment demonstrates different mapping behavior. It does not claim
that the smaller deltaEOK value is universally the perceptually preferable
result.

## Alpha

Mapping is a color transformation, not an alpha transformation.

Observed:

```text
input alpha: 0.37
Local alpha: 0.37
Ray alpha:   0.37
```

Alpha preservation therefore remains part of the mapping contract.

## Fast-path semantics

A separate 4096-color in-gamut dataset produced:

```text
failures:             0
non-zero iterations:  0
max deltaEOK:         1.13764e-15
```

Already valid target colors therefore do not enter the expensive iterative
mapping process.

This is an important semantic and performance property.

## Optimized implementation candidates

Two implementation-level optimizations were compared against their respective
reference algorithms over 4096 out-of-gamut colors.

Observed:

```text
Local cached-hue max deltaEOK: 0
Local failures:                0

Ray no-atan2 max deltaEOK:     0
Ray failures:                  0
```

For the tested dataset, these optimizations preserve the exact numerical
result of their reference variants.

### Local MINDE

Caching hue trigonometry materially reduces repeated work.

### Ray Trace

The projection step can retain original lightness and hue direction while
recovering chroma from Oklab with:

```text
C = sqrt(a*a + b*b)
```

This removes repeated `atan2` from the iterative Ray Trace path.

## Scalar policy

Paired `float` and `double` benchmarks show that `float` is faster for some
conversion and Ray Trace operations but provides effectively no advantage for
Local MINDE on the tested system.

R0.8 therefore reinforces the existing scalar policy:

```text
public mathematical types remain generic over float and double
```

No implicit library-wide scalar choice is justified.

## Performance result

On the tested LDC/x86-64 system, Ray Trace performs substantially less
dynamic work than Local MINDE.

Before intersection inlining, representative `double` hardware-counter
results were:

```text
Local MINDE:
    ~11837 cycles/color
    ~10329 instructions/color
    ~1223 branches/color

Ray Trace:
    ~4255 cycles/color
    ~3739 instructions/color
    ~405 branches/color
```

IPC was similar.

The main performance advantage therefore comes from doing less work, rather
than from unusually favorable CPU execution characteristics.

## Generated-code result

LDC emits a sensible bounded Ray Trace structure:

- first intersection peeled;
- remaining iterations represented by a small loop;
- no `atan2` in the optimized Ray kernel.

Manual loop unrolling is not supported by the observed evidence.

`intersectUnitRgbCube` was initially emitted as a separate call and generated
visible struct/ABI traffic.

An isolated:

```d
pragma(inline, true)
```

experiment removed those calls and improved Ray Trace further.

For `double` the observed hardware-counter change was approximately:

```text
cycles/color:
    4255 -> 3790

instructions/color:
    3739 -> 3558

IPC:
    0.879 -> 0.939
```

This is sufficient evidence to retain explicit inlining of the intersection
helper as an implementation candidate.

Full benchmark evidence is recorded in:

```text
benchmark/RESULTS.md
```

## Algorithm-policy conclusion

R0.8 does not collapse perceptual gamut mapping to a single universal
algorithm.

Instead:

### Local MINDE

Retain as a standards-oriented / perceptual reference candidate.

Properties observed in R0.8:

- adaptive iteration count;
- higher dynamic cost;
- useful comparison/reference behavior.

### Ray Trace

Retain as the performance-oriented bounded-cost candidate.

Properties observed in R0.8:

- fixed small iteration budget;
- substantially fewer instructions and branches;
- good optimization opportunities;
- stable `float` and `double` implementation.

The measurements support Ray Trace strongly for hot-path-sensitive consumers,
but a public default mapping policy should not be frozen before consumer
evidence exists.

## API direction

R0.8 supports an API direction equivalent to:

```d
bool inSrgbGamut(Color value);

bool inSrgbGamut(
    Color value,
    NumericalTolerance tolerance);

Color clipToSrgb(Color value);

enum GamutMapMethod
{
    localMinde,
    rayTrace
}

Color gamutMapToSrgb(
    Color value,
    GamutMapMethod method);
```

Names remain provisional.

Important semantic constraints:

- target gamut is explicit;
- conversion does not imply clipping;
- conversion does not imply mapping;
- strict and tolerant membership remain distinguishable;
- non-finite values are not repaired;
- in-gamut values take the identity/fast path;
- alpha is preserved;
- mapping method is explicit where policy matters.

## Scope boundary

`color-d` owns scalar color-space gamut mathematics.

It does not own:

- image-wide rendering intent;
- raster traversal;
- spatial adaptation across an image;
- channel layout;
- NoData/mask semantics;
- profile metadata;
- GUI style policy.

Those remain consumer responsibilities, primarily in `imagery-d` or later
style/theme layers.

## Deferred work

R0.8 deliberately does not add:

- EdgeSeeker implementation;
- generic arbitrary-device gamut abstractions;
- Display-P3 or Rec.2020 gamut mapping;
- HDR mapping;
- image-wide perceptual rendering;
- SIMD/batch mapping;
- GPU implementation;
- direct Linear-sRGB <-> Oklab production shortcuts.

Any of those require separate consumer or research justification.

## R0 impact

R0.8 closes the research questions for:

- initial sRGB gamut detection semantics;
- strict versus tolerant membership separation;
- explicit clipping semantics;
- initial perceptual mapping candidates;
- in-gamut fast-path behavior;
- basic gamut-mapping performance inspection;
- basic generated-code inspection.

It also produces implementation evidence for the future R1 mathematical core.

R0.8 does not by itself close the remaining independent research topics such
as luminance/contrast, full deltaEOK policy, tone-scale semantics, palette
generation, or the library-wide numerical-tolerance policy.

## Final result

**PASS**

The validated architecture is:

```text
explicit target gamut
        |
        +-- diagnostic membership
        |
        +-- explicit clipping
        |
        +-- explicit perceptual mapping
                |
                +-- Local MINDE
                |
                +-- Ray Trace
```

Ray Trace is the stronger bounded-cost / hot-path candidate on the measured
system.

Local MINDE remains a distinct perceptual/reference candidate.

No public default is frozen by R0.8.
