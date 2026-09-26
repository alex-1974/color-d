# R1 — Mathematical Core Production API Closeout

Date: 2026-09-26

Status: **PASS / COMPLETE**

Tracked by GitHub issue #3.

## Scope completed

R1 promoted the accepted R0 mathematical core into production:

- `SRgb!T`, `LinearSRgb!T`, `XyzD65!T`, `Oklab!T`, `Oklch!T`;
- `OklabHue!T`;
- `T = float | double` plus convenience aliases;
- explicit sRGB ↔ linear-sRGB transfer;
- explicit linear-sRGB ↔ XYZ D65 conversion;
- explicit XYZ D65 ↔ Oklab conversion;
- explicit Oklab ↔ OKLCH conversion;
- strict sRGB target-gamut diagnostics;
- explicit hard clipping in encoded and linear sRGB;
- curated root exports and supported direct public module imports.

Deferred types remain absent from the v0.1 core: `SRgb8`, `SRgba8`,
HSL and HSV. Alpha/interpolation remain R2 work; perceptual/measurement
utilities remain R3 work.

## Semantic verification

The production implementation preserves the accepted R0 semantics:

- color-space transitions are explicit;
- conversion never silently clips or gamut-maps;
- finite extended/out-of-gamut values remain representable;
- computational `.init` retains natural non-finite floating-point state;
- unsupported scalar types are rejected at compile time;
- OKLCH hue storage is raw and unbounded;
- exact achromaticity is `C == 0`;
- near-achromatic classification remains caller policy;
- strict sRGB gamut membership is finite component membership in `[0, 1]`;
- hard clipping does not silently repair NaN or infinity.

## Integrated compiler verification

Reference compilers:

```text
DMD 2.113.0
LDC 1.43.0 / DMD frontend 2.113.0 / LLVM 22.1.8
```

The complete production library passed:

- DMD debug unittests;
- DMD release unittests;
- LDC debug unittests;
- LDC release unittests;
- external DMD root/direct-import consumer;
- external LDC root/direct-import consumer;
- external LDC release consumer;
- complete runtime conversion round trip;
- complete CTFE conversion round trip.

Direct imports verified:

```d
import color.rgb;
import color.xyz;
import color.oklab;
import color.oklch;
import color.gamut;
```

The curated `import color;` root also supports the complete explicit
conversion chain.

## Type-safety and numerical policy

The integrated closeout probe verified:

- supported scalar aliases;
- rejection of unsupported `int` / `real` instantiations;
- rejection of wrong-space conversion calls;
- rejection of target-space gamut operations on Oklab and OKLCH;
- CTFE hard clipping and strict gamut classification;
- non-finite visibility through clipping.

Production scalar operations retain `@safe pure nothrow @nogc` where
applicable. No dependency on `imagery-d`, GUI frameworks or renderer APIs is
introduced.

The R0.13 numerical policy remains in force: no universal epsilon, no generic
public `approxEqual`, property-specific exact/reference/derived contracts,
separate float/double characterization, circular hue comparison where needed,
and explicit NaN/infinity semantics.

## LDC sRGB decode code-generation gate

The previously validated narrow LDC runtime optimization for sRGB decode
exponent 2.4 remains intact.

A release probe compiled with `ldc-1.43.0 -O3 -release` exported one runtime
function decoding three `double` sRGB channels. Its LLVM IR uses
`@llvm.pow.f64(..., 2.4)` per channel.

The exported assembly path contains exactly three:

```text
callq pow@PLT
```

calls and no `_powImpl` call in that decode path.

The object also contains unrelated emitted Phobos/template code referencing
`_powImpl`; that code is outside the exported sRGB decode hot path and does
not invalidate the gate.

## Exit result

All exit criteria listed in issue #3 are satisfied for the accepted R1 scope.

R1 is complete. The API remains pre-1.0 and consumer-correctable through the
planned R4 validation before release stabilization.
