# R0.1 — Type Model and CTFE

Architecture spike for `color-d`.

Questions:

1. Are distinct color-space value types ergonomic in D?
2. Should computational color types be generic over `float` and `double`?
3. Do simple color structs have predictable compact layouts?
4. Is an orthogonal `Alpha!Color` wrapper practical?
5. Is a distinct premultiplied representation practical?
6. Can theme-like structures be generated at CTFE?
7. Can the same functions remain `@safe pure nothrow @nogc`?

This experiment does not define public API.

No code in this directory should be treated as stable or copied into
`source/color/` without a separate design decision.
