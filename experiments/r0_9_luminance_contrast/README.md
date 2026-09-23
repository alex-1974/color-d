# R0.9 — Relative Luminance and Contrast

Executable research spike for:

- WCAG 2.2 relative luminance;
- WCAG 2 contrast ratio;
- encoded-sRGB versus linear-sRGB paths;
- WCAG luminance versus XYZ-D65 Y;
- transfer-function boundary behavior;
- extended-range inputs;
- NaN / infinity behavior;
- alpha/compositing boundary;
- float / double generic arithmetic;
- CTFE and core function attributes;
- deterministic generated property tests.

The experiment deliberately does not create a production API.

It also deliberately does not silently clip, gamut-map or repair inputs.

The WCAG candidate functions are left arithmetically usable outside the
normative sRGB domain so that R0.9 can observe the consequences before
deciding whether a future public WCAG-specific API should require or
diagnose valid-domain input.

## Status

**PASS**

Validated with DMD 2.111.0 and LDC 1.41.0.

See `RESULTS.md` for:

- WCAG-2 luminance and contrast semantics;
- separation from XYZ-D65 Y;
- valid-domain and non-finite behavior;
- alpha/compositing boundary;
- checked-result API experiments;
- DMD/LDC performance measurements;
- DMD generated-code inspection.

No public API is frozen by R0.9.
