# Color model

## Color space is part of the type

The central color-d design rule is that materially different color spaces are
not interchangeable just because they contain three floating-point components.

The current computational value types are:

- `SRgb!T` — encoded nonlinear sRGB;
- `LinearSRgb!T` — linear-light sRGB;
- `XyzD65!T` — CIE XYZ with D65 reference white;
- `Oklab!T` — rectangular perceptual coordinates;
- `Oklch!T` — cylindrical Oklab coordinates.

The public scalar contract is `float` or `double`. `real` is deliberately
not part of the initial contract because its precision is platform-dependent.

## Conversions are explicit

A conversion is a visible operation, not an implicit constructor or generic
cast. This keeps encoded/linear distinctions and policy boundaries reviewable.

## Mathematical values are not display storage

Floating-point computational colors may legitimately contain values outside
nominal display intervals. Packed pixel formats, image layout, channel order,
and renderer/GPU ABI are different concerns.

## OKLCH hue is raw

`OklabHue!T` stores degrees without automatic normalization. Normalized views
are explicit. This permits interpolation paths and complete revolutions to
remain representable while a color stays in polar form.

## Alpha is orthogonal

`Alpha!Color` wraps supported computational colors. Premultiplied alpha is a
separate representation and is restricted to the linear-light sRGB
compositing boundary.

The accepted design is summarized in
[`research/R0_14_PROMOTION_GATE.md`](../research/R0_14_PROMOTION_GATE.md).
