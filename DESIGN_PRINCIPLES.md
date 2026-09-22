# color-d Design Principles

## 1. Make color-space semantics explicit

A color's color space is part of its type.

Semantically different values must not become interchangeable merely because
they share the same physical component layout.

## 2. Prefer explicit conversion

Color-space transitions must remain visible in source code.

Prefer:

    auto linear = rgb.toLinear;
    auto lab = rgb.toOklab;

over implicit conversion or generic casts.

## 3. Separate storage from computation

Packed integer formats and mathematical floating-point formats serve
different purposes and should use different types.

## 4. Preserve valid intermediate values

Floating-point computational colors are not automatically clamped.

Out-of-gamut values may be necessary for correct transformations and
round trips.

Clipping and gamut mapping are explicit operations.

## 5. Distinguish encoded and linear-light RGB

Operations such as compositing and luminance must use the mathematically
appropriate representation.

Encoded sRGB and linear-light sRGB are distinct types.

## 6. Use perceptual spaces intentionally

Oklab and OKLCH are the primary perceptual spaces for interpolation,
tone generation, palette construction, and related operations.

HSL and HSV remain interoperability and user-interface utility spaces.

## 7. Keep alpha semantics explicit

Straight and premultiplied alpha must not be silently interchangeable.

Correct compositing is a core mathematical concern.

## 8. Keep primitives small and orthogonal

Prefer narrowly defined operations that compose well.

Avoid application semantics such as GUI roles, OSM classifications, or
theme token names in the core library.

## 9. Design for D

Prefer:

- value types;
- predictable layouts;
- generic floating-point scalars where useful;
- UFCS-friendly APIs;
- `@safe`;
- `pure`;
- `nothrow`;
- `@nogc`;
- allocation-free core operations.

Use these attributes where they are technically and semantically appropriate,
not merely decoratively.

## 10. Treat CTFE as a supported execution mode

Deterministic core mathematics should work both at runtime and during CTFE
where technically possible.

Compile-time theme and palette generation is a concrete consumer requirement,
not an incidental optimization.

## 11. Validate against independent references

Implementations must be tested against standards, published reference vectors,
and independent implementations.

Do not rely solely on round-trip tests.

## 12. Optimize after semantics are correct

Data layout and hot-path performance matter, but correctness and explicit
semantics come first.

Measure before introducing specialized fast paths.

## 13. Do not grow without a reason

New color spaces and algorithms enter the library only when they are:

- fundamental to correct color mathematics;
- required by a concrete consumer;
- required for standards interoperability; or
- necessary to maintain architectural consistency.
