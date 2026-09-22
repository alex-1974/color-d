# R0.2 — sRGB Transfer Function and CTFE

Architecture/research spike for `color-d`.

## Questions

1. Can encoded sRGB and linear-light sRGB remain distinct value types?
2. Do the standard sRGB transfer functions work generically for `float`
   and `double`?
3. Do they remain usable at CTFE?
4. Can extended negative and >1 component values be preserved?
5. What round-trip tolerances are appropriate for `float` and `double`?
6. Do DMD and LDC agree on the tested reference values?

This experiment does not define the final public API.

## Reference behavior

Encoded sRGB -> linear-light sRGB:

- linear segment through zero;
- power segment above the sRGB threshold;
- sign-preserving extension for negative values.

Linear-light sRGB -> encoded sRGB:

- linear segment through zero;
- inverse power segment outside the threshold;
- sign-preserving extension for negative values.

No clamping is performed.
