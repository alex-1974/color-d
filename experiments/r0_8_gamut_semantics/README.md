# R0.8 — Gamut Semantics

Executable research spike for `color-d`.

Research basis:

`docs/research/R0_8_GAMUT_SEMANTICS.md`

The experiment investigates:

- strict sRGB gamut detection;
- epsilon-aware numerical boundary detection;
- encoded/linear-sRGB gamut equivalence;
- non-finite values;
- explicit target-RGB clipping;
- clipping idempotence;
- deltaEOK;
- CSS Local-MINDE gamut mapping;
- CSS Ray Trace gamut mapping;
- constant-lightness / constant-hue chroma reduction;
- mapping identity for already in-gamut colors;
- mapping idempotence;
- float/double;
- CTFE;
- algorithm iteration counts.

EdgeSeeker is intentionally not implemented in this first spike.

This is research code and does not define a stable public API.

`RESULTS.md` is created only after successful observed DMD and LDC runs.
