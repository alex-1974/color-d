/++
 Public entry module for color-d.

 Use `import color;` for the complete public color-math API. color-d keeps
 color spaces and policy choices visible in the type system instead of hiding
 them behind one generic color value, and its current mathematical operations
 are value-based and allocation-free.

 Quick_Start:
     A common display-oriented path starts with encoded sRGB, converts to a
     perceptual space for editing, maps the result explicitly into the sRGB
     gamut, and encodes it for output.

     ---
     import color;

     const encoded = SRgbd(0.82, 0.25, 0.12);

     const perceptual =
         encoded
         .toLinear
         .toXyzD65
         .toOklab
         .toOklch;

     const adjusted =
         perceptual
         .withLightness(0.70)
         .withChroma(0.16);

     const display =
         adjusted
         .gamutMapRayTraceToLinearSRgb
         .toSRgb;
     ---

     Each step is explicit. Conversion does not imply clipping. Editing in
     OKLCH does not imply gamut mapping. Gamut mapping does not imply encoding.

 Color_Model:
     Compact storage and floating-point computation are distinct. `SRgb8`
     stores encoded sRGB channel bytes, while `SRgba8` adds a straight-alpha
     byte. Explicit storage/computational conversion is a separate operation.

     The public computational chain is:

     ---
     SRgb!T
         <-> LinearSRgb!T
         <-> XyzD65!T
         <-> Oklab!T
         <-> Oklch!T
     ---

     `T` is `float` or `double`.

     Encoded sRGB and linear-light sRGB are deliberately different types.
     This matters because physically meaningful operations such as alpha
     compositing must not be performed on nonlinear encoded channel values.

 Storage_Interop:
     `SRgb8` and `SRgba8` provide bounded byte storage distinct from the
     floating-point computational model. Conversion is explicit and checked in
     the storage direction.

     Compact hexadecimal interop is deliberately limited to exact full-byte
     forms: `#RRGGBB` for `SRgb8` and `#RRGGBBAA` for `SRgba8`.
     Parsing accepts hexadecimal letter case; serialization is deterministic
     lowercase. Broader CSS color syntax is outside this surface.

 Extended_Values:
     Color components are mathematical values, not storage bytes. Construction
     does not silently clamp values to [0, 1], and intermediate out-of-gamut
     values are preserved where the operation permits them.

     Use explicit gamut diagnostics, clipping, or gamut mapping when a consumer
     actually needs a bounded sRGB result.

 Gamut_Policy:
     color-d provides strict sRGB gamut tests, explicit hard clipping, and two
     explicit perceptual mapping algorithms: Local MINDE and Ray Trace.

     There is no default perceptual mapper. The caller chooses the policy.

 Alpha_And_Compositing:
     Straight alpha and premultiplied alpha are distinct concepts.
     Source-over compositing is defined for linear-light color values; color-d
     does not silently decode or encode colors around the operation.

 Interpolation:
     Interpolation is explicit about color space. OKLCH interpolation also
     exposes hue-path choice instead of silently selecting one angular route.

 Measurement:
     The library provides WCAG 2 relative luminance/contrast measurements and
     Oklab `deltaEOK`. Measurement functions report mathematical results;
     application accessibility policy remains outside the library.

 Cvd_Transforms:
     Model-specific Brettel 1997, Viénot 1999, and Machado 2009 color-vision-
     deficiency transformations operate explicitly in linear-light sRGB.
     They do not classify accessibility or apply gamut policy. Machado severity
     remains model-specific rather than becoming a generic CVD parameter.

 Error_Model:
     color-d distinguishes three kinds of state:

     * extended mathematical values such as NaN, infinity, or out-of-gamut
       components;
     * programmer preconditions, which may be enforced with assertions;
     * recoverable validation failure, which uses an explicit success/result
       channel.

     Mathematical operations do not throw merely to repair extended values.

 Allocation:
     Current public mathematical operations are value-based, `@nogc`, and do
     not perform hidden allocation. Runtime batch tone construction writes into
     caller-owned storage.

 Compile_Time:
     Deterministic core operations use the same API at runtime and during CTFE
     where the supported D toolchain permits it. Do not assume bit-identical
     intermediate evaluation across compiler/runtime/CTFE boundaries when the
     documented numerical contract allows a tolerance.

 Threading:
     The library creates no worker threads, owns no scheduler, and uses no
     shared mutable global state for mathematical operations. Parallel
     execution remains caller-controlled.

 Imports:
     `import color;` is the supported root import and re-exports the complete
     public API.

     Callers may also import documented public modules directly when a narrower
     dependency surface is useful. Technical reachability of an internal helper
     does not make that helper public API.

 Documentation:
     Start with the repository README and `docs/tutorial/getting-started.md`
     for task-oriented guidance. DDox pages describe exact declaration
     contracts. Every public callable has a directly associated executable
     documented-unittest example showing its normal use.

     Research and experiment history are engineering evidence, not consumer API
     documentation and not release-package content.

 Support:
     The v0.2.0 release matrix supports DMD 2.112.1 and 2.113.0 plus LDC
     1.42.0 and 1.43.0 on Ubuntu 24.04 x86-64. Fast CI uses DMD 2.113.0 and
     LDC 1.43.0; the full supported matrix is a release gate. LDC is the
     current release-performance reference compiler.

 Authors:
     Alexander

 Date:
     September 28, 2026

 Copyright:
     Copyright (c) 2026 Alexander

 License:
     MIT License. See the repository LICENSE file.

 See_Also:
     color.storage, color.rgb, color.xyz, color.cielab, color.oklab, color.oklch, color.alpha,
     color.composite, color.interpolate, color.gamut, color.wcag,
     color.difference, color.tone, color.cvd,
     https://github.com/alex-1974/color-d
+/
module color;

public import color.storage;
public import color.rgb;
public import color.xyz;
public import color.cielab;
public import color.oklab;
public import color.oklch;
public import color.gamut;
public import color.alpha;
public import color.composite;
public import color.interpolate;
public import color.difference;
public import color.wcag;
public import color.tone;
public import color.cvd;
