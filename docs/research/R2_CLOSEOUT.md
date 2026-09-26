# R2 — Alpha and Interpolation Production API Closeout

Date: 2026-09-26

Status: **PASS / COMPLETE**

Tracked by GitHub issue #11.

## Scope completed

R2 promoted the accepted R0.6/R0.7 alpha, compositing and interpolation
semantics into the production API:

- generic straight-alpha `Alpha!Color` representation;
- statically distinct `Premultiplied!(LinearSRgb!T)` representation;
- explicit `premultiply` / `unpremultiply`;
- premultiplied linear-light `sourceOver`;
- same-space rectangular interpolation for encoded `SRgb`,
  linear-light `LinearSRgb`, and rectangular perceptual `Oklab`;
- explicit polar `Oklch` interpolation;
- public `HuePath` with `shorter`, `longer`, `increasing`, and `decreasing`;
- alpha-aware interpolation for the validated rectangular and polar spaces.

The production work was merged through PRs #27–#32.

## Alpha representation and compositing boundary

Straight and premultiplied alpha remain distinct static states.

`Alpha!Color` is the generic straight-alpha attachment for the supported
computational color types.

Persistent compositing premultiplication is deliberately narrower:

```d
Premultiplied!(LinearSRgb!T)
```

The public `premultiply` / `unpremultiply` transition therefore applies only to
linear-light sRGB.

`sourceOver` operates only on premultiplied linear-light sRGB. It does not
silently accept straight alpha, encoded sRGB, Oklab, OKLCH, or another color
space as though it were a compositing representation.

Zero-alpha premultiplication loses hidden straight RGB by construction.
`unpremultiply` returns canonical transparent black at zero alpha rather than
attempting to reconstruct information that no longer exists.

No alpha operation silently clamps alpha, clips RGB, gamut-maps, converts color
spaces, or infers a background.

## Interpolation boundary

Low-level interpolation remains explicitly same-space.

The accepted rectangular production set is:

```text
SRgb
LinearSRgb
Oklab
```

`XyzD65` is not promoted as a v0.1 interpolation space because it was not part
of the validated R0.7 rectangular set.

No low-level interpolation operation silently converts between spaces.

The interpolation factor `t` is not clamped. Values outside `[0, 1]` therefore
perform mathematical extrapolation.

Extended computational values remain representable; interpolation does not
silently clip or gamut-map them.

## OKLCH polar semantics

OKLCH interpolation requires an explicit `HuePath`; there is no hidden default.

The production policies are:

```text
shorter
longer
increasing
decreasing
```

Negative-chroma endpoints are canonicalized before polar interpolation.

Exact achromaticity remains `C == 0`.

When exactly one endpoint is achromatic, its interpolation hue is borrowed from
the chromatic endpoint. No implicit near-achromatic epsilon is introduced.

When both endpoints are exactly achromatic, neither stored numeric hue is
discarded; the explicit hue path still determines the numeric interpolation
trajectory.

Interpolated hue remains raw/unbounded rather than being automatically wrapped
to `[0, 360)`.

Raw stored-hue interpolation was deliberately not promoted as an additional
public v0.1 `HuePath` policy.

## Alpha-aware interpolation

Alpha-aware interpolation uses interpolation-specific premultiplication.

This is an algorithmic interpolation step and is intentionally distinct from
the persistent `Premultiplied!(LinearSRgb!T)` compositing representation.

For rectangular interpolation, every interpolation coordinate is weighted by
endpoint alpha before interpolation.

For OKLCH:

```text
L   alpha-weighted
C   alpha-weighted
h   never alpha-weighted
```

Hue remains an independent angular coordinate governed by the explicit
`HuePath`.

When interpolated alpha is nonzero, the weighted non-hue coordinates are
divided by that alpha.

When interpolated alpha is exactly zero, division is skipped and the
interpolated weighted coordinates are retained.

Consequently hidden straight color is not generally preserved by alpha-aware
interpolation, and raw endpoint identity is not guaranteed for a fully
transparent endpoint even at `t == 0` or `t == 1`.

This zero-alpha rule is deliberately distinct from general compositing
`unpremultiply`.

## Type-safety verification

Production compile-negative tests verify, among other boundaries:

- straight and premultiplied states are not interchangeable;
- unsupported `Premultiplied!Color` instantiations are rejected;
- source-over does not accept straight alpha;
- source-over does not accept encoded sRGB as a premultiplied compositor input;
- mixed scalar types are rejected;
- interpolation does not silently cross color spaces;
- `XyzD65` interpolation is not part of the accepted v0.1 set;
- OKLCH interpolation requires explicit `HuePath`;
- alpha-aware OKLCH interpolation also requires explicit `HuePath`;
- persistent compositing-premultiplied values are not alpha-aware interpolation
  inputs.

## Integrated compiler verification

Closeout base commit:

```text
214ed84e90123cabefe998d55733420743bc6109
```

Reference compilers:

```text
DMD 2.113.0
LDC 1.43.0 / DMD frontend 2.113.0 / LLVM 22.1.8
```

The complete production library passed:

- DMD debug unittests;
- DMD release unittests;
- LDC debug unittests;
- LDC release unittests.

An external integrated R2 consumer also passed with:

- DMD debug direct imports;
- DMD release direct imports;
- LDC debug direct imports;
- LDC release direct imports;
- DMD debug root import;
- DMD release root import;
- LDC debug root import;
- LDC release root import.

The external probe exercised together:

- `Alpha`;
- `Premultiplied`;
- `premultiply`;
- `unpremultiply`;
- `sourceOver`;
- rectangular interpolation;
- OKLCH polar interpolation;
- `HuePath`;
- alpha-aware rectangular interpolation;
- alpha-aware OKLCH interpolation;
- integrated compile-negative API boundaries;
- CTFE execution across the R2 surface.

## Public import surface

R2 public modules are available directly through:

```d
import color.alpha;
import color.composite;
import color.interpolate;
```

The same public R2 API is also available through the curated root:

```d
import color;
```

No dependency on GUI frameworks, rendering engines, `imagery-d`, or another
consumer library was introduced.

## Exit result

All exit criteria listed in issue #11 are satisfied for the accepted R2 scope.

R2 is complete.

The API remains pre-1.0 and consumer-correctable through the planned R4
validation before v0.1 release stabilization.

Completion of R2 is not the v0.1 feature freeze. R3 perceptual utilities remain
part of the accepted v0.1 production scope.
