/++
 Public entry module for color-d, a small, type-safe, allocation-free color
 mathematics library for D.

 color-d models materially different color spaces as distinct types and keeps
 semantic transitions explicit. Its public API covers encoded and linear-light
 sRGB, CIE XYZ D65, Oklab and OKLCH, alpha and premultiplied-alpha values,
 linear-light compositing, rectangular and polar interpolation, explicit gamut
 diagnostics and mapping, WCAG 2 luminance and contrast measurements, Oklab
 color difference, and low-level OKLCH tone construction.

 The library is designed as a mathematical core rather than an application
 styling framework. Color-space conversion, clipping, gamut mapping, alpha
 handling, and interpolation policy remain explicit operations. Extended
 mathematical values are preserved where the operation permits them instead of
 being silently clamped. Core value types and operations are intended to remain
 suitable for stack-based, allocation-free use, and deterministic operations
 support CTFE where the D toolchain permits it.

 Importing `color` provides the complete supported public color-d API through
 one module. Callers that prefer narrower dependencies may directly import the
 documented public submodules; those imports remain supported public entry
 points as well.

 Error_Model:
     color-d distinguishes mathematical extended values, programmer
     preconditions, and recoverable validation failures. Mathematical
     operations do not throw exceptions to repair NaN, infinity, extended
     range, alpha, or gamut state. Standards-facing validation exposes an
     explicit success channel such as `Wcag2Measurement.valid`; runtime batch
     APIs use an explicit Boolean success result and document output state on
     failure. Programmer preconditions may use assertions and must not be
     confused with recoverable input validation.

 Allocation:
     Current public mathematical operations are value-based, `@nogc`, and do
     not perform hidden allocation. Runtime batch operations that need storage
     write into caller-owned slices or static arrays.

 Threading:
     The library creates no worker threads, owns no scheduler, and uses no
     shared mutable global state for mathematical operations. Parallel
     execution remains caller-controlled.

 Support:
     The current pre-1.0 CI matrix tests DMD 2.113.0 and LDC 1.43.0 on
     Ubuntu 24.04 x86-64. No older minimum D frontend is currently promised.
     LDC is the current release-performance reference compiler.

 Authors:
     Alexander

 Date:
     September 27, 2026

 Copyright:
     Copyright (c) 2026 Alexander

 License:
     MIT License. See the repository LICENSE file.

 See_Also:
     color.rgb, color.oklab, color.oklch, color.gamut, color.wcag,
     https://github.com/alex-1974/color-d
+/
module color;

public import color.rgb;
public import color.xyz;
public import color.oklab;
public import color.oklch;
public import color.gamut;
public import color.alpha;
public import color.composite;
public import color.interpolate;
public import color.difference;
public import color.wcag;
public import color.tone;
