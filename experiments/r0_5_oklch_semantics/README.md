# R0.5 — Oklab / OKLCH and Hue Semantics

Architecture/research spike for `color-d`.

This experiment follows:

- `docs/research/R0_5_OKLCH_SEMANTICS.md`
- R0.1 through R0.4

## Questions

1. Is a dedicated `OklabHue!T` wrapper practical?
2. Does it add any storage overhead?
3. Can raw/unbounded hue be preserved?
4. Can positive and signed normalized hue views remain explicit operations?
5. Should public/default hue use degrees while trigonometric operations use
   radians internally?
6. Can Oklab <-> OKLCH remain `@safe pure nothrow @nogc`?
7. Do `sqrt`, `atan2`, `sin`, and `cos` work in the intended CTFE paths?
8. Is exact achromatic Oklab deterministically representable as hue 0 degrees?
9. Can negative chroma remain representable as a non-canonical computational
   value?
10. Can negative chroma be canonicalized without changing the represented
    Oklab color?
11. What information is lost when raw hue with additional revolutions is
    converted through Cartesian Oklab?
12. Do DMD and LDC agree on the tested semantics?

## Candidate model

    OklabHue!T
        raw degrees

    Oklch!T
        L
        C
        OklabHue!T

Hue construction does not automatically normalize.

Explicit views provide:

    raw
    [0, 360)
    (-180, 180]

Oklab -> OKLCH produces a canonical positive hue because Cartesian Oklab
contains no information about previous hue revolutions.

Exact achromatic Oklab uses:

    C = 0
    h = 0 degrees

as a deterministic numeric fallback.

Negative chroma is tested as a valid but non-canonical computational value.

This experiment does not define stable public API.
