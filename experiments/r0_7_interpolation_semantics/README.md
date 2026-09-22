# R0.7 — Interpolation Semantics

Executable research spike for `color-d`.

This experiment validates or challenges the hypotheses documented in:

`docs/research/R0_7_INTERPOLATION_SEMANTICS.md`

It investigates:

- same-space rectangular interpolation;
- encoded versus linear sRGB semantics;
- Oklab interpolation;
- OKLCH hue paths;
- raw/unbounded hue interpolation;
- CSS shorter/longer/increasing/decreasing behavior;
- exact achromatic endpoint handling;
- near-achromatic behavior without hidden epsilon;
- negative-chroma canonicalization;
- alpha-aware rectangular interpolation;
- alpha-aware polar interpolation;
- zero-alpha behavior;
- extended-range preservation;
- extrapolation;
- float/double support;
- CTFE;
- compile-negative type mismatches.

The code in this directory is research code.

It does not define a stable public `color-d` API.

`RESULTS.md` is written only after the experiment has been run with both DMD
and LDC and the observed behavior has been reviewed.
