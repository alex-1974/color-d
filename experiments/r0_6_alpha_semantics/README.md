# R0.6 — Alpha and Premultiplied Alpha Semantics

Architecture/research spike for `color-d`.

Research basis:

- `docs/research/R0_6_ALPHA_SEMANTICS.md`
- R0.1 through R0.5

## Questions

1. Is `Alpha!Color` practical as a generic straight-alpha wrapper?
2. Does the wrapper remain compact for the validated color types?
3. Can straight and premultiplied alpha remain statically distinct?
4. Should compositing premultiplication initially be restricted to
   `LinearSRgb!T`?
5. Can encoded `SRgb!T` be rejected from the low-level `sourceOver` primitive
   by the type system?
6. Does `.init` remain diagnostically invalid through D floating-point NaN
   initialization?
7. Can invalid raw alpha values be represented without implicit clamping?
8. Does finite zero-alpha premultiplication deliberately lose hidden straight
   RGB?
9. Can zero-alpha unpremultiplication return deterministic transparent black?
10. Does Porter-Duff source-over reproduce known reference vectors?
11. Are extended linear-RGB values preserved without clipping?
12. Is premultiplied source-over approximately associative under floating-point
    arithmetic?
13. Do the essential operations remain `@safe pure nothrow @nogc` and
    CTFE-capable?
14. Do DMD and LDC agree?

## Deliberate scope limit

`Alpha!Color` is exercised generically.

`Premultiplied!Color` is structurally representable, but R0.6 only gives
compositing semantics to:

```text
Premultiplied!(LinearSRgb!T)
```

The experiment does not define generic polar-space premultiplication or
alpha-aware OKLCH interpolation.

No public API is stable.
