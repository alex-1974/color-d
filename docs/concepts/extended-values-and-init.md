# Extended values and `.init`

## Extended values are deliberate

Computational values are not automatically clipped to display ranges.
Negative RGB intermediates, RGB components above one, raw OKLCH chroma, and raw
hue may be meaningful during calculation.

Clipping and perceptual gamut mapping are explicit operations.

## Natural floating-point `.init` remains visible

The promoted floating-point value types intentionally keep D's natural NaN
initialization rather than redefining `.init` as black or another plausible
color.

Consequently the natural `.init` of these public value types is detectably
invalid/uninitialized for semantic use:

- `SRgb!T`;
- `LinearSRgb!T`;
- `XyzD65!T`;
- `Oklab!T`;
- `OklabHue!T`;
- `Oklch!T`;
- `Alpha!Color`;
- `Premultiplied!Color`;
- `Wcag2Measurement!T`.

`HuePath` is different: `HuePath.init == HuePath.shorter`, and that is a
valid interpolation policy.

Do not use a value merely because it exists. Where an operation has a finite
or standards-specific domain, follow that operation's explicit contract.
