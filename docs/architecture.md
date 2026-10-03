# Architecture

## Responsibility

`color-d` owns general color-value mathematics. It does not own image layout,
GUI theme roles, OSM semantics, renderer policy, GPU ABI, or image-wide
rendering intent.

Dependency direction is intentionally outward:

```text
color-d
   ↑
imagery-d

color-d
   ↑
theme/style layer
   ↑
OSM editor
```

## Public module surface

The supported root import is:

```d
import color;
```

Supported direct modules are:

```text
color.storage
color.rgb
color.xyz
color.cielab
color.oklab
color.oklch
color.alpha
color.composite
color.interpolate
color.gamut
color.wcag
color.difference
color.tone
color.cvd
```

Technical importability of an implementation helper does not make it public
contract.

## Storage and computation

Compact storage and floating-point computation are distinct public concepts.

`color.storage` owns bounded encoded-sRGB storage such as `SRgb8` and
straight-alpha `SRgba8`. Computational color mathematics remains in the floating-point color-space
types such as `SRgb!T` and `LinearSRgb!T`. Storage types do not implicitly
convert to computational types.

The explicit storage boundary follows ADR 0006: byte-to-computation
normalization uses the full 0...255 range, while computation-to-storage is a
checked conversion with deterministic nearest-byte quantization. It does not
silently clip extended values or repair NaN/infinity.

Compact textual interchange follows ADR 0007 and is intentionally narrower
than CSS Color syntax: `SRgb8` serializes/parses exact `#RRGGBB` and
`SRgba8` exact `#RRGGBBAA`; shorthand and functional forms are not part of
the storage boundary.

## Value-oriented core

The public core uses small value types, explicit conversions, no hidden
allocation, and caller-owned storage for runtime-sized tone batches. The
library owns no worker threads or global scheduler.

## Policy boundaries

Conversions do not imply clipping or gamut mapping. Interpolation does not
select another space. WCAG measurement does not decide application
accessibility thresholds. Tone primitives do not assign semantic palette roles.

These boundaries are part of the maintained library architecture. Detailed
promotion and consumer-boundary evidence is maintainer material in the
production repository, not a prerequisite for using the package.
