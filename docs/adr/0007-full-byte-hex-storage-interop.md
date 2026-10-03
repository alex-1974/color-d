# ADR 0007 — Restrict hexadecimal storage interop to full byte forms

**Status:** Accepted

## Context

`SRgb8` and `SRgba8` are exact 8-bit-per-channel storage values. Common
configuration/UI boundaries frequently use hexadecimal sRGB notation.

CSS Color 4 defines 3-, 4-, 6-, and 8-digit hexadecimal forms. The 6-digit
form maps one byte each to red, green, and blue; the 8-digit form appends one
alpha byte. Letter case is insignificant.

color-d does not need a general CSS parser for v0.2.0. Supporting shorthand
forms would add syntax-expansion policy without increasing the value domain of
the existing byte storage types.

Reference:

- CSS Color Module Level 4, §5.2:
  <https://www.w3.org/TR/css-color-4/#hex-notation>

## Decision

Support exactly these textual forms:

    #RRGGBB
    #RRGGBBAA

`SRgb8` owns the 7-character form and `SRgba8` owns the 9-character form.

Parsing:

- requires the leading `#`;
- requires exactly 6 or 8 hexadecimal digits for the target storage type;
- accepts `0-9`, `a-f`, and `A-F`;
- rejects shorthand `#RGB` / `#RGBA`;
- rejects whitespace, missing `#`, extra characters, and non-hex digits;
- returns `false` and leaves caller-owned destination unchanged on failure;
- performs no normalization or color-space conversion.

Serialization:

- returns a fixed-size `char[7]` or `char[9]` value;
- always includes the leading `#`;
- always uses lowercase ASCII hexadecimal digits;
- is allocation-free and deterministic.

Public surface:

    SRgb8.toHex() -> char[7]
    SRgba8.toHex() -> char[9]

    tryParseSRgb8Hex(scope const(char)[] text, ref SRgb8 output)
    tryParseSRgba8Hex(scope const(char)[] text, ref SRgba8 output)

All operations remain `@safe pure nothrow @nogc` and support CTFE.

## Consequences

The v0.2.0 hexadecimal API is an exact storage/interchange layer rather than a
CSS grammar implementation.

Broader CSS color syntax, named colors, shorthand expansion, functional
`rgb()`/`rgba()`, and wide-gamut textual forms remain outside this contract.
