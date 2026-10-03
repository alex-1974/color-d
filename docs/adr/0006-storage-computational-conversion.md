# ADR 0006 — Checked normalized conversion between byte storage and encoded sRGB

**Status:** Accepted

## Context

v0.2.0 introduces bounded encoded-sRGB storage types, `SRgb8` and
`SRgba8`, while the existing computational `SRgb!T` model deliberately
preserves extended floating-point values.

Converting between those domains requires an explicit numerical contract.
A storage conversion must not silently become a clipping, gamut-mapping, or
special-value repair policy.

Unsigned normalized fixed-point conventions use the full integer range to
represent `[0, 1]`; for 8-bit storage this maps byte `c` to `c / 255`.
The Vulkan normalized fixed-point rules use this endpoint-preserving mapping
and nearest-integer conversion for the reverse direction. CSS Color 4 also
requires closest-integer behavior with upward tie resolution for legacy
8-bit alpha serialization.

Relevant references:

- Vulkan 1.4, §3.10.1–3.10.2, normalized fixed-point conversion:
  <https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html>
- CSS Color Module Level 4, §16.1.1 and §16.2:
  <https://www.w3.org/TR/css-color-4/>

These references motivate the normalized representation and rounding class;
color-d still owns its own explicit failure/clipping policy.

## Decision

### Storage to computation

Decode each byte independently as `component = byte / 255` in the requested
computational scalar type, `float` or `double`.

Therefore `0 -> 0` and `255 -> 1`.

For `SRgba8`, alpha uses the same normalization. The result is straight
`Alpha!(SRgb!T)`; RGB is not premultiplied and hidden RGB at zero alpha is
preserved.

### Computation to storage

Encoding is checked rather than implicitly clipping.

A component is storable only when it is within inclusive `[0, 1]`.
This predicate naturally rejects negative values, values greater than 1,
NaN, positive infinity, and negative infinity.

If any required RGB or alpha component is not storable, conversion returns
`false` and leaves the caller-supplied destination unchanged.

No implicit clipping or gamut mapping occurs. A caller that wants bounded
policy must perform that policy explicitly before storage conversion.

### Quantization

For a validated component `x`, quantize by multiplying by 255 and choosing
the nearest integer. Exact half steps choose the larger integer (half-up).

Equivalent bounded arithmetic is `truncate(x * 255 + 0.5)`, where the
truncating conversion is performed through a sufficiently wide unsigned
integer before narrowing to `ubyte`.

This guarantees `0.0 -> 0`, `1.0 -> 255`, and for example `0.5 -> 128`.

### API shape

The public conversion surface is:

    SRgb!T toSRgb(T)(SRgb8 value);

    Alpha!(SRgb!T) toAlphaSRgb(T)(SRgba8 value);

    bool tryToSRgb8(T)(
        SRgb!T value,
        ref SRgb8 output
    );

    bool tryToSRgba8(T)(
        Alpha!(SRgb!T) value,
        ref SRgba8 output
    );

The destination parameters use `ref`, not `out`, because failure promises
to leave existing caller state unchanged.

The scalar type for storage-to-computation conversion is always explicit.
Computation-to-storage infers `T` from the source value.

### Round-trip contract

For every possible byte value and both computational scalar widths:

    storage byte
        -> normalized float/double
        -> checked byte quantization
        == original byte

The same property applies independently to RGB and alpha.

This is a storage round-trip promise. It does not imply that arbitrary
floating-point inputs survive quantization unchanged.

### Attributes and execution modes

The conversion functions are allocation-free and must preserve
`@safe pure nothrow @nogc`. They support CTFE using the same public API.

## Consequences

Storage/computational transitions remain visible and policy-neutral.

Consumers cannot accidentally hide out-of-range or special floating-point
values by assigning them to byte storage.

Hexadecimal interop in #154 can operate directly on `SRgb8` / `SRgba8`
without inventing a second normalization policy.

Real-consumer validation in #155 can exercise the exact same conversion
contract through GUI/configuration and imagery-style boundaries.
