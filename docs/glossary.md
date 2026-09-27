# Glossary

**encoded sRGB**  
The nonlinear sRGB representation modeled by `SRgb!T`.

**linear-light sRGB**  
The transfer-decoded sRGB representation modeled by `LinearSRgb!T`. It is the
required RGB representation for the library's reference source-over
compositor.

**extended value**  
A computational color component outside a nominal display interval, or another
non-canonical mathematical value that remains meaningful to an operation.

**gamut**  
The set of colors representable by a particular target. In current v0.1 scope,
bounded gamut operations target sRGB.

**clipping**  
Hard component saturation in target RGB coordinates. It is not perceptual
gamut mapping.

**gamut mapping**  
An explicit operation that maps an out-of-gamut color to the target gamut.
color-d exposes Local MINDE and Ray Trace as distinct named strategies.

**Oklab**  
The rectangular perceptual color space represented by `Oklab!T`.

**OKLCH**  
The cylindrical representation of Oklab with lightness, chroma, and hue.

**raw hue**  
The unbounded degree value stored by `OklabHue!T`. Normalized views are
explicit.

**straight alpha**  
Color coordinates stored independently of alpha, represented by
`Alpha!Color`.

**premultiplied alpha**  
Color coordinates multiplied by alpha, represented by
`Premultiplied!LinearSRgb!T` for the supported compositing boundary.

**CTFE**  
D compile-time function evaluation. color-d uses the same semantic public APIs
at runtime and CTFE where supported.

**WCAG 2 measurement**  
A standards-specific sRGB relative-luminance or contrast measurement represented
by `Wcag2Measurement!T`.

**ΔEOK / deltaEOK**  
Euclidean distance directly in Oklab. It does not classify perceptibility.
